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
      @Sendable func resumeOnce(with result: Result<ScriptRunnerResult, any Error>) {
        if state.tryResume() {
          continuation.resume(with: result)
        }
      }

      process.terminationHandler = { terminatedProcess in
        let timedOut = state.complete()

        let stdoutData = stdoutCollector.finalize()
        let stderrData = stderrCollector.finalize()

        let stdoutString = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrString = String(data: stderrData, encoding: .utf8) ?? ""

        if timedOut {
          logger.error("Script timed out: \(scriptPath)")
          resumeOnce(with: .failure(ScriptRunnerError.timeout))
          return
        }

        let exitCode = terminatedProcess.terminationStatus
        if exitCode != 0 {
          logger.error("Script exited with code \(exitCode): \(scriptPath)")
          resumeOnce(
            with: .failure(
              ScriptRunnerError.nonZeroExit(
                code: exitCode,
                stderr: stderrString.trimmingCharacters(in: .whitespacesAndNewlines)
              )
            ))
          return
        }

        let trimmedOutput = stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedOutput.isEmpty {
          logger.warning("Script produced empty output: \(scriptPath)")
          resumeOnce(with: .failure(ScriptRunnerError.emptyOutput))
          return
        }

        resumeOnce(
          with: .success(
            ScriptRunnerResult(
              output: trimmedOutput,
              stderr: stderrString.trimmingCharacters(in: .whitespacesAndNewlines)
            )))
      }

      do {
        try process.run()

        // Schedule timeout only after process is running (pid is valid)
        state.scheduleTimeout(after: timeout) {
          guard state.beginTimeout() else { return }
          let pid = process.processIdentifier
          process.terminate()

          // Schedule SIGKILL in case SIGTERM is ignored
          state.scheduleKill(after: killDelay) {
            Darwin.kill(pid, SIGKILL)
          }
        }

        // Write stdin after launch
        let inputData = input.data(using: .utf8) ?? Data()
        stdinPipe.fileHandleForWriting.write(inputData)
        stdinPipe.fileHandleForWriting.closeFile()
      } catch {
        state.complete()
        logger.error("Failed to launch script: \(scriptPath), error: \(error)")
        resumeOnce(with: .failure(error))
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
    var resumed = false
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

  @discardableResult
  func complete() -> Bool {
    state.withLock { state in
      state.completed = true
      state.timeoutWork?.cancel()
      state.timeoutWork = nil
      state.killWork?.cancel()
      state.killWork = nil
      return state.didTimeout
    }
  }

  func tryResume() -> Bool {
    state.withLock { state in
      let shouldResume = !state.resumed
      state.resumed = true
      return shouldResume
    }
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

/// Collects data from a Pipe's readability handler without blocking.
nonisolated private final class PipeCollector: Sendable {
  private struct State {
    var chunks: [Data] = []
    var finalized = false
  }

  private let state = Mutex(State())
  private let pipe: Pipe

  init(pipe: Pipe) {
    self.pipe = pipe

    pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      guard let self else { return }
      self.state.withLock { state in
        guard !state.finalized else { return }
        let data = handle.availableData
        if !data.isEmpty { state.chunks.append(data) }
      }
    }
  }

  /// Stop collecting and return all accumulated data.
  /// Called from terminationHandler after the process has exited,
  /// so all output has been written. The lock joins any in-flight read and
  /// append before draining the pipe; queued callbacks skip the finalized pipe.
  func finalize() -> Data {
    pipe.fileHandleForReading.readabilityHandler = nil
    return state.withLock { state in
      state.finalized = true
      let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
      if !remaining.isEmpty { state.chunks.append(remaining) }
      return state.chunks.reduce(Data(), +)
    }
  }
}
