# Xrve - Native macOS Web Server App

## Overview

**Xrve** is a native macOS application that allows users to run any folder as a local web server with human-friendly local DNS names. The app supports both static file serving and intelligent Node.js project detection with dependency management and script execution.

**No backend required** - this is a pure Swift/SwiftUI application.

---

## Decisions Made

| Decision | Choice |
|----------|--------|
| **App Name** | Xrve |
| **Multiple Projects** | Yes, run simultaneously |
| **Port Strategy** | Auto-assigned random available ports |
| **URL Format** | `project-name.local:port` (e.g., `movies-shop.local:8742`) |

---

## Core Concept

Users can drag or select any folder, and the app will:
1. Serve it as a local web server on a randomly assigned port
2. Make it accessible via a pretty local URL like `project-name.local:port`
3. Support multiple projects running simultaneously, each with its own port
4. For Node.js projects: detect, install dependencies, and run scripts

---

## Features

### Feature 1: Folder Selection
**Description:** Allow users to pick or drag any folder into the app.

**Details:**
- Drag and drop support in the main window
- File picker button to browse and select folders
- Display selected folder path and name
- Support adding multiple folders (multiple projects)
- Remember recently used folders (optional enhancement)

**Technical approach:**
- SwiftUI `onDrop` modifier for drag-and-drop
- `NSOpenPanel` for folder picker
- Store folder paths in app state (array of projects)

---

### Feature 2: Static File Server
**Description:** Serve the selected folder under a local web server.

**Details:**
- Start an HTTP server on a randomly assigned available port
- Serve all files from the selected folder
- Support common MIME types (HTML, CSS, JS, images, JSON, etc.)
- Show server status (running/stopped) per project
- Display the local URL to access the server
- Button to open in default browser
- Button to copy URL to clipboard

**Technical approach:**
- Use Swift NIO, Swifter, or Vapor for embedded HTTP server
- Auto-assign available port (scan for free port)
- Serve index.html by default for directory roots
- Each project gets its own server instance

---

### Feature 3: Local DNS with Pretty Names
**Description:** Access projects via human-friendly URLs like `movies-shop.local:8742`.

**Details:**
- Derive the local hostname from the folder name
- Sanitize folder names for DNS compatibility (lowercase, replace spaces with hyphens)
- Register the hostname via mDNS/Bonjour
- Each project gets its own `.local` domain with its assigned port
- Example: folder "Movies Shop" on port 8742 → `movies-shop.local:8742`

**Technical approach:**
- Use `NetService` (Bonjour/mDNS) to publish each service
- `.local` domain is handled by macOS mDNS resolver automatically
- Each project registers its own mDNS name pointing to its port

---

### Feature 4: Node.js Project Detection
**Description:** Automatically identify if the selected folder is a Node.js project.

**Details:**
- Check for presence of `package.json` in the folder root
- Parse `package.json` to extract:
  - Project name
  - Available scripts
  - Dependencies info
- Update UI to show "Node.js Project Detected" indicator
- Switch to Node.js mode with additional options

**Technical approach:**
- File system check for `package.json`
- Swift `JSONDecoder` to parse package.json
- Store parsed data in project state

---

### Feature 5: Dependency Installation Prompt
**Description:** For Node.js projects, prompt users to install dependencies using the appropriate package manager.

**Details:**
- Detect package manager by checking for lock files:
  - `yarn.lock` present → use Yarn
  - `package-lock.json` present → use npm
  - Neither present → default to npm (or ask user)
- Check if `node_modules` folder exists
- If no `node_modules`, prompt user: "Dependencies not installed. Run [yarn install / npm install]?"
- Show installation progress/output in the app
- Handle installation errors gracefully

**Technical approach:**
- File system checks for lock files and node_modules
- `Process` class to spawn `yarn install` or `npm install`
- Capture stdout/stderr and display in UI
- Show spinner/progress during installation

---

