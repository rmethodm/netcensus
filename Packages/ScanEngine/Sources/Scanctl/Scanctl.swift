import Foundation
import ScanEngine

@main
enum Scanctl {
    static func main() async {
        do {
            try await run(Array(CommandLine.arguments.dropFirst()))
        } catch let error as ScanctlError {
            fputs("error: \(error.description)\n", stderr)
            Foundation.exit(error.exitCode)
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }
    }

    static func run(_ args: [String]) async throws {
        guard let command = args.first else { throw ScanctlError.usage }
        switch command {
        case "scopes":
            try await printScopes()
        case "dogfood":
            try await dogfood(Array(args.dropFirst()))
        default:
            throw ScanctlError.usage
        }
    }

    private static func printScopes() async throws {
        let scopes = await LiveScanEngine().availableScopes()
        if scopes.isEmpty {
            print("No assessable IPv4 scopes.")
            return
        }
        for scope in scopes {
            print("\(scope.interfaceName)\t\(scope.cidr)\thosts=\(scope.estimatedHostCount)")
        }
    }

    private static func dogfood(_ args: [String]) async throws {
        let options = try DogfoodOptions.parse(args)
        let engine = LiveScanEngine()
        let scope = try await selectScope(engine)
        let collected = try await collect(engine: engine, scope: scope, profile: options.profile)
        let report = ScanReport(
            interfaceName: scope.interfaceName,
            cidr: scope.cidr,
            profile: options.profile.rawValue,
            summary: collected.summary,
            hosts: collected.hosts.sorted { ($0.identity.ipv4 ?? "") < ($1.identity.ipv4 ?? "") }
        )
        let result = try DogfoodArchive.write(report: report, to: options.out)
        print("hosts=\(report.hosts.count) findings=\(report.findingCount)")
        print("wrote \(result.latestURL.path)")
        let changed = result.drift.filter { $0.status != .unchanged }
        if !changed.isEmpty {
            print("drift=\(changed.count)")
        }
    }

    private static func selectScope(_ engine: LiveScanEngine) async throws -> NetworkScopeDraft {
        let scopes = await engine.availableScopes()
        if let ethernet = scopes.first(where: { $0.interfaceName.hasPrefix("en") && $0.isAssessable }) {
            return ethernet
        }
        if let any = scopes.first(where: \.isAssessable) {
            return any
        }
        throw ScanctlError.noScope
    }

    private static func collect(
        engine: LiveScanEngine,
        scope: NetworkScopeDraft,
        profile: ScanProfile
    ) async throws -> (hosts: [HostDraft], summary: ScanSummary?) {
        var hosts: [HostDraft] = []
        var summary: ScanSummary?
        for await event in await engine.events(for: ScanConfiguration(scope: scope, profile: profile)) {
            switch event {
            case .hostDiscovered(let host), .hostUpdated(let host):
                hosts.removeAll { $0.id == host.id }
                hosts.append(host)
            case .completed(let value):
                summary = value
            case .failed(let message):
                throw ScanctlError.scanFailed(message)
            case .cancelled:
                throw ScanctlError.scanFailed("cancelled")
            default:
                break
            }
        }
        return (hosts, summary)
    }
}

struct DogfoodOptions {
    var profile: ScanProfile
    var out: URL

    static func parse(_ args: [String]) throws -> DogfoodOptions {
        var authorized = false
        var profile = ScanProfile.standard
        var out = DogfoodArchive.defaultDirectory()
        var index = 0
        while index < args.count {
            switch args[index] {
            case "--i-am-authorized":
                authorized = true
            case "--profile":
                index += 1
                guard index < args.count, let parsed = ScanProfile(rawValue: args[index]) else {
                    throw ScanctlError.usage
                }
                profile = parsed
            case "--out":
                index += 1
                guard index < args.count else { throw ScanctlError.usage }
                out = URL(fileURLWithPath: args[index], isDirectory: true)
            default:
                throw ScanctlError.usage
            }
            index += 1
        }
        guard authorized else { throw ScanctlError.notAuthorized }
        return DogfoodOptions(profile: profile, out: out)
    }
}

enum ScanctlError: Error, CustomStringConvertible {
    case usage
    case notAuthorized
    case noScope
    case scanFailed(String)

    var exitCode: Int32 {
        switch self {
        case .usage, .notAuthorized: 2
        case .noScope, .scanFailed: 1
        }
    }

    var description: String {
        switch self {
        case .usage:
            "usage: scanctl scopes | scanctl dogfood --i-am-authorized [--profile quick|standard|full] [--out dir]"
        case .notAuthorized:
            "\(AuthorizationCopy.confirmation) Pass --i-am-authorized to scan the attached private subnet."
        case .noScope:
            "No assessable private IPv4 interface."
        case .scanFailed(let message):
            message
        }
    }
}
