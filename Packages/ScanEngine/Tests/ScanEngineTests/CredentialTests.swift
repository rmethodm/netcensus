import Testing
@testable import ScanEngine

struct CredentialMatchTests {
    @Test func hostScopeMatchesExactIP() {
        var credential = ScanCredential(
            kind: .snmpv2c,
            label: "lab",
            target: "192.168.1.20",
            scope: .host
        )
        credential.secret = "private"
        #expect(credential.matches(hostIP: "192.168.1.20"))
        #expect(!credential.matches(hostIP: "192.168.1.21"))
    }

    @Test func subnetScopeMatchesCIDR() {
        let credential = ScanCredential(
            kind: .sshKey,
            label: "lab net",
            target: "10.0.0.0/24",
            scope: .subnet
        )
        #expect(credential.matches(hostIP: "10.0.0.15"))
        #expect(!credential.matches(hostIP: "10.0.1.15"))
    }
}

struct HTTPBasicAuthTests {
    @Test func authorizationHeaderIsBasicAndDoesNotEmbedRawPasswordInClearPrefix() {
        let value = HTTPBasicAuth.authorizationValue(username: "admin", password: "s3cret")
        #expect(value.hasPrefix("Basic "))
        #expect(!value.contains("s3cret"))
        let request = String(
            decoding: HTTPBasicAuth.getRequest(host: "192.168.1.1", username: "admin", password: "s3cret"),
            as: UTF8.self
        )
        #expect(request.contains("Authorization: Basic "))
        #expect(request.contains("GET / HTTP/1.0"))
    }
}

struct SSHProbeTests {
    @Test func argumentsUseFixedRemoteScriptAndNoUserCommandSlot() {
        let arguments = SSHProbe.processArguments(
            host: "192.168.1.10",
            username: "admin",
            keyPath: "/tmp/id_ed25519"
        )
        #expect(arguments.last == SSHProbe.remoteScript)
        #expect(arguments.contains("admin@192.168.1.10"))
        #expect(arguments.contains("-i"))
        #expect(!arguments.contains { $0.contains(";") && $0 != SSHProbe.remoteScript })
    }
}
