import SwiftUI
import ScanEngine

struct FindingsView: View {
    @Environment(ScanController.self) private var controller

    var body: some View {
        Group {
            if controller.findings.isEmpty {
                ContentUnavailableView(
                    "No findings",
                    systemImage: "checkmark.shield",
                    description: Text("Assessment results for the current scan appear here.")
                )
            } else {
                List(controller.findings) { finding in
                    FindingBlock(finding: finding) { status in
                        controller.setFindingStatus(finding.id, status)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let host = controller.hosts.first(where: { host in
                            host.findings.contains { $0.id == finding.id }
                        }) {
                            controller.selectedHostID = host.id
                        }
                    }
                }
            }
        }
        .navigationTitle("Findings")
        .toolbar {
            Toggle("Hide ignored", isOn: Bindable(controller).hideIgnoredFindings)
        }
    }
}
