#if canImport(StubMacro)
import MacroTesting
import Testing
@testable import StubMacro

@Suite(
	.macros(
		[
			"Stub": StubMacro.self,
			"StubDefault": StubDefaultMacro.self,
		],
		indentationWidth: .tab,
		record: .missing
	)
)
struct StubDefaultMacroTests {
	@Test func generatesCustomDefaultsInHelpers() {
		assertMacro {
			"""
			import Foundation

			@Stub
			public struct Measurement {
				@StubDefault(42)
				public var value: Int
				public var label: String
				@StubDefault(URL(string: "https://dogs.example")!)
				public var website: URL
			}
			"""
		} expansion: {
			"""
			import Foundation
			public struct Measurement {
				public var value: Int
				public var label: String
				public var website: URL

				#if DEBUG
				public static func stub(
					value: Int = 42,
					label: String = "",
					website: URL = URL(string: "https://dogs.example")!
				) -> Measurement {
					return Measurement(
						value: value,
						label: label,
						website: website
					)
				}

				public func stub(
					value: Int? = nil,
					label: String? = nil,
					website: URL? = nil
				) -> Measurement {
					return Measurement(
						value: value ?? self.value,
						label: label ?? self.label,
						website: website ?? self.website
					)
				}
				#endif
			}

			extension Measurement {
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

	@Test func reportsMissingDefaultValue() {
		assertMacro {
			"""
			@Stub
			struct Example {
				@StubDefault
				var value: Int
			}
			"""
		} diagnostics: {
			"""
			@Stub
			┬────
			╰─ 🛑 @StubDefault applied to 'value' must supply exactly one value.
			struct Example {
				@StubDefault
				var value: Int
			}
			"""
		}
	}

	@Test func reportsDuplicateAttributes() {
		assertMacro {
			"""
			@Stub
			struct Example {
				@StubDefault(1)
				@StubDefault(2)
				var value: Int
			}
			"""
		} diagnostics: {
			"""
			@Stub
			┬────
			╰─ 🛑 Property 'value' declares @StubDefault more than once.
			struct Example {
				@StubDefault(1)
				@StubDefault(2)
				var value: Int
			}
			"""
		}
	}
}
#endif
