import Foundation

// MARK: - Date Formatting Extensions

extension Date {

    /// Human-readable relative time: "just now", "2 hours ago", "yesterday",
    /// or a short date for anything older than a week.
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named

        let interval = Date.now.timeIntervalSince(self)

        // For very recent times, use the relative formatter directly.
        if interval < 7 * 24 * 3600 {
            return formatter.localizedString(for: self, relativeTo: .now)
        }

        // Beyond a week, fall back to a short date.
        return shortFormatted
    }

    /// Short date format: "Mar 15, 2024".
    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    /// ISO 8601 string: "2024-03-15T14:30:00Z".
    var isoFormatted: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: self)
    }
}
