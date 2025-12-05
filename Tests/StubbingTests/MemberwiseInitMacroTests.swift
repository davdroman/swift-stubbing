#if canImport(StubMacro)
import MacroTesting
import Testing
@testable import StubMacro

@Suite(
	.macros(
		[
			"MemberwiseInit": MemberwiseInitMacro.self,
			"Stub": StubMacro.self,
		],
		indentationWidth: .tab,
		record: .missing
	)
)
struct MemberwiseInitMacroTests {
	@Test func respectsExplicitAccessOverride() {
		assertMacro {
			"""
			@MemberwiseInit(.public)
			public struct Example {
				public var name: String
				public var age: Int
			}
			"""
		} expansion: {
			"""
			public struct Example {
				public var name: String
				public var age: Int

				public init(
					name: String,
					age: Int
				) {
					self.name = name
					self.age = age
				}
			}
			"""
		}
	}

	@Test func defaultsToAttacheeAccess() {
		assertMacro {
			"""
			@MemberwiseInit
			public struct Example {
				public var name: String
			}
			"""
		} expansion: {
			"""
			public struct Example {
				public var name: String

				public init(
					name: String
				) {
					self.name = name
				}
			}
			"""
		}
	}

	@Test func usesPropertyDefaults() {
		assertMacro {
			"""
			@MemberwiseInit
			struct Example {
				var count: Int = 3
				var name: String? = nil
			}
			"""
		} expansion: {
			"""
			struct Example {
				var count: Int = 3
				var name: String? = nil

				internal init(
					count: Int = 3,
					name: String? = nil
				) {
					self.count = count
					self.name = name
				}
			}
			"""
		}
	}

	@Test func mirrorsImplicitInternalAccess() {
		assertMacro {
			"""
			@MemberwiseInit
			struct Example {
				var name: String
			}
			"""
		} expansion: {
			"""
			struct Example {
				var name: String

				internal init(
					name: String
				) {
					self.name = name
				}
			}
			"""
		}
	}

	@Test func mirrorsExplicitInternalAccess() {
		assertMacro {
			"""
			@MemberwiseInit
			internal struct Example {
				var name: String
			}
			"""
		} expansion: {
			"""
			internal struct Example {
				var name: String

				internal init(
					name: String
				) {
					self.name = name
				}
			}
			"""
		}
	}

	@Test func mirrorsPackageAccess() {
		assertMacro {
			"""
			@MemberwiseInit
			package struct Example {
				var name: String
			}
			"""
		} expansion: {
			"""
			package struct Example {
				var name: String

				package init(
					name: String
				) {
					self.name = name
				}
			}
			"""
		}
	}

	@Test func mirrorsFileprivateAccess() {
		assertMacro {
			"""
			@MemberwiseInit
			fileprivate struct Example {
				var name: String
			}
			"""
		} expansion: {
			"""
			fileprivate struct Example {
				var name: String

				fileprivate init(
					name: String
				) {
					self.name = name
				}
			}
			"""
		}
	}

	@Test func mirrorsPrivateAccess() {
		assertMacro {
			"""
			@MemberwiseInit
			private struct Example {
				var name: String
			}
			"""
		} expansion: {
			"""
			private struct Example {
				var name: String

				private init(
					name: String
				) {
					self.name = name
				}
			}
			"""
		}
	}

	@Test func coexistsWithStubHelpers() {
		assertMacro {
			"""
			@MemberwiseInit(.public)
			@Stub
			public struct Widget {
				public var value: Int
			}
			"""
		} expansion: {
			"""
			public struct Widget {
				public var value: Int

				public init(
					value: Int
				) {
					self.value = value
				}

				#if DEBUG
				public static func stub(
					value: Int = 0
				) -> Widget {
					return Widget(
						value: value
					)
				}

				public func stub(
					value: Int? = nil
				) -> Widget {
					return Widget(
						value: value ?? self.value
					)
				}
				#endif
			}

			extension Widget {
				#if DEBUG
				public struct PreviewValues {
					fileprivate init() {
					}
				}

				public struct TestValues {
					fileprivate init() {
					}
				}
				#endif
			}
			"""
		}
	}
}
#endif
