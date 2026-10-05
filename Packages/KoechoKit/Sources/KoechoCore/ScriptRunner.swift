import Foundation
import Synchronization
import os

public nonisolated enum ScriptRunnerError: Error, Equatable {
  case emptyScript
  case timeout
  case nonZeroExit(code: Int32, stderr: String)
  case emptyOutput
}

public nonisolated struct ScriptRunnerContext: Sendable {
  public var selection: String = ""
  public var selectionStart: String = ""
  public var selectionEnd: String = ""
  public var prompt: String = ""

  public init(
    selection: String = "",
    selectionStart: String = "",
    selectionEnd: String = "",
    prompt: String = ""
  ) {
    self.selection = selection
    self.selectionStart = selectionStart
    self.selectionEnd = selectionEnd
    self.prompt = prompt
  }
}

public nonisolated struct ScriptRunnerResult: Sendable, Equatable {
  public var output: String
  public var stderr: String

  public init(output: String, stderr: String) {
    self.output = output
    self.stderr = stderr
  }
}

public nonisolated final class ScriptRunner: Sendable {
  public let timeout: TimeInterval
  public let killDelay: TimeInterval

  private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "ScriptRunner")

  public init(timeout: TimeInterval = 30.0, killDelay: TimeInterval = 5.0) {
    self.timeout = timeout
    self.killDelay = killDelay
  }

  /// Run a shell command, passing `input` via stdin and returning stdout.
  ///
  /// `scriptPath` is passed directly to `/bin/sh -c` as a shell command string.
  /// Do not pass untrusted input as `scriptPath`.
  public func run(
    scriptPath: String,
    input: String,
    context: ScriptRunnerContext = ScriptRunnerContext()
  ) async throws -> ScriptRunnerResult {
    guard !scriptPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      logger.error("Script command is empty")
      throw ScriptRunnerError.emptyScript
    }

    logger.info("Running script: \(scriptPath)")

    let process = makeProcess(
      scriptPath: scriptPath,
      context: context,
      parentEnvironment: ProcessInfo.processInfo.environment
    )

    let stdinPipe = Pipe()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardInput = stdinPipe
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    let stdoutCollector = PipeCollector(pipe: stdoutPipe)
    let stderrCollector = PipeCollector(pipe: stderrPipe)

    let state = RunState()
    let timeout = self.timeout
    let killDelay = self.killDelay
    let logger = self.logger

    let result: ScriptRunnerResult = try await withCheckedThrowingContinuation { continuation in
      @Sendable func finishIfReady(forceTimeout: Bool = false) {
        let stdoutData = stdoutCollector.outputIfFinished()
        let stderrData = stderrCollector.outputIfFinished()
        guard let completion = state.completeIfReady(
          outputFinished: stdoutData != nil && stderrData != nil,
          forceTimeout: forceTimeout
        ) else { return }

        stdoutCollector.stop()
        stderrCollector.stop()
        process.terminationHandler = nil

        if completion.timedOut {
          logger.error("Script timed out: \(scriptPath)")
          continuation.resume(throwing: ScriptRunnerError.timeout)
          return
        }

        let stdoutString = String(data: stdoutData ?? Data(), encoding: .utf8) ?? ""
        let stderrString = (String(data: stderrData ?? Data(), encoding: .utf8) ?? "")
          .trimmingCharacters(in: .whitespacesAndNewlines)
        if completion.exitCode != 0 {
          continuation.resume(throwing: ScriptRunnerError.nonZeroExit(
            code: completion.exitCode, stderr: stderrString))
          return
        }
        let output = stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
        if output.isEmpty {
          continuation.resume(throwing: ScriptRunnerError.emptyOutput)
        } else {
          continuation.resume(returning: ScriptRunnerResult(output: output, stderr: stderrString))
        }
      }

      stdoutCollector.start { finishIfReady() }
      stderrCollector.start { finishIfReady() }
      process.terminationHandler = { terminatedProcess in
        let timedOut = state.recordExit(terminatedProcess.terminationStatus)
        finishIfReady(forceTimeout: timedOut)
      }

      do {
        try process.run()

        // Schedule timeout only after process is running (pid is valid)
        state.scheduleTimeout(after: timeout) {
          guard state.beginTimeout() else { return }
          if process.isRunning { process.terminate() }
          if state.hasExited {
            finishIfReady(forceTimeout: true)
            return
          }

          // Bound output collection even when a child keeps a pipe open.
          state.scheduleKill(after: killDelay) {
            if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
            finishIfReady(forceTimeout: true)
          }
        }

        // Write stdin after launch
        let inputData = input.data(using: .utf8) ?? Data()
        stdinPipe.fileHandleForWriting.write(inputData)
        stdinPipe.fileHandleForWriting.closeFile()
      } catch {
        guard state.completeAfterLaunchFailure() else { return }
        stdoutCollector.stop()
        stderrCollector.stop()
        process.terminationHandler = nil
        logger.error("Failed to launch script: \(scriptPath), error: \(error)")
        continuation.resume(throwing: error)
      }
    }

    logger.info("Script completed: \(scriptPath)")
    return result
  }

  func makeProcess(
    scriptPath: String,
    context: ScriptRunnerContext,
    parentEnvironment: [String: String]
  ) -> Process {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", scriptPath]
    // Avoid inheriting the app process cwd and private TCC-related variables.
    process.currentDirectoryURL = FileManager.default.temporaryDirectory

    var env: [String: String] = [:]
    if let path = parentEnvironment["PATH"] { env["PATH"] = path }
    if let home = parentEnvironment["HOME"] { env["HOME"] = home }
    env["KOECHO_SELECTION"] = context.selection
    env["KOECHO_SELECTION_START"] = context.selectionStart
    env["KOECHO_SELECTION_END"] = context.selectionEnd
    env["KOECHO_PROMPT"] = context.prompt
    process.environment = env

    return process
  }
}

