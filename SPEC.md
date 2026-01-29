# Serv - Native macOS Web Server App

## Overview

**Serv** is a native macOS menu bar application that allows users to run any folder as a local web server with human-friendly local DNS names and HTTPS support. The app supports both static file serving and intelligent Node.js project detection with dependency management and script execution.

**No backend required** - this is a pure Swift/SwiftUI application.

---

## Decisions Made

| Decision | Choice |
|----------|--------|
| **App Name** | Serv |
| **Multiple Projects** | Yes, run simultaneously |
| **Port Strategy** | Auto-assigned, persisted per project, user-editable |
| **URL Format** | `http(s)://project-name.local:port` |
| **HTTP Library** | Vapor (with TLS support) |
| **App Style** | Menu bar app (like Docker Desktop) |

---

## Implementation Status

### Completed Features

| Feature | Status | Notes |
|---------|--------|-------|
| Folder Selection (drag & drop + picker) | ✅ Done | |
| Static File Server | ✅ Done | Vapor-based |
| Directory Listing | ✅ Done | Styled HTML listing |
| Auto Port Assignment | ✅ Done | 8000-9999 range |
| Local DNS (.local domains) | ✅ Done | dns-sd based mDNS |
| Multiple Projects | ✅ Done | Each with own server |
| Menu Bar App | ✅ Done | Docker Desktop style |
| HTTPS Support | ✅ Done | Local CA + per-domain certs |
| Persistence | ✅ Done | ~/Library/Application Support/Serv/ |
| Consistent Ports | ✅ Done | Same port on restart |
| Project Editing | ✅ Done | Edit name and port |
| Graceful Shutdown | ✅ Done | Clean exit on quit |
| Network Sharing | ✅ Done | LAN accessible (0.0.0.0) |
| Node.js Detection | ✅ Done | Detects package.json |
| Package Manager Detection | ✅ Done | yarn.lock vs package-lock.json |

### Pending Features

| Feature | Status | Notes |
|---------|--------|-------|
| Dependency Installation | ⏳ Pending | npm/yarn install |
| Script Execution | ⏳ Pending | Run npm scripts |
| Real-time Output | ⏳ Pending | Show script output |
| Auto-start on Launch | ⏳ Pending | Optional preference |

---

## Core Concept

Users can drag or select any folder, and the app will:
1. Serve it as a local HTTP or HTTPS server on a persisted port
2. Make it accessible via a pretty local URL like `project-name.local:port`
3. Support multiple projects running simultaneously, each with its own port
4. For Node.js projects: detect package manager and show project info

---

## Features

### Feature 1: Folder Selection ✅ COMPLETED
**Description:** Allow users to pick or drag any folder into the app.

**Implementation:**
- SwiftUI `onDrop` modifier for drag-and-drop
- `NSOpenPanel` for folder picker via "Browse..." button
- Multiple folders supported simultaneously
- Folders persist across app restarts

---

### Feature 2: Static File Server ✅ COMPLETED
**Description:** Serve the selected folder under a local web server.

**Implementation:**
- Vapor framework for HTTP/HTTPS server
- Auto-assign available port (8000-9999 range)
- Proper MIME types for all common file formats
- Directory listing with styled HTML when no index.html
- Open in browser and copy URL buttons

---

### Feature 3: Local DNS with Pretty Names ✅ COMPLETED
**Description:** Access projects via human-friendly URLs like `movies-shop.local:8742`.

**Implementation:**
- Folder names sanitized for DNS (lowercase, hyphens)
- `dns-sd -P` command for mDNS/Bonjour registration
- Registers both service AND hostname-to-IP mapping
- Works on macOS, iOS, Linux (with Avahi)

---

### Feature 4: Node.js Project Detection ✅ COMPLETED
**Description:** Automatically identify if the selected folder is a Node.js project.

**Implementation:**
- Checks for `package.json` in folder root
- Parses package.json to extract scripts
- Detects package manager (yarn.lock vs package-lock.json)
- Shows "Node.js" badge in UI

---

