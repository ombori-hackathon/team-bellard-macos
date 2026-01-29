import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var appState: AppState
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Serv")
                    .font(.title.bold())
                Spacer()
                Text("\(appState.projects.filter { $0.status == .running }.count) running")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Drop Zone
            DropZoneView(isTargeted: $isDropTargeted) { urls in
                for url in urls {
                    appState.addProject(folderURL: url)
                }
            }
            .frame(height: appState.projects.isEmpty ? 200 : 120)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, appState.projects.isEmpty ? 0 : 12)

            if !appState.projects.isEmpty {
                // Project List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(appState.projects) { project in
                            ProjectCard(project: project, appState: appState)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }

            Spacer()
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

// MARK: - Drop Zone

struct DropZoneView: View {
    @Binding var isTargeted: Bool
    let onDrop: ([URL]) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .foregroundColor(isTargeted ? .accentColor : .secondary.opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                )

            VStack(spacing: 12) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 40))
                    .foregroundColor(isTargeted ? .accentColor : .secondary)

                Text("Drag & Drop Folders Here")
                    .font(.headline)
                    .foregroundColor(isTargeted ? .accentColor : .secondary)

                Button("Browse...") {
                    selectFolder()
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.title = "Select Folder"

        if panel.runModal() == .OK {
            onDrop(panel.urls)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil),
                   url.hasDirectoryPath {
                    DispatchQueue.main.async {
                        onDrop([url])
                    }
                }
            }
        }
    }
}

// MARK: - Project Card

struct ProjectCard: View {
    let project: Project
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Folder icon and name
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)

                Text(project.name)
                    .font(.headline)

                // Project type badge
                Text(project.type.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(project.type == .nodejs ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                    .foregroundColor(project.type == .nodejs ? .green : .blue)
                    .cornerRadius(4)

                Spacer()

                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                // Start/Stop button
                Button(action: {
                    appState.toggleProject(project)
                }) {
                    Image(systemName: project.status == .running ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.bordered)

                // Remove button
                Button(action: {
                    appState.removeProject(project)
                }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }

            // Path
            Text(project.folderURL.path)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            // URL when running
            if let url = project.url, project.status == .running {
                HStack {
                    Text(url)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.accentColor)

                    Spacer()

                    Button("Open") {
                        if let nsUrl = URL(string: url) {
                            NSWorkspace.shared.open(nsUrl)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url, forType: .string)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            // Error message
            if case .error(let message) = project.status {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
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
