import Foundation
import SwiftSyntax
import SwiftParser

func rewriteProjectFile(at filePath: String, moduleName: String) {
    do {
        let sourceCode = try Parser.parse(source: String(contentsOfFile: filePath, encoding: .utf8))
        let rewriter = ProjectRewriter(targetModuleName: moduleName)
        let newSourceFile = rewriter.visit(sourceCode)
        let newSourceCode = newSourceFile.description
        try newSourceCode.write(toFile: filePath, atomically: true, encoding: .utf8)
    } catch {
        print("Error parsing Project.swift \(error)")
    }
}

private class ProjectRewriter: SyntaxRewriter {
    let targetModuleName: String
    
    init(targetModuleName: String) {
        self.targetModuleName = targetModuleName
        super.init()
    }
    
    //  Module(
    //      name: "MoreInfo",
    //      kind: .business,
    //      moduleDependencies: [
    //          .core.extensionKit,
    //          .core.oxide,
    //          .core.reusableViewControllers,
    //          .core.ribs, .business.moreInfoInterface
    //      ],
    //      features: [
    //          .tests(
    //              moduleDependencies: [.core.typography]
    //          ),
    //          .snapshotTests(),
    //          .testSupport(targetDependencies: [
    //              .testSupportTarget(of: .core.ribs)
    //          ])
    //      ]
    //  )
    //  name: "MoreInfo",
    private func functionCallAndNameDeclarationForModule(node: VariableDeclSyntax) -> (functionCallExpression: FunctionCallExprSyntax, nameArgument: LabeledExprListSyntax.Element)?  {
        if let binding = node.bindings.first,
           let functionCallExpression = binding.initializer?.value.as(FunctionCallExprSyntax.self),
           functionCallExpression.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "Module",
           let nameArgument = functionCallExpression.arguments.first(where: { $0.label?.text == "name" }),
           nameArgument.expression.as(StringLiteralExprSyntax.self)?.segments.first?.as(StringSegmentSyntax.self)?.content.text == targetModuleName
        {
            return (functionCallExpression, nameArgument)
        }
        return nil
    }
    
