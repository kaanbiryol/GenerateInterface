import ArgumentParser
import SwiftSyntax

@main
struct GenerateInterface: ParsableCommand {
    @Argument var projectSwiftPath: String
    @Argument var moduleName: String
    @Argument var modulesPath: String
    @Argument var compilerArgsPath: String

    @Flag var printOnly: Bool = false
    
    mutating func run() throws {
        do {
            // Get ModuleInterface.swift from sourcekitten.
            print("🔨 Generating module interface...")
            let compilerArgsContent = try String(contentsOfFile: compilerArgsPath, encoding: .utf8)
            let compilerArgs = compilerArgsContent.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            
            // Extract Swift files from compiler arguments
            let swiftFiles = compilerArgs.filter { $0.hasSuffix(".swift") }
            print("📄 Swift files found in compiler arguments:")
            swiftFiles.forEach { print("   \($0)") }

            let sourceText = try moduleInterfaceSourceText(moduleName: moduleName, compilerArgs: compilerArgs)
            
            // Rewrite it to remove unnecessary imports, any/some keywords etc..
            print("🔨 Modifying generated module interface...")
            let modifiedSourceText = rewriteModuleInterface(sourceText: sourceText, additionalFiles: swiftFiles, moduleName: moduleName) ?? ""
            
            if printOnly {
                print("\n" + String(repeating: "=", count: 80))
                print(modifiedSourceText)
                print("\n" + String(repeating: "=", count: 80))
                return
            }
            
            print("🔨 Creating Interface module folders...")
            // Create necessary folders and move the Interface.swift file there.
            let moduleInterfaceFilePath = try createInterfaceModuleDirectoryWithSource(modulesPath, moduleName: moduleName, fileContent: modifiedSourceText)
            
            print("🔨 Replacing import statements in other files...")
            // Scan each file to replace "import ModuleName" with "import ModuleNameInterface"
            try rewriteImportStatementsToInterfaceModule(modulesPath, moduleName: moduleName)
            
            print("🔨 Modifying Project.swift...")
            // Create a interface module in "Project.swift"
            rewriteProjectFile(at: projectSwiftPath, moduleName: moduleName)
            
            print("""
                 ✅ Generated: \(moduleInterfaceFilePath)
                    Modified: \(projectSwiftPath)
                    Please make sure that the changes made are correct.
                 """)
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
}
