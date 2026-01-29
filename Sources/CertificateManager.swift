import Foundation
import Security

class CertificateManager {
    static let shared = CertificateManager()

    private let appSupportDir: URL
    private let caKeyPath: URL
    private let caCertPath: URL
    private let certsDir: URL

    private(set) var isCAInstalled = false

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        appSupportDir = appSupport.appendingPathComponent("Serv")
        caKeyPath = appSupportDir.appendingPathComponent("ca-key.pem")
        caCertPath = appSupportDir.appendingPathComponent("ca-cert.pem")
        certsDir = appSupportDir.appendingPathComponent("certs")

        // Create directories if needed
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: certsDir, withIntermediateDirectories: true)

        // Check if CA exists AND is trusted
        isCAInstalled = FileManager.default.fileExists(atPath: caCertPath.path) && isCAInKeychain()
    }

    // MARK: - CA Management

    func setupCA() async throws {
        // Generate CA if it doesn't exist
        if !FileManager.default.fileExists(atPath: caCertPath.path) {
            try await generateCA()
        }

        // Check if CA is trusted
        if !isCAInKeychain() {
            try await trustCA()
        }

        isCAInstalled = true
    }

    private func generateCA() async throws {
        // Generate CA private key
        let keyGenProcess = Process()
        keyGenProcess.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        keyGenProcess.arguments = [
            "genrsa",
            "-out", caKeyPath.path,
            "4096"
        ]
        keyGenProcess.standardOutput = FileHandle.nullDevice
        keyGenProcess.standardError = FileHandle.nullDevice

        try keyGenProcess.run()
        keyGenProcess.waitUntilExit()

        guard keyGenProcess.terminationStatus == 0 else {
            throw CertificateError.caGenerationFailed
        }

        // Generate CA certificate
        let certGenProcess = Process()
        certGenProcess.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        certGenProcess.arguments = [
            "req",
            "-x509",
            "-new",
            "-nodes",
            "-key", caKeyPath.path,
            "-sha256",
            "-days", "3650",
            "-out", caCertPath.path,
            "-subj", "/C=US/ST=Local/L=Local/O=Serv Local CA/CN=Serv Local Development CA"
        ]
        certGenProcess.standardOutput = FileHandle.nullDevice
        certGenProcess.standardError = FileHandle.nullDevice

        try certGenProcess.run()
        certGenProcess.waitUntilExit()

        guard certGenProcess.terminationStatus == 0 else {
            throw CertificateError.caGenerationFailed
        }

        print("CA generated at: \(caCertPath.path)")
    }

    private func isCAInKeychain() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = [
            "find-certificate",
            "-c", "Serv Local Development CA",
            "/Library/Keychains/System.keychain"
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try? process.run()
        process.waitUntilExit()

        return process.terminationStatus == 0
    }

    func trustCA() async throws {
        // Use AppleScript to run with admin privileges - prompts user for password
        let script = """
        do shell script "security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain '\(caCertPath.path)'" with administrator privileges
        """

        let appleScript = Process()
        appleScript.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        appleScript.arguments = ["-e", script]

        let errorPipe = Pipe()
        appleScript.standardError = errorPipe
        appleScript.standardOutput = FileHandle.nullDevice

        do {
            try appleScript.run()
            appleScript.waitUntilExit()
        } catch {
            throw CertificateError.caTrustFailed
        }

        if appleScript.terminationStatus != 0 {
            // Try login keychain as fallback (no admin needed, but user-specific)
            let loginKeychain = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Keychains/login.keychain-db").path

            let loginProcess = Process()
            loginProcess.executableURL = URL(fileURLWithPath: "/usr/bin/security")
            loginProcess.arguments = [
                "add-trusted-cert",
                "-r", "trustRoot",
                "-k", loginKeychain,
                caCertPath.path
            ]

            do {
                try loginProcess.run()
                loginProcess.waitUntilExit()
                if loginProcess.terminationStatus == 0 {
                    return
                }
            } catch {
                // Fall through to error
            }

            throw CertificateError.caTrustFailed
        }
    }

    // MARK: - Project Certificates

    func getCertificate(for domain: String) async throws -> (certPath: String, keyPath: String) {
        let certPath = certsDir.appendingPathComponent("\(domain)-cert.pem")
        let keyPath = certsDir.appendingPathComponent("\(domain)-key.pem")

        // Return existing cert if valid
        if FileManager.default.fileExists(atPath: certPath.path),
           FileManager.default.fileExists(atPath: keyPath.path) {
            return (certPath.path, keyPath.path)
        }

        // Generate new certificate
        try await generateCertificate(for: domain, certPath: certPath, keyPath: keyPath)

        return (certPath.path, keyPath.path)
    }

    private func generateCertificate(for domain: String, certPath: URL, keyPath: URL) async throws {
        // Generate private key
        let keyGenProcess = Process()
        keyGenProcess.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        keyGenProcess.arguments = [
            "genrsa",
            "-out", keyPath.path,
            "2048"
        ]
        keyGenProcess.standardOutput = FileHandle.nullDevice
        keyGenProcess.standardError = FileHandle.nullDevice

        try keyGenProcess.run()
        keyGenProcess.waitUntilExit()

        guard keyGenProcess.terminationStatus == 0 else {
            throw CertificateError.certGenerationFailed
        }

        // Create CSR
        let csrPath = certsDir.appendingPathComponent("\(domain)-csr.pem")
        let csrProcess = Process()
        csrProcess.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        csrProcess.arguments = [
            "req",
            "-new",
            "-key", keyPath.path,
            "-out", csrPath.path,
            "-subj", "/C=US/ST=Local/L=Local/O=Serv/CN=\(domain)"
        ]
        csrProcess.standardOutput = FileHandle.nullDevice
        csrProcess.standardError = FileHandle.nullDevice

        try csrProcess.run()
        csrProcess.waitUntilExit()

        guard csrProcess.terminationStatus == 0 else {
            throw CertificateError.certGenerationFailed
        }

        // Create extension file for SAN
        let extPath = certsDir.appendingPathComponent("\(domain)-ext.cnf")
        let extContent = """
        authorityKeyIdentifier=keyid,issuer
        basicConstraints=CA:FALSE
        keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
        subjectAltName = @alt_names

        [alt_names]
        DNS.1 = \(domain)
        DNS.2 = localhost
        IP.1 = 127.0.0.1
        """
        try extContent.write(to: extPath, atomically: true, encoding: .utf8)

        // Sign with CA
        let signProcess = Process()
        signProcess.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        signProcess.arguments = [
            "x509",
            "-req",
            "-in", csrPath.path,
            "-CA", caCertPath.path,
            "-CAkey", caKeyPath.path,
            "-CAcreateserial",
            "-out", certPath.path,
            "-days", "365",
            "-sha256",
            "-extfile", extPath.path
        ]
        signProcess.standardOutput = FileHandle.nullDevice
        signProcess.standardError = FileHandle.nullDevice

        try signProcess.run()
        signProcess.waitUntilExit()

        guard signProcess.terminationStatus == 0 else {
            throw CertificateError.certGenerationFailed
        }

        // Cleanup temp files
        try? FileManager.default.removeItem(at: csrPath)
        try? FileManager.default.removeItem(at: extPath)

        print("Certificate generated for: \(domain)")
    }

    // MARK: - Helpers

    var caExists: Bool {
        FileManager.default.fileExists(atPath: caCertPath.path)
    }
}

enum CertificateError: Error, LocalizedError {
    case caGenerationFailed
    case caTrustFailed
    case certGenerationFailed

    var errorDescription: String? {
        switch self {
        case .caGenerationFailed:
            return "Failed to generate CA certificate"
        case .caTrustFailed:
            return "Failed to trust CA certificate. Please try again with admin privileges."
        case .certGenerationFailed:
            return "Failed to generate project certificate"
        }
    }
}
