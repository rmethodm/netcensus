import SwiftUI
import ScanEngine

struct DeviceDetailView: View {
    @Environment(ScanController.self) private var controller

    var body: some View {
        if let host = controller.selectedHost {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(host)
                    findings(host)
                    services(host)
                    evidence(host)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(host.identity.displayName)
            .toolbar {
                Button("Copy Markdown") {
                    ReportExport.copyMarkdown(host)
                }
            }
        } else {
            ContentUnavailableView(
                "No device selected",
                systemImage: "laptopcomputer",
                description: Text("Select a host to inspect identity, services, and evidence.")
            )
        }
    }

    private func header(_ host: HostDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(host.deviceClass.title)
                    .font(.title2.bold())
                if host.flags.isGateway {
                    Text("Gateway")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                if host.flags.isThisMac {
                    Text("This Mac")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
            labeled("IPv4", host.identity.ipv4)
            labeled("MAC", host.identity.mac)
            labeled("Vendor", host.identity.vendor)
            labeled("OS", host.flags.osGuess)
            labeled("Firmware", host.flags.firmwareGuess)
            labeled("Discovery", host.flags.discoveryMethods.joined(separator: ", "))
        }
    }

    private func findings(_ host: HostDraft) -> some View {
        GroupBox("Findings") {
            if host.findings.isEmpty {
                Text("No findings on this host.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(host.findings) { finding in
                        FindingBlock(finding: finding) { status in
                            controller.setFindingStatus(finding.id, status)
                        }
                    }
                }
            }
        }
    }

    private func services(_ host: HostDraft) -> some View {
        GroupBox("Services") {
            if host.services.isEmpty {
                Text("No open services recorded yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Table(host.services) {
                    TableColumn("Port") { service in
                        Text("\(service.port)/\(service.transport.rawValue)")
                            .monospaced()
                    }
                    TableColumn("Service") { service in
                        Text(service.protocolGuess ?? "—")
                    }
                    TableColumn("Banner") { service in
                        Text(service.banner ?? "—")
                            .lineLimit(1)
                    }
                }
                .frame(minHeight: 120)
            }
        }
    }

    private func evidence(_ host: HostDraft) -> some View {
        GroupBox("Evidence") {
            if host.evidence.isEmpty {
                Text("No evidence collected yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(host.evidence) { item in
                    DisclosureGroup(item.summary) {
                        Text(item.payload)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func labeled(_ title: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            LabeledContent(title) {
                Text(value)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
            }
        }
    }
}

struct FindingBlock: View {
    var finding: FindingDraft
    var onStatus: ((FindingStatus) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SeverityBadge(severity: finding.classification.severity)
                Text(finding.title)
                    .font(.headline)
                Spacer()
                Text(finding.status.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(finding.detail)
                .foregroundStyle(.secondary)
            if !finding.classification.cveIDs.isEmpty {
                Text(finding.classification.cveIDs.joined(separator: ", "))
                    .font(.caption.monospaced())
            }
            Text(finding.remediation)
                .font(.callout)
            Text("Confidence: \(finding.classification.confidence.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let onStatus {
                HStack {
                    Button("Acknowledge") { onStatus(.acknowledged) }
                    Button("Ignore") { onStatus(.ignored) }
                    Button("Reopen") { onStatus(.open) }
                }
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(finding.status == .ignored ? 0.55 : 1)
        .accessibilityElement(children: .combine)
    }
}
