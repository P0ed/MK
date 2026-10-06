// swift-tools-version: 6.0

import PackageDescription

let package = Package(
	name: "SoundGen",
	products: [.executable(name: "soundgen", targets: ["SoundGen"])],
	targets: [
		.target(name: "SoundSynthesis"),
		.executableTarget(name: "SoundGen", dependencies: ["SoundSynthesis"]),
		.testTarget(name: "SoundSynthesisTests", dependencies: ["SoundSynthesis"]),
	]
)
