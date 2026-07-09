// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "VirtualDisplayTests",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "VirtualDisplayCore", targets: ["VirtualDisplayCore"]),
        .library(name: "VDCTLCore", targets: ["VDCTLCore"]),
    ],
    targets: [
        .target(
            name: "VirtualDisplayCore",
            path: "VirtualDisplay",
            exclude: [
                "main.swift",
                "AppDelegate.swift",
                "MenuBuilder.swift",
                "DisplayActionHandler.swift",
                "DisplaySheetController.swift",
                "Info.plist",
                "VirtualDisplay.entitlements",
                "Assets.xcassets",
                "Resources",
            ],
            swiftSettings: [
                .unsafeFlags(["-import-objc-header", "VirtualDisplay/VirtualDisplay-Bridging-Header.h"])
            ]
        ),
        .target(
            name: "VDCTLCore",
            dependencies: ["VirtualDisplayCore"],
            path: "vdctl",
            exclude: ["main.swift"]
        ),
    ]
)
