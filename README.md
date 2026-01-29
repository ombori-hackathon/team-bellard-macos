# Serv

A native macOS menu bar application that lets you run any folder as a local web server with human-friendly `.local` domain names and HTTPS support.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## What is Serv?

Serv (pronounced "serve") is a lightweight macOS utility that makes local web development effortless. Simply drag and drop a folder, and Serv will:

- Serve it as a local HTTP or HTTPS server
- Assign a random available port (or reuse your preferred port)
- Register a `.local` domain name via mDNS/Bonjour
- Let you access it at `http://your-folder.local:port` or `https://your-folder.local:port`

No terminal commands. No configuration files. Just drag, drop, and browse.

## Features

### Core Features

- **Menu Bar App** - Lives in your menu bar like Docker Desktop, always accessible
- **Drag & Drop** - Add folders by dragging them into the app or using the file picker
- **Static File Server** - Serves any folder with proper MIME types for all common file formats
- **Directory Listing** - Beautiful file browser when no index.html is present
- **Local DNS (.local domains)** - Access projects via `project-name.local:port` instead of `localhost`
- **Multiple Projects** - Run multiple folders simultaneously, each on its own port
- **Auto Port Assignment** - Automatically finds available ports (8000-9999 range)

### HTTPS Support

- **One-Click HTTPS** - Toggle HTTPS on/off per project with the lock icon
- **Local CA Certificate** - Generates a trusted root CA on first use
- **Auto-Trusted Certificates** - Prompts for admin password to trust CA in system keychain
- **Per-Domain Certificates** - Automatically generates certificates for each project
- **No Browser Warnings** - Certificates are trusted by your system

### Persistence

- **Remember Projects** - Added folders persist across app restarts
- **Consistent Ports** - Same port assigned to each project every time
- **Save HTTPS Preference** - Remember which projects use HTTPS
- **Settings Location** - `~/Library/Application Support/Serv/projects.json`

### Project Detection

- **Node.js Detection** - Automatically detects Node.js projects (package.json)
- **Package Manager Detection** - Identifies yarn vs npm based on lock files

### Network Sharing

- **LAN Access** - Servers bind to `0.0.0.0`, accessible from other devices on your network
- **Share via IP** - Others can access via `http://your-ip:port`
- **mDNS Support** - `.local` domains work on macOS, iOS, and Linux (with Avahi)

### Graceful Shutdown

- **Clean Exit** - All servers stop properly when app quits
- **Port Release** - Ports are released back to the system
- **Service Cleanup** - Bonjour/mDNS services are unregistered

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
swift run Serv
```

## Usage

1. **Launch Serv** - The app appears in your menu bar (server rack icon)
2. **Add a folder** - Click the menu bar icon → "Open Serv" → Drag a folder or click "Browse..."
3. **Start serving** - Click the play button next to your project
4. **Access in browser** - Click "Open" or visit `http://folder-name.local:port`

### Enable HTTPS

1. Click the **lock icon** next to any project
2. First time only: Enter your admin password to trust the CA certificate
3. The project restarts with HTTPS enabled
4. Access via `https://folder-name.local:port`

### Menu Bar Quick Access

Click the menu bar icon to:
- See all your projects and their status
- Start/stop projects with one click
- Open projects in browser
- Access the main window

### Sharing with Others on Your Network

1. Find your IP: System Preferences → Network (or run `ipconfig getifaddr en0`)
2. Share the URL: `http://192.168.x.x:port`
3. Others on the same network can access your served files

## Architecture

```
Sources/
├── ServApp.swift           # App entry point, menu bar setup, graceful shutdown
├── ContentView.swift       # Main window UI
├── AppState.swift          # Centralized state management, persistence
├── Models.swift            # Data models (Project, SavedProject, enums)
├── StaticServer.swift      # HTTP/HTTPS server (Vapor-based)
├── CertificateManager.swift # CA and certificate generation
├── BonjourService.swift    # mDNS/.local domain registration
└── PortManager.swift       # Port allocation and tracking
```

### Dependencies

- [Vapor](https://github.com/vapor/vapor) - Swift web framework with TLS/HTTPS support

## How It Works

1. **HTTP/HTTPS Server**: Uses Vapor to create an embedded server that serves static files with optional TLS encryption
2. **Certificate Management**: Generates a local CA certificate (trusted in your keychain) and signs per-domain certificates using OpenSSL
3. **mDNS Registration**: Uses `dns-sd` to register the hostname with Bonjour, making `project-name.local` resolve to `127.0.0.1`
4. **Port Management**: Scans for available ports in the 8000-9999 range, remembers preferred ports per project
5. **Persistence**: Saves project list to JSON file in Application Support folder

## Project Types

### Static Folders
Any folder without a `package.json` is treated as a static site. Serv serves all files directly with appropriate MIME types.

### Node.js Projects (Detected)
Folders with `package.json` are identified as Node.js projects. Currently shows detection status; script execution coming in future updates.

## Supported File Types

Serv serves files with correct MIME types for:

| Category | Extensions |
|----------|------------|
| Web | `.html`, `.css`, `.js`, `.json`, `.xml` |
| Images | `.png`, `.jpg`, `.jpeg`, `.gif`, `.svg`, `.webp`, `.ico` |
| Fonts | `.woff`, `.woff2`, `.ttf`, `.otf` |
| Media | `.mp4`, `.webm`, `.mp3`, `.wav` |
| Documents | `.pdf`, `.txt`, `.md` |

## Certificate Storage

Certificates are stored in `~/Library/Application Support/Serv/`:

```
Serv/
├── ca-cert.pem          # Root CA certificate (trusted in keychain)
├── ca-key.pem           # Root CA private key
├── projects.json        # Saved project settings
└── certs/
    ├── project.local-cert.pem  # Per-domain certificate
    └── project.local-key.pem   # Per-domain private key
```

## Development

### Project Structure

This is part of the [team-bellard-ws](https://github.com/ombori-hackathon/team-bellard-ws) hackathon workspace.

### Building for Development

```bash
# Build in debug mode
swift build

# Run directly
swift run Serv

# Build for release
swift build -c release
```

### Specifications

See [SPEC.md](./SPEC.md) for detailed feature specifications and implementation phases.

## Planned Features

- **Node.js Script Runner** - Run npm/yarn scripts directly from the app
- **Dependency Installation** - One-click `npm install` or `yarn install`
- **Real-time Output** - View script output in the app
- **Auto-start** - Optionally start projects when app launches
- **Custom Ports** - Allow users to manually set preferred ports

## Contributing

1. Create a feature branch
2. Make your changes
3. Submit a pull request

## License

MIT License - see LICENSE file for details.

---

Built with SwiftUI and Vapor for the Ombori Hackathon 2026.
