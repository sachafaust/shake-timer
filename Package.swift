// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ShakeTimer",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "ShakeTimer", targets: ["ShakeTimer"]),
        .executable(name: "ShakeTimerCoreChecks", targets: ["ShakeTimerCoreChecks"])
    ],
    targets: [
        .target(
            name: "ShakeTimerCore",
            path: "Sources/ShakeTimerCore"
        ),
        .executableTarget(
            name: "ShakeTimer",
            dependencies: ["ShakeTimerCore"],
            path: "Sources/ShakeTimer"
        ),
        .executableTarget(
            name: "ShakeTimerCoreChecks",
            dependencies: ["ShakeTimerCore"],
            path: "Sources/ShakeTimerCoreChecks"
        )
    ]
)
