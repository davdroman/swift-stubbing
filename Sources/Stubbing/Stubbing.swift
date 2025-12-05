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

/// Synthesizes a static `stub` factory, an instance `stub` helper, and empty preview/test helper structs
/// for use in debugging contexts. When no access level is provided, the generated APIs match the access
/// level of the annotated type.
///
/// - Parameter configurations: Build configurations where the generated helpers should be emitted. Defaults to `.debug` only.
@attached(member, names: named(stub))
@attached(extension, names: named(PreviewValues), named(TestValues))
public macro Stub(
	in configurations: BuildConfigurations = .debug
) = #externalMacro(
	module: "StubMacro",
	type: "StubMacro"
)

/// Synthesizes stub helpers with an explicit access level override.
@attached(member, names: named(stub))
@attached(extension, names: named(PreviewValues), named(TestValues))
public macro Stub(
	_ accessLevel: AccessLevel,
	in configurations: BuildConfigurations = .debug
) = #externalMacro(
	module: "StubMacro",
	type: "StubMacro"
)

/// Synthesizes a memberwise initializer matching the access level of the annotated type.
@attached(member, names: named(init))
public macro MemberwiseInit() = #externalMacro(
	module: "StubMacro",
	type: "MemberwiseInitMacro"
)

/// Synthesizes a memberwise initializer that uses a custom access level.
@attached(member, names: named(init))
public macro MemberwiseInit(
	_ accessLevel: AccessLevel
) = #externalMacro(
	module: "StubMacro",
	type: "MemberwiseInitMacro"
)

/// Overrides the default value that the enclosing `@Stub` type uses when synthesizing its `stub` method.
@attached(peer)
public macro StubDefault<T>(_ value: T) = #externalMacro(
	module: "StubMacro",
	type: "StubDefaultMacro"
)
