import Foundation
import Observation

// MARK: - GitService Protocol

/// Thin protocol so the ViewModel can be tested with a mock.
/// A concrete implementation backed by `ProcessRunner` would live in Services/.
protocol GitServiceProtocol: Sendable {
    func branches(in directory: URL) async throws -> [GitBranch]
    func log(in directory: URL, limit: Int) async throws -> [GitCommit]
    func status(in directory: URL) async throws -> GitStatus
    func commit(message: String, files: [String], in directory: URL) async throws
    func push(in directory: URL) async throws
    func pull(in directory: URL) async throws
    func createBranch(name: String, in directory: URL) async throws
    func switchBranch(name: String, in directory: URL) async throws
    func merge(branch: String, in directory: URL) async throws
}

// MARK: - GitViewModel

/// Drives all Git-related UI: branch listing, commit history, staging, and
/// remote operations. Delegates actual Git execution to a `GitServiceProtocol`.
@MainActor
@Observable
final class GitViewModel {

    // MARK: - Published State

    var branches: [GitBranch] = []
    var commits: [GitCommit] = []
    var status: GitStatus?
    var isLoading: Bool = false
    var error: String?
    var commitMessage: String = ""
    var selectedFiles: Set<String> = []

    // MARK: - Dependencies

    private let gitService: GitServiceProtocol
    private let workingDirectory: () -> URL?

    // MARK: - Init

    /// - Parameters:
    ///   - gitService: The service that actually runs Git commands.
    ///   - workingDirectory: Closure returning the current project's local path.
    init(gitService: GitServiceProtocol, workingDirectory: @escaping () -> URL?) {
        self.gitService = gitService
        self.workingDirectory = workingDirectory
    }

    // MARK: - Actions

    /// Refreshes branches, commits, and working-tree status in parallel.
    func refresh() {
        guard let directory = workingDirectory() else { return }
        isLoading = true
        error = nil

        Task {
            do {
                async let fetchedBranches = gitService.branches(in: directory)
                async let fetchedCommits = gitService.log(in: directory, limit: 50)
                async let fetchedStatus = gitService.status(in: directory)

                branches = try await fetchedBranches
                commits = try await fetchedCommits
                status = try await fetchedStatus
                isLoading = false
            } catch {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    /// Commits the selected (staged) files with the current commit message.
    func commit() {
        guard let directory = workingDirectory() else { return }
        let message = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            error = "Commit message cannot be empty."
            return
        }
        guard !selectedFiles.isEmpty else {
            error = "No files selected for commit."
            return
        }

        isLoading = true
        error = nil

        Task {
            do {
                try await gitService.commit(
                    message: message,
                    files: Array(selectedFiles),
                    in: directory
                )
                commitMessage = ""
                selectedFiles = []
                refresh()
            } catch {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    /// Pushes the current branch to the remote.
    func push() {
        guard let directory = workingDirectory() else { return }
        performRemoteOperation { [gitService] in
            try await gitService.push(in: directory)
        }
    }

    /// Pulls the latest changes from the remote.
    func pull() {
        guard let directory = workingDirectory() else { return }
        performRemoteOperation { [gitService] in
            try await gitService.pull(in: directory)
        }
    }

    /// Creates a new local branch and switches to it.
    func createBranch(name: String) {
        guard let directory = workingDirectory() else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "Branch name cannot be empty."
            return
        }

        performRemoteOperation { [gitService] in
            try await gitService.createBranch(name: trimmed, in: directory)
        }
    }

    /// Switches to an existing branch.
    func switchBranch(name: String) {
        guard let directory = workingDirectory() else { return }
        performRemoteOperation { [gitService] in
            try await gitService.switchBranch(name: name, in: directory)
        }
    }

    /// Merges the given branch into the current branch.
    func merge(branch: String) {
        guard let directory = workingDirectory() else { return }
        performRemoteOperation { [gitService] in
            try await gitService.merge(branch: branch, in: directory)
        }
    }

    // MARK: - Private

    /// Shared pattern for remote operations: set loading, run, refresh on success.
    private func performRemoteOperation(_ operation: @escaping @Sendable () async throws -> Void) {
        isLoading = true
        error = nil

        Task {
            do {
                try await operation()
                refresh()
            } catch {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
}