### Feature 5: Menu Bar App ✅ COMPLETED
**Description:** Run as a menu bar application like Docker Desktop.

**Implementation:**
- MenuBarExtra with server rack icon
- Shows running project count in menu bar
- Quick access to start/stop projects
- Open in browser directly from menu
- Full window available via "Open Serv"

---

### Feature 6: HTTPS Support ✅ COMPLETED
**Description:** Serve projects over HTTPS with locally-trusted certificates.

**Implementation:**
- Generates root CA certificate on first HTTPS use
- Prompts for admin password to trust CA in System Keychain
- Auto-generates per-domain certificates signed by CA
- Certificates include SAN for .local, localhost, 127.0.0.1
- Toggle HTTPS per project with lock icon
- Certificates stored in `~/Library/Application Support/Serv/`

---

### Feature 7: Persistence ✅ COMPLETED
**Description:** Remember all added projects across app restarts.

**Implementation:**
- Projects saved to `~/Library/Application Support/Serv/projects.json`
- Stores: folder path, HTTPS preference, assigned port, custom name
- Auto-saves on any change
- Restores projects on app launch (if folders still exist)

---

### Feature 8: Consistent Port Assignment ✅ COMPLETED
**Description:** Each project always runs on the same port.

**Implementation:**
- Port persisted per project
- Tries preferred port first on start
- Falls back to random if preferred unavailable
- Port preserved when stopping/starting

---

### Feature 9: Project Editing ✅ COMPLETED
**Description:** Allow users to edit project name and port.

**Implementation:**
- Pencil icon opens edit popover
- Custom name changes the .local domain
- Port can be set to any value (1024-65535)
- Changes auto-save and restart server if running

---

### Feature 10: Graceful Shutdown ✅ COMPLETED
**Description:** Clean shutdown when app quits.

**Implementation:**
- AppDelegate observes app termination
- Stops all running Vapor servers
- Releases ports back to system
- Unregisters Bonjour/mDNS services

---

### Feature 11: Network Sharing ✅ COMPLETED
**Description:** Allow access from other devices on the same network.

**Implementation:**
- Servers bind to `0.0.0.0` (all interfaces)
- Accessible via machine's IP address + port
- .local domains work on devices with mDNS support

---

### Feature 12: Dependency Installation ⏳ PENDING
**Description:** For Node.js projects, prompt users to install dependencies.

**Planned:**
- Check for node_modules folder
- Prompt to run yarn install / npm install
- Show installation progress in UI

---

### Feature 13: Script Execution ⏳ PENDING
**Description:** Run npm/yarn scripts from the app.

**Planned:**
- List available scripts from package.json
- Run selected script
- Real-time output display
- Process management (stop/restart)

---

## User Interface

### Menu Bar
```
┌──────────────────────────────┐
│ 🖥 Serv                      │
├──────────────────────────────┤
│ ● movies-shop     :8742  ▶️ ➡️│
│ ○ portfolio       :9156  ▶️   │
├──────────────────────────────┤
│ Open Serv                    │
│ Quit Serv                    │
└──────────────────────────────┘
```

### Main Window
```
┌─────────────────────────────────────────────────────────────┐
│  🖥 Serv                                    1 running        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │         Drop folders here                           │   │
│  │              [Browse]                               │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 📁 movies-shop ✏️  [Node.js] [HTTPS]    🔒 ● ▶️ ✕   │   │
│  │    /Users/john/projects/movies-shop                 │   │
│  │    https://movies-shop.local:8742                   │   │
│  │                                    [Open] [Copy]    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 📁 portfolio ✏️  [Static]            🔓 ○ ▶️ ✕      │   │
│  │    /Users/john/sites/portfolio                      │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Technical Stack

| Component | Technology |
|-----------|------------|
| UI Framework | SwiftUI |
| HTTP/HTTPS Server | Vapor (with NIOSSL) |
| Local DNS | dns-sd (mDNS/Bonjour) |
| Certificate Generation | OpenSSL (via Process) |
| Keychain Trust | security command (via AppleScript) |
| Process Management | Foundation `Process` class |
| JSON Parsing | Swift `Codable` / `JSONDecoder` |
| File System | Foundation `FileManager` |
| Persistence | JSON file in Application Support |

---

## Architecture

```
Sources/
├── ServApp.swift            # App entry, MenuBarExtra, graceful shutdown
├── ContentView.swift        # Main window UI, project cards, edit popover
├── AppState.swift           # State management, persistence, project operations
├── Models.swift             # Project, SavedProject, enums
├── StaticServer.swift       # Vapor HTTP/HTTPS server
├── CertificateManager.swift # CA generation, certificate signing
├── BonjourService.swift     # mDNS registration via dns-sd
└── PortManager.swift        # Port allocation and tracking
```

---

## Data Models

```swift
struct SavedProject: Codable {
    let folderPath: String
    let useHTTPS: Bool
    let preferredPort: Int?
    let customName: String?
}

