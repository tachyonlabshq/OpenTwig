import Foundation

// MARK: - Errors

enum GitError: LocalizedError, Sendable {
    case notARepository
    case repositoryNotOpen
    case cloneFailed(String)
    case commitFailed(String)
    case pushFailed(String)
    case pullFailed(String)
    case branchFailed(String)
    case mergeFailed(String)
    case diffFailed(String)
    case statusFailed(String)
    case logFailed(String)
    case commandFailed(command: String, exitCode: Int32, stderr: String)
    case gitNotFound
    case invalidArgument(String)

    var errorDescription: String? {
        switch self {
        case .notARepository:
            return "The directory is not a Git repository"
        case .repositoryNotOpen:
            return "No repository is currently open"
        case .cloneFailed(let msg):
            return "Clone failed: \(msg)"
        case .commitFailed(let msg):
            return "Commit failed: \(msg)"
        case .pushFailed(let msg):
            return "Push failed: \(msg)"
        case .pullFailed(let msg):
            return "Pull failed: \(msg)"
        case .branchFailed(let msg):
            return "Branch operation failed: \(msg)"
        case .mergeFailed(let msg):
            return "Merge failed: \(msg)"
        case .diffFailed(let msg):
            return "Diff failed: \(msg)"
        case .statusFailed(let msg):
            return "Status failed: \(msg)"
        case .logFailed(let msg):
            return "Log failed: \(msg)"
        case .commandFailed(let command, let exitCode, let stderr):
            return "Git command '\(command)' exited with code \(exitCode): \(stderr)"
        case .gitNotFound:
            return "Git executable not found. Ensure Git is installed."
        case .invalidArgument(let msg):
            return "Invalid argument: \(msg)"
        }
    }
}

// MARK: - Merge Result

enum MergeResult: Sendable {
    case success
    case conflicts([MergeConflict])
}

// MARK: - GitService Actor

