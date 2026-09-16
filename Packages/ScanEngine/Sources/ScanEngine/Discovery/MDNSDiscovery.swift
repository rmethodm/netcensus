import Foundation
import Network

public struct MDNSRecord: Sendable, Equatable {
    public var ipv4: String?
    public var hostname: String
    public var serviceType: String

    public init(ipv4: String? = nil, hostname: String, serviceType: String) {
        self.ipv4 = ipv4
        self.hostname = hostname
        self.serviceType = serviceType
    }
}

public enum MDNSDiscovery: Sendable {
    public static let defaultTypes = [
        "_http._tcp",
        "_https._tcp",
        "_ssh._tcp",
        "_smb._tcp",
        "_airplay._tcp",
        "_ipp._tcp",
        "_printer._tcp",
        "_companion-link._tcp",
        "_hap._tcp",
        "_googlecast._tcp",
        "_device-info._tcp",
        "_sftp-ssh._tcp",
    ]

    public static func browse(
        duration: Duration = .seconds(2),
        types: [String] = defaultTypes
    ) async -> [MDNSRecord] {
        await withTaskGroup(of: [MDNSRecord].self) { group in
            for type in types {
                group.addTask {
                    await browseOne(type: type, duration: duration)
                }
            }
            var all: [MDNSRecord] = []
            for await batch in group {
                all.append(contentsOf: batch)
            }
            return unique(all)
        }
    }

    private static func browseOne(type: String, duration: Duration) async -> [MDNSRecord] {
        let browser = NWBrowser(for: .bonjour(type: type, domain: "local."), using: .tcp)
        let store = RecordStore()
        browser.browseResultsChangedHandler = { results, _ in
            Task {
                for result in results {
                    if let record = await resolve(result, type: type) {
                        await store.add(record)
                    }
                }
            }
        }
        browser.start(queue: .global())
        try? await Task.sleep(for: duration)
        browser.cancel()
        try? await Task.sleep(for: .milliseconds(80))
        return await store.snapshot()
    }

    private static func resolve(_ result: NWBrowser.Result, type: String) async -> MDNSRecord? {
        let hostname: String = {
            if case .service(let name, _, _, _) = result.endpoint { return name }
            return result.endpoint.debugDescription
        }()
        let ipv4 = await ipv4(for: result.endpoint)
        return MDNSRecord(ipv4: ipv4, hostname: hostname, serviceType: type)
    }

    private static func ipv4(for endpoint: NWEndpoint) async -> String? {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(to: endpoint, using: .tcp)
            let once = OnceFlag()
            let finish: @Sendable (String?) -> Void = { value in
                if once.take() {
                    connection.cancel()
                    continuation.resume(returning: value)
                }
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(ipv4String(connection.currentPath?.remoteEndpoint))
                case .failed, .cancelled:
                    finish(nil)
                default:
                    break
                }
            }
            connection.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(400)) {
                finish(ipv4String(connection.currentPath?.remoteEndpoint))
            }
        }
    }

    private static func ipv4String(_ endpoint: NWEndpoint?) -> String? {
        guard case .hostPort(let host, _) = endpoint else { return nil }
        if case .ipv4(let address) = host {
            let bytes = Array(address.rawValue.prefix(4))
            guard bytes.count == 4 else { return nil }
            return "\(bytes[0]).\(bytes[1]).\(bytes[2]).\(bytes[3])"
        }
        return nil
    }

    private static func unique(_ records: [MDNSRecord]) -> [MDNSRecord] {
        var seen: Set<String> = []
        return records.filter { record in
            let key = "\(record.ipv4 ?? "")|\(record.hostname)|\(record.serviceType)"
            return seen.insert(key).inserted
        }
    }
}

private actor RecordStore {
    private var records: [MDNSRecord] = []

    func add(_ record: MDNSRecord) {
        records.append(record)
    }

    func snapshot() -> [MDNSRecord] {
        records
    }
}