### Feature 6: Script Selection and Execution
**Description:** Show users a list of available npm scripts and run the selected one.

**Details:**
- Parse `scripts` section from `package.json`
- Display scripts in a list/dropdown (e.g., `dev`, `start`, `build`, `serve`)
- Common scripts to highlight: `dev`, `start`, `serve` (likely to start a dev server)
- On selection, run the script: `yarn <script>` or `npm run <script>`
- Capture and display script output in real-time
- The running dev server should be accessible via `project-name.local:port`
- Show stop button to terminate the running script

**Technical approach:**
- Parse `scripts` object from package.json
- `Process` class to run commands
- Pipe stdout/stderr to UI in real-time
- Track process ID to allow termination
- Detect port from script output (e.g., "listening on port 3000")
- Register mDNS name pointing to the detected port

---

## User Interface Concept

```
┌─────────────────────────────────────────────────────────────┐
│  Xrve                                               [─][□][×] │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                                                     │   │
│  │         Drag & Drop Folders Here                   │   │
│  │                                                     │   │
│  │              or [Browse...]                         │   │
│  │                                                     │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ─────────────────────────────────────────────────────────  │
│  Running Projects (2)                                       │
│  ─────────────────────────────────────────────────────────  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 📁 movies-shop                              [■ Stop] │   │
│  │    Type: Node.js (yarn)                              │   │
│  │    Script: dev                                       │   │
│  │    URL: http://movies-shop.local:8742               │   │
│  │    [Open] [Copy URL]                                 │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 📁 portfolio                                [■ Stop] │   │
│  │    Type: Static                                      │   │
│  │    URL: http://portfolio.local:9156                 │   │
│  │    [Open] [Copy URL]                                 │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ─────────────────────────────────────────────────────────  │
│  Output: movies-shop                           [Clear]      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ $ yarn dev                                          │   │
│  │ VITE v5.0.0  ready in 500ms                        │   │
│  │ ➜  Local:   http://localhost:3000/                 │   │
│  │ ➜  Network: http://192.168.1.10:3000/              │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Node.js Project Setup Flow

```
┌─────────────────────────────────────────────────────────────┐
│  Xrve - Setup: movies-shop                                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  📁 /Users/john/projects/movies-shop                       │
│                                                             │
│  ✓ Node.js project detected (package.json)                 │
│  ✓ Package manager: yarn (yarn.lock found)                 │
│  ⚠ Dependencies not installed (node_modules missing)       │
│                                                             │
│  [Install Dependencies]                                     │
│                                                             │
│  ─────────────────────────────────────────────────────────  │
│                                                             │
│  Select a script to run:                                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ ● dev      - vite                                   │   │
│  │ ○ build    - vite build                             │   │
│  │ ○ preview  - vite preview                           │   │
│  │ ○ test     - vitest                                 │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  [▶ Start Project]                      [Cancel]            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Technical Stack

| Component | Technology |
|-----------|------------|
| UI Framework | SwiftUI |
| HTTP Server | Swift NIO / Swifter / Vapor (embedded) |
| Local DNS | NetService (Bonjour/mDNS) |
| Process Management | Foundation `Process` class |
| JSON Parsing | Swift `Codable` / `JSONDecoder` |
| File System | Foundation `FileManager` |

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                       SwiftUI Views                          │
│  (MainView, DropZone, ProjectCard, SetupSheet, OutputLog)   │
└──────────────────────────┬───────────────────────────────────┘
                           │
┌──────────────────────────┴───────────────────────────────────┐
│                      View Models                             │
│  (AppState, ProjectViewModel)                                │
│  - Manages list of active projects                           │
│  - Each project has its own state                            │
└──────────────────────────┬───────────────────────────────────┘
                           │
┌──────────────────────────┴───────────────────────────────────┐
│                       Services                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ HTTPServer   │  │ DNSService   │  │ ProcessRunner    │   │
│  │ (per project)│  │ (per project)│  │ (npm/yarn)       │   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ ProjectDetector (package.json, lock files, etc.)     │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ PortManager (finds available ports, tracks usage)    │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

