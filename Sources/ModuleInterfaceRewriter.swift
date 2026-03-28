import Foundation
import SwiftSyntax
import SwiftParser

func rewriteModuleInterface(sourceText: String, additionalFiles: [String], moduleName: String) -> String {
    let sourceFile = Parser.parse(source: sourceText)

    let interfaceExtractedDeclarations: [NamedDeclaration] = extractDeclarationsFromSource(sourceText, fileName: "Interface")
    var additionalDeclarations: [NamedDeclaration] = []
    for filePath in additionalFiles {
        do {
            let fileContent = try String(contentsOfFile: filePath, encoding: .utf8)
            let fileDeclarations = extractDeclarationsFromSource(fileContent, fileName: filePath)
            additionalDeclarations.append(contentsOf: fileDeclarations)
        } catch {
            print("Error reading file \(filePath): \(error.localizedDescription)")
        }
    }

    let rewriter = ModuleInterfaceRewriter()
    rewriter.interfaceDeclarations = interfaceExtractedDeclarations
    rewriter.additionalDeclarations = additionalDeclarations

    let simplifiedSyntax = rewriter.rewrite(sourceFile)

    // Remove declarations from additional files if they exist in both interfaceDeclarations and additionalDeclarations
    for (index, filePath) in additionalFiles.enumerated() {
        do {
            var fileContent = try String(contentsOfFile: filePath, encoding: .utf8)
            let fileDeclarations = extractDeclarationsFromSource(fileContent, fileName: filePath)
            
            var declarationsRemoved = false
            for declaration in fileDeclarations {
                if interfaceExtractedDeclarations.contains(where: { $0.name == declaration.name }) &&
                   additionalDeclarations.contains(where: { $0.name == declaration.name }) {
                    // Remove the declaration from the file content
                    let declarationString = declaration.declaration.description
                    if let range = fileContent.range(of: declarationString) {
                        fileContent.removeSubrange(range)
                        declarationsRemoved = true
                    }
                }
            }
            
            // Check if the file is empty or contains only imports
            let trimmedContent = fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
            let lines = trimmedContent.components(separatedBy: .newlines)
            let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let onlyImports = nonEmptyLines.allSatisfy { $0.trimmingCharacters(in: .whitespaces).hasPrefix("import") }
            
            // if trimmedContent.isEmpty || onlyImports {
            if false {
                // Remove the file
                try FileManager.default.removeItem(atPath: filePath)
                print("Removed empty or import-only file: \(filePath)")
            } else {
                // Add import ModuleInterface if declarations were removed
                if declarationsRemoved {
                    fileContent = "import \(moduleName)\n" + fileContent
                }
                // Write the modified content back to the file
                try fileContent.write(toFile: filePath, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Error processing file \(filePath): \(error.localizedDescription)")
        }
    }
        
    // Combine the rewritten source with extracted declarations
    return simplifiedSyntax.description
}


private func extractDeclarationsFromSource(_ sourceCode: String, fileName: String) -> [NamedDeclaration] {
    var namedDeclarations: [NamedDeclaration] = []

    // Parse the source code
    let sourceFile = Parser.parse(source: sourceCode)

    // Extract struct, protocol, and class declarations
    let declarationExtractor = DeclarationExtractor(viewMode: .sourceAccurate)
    declarationExtractor.walk(sourceFile)
    
    // Create NamedDeclarations from extracted declarations
    for declaration in declarationExtractor.extractedDeclarations {
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            let name = structDecl.name.text
            // print("Struct: \(name)")
            namedDeclarations.append(NamedDeclaration(name: name, declaration: declaration))
        } 
        else if let classDecl = declaration.as(ClassDeclSyntax.self) {
            let isBuilderInheritance = classDecl.inheritanceClause?.inheritedTypes.contains(where: { $0.type.as(IdentifierTypeSyntax.self)?.name.text == "Builder" }) ?? true
            if !isBuilderInheritance {
                let name = classDecl.name.text
                namedDeclarations.append(NamedDeclaration(name: name, declaration: declaration))
            }
        }
        else if let protocolDecl = declaration.as(ProtocolDeclSyntax.self) {
            let name = protocolDecl.name.text
            // print("Protocol: \(name)")
            namedDeclarations.append(NamedDeclaration(name: name, declaration: declaration))
        } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            let name = enumDecl.name.text
            // print("Enum: \(name)")
            namedDeclarations.append(NamedDeclaration(name: name, declaration: declaration))
        } else if let extensionDecl = declaration.as(ExtensionDeclSyntax.self) {
            let name = extensionDecl.extendedType.description
            namedDeclarations.append(NamedDeclaration(name: name, declaration: declaration))
        } else if let typealiasDecl = declaration.as(TypealiasDeclSyntax.self) {
            let name = typealiasDecl.name.text
            // print("Typealias: \(name)")
            namedDeclarations.append(NamedDeclaration(name: name, declaration: declaration))
        } else if let funcDecl = declaration.as(FunctionDeclSyntax.self) {
            let name = funcDecl.name.text
            // print("Function: \(name)")
            namedDeclarations.append(NamedDeclaration(name: name, declaration: declaration))
        }
    }
    
    return namedDeclarations
}

