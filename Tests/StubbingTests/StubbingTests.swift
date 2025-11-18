import Foundation
import Testing
@testable import Stubbing

@Stub(.public, memberwiseInit: .public, in: [.debug, .release])
struct Person {
	var name: String
	var age: Int
}

@Stub(in: [.debug, .release])
struct Measurement {
	@StubDefault(42)
	var value: Int
}

@Stub(.public, memberwiseInit: .public, in: [.debug, .release])
final class Dog {
	var name: String
	var age: Int
	var isGoodBoy: Bool
	var favoriteToys: [String]
	var collars: Set<String>
	var vaccinationRecords: [String: Date]
	var microchipID: String? = nil
	var birthDate: Date
	var profilePicture: Data
	var website: URL
	var owner: Person
	var bestFriend: Dog? = nil
}

@MainActor extension Dog.PreviewValues {
	static let featured = Dog.stub(name: "Buddy", isGoodBoy: true)
}

@MainActor extension Dog.TestValues {
	static let regression = Dog.stub(name: "Testy", age: 9)
}

@Suite
struct StubbingTests {
	@Test func stubProvidesReasonableDefaults() {
		let dog = Dog.stub()

		#expect(dog.name == "")
		#expect(dog.age == 0)
		#expect(dog.isGoodBoy == false)
		#expect(dog.favoriteToys.isEmpty)
		#expect(dog.collars.isEmpty)
		#expect(dog.vaccinationRecords.isEmpty)
		#expect(dog.microchipID == nil)
		#expect(dog.birthDate == Date(timeIntervalSince1970: 0))
		#expect(dog.profilePicture == Data())
		#expect(dog.website == URL(string: "https://example.com")!)
		#expect(dog.owner.name == "")
		#expect(dog.owner.age == 0)
		#expect(dog.bestFriend == nil)
	}

	@Test func stubSupportsOverridingIndividualValues() {
		let customOwner = Person.stub(name: "Sarah", age: 33)
		let dog = Dog.stub(name: "Luna", age: 5, owner: customOwner, bestFriend: Dog.stub(name: "Max"))

		#expect(dog.name == "Luna")
		#expect(dog.age == 5)
		#expect(dog.owner.name == "Sarah")
		#expect(dog.bestFriend?.name == "Max")
	}

	@MainActor
	@Test func previewAndTestValuesExposeCustomizationPoints() {
		let previewDog = Dog.PreviewValues.featured
		let testDog = Dog.TestValues.regression

		#expect(previewDog.isGoodBoy)
		#expect(testDog.age == 9)
	}

	@Test func stubDefaultAssignsOverride() {
		let measurement = Measurement.stub()
		#expect(measurement.value == 42)
	}

	@Test func memberwiseInitializerMatchesStoredProperties() throws {
		let owner = Person.stub(name: "Jess", age: 28)
		let friend = Dog.stub(name: "Coco")

		let dog = try Dog(
			name: "Buddy",
			age: 2,
			isGoodBoy: true,
			favoriteToys: ["Rope"],
			collars: ["Green"],
			vaccinationRecords: ["Rabies": Date(timeIntervalSince1970: 1_700_000_000)],
			microchipID: "ABC123",
			birthDate: Date(timeIntervalSince1970: 1_600_000_000),
			profilePicture: Data([0x01, 0x02]),
			website: #require(URL(string: "https://buddy.example")),
			owner: owner,
			bestFriend: friend
		)

		#expect(dog.name == "Buddy")
		#expect(dog.owner.name == "Jess")
		#expect(dog.bestFriend?.name == "Coco")
	}
}
