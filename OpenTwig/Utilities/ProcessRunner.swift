import Foundation

// MARK: - ProcessResult

/// Captures the outcome of a subprocess execution.
struct ProcessResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

// MARK: - ProcessRunner Errors

enum ProcessRunnerError: LocalizedError {
    case executableNotFound(String)
    case unsafeArgument(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let path):
            return "Executable not found at path: \(path)."
        case .unsafeArgument(let argument):
            return "Argument contains disallowed shell metacharacters: \"\(argument)\"."
        case .executionFailed(let reason):
            return "Process execution failed: \(reason)."
        }
    }
}

// MARK: - ProcessRunner

/// Runs external processes safely, without invoking a shell.
///
/// **Security contract:**
/// - Executable paths must be absolute (no PATH lookup through a shell).
/// - Arguments are passed directly to `execve` -- no shell interpolation.
/// - Arguments containing shell metacharacters are rejected at the call site
///   to prevent accidental misuse if a future caller builds strings naively.
enum ProcessRunner {

    // Characters that have special meaning in common shells. Rejecting these
    // provides defense-in-depth even though we never invoke a shell.
    private static let shellMetacharacters = CharacterSet(charactersIn: ";|&$`\"'\\!{}()<>*?~#\n")

    /// Runs an executable with the given arguments and optional working directory.
    ///
    /// - Parameters:
    ///   - executable: Absolute path to the binary (e.g. `/usr/bin/git`).
    ///   - arguments: Command-line arguments. Each is validated for shell metacharacters.
    ///   - workingDirectory: Optional directory to set as the CWD for the process.
    /// - Returns: A `ProcessResult` with stdout, stderr, and exit code.
    /// - Throws: `ProcessRunnerError` if validation fails or the process cannot start.
    static func run(
        executable: String,
        arguments: [String],
        workingDirectory: URL? = nil
    ) async throws -> ProcessResult {
        // Validate executable path is absolute.
        guard executable.hasPrefix("/") else {
            throw ProcessRunnerError.executableNotFound(executable)
        }

        // Verify the executable exists on disk.
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            throw ProcessRunnerError.executableNotFound(executable)
        }

        // Validate arguments -- reject any containing shell metacharacters.
        for argument in arguments {
            if argument.rangeOfCharacter(from: Self.shellMetacharacters) != nil {
                throw ProcessRunnerError.unsafeArgument(argument)
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            if let workingDirectory {
                process.currentDirectoryURL = workingDirectory
            }

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Prevent the child from inheriting our environment wholesale.
            // Pass a minimal, safe environment.
            process.environment = Self.safeEnvironment()

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ProcessRunnerError.executionFailed(error.localizedDescription))
                return
            }

            process.waitUntilExit()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            let result = ProcessResult(
                stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                stderr: String(data: stderrData, encoding: .utf8) ?? "",
                exitCode: process.terminationStatus
            )

            continuation.resume(returning: result)
        }
    }

    // MARK: - Private

    /// Returns a minimal environment dictionary for child processes.
    private static func safeEnvironment() -> [String: String] {
        var env: [String: String] = [:]
        // Preserve PATH so the child can locate dynamic libraries, but nothing else
        // that could alter behavior in surprising ways.
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            env["PATH"] = path
        }
        if let home = ProcessInfo.processInfo.environment["HOME"] {
            env["HOME"] = home
        }
        // Git requires these for proper operation.
        if let lang = ProcessInfo.processInfo.environment["LANG"] {
            env["LANG"] = lang
        }
        return env
    }
}
