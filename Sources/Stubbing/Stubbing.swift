/// Access levels supported by the `@Stub` macro.
public enum AccessLevel: String, Sendable {
	case `public`
	case `internal`
	case `package`
	case `fileprivate`
	case `private`
}

public struct BuildConfigurations: OptionSet, Sendable {
	public static let debug = Self(rawValue: 1 << 0)
	public static let release = Self(rawValue: 1 << 1)

	public let rawValue: Int
	public init(rawValue: Int) {
		self.rawValue = rawValue
	}
}

/// Synthesizes a memberwise initializer, a static `stub` factory, and empty preview/test helper structs
/// for use in debugging contexts.
///
/// - Parameters:
///   - accessLevel: Visibility applied to the generated `stub` method. Defaults to `.internal`.
///   - memberwiseInit: Visibility applied to the synthesized memberwise initializer. Defaults to `.internal`.
///   - in: Build configurations where the generated helpers should be emitted. Defaults to `.debug` only.
@attached(member, names: named(init), named(stub))
@attached(extension, names: named(PreviewValues), named(TestValues))
public macro Stub(
	_ accessLevel: AccessLevel = .internal,
	memberwiseInit: AccessLevel = .internal,
	in configurations: BuildConfigurations = .debug
) = #externalMacro(
	module: "StubMacro",
	type: "StubMacro"
)

/// Overrides the default value that the enclosing `@Stub` type uses when synthesizing its `stub` method.
@attached(peer)
public macro StubDefault<T>(_ value: T) = #externalMacro(
	module: "StubMacro",
	type: "StubDefaultMacro"
)
