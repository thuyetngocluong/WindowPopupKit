// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WindowPopupKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "WindowPopupKit", targets: ["WindowPopupKit"])
    ],
    targets: [
        .target(name: "WindowPopupKit"),
        .testTarget(
            name: "WindowPopupKitTests",
            dependencies: ["WindowPopupKit"]
        )
    ],
    swiftLanguageModes: [.v5]
)
