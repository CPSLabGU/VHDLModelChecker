import Foundation
import TCTLParser
import VHDLKripkeStructures
import XCTest

@testable import VHDLModelChecker

class JobStorableTestCase: XCTestCase {

    var store: JobStorable!

    var revisit: JobData!

    var newJob: JobData {
        get throws {
            JobData(
                nodeId: UUID(),
                expression: Expression.language(expression: .vhdl(expression: .true)),
                history: [UUID(), UUID()],
                currentBranch: [UUID(), UUID()],
                inSession: true,
                historyExpression: Expression.language(expression: .vhdl(expression: .false)),
                constraints: [PhysicalConstraint(cost: Cost(time: 12, energy: 12), constraint: .lessThan(constraint: .time(amount: 20, unit: .s)))],
                session: UUID(),
                successRevisit: try store.job(forData: revisit).id,
                failRevisit: try store.job(forData: revisit).id
            )
        }
    }

    override func setUp() {
        self.revisit = JobData(
            nodeId: UUID(),
            expression: Expression.language(expression: .vhdl(expression: .true)),
            history: [],
            currentBranch: [],
            inSession: false,
            historyExpression: nil,
            constraints: [],
            session: nil,
            successRevisit: nil,
            failRevisit: nil
        )
    }

    func _testCanAddJobs() throws {
        let job = try self.newJob
        let jobId = try store.addJob(data: job)
        let result = try store.job(withId: jobId)
        XCTAssertEqual(Job(id: jobId, data: job), result)
        let resultId = try store.job(forData: result.data).id
        XCTAssertEqual(jobId, resultId)
        let nextJobId = try store.next
        XCTAssertEqual(jobId, nextJobId)
        XCTAssertNil(try store.next)
    }

    func _testCanAddManyJobs() throws {
        let jobs = try Array(repeating: 0, count: 10).map { _ in try self.newJob }
        try store.addManyJobs(jobs: jobs)
        try jobs.reversed().forEach {
            let id = try store.job(forData: $0).id
            XCTAssertEqual(id, try store.next)
        }
        XCTAssertNil(try store.next)
    }

    func _testInCycle() throws {
        let job = Job(id: UUID(), data: try newJob)
        XCTAssertFalse(try store.inCycle(job))
        XCTAssertTrue(try store.inCycle(job))
    }

    func _testReset() throws {
        let job1 = try newJob
        let job2 = try newJob
        let job1Id = try store.addJob(data: job1)
        let job2Id = try store.addJob(data: job2)
        let session1 = try store.sessionId(forJob: Job(id: job1Id, data: job1))
        let session2 = try store.sessionId(forJob: Job(id: job2Id, data: job2))
        try store.completePendingSession(session: session1, result: nil)
        XCTAssertEqual(try store.pendingSessionJob, Job(id: job2Id, data: job2))
        try store.reset()
        XCTAssertNil(try store.next)
        XCTAssertNil(try store.pendingSessionJob)
        let job1Id_2 = try store.job(forData: job1).id
        let job2Id_2 = try store.job(forData: job2).id
        XCTAssertNotEqual(job1Id, job1Id_2)
        XCTAssertNotEqual(job2Id, job2Id_2)
        let session1_2 = try store.sessionId(forJob: Job(id: job1Id, data: job1))
        let session2_2 = try store.sessionId(forJob: Job(id: job2Id, data: job2))
        XCTAssertNotEqual(session1, session1_2)
        XCTAssertNotEqual(session2, session2_2)
    }

    func _testSessions() throws {
        let job = try store.job(forData: try newJob)
        let session = try store.sessionId(forJob: job)
        XCTAssertTrue(try store.isPending(session: session))
        XCTAssertEqual(try store.sessionStatus(session: session), .none)
        let pendingJob = try store.pendingSessionJob
        XCTAssertEqual(job, pendingJob)
        try store.completePendingSession(session: session, result: nil)
        XCTAssertFalse(try store.isPending(session: session))
        XCTAssertEqual(try store.sessionStatus(session: session), .some(.none))
        let session2 = try store.sessionId(forJob: job)
        XCTAssertEqual(session, session2)
        XCTAssertFalse(try store.isPending(session: session))
        XCTAssertEqual(try store.sessionStatus(session: session), .some(.none))
        XCTAssertNil(try store.pendingSessionJob)
    }

    func _testSessionStatus() throws {
        let job1 = try store.job(forData: try newJob)
        let job2 = try store.job(forData: try newJob)
        let session1 = try store.sessionId(forJob: job1)
        let session2 = try store.sessionId(forJob: job2)
        try store.completePendingSession(session: session1, result: nil)
        let result = ModelCheckerError.notSupported(expression: .language(expression: .vhdl(expression: .false)))
        try store.completePendingSession(session: session2, result: .some(result))
        XCTAssertEqual(result, try store.sessionStatus(session: session2))
    }

    func _testAddJobPerformance() throws {
        measure {
            for _ in 0..<100 {
                let job = try! self.newJob
                _ = try! store.addJob(data: job)
            }
        }
    }

}
