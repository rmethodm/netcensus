import AppKit
import ScanEngine
import SwiftUI

struct CredentialsView: View {
    @State private var records: [ScanCredential] = []
    @State private var label = ""
    @State private var kind: CredentialKind = .snmpv2c
    @State private var scope: CredentialScopeKind = .subnet
    @State private var target = ""
    @State private var username = ""
    @State private var secret = ""
    @State private var keyPath = ""
    private let vault = CredentialVault()

    var body: some View {
        Form {
            Section("Stored credentials") {
                if records.isEmpty {
                    Text("None. Secrets go in the Keychain; metadata stays on this Mac.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(records) { record in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(record.label).font(.headline)
                                Text("\(record.kind.title) · \(record.target)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Remove", role: .destructive) {
                                vault.remove(record.id)
                                records = vault.list()
                            }
                        }
                    }
                }
            }
            Section("Add") {
                TextField("Label", text: $label)
                Picker("Type", selection: $kind) {
                    ForEach(CredentialKind.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                Picker("Scope", selection: $scope) {
                    ForEach(CredentialScopeKind.allCases, id: \.self) { item in
                        Text(item.title).tag(item)
                    }
                }
                TextField(scope == .host ? "Host IPv4" : "CIDR", text: $target)
                switch kind {
                case .snmpv2c:
                    SecureField("Community", text: $secret)
                case .sshKey:
                    TextField("SSH username", text: $username)
                    HStack {
                        Text(keyPath.isEmpty ? "No key selected" : keyPath)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                        Button("Choose key…", action: chooseKey)
                    }
                    Text("SSH runs a fixed read-only script (uname / os-release). No password spraying.")
                        .foregroundStyle(.secondary)
                case .httpBasic:
                    TextField("HTTP username", text: $username)
                    SecureField("HTTP password", text: $secret)
                    Text("One stored login is tried on HTTP/HTTPS. No password lists.")
                        .foregroundStyle(.secondary)
                }
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Credentials")
        .onAppear { records = vault.list() }
    }

    private var canSave: Bool {
        if label.isEmpty || target.isEmpty { return false }
        switch kind {
        case .snmpv2c: return !secret.isEmpty
        case .sshKey: return !username.isEmpty && !keyPath.isEmpty
        case .httpBasic: return !username.isEmpty && !secret.isEmpty
        }
    }

    private func save() {
        var credential = ScanCredential(kind: kind, label: label, target: target, scope: scope)
        credential.username = username.isEmpty ? nil : username
        credential.keyPath = keyPath.isEmpty ? nil : keyPath
        credential.secret = secret
        try? vault.save(credential)
        records = vault.list()
        label = ""
        secret = ""
        username = ""
        keyPath = ""
    }

    private func chooseKey() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a private SSH key. It is not copied; only the path is stored."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        keyPath = url.path
    }
}
