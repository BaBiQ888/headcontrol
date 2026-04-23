// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HeadControl",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "HeadControl",
            path: "Sources/HeadControl",
            exclude: ["Info.plist"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                // Embed Info.plist into the binary so macOS shows the camera-permission prompt
                // for a plain SwiftPM executable. Path is resolved from the package root.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/HeadControl/Info.plist"
                ])
            ]
        )
    ]
)
