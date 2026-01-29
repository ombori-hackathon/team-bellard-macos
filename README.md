# Xrve

A native macOS menu bar application that lets you run any folder as a local web server with human-friendly `.local` domain names.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## What is Xrve?

Xrve (pronounced "serve") is a lightweight macOS utility that makes local web development effortless. Simply drag and drop a folder, and Xrve will:

- Serve it as a local HTTP server
- Assign a random available port
- Register a `.local` domain name via mDNS/Bonjour
- Let you access it at `http://your-folder.local:port`

No terminal commands. No configuration files. Just drag, drop, and browse.

## Features

### Current Features (v1.0)

- **Menu Bar App** - Lives in your menu bar like Docker Desktop, always accessible
- **Drag & Drop** - Add folders by dragging them into the app or using the file picker
- **Static File Server** - Serves any folder with proper MIME types for all common file formats
- **Directory Listing** - Beautiful file browser when no index.html is present
- **Local DNS (.local domains)** - Access projects via `project-name.local:port` instead of `localhost`
- **Multiple Projects** - Run multiple folders simultaneously, each on its own port
- **Auto Port Assignment** - Automatically finds available ports (8000-9999 range)
- **Node.js Detection** - Automatically detects Node.js projects (package.json)
- **Package Manager Detection** - Identifies yarn vs npm based on lock files
- **Quick Actions** - Open in browser, copy URL, start/stop with one click

### Planned Features

- **Persistent Projects** - Remember added folders across app restarts
- **Consistent Ports** - Same port assigned to each project every time
- **Custom Ports** - Allow users to manually set preferred ports
- **Node.js Script Runner** - Run npm/yarn scripts directly from the app
- **Dependency Installation** - One-click `npm install` or `yarn install`
- **Real-time Output** - View script output in the app
- **Auto-start** - Optionally start projects when app launches

## Installation

### Requirements

- macOS 13.0 (Ventura) or later
- Swift 5.9+

### Build from Source

```bash
# Clone the repository
git clone https://github.com/ombori-hackathon/team-bellard-macos.git
cd team-bellard-macos

# Build
swift build

# Run
swift run Xrve
```

## Usage

1. **Launch Xrve** - The app appears in your menu bar (server rack icon)
2. **Add a folder** - Click the menu bar icon → "Open Xrve" → Drag a folder or click "Browse..."
3. **Start serving** - Click the play button next to your project
4. **Access in browser** - Click "Open" or visit `http://folder-name.local:port`

### Menu Bar Quick Access

Click the menu bar icon to:
- See all your projects and their status
- Start/stop projects with one click
- Open projects in browser
- Access the main window

## Architecture

```
Sources/
├── XrveApp.swift        # App entry point, menu bar setup
├── ContentView.swift    # Main window UI
├── AppState.swift       # Centralized state management
├── Models.swift         # Data models (Project, enums)
├── StaticServer.swift   # HTTP server (Swifter-based)
├── BonjourService.swift # mDNS/.local domain registration
└── PortManager.swift    # Port allocation and tracking
```

### Dependencies

- [Swifter](https://github.com/httpswift/swifter) - Lightweight HTTP server

## How It Works

1. **HTTP Server**: Uses Swifter to create an embedded HTTP server that serves static files from the selected folder
2. **mDNS Registration**: Uses `dns-sd` to register the hostname with Bonjour, making `project-name.local` resolve to `127.0.0.1`
3. **Port Management**: Scans for available ports in the 8000-9999 range and tracks which ports are in use

## Project Types

### Static Folders
Any folder without a `package.json` is treated as a static site. Xrve serves all files directly with appropriate MIME types.

### Node.js Projects (Detected)
Folders with `package.json` are identified as Node.js projects. Currently shows detection status; script execution coming in future updates.

## Supported File Types

Xrve serves files with correct MIME types for:

| Category | Extensions |
|----------|------------|
| Web | `.html`, `.css`, `.js`, `.json`, `.xml` |
| Images | `.png`, `.jpg`, `.jpeg`, `.gif`, `.svg`, `.webp`, `.ico` |
| Fonts | `.woff`, `.woff2`, `.ttf`, `.otf` |
| Media | `.mp4`, `.webm`, `.mp3`, `.wav` |
| Documents | `.pdf`, `.txt`, `.md` |

## Development

### Project Structure

This is part of the [team-bellard-ws](https://github.com/ombori-hackathon/team-bellard-ws) hackathon workspace.

### Building for Development

```bash
# Build in debug mode
swift build

# Run directly
swift run Xrve

# Build for release
swift build -c release
```

### Specifications

See [SPEC.md](./SPEC.md) for detailed feature specifications and implementation phases.

## Contributing

1. Create a feature branch
2. Make your changes
3. Submit a pull request

## License

MIT License - see LICENSE file for details.

---

Built with SwiftUI for the Ombori Hackathon 2026.
