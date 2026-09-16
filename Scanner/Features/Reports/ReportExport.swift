import AppKit
import ScanEngine
import UniformTypeIdentifiers

enum ReportExport {
    @MainActor
    static func save(_ report: ScanReport, format: ScanReportFormat) throws {
        let data = try ScanReportFormatter.render(report, as: format)
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "scanner-\(report.cidr.replacingOccurrences(of: "/", with: "-")).\(format.fileExtension)"
        panel.allowedContentTypes = [utType(format)]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try data.write(to: url, options: .atomic)
    }

    @MainActor
    static func copyMarkdown(_ host: HostDraft) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ScanReportFormatter.hostMarkdown(host), forType: .string)
    }

    private static func utType(_ format: ScanReportFormat) -> UTType {
        switch format {
        case .json: .json
        case .csv: .commaSeparatedText
        case .markdown: .plainText
        }
    }
}
