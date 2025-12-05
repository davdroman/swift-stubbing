#if canImport(StubMacro)
import MacroTesting
import Testing
@testable import StubMacro

@Suite(
	.macros(
		["Stub": StubMacro.self],
		indentationWidth: .tab,
		record: .missing
	)
)
struct StubMacroTests {
	@Test func generatesStubHelpers() {
		assertMacro {
			"""
			import Foundation

			struct Person {
				static func stub() -> Person { .init(name: "", age: 0) }
			}

			@Stub(.public)
			public struct Dog {
				public var name: String
				public var age: Int
				public var isGoodBoy: Bool
				public var favoriteToys: [String]
				public var collars: Set<String>
				public var vaccinationRecords: [String: Date]
				public var microchipID: String?
				public var birthDate: Date
				public var profilePicture: Data
				public var website: URL
				public var owner: Person
				public var bestFriend: Dog?
			}
			"""
		} expansion: {
			"""
			import Foundation

			struct Person {
				static func stub() -> Person { .init(name: "", age: 0) }
			}
			public struct Dog {
				public var name: String
				public var age: Int
				public var isGoodBoy: Bool
				public var favoriteToys: [String]
				public var collars: Set<String>
				public var vaccinationRecords: [String: Date]
				public var microchipID: String?
				public var birthDate: Date
				public var profilePicture: Data
				public var website: URL
				public var owner: Person
				public var bestFriend: Dog?

				#if DEBUG
				public static func stub(
					name: String = "",
					age: Int = 0,
					isGoodBoy: Bool = false,
					favoriteToys: [String] = [],
					collars: Set<String> = [],
					vaccinationRecords: [String: Date] = [:],
					microchipID: String? = nil,
					birthDate: Date = Date(timeIntervalSince1970: 0),
					profilePicture: Data = Data(),
					website: URL = URL(string: "https://example.com")!,
					owner: Person = Person.stub(),
					bestFriend: Dog? = nil
				) -> Dog {
					return Dog(
						name: name,
						age: age,
						isGoodBoy: isGoodBoy,
						favoriteToys: favoriteToys,
						collars: collars,
						vaccinationRecords: vaccinationRecords,
						microchipID: microchipID,
						birthDate: birthDate,
						profilePicture: profilePicture,
						website: website,
						owner: owner,
						bestFriend: bestFriend
					)
				}

				public func stub(
					name: String? = nil,
					age: Int? = nil,
					isGoodBoy: Bool? = nil,
					favoriteToys: [String]? = nil,
					collars: Set<String>? = nil,
					vaccinationRecords: [String: Date]? = nil,
					microchipID: String? = nil,
					birthDate: Date? = nil,
					profilePicture: Data? = nil,
					website: URL? = nil,
					owner: Person? = nil,
					bestFriend: Dog? = nil
				) -> Dog {
					return Dog(
						name: name ?? self.name,
						age: age ?? self.age,
						isGoodBoy: isGoodBoy ?? self.isGoodBoy,
						favoriteToys: favoriteToys ?? self.favoriteToys,
						collars: collars ?? self.collars,
						vaccinationRecords: vaccinationRecords ?? self.vaccinationRecords,
						microchipID: microchipID ?? self.microchipID,
						birthDate: birthDate ?? self.birthDate,
						profilePicture: profilePicture ?? self.profilePicture,
						website: website ?? self.website,
						owner: owner ?? self.owner,
						bestFriend: bestFriend ?? self.bestFriend
					)
				}
				#endif
			}

			extension Dog {
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

	@Test func includesPropertiesWithObservers() {
		assertMacro {
			"""
			@Stub
			struct Example {
				var counter: Int = 0 {
					didSet { print(counter) }
				}
			}
			"""
		} expansion: {
			"""
			struct Example {
				var counter: Int = 0 {
					didSet { print(counter) }
				}

				#if DEBUG
				internal static func stub(
					counter: Int = 0
				) -> Example {
					return Example(
						counter: counter
					)
				}

				internal func stub(
					counter: Int? = nil
				) -> Example {
					return Example(
						counter: counter ?? self.counter
					)
				}
				#endif
			}

			extension Example {
				#if DEBUG
				internal struct PreviewValues {
					fileprivate init() {
					}
				}

				internal struct TestValues {
					fileprivate init() {
					}
				}
				#endif
			}
			"""
		}
	}

	@Test func emitsInAllBuildsWhenRequested() {
		assertMacro {
			"""
			@Stub(in: [.debug, .release])
			struct Example {
				var value: Int
			}
			"""
		} expansion: {
			"""
			struct Example {
				var value: Int

				internal static func stub(
					value: Int = 0
				) -> Example {
					return Example(
						value: value
					)
				}

				internal func stub(
					value: Int? = nil
				) -> Example {
					return Example(
						value: value ?? self.value
					)
				}
			}

			extension Example {
				internal struct PreviewValues {
					fileprivate init() {
					}
				}

				internal struct TestValues {
					fileprivate init() {
					}
				}
			}
			"""
		}
	}

	@Test func qualifiesNestedTypesWithinExtensions() {
		assertMacro {
			"""
			extension MovieAPI {
				@Stub(.public)
				public struct Page {
					let start: Int
					var cursor: String?
				}
			}
			"""
		} expansion: {
			"""
			extension MovieAPI {
				public struct Page {
					let start: Int
					var cursor: String?

					#if DEBUG
					public static func stub(
						start: Int = 0,
						cursor: String? = nil
					) -> Page {
						return Page(
							start: start,
							cursor: cursor
						)
					}

					public func stub(
						start: Int? = nil,
						cursor: String? = nil
					) -> Page {
						return Page(
							start: start ?? self.start,
							cursor: cursor ?? self.cursor
						)
					}
					#endif
				}
			}

			extension MovieAPI.Page {
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
