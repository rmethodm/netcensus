import SwiftData
import SwiftUI
import ScanEngine

struct InventoryView: View {
    @Query(sort: \DeviceRecord.lastSeenAt, order: .reverse) private var devices: [DeviceRecord]
    @Environment(ScanController.self) private var controller
    @State private var filter: DriftStatus?

    var body: some View {
        Group {
            if controller.driftRows.isEmpty && devices.isEmpty {
                ContentUnavailableView(
                    "No inventory yet",
                    systemImage: "externaldrive.connected.to.line.below",
                    description: Text("Completed scans are stored here and merged across runs.")
                )
            } else {
                List(filteredRows, selection: Bindable(controller).selectedHostID) { row in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.snapshot.hostname ?? row.snapshot.ipv4 ?? "Unknown host")
                                .font(.headline)
                            Text(subtitle(row.snapshot))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospaced()
                        }
                        Spacer()
                        Text(row.status.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(color(row.status))
                    }
                    .tag(hostID(for: row))
                }
            }
        }
        .navigationTitle("Inventory")
        .toolbar {
            Picker("Drift", selection: $filter) {
                Text("All").tag(Optional<DriftStatus>.none)
                Text("New").tag(Optional.some(DriftStatus.appeared))
                Text("Gone").tag(Optional.some(DriftStatus.disappeared))
                Text("Changed").tag(Optional.some(DriftStatus.changed))
            }
            .pickerStyle(.segmented)
        }
        .onAppear { controller.refreshDrift() }
    }

    private var filteredRows: [DriftRow] {
        let rows = controller.driftRows
        guard let filter else { return rows }
        return rows.filter { $0.status == filter }
    }

    private func subtitle(_ snapshot: HostDriftSnapshot) -> String {
        [snapshot.ipv4, snapshot.mac]
            .compactMap { $0 }
            .joined(separator: "  ·  ")
    }

    private func color(_ status: DriftStatus) -> Color {
        switch status {
        case .appeared: .teal
        case .disappeared: .secondary
        case .changed: .orange
        case .unchanged: .secondary
        }
    }

    private func hostID(for row: DriftRow) -> UUID? {
        controller.hosts.first { host in
            host.driftSnapshot.key == row.snapshot.key
        }?.id
    }
}
