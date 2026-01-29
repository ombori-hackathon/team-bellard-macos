import Foundation

// MARK: - Project Model

struct Project: Identifiable {
    let id: UUID
    let folderURL: URL
    let name: String
    let sanitizedName: String

    var type: ProjectType
    var status: ProjectStatus
    var port: Int?

    var url: String? {
        guard let port = port else { return nil }
        return "http://\(sanitizedName).local:\(port)"
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