---

## Data Models

```swift
struct Project: Identifiable {
    let id: UUID
    let folderURL: URL
    let name: String           // Derived from folder name
    let sanitizedName: String  // DNS-safe name (lowercase, hyphens)

    var type: ProjectType      // .static or .nodejs
    var status: ProjectStatus  // .stopped, .starting, .running, .error
    var port: Int?             // Assigned port when running
    var url: String?           // Full URL (e.g., "http://name.local:port")

    // Node.js specific
    var packageManager: PackageManager?  // .npm or .yarn
    var scripts: [String: String]?       // From package.json
    var selectedScript: String?
    var hasNodeModules: Bool
}

enum ProjectType {
    case static
    case nodejs
}

enum ProjectStatus {
    case stopped
    case starting
    case running
    case error(String)
}

enum PackageManager {
    case npm
    case yarn
}
```

---

## Implementation Phases

### Phase 1: Basic Static Server
- [x] Project setup (rename app to Xrve)
- [ ] Folder selection (drag & drop + picker)
- [ ] Embedded HTTP server to serve static files
- [ ] Auto-assign available port
- [ ] Display URL, open in browser

### Phase 2: Local DNS
- [ ] mDNS/Bonjour integration
- [ ] Register `project-name.local` pointing to assigned port
- [ ] Handle multiple simultaneous registrations

### Phase 3: Multi-Project Support
- [ ] UI for multiple running projects
- [ ] Project cards with status, URL, controls
- [ ] Start/stop individual projects

### Phase 4: Node.js Detection
- [ ] Detect package.json
- [ ] Parse and display project info
- [ ] Detect package manager (yarn.lock vs package-lock.json)

### Phase 5: Dependency Management
- [ ] Check for node_modules
- [ ] Run install command with output
- [ ] Progress/spinner during installation

### Phase 6: Script Execution
- [ ] List available scripts from package.json
- [ ] Run selected script
- [ ] Real-time output display
- [ ] Detect port from output
- [ ] Process management (stop/restart)

### Phase 7: Persistence & Port Management
- [ ] Remember added folders across app restarts
- [ ] Assign consistent port per project (same port each time)
- [ ] Allow users to manually change/customize port per project
- [ ] Store project settings (folder path, assigned port, preferences)

### Phase 8: Polish
- [ ] Error handling
- [ ] Edge cases
- [ ] UI refinements
- [ ] Auto-start projects on app launch (optional)

---

## Confirmed Features (To Implement)

### Feature 7: Persistence
**Description:** Remember all added projects across app restarts.

**Details:**
- Save project list to disk (UserDefaults or JSON file)
- On app launch, restore all previously added projects
- Projects remain in stopped state until user starts them
- Remove project = remove from persistence

**Technical approach:**
- Use `UserDefaults` or `~/Library/Application Support/Xrve/projects.json`
- Store: folder path, assigned port, project type, preferences

---

### Feature 8: Consistent Port Assignment
**Description:** Each project always runs on the same port (unless user changes it).

**Details:**
- First time a project is added, assign a random available port
- Save this port assignment persistently
- On subsequent runs, use the same port
- If port is occupied, show error and offer to pick a new one
- Allow users to manually change port via UI (settings per project)

**Technical approach:**
- Store port in project persistence data
- On start: check if assigned port is available
- If not available: prompt user (use different port or wait)
- Add "Change Port" option in project card UI

---

## Open Questions (Remaining)

1. **Static server for Node.js projects:**
   - If user selects a Node.js project but wants to serve it statically (e.g., a built `dist` folder), should we offer both options?

---

## Related Files

- Swift client location: `apps/macos-client/`
- This spec: `specs/2025-01-29-local-web-server-app.md`

---

*Last updated: 2025-01-29*
