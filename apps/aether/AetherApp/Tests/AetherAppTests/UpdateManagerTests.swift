import XCTest
@testable import AetherApp

final class UpdateManagerTests: XCTestCase {
    
    // MARK: - SemanticVersion Tests
    
    func testSemverComparison() {
        XCTAssertTrue(SemanticVersion("1.0.0")! > SemanticVersion("0.9.9")!)
        XCTAssertTrue(SemanticVersion("0.4.0")! > SemanticVersion("0.3.9")!)
        XCTAssertTrue(SemanticVersion("0.3.1")! > SemanticVersion("0.3.0")!)
        XCTAssertTrue(SemanticVersion("1.2.3")! == SemanticVersion("1.2.3")!)
        XCTAssertFalse(SemanticVersion("1.0.0")! > SemanticVersion("1.0.0")!)
    }
    
    func testSemverPrefix() {
        XCTAssertEqual(SemanticVersion("v1.0.0"), SemanticVersion("1.0.0"))
        XCTAssertTrue(SemanticVersion("v0.4.0")! > SemanticVersion("0.3.0")!)
    }
    
    func testSemverParsing() {
        XCTAssertNotNil(SemanticVersion("1.0"))
        XCTAssertNotNil(SemanticVersion("1.0.0"))
        XCTAssertNil(SemanticVersion("invalid"))
        XCTAssertNil(SemanticVersion("1"))
        
        let v = SemanticVersion("1.2")!
        XCTAssertEqual(v.major, 1)
        XCTAssertEqual(v.minor, 2)
        XCTAssertEqual(v.patch, 0)
    }
    
    func testSemverSort() {
        let versions = ["0.3.0", "1.0.0", "0.9.0", "v0.3.1"].compactMap { SemanticVersion($0) }
        let sorted = versions.sorted()
        XCTAssertEqual(sorted.last?.originalString, "1.0.0")
        XCTAssertEqual(sorted.first?.originalString, "0.3.0")
    }
    
    // MARK: - UpdateState Tests
    
    func testUpdateStateEquality() {
        XCTAssertEqual(UpdateManager.UpdateState.idle, .idle)
        XCTAssertEqual(UpdateManager.UpdateState.available(version: "1.0.0"), .available(version: "1.0.0"))
        XCTAssertNotEqual(UpdateManager.UpdateState.available(version: "1.0.0"), .available(version: "1.0.1"))
        XCTAssertNotEqual(UpdateManager.UpdateState.idle, .checking)
    }
    
    func testUpdateStateHelpers() {
        XCTAssertTrue(UpdateManager.UpdateState.downloading.isProgressState)
        XCTAssertTrue(UpdateManager.UpdateState.installing.isProgressState)
        XCTAssertFalse(UpdateManager.UpdateState.idle.isProgressState)
        
        XCTAssertTrue(UpdateManager.UpdateState.failed(error: "test").isFailedState)
        XCTAssertFalse(UpdateManager.UpdateState.idle.isFailedState)
    }
}
