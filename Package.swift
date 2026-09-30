// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScreenRecord",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ScreenRecord",
            path: "Sources/ScreenRecord"
        )
    ]
)
