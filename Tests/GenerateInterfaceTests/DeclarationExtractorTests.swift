import XCTest
import SwiftSyntax
import SwiftParser
@testable import generateInterface

final class DeclarationExtractorTests: XCTestCase {
    func testExtractsStructDeclarations() {
        let source = """
        public struct MyModel {
            let name: String
        }
        """
        let declarations = extractDeclarations(from: source)
        XCTAssertEqual(declarations.count, 1)
        XCTAssertTrue(declarations[0].is(StructDeclSyntax.self))
    }

    func testExtractsClassDeclarations() {
        let source = """
        public class MyService {
            func doWork() {}
        }
        """
        let declarations = extractDeclarations(from: source)
        XCTAssertEqual(declarations.count, 1)
        XCTAssertTrue(declarations[0].is(ClassDeclSyntax.self))
    }

    func testExtractsProtocolDeclarations() {
        let source = """
        public protocol MyProtocol {
            func execute()
        }
        """
        let declarations = extractDeclarations(from: source)
        XCTAssertEqual(declarations.count, 1)
        XCTAssertTrue(declarations[0].is(ProtocolDeclSyntax.self))
    }

    func testExtractsEnumDeclarations() {
        let source = """
        public enum State {
            case active
            case inactive
        }
        """
        let declarations = extractDeclarations(from: source)
        XCTAssertEqual(declarations.count, 1)
        XCTAssertTrue(declarations[0].is(EnumDeclSyntax.self))
    }

    func testExtractsTypealiasDeclarations() {
        let source = """
        public typealias Handler = (String) -> Void
        """
        let declarations = extractDeclarations(from: source)
        XCTAssertEqual(declarations.count, 1)
        XCTAssertTrue(declarations[0].is(TypeAliasDeclSyntax.self))
    }

    func testExtractsExtensionDeclarations() {
        let source = """
        extension String {
            var isEmpty: Bool { count == 0 }
        }
        """
        let declarations = extractDeclarations(from: source)
        XCTAssertEqual(declarations.count, 1)
        XCTAssertTrue(declarations[0].is(ExtensionDeclSyntax.self))
    }

    func testExtractsMultipleDeclarations() {
        let source = """
        public struct MyModel {
            let name: String
        }
        public protocol MyProtocol {
            func execute()
        }
        public enum State {
            case active
        }
        extension MyModel: MyProtocol {
            func execute() {}
        }
        """
        let declarations = extractDeclarations(from: source)
        XCTAssertEqual(declarations.count, 4)
    }

    func testSkipsChildDeclarations() {
        let source = """
        public struct Outer {
            struct Inner {
                let value: Int
            }
            let inner: Inner
        }
        """
        let declarations = extractDeclarations(from: source)
        // Should only extract Outer, not Inner (skipChildren)
        XCTAssertEqual(declarations.count, 1)
    }

    func testIgnoresFunctionDeclarations() {
        let source = """
        func topLevelFunction() {}
        """
        let declarations = extractDeclarations(from: source)
        XCTAssertEqual(declarations.count, 0)
    }

    // MARK: - Helpers

    private func extractDeclarations(from source: String) -> [DeclSyntax] {
        let sourceFile = Parser.parse(source: source)
        let extractor = DeclarationExtractor(viewMode: .sourceAccurate)
        extractor.walk(sourceFile)
        return extractor.extractedDeclarations
    }
}
