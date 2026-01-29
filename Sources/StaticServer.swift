import Foundation
import Vapor
import NIOSSL

class StaticServer {
    private var app: Application?
    private(set) var port: Int?
    private(set) var isRunning = false
    private(set) var isHTTPS = false
    let folderURL: URL

    init(folderURL: URL) {
        self.folderURL = folderURL
    }

    func start(https: Bool = false, certPath: String? = nil, keyPath: String? = nil, preferredPort: Int? = nil) throws -> Int {
        guard let port = PortManager.shared.acquirePort(preferred: preferredPort) else {
            throw ServerError.noPortAvailable
        }

        // Create Vapor app with minimal logging
        var env = Environment.production
        env.arguments = ["serve"]
        let app = Application(env)

        // Configure server
        app.http.server.configuration.hostname = "0.0.0.0"
        app.http.server.configuration.port = port

        // Configure TLS if requested
        if https, let certPath = certPath, let keyPath = keyPath {
            do {
                let certs = try NIOSSLCertificate.fromPEMFile(certPath)
                let privateKey = try NIOSSLPrivateKey(file: keyPath, format: .pem)

                var tlsConfig = TLSConfiguration.makeServerConfiguration(
                    certificateChain: certs.map { .certificate($0) },
                    privateKey: .privateKey(privateKey)
                )
                tlsConfig.certificateVerification = .none

                app.http.server.configuration.tlsConfiguration = tlsConfig
                self.isHTTPS = true
            } catch {
                print("TLS setup failed: \(error)")
                // Fall back to HTTP
                self.isHTTPS = false
            }
        } else {
            self.isHTTPS = false
        }

        // Serve static files
        let folderPath = folderURL.path

        // Catch-all route for file serving
        app.get("**") { req -> Response in
            let path = req.url.path
            let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

            let fileURL = cleanPath.isEmpty
                ? self.folderURL
                : self.folderURL.appendingPathComponent(cleanPath)

            return self.serveFileOrDirectory(at: fileURL, requestPath: path, req: req)
        }

        // Root route
        app.get { req -> Response in
            return self.serveFileOrDirectory(at: self.folderURL, requestPath: "/", req: req)
        }

        self.app = app
        self.port = port
        self.isRunning = true

        // Start server in background
        Task {
            do {
                try app.start()
            } catch {
                print("Server start error: \(error)")
            }
        }

        return port
    }

    private func serveFileOrDirectory(at url: URL, requestPath: String, req: Request) -> Response {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return Response(status: .notFound, body: .init(string: "Not Found"))
        }

        if isDirectory.boolValue {
            // Check for index.html in directory
            let indexURL = url.appendingPathComponent("index.html")
            if fileManager.fileExists(atPath: indexURL.path) {
                return serveFile(at: indexURL, req: req)
            }
            // Show directory listing
            return directoryListing(at: url, requestPath: requestPath)
        } else {
            return serveFile(at: url, req: req)
        }
    }

    private func serveFile(at url: URL, req: Request) -> Response {
        do {
            let data = try Data(contentsOf: url)
            let mimeType = mimeTypeForExtension(url.pathExtension)

            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: mimeType)

            return Response(status: .ok, headers: headers, body: .init(data: data))
        } catch {
            return Response(status: .internalServerError, body: .init(string: "Internal Server Error"))
        }
    }

    private func directoryListing(at url: URL, requestPath: String) -> Response {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            let displayPath = requestPath.isEmpty ? "/" : requestPath
            var html = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <title>Index of \(displayPath)</title>
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
                        padding: 40px;
                        max-width: 800px;
                        margin: 0 auto;
                        background: #f5f5f7;
                    }
                    h1 {
                        color: #1d1d1f;
                        font-weight: 600;
                        font-size: 24px;
                    }
                    .listing {
                        background: white;
                        border-radius: 12px;
                        overflow: hidden;
                        box-shadow: 0 1px 3px rgba(0,0,0,0.1);
                    }
                    .item {
                        display: flex;
                        align-items: center;
                        padding: 12px 16px;
                        border-bottom: 1px solid #f0f0f0;
                        text-decoration: none;
                        color: #1d1d1f;
                        transition: background 0.15s;
                    }
                    .item:hover { background: #f5f5f7; }
                    .item:last-child { border-bottom: none; }
                    .icon {
                        width: 20px;
                        margin-right: 12px;
                        text-align: center;
                        font-size: 16px;
                    }
                    .name { flex: 1; }
                    .folder { color: #007AFF; }
                    .parent { color: #86868b; }
                </style>
            </head>
            <body>
                <h1>Index of \(displayPath)</h1>
                <div class="listing">
            """

            // Add parent directory link if not at root
            if requestPath != "/" && !requestPath.isEmpty {
                let parentPath = (requestPath as NSString).deletingLastPathComponent
                html += """
                    <a class="item parent" href="\(parentPath.isEmpty ? "/" : parentPath)">
                        <span class="icon">..</span>
                        <span class="name">Parent Directory</span>
                    </a>
                """
            }

            for fileURL in contents.sorted(by: { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }) {
                let name = fileURL.lastPathComponent
                let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                let icon = isDir ? "📁" : fileIcon(for: fileURL.pathExtension)
                let href = requestPath.hasSuffix("/") ? "\(requestPath)\(name)" : "\(requestPath)/\(name)"
                let cssClass = isDir ? "item folder" : "item"

                html += """
                    <a class="\(cssClass)" href="\(href)">
                        <span class="icon">\(icon)</span>
                        <span class="name">\(name)\(isDir ? "/" : "")</span>
                    </a>
                """
            }

            html += """
                </div>
            </body>
            </html>
            """

            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "text/html; charset=utf-8")

            return Response(status: .ok, headers: headers, body: .init(string: html))
        } catch {
            return Response(status: .internalServerError, body: .init(string: "Internal Server Error"))
        }
    }

    private func fileIcon(for ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "🌐"
        case "css": return "🎨"
        case "js", "ts": return "📜"
        case "json": return "📋"
        case "md": return "📝"
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return "🖼"
        case "mp4", "mov", "avi": return "🎬"
        case "mp3", "wav", "m4a": return "🎵"
        case "pdf": return "📕"
        case "zip", "tar", "gz": return "📦"
        default: return "📄"
        }
    }

    private func mimeTypeForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html"
        case "css": return "text/css"
        case "js": return "application/javascript"
        case "json": return "application/json"
        case "xml": return "application/xml"
        case "txt": return "text/plain"
        case "md": return "text/markdown"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "ico": return "image/x-icon"
        case "mp4": return "video/mp4"
        case "webm": return "video/webm"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        case "ttf": return "font/ttf"
        case "otf": return "font/otf"
        case "pdf": return "application/pdf"
        case "zip": return "application/zip"
        default: return "application/octet-stream"
        }
    }

    func stop() {
        app?.shutdown()
        if let port = port {
            PortManager.shared.releasePort(port)
        }
        app = nil
        port = nil
        isRunning = false
        isHTTPS = false
    }
}

enum ServerError: Error, LocalizedError {
    case noPortAvailable
    case startFailed(String)

    var errorDescription: String? {
        switch self {
        case .noPortAvailable:
            return "No available port found"
        case .startFailed(let message):
            return "Failed to start server: \(message)"
        }
    }
}
