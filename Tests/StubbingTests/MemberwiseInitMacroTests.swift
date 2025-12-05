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
	@Test func generatesMemberwiseInitializer() {
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

	@Test func coexistsWithStubHelpers() {
		assertMacro {
			"""
			@MemberwiseInit(.public)
			@Stub(.public)
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
