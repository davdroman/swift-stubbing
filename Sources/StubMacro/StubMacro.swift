import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

struct StubMacro: MemberMacro {
	static func expansion(
		of attribute: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		let typeContext = try TypeContext(declaration: declaration)
		let configuration = try StubConfiguration(attribute: attribute)
		let storedProperties = try typeContext.storedProperties()

		let shouldGenerateMemberwiseInit = !typeContext.hasMemberwiseInitMacro && !storedProperties.isEmpty
		var members: [DeclSyntax] = []

		if shouldGenerateMemberwiseInit {
			members.append(
				DeclSyntax(
					MemberBuilder.makeInitializer(
						access: configuration.memberwiseInitAccess,
						properties: storedProperties
					)
				)
			)
		}

		let stubTexts = MemberBuilder.makeStubTexts(
			access: configuration.stubAccess,
			typeName: typeContext.typeNameDescription,
			properties: storedProperties
		)
		let wrappedStubs = try ConditionalTextBuilder.makeDecls(
			stubTexts,
			selection: configuration.buildConfigurations
		)
		members.append(contentsOf: wrappedStubs)

		return members
	}

	static func expansion(
		of attribute: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		try expansion(of: attribute, providingMembersOf: declaration, in: context)
	}
}

extension StubMacro: ExtensionMacro {
	static func expansion(
		of attribute: AttributeSyntax,
		attachedTo declaration: some DeclGroupSyntax,
		providingExtensionsOf type: some TypeSyntaxProtocol,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [ExtensionDeclSyntax] {
		let configuration = try StubConfiguration(attribute: attribute)
		let typeName = type.trimmedDescription
		let extensionDecl = try MemberBuilder.makeValuesExtension(
			access: configuration.stubAccess,
			typeName: typeName,
			selection: configuration.buildConfigurations
		)
		return [extensionDecl]
	}
}

// MARK: - Parsing

private struct TypeContext {
	let attributes: AttributeListSyntax?
	let members: MemberBlockItemListSyntax
	let name: TokenSyntax
	let qualifiedTypeName: String

	init(declaration: some DeclGroupSyntax) throws {
		if let structDecl = declaration.as(StructDeclSyntax.self) {
			attributes = structDecl.attributes
			members = structDecl.memberBlock.members
			name = structDecl.name
			qualifiedTypeName = Self.qualifiedTypeName(from: structDecl, named: structDecl.name.text)
			return
		}

		if let classDecl = declaration.as(ClassDeclSyntax.self) {
			attributes = classDecl.attributes
			members = classDecl.memberBlock.members
			name = classDecl.name
			qualifiedTypeName = Self.qualifiedTypeName(from: classDecl, named: classDecl.name.text)
			return
		}

		throw MacroExpansionErrorMessage("@Stub can only be applied to structs or classes.")
	}

	func storedProperties() throws -> [StoredProperty] {
		var properties: [StoredProperty] = []

		for member in members {
			guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
			if variable.bindings.count != 1 { continue }
			if variable.isStatic { continue }

			guard let binding = variable.bindings.first else { continue }
			if let accessorBlock = binding.accessorBlock {
				guard accessorBlock.hasOnlyObservers else { continue }
			}
			guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
			guard let type = binding.typeAnnotation?.type else {
				throw MacroExpansionErrorMessage(
					"@Stub requires explicit type annotations for stored property '\(pattern.identifier.text)'."
				)
			}

			let defaultValue = try variable.attributes.stubDefaultValue(
				for: pattern.identifier.text
			)

			properties.append(
				StoredProperty(
					name: pattern.identifier.text,
					type: type,
					defaultValue: defaultValue,
					initializerDefault: binding.initializer?.value
				)
			)
		}

		return properties
	}

	var hasMemberwiseInitMacro: Bool {
		guard let attributes else { return false }

		for element in attributes {
			guard let attribute = element.as(AttributeSyntax.self) else { continue }
			let attributeName = attribute.attributeName.trimmedDescription.split(separator: ".").last.map(String.init)

			if attributeName == "MemberwiseInit" {
				return true
			}

			if case let .argumentList(arguments)? = attribute.arguments,
			   arguments.containsMemberwiseInitFlag
			{
				return true
			}
		}

		return false
	}

