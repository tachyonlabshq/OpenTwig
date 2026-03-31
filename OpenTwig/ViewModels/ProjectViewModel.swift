import Foundation
import Observation

// MARK: - Sync Status

enum SyncStatus: Equatable, Sendable {
    case idle
    case syncing
    case error(String)
    case upToDate
}

// MARK: - ProjectViewModel

/// Manages the lifecycle of a project: opening, document listing, creation,
/// deletion, and sync-status tracking.
@MainActor
@Observable
final class ProjectViewModel {

    // MARK: - State

    var project: Project?
    var documents: [Document] = []
    var isLoading: Bool = false
    var syncStatus: SyncStatus = .idle

    // MARK: - Project Lifecycle

    /// Opens a project, reads its document tree from disk, and updates state.
    func open(project: Project) {
        self.project = project
        syncStatus = .idle
        refresh()
    }

    /// Re-scans the project directory for Markdown documents.
    func refresh() {
        guard let project, let localPath = project.localPath else { return }
        isLoading = true

        Task {
            do {
                let found = try await scanDocuments(in: localPath)
                documents = found
                isLoading = false
                syncStatus = .upToDate
            } catch {
                syncStatus = .error(error.localizedDescription)
                isLoading = false
            }
        }
    }

    /// Creates a new Markdown document in the project directory.
    func createDocument(name: String) {
        guard let project, let localPath = project.localPath else { return }
        let sanitized = sanitizeFilename(name)
        let filename = sanitized.hasSuffix(".md") ? sanitized : "\(sanitized).md"
        let fileURL = localPath.appendingPathComponent(filename)

        // Avoid overwriting existing files.
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let frontMatter = """
            ---
            title: "\(sanitized.replacingOccurrences(of: ".md", with: ""))"
            date: \(ISO8601DateFormatter().string(from: .now))
            ---


            """
            try frontMatter.write(to: fileURL, atomically: true, encoding: .utf8)

            let document = Document(
                filename: filename,
                relativePath: filename,
                content: frontMatter,
                lastModified: .now
            )
            documents.append(document)
        } catch {
            syncStatus = .error("Failed to create document: \(error.localizedDescription)")
        }
    }

    /// Deletes a document from both the in-memory list and disk.
    func deleteDocument(_ document: Document) {
        guard let project, let localPath = project.localPath else { return }
        let fileURL = localPath.appendingPathComponent(document.relativePath)

        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            documents.removeAll { $0.id == document.id }
        } catch {
            syncStatus = .error("Failed to delete document: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    /// Recursively scans for `.md` files under the given directory.
    private func scanDocuments(in directory: URL) async throws -> [Document] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var results: [Document] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "md" else { continue }

            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])
            guard resourceValues.isRegularFile == true else { continue }

            let relativePath = fileURL.path.replacingOccurrences(
                of: directory.path + "/",
                with: ""
            )
            let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            let modified = resourceValues.contentModificationDate ?? .now

            results.append(Document(
                filename: fileURL.lastPathComponent,
                relativePath: relativePath,
                content: content,
                lastModified: modified
            ))
        }

        return results.sorted { $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedAscending }
    }

    /// Strips characters that are unsafe for filenames.
    private func sanitizeFilename(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name.components(separatedBy: illegal).joined()
    }
}
