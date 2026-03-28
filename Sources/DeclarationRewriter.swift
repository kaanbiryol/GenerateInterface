import SwiftSyntax

struct NamedDeclaration {
    let name: String
    let declaration: DeclSyntax
    
    init(name: String, declaration: DeclSyntax) {
        self.name = name
        self.declaration = declaration
    }
}

class DeclarationExtractor: SyntaxVisitor {
    var extractedDeclarations: [DeclSyntax] = []

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        extractedDeclarations.append(DeclSyntax(node))
        return .skipChildren
    }
    
    override func visit(_ node: TypealiasDeclSyntax) -> SyntaxVisitorContinueKind {
        extractedDeclarations.append(DeclSyntax(node))
        return .skipChildren
    }
    
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        extractedDeclarations.append(DeclSyntax(node))
        return .skipChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        extractedDeclarations.append(DeclSyntax(node))
        return .skipChildren
    }
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        extractedDeclarations.append(DeclSyntax(node))
        return .skipChildren
    }
    
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        extractedDeclarations.append(DeclSyntax(node))
        return .skipChildren
    }
}

private class DeclarationRemover: SyntaxRewriter {
    let declarationsToRemove: [DeclSyntax]
    
    init(declarationsToRemove: [DeclSyntax]) {
        self.declarationsToRemove = declarationsToRemove
    }
    
    override func visit(_ node: SourceFileSyntax) -> SourceFileSyntax {
        let newStatements = node.statements.filter { statement in
            !declarationsToRemove.contains(where: { $0.description == statement.item.description })
        }
        return node.with(\.statements, newStatements)
    }
}
