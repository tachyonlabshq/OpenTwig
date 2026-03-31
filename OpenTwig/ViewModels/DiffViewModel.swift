import Foundation
import Observation

// MARK: - Display Mode

enum DiffDisplayMode: String, Sendable, CaseIterable {
    case unified
    case sideBySide
}

// MARK: - Diff Service Protocol

/// Abstraction for computing diffs, allowing test doubles.
protocol DiffServiceProtocol: Sendable {
    func diff(from base: String, to head: String, in directory: URL) async throws -> [GitDiff]
    func requestAISuggestion(for conflict: MergeConflict) async throws -> AISuggestion
}

// MARK: - DiffViewModel

/// Drives the diff viewer and AI-assisted merge conflict resolution UI.
@MainActor
@Observable
final class DiffViewModel {

    // MARK: - State

    var diffs: [GitDiff] = []
    var displayMode: DiffDisplayMode = .unified
    var conflicts: [MergeConflict] = []
    var aiSuggestions: [AISuggestion] = []
    var isLoadingAI: Bool = false
    var error: String?

    // MARK: - Dependencies

    private let diffService: DiffServiceProtocol?
    private let workingDirectory: () -> URL?

    // MARK: - Init

    init(diffService: DiffServiceProtocol? = nil, workingDirectory: @escaping () -> URL? = { nil }) {
        self.diffService = diffService
        self.workingDirectory = workingDirectory
    }

    // MARK: - Diff Loading

    /// Loads the diff between two revisions (commit SHAs, branch names, etc.).
    func loadDiff(from base: String, to head: String) {
        guard let service = diffService,
              let directory = workingDirectory() else { return }

        error = nil

        Task {
            do {
                diffs = try await service.diff(from: base, to: head, in: directory)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - AI Conflict Resolution

    /// Requests an AI-generated suggestion for resolving a merge conflict.
    func requestAISuggestion(for conflict: MergeConflict) {
        guard let service = diffService else { return }
        isLoadingAI = true
        error = nil

        Task {
            do {
                let suggestion = try await service.requestAISuggestion(for: conflict)
                aiSuggestions.append(suggestion)
                isLoadingAI = false
            } catch {
                self.error = error.localizedDescription
                isLoadingAI = false
            }
        }
    }

    /// Marks a suggestion as accepted and removes the corresponding conflict.
    func acceptSuggestion(_ suggestion: AISuggestion) {
        guard let index = aiSuggestions.firstIndex(where: { $0.id == suggestion.id }) else { return }
        aiSuggestions[index] = AISuggestion(
            id: suggestion.id,
            conflictPath: suggestion.conflictPath,
            strategy: suggestion.strategy,
            resolvedText: suggestion.resolvedText,
            reasoning: suggestion.reasoning,
            confidence: suggestion.confidence,
            citationsAffected: suggestion.citationsAffected,
            warnings: suggestion.warnings,
            status: .accepted,
            createdAt: suggestion.createdAt
        )
        conflicts.removeAll { $0.path == suggestion.conflictPath }
    }

    /// Marks a suggestion as rejected. The conflict remains for manual resolution.
    func rejectSuggestion(_ suggestion: AISuggestion) {
        guard let index = aiSuggestions.firstIndex(where: { $0.id == suggestion.id }) else { return }
        aiSuggestions[index] = AISuggestion(
            id: suggestion.id,
            conflictPath: suggestion.conflictPath,
            strategy: suggestion.strategy,
            resolvedText: suggestion.resolvedText,
            reasoning: suggestion.reasoning,
            confidence: suggestion.confidence,
            citationsAffected: suggestion.citationsAffected,
            warnings: suggestion.warnings,
            status: .rejected,
            createdAt: suggestion.createdAt
        )
    }
}
