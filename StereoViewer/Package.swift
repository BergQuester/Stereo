// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StereoViewer",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "StereoViewer", targets: ["StereoViewer"])
    ],
    targets: [
        .target(name: "StereoViewer")
    ]
)
