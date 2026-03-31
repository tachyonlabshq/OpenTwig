import Foundation

// MARK: - Errors

enum ExportError: LocalizedError, Sendable {
    case pandocNotFound
    case exportFailed(String)
    case invalidDocument
    case templateNotFound(URL)
    case unsupportedFormat(String)
    case commandFailed(exitCode: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .pandocNotFound:
            return "Pandoc not found. Install it via Homebrew: brew install pandoc"
        case .exportFailed(let msg):
            return "Export failed: \(msg)"
        case .invalidDocument:
            return "Document content is empty or invalid"
        case .templateNotFound(let url):
            return "Template not found at \(url.path)"
        case .unsupportedFormat(let format):
            return "Unsupported export format: \(format)"
        case .commandFailed(let exitCode, let stderr):
            return "Pandoc exited with code \(exitCode): \(stderr)"
        }
    }
}

// MARK: - ExportService

struct ExportService: Sendable {

    // MARK: - Public API

    /// Export a document to the specified format.
    ///
    /// - Parameters:
    ///   - document: The document to export.
    ///   - format: Target export format (pdf, latex, docx, html).
    ///   - citations: Citation library for bibliography generation.
    ///   - template: Optional custom pandoc template file.
    /// - Returns: URL of the exported file in a temporary directory.
    func export(
        document: Document,
        format: ExportFormat,
        citations: [CitationEntry],
        template: URL? = nil
    ) async throws -> URL {
        guard !document.content.isEmpty else {
            throw ExportError.invalidDocument
        }

        if let template, !FileManager.default.fileExists(atPath: template.path) {
            throw ExportError.templateNotFound(template)
        }

        let pandocPath = try resolvePandocPath()
        let tempDir = try createTempDirectory(for: document)

        // Write the document content to a temp .md file.
        let inputFile = tempDir.appendingPathComponent("input.md")
        try document.content.write(to: inputFile, atomically: true, encoding: .utf8)

        // Write the bibliography if citations are provided.
        var bibFile: URL?
        if !citations.isEmpty {
            let bibURL = tempDir.appendingPathComponent("references.json")
            let citationService = CitationService()
            let cslData = try citationService.exportCSLJSON(citations: citations)
            try cslData.write(to: bibURL)
            bibFile = bibURL
        }

        // Build the output path.
        let outputName = document.filename
            .replacingOccurrences(of: ".md", with: "")
            .replacingOccurrences(of: ".tex", with: "")
        let outputFile = tempDir.appendingPathComponent("\(outputName).\(format.fileExtension)")

        // Build pandoc arguments.
        var args = buildPandocArguments(
            input: inputFile,
            output: outputFile,
            format: format,
            bibliography: bibFile,
            template: template
        )

        // Run pandoc.
        let result = try await runPandoc(
            executablePath: pandocPath,
            arguments: args,
            workingDirectory: tempDir
        )

        guard result.exitCode == 0 else {
            throw ExportError.commandFailed(exitCode: result.exitCode, stderr: result.stderr)
        }

        guard FileManager.default.fileExists(atPath: outputFile.path) else {
            throw ExportError.exportFailed("Output file was not created")
        }

        return outputFile
    }

    // MARK: - Private: Pandoc Arguments

    private func buildPandocArguments(
        input: URL,
        output: URL,
        format: ExportFormat,
        bibliography: URL?,
        template: URL?
    ) -> [String] {
        var args: [String] = []

        args.append(contentsOf: ["--from", "markdown"])
        args.append(contentsOf: ["--to", format.pandocFormat])
        args.append(contentsOf: ["--output", output.path])

        // Citation processing.
        if let bib = bibliography {
            args.append("--citeproc")
            args.append(contentsOf: ["--bibliography", bib.path])
        }

        // Custom template.
        if let template {
            args.append(contentsOf: ["--template", template.path])
        }

        // Format-specific options.
        switch format {
        case .pdf:
            args.append(contentsOf: ["--pdf-engine", "xelatex"])
            // Enable better Unicode support.
            args.append(contentsOf: ["-V", "mainfont=Times New Roman"])
        case .html:
            args.append("--standalone")
            args.append("--mathml")
        case .latex:
            args.append("--standalone")
        case .docx:
            break
        }

        // Input file last.
        args.append(input.path)

        return args
    }

    // MARK: - Private: Process Execution

    private struct ProcessOutput {
        var stdout: String
        var stderr: String
        var exitCode: Int32
    }

    private func runPandoc(
        executablePath: String,
        arguments: [String],
        workingDirectory: URL
    ) async throws -> ProcessOutput {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.currentDirectoryURL = workingDirectory

            // Use a minimal environment to avoid leaking secrets or
            // unexpected variables into the Pandoc subprocess.
            var safeEnv: [String: String] = [:]
            if let path = ProcessInfo.processInfo.environment["PATH"] {
                safeEnv["PATH"] = path
            }
            if let home = ProcessInfo.processInfo.environment["HOME"] {
                safeEnv["HOME"] = home
            }
            if let lang = ProcessInfo.processInfo.environment["LANG"] {
                safeEnv["LANG"] = lang
            }
            process.environment = safeEnv

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { proc in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let output = ProcessOutput(
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    exitCode: proc.terminationStatus
                )
                continuation.resume(returning: output)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ExportError.exportFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - Private: Helpers

    private func resolvePandocPath() throws -> String {
        let candidates = [
            "/usr/local/bin/pandoc",
            "/opt/homebrew/bin/pandoc",
            "/usr/bin/pandoc",
        ]

        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        throw ExportError.pandocNotFound
    }

    private func createTempDirectory(for document: Document) throws -> URL {
        let tempBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenTwig-Export")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(
            at: tempBase,
            withIntermediateDirectories: true
        )

        return tempBase
    }
}
