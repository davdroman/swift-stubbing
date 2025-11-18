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
	@Test func generatesMemberwiseInitializerAndStub() {
		assertMacro {
			"""
			import Foundation

			struct Person {
				static func stub() -> Person { .init(name: "", age: 0) }
			}

			@Stub(.public, memberwiseInit: .public)
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

				public init(
					name: String,
					age: Int,
					isGoodBoy: Bool,
					favoriteToys: [String],
					collars: Set<String>,
					vaccinationRecords: [String: Date],
					microchipID: String?,
					birthDate: Date,
					profilePicture: Data,
					website: URL,
					owner: Person,
					bestFriend: Dog?
				) {
					self.name = name
					self.age = age
					self.isGoodBoy = isGoodBoy
					self.favoriteToys = favoriteToys
					self.collars = collars
					self.vaccinationRecords = vaccinationRecords
					self.microchipID = microchipID
					self.birthDate = birthDate
					self.profilePicture = profilePicture
					self.website = website
					self.owner = owner
					self.bestFriend = bestFriend
				}

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

	@Test func skipsMemberwiseInitWhenExplicitMacroExists() {
		assertMacro {
			"""
			@Stub
			@MemberwiseInit
			struct Example {
				var value: String
			}
			"""
		} expansion: {
			"""
			@MemberwiseInit
			struct Example {
				var value: String

				#if DEBUG
				internal static func stub(
					value: String = ""
				) -> Example {
					return Example(
						value: value
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

	@Test func skipsMemberwiseInitWhenMemberwiseFlagIsPresent() {
		assertMacro {
			"""
			@Stub
			@Tracker(memberwiseInit: true)
			struct Example {
				var value: Int
			}
			"""
		} expansion: {
			"""
			@Tracker(memberwiseInit: true)
			struct Example {
				var value: Int

				#if DEBUG
				internal static func stub(
					value: Int = 0
				) -> Example {
					return Example(
						value: value
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

				internal init(
					value: Int
				) {
					self.value = value
				}

				internal static func stub(
					value: Int = 0
				) -> Example {
					return Example(
						value: value
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
}
#endif
