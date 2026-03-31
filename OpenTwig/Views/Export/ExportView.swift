import SwiftUI

struct ExportView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ExportFormat = .pdf
    @State private var selectedStyle: CitationStyle = .apa
    @State private var selectedTemplate: String = "Default"
    @State private var isExporting: Bool = false
    @State private var exportProgress: Double = 0

    private let templates = ["Default", "Academic Paper", "Thesis", "Report", "Manuscript"]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            formContent
            Divider()
            footer
        }
        .frame(width: 560, height: 480)
        .onAppear {
            selectedFormat = appState.defaultExportFormat
            selectedStyle = appState.defaultCitationStyle
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "square.and.arrow.up")
                .font(.title2)
                .foregroundStyle(.accent)
            VStack(alignment: .leading) {
                Text("Export Document")
                    .font(.headline)
                if let doc = appState.selectedDocument {
                    Text(doc.filename)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Form

    private var formContent: some View {
        Form {
            Section("Output Format") {
                Picker("Format", selection: $selectedFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        HStack {
                            Image(systemName: format.iconName)
                            Text(format.rawValue)
                        }
                        .tag(format)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Template") {
                Picker("Template", selection: $selectedTemplate) {
                    ForEach(templates, id: \.self) { template in
                        Text(template).tag(template)
                    }
                }
            }

            Section("Citation Style") {
                Picker("Style", selection: $selectedStyle) {
                    ForEach(CitationStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
            }

            if isExporting {
                Section {
                    VStack(spacing: 8) {
                        ProgressView(value: exportProgress)
                        Text(exportStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var exportStatusText: String {
        if exportProgress < 0.3 {
            return "Resolving citations..."
        } else if exportProgress < 0.6 {
            return "Formatting document..."
        } else if exportProgress < 0.9 {
            return "Generating output..."
        } else {
            return "Finalizing..."
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel", role: .cancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            if isExporting {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            }

            Button("Export") {
                performExport()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(isExporting || appState.selectedDocument == nil)
        }
        .padding()
    }

    // MARK: - Actions

    private func performExport() {
        isExporting = true
        exportProgress = 0

        // Simulate export progress, then present save dialog
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            exportProgress += 0.1
            if exportProgress >= 1.0 {
                timer.invalidate()
                isExporting = false
                showSavePanel()
            }
        }
    }

    private func showSavePanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [
            .init(filenameExtension: selectedFormat.fileExtension)
        ].compactMap { $0 }
        panel.nameFieldStringValue = (appState.selectedDocument?.filename ?? "document")
            .replacingOccurrences(of: ".md", with: ".\(selectedFormat.fileExtension)")

        if panel.runModal() == .OK, let _ = panel.url {
            // Placeholder: write exported file to url
            dismiss()
        }
    }

}

#Preview {
    ExportView()
        .environment(AppState())
}
