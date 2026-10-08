// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Sugoso",
    platforms: [
        .macOS(.v13)   // MenuBarExtra requires macOS 13+
    ],
    products: [
        // The shared core - one source of truth that the app (and any other
        // executable) builds on instead of duplicating the code.
        .library(name: "SugosoCore", targets: ["SugosoCore"])
    ],
    targets: [
        .target(
            name: "SugosoCore",
            path: "Sources/SugosoCore"
        ),
        // The app: a thin executable over SugosoCore. The product stays named
        // "Sugoso" so the build/sign/install scripts need no changes.
        .executableTarget(
            name: "Sugoso",
            dependencies: ["SugosoCore"],
            path: "Sources/Sugoso"
        )
    ]
)
