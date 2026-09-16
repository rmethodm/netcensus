import AppKit
import SwiftData
import SwiftUI
import ScanEngine
import ScanEngineMocks

@main
struct ScannerApp: App {
    @State private var controller: ScanController
    private let container: ModelContainer

    init() {
        let schema = Schema(ScannerSchema.models)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema)
        } catch {
            fatalError("Unable to create model container: \(error)")
        }
        self.container = container
        let repository = InventoryRepository(context: container.mainContext)
        _controller = State(
            initialValue: ScanController(repository: repository)
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(controller)
                .modelContainer(container)
                .frame(minWidth: 960, minHeight: 640)
                .task {
                    await controller.refreshScopes()
                    controller.considerLaunchScan()
                }
        }
        .commands {
            CommandGroup(after: .saveItem) {
                Menu("Export") {
                    ForEach(ScanReportFormat.allCases, id: \.self) { format in
                        Button("Export \(format.contentTypeDescription)…") {
                            export(format)
                        }
                    }
                }
            }
            CommandMenu("Scan") {
                Button("Start Scan") {
                    controller.start()
                }
                .keyboardShortcut("r", modifiers: [.command])
                Button("Stop Scan") {
                    controller.stop()
                }
                .keyboardShortcut(".", modifiers: [.command])
            }
            CommandGroup(replacing: .help) {
                Button("Scanner Policy") {
                    PolicyWindow.open()
                }
            }
        }
    }

    private func export(_ format: ScanReportFormat) {
        guard let report = controller.currentReport, !report.hosts.isEmpty else { return }
        try? ReportExport.save(report, format: format)
    }
}

enum PolicyWindow {
    @MainActor
    private static var retained: NSWindow?

    @MainActor
    static func open() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Scanner Policy"
        window.contentView = NSHostingView(rootView: PolicyView())
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        retained = window
    }
}
