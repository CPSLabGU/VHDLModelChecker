import Foundation
import XCTest

@testable import VHDLModelChecker

final class SQLiteJobStoreTests: JobStorableTestCase {

    override func setUp() {
        super.setUp()
        super.store = try! SQLiteJobStore(path: FileManager.default.currentDirectoryPath + "/test.db")
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

    func testJobForData() throws {
        try super._testJobFromData()
    }

    func testJobWithID() throws {
        try super._testJobWithID()
    }

    func testNext() throws {
        try super._testNext()
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

    func testSessionIdPerformance() throws {
        try super._testSessionIdPerformance()
    }

    func testSessionStatusPerformance() throws {
        try super._testSessionStatusPerformance()
    }

}
