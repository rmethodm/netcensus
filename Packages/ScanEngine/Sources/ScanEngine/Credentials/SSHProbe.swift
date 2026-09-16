import Foundation

public enum SSHProbe: Sendable {
    /// Fixed read-only remote script. Never take a user-supplied command.
    public static let remoteScript = "uname -a; cat /etc/os-release 2>/dev/null | head -5"

    public static func processArguments(host: String, username: String, keyPath: String) -> [String] {
        [
            "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ConnectTimeout=5",
            "-i", keyPath,
            "\(username)@\(host)",
            remoteScript,
        ]
    }

    public static func run(host: String, username: String, keyPath: String) async -> String? {
        let arguments = processArguments(host: host, username: username, keyPath: keyPath)
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: runBlocking(arguments: arguments))
            }
        }
    }

    private static func runBlocking(arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            return nil
        }
        let deadline = Date().addingTimeInterval(8)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            return nil
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let text = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : String(text.prefix(2_000))
    }
}
