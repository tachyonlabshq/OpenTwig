import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        List(selection: $appState.sidebarSelection) {
            projectPickerSection

            Section("Workspace") {
                ForEach(SidebarSelection.allCases, id: \.self) { section in
                    Label(section.label, systemImage: section.iconName)
                        .tag(section)
                }
            }
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
                if !appState.projects.isEmpty {
                    ForEach(appState.projects) { project in
                        Button {
                            appState.openProject(project)
                        } label: {
                            Label(
                                project.name,
                                systemImage: project.id == appState.selectedProject?.id
                                    ? "checkmark.circle.fill" : "folder"
                            )
                        }
                    }

                    Divider()
                }

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
                HStack(spacing: 10) {
                    Image(systemName: "folder.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)

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
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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

    // MARK: - Git Status Bar

    private var gitStatusBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text(appState.selectedProject?.currentBranch ?? "main")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                syncStatusBadge
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(.windowBackgroundColor))
        }
    }

    private var syncStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(syncStatusColor)
                .frame(width: 6, height: 6)
            Text(syncStatusLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var syncStatusColor: Color {
        switch appState.selectedProject?.status {
        case .ready: return .green
        case .syncing: return .blue
        case .cloning: return .orange
        case .error: return .red
        case nil: return .gray
        }
    }

    private var syncStatusLabel: String {
        switch appState.selectedProject?.status {
        case .ready: return "Up to date"
        case .syncing: return "Syncing..."
        case .cloning: return "Cloning..."
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
