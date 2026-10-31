// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MacResMon",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure logic (parsers, snapshot building): no UI, no processes.
        .target(name: "MonitorCore", swiftSettings: [.swiftLanguageMode(.v5)]),
        // The app: window, WKWebView, data collection loop.
        .executableTarget(name: "MacResMon", dependencies: ["MonitorCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
        // Unit checks for MonitorCore: `swift run CoreChecks`. (XCTest / Swift Testing need a full Xcode,
        // so this is a plain executable that exits non-zero on failure.)
        .executableTarget(name: "CoreChecks", dependencies: ["MonitorCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
