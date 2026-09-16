import SwiftUI
import ScanEngine

struct SettingsView: View {
    @Environment(ScanController.self) private var controller
    @State private var launchAtLogin = LoginItemSettings.isEnabled

    var body: some View {
        Form {
            #if DEBUG
            Section("Engine") {
                Toggle("Use fixture hosts", isOn: Bindable(controller).usesFixtureEngine)
                Text(
                    controller.usesFixtureEngine
                        ? "Fixture mode emits five sample hosts. Turn this off to discover the real LAN."
                        : "Live mode discovers, fingerprints, then assesses hygiene, a local CVE subset, firmware lag, and SNMP public."
                )
                .foregroundStyle(.secondary)
            }
            #endif
            Section("Defaults") {
                Picker("Scan profile", selection: Bindable(controller).profile) {
                    ForEach(ScanProfile.allCases) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
            }
            Section("Schedule") {
                Picker("Repeat while \(AppBrand.displayName) is open", selection: Bindable(controller).schedule) {
                    ForEach(ScanSchedule.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                Toggle("Open \(AppBrand.displayName) at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try LoginItemSettings.setEnabled(enabled)
                        } catch {
                            launchAtLogin = LoginItemSettings.isEnabled
                        }
                    }
                Toggle("Scan when \(AppBrand.displayName) opens", isOn: Bindable(controller).scanOnLaunch)
                Text("Scheduled scans use the current authorized scope. Open at login plus scan-on-open covers a reboot.")
                    .foregroundStyle(.secondary)
            }
            Section("Credentials") {
                NavigationLink("SNMP and SSH keys") {
                    CredentialsView()
                }
                Text("Communities and keys are used only on matching hosts. SSH runs a fixed read-only script.")
                    .foregroundStyle(.secondary)
            }
            Section("Retention") {
                Stepper(
                    "Keep runs for \(controller.retentionDays) days",
                    value: Bindable(controller).retentionDays,
                    in: 1...365
                )
                Text("At least the newest run per network is kept.")
                    .foregroundStyle(.secondary)
            }
            Section("Authorization copy") {
                LabeledContent("Version", value: AuthorizationCopy.version)
            }
            Section("Privacy") {
                Text("Scan results stay on this Mac unless you export them. There is no account and no telemetry.")
                    .foregroundStyle(.secondary)
                NavigationLink("\(AppBrand.displayName) policy") {
                    PolicyView()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .padding()
    }
}