    //  static let moreInfo = Module(
    //      name: "MoreInfo",
    //      kind: .business,
    //      moduleDependencies: [
    //          .core.extensionKit,
    //          .core.oxide,
    //          .core.reusableViewControllers,
    //          .core.ribs, .business.moreInfoInterface, .business.moreInfoInterface
    //      ],
    //      features: [
    //           .tests(
    //              moduleDependencies: [.core.typography]
    //            ),
    //            .snapshotTests(),
    //            .testSupport(targetDependencies: [
    //              .testSupportTarget(of: .core.ribs)
    //             ])
    //          ]
    //      )
    //
    //
    //
    //  static let  moreInfoInterface = Module(
    //      name: "MoreInfoInterface",
    //      kind: .business,
    //      moduleDependencies: [
    //          .core.extensionKit,
    //          .core.oxide,
    //          .core.reusableViewControllers,
    //          .core.ribs, .business.moreInfoInterface, .business.moreInfoInterface
    //      ],
    //      features: [
    //          .testSupport(targetDependencies: [
    //              .testSupportTarget(of: .core.ribs)
    //          ])
    //      ]
    //  )
    private func generateInterfaceAndImplementationModuleExpression(node: VariableDeclSyntax, nameArgument: LabeledExprListSyntax.Element) -> (modifiedCurrentDecl: VariableDeclSyntax, newInterfaceDecl: VariableDeclSyntax)? {
        if var newBinding = node.bindings.first,
           var newFunctionCall = newBinding.initializer?.value.as(FunctionCallExprSyntax.self) {

            // Get the kind parameter value
            var kindValue: String = ""
            if let kindArgumentIndex = newFunctionCall.arguments.firstIndex(where: { $0.label?.text == "kind" }),
               let memberAccessExpr = newFunctionCall.arguments[kindArgumentIndex].expression.as(MemberAccessExprSyntax.self) {
                kindValue = memberAccessExpr.name.text
            }
            
            // Create "ModuleNameInterface"
            let contentToken = TokenSyntax.stringSegment("\(targetModuleName)Interface")
            let segment = StringSegmentSyntax(content: contentToken)
            let segments = StringLiteralSegmentListSyntax([.stringSegment(segment)])
            let newStringLiteral = StringLiteralExprSyntax(
                openingQuote: .stringQuoteToken(),
                segments: segments,
                closingQuote: .stringQuoteToken()
            )
            let newNameArgument = nameArgument.with(\.expression, ExprSyntax(newStringLiteral))
            
            // Create name: "ModuleNameInterface"
            if let nameArgumentIndex = newFunctionCall.arguments.firstIndex(where: { $0.label?.text == "name" }) {
                newFunctionCall.arguments = newFunctionCall.arguments.with(
                    \.[nameArgumentIndex],
                     newNameArgument
                )
            }
            
            // Remove snapshotTests() and tests() from features
            if let featuresArgumentIndex = newFunctionCall.arguments.firstIndex(where: { $0.label?.text == "features" }) {
                print("featuresArgumentIndex: \(featuresArgumentIndex)")
                if var featuresArray = newFunctionCall.arguments[featuresArgumentIndex].expression.as(ArrayExprSyntax.self) {
                    featuresArray.elements = ArrayElementListSyntax(
                        featuresArray.elements.filter { element in
                            if let functionCall = element.expression.as(FunctionCallExprSyntax.self) {
                                let functionName = functionCall.calledExpression.as(MemberAccessExprSyntax.self)?.name.text
                                return functionName != "snapshotTests" && functionName != "tests"
                            }
                            return true
                        }
                    )
                    newFunctionCall.arguments = newFunctionCall.arguments.with(
                        \.[featuresArgumentIndex].expression,
                        ExprSyntax(featuresArray)
                    )
                }
            }

            newBinding.initializer?.value = ExprSyntax(newFunctionCall)
            
            // Create moduleNameInterface = Module(...
            let newIdentifier = newBinding.pattern.as(IdentifierPatternSyntax.self)!.with(
                \.identifier,
                 .identifier(" \(targetModuleName.camelCased)Interface ")
            )
            newBinding = newBinding.with(\.pattern, PatternSyntax(newIdentifier))
            
            // Create the whole new interface declaration
            let newInterfaceDecl = VariableDeclSyntax(
                attributes: node.attributes,
                modifiers: node.modifiers,
                bindingSpecifier: node.bindingSpecifier,
                bindings: PatternBindingListSyntax([newBinding])
            ).with(\.trailingTrivia, .newlines(2)).with(\.leadingTrivia, .newline)
            
            // Modify the current declaration
            let modifiedCurrentDecl = node.with(\.bindings, PatternBindingListSyntax(
                node.bindings.enumerated().map { index, binding in
                    if index == 0 {
                        var modifiedBinding = binding.with(\.leadingTrivia, .tab + .unexpectedText("static let "))
                        if var functionCall = modifiedBinding.initializer?.value.as(FunctionCallExprSyntax.self) {
                            if let moduleDependenciesIndex = functionCall.arguments.firstIndex(where: { $0.label?.text == "moduleDependencies" }) {
                                if var moduleDependenciesArray = functionCall.arguments[moduleDependenciesIndex].expression.as(ArrayExprSyntax.self) {
                                    let newDependency = ArrayElementSyntax(
                                        expression: ExprSyntax(
                                            MemberAccessExprSyntax(
                                                base: DeclReferenceExprSyntax(
                                                    baseName: .identifier(".\(kindValue)")
                                                ),
                                                name: .identifier("\(self.targetModuleName.camelCased)Interface")
                                            )
                                        )
                                    )
                                    if var lastElement = moduleDependenciesArray.elements.last {
                                        lastElement = lastElement.with(\.trailingTrivia, .unexpectedText(",") + lastElement.leadingTrivia)
                                        moduleDependenciesArray.elements = moduleDependenciesArray.elements.dropLast() + [lastElement, newDependency]
                                    } else {
                                        moduleDependenciesArray.elements = moduleDependenciesArray.elements.appending(newDependency)
                                    }
                                    
                                    functionCall.arguments = functionCall.arguments.with(
                                        \.[moduleDependenciesIndex].expression,
                                        ExprSyntax(moduleDependenciesArray)
                                    )
                                }
                            }
                            
                            if let featuresIndex = functionCall.arguments.firstIndex(where: { $0.label?.text == "features" }) {
                                if var featuresArray = functionCall.arguments[featuresIndex].expression.as(ArrayExprSyntax.self) {
                                    if let testsIndex = featuresArray.elements.firstIndex(where: { element in
                                        if let functionCall = element.expression.as(FunctionCallExprSyntax.self) {
                                            return functionCall.calledExpression.as(MemberAccessExprSyntax.self)?.name.text == "tests"
                                        }
                                        return false
                                    }) {
                                        // Add tests(targetDependencies: [.testSupportTarget(of: .business.moreInfo)])
                                        if var testsCall = featuresArray.elements[testsIndex].expression.as(FunctionCallExprSyntax.self),
                                           let targetDependenciesIndex = testsCall.arguments.firstIndex(where: { $0.label?.text == "targetDependencies" }) {
                                            if var targetDependenciesArray = testsCall.arguments[targetDependenciesIndex].expression.as(ArrayExprSyntax.self) {
                                                let newTestSupportTarget = ArrayElementSyntax(
                                                    expression: ExprSyntax(
                                                        FunctionCallExprSyntax(
                                                            calledExpression: MemberAccessExprSyntax(
                                                                base: DeclReferenceExprSyntax(baseName: .identifier("")),
                                                                name: .identifier("testSupportTarget")
                                                            ),
                                                            arguments: LabeledExprListSyntax([
                                                                LabeledExprSyntax(
                                                                    label: .identifier("(of: "),
                                                                    expression: ExprSyntax(
                                                                        MemberAccessExprSyntax(
                                                                            base: DeclReferenceExprSyntax(baseName: .identifier(".\(kindValue)")),
                                                                            name: .identifier("\(self.targetModuleName.camelCased)Interface)")
                                                                        )
                                                                    )
                                                                )
                                                            ])
                                                        )
                                                    )
                                                )
                                                if var lastElement = targetDependenciesArray.elements.last {
                                                    lastElement = lastElement.with(\.trailingTrivia, .unexpectedText(",") + lastElement.leadingTrivia)
                                                    targetDependenciesArray.elements = targetDependenciesArray.elements.dropLast() + [lastElement]
                                                }
                                                targetDependenciesArray.elements = targetDependenciesArray.elements + [
                                                    newTestSupportTarget
                                                ]
                                                testsCall.arguments = testsCall.arguments.with(
                                                    \.[targetDependenciesIndex].expression,
                                                    ExprSyntax(targetDependenciesArray)
                                                )
                                                featuresArray.elements = featuresArray.elements.with(\.[testsIndex].expression, ExprSyntax(testsCall))
                                            }
                                        }
                                    }
                                    if let testSupportIndex = featuresArray.elements.firstIndex(where: { element in
                                        if let functionCall = element.expression.as(FunctionCallExprSyntax.self) {
                                            return functionCall.calledExpression.as(MemberAccessExprSyntax.self)?.name.text == "testSupport"
                                        }
                                        return false
                                    }) {
                                        if var testSupportCall = featuresArray.elements[testSupportIndex].expression.as(FunctionCallExprSyntax.self),
                                           let targetDependenciesIndex = testSupportCall.arguments.firstIndex(where: { $0.label?.text == "targetDependencies" }) {
                                            if var targetDependenciesArray = testSupportCall.arguments[targetDependenciesIndex].expression.as(ArrayExprSyntax.self) {
                                                // Add .testSupport(targetDependencies: [.testSupportTarget(of: .business.moreInfo)]
                                                let newTestSupportTarget = ArrayElementSyntax(
                                                    expression: ExprSyntax(
                                                        FunctionCallExprSyntax(
                                                            calledExpression: MemberAccessExprSyntax(
                                                                base: DeclReferenceExprSyntax(baseName: .identifier("")),
                                                                name: .identifier("testSupportTarget")
                                                            ), 
                                                            arguments: LabeledExprListSyntax([
                                                                LabeledExprSyntax(
                                                                    label: .identifier("(of:"),
                                                                    expression: ExprSyntax(
                                                                        MemberAccessExprSyntax(
                                                                            base: DeclReferenceExprSyntax(baseName: .identifier(" .\(kindValue)")),
                                                                            name: .identifier("\(self.targetModuleName.camelCased)Interface)")
                                                                        )
                                                                    )
                                                                )
                                                            ])
                                                        )
                                                    )
                                                 ).with(\.leadingTrivia, targetDependenciesArray.elements.first?.leadingTrivia ?? .newline)
                                                
                                                if let lastIndex = targetDependenciesArray.elements.indices.last {
                                                    targetDependenciesArray.elements[lastIndex] = targetDependenciesArray.elements[lastIndex].with(\.trailingTrivia, .unexpectedText(","))
                                                }
                                                targetDependenciesArray.elements = targetDependenciesArray.elements + [newTestSupportTarget]
                                                testSupportCall.arguments = testSupportCall.arguments.with(
                                                    \.[targetDependenciesIndex].expression,
                                                    ExprSyntax(targetDependenciesArray)
                                                )
                                                featuresArray.elements = featuresArray.elements.with(\.[testSupportIndex].expression, ExprSyntax(testSupportCall))
                                            }
                                        }
                                    }
                                    functionCall.arguments = functionCall.arguments.with(
                                        \.[featuresIndex].expression,
                                        ExprSyntax(featuresArray)
                                    )
                                }
                            }
                            
                            modifiedBinding.initializer?.value = ExprSyntax(functionCall)
                        }
                        return modifiedBinding
                    }
                    return binding
                }
            )).with(\.leadingTrivia, .tab)
            
            return (modifiedCurrentDecl, newInterfaceDecl)
        }
        return nil
    }
    
