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

  @Test func capturesShortLivedTransformation() async throws {
    let result = try await ScriptRunner().run(scriptPath: "tr a-z A-Z", input: "original")

    #expect(result.output == "ORIGINAL")
  }

  @Test func repeatsShortLivedCustomScripts() async throws {
    let runner = ScriptRunner(timeout: 0.2, killDelay: 0.1)
    for _ in 0..<30 {
      let result = try await runner.run(scriptPath: "tr a-z A-Z", input: "original")
      #expect(result.output == "ORIGINAL")
      await #expect(throws: ScriptRunnerError.nonZeroExit(code: 2, stderr: "error")) {
        try await runner.run(scriptPath: "printf error >&2; exit 2", input: "")
      }
      await #expect(throws: ScriptRunnerError.emptyOutput) {
        try await runner.run(scriptPath: ":", input: "")
      }
    }
  }

  @Test func escalatesTimeoutWhenTermIsIgnored() async throws {
    await #expect(throws: ScriptRunnerError.timeout) {
      try await ScriptRunner(timeout: 0.1, killDelay: 0.1).run(
        scriptPath: "trap '' TERM; while :; do :; done", input: "")
    }
  }

  @Test func capturesOrderedOutputBeyondPipeCapacity() async throws {
    let result = try await ScriptRunner().run(
      scriptPath: "awk 'BEGIN { for (i = 0; i < 20000; i++) { print i; print i > \"/dev/stderr\" } }'",
      input: ""
    )
    let expected = (0..<20000).map(String.init).joined(separator: "\n")

    #expect(result.output == expected)
    #expect(result.stderr == expected)
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

  @Test func doesNotLeakTCCVariables() throws {
    let parentEnvironment = [
      "PATH": "/koecho-test/path",
      "HOME": "/koecho-test/home",
      "__CF_USER_TEXT_ENCODING": "koecho-test-encoding",
      "__CF_TEST_SENTINEL": "koecho-test-private",
      "KOECHO_TEST_UNRELATED": "koecho-test-unrelated",
    ]
    let process = ScriptRunner().makeProcess(
      scriptPath: "/usr/bin/env",
      context: ScriptRunnerContext(),
      parentEnvironment: parentEnvironment
    )
    #expect(process.environment == [
      "PATH": "/koecho-test/path",
      "HOME": "/koecho-test/home",
      "KOECHO_SELECTION": "",
      "KOECHO_SELECTION_START": "",
      "KOECHO_SELECTION_END": "",
      "KOECHO_PROMPT": "",
    ])

    let outputPipe = Pipe()
    defer { try? outputPipe.fileHandleForReading.close() }
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = outputPipe
    try process.run()
    let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)

    let lines = try #require(String(data: output, encoding: .utf8)).split(separator: "\n")
    let childEnvironment = Dictionary(uniqueKeysWithValues: lines.map { line in
      let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
      return (String(parts[0]), String(parts[1]))
    })
    #expect(childEnvironment.keys.filter { $0.hasPrefix("__CF_") }.isEmpty)
    #expect(childEnvironment["KOECHO_TEST_UNRELATED"] == nil)
    #expect(childEnvironment["PATH"] == "/koecho-test/path")
    #expect(childEnvironment["HOME"] == "/koecho-test/home")
  }

  // MARK: - Errors

  @Test func scriptNotFound() async throws {
    let runner = ScriptRunner()

    await #expect {
      try await runner.run(scriptPath: "/nonexistent/script.sh", input: "")
    } throws: { error in
      guard let scriptError = error as? ScriptRunnerError,
        case .nonZeroExit(let code, let stderr) = scriptError
      else { return false }
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

  // MARK: - Edge Cases

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
