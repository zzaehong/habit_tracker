// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ChagokCore", platforms: [.iOS(.v18), .macOS(.v14)], products: [.library(name: "ChagokCore", targets: ["ChagokCore"])], targets: [.target(name: "CZip", linkerSettings: [.linkedLibrary("z")]), .target(name: "ChagokCore", dependencies: ["CZip"]), .testTarget(name: "ChagokCoreTests", dependencies: ["ChagokCore"])])
