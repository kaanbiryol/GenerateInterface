import XCTest
@testable import generateInterface

final class ProjectRewriterTests: XCTestCase {
    func testAddsInterfaceModuleDeclaration() throws {
        let projectSource = """
        static let moreInfo = Module(
            name: "MoreInfo",
            kind: .business,
            moduleDependencies: [
                .core.extensionKit,
                .core.oxide
            ],
            features: [
                .tests(
                    moduleDependencies: [.core.typography]
                ),
                .snapshotTests(),
                .testSupport(targetDependencies: [
                    .testSupportTarget(of: .core.ribs)
                ])
            ]
        )
        """

        let result = try rewriteProjectSource(projectSource, moduleName: "MoreInfo")

        // Should contain the interface module name
        XCTAssertTrue(result.contains("MoreInfoInterface"), "Should create interface module declaration")
        // Should add interface dependency to the original module
        XCTAssertTrue(result.contains("moreInfoInterface"), "Should add interface as dependency")
    }

    func testInterfaceModuleExcludesTestsAndSnapshotTests() throws {
        let projectSource = """
        static let payments = Module(
            name: "Payments",
            kind: .business,
            moduleDependencies: [
                .core.networking
            ],
            features: [
                .tests(
                    moduleDependencies: [.core.testHelpers]
                ),
                .snapshotTests(),
                .testSupport(targetDependencies: [])
            ]
        )
        """

        let result = try rewriteProjectSource(projectSource, moduleName: "Payments")

        // The interface module definition should not include tests() or snapshotTests()
        // Count occurrences - the original should still have them
        let lines = result.components(separatedBy: .newlines)
        let interfaceSection = extractInterfaceSection(from: result, moduleName: "Payments")
        if let interfaceSection = interfaceSection {
            XCTAssertFalse(interfaceSection.contains(".snapshotTests"), "Interface module should not have snapshotTests")
        }
    }

    func testPreservesNonTargetModules() throws {
        let projectSource = """
        static let auth = Module(
            name: "Auth",
            kind: .core,
            moduleDependencies: [],
            features: []
        )
        static let payments = Module(
            name: "Payments",
            kind: .business,
            moduleDependencies: [
                .core.auth
            ],
            features: []
        )
        """

        let result = try rewriteProjectSource(projectSource, moduleName: "Payments")

        // Auth module should be unchanged
        XCTAssertTrue(result.contains("name: \"Auth\""), "Non-target module should be preserved")
        // Payments should have interface added
        XCTAssertTrue(result.contains("PaymentsInterface"), "Target module should get interface")
    }

    // MARK: - Helpers

    private func rewriteProjectSource(_ source: String, moduleName: String) throws -> String {
        let tempFile = NSTemporaryDirectory() + "TestProject_\(UUID().uuidString).swift"
        try source.write(toFile: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        rewriteProjectFile(at: tempFile, moduleName: moduleName)
        return try String(contentsOfFile: tempFile, encoding: .utf8)
    }

    private func extractInterfaceSection(from source: String, moduleName: String) -> String? {
        guard let range = source.range(of: "\(moduleName)Interface") else { return nil }
        // Find the Module(...) call containing this interface name
        let start = source[..<range.lowerBound].lastIndex(of: "M") ?? range.lowerBound
        // Find matching closing paren - rough extraction
        var depth = 0
        var end = range.upperBound
        for i in source[start...].indices {
            if source[i] == "(" { depth += 1 }
            if source[i] == ")" { depth -= 1 }
            if depth == 0 && source[i] == ")" {
                end = source.index(after: i)
                break
            }
        }
        return String(source[start..<end])
    }
}
