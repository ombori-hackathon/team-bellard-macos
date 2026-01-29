import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?

    func applicationWillTerminate(_ notification: Notification) {
        appState?.stopAllProjects()
    }
}

@main
struct ServApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    init() {
        // Set as accessory app (menu bar) but can show windows
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        // Menu Bar
        MenuBarExtra {
            MenuBarView(appState: appState)
                .onAppear {
                    appDelegate.appState = appState
                }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "server.rack")
                let runningCount = appState.projects.filter { $0.status == .running }.count
                if runningCount > 0 {
                    Text("\(runningCount)")
                        .font(.caption2)
                }
            }
        }
        .menuBarExtraStyle(.window)

        // Main Window
        Window("Serv", id: "main") {
            ContentView(appState: appState)
                .onAppear {
                    appDelegate.appState = appState
                }
        }
        .defaultSize(width: 600, height: 500)
        .windowStyle(.titleBar)
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Serv")
                    .font(.headline)
                Spacer()
                let runningCount = appState.projects.filter { $0.status == .running }.count
                Text("\(runningCount) running")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if appState.projects.isEmpty {
                Text("No projects")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(appState.projects) { project in
                            MenuBarProjectRow(project: project, appState: appState)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 300)
            }

            Divider()

            // Actions
            VStack(spacing: 0) {
                Button(action: {
                    openWindow(id: "main")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }) {
                    HStack {
                        Image(systemName: "macwindow")
                        Text("Open Serv")
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                Divider()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit Serv")
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 280)
    }
}

// MARK: - Menu Bar Project Row

struct MenuBarProjectRow: View {
    let project: Project
    @ObservedObject var appState: AppState

    var body: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            // Name
            Text(project.name)
                .lineLimit(1)

            Spacer()

            // URL / Port
            if let port = project.port, project.status == .running {
                Text(":\(port)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Open button
                Button(action: {
                    if let urlString = project.url, let url = URL(string: urlString) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.borderless)
            }

            // Toggle button
            Button(action: {
                appState.toggleProject(project)
            }) {
                Image(systemName: project.status == .running ? "stop.fill" : "play.fill")
                    .foregroundColor(project.status == .running ? .red : .green)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch project.status {
        case .stopped: return .gray
        case .starting: return .orange
        case .running: return .green
        case .error: return .red
        }
    }
}
