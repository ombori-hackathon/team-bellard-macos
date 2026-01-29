// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Serv",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0")
    ],
    targets: [
        .executableTarget(
            name: "Serv",
            dependencies: [
                .product(name: "Vapor", package: "vapor")
            ],
            path: "Sources"
        ),
    ]
)
