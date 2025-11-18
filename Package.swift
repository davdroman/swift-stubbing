// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

let package = Package(
	name: "swift-stubbing",
	platforms: [
		.iOS(.v13),
		.macCatalyst(.v13),
		.macOS(.v10_15),
		.tvOS(.v13),
		.visionOS(.v1),
		.watchOS(.v6),
	],
	products: [
		.library(name: "Stubbing", targets: ["Stubbing"]),
	],
	dependencies: [],
	targets: [
		.target(
			name: "Stubbing",
			dependencies: [
				"StubMacro",
			]
		),
		.macro(
			name: "StubMacro",
			dependencies: [
				.product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
				.product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
			]
		),
		.testTarget(
			name: "StubbingTests",
			dependencies: [
				"Stubbing",
				"StubMacro",
				.product(name: "MacroTesting", package: "swift-macro-testing"),
				.product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
			]
		),
	]
)

package.dependencies += [
	.package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.6.0"),
	.package(url: "https://github.com/swiftlang/swift-syntax", "600.0.0"..<"603.0.0"),
]

for target in package.targets {
	target.swiftSettings = target.swiftSettings ?? []
	target.swiftSettings? += [
		.enableUpcomingFeature("ExistentialAny"),
		.enableUpcomingFeature("InternalImportsByDefault"),
	]
}
