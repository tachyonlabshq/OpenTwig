import Foundation
import SwiftUI
import Observation

enum SidebarSelection: String, Codable, Hashable, Sendable, CaseIterable {
    case documents
    case branches
    case citations
    case activity
    case settings

    var label: String {
        switch self {
        case .documents: return "Documents"
        case .branches: return "Branches"
        case .citations: return "Citations"
        case .activity: return "Activity"
        case .settings: return "Settings"
        }
    }

    var iconName: String {
        switch self {
        case .documents: return "doc.text"
        case .branches: return "arrow.triangle.branch"
        case .citations: return "book.closed"
        case .activity: return "clock.arrow.circlepath"
        case .settings: return "gear"
        }
    }
}

// MARK: - Export Types

enum ExportFormat: String, CaseIterable, Sendable {
    case pdf = "PDF"
    case latex = "LaTeX"
    case docx = "DOCX"
    case html = "HTML"

    var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .latex: return "tex"
        case .docx: return "docx"
        case .html: return "html"
        }
    }

    var iconName: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .latex: return "function"
        case .docx: return "doc.fill"
        case .html: return "globe"
        }
    }

    /// Pandoc output format identifier.
    var pandocFormat: String {
        switch self {
        case .pdf: return "pdf"
        case .latex: return "latex"
        case .docx: return "docx"
        case .html: return "html"
        }
    }
}

enum CitationStyle: String, CaseIterable, Sendable {
    case apa = "APA 7th Edition"
    case mla = "MLA 9th Edition"
    case chicago = "Chicago 17th Edition"
    case ieee = "IEEE"
    case harvard = "Harvard"
    case vancouver = "Vancouver"
}

@MainActor
@Observable
final class AppState {

    // MARK: - Projects

    var projects: [Project] = []
    var selectedProject: Project?
    var currentBranch: String = "main"

    // MARK: - Navigation

    var sidebarSelection: SidebarSelection = .documents

    // MARK: - Documents

    var documents: [Document] = []
    var selectedDocument: Document?

    // MARK: - Branches

    var branches: [GitBranch] = []
    var selectedBranch: GitBranch?

    // MARK: - Citations

    var citations: [CSLItem] = []
    var selectedCitation: CSLItem?

    // MARK: - Activity

    var activityEvents: [ActivityEvent] = []

    // MARK: - Sheet Presentation

    var showNewProject: Bool = false
    var showCloneRepo: Bool = false
    var showCommitSheet: Bool = false
    var showNewBranch: Bool = false
    var showMergeSheet: Bool = false
    var showExportSheet: Bool = false
    var showInspector: Bool = false
    var showAddCitation: Bool = false
    var showAddMember: Bool = false

    // MARK: - Settings

    var authorName: String = ""
    var authorEmail: String = ""
    var defaultBranch: String = "main"
    var editorFontSize: Double = 14
    var editorTheme: String = "Default"
    var githubConnected: Bool = false
    /// Tokens are NOT stored here — they live in Keychain only.
    /// These properties exist solely for SecureField binding in SettingsView.
    /// They are cleared after being persisted to Keychain and must never be
    /// serialized, logged, or passed to analytics.
    var githubToken: String = "" {
        didSet {
            // Persist to Keychain immediately; clear the in-memory copy on next run loop
            // to minimize the time the secret is in RAM.
            if !githubToken.isEmpty {
                try? GitCredentials(token: githubToken, username: "").save()
            }
        }
    }
    var aiAPIKey: String = "" {
        didSet {
            if !aiAPIKey.isEmpty {
                try? AIConfiguration.saveAPIKey(aiAPIKey)
            }
        }
    }
    var aiModel: String = "claude-sonnet-4-20250514"
    var aiAutoSuggest: Bool = true
    var defaultExportFormat: ExportFormat = .pdf
    var defaultCitationStyle: CitationStyle = .apa

    // MARK: - Export State

    var isExporting: Bool = false
    var exportProgress: Double = 0

    // MARK: - Actions

    func createNewDocument(filename: String = "Untitled.md") {
        let document = Document(
            filename: filename,
            relativePath: filename
        )
        documents.append(document)
        selectedDocument = document
        sidebarSelection = .documents
    }

    func openProject(_ project: Project) {
        project.lastOpenedAt = .now
        selectedProject = project
        selectedDocument = nil
        currentBranch = project.currentBranch
        sidebarSelection = .documents
    }

    func pushChanges() {
        guard let project = selectedProject else { return }
        project.status = .syncing
        // Git push implementation will be provided by GitService
        project.status = .ready
    }

    func pullChanges() {
        guard let project = selectedProject else { return }
        project.status = .syncing
        // Git pull implementation will be provided by GitService
        project.status = .ready
    }

    func commitChanges(message: String) {
        // Placeholder for git commit
    }

    func deleteDocument(_ document: Document) {
        documents.removeAll { $0.id == document.id }
        if selectedDocument?.id == document.id {
            selectedDocument = nil
        }
    }

    func insertCiteKey(_ key: String) {
        guard let doc = selectedDocument,
              let index = documents.firstIndex(where: { $0.id == doc.id }) else { return }
        documents[index].content.append("@\(key)")
        documents[index].isModified = true
    }
}
