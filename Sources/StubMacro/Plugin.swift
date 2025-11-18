import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct StubMacroPlugin: CompilerPlugin {
	let providingMacros: [any Macro.Type] = [
		StubMacro.self,
		StubDefaultMacro.self,
	]
}
