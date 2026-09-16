import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case scan
    case inventory
    case findings
    case reports
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scan: "Scan"
        case .inventory: "Inventory"
        case .findings: "Findings"
        case .reports: "Reports"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .scan: "dot.radiowaves.left.and.right"
        case .inventory: "externaldrive.connected.to.line.below"
        case .findings: "exclamationmark.triangle"
        case .reports: "doc.text"
        case .settings: "gearshape"
        }
    }
}

struct RootView: View {
    @Environment(ScanController.self) private var controller
    @State private var section: SidebarSection? = .scan

    var body: some View {
        Group {
            if controller.needsAuthorization && !controller.isRunning && controller.hosts.isEmpty {
                AuthorizationView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NavigationSplitView {
                    List(SidebarSection.allCases, selection: $section) { item in
                        Label(item.title, systemImage: item.systemImage)
                            .tag(item)
                    }
                    .navigationSplitViewColumnWidth(min: 160, ideal: 180)
                } content: {
                    switch section ?? .scan {
                    case .scan:
                        HostListView()
                    case .inventory:
                        InventoryView()
                    case .findings:
                        FindingsView()
                    case .reports:
                        ReportsView()
                    case .settings:
                        SettingsView()
                    }
                } detail: {
                    DeviceDetailView()
                }
                .navigationTitle(AppBrand.displayName)
            }
        }
    }
}
