import Foundation
import XCTest

@testable import VHDLModelChecker

final class SQLiteJobStoreTests: JobStorableTestCase {

    override func setUp() {
        super.setUp()
        super.store = try! SQLiteJobStore(path: FileManager.default.currentDirectoryPath + "/test.db")
    }

    override func testCanAddJobs() throws {
        try super.testCanAddJobs()
    }

    override func testCanAddManyJobs() throws {
        try super.testCanAddManyJobs()
    }

    override func testInCycle() throws {
        try super.testInCycle()
    }

    override func testReset() throws {
        try super.testReset()
    }

    override func testSessions() throws {
        try super.testSessions()
    }

    override func testSessionStatus() throws {
        try super.testSessionStatus()
    }

}
