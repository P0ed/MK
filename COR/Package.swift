// swift-tools-version: 6.4

import PackageDescription

let package = Package(
	name: "COR",
	platforms: [.iOS(.v27), .macOS(.v27)],
	products: [.library(name: "COR", targets: ["COR"])],
	targets: [
		.target(name: "COR", path: "Sources"),
		.testTarget(name: "CORTests", dependencies: ["COR"], path: "Tests"),
	]
)