/// Thread-safe mutable state shared between timeout and termination handlers.
nonisolated private final class RunState: Sendable {
  private struct State {
    var didTimeout = false
    var exitCode: Int32?
    var completed = false
    var timeoutWork: DispatchWorkItem?
    var killWork: DispatchWorkItem?
  }

  private let state = Mutex(State())

  func beginTimeout() -> Bool {
    state.withLock { state in
      guard !state.completed else { return false }
      state.didTimeout = true
      return true
    }
  }

  var hasExited: Bool { state.withLock { $0.exitCode != nil } }

  func recordExit(_ exitCode: Int32) -> Bool {
    state.withLock { state in
      state.exitCode = exitCode
      return state.didTimeout
    }
  }

  func completeIfReady(outputFinished: Bool, forceTimeout: Bool)
    -> (timedOut: Bool, exitCode: Int32)?
  {
    state.withLock { state in
      guard !state.completed else { return nil }
      if state.didTimeout {
        guard forceTimeout else { return nil }
      } else {
        guard outputFinished, state.exitCode != nil else { return nil }
      }
      finish(&state)
      return (state.didTimeout, state.exitCode ?? 0)
    }
  }

  func completeAfterLaunchFailure() -> Bool {
    state.withLock { state in
      guard !state.completed else { return false }
      finish(&state)
      return true
    }
  }

  private func finish(_ state: inout State) {
    state.completed = true
    state.timeoutWork?.cancel()
    state.timeoutWork = nil
    state.killWork?.cancel()
    state.killWork = nil
  }

  func scheduleTimeout(after delay: TimeInterval, execute: @escaping @Sendable () -> Void) {
    state.withLock { state in
      guard !state.completed else { return }
      let work = DispatchWorkItem(block: execute)
      state.timeoutWork = work
      DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: work)
    }
  }

  func scheduleKill(after delay: TimeInterval, execute: @escaping @Sendable () -> Void) {
    state.withLock { state in
      guard !state.completed else { return }
      let work = DispatchWorkItem(block: execute)
      state.killWork = work
      DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: work)
    }
  }

}

/// Nonblocking reads keep both pipe draining and shutdown independent of child EOF.
nonisolated private final class PipeCollector: Sendable {
  private struct State {
    var data = Data()
    var finished = false
    var stopped = false
  }

  private let state = Mutex(State())
  private let pipe: Pipe
  private let source: any DispatchSourceRead

  init(pipe: Pipe) {
    self.pipe = pipe
    let fd = pipe.fileHandleForReading.fileDescriptor
    _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
    source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global())
    source.setCancelHandler { try? pipe.fileHandleForReading.close() }
  }

  func start(onFinished: @escaping @Sendable () -> Void) {
    source.setEventHandler { [weak self] in
      guard let self else { return }
      let finished = self.state.withLock { state in
        guard !state.stopped && !state.finished else { return false }
        var buffer = [UInt8](repeating: 0, count: 4096)
        // Limit each callback so shutdown can always acquire this lock.
        for _ in 0..<64 {
          let count = Darwin.read(self.pipe.fileHandleForReading.fileDescriptor, &buffer, buffer.count)
          if count > 0 {
            state.data.append(contentsOf: buffer.prefix(count))
          } else if count == 0 {
            state.finished = true
            return true
          } else if errno == EINTR {
            continue
          } else {
            return false
          }
        }
        return false
      }
      if finished {
        self.source.cancel()
        onFinished()
      }
    }
    source.resume()
  }

  func outputIfFinished() -> Data? {
    state.withLock { $0.finished ? $0.data : nil }
  }

  func stop() {
    state.withLock { $0.stopped = true }
    source.setEventHandler(handler: nil)
    source.cancel()
  }
}
