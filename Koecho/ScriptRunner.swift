import Foundation
import os

nonisolated enum ScriptRunnerError: Error, Equatable {
    case emptyScript
    case timeout
    case nonZeroExit(code: Int32, stderr: String)
    case emptyOutput
}

nonisolated struct ScriptRunnerContext: Sendable {
    var selection: String = ""
    var selectionStart: String = ""
    var selectionEnd: String = ""
    var prompt: String = ""
}

nonisolated struct ScriptRunnerResult: Sendable, Equatable {
    var output: String
    var stderr: String
}

nonisolated final class ScriptRunner: Sendable {
    let timeout: TimeInterval
    let killDelay: TimeInterval

    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "ScriptRunner")

    init(timeout: TimeInterval = 30.0, killDelay: TimeInterval = 5.0) {
        self.timeout = timeout
        self.killDelay = killDelay
    }

    /// Run a shell command, passing `input` via stdin and returning stdout.
    ///
    /// `scriptPath` is passed directly to `/bin/sh -c` as a shell command string.
    /// Do not pass untrusted input as `scriptPath`.
    func run(
        scriptPath: String,
        input: String,
        context: ScriptRunnerContext = ScriptRunnerContext()
    ) async throws -> ScriptRunnerResult {
        guard !scriptPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.error("Script command is empty")
            throw ScriptRunnerError.emptyScript
        }

        logger.info("Running script: \(scriptPath)")

        let process = makeProcess(scriptPath: scriptPath, context: context)

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
                state.cancelTimeoutWork()
                state.cancelKillWork()

                let timedOut = state.isTimedOut

                // Collect remaining pipe data
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
                    resumeOnce(with: .failure(
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

                resumeOnce(with: .success(ScriptRunnerResult(
                    output: trimmedOutput,
                    stderr: stderrString.trimmingCharacters(in: .whitespacesAndNewlines)
                )))
            }

            do {
                try process.run()

                // Schedule timeout only after process is running (pid is valid)
                let timeoutWork = DispatchWorkItem {
                    state.markTimedOut()
                    let pid = process.processIdentifier
                    process.terminate()

                    // Schedule SIGKILL in case SIGTERM is ignored
                    let sigkillWork = DispatchWorkItem {
                        Darwin.kill(pid, SIGKILL)
                    }
                    state.setKillWork(sigkillWork)
                    DispatchQueue.global().asyncAfter(
                        deadline: .now() + killDelay,
                        execute: sigkillWork
                    )
                }
                state.setTimeoutWork(timeoutWork)
                DispatchQueue.global().asyncAfter(
                    deadline: .now() + timeout,
                    execute: timeoutWork
                )

                // Write stdin after launch
                let inputData = input.data(using: .utf8) ?? Data()
                stdinPipe.fileHandleForWriting.write(inputData)
                stdinPipe.fileHandleForWriting.closeFile()
            } catch {
                logger.error("Failed to launch script: \(scriptPath), error: \(error)")
                resumeOnce(with: .failure(error))
            }
        }

        logger.info("Script completed: \(scriptPath)")
        return result
    }

    private func makeProcess(
        scriptPath: String,
        context: ScriptRunnerContext
    ) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", scriptPath]
        process.currentDirectoryURL = FileManager.default.temporaryDirectory

        let parentEnv = ProcessInfo.processInfo.environment
        var env: [String: String] = [:]
        if let path = parentEnv["PATH"] { env["PATH"] = path }
        if let home = parentEnv["HOME"] { env["HOME"] = home }
        env["KOECHO_SELECTION"] = context.selection
        env["KOECHO_SELECTION_START"] = context.selectionStart
        env["KOECHO_SELECTION_END"] = context.selectionEnd
        env["KOECHO_PROMPT"] = context.prompt
        process.environment = env

        return process
    }
}

/// Thread-safe mutable state shared between timeout and termination handlers.
nonisolated private final class RunState: @unchecked Sendable {
    private let lock = NSLock()
    private var _didTimeout = false
    private var _resumed = false
    private var _timeoutWork: DispatchWorkItem?
    private var _killWork: DispatchWorkItem?

    var isTimedOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _didTimeout
    }

    func markTimedOut() {
        lock.lock()
        _didTimeout = true
        lock.unlock()
    }

    func tryResume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let shouldResume = !_resumed
        _resumed = true
        return shouldResume
    }

    func setTimeoutWork(_ work: DispatchWorkItem) {
        lock.lock()
        _timeoutWork = work
        lock.unlock()
    }

    func cancelTimeoutWork() {
        lock.lock()
        _timeoutWork?.cancel()
        lock.unlock()
    }

    func setKillWork(_ work: DispatchWorkItem) {
        lock.lock()
        _killWork = work
        lock.unlock()
    }

    func cancelKillWork() {
        lock.lock()
        _killWork?.cancel()
        lock.unlock()
    }
}

/// Collects data from a Pipe's readability handler without blocking.
nonisolated private final class PipeCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var chunks: [Data] = []
    private let pipe: Pipe

    init(pipe: Pipe) {
        self.pipe = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self else { return }
            self.lock.lock()
            self.chunks.append(data)
            self.lock.unlock()
        }
    }

    /// Stop collecting and return all accumulated data.
    /// Called from terminationHandler after the process has exited,
    /// so all output has been written and readabilityHandler callbacks
    /// have been dispatched. Setting readabilityHandler = nil prevents
    /// new callbacks; readDataToEndOfFile() drains any remaining buffered data.
    func finalize() -> Data {
        pipe.fileHandleForReading.readabilityHandler = nil
        let remaining = pipe.fileHandleForReading.readDataToEndOfFile()

        lock.lock()
        var allData = chunks
        lock.unlock()

        if !remaining.isEmpty {
            allData.append(remaining)
        }
        return allData.reduce(Data(), +)
    }
}
