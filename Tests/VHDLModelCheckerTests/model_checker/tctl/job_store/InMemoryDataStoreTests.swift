import Foundation
import TCTLParser
import VHDLKripkeStructures
import XCTest

@testable import VHDLModelChecker

/// Test in-memory data store.
final class InMemoryDataStoreTests: JobStorableTestCase {

    /// Set up the test case.
    override func setUp() {
        super.setUp()
        super.store = InMemoryDataStore()
    }

    /// Test can add jobs.
    func testCanAddJobs() throws {
        try super._testCanAddJobs()
    }

    /// Test fails session.
    func testFailsSession() throws {
        try super._testFailsSession()
    }

    /// Test in cycle.
    func testInCycle() throws {
        try super._testInCycle()
    }

    /// Test job for data.
    func testJobForData() throws {
        try super._testJobFromData()
    }

    /// Test job with ID.
    func testJobWithID() throws {
        try super._testJobWithID()
    }

    /// Test next.
    func testNext() throws {
        try super._testNext()
    }

    /// Test reset.
    func testReset() throws {
        try super._testReset()
    }

    /// Test next performance.
    func testNextPerformance() throws {
        try super._testNextPerformance()
    }

    /// Test add job data performance.
    func testAddJobDataPerformance() throws {
        try super._testAddJobDataPerformance()
    }

    /// Test add job performance.
    func testAddJobPerformance() throws {
        try super._testAddJobPerformance()
    }

    /// Test in cycle performance.
    func testInCyclePerformance() throws {
        try super._testInCyclePerformance()
    }

    /// Test job from data performance.
    func testJobFromDataPerformance() throws {
        try super._testJobFromDataPerformance()
    }

    /// Test job from ID performance.
    func testJobFromIDPerformance() throws {
        try super._testJobFromIDPerformance()
    }

}
