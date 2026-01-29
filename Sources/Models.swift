import Foundation

// MARK: - Saved Project (for persistence)

struct SavedProject: Codable {
    let folderPath: String
    let useHTTPS: Bool
    let preferredPort: Int?

    init(from project: Project) {
        self.folderPath = project.folderURL.path
        self.useHTTPS = project.useHTTPS
        self.preferredPort = project.port
    }
}

// MARK: - Project Model

struct Project: Identifiable {
    let id: UUID
    let folderURL: URL
    let name: String
    let sanitizedName: String

    var type: ProjectType
    var status: ProjectStatus
    var port: Int?
    var useHTTPS: Bool

    var url: String? {
        guard let port = port else { return nil }
        let scheme = useHTTPS ? "https" : "http"
        return "\(scheme)://\(sanitizedName).local:\(port)"
    }

    // Node.js specific
    var packageManager: PackageManager?
    var scripts: [String: String]?
    var selectedScript: String?
    var hasNodeModules: Bool

    init(folderURL: URL) {
        self.id = UUID()
        self.folderURL = folderURL
        self.name = folderURL.lastPathComponent
        self.sanitizedName = Project.sanitizeName(folderURL.lastPathComponent)
        self.type = .static
        self.status = .stopped
        self.port = nil
        self.useHTTPS = false
        self.packageManager = nil
        self.scripts = nil
        self.selectedScript = nil
        self.hasNodeModules = false
    }

    init(from saved: SavedProject) {
        let url = URL(fileURLWithPath: saved.folderPath)
        self.id = UUID()
        self.folderURL = url
        self.name = url.lastPathComponent
        self.sanitizedName = Project.sanitizeName(url.lastPathComponent)
        self.type = .static
        self.status = .stopped
        self.port = saved.preferredPort
        self.useHTTPS = saved.useHTTPS
        self.packageManager = nil
        self.scripts = nil
        self.selectedScript = nil
        self.hasNodeModules = false
    }

    static func sanitizeName(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}

enum ProjectType: String {
    case `static` = "Static"
    case nodejs = "Node.js"
}

enum ProjectStatus: Equatable {
    case stopped
    case starting
    case running
    case error(String)

    var displayText: String {
        switch self {
        case .stopped: return "Stopped"
        case .starting: return "Starting..."
        case .running: return "Running"
        case .error(let message): return "Error: \(message)"
        }
    }

    var color: String {
        switch self {
        case .stopped: return "gray"
        case .starting: return "orange"
        case .running: return "green"
        case .error: return "red"
        }
    }
}

enum PackageManager: String {
    case npm = "npm"
    case yarn = "yarn"
}
