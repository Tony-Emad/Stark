import XCTest
@testable import Stark

final class StarkMatchPolicyTests: XCTestCase {
    func testAcceptsOnlyWhenAllGatesPass() {
        XCTAssertTrue(StarkMatchPolicy.accepts(distance: 0.40, livenessScore: 0.80, confidence: 0.90))
        XCTAssertFalse(StarkMatchPolicy.accepts(distance: 0.80, livenessScore: 0.80, confidence: 0.90))
        XCTAssertFalse(StarkMatchPolicy.accepts(distance: 0.40, livenessScore: 0.10, confidence: 0.90))
        XCTAssertFalse(StarkMatchPolicy.accepts(distance: 0.40, livenessScore: 0.80, confidence: 0.20))
    }
}