actor GitService {

    private var repositoryPath: URL?

    /// Resolved path to the git binary. Cached after first lookup.
    private var gitPath: String?

    // MARK: - Repository Lifecycle

    /// Clone a remote repository.
    func clone(
        url: String,
        to destination: URL,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        try validateURL(url)

        // Clone runs in the parent directory; git creates a subdirectory.
        let result = try await runGitAsync(
            ["clone", "--progress", url, destination.path],
            at: destination.deletingLastPathComponent(),
            progressHandler: progressHandler
        )

        guard FileManager.default.fileExists(
            atPath: destination.appendingPathComponent(".git").path
        ) else {
            throw GitError.cloneFailed(result.stderr)
        }

        repositoryPath = destination
        return destination
    }

    /// Open an existing local repository.
    func open(at path: URL) throws {
        guard FileManager.default.fileExists(
            atPath: path.appendingPathComponent(".git").path
        ) else {
            throw GitError.notARepository
        }
        repositoryPath = path
    }

    // MARK: - Status

    func status() throws -> GitStatus {
        let output = try runGit(["status", "--porcelain=v1", "-uall"])

        var staged: [GitFileStatus] = []
        var modified: [GitFileStatus] = []
        var untracked: [GitFileStatus] = []

        for line in output.stdout.components(separatedBy: .newlines) where !line.isEmpty {
            guard line.count >= 3 else { continue }

            let indexChar = line[line.startIndex]
            let workChar = line[line.index(after: line.startIndex)]
            let filePath = String(line.dropFirst(3))

            if indexChar == "?" {
                untracked.append(GitFileStatus(path: filePath, status: .untracked))
                continue
            }

            // Index status (staged)
            if let kind = Self.mapStatusChar(indexChar) {
                staged.append(GitFileStatus(path: filePath, status: kind))
            }

            // Worktree status (modified)
            if let kind = Self.mapStatusChar(workChar) {
                modified.append(GitFileStatus(path: filePath, status: kind))
            }
        }

        return GitStatus(staged: staged, modified: modified, untracked: untracked)
    }

    // MARK: - Staging & Committing

    func stage(files: [String]) throws {
        guard !files.isEmpty else { return }
        for file in files {
            try validatePathComponent(file)
        }
        try runGit(["add"] + files)
    }

    func commit(message: String, author: String, email: String) throws -> GitCommit {
        guard !message.isEmpty else {
            throw GitError.invalidArgument("Commit message cannot be empty")
        }
        try validateNoShellSpecials(author)
        try validateNoShellSpecials(email)

        let authorString = "\(author) <\(email)>"
        let output = try runGit([
            "commit",
            "-m", message,
            "--author", authorString,
        ])

        // Parse the commit SHA from the output (first line usually contains it).
        let sha = try currentHEAD()

        return GitCommit(
            sha: sha,
            message: message,
            author: author,
            date: Date(),
            parentSHAs: []
        )
    }

    // MARK: - Remote Operations

    func push(remote: String, branch: String, credentials: GitCredentials) async throws {
        try validateRefName(remote)
        try validateRefName(branch)

        let env = credentialEnvironment(for: credentials)
        let result = try await runGitAsync(
            ["push", remote, branch],
            at: try repoPath(),
            environment: env
        )

        if result.exitCode != 0 {
            throw GitError.pushFailed(result.stderr)
        }
    }

    func pull(remote: String, branch: String, credentials: GitCredentials) async throws {
        try validateRefName(remote)
        try validateRefName(branch)

        let env = credentialEnvironment(for: credentials)
        let result = try await runGitAsync(
            ["pull", remote, branch],
            at: try repoPath(),
            environment: env
        )

        if result.exitCode != 0 {
            throw GitError.pullFailed(result.stderr)
        }
    }

    // MARK: - Branches

    func branches() throws -> [GitBranch] {
        let output = try runGit([
            "branch", "-a",
            "--format=%(refname:short)\t%(objectname:short)\t%(HEAD)\t%(upstream:short)",
        ])

        return output.stdout
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { line -> GitBranch in
                let parts = line.components(separatedBy: "\t")
                let name = parts[safe: 0] ?? ""
                let isRemote = name.hasPrefix("remotes/") || name.contains("/")
                let isCurrent = (parts[safe: 2] ?? "") == "*"
                return GitBranch(
                    name: name,
                    isRemote: isRemote,
                    isCurrent: isCurrent,
                    lastCommit: nil
                )
            }
    }

    func createBranch(name: String, from source: String? = nil) throws {
        try validateRefName(name)

        var args = ["branch", name]
        if let source {
            try validateRefName(source)
            args.append(source)
        }
        try runGit(args)
    }

    func switchBranch(name: String) throws {
        try validateRefName(name)
        try runGit(["checkout", name])
    }

    func deleteBranch(name: String) throws {
        try validateRefName(name)
        try runGit(["branch", "-d", name])
    }

    // MARK: - Log

    func log(limit: Int = 50) throws -> [GitCommit] {
        let safeLimit = max(1, min(limit, 10_000))
        let output = try runGit([
            "log",
            "-n", String(safeLimit),
            "--format=%H%n%an%n%aI%n%P%n%s%n---END---",
        ])

        var commits: [GitCommit] = []
        let blocks = output.stdout.components(separatedBy: "---END---\n")

        for block in blocks {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let lines = trimmed.components(separatedBy: .newlines)
            guard lines.count >= 5 else { continue }

            let sha = lines[0]
            let author = lines[1]
            let dateString = lines[2]
            let parents = lines[3].components(separatedBy: " ").filter { !$0.isEmpty }
            let message = lines[4]

            let date = ISO8601DateFormatter().date(from: dateString) ?? Date()

            commits.append(GitCommit(
                sha: sha,
                message: message,
                author: author,
                date: date,
                parentSHAs: parents
            ))
        }

        return commits
    }

    // MARK: - Diff

    func diff(from: String, to: String) throws -> [GitDiff] {
        try validateRefName(from)
        try validateRefName(to)

        let output = try runGit(["diff", from, to, "--stat", "--numstat", "-p"])
        return parseDiffOutput(output.stdout)
    }

    // MARK: - Merge

    func mergeConflicts() throws -> [MergeConflict] {
        let output = try runGit(["diff", "--name-only", "--diff-filter=U"])
        let conflictedFiles = output.stdout
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }

        let repoDir = try repoPath()
        var conflicts: [MergeConflict] = []

        for file in conflictedFiles {
            let filePath = repoDir.appendingPathComponent(file)
            guard let content = try? String(contentsOf: filePath, encoding: .utf8) else {
                continue
            }

            let parsed = parseConflictMarkers(content: content, path: file)
            conflicts.append(contentsOf: parsed)
        }

        return conflicts
    }

    func merge(branch: String) throws -> MergeResult {
        try validateRefName(branch)

        let output = try runGitAllowingFailure(["merge", branch])

        if output.exitCode == 0 {
            return .success
        }

        // Check for merge conflicts specifically.
        if output.stdout.contains("CONFLICT") || output.stderr.contains("CONFLICT") {
            let conflicts = try mergeConflicts()
            return .conflicts(conflicts)
        }

        throw GitError.mergeFailed(output.stderr)
    }

    // MARK: - Private: Git CLI Execution

    private struct GitOutput {
        var stdout: String
        var stderr: String
        var exitCode: Int32
    }

    /// Run git synchronously (for fast local operations).
    @discardableResult
    private func runGit(
        _ arguments: [String],
        environment: [String: String]? = nil
    ) throws -> GitOutput {
        let path = try repoPath()
        let git = try resolveGitPath()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = arguments
        process.currentDirectoryURL = path

        // Build a minimal, safe environment to avoid leaking secrets or
        // unexpected variables into the child process.
        var safeEnv = Self.safeEnvironment()
        if let environment {
            safeEnv.merge(environment) { _, new in new }
        }
        process.environment = safeEnv

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw GitError.commandFailed(
                command: "git \(arguments.joined(separator: " "))",
                exitCode: process.terminationStatus,
                stderr: stderr
            )
        }

        return GitOutput(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
    }

    /// Run git allowing non-zero exit (used for merge which may have expected conflicts).
    private func runGitAllowingFailure(
        _ arguments: [String],
        environment: [String: String]? = nil
    ) throws -> GitOutput {
        let path = try repoPath()
        let git = try resolveGitPath()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = arguments
        process.currentDirectoryURL = path

        var safeEnv = Self.safeEnvironment()
        if let environment {
            safeEnv.merge(environment) { _, new in new }
        }
        process.environment = safeEnv

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return GitOutput(
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }

    /// Run git asynchronously (for clone, push, pull that may take time).
    private func runGitAsync(
        _ arguments: [String],
        at directory: URL,
        environment: [String: String]? = nil,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> GitOutput {
        let git = try resolveGitPath()

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: git)
            process.arguments = arguments
            process.currentDirectoryURL = directory

            var safeEnv = Self.safeEnvironment()
            if let environment {
                safeEnv.merge(environment) { _, new in new }
            }
            process.environment = safeEnv

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Read stderr for progress reporting (git writes progress to stderr).
            if let progressHandler {
                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty,
                          let text = String(data: data, encoding: .utf8)
                    else { return }

                    // Parse percentage from git progress lines like "Receiving objects:  45% ..."
                    if let range = text.range(of: #"\d+%"#, options: .regularExpression),
                       let pct = Double(text[range].dropLast())
                    {
                        progressHandler(pct / 100.0)
                    }
                }
            }

            process.terminationHandler = { proc in
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let output = GitOutput(
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    exitCode: proc.terminationStatus
                )
                continuation.resume(returning: output)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Private: Helpers

    private func repoPath() throws -> URL {
        guard let path = repositoryPath else {
            throw GitError.repositoryNotOpen
        }
        return path
    }

    private func resolveGitPath() throws -> String {
        if let cached = gitPath { return cached }

        // Check common locations.
        let candidates = [
            "/usr/bin/git",
            "/usr/local/bin/git",
            "/opt/homebrew/bin/git",
        ]

        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                gitPath = candidate
                return candidate
            }
        }

        throw GitError.gitNotFound
    }

    private func currentHEAD() throws -> String {
        let output = try runGit(["rev-parse", "HEAD"])
        return output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Build environment variables that inject credentials via GIT_ASKPASS.
    private func credentialEnvironment(for credentials: GitCredentials) -> [String: String] {
        // Use a credential helper approach: set the token as a header for HTTPS.
        return [
            "GIT_TERMINAL_PROMPT": "0",
            "GIT_ASKPASS": "/bin/echo",
            "GIT_CONFIG_COUNT": "1",
            "GIT_CONFIG_KEY_0": "http.extraHeader",
            "GIT_CONFIG_VALUE_0": "Authorization: token \(credentials.token)",
        ]
    }

    // MARK: - Private: Safe Environment

    /// Returns a minimal environment dictionary for child processes to avoid
    /// leaking secrets or configuration from the parent environment.
    private static func safeEnvironment() -> [String: String] {
        var env: [String: String] = [:]
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            env["PATH"] = path
        }
        if let home = ProcessInfo.processInfo.environment["HOME"] {
            env["HOME"] = home
        }
        if let lang = ProcessInfo.processInfo.environment["LANG"] {
            env["LANG"] = lang
        }
        return env
    }

    // MARK: - Private: Input Validation (command injection prevention)

    private func validateURL(_ urlString: String) throws {
        // Reject shell metacharacters and ensure it looks like a URL.
        guard let url = URL(string: urlString),
              url.scheme == "https" || url.scheme == "http" || url.scheme == "ssh" || url.scheme == "git"
        else {
            throw GitError.invalidArgument("Invalid repository URL: \(urlString)")
        }
    }

    private func validateRefName(_ name: String) throws {
        // Git ref names: alphanumeric, -, _, /, .  No shell specials.
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_/.@"))
        guard !name.isEmpty,
              name.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              !name.contains("..")
        else {
            throw GitError.invalidArgument("Invalid ref name: \(name)")
        }
    }

    private func validatePathComponent(_ path: String) throws {
        // Reject absolute paths, traversal, and null bytes.
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.contains("\0"),
              !path.contains(".."),
              !path.contains(";"),
              !path.contains("$("),
              !path.contains("`")
        else {
            throw GitError.invalidArgument("Invalid file path: \(path)")
        }
    }

    private func validateNoShellSpecials(_ value: String) throws {
        let forbidden: [Character] = [";", "|", "&", "$", "`", "(", ")", "{", "}", "\0"]
        for ch in forbidden {
            if value.contains(ch) {
                throw GitError.invalidArgument("Value contains forbidden character: \(ch)")
            }
        }
    }

    // MARK: - Private: Parsing

    private static func mapStatusChar(_ char: Character) -> GitFileStatus.FileStatusKind? {
        switch char {
        case "A": return .added
        case "M": return .modified
        case "D": return .deleted
        case "R": return .renamed
        case " ", "?": return nil
        default: return .modified
        }
    }

    private func parseDiffOutput(_ output: String) -> [GitDiff] {
        // Simplified parser: split by "diff --git" headers.
        let fileSections = output.components(separatedBy: "diff --git ")
            .dropFirst() // first element is empty or stats

        return fileSections.map { section in
            var hunks: [DiffHunk] = []
            var additions = 0
            var deletions = 0

            let hunkPattern = #"@@ -(\d+),?(\d*) \+(\d+),?(\d*) @@"#
            let regex = try? NSRegularExpression(pattern: hunkPattern)
            let lines = section.components(separatedBy: .newlines)

            var currentHunk: DiffHunk?
            for line in lines {
                let nsLine = line as NSString
                if let match = regex?.firstMatch(
                    in: line, range: NSRange(location: 0, length: nsLine.length)
                ) {
                    // Save previous hunk.
                    if let hunk = currentHunk { hunks.append(hunk) }

                    let oldStart = Int(nsLine.substring(with: match.range(at: 1))) ?? 0
                    let oldCount = Int(nsLine.substring(with: match.range(at: 2))) ?? 1
                    let newStart = Int(nsLine.substring(with: match.range(at: 3))) ?? 0
                    let newCount = Int(nsLine.substring(with: match.range(at: 4))) ?? 1

                    currentHunk = DiffHunk(
                        oldStart: oldStart, oldCount: oldCount,
                        newStart: newStart, newCount: newCount,
                        lines: []
                    )
                } else if line.hasPrefix("+") && !line.hasPrefix("+++") {
                    additions += 1
                    currentHunk?.lines.append(
                        DiffLine(type: .addition, content: String(line.dropFirst()))
                    )
                } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                    deletions += 1
                    currentHunk?.lines.append(
                        DiffLine(type: .deletion, content: String(line.dropFirst()))
                    )
                } else if currentHunk != nil {
                    currentHunk?.lines.append(
                        DiffLine(type: .context, content: line)
                    )
                }
            }
            if let hunk = currentHunk { hunks.append(hunk) }

            return GitDiff(
                hunks: hunks,
                stats: DiffStats(additions: additions, deletions: deletions, filesChanged: 1)
            )
        }
    }

    private func parseConflictMarkers(content: String, path: String) -> [MergeConflict] {
        // Parse standard Git conflict markers.
        var conflicts: [MergeConflict] = []
        let lines = content.components(separatedBy: .newlines)

        var oursLines: [String] = []
        var theirsLines: [String] = []
        var baseLines: [String] = []
        var inConflict = false
        var inOurs = false
        var inTheirs = false
        var conflictIndex = 0

        for line in lines {
            if line.hasPrefix("<<<<<<<") {
                inConflict = true
                inOurs = true
                inTheirs = false
                oursLines = []
                theirsLines = []
                baseLines = []
            } else if line.hasPrefix("|||||||") {
                // diff3 base section
                inOurs = false
            } else if line.hasPrefix("=======") {
                inOurs = false
                inTheirs = true
            } else if line.hasPrefix(">>>>>>>") {
                inConflict = false
                inTheirs = false
                conflicts.append(MergeConflict(
                    path: conflictIndex > 0 ? "\(path)#\(conflictIndex)" : path,
                    baseContent: baseLines.joined(separator: "\n"),
                    oursContent: oursLines.joined(separator: "\n"),
                    theirsContent: theirsLines.joined(separator: "\n")
                ))
                conflictIndex += 1
            } else if inConflict {
                if inOurs {
                    oursLines.append(line)
                } else if inTheirs {
                    theirsLines.append(line)
                } else {
                    baseLines.append(line)
                }
            }
        }

        return conflicts
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