	var typeNameDescription: String {
		qualifiedTypeName
	}

	private static func qualifiedTypeName(
		from declaration: some DeclGroupSyntax,
		named baseName: String
	) -> String {
		let ancestorNames = ancestorTypeNames(startingAt: Syntax(declaration).parent)
		guard !ancestorNames.isEmpty else {
			return baseName
		}

		return (ancestorNames.reversed() + [baseName]).joined(separator: ".")
	}

	private static func ancestorTypeNames(startingAt node: Syntax?) -> [String] {
		var names: [String] = []
		var current = node

		while let node = current {
			if let parentStruct = node.as(StructDeclSyntax.self) {
				names.append(parentStruct.name.text)
			} else if let parentClass = node.as(ClassDeclSyntax.self) {
				names.append(parentClass.name.text)
			} else if let parentEnum = node.as(EnumDeclSyntax.self) {
				names.append(parentEnum.name.text)
			} else if let parentActor = node.as(ActorDeclSyntax.self) {
				names.append(parentActor.name.text)
			} else if let parentExtension = node.as(ExtensionDeclSyntax.self) {
				names.append(parentExtension.extendedType.trimmedDescription)
			}

			current = node.parent
		}

		return names
	}
}

private struct StubConfiguration {
	let stubAccess: AccessModifier
	let memberwiseInitAccess: AccessModifier
	let buildConfigurations: BuildConfigurationSelection

	init(attribute: AttributeSyntax) throws {
		var stubAccess: AccessModifier?
		var memberwiseAccess: AccessModifier?
		var buildConfigurations = BuildConfigurationSelection(debug: true, release: false)

		if case let .argumentList(arguments)? = attribute.arguments {
			for argument in arguments {
				if let label = argument.label, label.text == "memberwiseInit" {
					memberwiseAccess = try AccessModifier.parse(from: argument.expression)
					continue
				}

				if let label = argument.label, label.text == "in" {
					buildConfigurations = try BuildConfigurationSelection.parse(from: argument.expression)
					continue
				}

				if stubAccess == nil {
					stubAccess = try AccessModifier.parse(from: argument.expression)
				}
			}
		}

		self.stubAccess = stubAccess ?? .internal
		memberwiseInitAccess = memberwiseAccess ?? .internal
		self.buildConfigurations = buildConfigurations
	}
}

private enum AccessModifier: String {
	case `public`
	case `internal`
	case `package`
	case `fileprivate`
	case `private`

	var sourceText: String {
		rawValue + " "
	}

	static func parse(from expression: ExprSyntax) throws -> AccessModifier {
		let description = expression.trimmedDescription
		let candidates = description
			.split(separator: ".")
			.map(String.init)
			.filter { !$0.isEmpty }

		guard let value = candidates.last, let modifier = AccessModifier(rawValue: value) else {
			throw MacroExpansionErrorMessage("Unsupported access level '\(description)' in @Stub.")
		}

		return modifier
	}
}

private struct BuildConfigurationSelection {
	let includesDebug: Bool
	let includesRelease: Bool

	init(debug: Bool, release: Bool) {
		self.includesDebug = debug
		self.includesRelease = release
	}

	static func parse(from expression: ExprSyntax) throws -> BuildConfigurationSelection {
		if let array = expression.as(ArrayExprSyntax.self) {
			var selection = BuildConfigurationSelection(debug: false, release: false)
			for element in array.elements {
				selection = try selection.merging(with: parse(from: element.expression))
			}
			guard selection.includesDebug || selection.includesRelease else {
				throw MacroExpansionErrorMessage("Build configuration list for @Stub must include at least .debug or .release.")
			}
			return selection
		}

		if let memberAccess = expression.as(MemberAccessExprSyntax.self) {
			let name = memberAccess.declName.baseName.text
			return try selection(for: name, fullDescription: expression.trimmedDescription)
		}

		let description = expression.trimmedDescription
		return try selection(for: description.split(separator: ".").last.map(String.init) ?? description, fullDescription: description)
	}

