// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Windowed",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Windowed",
            path: "Sources/WebShell",
            linkerSettings: [
                .linkedFramework("WebKit")
            ]
        )
    ]
)
