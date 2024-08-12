import Foundation
import XCTest

@testable import VHDLModelChecker

final class SQLiteJobStoreTests: JobStorableTestCase {

    override func setUp() {
        super.setUp()
        super.store = try! SQLiteJobStore(path: FileManager.default.currentDirectoryPath + "/test.db")
    }

    override func tearDown() {
        super.tearDown()
        _ = try? FileManager.default.removeItem(atPath: FileManager.default.currentDirectoryPath + "/test.db")
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

    func testAddJobPerformance() throws {
        try super._testAddJobPerformance()
    }

    func testInCyclePerformance() throws {
        try super._testInCyclePerformance()
    }

}
