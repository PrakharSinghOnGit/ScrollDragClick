// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScrollClick",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ScrollClick", targets: ["ScrollClick"])
    ],
    targets: [
        .executableTarget(
            name: "ScrollClick",
            path: "Sources/ScrollClick"
        )
    ]
)
