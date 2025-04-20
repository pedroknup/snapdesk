// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "snapdesk",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.1"),
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.1.3")
    ],
    targets: [
        .target(
            name: "snapdesk",
            dependencies: [
                "Yams",
                "HotKey"
            ]
        )
    ]
) 