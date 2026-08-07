// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Turntable",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Turntable",
            path: "Sources/Turntable",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Resources/Info.plist"
                ])
            ]
        )
    ]
)
