// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Recordly",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Recordly",
            path: "Sources/Recordly"
        )
    ]
)