private class ModuleInterfaceRewriter: SyntaxRewriter {
    var importedModules: Set<String> = []

    var interfaceDeclarations: [NamedDeclaration] = []
    var additionalDeclarations: [NamedDeclaration] = []

    // Add this new property to keep track of processed extensions
    private var processedExtensions: Set<String> = []

    // Remove import statements containing underscores
    override func visit(_ node: ImportDeclSyntax) -> DeclSyntax {
        guard let importText = node.path.as(ImportPathComponentListSyntax.self)?.first?.name.text else {
            return DeclSyntax(node)
        }
        guard importText.contains("_") else {
            importedModules.insert(importText)
            return DeclSyntax(node)
        }
        return DeclSyntax(MissingDeclSyntax(placeholder: TokenSyntax(.unknown(""), presence: .missing)))
    }
    
    // Simplify member type syntax by removing the first component if it's already imported
    override func visit(_ node: MemberTypeSyntax) -> TypeSyntax {
        let simplifiedName = node.name.text
        return TypeSyntax(IdentifierTypeSyntax(name: .identifier(simplifiedName)))
    }
    
    // Remove 'some' or 'any' keywords from types
    override func visit(_ node: SomeOrAnyTypeSyntax) -> TypeSyntax {
        return visit(node.constraint)
    }
    
    // Visit composition type elements
    override func visit(_ node: CompositionTypeElementSyntax) -> CompositionTypeElementSyntax {
        let newElement = node.with(\.type, visit(node.type))
        return newElement
    }
    
    // Remove classes that inherit from 'Builder'
    override func visit(_ node: ClassDeclSyntax) -> DeclSyntax {
        if let inheritanceClause = node.inheritanceClause,
           inheritanceClause.inheritedTypes.contains(where: { $0.type.as(MemberTypeSyntax.self)?.name.text == "Builder" }) {
            return DeclSyntax(MissingDeclSyntax(placeholder: TokenSyntax(.unknown(""), presence: .missing)))
        }
        
        // For classes that don't inherit from 'Builder', proceed with normal processing
        if let index = interfaceDeclarations.firstIndex(where: { $0.name == node.name.text }),
           let additionalDecl = additionalDeclarations.first(where: { $0.name == node.name.text }) {
            return DeclSyntax(additionalDecl.declaration)
        }
        
        return super.visit(node)
    }


