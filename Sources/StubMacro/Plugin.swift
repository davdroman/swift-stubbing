import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct StubMacroPlugin: CompilerPlugin {
	let providingMacros: [any Macro.Type] = [
		MemberwiseInitMacro.self,
		StubMacro.self,
		StubDefaultMacro.self,
	]
}
