import SwiftUI
import ScanEngine

struct HostListView: View {
    @Environment(ScanController.self) private var controller

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if controller.hosts.isEmpty {
                ContentUnavailableView(
                    controller.isRunning ? "Discovering hosts" : "No hosts yet",
                    systemImage: "wifi.router",
                    description: Text(controller.isRunning
                        ? "Discovering hosts on the scoped subnet."
                        : "Start a scan to inventory this network.")
                )
            } else {
                List(selection: Bindable(controller).selectedHostID) {
                    ForEach(controller.hosts) { host in
                        HostRow(host: host)
                            .tag(Optional(host.id))
                    }
                }
            }
        }
        .navigationTitle("Scan")
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            if controller.isRunning {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 180)
                Text(phaseLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Button("Stop", role: .destructive, action: controller.stop)
            } else {
                Button("Scan") { controller.start() }
                    .keyboardShortcut("r", modifiers: [.command])
                    .disabled(controller.needsAuthorization || !(controller.selectedScope?.isAssessable ?? false))
            }
            Spacer()
            if let summary = controller.lastSummary {
                Text("\(summary.hostCount) hosts · \(summary.findingCount) findings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    private var progress: Double {
        guard controller.progressTotal > 0 else { return 0 }
        return Double(controller.progressCompleted) / Double(controller.progressTotal)
    }

    private var phaseLabel: String {
        let phase = controller.phase?.rawValue.capitalized ?? "Running"
        return "\(phase) \(controller.progressCompleted)/\(controller.progressTotal)"
    }
}

struct HostRow: View {
    var host: HostDraft

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(host.identity.displayName)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospaced()
            }
            Spacer()
            if let severity = host.highestSeverity {
                SeverityBadge(severity: severity)
            } else {
                Text(host.deviceClass.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        [host.identity.ipv4, host.identity.mac, host.identity.vendor]
            .compactMap { $0 }
            .joined(separator: "  ·  ")
    }
}