	private func merging(with other: BuildConfigurationSelection) -> BuildConfigurationSelection {
		BuildConfigurationSelection(
			debug: includesDebug || other.includesDebug,
			release: includesRelease || other.includesRelease
		)
	}

	private static func selection(for name: String, fullDescription: String) throws -> BuildConfigurationSelection {
		switch name {
		case "debug":
			return BuildConfigurationSelection(debug: true, release: false)
		case "release":
			return BuildConfigurationSelection(debug: false, release: true)
		default:
			throw MacroExpansionErrorMessage("Unsupported build configuration '\(fullDescription)' in @Stub.")
		}
	}
}

private struct StoredProperty {
	let name: String
	let type: TypeSyntax
	let defaultValue: ExprSyntax?
	let initializerDefault: ExprSyntax?

	var signature: String {
		"\(name): \(type.trimmedDescription)"
	}

	var memberwiseSignature: String {
		let base = signature
		guard let initializerDefault else { return base }
		return "\(base) = \(initializerDefault.trimmedDescription)"
	}
}

private enum MemberBuilder {
	static func makeInitializer(access: AccessModifier, properties: [StoredProperty]) -> DeclSyntax {
		let modifier = access.sourceText
		let parameterLines = properties
			.map { "\t\($0.memberwiseSignature)" }
			.joined(separator: ",\n")
		let assignmentLines = properties
			.map { "\tself.\($0.name) = \($0.name)" }
			.joined(separator: "\n")

		if properties.isEmpty {
			return DeclSyntax("""

			\(raw: modifier)init() {}
			""")
		}

		return DeclSyntax("""

		\(raw: modifier)init(
		\(raw: parameterLines)
		) {
		\(raw: assignmentLines)
		}
		""")
	}

	static func makeStubTexts(
		access: AccessModifier,
		typeName: String,
		properties: [StoredProperty]
	) -> [String] {
		let staticStub = stubFunctionText(
			access: access,
			properties: properties,
			returnType: typeName,
			callType: typeName,
			indentation: "",
			parentTypeName: typeName
		)
		let instanceStub = instanceStubFunctionText(
			access: access,
			typeName: typeName,
			properties: properties,
			indentation: ""
		)

		return [staticStub, instanceStub]
	}

	static func makeValuesExtension(
		access: AccessModifier,
		typeName: String,
		selection: BuildConfigurationSelection
	) throws -> ExtensionDeclSyntax {
		let accessText = access.sourceText
		let helperBlock = """
		\t\(accessText)struct PreviewValues {
		\t\tfileprivate init() {}
		\t}

		\t\(accessText)struct TestValues {
		\t\tfileprivate init() {}
		\t}
		"""
		let wrappedBlock = try ConditionalTextBuilder.wrap(
			helperBlock,
			selection: selection,
			indentation: "\t"
		)

		return try ExtensionDeclSyntax(
			"extension \(raw: typeName) {\n\(raw: wrappedBlock)\n}\n"
		)
	}

	private static func stubFunctionText(
		access: AccessModifier,
		properties: [StoredProperty],
		returnType: String,
		callType: String,
		indentation: String,
		parentTypeName: String
	) -> String {
		let accessText = access.sourceText
		let parameterIndent = indentation + "\t"
		let argumentIndent = indentation + "\t\t"

		if properties.isEmpty {
			return """
			\(indentation)\(accessText)static func stub() -> \(returnType) {
			\(indentation)\treturn \(callType)()
			\(indentation)}
			"""
		}

		let parameterLines = properties
			.map { property in
				"\(parameterIndent)\(property.signature) = \(defaultValue(for: property, parentTypeName: parentTypeName))"
			}
			.joined(separator: ",\n")
		let argumentLines = properties
			.map { propertyArgument(for: $0, indentation: argumentIndent) }
			.joined(separator: ",\n")

		return """
		\(indentation)\(accessText)static func stub(
		\(parameterLines)
		\(indentation)) -> \(returnType) {
		\(indentation)\treturn \(callType)(
		\(argumentLines)
		\(indentation)\t)
		\(indentation)}
		"""
	}

