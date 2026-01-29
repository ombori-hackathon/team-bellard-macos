import Foundation

class BonjourService {
    private var process: Process?
    private(set) var isPublished = false

    let name: String
    let port: Int

    init(name: String, port: Int) {
        self.name = name
        self.port = port
    }

    func publish() async throws {
        // Use dns-sd -P to register both the service AND create hostname resolution
        // dns-sd -P <name> <type> <domain> <port> <hostname> <IP>
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/dns-sd")
        process.arguments = [
            "-P",
            name,
            "_http._tcp.",
            "local",
            String(port),
            "\(name).local",
            "127.0.0.1"
        ]

        // Suppress output
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        self.process = process

        do {
            try process.run()

            // Give it a moment to register
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            if process.isRunning {
                isPublished = true
                print("Bonjour: Published \(name).local -> 127.0.0.1:\(port)")
            } else {
                throw BonjourError.publishFailed(code: Int(process.terminationStatus))
            }
        } catch {
            throw BonjourError.publishFailed(code: -1)
        }
    }

    func stop() {
        if let process = process, process.isRunning {
            process.terminate()
        }
        process = nil
        isPublished = false
        print("Bonjour: Stopped \(name).local")
    }

    deinit {
        stop()
    }
}

enum BonjourError: Error, LocalizedError {
    case publishFailed(code: Int)

    var errorDescription: String? {
        switch self {
        case .publishFailed(let code):
            return "Failed to publish Bonjour service (error \(code))"
        }
    }
}
