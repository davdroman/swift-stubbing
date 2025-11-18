import SwiftSyntax
import SwiftSyntaxMacros

struct StubDefaultMacro: PeerMacro {
	static func expansion(
		of attribute: AttributeSyntax,
		providingPeersOf declaration: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		[]
	}

	static func expansion(
		of attribute: AttributeSyntax,
		providingPeersOf declaration: some DeclSyntaxProtocol,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		try expansion(of: attribute, providingPeersOf: declaration, in: context)
	}
}
