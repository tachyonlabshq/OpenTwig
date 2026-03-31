import Foundation

// MARK: - Errors

enum ProjectError: LocalizedError, Sendable {
    case directoryAlreadyExists(URL)
    case directoryNotFound(URL)
    case notAGitRepository(URL)
    case documentNotFound(String)
    case saveFailed(String)
    case loadFailed(String)
    case invalidProjectStructure(String)

    var errorDescription: String? {
        switch self {
        case .directoryAlreadyExists(let url):
            return "Directory already exists at \(url.path)"
        case .directoryNotFound(let url):
            return "Directory not found: \(url.path)"
        case .notAGitRepository(let url):
            return "\(url.path) is not a Git repository"
        case .documentNotFound(let path):
            return "Document not found: \(path)"
        case .saveFailed(let msg):
            return "Failed to save: \(msg)"
        case .loadFailed(let msg):
            return "Failed to load: \(msg)"
        case .invalidProjectStructure(let msg):
            return "Invalid project structure: \(msg)"
        }
    }
}

// MARK: - ProjectService

actor ProjectService {

    private let gitService: GitService
    private let fileManager = FileManager.default

    // Supported document extensions for auto-discovery.
    private static let documentExtensions: Set<String> = [
        "md", "markdown", "tex", "txt", "bib", "yaml", "yml", "json",
    ]

    private static let recentProjectsKey = "recentProjects"

    init(gitService: GitService = GitService()) {
        self.gitService = gitService
    }

    // MARK: - Project Lifecycle

    /// Create a new project with a fresh Git repository.
    func createProject(name: String, at parentDirectory: URL) async throws -> Project {
        let projectDir = parentDirectory.appendingPathComponent(name)

        guard !fileManager.fileExists(atPath: projectDir.path) else {
            throw ProjectError.directoryAlreadyExists(projectDir)
        }

        // Create directory structure.
        try fileManager.createDirectory(at: projectDir, withIntermediateDirectories: true)

        // Initialize a Git repository.
        let git = try resolveGitPath()
        try runProcess(
            executable: git,
            arguments: ["init"],
            at: projectDir
        )

        // Create a starter document.
        let readmePath = projectDir.appendingPathComponent("README.md")
        let starterContent = "# \(name)\n\nA new OpenTwig academic project.\n"
        try starterContent.write(to: readmePath, atomically: true, encoding: .utf8)

        // Stage and commit.
        try runProcess(executable: git, arguments: ["add", "."], at: projectDir)
        try runProcess(
            executable: git,
            arguments: ["commit", "-m", "Initial commit"],
            at: projectDir
        )

        // Open the repository in the Git service.
        try await gitService.open(at: projectDir)

        let project = Project(
            name: name,
            localPath: projectDir,
            remoteURL: "",
            currentBranch: "main",
            description: "",
            status: .ready
        )

        appendToRecentProjects(project)
        return project
    }

    /// Clone a remote repository as a new project.
    func cloneProject(
        url: String,
        to destination: URL,
        credentials: GitCredentials
    ) async throws -> Project {
        let clonedPath = try await gitService.clone(url: url, to: destination)

        try await gitService.open(at: clonedPath)

        // Derive the project name from the directory.
        let name = clonedPath.lastPathComponent
            .replacingOccurrences(of: ".git", with: "")

        let project = Project(
            name: name,
            localPath: clonedPath,
            remoteURL: url,
            currentBranch: "main",
            status: .ready
        )

        appendToRecentProjects(project)
        return project
    }

    /// Open an existing local project.
    func openProject(at path: URL) async throws -> Project {
        guard fileManager.fileExists(atPath: path.path) else {
            throw ProjectError.directoryNotFound(path)
        }

        guard fileManager.fileExists(
            atPath: path.appendingPathComponent(".git").path
        ) else {
            throw ProjectError.notAGitRepository(path)
        }

        try await gitService.open(at: path)

        // Read the remote URL if available.
        let remoteURL: String
        do {
            let git = try resolveGitPath()
            let output = try runProcess(
                executable: git,
                arguments: ["remote", "get-url", "origin"],
                at: path
            )
            remoteURL = output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            remoteURL = ""
        }

        // Read the current branch.
        let currentBranch: String
        do {
            let git = try resolveGitPath()
            let output = try runProcess(
                executable: git,
                arguments: ["rev-parse", "--abbrev-ref", "HEAD"],
                at: path
            )
            currentBranch = output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            currentBranch = "main"
        }

        let project = Project(
            name: path.lastPathComponent,
            localPath: path,
            remoteURL: remoteURL,
            currentBranch: currentBranch,
            lastOpenedAt: .now,
            status: .ready
        )

        appendToRecentProjects(project)
        return project
    }

    // MARK: - Document Management

    /// Load all documents from the project directory (non-recursive into .git or hidden dirs).
    func loadDocuments(for project: Project) throws -> [Document] {
        guard let projectPath = project.localPath else {
            throw ProjectError.directoryNotFound(URL(fileURLWithPath: "/"))
        }

        var documents: [Document] = []

        let enumerator = fileManager.enumerator(
            at: projectPath,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            // Skip .git directory and other hidden paths.
            if fileURL.pathComponents.contains(where: { $0.hasPrefix(".") }) {
                continue
            }

            let ext = fileURL.pathExtension.lowercased()
            guard Self.documentExtensions.contains(ext) else { continue }

            guard let resourceValues = try? fileURL.resourceValues(
                forKeys: [.isRegularFileKey, .contentModificationDateKey]
            ),
                  resourceValues.isRegularFile == true
            else { continue }

            let relativePath = fileURL.path
                .replacingOccurrences(of: projectPath.path + "/", with: "")

            let content: String
            do {
                content = try String(contentsOf: fileURL, encoding: .utf8)
            } catch {
                continue // Skip files that can't be read as UTF-8.
            }

            let document = Document(
                filename: fileURL.lastPathComponent,
                relativePath: relativePath,
                content: content,
                lastModified: resourceValues.contentModificationDate ?? Date(),
                isModified: false
            )

            documents.append(document)
        }

        return documents.sorted { $0.relativePath < $1.relativePath }
    }

    /// Save a document back to disk.
    func saveDocument(_ document: Document) throws {
        // The document's relativePath must be resolved against an open project.
        // For safety, we require a valid relativePath that doesn't escape the project.
        guard !document.relativePath.isEmpty,
              !document.relativePath.contains(".."),
              !document.relativePath.hasPrefix("/")
        else {
            throw ProjectError.saveFailed("Invalid document path: \(document.relativePath)")
        }

        // We need the repo path from gitService; since we can't access it directly,
        // the caller should provide absolute paths via a project reference.
        // For now, this requires the document content to be written by the caller
        // with a known base path.
        throw ProjectError.saveFailed(
            "Use saveDocument(_:in:) with a project reference for path resolution"
        )
    }

    /// Save a document within the context of a specific project.
    func saveDocument(_ document: Document, in project: Project) throws {
        guard let projectPath = project.localPath else {
            throw ProjectError.saveFailed("Project has no local path")
        }

        guard !document.relativePath.isEmpty,
              !document.relativePath.contains(".."),
              !document.relativePath.hasPrefix("/"),
              !document.relativePath.contains("\0")
        else {
            throw ProjectError.saveFailed("Invalid document path: \(document.relativePath)")
        }

        let fileURL = projectPath.appendingPathComponent(document.relativePath)

        // Verify the resolved path is still within the project directory
        // (defense-in-depth against symlink traversal or encoding tricks).
        let resolvedProject = projectPath.standardizedFileURL.path
        let resolvedFile = fileURL.standardizedFileURL.path
        guard resolvedFile.hasPrefix(resolvedProject + "/") || resolvedFile == resolvedProject else {
            throw ProjectError.saveFailed("Path escapes project directory: \(document.relativePath)")
        }

        // Ensure parent directory exists.
        let parentDir = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        do {
            try document.content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw ProjectError.saveFailed(error.localizedDescription)
        }
    }

    /// Delete a document from the project.
    func deleteDocument(_ document: Document, in project: Project) throws {
        guard let projectPath = project.localPath else {
            throw ProjectError.saveFailed("Project has no local path")
        }

        guard !document.relativePath.isEmpty,
              !document.relativePath.contains(".."),
              !document.relativePath.hasPrefix("/"),
              !document.relativePath.contains("\0")
        else {
            throw ProjectError.saveFailed("Invalid document path: \(document.relativePath)")
        }

        let fileURL = projectPath.appendingPathComponent(document.relativePath)

        // Verify the resolved path is still within the project directory.
        let resolvedProject = projectPath.standardizedFileURL.path
        let resolvedFile = fileURL.standardizedFileURL.path
        guard resolvedFile.hasPrefix(resolvedProject + "/") || resolvedFile == resolvedProject else {
            throw ProjectError.saveFailed("Path escapes project directory: \(document.relativePath)")
        }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw ProjectError.documentNotFound(document.relativePath)
        }

        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw ProjectError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Recent Projects

    func loadRecentProjects() -> [Project] {
        guard let data = UserDefaults.standard.data(forKey: Self.recentProjectsKey) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode([Project].self, from: data)
        } catch {
            return []
        }
    }

    func saveRecentProjects(_ projects: [Project]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(projects)
            UserDefaults.standard.set(data, forKey: Self.recentProjectsKey)
        } catch {
            // Silently fail for recent projects persistence.
        }
    }

    // MARK: - Private Helpers

    private func appendToRecentProjects(_ project: Project) {
        var recent = loadRecentProjects()

        // Remove existing entry with same path.
        recent.removeAll { $0.localPath == project.localPath }

        // Prepend the new project.
        recent.insert(project, at: 0)

        // Keep only the last 20.
        if recent.count > 20 {
            recent = Array(recent.prefix(20))
        }

        saveRecentProjects(recent)
    }

    private func resolveGitPath() throws -> String {
        let candidates = [
            "/usr/bin/git",
            "/usr/local/bin/git",
            "/opt/homebrew/bin/git",
        ]

        for candidate in candidates {
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        throw GitError.gitNotFound
    }

    @discardableResult
    private func runProcess(
        executable: String,
        arguments: [String],
        at directory: URL
    ) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory

        // Use a minimal environment to avoid leaking secrets or unexpected
        // variables into the child process.
        var safeEnv: [String: String] = [:]
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            safeEnv["PATH"] = path
        }
        if let home = ProcessInfo.processInfo.environment["HOME"] {
            safeEnv["HOME"] = home
        }
        if let lang = ProcessInfo.processInfo.environment["LANG"] {
            safeEnv["LANG"] = lang
        }
        process.environment = safeEnv

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
