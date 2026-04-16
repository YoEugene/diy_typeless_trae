// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceInline",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "VoiceInline",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("UserNotifications"),
            ]
        )
    ]
)
