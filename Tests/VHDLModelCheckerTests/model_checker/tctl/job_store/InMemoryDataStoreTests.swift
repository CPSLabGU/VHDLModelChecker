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

    func testFailsSession() throws {
        try super._testFailsSession()
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

    func testNextPerformance() throws {
        try super._testNextPerformance()
    }

    func testAddJobDataPerformance() throws {
        try super._testAddJobDataPerformance()
    }

    func testAddJobPerformance() throws {
        try super._testAddJobPerformance()
    }

    func testInCyclePerformance() throws {
        try super._testInCyclePerformance()
    }

    func testJobFromDataPerformance() throws {
        try super._testJobFromDataPerformance()
    }

    func testJobFromIDPerformance() throws {
        try super._testJobFromIDPerformance()
    }

}
