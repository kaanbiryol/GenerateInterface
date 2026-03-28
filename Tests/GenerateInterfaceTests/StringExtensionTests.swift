import XCTest
@testable import generateInterface

final class StringExtensionTests: XCTestCase {
    func testLowercasingFirst() {
        XCTAssertEqual("Hello".lowercasingFirst, "hello")
        XCTAssertEqual("ABC".lowercasingFirst, "aBC")
        XCTAssertEqual("a".lowercasingFirst, "a")
        XCTAssertEqual("".lowercasingFirst, "")
    }

    func testUppercasingFirst() {
        XCTAssertEqual("hello".uppercasingFirst, "Hello")
        XCTAssertEqual("abc".uppercasingFirst, "Abc")
        XCTAssertEqual("A".uppercasingFirst, "A")
        XCTAssertEqual("".uppercasingFirst, "")
    }

    func testCamelCased() {
        XCTAssertEqual("MoreInfo".camelCased, "moreInfo")
        XCTAssertEqual("my-module".camelCased, "myModule")
        XCTAssertEqual("my_module".camelCased, "myModule")
        XCTAssertEqual("MyModule".camelCased, "myModule")
        XCTAssertEqual("single".camelCased, "single")
        XCTAssertEqual("".camelCased, "")
    }
}