struct Project: Identifiable {
    let id: UUID
    let folderURL: URL
    var customName: String?

    var name: String          // customName ?? folderURL.lastPathComponent
    var sanitizedName: String // DNS-safe name

    var type: ProjectType     // .static or .nodejs
    var status: ProjectStatus // .stopped, .starting, .running, .error
    var port: Int?
    var useHTTPS: Bool

    var url: String?          // http(s)://name.local:port

    // Node.js specific
    var packageManager: PackageManager?
    var scripts: [String: String]?
    var hasNodeModules: Bool
}
```

---

## File Storage

```
~/Library/Application Support/Serv/
├── projects.json            # Saved project list
├── ca-cert.pem              # Root CA certificate
├── ca-key.pem               # Root CA private key
├── ca-cert.srl              # CA serial number
└── certs/
    ├── project.local-cert.pem   # Per-domain certificate
    └── project.local-key.pem    # Per-domain private key
```

---

## Implementation Phases

### Phase 1: Basic Static Server ✅ COMPLETED
- [x] Project setup (rename app to Serv)
- [x] Folder selection (drag & drop + picker)
- [x] Embedded HTTP server to serve static files
- [x] Auto-assign available port
- [x] Display URL, open in browser, copy URL

### Phase 2: Local DNS ✅ COMPLETED
- [x] mDNS/Bonjour integration via dns-sd
- [x] Register `project-name.local` pointing to assigned port
- [x] Handle multiple simultaneous registrations

### Phase 3: Multi-Project Support ✅ COMPLETED
- [x] UI for multiple running projects
- [x] Project cards with status, URL, controls
- [x] Start/stop individual projects

### Phase 4: Menu Bar App ✅ COMPLETED
- [x] MenuBarExtra with icon and running count
- [x] Quick project list with start/stop
- [x] Open in browser from menu bar

### Phase 5: HTTPS Support ✅ COMPLETED
- [x] Switch from Swifter to Vapor for TLS
- [x] CA certificate generation
- [x] Keychain trust via AppleScript
- [x] Per-domain certificate generation
- [x] HTTPS toggle per project

### Phase 6: Persistence & Port Management ✅ COMPLETED
- [x] Save projects to JSON file
- [x] Restore on app launch
- [x] Consistent port per project
- [x] User-editable name and port

### Phase 7: Node.js Detection ✅ COMPLETED
- [x] Detect package.json
- [x] Parse and display project info
- [x] Detect package manager

### Phase 8: Graceful Shutdown ✅ COMPLETED
- [x] Stop all servers on app quit
- [x] Release ports
- [x] Unregister Bonjour services

### Phase 9: Dependency Management ⏳ PENDING
- [ ] Check for node_modules
- [ ] Run install command with output
- [ ] Progress/spinner during installation

### Phase 10: Script Execution ⏳ PENDING
- [ ] List available scripts from package.json
- [ ] Run selected script
- [ ] Real-time output display
- [ ] Process management (stop/restart)

---

## Related Files

- Swift client location: `apps/macos-client/`
- README: `apps/macos-client/README.md`

---

*Last updated: 2026-01-29*
