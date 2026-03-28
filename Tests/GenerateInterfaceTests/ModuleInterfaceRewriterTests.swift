import XCTest
@testable import generateInterface

final class ModuleInterfaceRewriterTests: XCTestCase {
    func testRemovesUnderscoreImports() {
        let source = """
        import Foundation
        import _Concurrency
        import _StringProcessing
        import UIKit

        public struct MyModel {}
        """
        let result = rewriteModuleInterface(sourceText: source, additionalFiles: [], moduleName: "MyModule")!
        XCTAssertTrue(result.contains("import Foundation"))
        XCTAssertTrue(result.contains("import UIKit"))
        XCTAssertFalse(result.contains("_Concurrency"))
        XCTAssertFalse(result.contains("_StringProcessing"))
    }

    func testRemovesSomeKeyword() {
        let source = """
        import Foundation

        public struct MyView {
            public var body: some View { fatalError() }
        }
        """
        let result = rewriteModuleInterface(sourceText: source, additionalFiles: [], moduleName: "MyModule")!
        XCTAssertFalse(result.contains("some View"))
        XCTAssertTrue(result.contains("View"))
    }

    func testRemovesAnyKeyword() {
        let source = """
        import Foundation

        public func handle(error: any Error) {}
        """
        let result = rewriteModuleInterface(sourceText: source, additionalFiles: [], moduleName: "MyModule")!
        XCTAssertFalse(result.contains("any Error"))
        XCTAssertTrue(result.contains("Error"))
    }

    func testRemovesBuilderClasses() {
        let source = """
        import Foundation

        public class MyService {}
        public class MyBuilder: Builder {}
        """
        let result = rewriteModuleInterface(sourceText: source, additionalFiles: [], moduleName: "MyModule")!
        XCTAssertTrue(result.contains("MyService"))
        XCTAssertFalse(result.contains("MyBuilder"))
    }

    func testSimplifiesMemberTypeSyntax() {
        let source = """
        import Foundation

        public func getValue() -> Swift.String { "" }
        """
        let result = rewriteModuleInterface(sourceText: source, additionalFiles: [], moduleName: "MyModule")!
        // MemberTypeSyntax (Swift.String) should be simplified to just the name (String)
        XCTAssertTrue(result.contains("String"))
    }

    func testPreservesRegularImports() {
        let source = """
        import Foundation
        import UIKit
        import Combine

        public struct MyModel {}
        """
        let result = rewriteModuleInterface(sourceText: source, additionalFiles: [], moduleName: "MyModule")!
        XCTAssertTrue(result.contains("import Foundation"))
        XCTAssertTrue(result.contains("import UIKit"))
        XCTAssertTrue(result.contains("import Combine"))
    }

    func testReplacesDeclarationsWithSourceVersions() throws {
        let interfaceSource = """
        import Foundation

        public struct MyModel {
            public let id: String
            public let name: String
        }
        """

        // Create a temp file with the "source" version of the declaration
        let sourceContent = """
        /// A model representing a user.
        public struct MyModel {
            public let id: String
            public let name: String

            public init(id: String, name: String) {
                self.id = id
                self.name = name
            }
        }
        """
        let tempFile = NSTemporaryDirectory() + "TestSource.swift"
        try sourceContent.write(toFile: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        let result = rewriteModuleInterface(sourceText: interfaceSource, additionalFiles: [tempFile], moduleName: "MyModule")!
        // Should use the source version which includes the doc comment and init
        XCTAssertTrue(result.contains("A model representing a user"))
        XCTAssertTrue(result.contains("public init"))
    }
}
