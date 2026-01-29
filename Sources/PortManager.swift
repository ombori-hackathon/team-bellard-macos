import Foundation

class PortManager {
    static let shared = PortManager()

    private var usedPorts: Set<Int> = []
    private let portRange = 8000...9999

    private init() {}

    func acquirePort(preferred: Int? = nil) -> Int? {
        // Try preferred port first
        if let preferred = preferred,
           portRange.contains(preferred),
           !usedPorts.contains(preferred),
           isPortAvailable(preferred) {
            usedPorts.insert(preferred)
            return preferred
        }

        // Fall back to any available port
        for port in portRange.shuffled() {
            if !usedPorts.contains(port) && isPortAvailable(port) {
                usedPorts.insert(port)
                return port
            }
        }
        return nil
    }

    func releasePort(_ port: Int) {
        usedPorts.remove(port)
    }

    private func isPortAvailable(_ port: Int) -> Bool {
        let socketFD = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        if socketFD == -1 {
            return false
        }
        defer { close(socketFD) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        return bindResult == 0
    }
}
