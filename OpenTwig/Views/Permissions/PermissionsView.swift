import SwiftUI

struct PermissionsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedMemberID: UUID?
    @State private var showAddMember: Bool = false
    @State private var newMemberName: String = ""
    @State private var newMemberEmail: String = ""
    @State private var newMemberRole: ProjectRole = .viewer

    private var members: [ProjectMember] {
        appState.selectedProject?.members ?? []
    }

    var body: some View {
        HSplitView {
            memberTable
                .frame(minWidth: 400)

            if let member = selectedMember {
                permissionDetail(for: member)
                    .frame(minWidth: 240, idealWidth: 280)
            }
        }
        .navigationTitle("Team & Permissions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddMember = true
                } label: {
                    Label("Add Member", systemImage: "person.badge.plus")
                }
                .help("Add a team member")
            }
        }
        .sheet(isPresented: $showAddMember) {
            addMemberSheet
        }
    }

    private var selectedMember: ProjectMember? {
        members.first { $0.id == selectedMemberID }
    }

    // MARK: - Member Table

    private var memberTable: some View {
        Table(members, selection: $selectedMemberID) {
            TableColumn("") { member in
                ZStack {
                    Circle()
                        .fill(Color(.controlBackgroundColor))
                    Text(memberInitials(member.displayName))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .frame(width: 28, height: 28)
            }
            .width(36)

            TableColumn("Name") { member in
                VStack(alignment: .leading, spacing: 1) {
                    Text(member.displayName)
                        .font(.body)
                    Text(member.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 150, ideal: 200)

            TableColumn("Role") { member in
                if member.role != .owner {
                    Picker("", selection: roleBinding(for: member)) {
                        ForEach(ProjectRole.allCases, id: \.self) { role in
                            Text(role.rawValue.capitalized).tag(role)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                } else {
                    Text(member.role.rawValue.capitalized)
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 100, ideal: 140)

            TableColumn("Joined") { member in
                Text(member.joinedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: UUID.self) { selection in
            if let memberID = selection.first,
               let member = members.first(where: { $0.id == memberID }),
               member.role != .owner {
                Button("Remove Member", role: .destructive) {
                    removeMember(member)
                }
            }
        } primaryAction: { _ in }
        .overlay {
            if members.isEmpty {
                ContentUnavailableView {
                    Label("No Members", systemImage: "person.3")
                } description: {
                    Text("Add team members to collaborate on this project.")
                } actions: {
                    Button("Add Member") {
                        showAddMember = true
                    }
                }
            }
        }
    }

    // MARK: - Permission Detail

    private func permissionDetail(for member: ProjectMember) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(.controlBackgroundColor))
                    Text(memberInitials(member.displayName))
                        .font(.title2)
                        .fontWeight(.medium)
                }
                .frame(width: 56, height: 56)

                Text(member.displayName)
                    .font(.headline)
                Text(member.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(member.role.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.controlBackgroundColor), in: Capsule())
            }
            .frame(maxWidth: .infinity)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Permissions")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                permissionRow("Read", granted: true)
                permissionRow("Write", granted: member.canWrite)
                permissionRow("Merge Branches", granted: member.canMergeBranches)
                permissionRow("Manage Members", granted: member.canManageMembers)
                permissionRow("Edit Settings", granted: member.canEditSettings)
                permissionRow("Create Branches", granted: member.canCreateBranches)
                permissionRow("Review", granted: member.canReview)
                permissionRow("Delete Project", granted: member.canDeleteProject)
            }

            Spacer()
        }
        .padding()
    }

    private func permissionRow(_ label: String, granted: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: granted ? "checkmark" : "xmark")
                .font(.caption)
                .foregroundStyle(granted ? .green : .red)
            Text(label)
                .font(.body)
                .foregroundStyle(granted ? .primary : .secondary)
        }
    }

    // MARK: - Add Member Sheet

    private var addMemberSheet: some View {
        VStack(spacing: 16) {
            Text("Add Team Member")
                .font(.headline)

            Form {
                TextField("Display Name", text: $newMemberName)
                TextField("Username / Email", text: $newMemberEmail)
                Picker("Role", selection: $newMemberRole) {
                    ForEach(ProjectRole.allCases.filter { $0 != .owner }, id: \.self) { role in
                        Text(role.rawValue.capitalized).tag(role)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel", role: .cancel) {
                    resetAddForm()
                    showAddMember = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    addMember()
                    showAddMember = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    newMemberName.trimmingCharacters(in: .whitespaces).isEmpty ||
                    newMemberEmail.trimmingCharacters(in: .whitespaces).isEmpty
                )
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }

    // MARK: - Helpers

    private func memberInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let initials = parts.prefix(2).compactMap { $0.first }.map { String($0) }
        return initials.joined().uppercased()
    }

    private func roleBinding(for member: ProjectMember) -> Binding<ProjectRole> {
        Binding(
            get: { member.role },
            set: { newRole in
                guard let projectIndex = appState.projects.firstIndex(where: {
                    $0.id == appState.selectedProject?.id
                }) else { return }
                if let memberIndex = appState.projects[projectIndex].members.firstIndex(where: {
                    $0.id == member.id
                }) {
                    appState.projects[projectIndex].members[memberIndex].role = newRole
                }
            }
        )
    }

    private func addMember() {
        let member = ProjectMember(
            userId: UUID().uuidString,
            username: newMemberEmail,
            displayName: newMemberName,
            role: newMemberRole
        )
        guard let projectIndex = appState.projects.firstIndex(where: {
            $0.id == appState.selectedProject?.id
        }) else { return }
        appState.projects[projectIndex].members.append(member)
        resetAddForm()
    }

    private func removeMember(_ member: ProjectMember) {
        guard let projectIndex = appState.projects.firstIndex(where: {
            $0.id == appState.selectedProject?.id
        }) else { return }
        appState.projects[projectIndex].members.removeAll { $0.id == member.id }
    }

    private func resetAddForm() {
        newMemberName = ""
        newMemberEmail = ""
        newMemberRole = .viewer
    }
}

#Preview {
    PermissionsView()
        .environment(AppState())
        .frame(width: 700, height: 500)
}
