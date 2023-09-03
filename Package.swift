// swift-tools-version: 5.4

import PackageDescription

let package = Package(
	name: "Furl",
	products: [
		.library(
			name: "Furl",
			targets: ["Furl"]),
	],
	targets: [
		.target(
			name: "Furl"),
		.testTarget(
			name: "FurlTests",
			dependencies: ["Furl"]),
	]
)