	private static func defaultValue(for property: StoredProperty, parentTypeName: String) -> String {
		if let override = property.defaultValue?.trimmedDescription {
			return override
		}

		let typeDescription = property.type.trimmedDescription
		let parentBaseName = baseTypeName(from: parentTypeName)
		if typeDescription == parentTypeName ||
			typeDescription == "Self" ||
			baseTypeName(from: typeDescription) == parentBaseName
		{
			return "\(parentTypeName).stub()"
		}

		return defaultValueExpression(for: property.type)
	}

	private static func propertyArgument(for property: StoredProperty, indentation: String) -> String {
		"\(indentation)\(property.name): \(property.name)"
	}

	private static func defaultValueExpression(for type: TypeSyntax) -> String {
		let description = sanitize(type.trimmedDescription)

		if description.hasSuffix("?") || description.hasSuffix("!") {
			return "nil"
		}

		if description.hasPrefix("Optional<") || description.hasPrefix("ImplicitlyUnwrappedOptional<") {
			return "nil"
		}

		if description.hasPrefix("[") {
			return description.contains(":") ? "[:]" : "[]"
		}

		if description.hasPrefix("Dictionary<") || description.hasPrefix("Swift.Dictionary<") {
			return "[:]"
		}

		if description.hasPrefix("Array<") || description.hasPrefix("Swift.Array<") {
			return "[]"
		}

		if description.hasPrefix("Set<") || description.hasPrefix("Swift.Set<") {
			return "[]"
		}

		let baseName = baseTypeName(from: description)
		if let literal = literalDefaults[baseName] {
			return literal
		}

		return "\(description).stub()"
	}

	private static func sanitize(_ type: String) -> String {
		var sanitized = type.trimmingCharacters(in: .whitespacesAndNewlines)

		while sanitized.hasPrefix("some ") {
			sanitized.removeFirst(5)
		}

		while sanitized.hasPrefix("any ") {
			sanitized.removeFirst(4)
		}

		if sanitized.hasPrefix("("), sanitized.hasSuffix(")") {
			sanitized = String(sanitized.dropFirst().dropLast())
		}

		return sanitized
	}

	private static func baseTypeName(from type: String) -> String {
		let trimmed = type.split(separator: ".").last.map(String.init) ?? type
		if let genericStartIndex = trimmed.firstIndex(of: "<") {
			return String(trimmed[..<genericStartIndex])
		}

		return trimmed
	}

	private static let literalDefaults: [String: String] = [
		"Bool": "false",
		"Character": "\"\"",
		"Data": "Data()",
		"Date": "Date(timeIntervalSince1970: 0)",
		"Decimal": "Decimal(0)",
		"Double": "0",
		"Float": "0",
		"Float16": "0",
		"Float32": "0",
		"Float64": "0",
		"Float80": "0",
		"CGFloat": "0",
		"Int": "0",
		"Int8": "0",
		"Int16": "0",
		"Int32": "0",
		"Int64": "0",
		"Set": "[]",
		"String": "\"\"",
		"Substring": "\"\"",
		"TimeInterval": "0",
		"UInt": "0",
		"UInt8": "0",
		"UInt16": "0",
		"UInt32": "0",
		"UInt64": "0",
		"URL": "URL(string: \"https://example.com\")!",
		"UUID": "UUID()",
	]

	private static func instanceStubFunctionText(
		access: AccessModifier,
		typeName: String,
		properties: [StoredProperty],
		indentation: String
	) -> String {
		let accessText = access.sourceText
		let parameterIndent = indentation + "\t"
		let argumentIndent = indentation + "\t\t"

		if properties.isEmpty {
			return """
			\(indentation)\(accessText)func stub() -> \(typeName) {
			\(indentation)\treturn \(typeName)()
			\(indentation)}
			"""
		}

		let parameterLines = properties
			.map { "\(parameterIndent)\($0.name): \(parameterType(for: $0)) = nil" }
			.joined(separator: ",\n")
		let argumentLines = properties
			.map { instancePropertyArgument(for: $0, indentation: argumentIndent) }
			.joined(separator: ",\n")

		return """
		\(indentation)\(accessText)func stub(
		\(parameterLines)
		\(indentation)) -> \(typeName) {
		\(indentation)\treturn \(typeName)(
		\(argumentLines)
		\(indentation)\t)
		\(indentation)}
		"""
	}

