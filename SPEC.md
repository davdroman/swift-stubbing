# swift-stubbing spec

## @Stub macro

Can be applied to structs and classes.

@Stub supports two invocation styles:
	- `@Stub` inherits the access level of the annotated type and optionally accepts an `in:` parameter specifying the `BuildConfigurations` where the generated helpers should be emitted. Defaults to `.debug`.
	- `@Stub(.public, in: [.debug, .release])` overrides the access level of the synthesized helpers while still supporting the same `in:` argument.

```swift
public struct BuildConfigurations: OptionSet, Sendable {
	public static let debug: BuildConfigurations
	public static let release: BuildConfigurations
}
```

@Stub generates two things:
	1. A static `stub` function that returns a pre-defined instance of the type. The stub function can take parameters to override specific properties of the stubbed instance. By pre-defined instance, we mean that for each property type we have a default value. For example, String properties default to "", Int properties default to 0, Bool properties default to false, and so on. For custom types, we assume they also have a `stub` function that can be called to get a default instance.
	2. An extension containing empty `PreviewValues` and `TestValues` helper structs that developers can extend to hold curated samples for previews and tests.

Both the stub function and the helper structs are wrapped in `#if DEBUG` by default so they stay out of release builds. Pass `in: [.debug, .release]` (or `.release` by itself) if you want these helpers available everywhere.

Make sure to cover all the following built-in types and any others you can think of, as long as they have sensible defaults: String, Int, Double, Float, Bool, Array, Dictionary, Set, Optional, Date, Data, URL

### Examples

Tip: you may use these as inspo for test cases.

```swift
@MemberwiseInit
@Stub
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

	// synthesized
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

	// synthesized
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
}

// synthesized
extension Dog {
	struct PreviewValues {
		fileprivate init() {}
	}

	struct TestValues {
		fileprivate init() {}
	}
}

// Always emit helpers
@MemberwiseInit
@Stub(in: [.debug, .release])
public struct AlwaysAvailableDog {
	// ... definitions ...
}
```

## @StubDefault

Can be applied to properties within structs and classes that have the @Stub macro applied.

When a property is annotated with @StubDefault, the code generator will use the provided default value when generating the stub function for the enclosing type. This allows developers to specify custom default values for specific properties while still leveraging the automatic stub generation for the rest of the properties. Preview/test helper structs are still emitted (and remain empty) so that teams can extend them with curated presets, and they follow the same `in:` build-configuration behavior described above.

### Example

```swift
@Stub
struct Person {
	var name: String
	@StubDefault(30)
	var age: Int
	var isEmployed: Bool
	var hobbies: [String]

	// synthesized
	static func stub(
		name: String = "",
		age: Int = 30,
		isEmployed: Bool = false,
		hobbies: [String] = []
	) -> Person {
		return Person(
			name: name,
			age: age,
			isEmployed: isEmployed,
			hobbies: hobbies
		)
	}
}

// synthesized
extension Person {
	struct PreviewValues {
		fileprivate init() {}
	}

	struct TestValues {
		fileprivate init() {}
	}
}
```

## PreviewValues and TestValues extension

For types annotated with @Stub, generate an extension with the following structure (no stub methods live inside the helper structs):

```swift
@Stub
struct Example {
	var text: String
	var number: Int
}

// synthesized
extension Example {
	struct PreviewValues {
		fileprivate init() {}
	}
	struct TestValues {
		fileprivate init() {}
	}
}
```

Then the user can extend these nested structs to provide custom preview and test values while calling the main `Example.stub` factory.

```swift
#if DEBUG
extension Example.PreviewValues {
	static let sample = Example.stub(
		text: "Preview Text"
	)
}

extension Example.TestValues {
	static let sample = Example.stub(
		text: "Test Text"
	)
}
#endif
```

## @MemberwiseInit macro

Apply `@MemberwiseInit` with no arguments to synthesize a memberwise initializer that matches the access level of the annotated type. Pass an explicit argument (e.g. `@MemberwiseInit(.public)`) when you need to override the synthesized initializer's visibility. The macro always mirrors the stored properties declared in the type, using their default values where specified. Combine it with `@Stub` when you need both initializers and stub helpers.

Match the access level of the nested structs to that of the @Stub annotation, and wrap any extensions in the same build-configuration checks unless the stub is emitted for release builds.