    override func visit(_ node: VariableDeclSyntax) -> DeclSyntax {
        if let expression = functionCallAndNameDeclarationForModule(node: node) {
            let nameArgument = expression.nameArgument
            
            // Modify the name of the new module
            let generatedModuleExpressions = generateInterfaceAndImplementationModuleExpression(node: node, nameArgument: nameArgument)!
            let oldDecl = generatedModuleExpressions.modifiedCurrentDecl
            
            let combinedDeclarations = [generatedModuleExpressions.newInterfaceDecl, oldDecl]
            
            let combinedNode = VariableDeclSyntax(
                bindingSpecifier: .unknown("static let"),
                bindings: PatternBindingListSyntax(combinedDeclarations.flatMap { $0.bindings })
            ).with(\.leadingTrivia, .newlines(2) + .tab)
            
            return DeclSyntax(combinedNode)
        }
        
        return super.visit(node)
    }
    
    // Replace module expressions with the interface ones
    override func visit(_ node: MemberAccessExprSyntax) -> ExprSyntax {
        let baseExpression = node.base?.as(MemberAccessExprSyntax.self)
        if let base = baseExpression?.declName.baseName.text,
           base == "core" || base == "service" || base == "business",
           node.declName.baseName.text.lowercased() == targetModuleName.lowercased()
        {
            guard let parentVariableDeclaration = findParentVariableDeclaration(for: Syntax(node)),
                  let binding = parentVariableDeclaration.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  let typeAnnotation = binding.typeAnnotation?.type,
                  pattern.identifier.text == "modules",
                  typeAnnotation.as(IdentifierTypeSyntax.self)?.name.text == "Set"
            else {
                return ExprSyntax(
                    MemberAccessExprSyntax(
                        base: baseExpression,
                        dot: .periodToken(),
                        name: .identifier("\(targetModuleName.camelCased)Interface")
                    )
                )
            }
            
            let newMemberAccess = MemberAccessExprSyntax(
                base: node.base!,
                dot: .periodToken(),
                name: .identifier("\(targetModuleName.camelCased)Interface")
            )
            
            // Add the new interface expression to the "modules" Set we have
            let modifiedNode = node.with(\.trailingTrivia, .unexpectedText(",") + .newline)
            let newElement = ExprSyntax(newMemberAccess)
                .with(\.leadingTrivia, .spaces(node.leadingTriviaLength.utf8Length - 1))
                .with(\.trailingTrivia, node.trailingTrivia)
            
            return ExprSyntax(
                SequenceExprSyntax(
                    elements: ExprListSyntax([
                        ExprSyntax(modifiedNode),
                        newElement
                    ])
                )
            )
        }
        
        return super.visit(node)
    }
    
    private func findParentVariableDeclaration(for node: Syntax) -> VariableDeclSyntax? {
        var currentNode: Syntax? = node
        while let parent = currentNode?.parent {
            if let variableDecl = parent.as(VariableDeclSyntax.self) {
                return variableDecl
            }
            currentNode = parent
        }
        return nil
    }
}
