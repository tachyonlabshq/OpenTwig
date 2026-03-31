import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        List(selection: $appState.sidebarSelection) {
            projectPickerSection
            navigationSections
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            gitStatusBar
        }
        .navigationTitle("OpenTwig")
    }

    // MARK: - Project Picker

    private var projectPickerSection: some View {
        Section {
            Menu {
                ForEach(appState.projects) { project in
                    Button {
                        appState.openProject(project)
                    } label: {
                        Label(
                            project.name,
                            systemImage: project.id == appState.selectedProject?.id
                                ? "checkmark" : "folder"
                        )
                    }
                }

                Divider()

                Button {
                    appState.showNewProject = true
                } label: {
                    Label("New Project...", systemImage: "plus")
                }

                Button {
                    appState.showCloneRepo = true
                } label: {
                    Label("Clone Repository...", systemImage: "arrow.down.doc")
                }
            } label: {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.selectedProject?.name ?? "No Project")
                            .font(.headline)
                            .lineLimit(1)
                        if let project = appState.selectedProject {
                            statusLabel(for: project.status)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func statusLabel(for status: ProjectStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor(for: status))
                .frame(width: 6, height: 6)
            Text(status.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func statusColor(for status: ProjectStatus) -> Color {
        switch status {
        case .ready: return .green
        case .syncing: return .blue
        case .cloning: return .orange
        case .error: return .red
        }
    }

    // MARK: - Navigation Sections

    private var navigationSections: some View {
        Section("Navigation") {
            ForEach(SidebarSelection.allCases, id: \.self) { section in
                NavigationLink(value: section) {
                    Label(section.label, systemImage: section.iconName)
                }
            }
        }
    }

    // MARK: - Git Status Bar

    private var gitStatusBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(appState.selectedProject?.currentBranch ?? "main")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(syncStatusColor)
                        .frame(width: 6, height: 6)
                    Text(syncStatusLabel)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.controlBackgroundColor))
        }
    }

    private var syncStatusColor: Color {
        switch appState.selectedProject?.status {
        case .ready: return .green
        case .syncing: return .blue
        case .cloning: return .orange
        case .error: return .red
        case nil: return .secondary
        }
    }

    private var syncStatusLabel: String {
        switch appState.selectedProject?.status {
        case .ready: return "Up to date"
        case .syncing: return "Syncing"
        case .cloning: return "Cloning"
        case .error: return "Error"
        case nil: return "No project"
        }
    }
}

#Preview {
    NavigationSplitView {
        SidebarView()
            .environment(AppState())
    } detail: {
        Text("Detail")
    }
    .frame(width: 300, height: 600)
}