	private static func instancePropertyArgument(for property: StoredProperty, indentation: String) -> String {
		"\(indentation)\(property.name): \(property.name) ?? self.\(property.name)"
	}

	private static func parameterType(for property: StoredProperty) -> String {
		if property.type.is(OptionalTypeSyntax.self) || property.type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
			return property.type.trimmedDescription
		}

		return "\(property.type.trimmedDescription)?"
	}
}

private enum ConditionalTextBuilder {
	static func makeDecl(
		_ content: String,
		selection: BuildConfigurationSelection
	) throws -> DeclSyntax {
		let wrapped = try wrap(
			content,
			selection: selection,
			indentation: ""
		)
		return try DeclSyntax("\n\(raw: wrapped)\n")
	}

	static func makeDecls(
		_ contents: [String],
		selection: BuildConfigurationSelection
	) throws -> [DeclSyntax] {
		switch (selection.includesDebug, selection.includesRelease) {
		case (true, true):
			return try contents.map { content in
				try DeclSyntax("\n\(raw: content.trimmingCharacters(in: .whitespacesAndNewlines))\n")
			}
		case (true, false), (false, true):
			let joined = contents
				.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
				.joined(separator: "\n\n")
			return [try makeDecl(joined, selection: selection)]
		case (false, false):
			throw MacroExpansionErrorMessage("@Stub build configurations must include at least .debug or .release.")
		}
	}

	static func wrap(
		_ content: String,
		selection: BuildConfigurationSelection,
		indentation: String
	) throws -> String {
		switch (selection.includesDebug, selection.includesRelease) {
		case (true, true):
			return content
		case (true, false):
			return "\(indentation)#if DEBUG\n\(content)\n\(indentation)#endif"
		case (false, true):
			return "\(indentation)#if !DEBUG\n\(content)\n\(indentation)#endif"
		case (false, false):
			throw MacroExpansionErrorMessage("@Stub build configurations must include at least .debug or .release.")
		}
	}
}

extension VariableDeclSyntax {
	fileprivate var isStatic: Bool {
		modifiers.contains(where: { modifier in
			modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
		})
	}
}

extension AccessorBlockSyntax {
	fileprivate var hasOnlyObservers: Bool {
		switch accessors {
		case let .accessors(accessors):
			for accessor in accessors {
				let specifier = accessor.accessorSpecifier.tokenKind
				if specifier != .keyword(.willSet) && specifier != .keyword(.didSet) {
					return false
				}
			}
			return true
		case .getter:
			return false
		}
	}
}

extension AttributeListSyntax {
	fileprivate func stubDefaultValue(for propertyName: String) throws -> ExprSyntax? {
		var value: ExprSyntax?

		for element in self {
			guard let attribute = element.as(AttributeSyntax.self) else { continue }
			guard attribute.matches(name: "StubDefault") else { continue }

			guard case let .argumentList(arguments)? = attribute.arguments,
			      arguments.count == 1,
			      let expression = arguments.first?.expression
			else {
				throw MacroExpansionErrorMessage(
					"@StubDefault applied to '\(propertyName)' must supply exactly one value."
				)
			}

			if value != nil {
				throw MacroExpansionErrorMessage(
					"Property '\(propertyName)' declares @StubDefault more than once."
				)
			}

			value = expression
		}

		return value
	}
}

extension AttributeSyntax {
	fileprivate func matches(name target: String) -> Bool {
		guard let name = attributeName.trimmedDescription.split(separator: ".").last else {
			return false
		}

		return String(name) == target
	}
}

extension LabeledExprListSyntax {
	fileprivate var containsMemberwiseInitFlag: Bool {
		for argument in self {
			guard argument.label?.text == "memberwiseInit" else { continue }
			guard let literal = argument.expression.as(BooleanLiteralExprSyntax.self) else { continue }
			if literal.literal.tokenKind == .keyword(.true) {
				return true
			}
		}

		return false
	}
}
