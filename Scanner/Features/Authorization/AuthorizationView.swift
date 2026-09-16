import SwiftUI
import ScanEngine

struct AuthorizationView: View {
    @Environment(ScanController.self) private var controller
    @State private var confirmed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(AuthorizationCopy.title)
                .font(.largeTitle)
                .bold()

            Text(AuthorizationCopy.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            scopePicker

            if controller.scopes.isEmpty {
                Label(
                    "No private IPv4 interface is up. Connect to Wi-Fi or Ethernet.",
                    systemImage: "wifi.slash"
                )
                .foregroundStyle(.orange)
            } else if let scope = controller.selectedScope, !scope.isAssessable {
                Label(
                    "This address range is not private. Scanner will not probe it.",
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(.orange)
            }

            Toggle(AuthorizationCopy.confirmation, isOn: $confirmed)
                .disabled(!(controller.selectedScope?.isAssessable ?? false))

            HStack {
                Spacer()
                Button("Start assessment") {
                    controller.authorizeSelectedScope()
                    controller.start()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canStart)
            }
        }
        .padding(24)
        .frame(maxWidth: 640)
        .task {
            await controller.refreshScopes()
        }
    }

    private var canStart: Bool {
        confirmed && (controller.selectedScope?.isAssessable ?? false)
    }

    @ViewBuilder
    private var scopePicker: some View {
        Picker("Network", selection: Bindable(controller).selectedScopeID) {
            ForEach(controller.scopes) { scope in
                Text(scopeLabel(scope))
                    .tag(Optional(scope.id))
            }
        }
        Picker("Profile", selection: Bindable(controller).profile) {
            ForEach(ScanProfile.allCases) { profile in
                Text(profile.title).tag(profile)
            }
        }
        .pickerStyle(.segmented)
    }

    private func scopeLabel(_ scope: NetworkScopeDraft) -> String {
        let hosts = scope.estimatedHostCount
        return "\(scope.displayName)  \(scope.cidr)  (~\(hosts) hosts)"
    }
}
