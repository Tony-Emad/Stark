import XCTest
@testable import Stark

final class StarkMatchPolicyTests: XCTestCase {
    func testAcceptsOnlyWhenAllGatesPass() {
        XCTAssertTrue(StarkMatchPolicy.accepts(distance: 0.40, livenessScore: 0.80, confidence: 0.90))
        XCTAssertFalse(StarkMatchPolicy.accepts(distance: 0.80, livenessScore: 0.80, confidence: 0.90))
        XCTAssertFalse(StarkMatchPolicy.accepts(distance: 0.40, livenessScore: 0.10, confidence: 0.90))
        XCTAssertFalse(StarkMatchPolicy.accepts(distance: 0.40, livenessScore: 0.80, confidence: 0.20))
    }

    func testLivenessNeedsMovementAndEnoughObservationTime() {
        XCTAssertTrue(StarkLivenessPolicy.accepts(score: 0.60, windowCoverage: 0.80))
        XCTAssertFalse(StarkLivenessPolicy.accepts(score: 0.20, windowCoverage: 0.80))
        XCTAssertFalse(StarkLivenessPolicy.accepts(score: 0.60, windowCoverage: 0.20))
    }

    func testLivenessScoreIsBounded() {
        XCTAssertEqual(StarkLivenessPolicy.score(motion: 0, windowCoverage: 0), 0)
        XCTAssertEqual(StarkLivenessPolicy.score(motion: 1, windowCoverage: 2), 1)
    }

    func testIdentityRoundTripsWithoutChangingSamples() throws {
        let identity = FaceIdentity(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 123),
            featurePrints: [Data([0, 1, 2]), Data([3, 4, 5])]
        )
        let data = try JSONEncoder().encode(identity)
        let decoded = try JSONDecoder().decode(FaceIdentity.self, from: data)

        XCTAssertEqual(decoded.id, identity.id)
        XCTAssertEqual(decoded.createdAt, identity.createdAt)
        XCTAssertEqual(decoded.featurePrints, identity.featurePrints)
    }

    func testAutoLockSettingIsKeptInsideSafeBounds() {
        XCTAssertEqual(StarkSessionPolicy.clampAutoLockMinutes(0), 1)
        XCTAssertEqual(StarkSessionPolicy.clampAutoLockMinutes(90), 60)
        XCTAssertEqual(StarkSessionPolicy.clampAutoLockMinutes(5), 5)
    }
}
