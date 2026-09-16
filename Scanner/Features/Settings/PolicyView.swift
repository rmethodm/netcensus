import SwiftUI

struct PolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Scanner policy")
                    .font(.title.bold())
                Text("Authorized assessment only. Identify, don’t attack.")
                    .font(.headline)
                Text(
                    "Scanner records banners, services, and known issues on networks you confirm you may assess. "
                    + "It does not run exploits, guess passwords, or send results to a server. Export is explicit and local."
                )
                Text("Local Network permission is used to discover devices. CVE matching uses a snapshot shipped with the app.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(24)
        }
    }
}
