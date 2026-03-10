import Foundation
import Testing
@testable import KoechoCore

nonisolated struct ScriptRunnerTests {
    private func makeScript(_ content: String) throws -> String {
        let dir = FileManager.default.temporaryDirectory
        let path = dir.appendingPathComponent("koecho-test-\(UUID().uuidString).sh").path
        try ("#!/bin/sh\n" + content).write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: path
        )
        return path
    }

    // MARK: - Success

    @Test func passthrough() async throws {
        let path = try makeScript("cat")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner()
        let result = try await runner.run(scriptPath: path, input: "hello world")

        #expect(result.output == "hello world")
    }

    @Test func transforms() async throws {
        let path = try makeScript("tr a-z A-Z")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner()
        let result = try await runner.run(scriptPath: path, input: "hello")

        #expect(result.output == "HELLO")
    }

    @Test func trimsWhitespace() async throws {
        let path = try makeScript("echo '  trimmed  '")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner()
        let result = try await runner.run(scriptPath: path, input: "")

        #expect(result.output == "trimmed")
    }

    @Test func capturesStderr() async throws {
        let path = try makeScript("echo 'output' && echo 'debug info' >&2")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner()
        let result = try await runner.run(scriptPath: path, input: "")

        #expect(result.output == "output")
        #expect(result.stderr == "debug info")
    }

    // MARK: - Environment Variables

    @Test func passesKoechoEnvironmentVariables() async throws {
        let path = try makeScript(
            "echo \"$KOECHO_SELECTION|$KOECHO_SELECTION_START|$KOECHO_SELECTION_END|$KOECHO_PROMPT\""
        )
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner()
        let context = ScriptRunnerContext(
            selection: "selected text",
            selectionStart: "10",
            selectionEnd: "22",
            prompt: "make it better"
        )
        let result = try await runner.run(scriptPath: path, input: "", context: context)

        #expect(result.output == "selected text|10|22|make it better")
    }

    @Test func passesPathAndHome() async throws {
        let path = try makeScript("echo \"PATH=$PATH\" && echo \"HOME=$HOME\"")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner()
        let result = try await runner.run(scriptPath: path, input: "")

        #expect(result.output.contains("PATH="))
        #expect(result.output.contains("HOME="))
    }

    @Test func doesNotLeakTCCVariables() async throws {
        let path = try makeScript("env")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner()
        let result = try await runner.run(scriptPath: path, input: "")

        let lines = result.output.components(separatedBy: "\n")
        let cfVars = lines.filter { $0.hasPrefix("__CF_") }
        #expect(cfVars.isEmpty)
    }

    // MARK: - Errors

    @Test func scriptNotFound() async throws {
        let runner = ScriptRunner()

        await #expect {
            try await runner.run(scriptPath: "/nonexistent/script.sh", input: "")
        } throws: { error in
            guard let scriptError = error as? ScriptRunnerError,
                  case .nonZeroExit(let code, let stderr) = scriptError else { return false }
            return code == 127 && !stderr.isEmpty
        }
    }

    @Test func emptyScript() async throws {
        let runner = ScriptRunner()

        await #expect(throws: ScriptRunnerError.emptyScript) {
            try await runner.run(scriptPath: "", input: "")
        }
        await #expect(throws: ScriptRunnerError.emptyScript) {
            try await runner.run(scriptPath: "   ", input: "")
        }
    }

    @Test func scriptWithArguments() async throws {
        let path = try makeScript("echo \"args: $@\"")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner()
        let result = try await runner.run(scriptPath: "'\(path)' arg1 arg2", input: "")

        #expect(result.output == "args: arg1 arg2")
    }

    @Test func nonZeroExitNoStderr() async throws {
        let path = try makeScript("exit 1")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner()

        await #expect(throws: ScriptRunnerError.nonZeroExit(code: 1, stderr: "")) {
            try await runner.run(scriptPath: path, input: "")
        }
    }

    @Test func nonZeroExitWithStderr() async throws {
        let path = try makeScript("echo 'error msg' >&2; exit 2")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner()

        await #expect(throws: ScriptRunnerError.nonZeroExit(code: 2, stderr: "error msg")) {
            try await runner.run(scriptPath: path, input: "")
        }
    }

    @Test func emptyOutput() async throws {
        let path = try makeScript("printf ''")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner()

        await #expect(throws: ScriptRunnerError.emptyOutput) {
            try await runner.run(scriptPath: path, input: "")
        }
    }

    @Test func whitespaceOnlyOutput() async throws {
        let path = try makeScript("echo '   '")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner()

        await #expect(throws: ScriptRunnerError.emptyOutput) {
            try await runner.run(scriptPath: path, input: "")
        }
    }

    // MARK: - Timeout

    @Test func timeout() async throws {
        let path = try makeScript("sleep 10")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner(timeout: 0.5, killDelay: 0.5)

        await #expect(throws: ScriptRunnerError.timeout) {
            try await runner.run(scriptPath: path, input: "")
        }
    }

    @Test func normalCompletionDoesNotTimeout() async throws {
        let path = try makeScript("echo 'fast'")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner(timeout: 5.0)
        let result = try await runner.run(scriptPath: path, input: "")

        #expect(result.output == "fast")
    }

    // MARK: - Edge Cases

    @Test func emptyInput() async throws {
        let path = try makeScript("echo 'no input needed'")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner()
        let result = try await runner.run(scriptPath: path, input: "")

        #expect(result.output == "no input needed")
    }

    @Test func multilineInput() async throws {
        let path = try makeScript("cat")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner()
        let input = "line1\nline2\nline3"
        let result = try await runner.run(scriptPath: path, input: input)

        #expect(result.output == input)
    }

    @Test func currentDirectoryIsTmpDir() async throws {
        let path = try makeScript("pwd -P")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner()
        let result = try await runner.run(scriptPath: path, input: "")

        // pwd -P resolves /var → /private/var, but FileManager does not
        let tmpDir = FileManager.default.temporaryDirectory.path
        #expect(
            result.output == tmpDir || result.output == "/private" + tmpDir
        )
    }

    @Test func scriptPathWithSpaces() async throws {
        let dir = FileManager.default.temporaryDirectory
        let path = dir.appendingPathComponent("koecho test script \(UUID().uuidString).sh").path
        try ("#!/bin/sh\necho 'spaces ok'").write(
            toFile: path, atomically: true, encoding: .utf8
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: path
        )
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner()
        let result = try await runner.run(scriptPath: "'\(path)'", input: "")

        #expect(result.output == "spaces ok")
    }

    @Test func scriptPathWithSpacesAndArguments() async throws {
        let dir = FileManager.default.temporaryDirectory
        let path = dir.appendingPathComponent("koecho test script \(UUID().uuidString).sh").path
        try ("#!/bin/sh\necho \"args: $@\"").write(
            toFile: path, atomically: true, encoding: .utf8
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: path
        )
        defer { try? FileManager.default.removeItem(atPath: path) }

        let runner = ScriptRunner()
        let result = try await runner.run(scriptPath: "'\(path)' arg1 arg2", input: "")

        #expect(result.output == "args: arg1 arg2")
    }
}
