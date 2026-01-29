import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProjectId: UUID?
    @Published var isSettingUpHTTPS = false
    @Published var httpsSetupError: String?

    private var servers: [UUID: StaticServer] = [:]
    private var bonjourServices: [UUID: BonjourService] = [:]

    private let settingsURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let servDir = appSupport.appendingPathComponent("Serv")
        try? FileManager.default.createDirectory(at: servDir, withIntermediateDirectories: true)
        return servDir.appendingPathComponent("projects.json")
    }()

    init() {
        loadProjects()
    }

    // MARK: - Persistence

    private func loadProjects() {
        guard FileManager.default.fileExists(atPath: settingsURL.path),
              let data = try? Data(contentsOf: settingsURL),
              let savedProjects = try? JSONDecoder().decode([SavedProject].self, from: data) else {
            return
        }

        for saved in savedProjects {
            let url = URL(fileURLWithPath: saved.folderPath)
            // Only restore if folder still exists
            guard FileManager.default.fileExists(atPath: url.path) else { continue }

            var project = Project(from: saved)

            // Detect Node.js project
            let packageJsonURL = url.appendingPathComponent("package.json")
            if FileManager.default.fileExists(atPath: packageJsonURL.path) {
                project.type = .nodejs
                detectPackageManager(for: &project)
                parsePackageJson(for: &project)
            }

            projects.append(project)
        }
    }

    private func saveProjects() {
        let savedProjects = projects.map { SavedProject(from: $0) }
        if let data = try? JSONEncoder().encode(savedProjects) {
            try? data.write(to: settingsURL)
        }
    }

    func addProject(folderURL: URL) {
        // Check if project already exists
        if projects.contains(where: { $0.folderURL == folderURL }) {
            return
        }

        var project = Project(folderURL: folderURL)

        // Detect Node.js project
        let packageJsonURL = folderURL.appendingPathComponent("package.json")
        if FileManager.default.fileExists(atPath: packageJsonURL.path) {
            project.type = .nodejs
            detectPackageManager(for: &project)
            parsePackageJson(for: &project)
        }

        projects.append(project)
        saveProjects()
    }

    func removeProject(_ project: Project) {
        stopProject(project)
        projects.removeAll { $0.id == project.id }
        saveProjects()
    }

    func stopAllProjects() {
        for project in projects where project.status == .running {
            stopProject(project)
        }
    }

    func updateProject(_ project: Project, name: String?, port: Int?) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }

        let wasRunning = projects[index].status == .running

        // Stop if running (port change requires restart)
        if wasRunning {
            stopProject(project)
        }

        // Update name
        if let name = name, !name.isEmpty {
            projects[index].customName = name
        }

        // Update port
        if let port = port, port >= 1024 && port <= 65535 {
            projects[index].port = port
        }

        saveProjects()

        // Restart if was running
        if wasRunning {
            startProject(projects[index])
        }
    }

    func startProject(_ project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }

        projects[index].status = .starting

        let server = StaticServer(folderURL: project.folderURL)
        let useHTTPS = projects[index].useHTTPS
        let preferredPort = projects[index].port

        Task {
            do {
                var certPath: String?
                var keyPath: String?

                if useHTTPS {
                    // Get certificate for this domain
                    let domain = projects[index].sanitizedName + ".local"
                    let certs = try await CertificateManager.shared.getCertificate(for: domain)
                    certPath = certs.certPath
                    keyPath = certs.keyPath
                }

                let port = try server.start(https: useHTTPS, certPath: certPath, keyPath: keyPath, preferredPort: preferredPort)
                servers[project.id] = server
                projects[index].port = port
                projects[index].status = .running
                saveProjects()

                // Register mDNS/Bonjour for .local domain
                let sanitizedName = projects[index].sanitizedName
                await registerBonjour(for: project.id, name: sanitizedName, port: port)
            } catch {
                projects[index].status = .error(error.localizedDescription)
            }
        }
    }

    private func registerBonjour(for projectId: UUID, name: String, port: Int) async {
        let bonjour = BonjourService(name: name, port: port)
        bonjourServices[projectId] = bonjour

        do {
            try await bonjour.publish()
        } catch {
            print("Failed to register Bonjour for \(name): \(error)")
            // Don't fail the project - localhost still works
        }
    }

    func stopProject(_ project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }

        // Stop HTTP server
        if let server = servers[project.id] {
            server.stop()
            servers.removeValue(forKey: project.id)
        }

        // Stop Bonjour service
        if let bonjour = bonjourServices[project.id] {
            bonjour.stop()
            bonjourServices.removeValue(forKey: project.id)
        }

        // Keep port for reuse on next start
        projects[index].status = .stopped
    }

    func toggleProject(_ project: Project) {
        if project.status == .running {
            stopProject(project)
        } else {
            startProject(project)
        }
    }

    func toggleHTTPS(for project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }

        let wasRunning = projects[index].status == .running

        // Stop if running
        if wasRunning {
            stopProject(project)
        }

        // Toggle HTTPS
        projects[index].useHTTPS.toggle()
        saveProjects()

        // If enabling HTTPS for the first time, ensure CA is set up
        if projects[index].useHTTPS {
            Task {
                await setupHTTPSIfNeeded()

                // Restart if was running
                if wasRunning {
                    startProject(projects[index])
                }
            }
        } else if wasRunning {
            // Restart with HTTP
            startProject(projects[index])
        }
    }

    func setupHTTPSIfNeeded() async {
        guard !CertificateManager.shared.isCAInstalled else { return }

        isSettingUpHTTPS = true
        httpsSetupError = nil

        do {
            try await CertificateManager.shared.setupCA()
        } catch {
            httpsSetupError = error.localizedDescription
        }

        isSettingUpHTTPS = false
    }

    private func detectPackageManager(for project: inout Project) {
        let yarnLockURL = project.folderURL.appendingPathComponent("yarn.lock")
        let npmLockURL = project.folderURL.appendingPathComponent("package-lock.json")
        let nodeModulesURL = project.folderURL.appendingPathComponent("node_modules")

        if FileManager.default.fileExists(atPath: yarnLockURL.path) {
            project.packageManager = .yarn
        } else if FileManager.default.fileExists(atPath: npmLockURL.path) {
            project.packageManager = .npm
        } else {
            project.packageManager = .npm // default
        }

        project.hasNodeModules = FileManager.default.fileExists(atPath: nodeModulesURL.path)
    }

    private func parsePackageJson(for project: inout Project) {
        let packageJsonURL = project.folderURL.appendingPathComponent("package.json")

        guard let data = try? Data(contentsOf: packageJsonURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        if let scripts = json["scripts"] as? [String: String] {
            project.scripts = scripts
        }
    }
}
