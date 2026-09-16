public enum SSHCheck: Sendable {
    public static func assess(_ host: HostDraft, credentials: [ScanCredential]) async -> HostDraft {
        guard let ip = host.identity.ipv4 else { return host }
        guard host.openPort(22) != nil else { return host }
        let matches = credentials.filter { $0.kind == .sshKey && $0.matches(hostIP: ip) }
        guard let credential = matches.first,
              let username = credential.username, !username.isEmpty,
              let keyPath = credential.keyPath, !keyPath.isEmpty
        else {
            return host
        }
        guard let output = await SSHProbe.run(host: ip, username: username, keyPath: keyPath) else {
            return host
        }
        var updated = host
        updated.flags.osGuess = updated.flags.osGuess ?? String(output.prefix(200))
        updated.evidence.append(
            EvidenceDraft(kind: .banner, summary: "SSH read-only uname", payload: output)
        )
        return updated
    }
}