    // Remove protocols that inherit from 'Builder'
    override func visit(_ node: ProtocolDeclSyntax) -> DeclSyntax {
        // The Builder check has been removed for protocols
        
        // Check if the protocol declaration exists in interfaceDeclarations
        if let index = interfaceDeclarations.firstIndex(where: { $0.name == node.name.text }) {
            // If it exists, find the matching declaration in additionalDeclarations
            if let additionalDecl = additionalDeclarations.first(where: { $0.name == node.name.text }) {
                // Replace the declaration with the one from additionalDeclarations
                return DeclSyntax(additionalDecl.declaration)
            }
        }
        
        return super.visit(node)
    }
    
    // Handle struct declarations
    override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        // Check if the struct declaration exists in interfaceDeclarations
        if let index = interfaceDeclarations.firstIndex(where: { $0.name == node.name.text }) {
            // If it exists, find the matching declaration in additionalDeclarations
            if let additionalDecl = additionalDeclarations.first(where: { $0.name == node.name.text }) {
                // Replace the declaration with the one from additionalDeclarations
                return DeclSyntax(additionalDecl.declaration)
            }
        }
        
        return super.visit(node)
    }
    
    // Handle enum declarations
    override func visit(_ node: EnumDeclSyntax) -> DeclSyntax {
        // Check if the enum declaration exists in interfaceDeclarations
        if let index = interfaceDeclarations.firstIndex(where: { $0.name == node.name.text }) {
            // If it exists, find the matching declaration in additionalDeclarations
            if let additionalDecl = additionalDeclarations.first(where: { $0.name == node.name.text }) {
                // Replace the declaration with the one from additionalDeclarations
                return DeclSyntax(additionalDecl.declaration)
            }
        }
        
        return super.visit(node)
    }
    
    // Handle typealias declarations
    override func visit(_ node: TypeAliasDeclSyntax) -> DeclSyntax {
        // Check if the typealias declaration exists in interfaceDeclarations
        if let index = interfaceDeclarations.firstIndex(where: { $0.name == node.name.text }) {
            // If it exists, find the matching declaration in additionalDeclarations
            if let additionalDecl = additionalDeclarations.first(where: { $0.name == node.name.text }) {
                // Replace the declaration with the one from additionalDeclarations
                return DeclSyntax(additionalDecl.declaration)
            }
        }
        
        return super.visit(node)
    }

    // Handle extension declarations
    override func visit(_ node: ExtensionDeclSyntax) -> DeclSyntax {
        let extensionKey = "\(node.extendedType.description)"
        
        // If we've already processed this extension, skip it
        if processedExtensions.contains(extensionKey) {
            return DeclSyntax(MissingDeclSyntax(placeholder: TokenSyntax(.unknown(""), presence: .missing)))
        }
        
        // Mark this extension as processed
        processedExtensions.insert(extensionKey)
        
        // Check if the extension declaration exists in interfaceDeclarations
        let matchingInterfaceDeclarations = interfaceDeclarations.filter { $0.name == node.extendedType.description }
        if !matchingInterfaceDeclarations.isEmpty {
            // Find all matching declarations in additionalDeclarations
            let matchingAdditionalDeclarations = additionalDeclarations.filter { $0.name == node.extendedType.description }
            if !matchingAdditionalDeclarations.isEmpty {
                // Combine all matching extension declarations
                let combinedExtensions = matchingAdditionalDeclarations.compactMap { $0.declaration.as(ExtensionDeclSyntax.self) }
                let combinedMembers = combinedExtensions.flatMap { $0.memberBlock.members }
                
                return DeclSyntax(ExtensionDeclSyntax(
                    extensionKeyword: .identifier("extension", leadingTrivia: .newlines(2), trailingTrivia: .space),
                    extendedType: node.extendedType,
                    inheritanceClause: node.inheritanceClause,
                    genericWhereClause: node.genericWhereClause,
                    memberBlock: MemberDeclBlockSyntax(
                        leftBrace: .leftBraceToken(),
                        members: MemberDeclListSyntax(combinedMembers),
                        rightBrace: .rightBraceToken().with(\.leadingTrivia, .newline)
                    )
                ))
            }
        }
        
        // If no matching declaration is found, keep the original extension
        return super.visit(node)
    }
}
