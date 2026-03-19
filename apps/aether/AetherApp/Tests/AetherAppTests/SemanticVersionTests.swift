import XCTest
@testable import AetherApp

final class SemanticVersionTests: XCTestCase {
    func testVersionParsing() {
        XCTAssertNotNil(SemanticVersion("0.1.0"))
        XCTAssertNotNil(SemanticVersion("1.2.34"))
        XCTAssertNil(SemanticVersion("invalid"))
        XCTAssertNil(SemanticVersion("1.2"))
    }
    
    func testVersionComparison() {
        let v1 = SemanticVersion("0.1.0")!
        let v2 = SemanticVersion("0.2.0")!
        let v3 = SemanticVersion("0.2.1")!
        let v4 = SemanticVersion("1.0.0")!
        
        XCTAssertTrue(v2 > v1)
        XCTAssertTrue(v3 > v2)
        XCTAssertTrue(v4 > v3)
        XCTAssertTrue(v1 < v4)
        XCTAssertEqual(SemanticVersion("1.0.0"), SemanticVersion("1.0.0"))
    }
    
    func testPatchComparison() {
        let v1 = SemanticVersion("1.0.10")!
        let v2 = SemanticVersion("1.0.9")!
        XCTAssertTrue(v1 > v2)
    }
}
