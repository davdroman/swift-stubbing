import SwiftSyntax
import SwiftSyntaxMacros

struct MemberwiseInitMacro: MemberMacro {
	static func expansion(
		of attribute: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		let typeContext = try TypeContext(declaration: declaration, macroName: "@MemberwiseInit")
		let storedProperties = try typeContext.storedProperties()
		guard !storedProperties.isEmpty else {
			return []
		}

		let configuration = try MemberwiseInitConfiguration(attribute: attribute)
		return [
			DeclSyntax(
				MemberBuilder.makeInitializer(
					access: configuration.access,
					properties: storedProperties
				)
			),
		]
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

private struct MemberwiseInitConfiguration {
	let access: AccessModifier

	init(attribute: AttributeSyntax) throws {
		var memberwiseAccess: AccessModifier?

		if case let .argumentList(arguments)? = attribute.arguments {
			for argument in arguments where argument.label == nil {
				memberwiseAccess = try AccessModifier.parse(from: argument.expression, macroName: "@MemberwiseInit")
				break
			}
		}

		self.access = memberwiseAccess ?? .internal
	}
}
