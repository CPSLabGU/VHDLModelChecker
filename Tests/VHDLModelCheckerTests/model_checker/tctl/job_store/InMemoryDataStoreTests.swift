import Foundation
import TCTLParser
import VHDLKripkeStructures
import XCTest

@testable import VHDLModelChecker

final class InMemoryDataStoreTests: JobStorableTestCase {

    override func setUp() {
        super.setUp()
        super.store = InMemoryDataStore()
    }

    func testCanAddJobs() throws {
        try super._testCanAddJobs()
    }

    func testCanAddManyJobs() throws {
        try super._testCanAddManyJobs()
    }

    func testInCycle() throws {
        try super._testInCycle()
    }

    func testReset() throws {
        try super._testReset()
    }

    func testSessions() throws {
        try super._testSessions()
    }

    func testSessionStatus() throws {
        try super._testSessionStatus()
    }

    func testNextPerformance() throws {
        try super._testNextPerformance()
    }

    func testPendingSessionJob() throws {
        try super._testPendingSessionJob()
    }

    func testAddJobDataPerformance() throws {
        try super._testAddJobDataPerformance()
    }

    func testAddJobPerformance() throws {
        try super._testAddJobPerformance()
    }

    func testAddManyJobPerformance() throws {
        try super._testAddManyJobPerformance()
    }

    func testCompletePendingSessionPerformance() throws {
        try super._testCompletePendingSessionPerformance()
    }

    func testInCyclePerformance() throws {
        try super._testInCyclePerformance()
    }

    func testIsPendingPerformance() throws {
        try super._testIsPendingPerformance()
    }

    func testJobFromDataPerformance() throws {
        try super._testJobFromDataPerformance()
    }

    func testJobFromIDPerformance() throws {
        try super._testJobFromIDPerformance()
    }

}
