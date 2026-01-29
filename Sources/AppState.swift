import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProjectId: UUID?

    private var servers: [UUID: StaticServer] = [:]
    private var bonjourServices: [UUID: BonjourService] = [:]

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
    }

    func removeProject(_ project: Project) {
        stopProject(project)
        projects.removeAll { $0.id == project.id }
    }

    func startProject(_ project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }

        projects[index].status = .starting

        let server = StaticServer(folderURL: project.folderURL)

        do {
            let port = try server.start()
            servers[project.id] = server
            projects[index].port = port
            projects[index].status = .running

            // Register mDNS/Bonjour for .local domain
            let sanitizedName = projects[index].sanitizedName
            Task {
                await registerBonjour(for: project.id, name: sanitizedName, port: port)
            }
        } catch {
            projects[index].status = .error(error.localizedDescription)
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

        projects[index].port = nil
        projects[index].status = .stopped
    }

    func toggleProject(_ project: Project) {
        if project.status == .running {
            stopProject(project)
        } else {
            startProject(project)
        }
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
