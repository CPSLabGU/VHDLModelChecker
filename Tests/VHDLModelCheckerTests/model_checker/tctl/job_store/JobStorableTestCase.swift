import Foundation
import TCTLParser
import VHDLKripkeStructures
import XCTest

@testable import VHDLModelChecker

/// Helper class for performing job store tests.
class JobStorableTestCase: XCTestCase {

    // swiftlint:disable implicitly_unwrapped_optional

    /// The store to test.
    var store: JobStorable!

    /// A revisit data.
    var revisit: JobData!

    // swiftlint:enable implicitly_unwrapped_optional

    /// New job data.
    var newJob: JobData {
        get throws {
            JobData(
                nodeId: UUID(),
                expression: Expression.language(expression: .vhdl(expression: .true)),
                history: [UUID(), UUID()],
                currentBranch: [UUID(), UUID()],
                historyExpression: Expression.language(expression: .vhdl(expression: .false)),
                successRevisit: try store.job(forData: revisit).id,
                failRevisit: try store.job(forData: revisit).id,
                session: UUID(),
                sessionRevisit: nil,
                window: ConstrainedWindow(cost: Cost(time: 12, energy: 12))
            )
        }
    }

    /// setup the test cases.
    override func setUp() {
        self.revisit = JobData(
            nodeId: UUID(),
            expression: Expression.language(expression: .vhdl(expression: .true)),
            history: [],
            currentBranch: [],
            historyExpression: nil,
            successRevisit: nil,
            failRevisit: nil,
            session: nil,
            sessionRevisit: nil,
            window: nil
        )
    }

    // swiftlint:disable identifier_name
    // swiftlint:disable force_unwrapping
    // swiftlint:disable force_try

    /// Delegate test.
    func _testCanAddJobs() throws {
        let job = try self.newJob
        let jobId = try store.addJob(data: job)
        let result = try store.job(withId: jobId)
        XCTAssertEqual(Job(id: jobId, data: job), result)
        let resultId = try store.job(forData: result.data).id
        XCTAssertEqual(jobId, resultId)
        XCTAssertFalse(try store.isComplete(session: job.session!))
        let nextJobId = try store.next
        XCTAssertTrue(try store.isComplete(session: job.session!))
        XCTAssertEqual(jobId, nextJobId)
        XCTAssertNil(try store.next)
    }

    /// Delegate test.
    func _testFailsSession() throws {
        let job = try newJob
        let id = try self.store.addJob(data: job)
        XCTAssertFalse(try store.isComplete(session: job.session!))
        XCTAssertNil(try store.error(session: job.session!))
        try store.failSession(id: job.session!, error: .internalError)
        XCTAssertFalse(try store.isComplete(session: job.session!))
        XCTAssertEqual(try store.error(session: job.session!), .internalError)
        XCTAssertFalse(try store.isComplete(session: job.session!))
        let next = try store.next
        XCTAssertEqual(next, id)
        XCTAssertTrue(try store.isComplete(session: job.session!))
        XCTAssertEqual(try store.error(session: job.session!), .internalError)
    }

    /// Delegate test.
    func _testInCycle() throws {
        let job = Job(id: UUID(), data: try newJob)
        XCTAssertFalse(try store.inCycle(job))
        XCTAssertTrue(try store.inCycle(job))
    }

    /// Delegate test.
    func _testJobFromData() throws {
        let data = try newJob
        let job = try store.job(forData: data)
        XCTAssertEqual(job, try store.job(withId: job.id))
    }

    /// Delegate test.
    func _testJobWithID() throws {
        XCTAssertThrowsError(try store.job(withId: UUID()))
        let data = try self.newJob
        let job = try store.job(forData: data)
        let result = try store.job(withId: job.id)
        XCTAssertEqual(job, result)
    }

    /// Delegate test.
    func _testNext() throws {
        XCTAssertNil(try self.store.next)
        let data = try self.newJob
        let id = try self.store.addJob(data: data)
        XCTAssertEqual(id, try self.store.next)
    }

    /// Delegate test.
    func _testReset() throws {
        let job1 = try newJob
        let job2 = try newJob
        let job1Id = try store.addJob(data: job1)
        let job2Id = try store.addJob(data: job2)
        try store.reset()
        XCTAssertNil(try store.next)
        let job1Id2 = try store.job(forData: job1).id
        let job2Id2 = try store.job(forData: job2).id
        XCTAssertNotEqual(job1Id, job1Id2)
        XCTAssertNotEqual(job2Id, job2Id2)
    }

    /// Delegate test.
    func _testNextPerformance() throws {
        for _ in 0..<1000 {
            let job = try! self.newJob
            _ = try! store.addJob(data: job)
        }
        measure {
            for _ in 0..<1000 {
                _ = try! store.next
            }
        }
    }

    /// Delegate test.
    func _testAddJobDataPerformance() throws {
        measure {
            for _ in 0..<1000 {
                let job = try! self.newJob
                _ = try! store.addJob(data: job)
            }
        }
    }

    /// Delegate test.
    func _testAddJobPerformance() throws {
        measure {
            for _ in 0..<1000 {
                let job = try! self.newJob
                _ = try! store.addJob(job: Job(id: UUID(), data: job))
            }
        }
    }

    /// Delegate test.
    func _testInCyclePerformance() throws {
        measure {
            for _ in 0..<1000 {
                let job = try! self.newJob
                _ = try! store.inCycle(Job(id: UUID(), data: job))
            }
        }
    }

    /// Delegate test.
    func _testJobFromDataPerformance() throws {
        let jobs = try (0..<1000).map { _ in try self.newJob }
        try jobs.forEach { _ = try self.store.addJob(data: $0) }
        let shuffledJobs = jobs.shuffled()
        measure {
            try! shuffledJobs.forEach {
                _ = try self.store.job(forData: $0)
            }
        }
    }

    /// Delegate test.
    func _testJobFromIDPerformance() throws {
        let jobs = try (0..<1000).map { _ in try self.newJob }
        let fetchedJobs = try jobs.map { try self.store.job(forData: $0) }
        let shuffledJobs = fetchedJobs.shuffled()
        measure {
            try! shuffledJobs.forEach { _ = try self.store.job(withId: $0.id) }
        }
    }

    // swiftlint:enable force_try
    // swiftlint:enable force_unwrapping
    // swiftlint:enable identifier_name

}
