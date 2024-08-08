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
