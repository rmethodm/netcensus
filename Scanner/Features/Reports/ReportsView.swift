import ScanEngine
import SwiftUI

struct ReportsView: View {
    @Environment(ScanController.self) private var controller
    @State private var exportError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export the current scan. JSON is complete; CSV is a host table; Markdown is readable for tickets.")
                .foregroundStyle(.secondary)
            if let report = controller.currentReport, !report.hosts.isEmpty {
                LabeledContent("Hosts", value: "\(report.hosts.count)")
                LabeledContent("Findings", value: "\(report.findingCount)")
                HStack {
                    ForEach(ScanReportFormat.allCases, id: \.self) { format in
                        Button("Export \(format.contentTypeDescription)") {
                            export(report, format: format)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "No scan to export",
                    systemImage: "doc.text",
                    description: Text("Run a scan first, then export it from here or File → Export.")
                )
            }
            if let exportError {
                Text(exportError)
                    .foregroundStyle(.red)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Reports")
    }

    private func export(_ report: ScanReport, format: ScanReportFormat) {
        do {
            try ReportExport.save(report, format: format)
            exportError = nil
        } catch {
            exportError = error.localizedDescription
        }
    }
}
