import SwiftUI

struct ActivityLogView: View {
    @Environment(AppState.self) private var appState
    @State private var filterType: ActivityEventType?

    private var groupedEvents: [(String, [ActivityEvent])] {
        let events: [ActivityEvent]
        if let filterType {
            events = appState.activityEvents.filter { $0.eventType == filterType }
        } else {
            events = appState.activityEvents
        }

        let sorted = events.sorted { $0.timestamp > $1.timestamp }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let grouped = Dictionary(grouping: sorted) { event in
            formatter.string(from: event.timestamp)
        }

        return grouped.sorted { lhs, rhs in
            guard let lDate = lhs.value.first?.timestamp,
                  let rDate = rhs.value.first?.timestamp else { return false }
            return lDate > rDate
        }
    }

    var body: some View {
        List {
            ForEach(groupedEvents, id: \.0) { dateString, events in
                Section(dateString) {
                    ForEach(events) { event in
                        ActivityEventRow(event: event)
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Activity")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("All Events") {
                        filterType = nil
                    }

                    Divider()

                    ForEach(ActivityEventType.allCases, id: \.self) { type in
                        Button {
                            filterType = type
                        } label: {
                            Label(type.rawValue, systemImage: iconName(for: type))
                        }
                    }
                } label: {
                    Label(
                        filterType?.rawValue ?? "Filter",
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                }
                .help("Filter events by type")
            }
        }
        .overlay {
            if appState.activityEvents.isEmpty {
                ContentUnavailableView {
                    Label("No Activity", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Project activity will appear here as you work.")
                }
            }
        }
    }

    private func iconName(for type: ActivityEventType) -> String {
        switch type {
        case .commit: return "checkmark.circle"
        case .push: return "arrow.up.circle"
        case .pull: return "arrow.down.circle"
        case .branchCreated: return "plus.circle"
        case .branchMerged: return "arrow.triangle.merge"
        case .prOpened: return "arrow.triangle.pull"
        case .prMerged: return "arrow.triangle.merge"
        case .citationAdded: return "book.circle"
        case .citationRemoved: return "book.closed.circle"
        case .aiSuggestionCreated: return "sparkles"
        case .aiSuggestionAccepted: return "checkmark.seal"
        case .aiSuggestionRejected: return "xmark.seal"
        case .memberAdded: return "person.badge.plus"
        case .memberRemoved: return "person.badge.minus"
        case .documentCreated: return "doc.badge.plus"
        case .documentDeleted: return "doc.badge.minus"
        case .exportGenerated: return "square.and.arrow.up"
        }
    }
}

// MARK: - Activity Event Row

private struct ActivityEventRow: View {
    let event: ActivityEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(event.username)
                        .font(.body)
                        .fontWeight(.medium)

                    Text(event.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(event.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch event.eventType {
        case .commit: return "checkmark.circle"
        case .push: return "arrow.up.circle"
        case .pull: return "arrow.down.circle"
        case .branchCreated: return "plus.circle"
        case .branchMerged: return "arrow.triangle.merge"
        case .prOpened: return "arrow.triangle.pull"
        case .prMerged: return "arrow.triangle.merge"
        case .citationAdded: return "book.circle"
        case .citationRemoved: return "book.closed.circle"
        case .aiSuggestionCreated: return "sparkles"
        case .aiSuggestionAccepted: return "checkmark.seal"
        case .aiSuggestionRejected: return "xmark.seal"
        case .memberAdded: return "person.badge.plus"
        case .memberRemoved: return "person.badge.minus"
        case .documentCreated: return "doc.badge.plus"
        case .documentDeleted: return "doc.badge.minus"
        case .exportGenerated: return "square.and.arrow.up"
        }
    }

    private var iconColor: Color {
        switch event.eventType {
        case .commit: return .green
        case .push: return .blue
        case .pull: return .orange
        case .branchCreated: return .teal
        case .branchMerged: return .purple
        case .prOpened: return .indigo
        case .prMerged: return .purple
        case .citationAdded: return .mint
        case .citationRemoved: return .red
        case .aiSuggestionCreated: return .cyan
        case .aiSuggestionAccepted: return .green
        case .aiSuggestionRejected: return .red
        case .memberAdded: return .cyan
        case .memberRemoved: return .red
        case .documentCreated: return .green
        case .documentDeleted: return .red
        case .exportGenerated: return .blue
        }
    }
}

#Preview {
    NavigationStack {
        ActivityLogView()
            .environment(AppState())
    }
    .frame(width: 400, height: 600)
}
