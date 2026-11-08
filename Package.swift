// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SerbianVehicleKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "SerbianVehicleKit", targets: ["SerbianVehicleKit"]),
    ],
    targets: [
        .target(name: "SerbianVehicleKit"),
        .testTarget(
            name: "SerbianVehicleKitTests",
            dependencies: ["SerbianVehicleKit"]
        ),
    ]
)
