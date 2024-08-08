import Foundation
import TCTLParser
import VHDLKripkeStructures
import XCTest

@testable import VHDLModelChecker

class JobStorableTestCase: XCTestCase {

    var store: JobStorable!

    var revisit: Job!

    var newJob: Job {
        get throws {
            Job(
                nodeId: UUID(),
                expression: Expression.language(expression: .vhdl(expression: .true)),
                history: [UUID(), UUID()],
                currentBranch: [UUID(), UUID()],
                inSession: true,
                historyExpression: Expression.language(expression: .vhdl(expression: .false)),
                constraints: [PhysicalConstraint(cost: Cost(time: 12, energy: 12), constraint: .lessThan(constraint: .time(amount: 20, unit: .s)))],
                session: UUID(),
                successRevisit: try store.id(forJob: revisit),
                failRevisit: try store.id(forJob: revisit)
            )
        }
    }

    override func setUp() {
        self.revisit = Job(
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

    func testCanAddJobs() throws {
        let job = try self.newJob
        let jobId = try store.addJob(job: job)
        let result = try store.job(withId: jobId)
        XCTAssertEqual(job, result)
        let resultId = try store.id(forJob: result)
        XCTAssertEqual(jobId, resultId)
        let nextJobId = try store.next
        XCTAssertEqual(jobId, nextJobId)
        XCTAssertNil(try store.next)
    }

    func testCanAddManyJobs() throws {
        let jobs = try Array(repeating: 0, count: 10).map { _ in try self.newJob }
        try store.addManyJobs(jobs: jobs)
        try jobs.reversed().forEach {
            let id = try store.id(forJob: $0)
            XCTAssertEqual(id, try store.next)
        }
        XCTAssertNil(try store.next)
    }

    func testInCycle() throws {
        let job = try newJob
        XCTAssertFalse(try store.inCycle(job))
        XCTAssertTrue(try store.inCycle(job))
    }

    func testReset() throws {
        let job1 = try newJob
        let job2 = try newJob
        let job1Id = try store.addJob(job: job1)
        let job2Id = try store.addJob(job: job2)
        let session1 = try store.sessionId(forJob: job1)
        let session2 = try store.sessionId(forJob: job2)
        try store.completePendingSession(session: session1, result: nil)
        XCTAssertEqual(try store.pendingSessionJob, job2)
        try store.reset()
        XCTAssertNil(try store.next)
        XCTAssertNil(try store.pendingSessionJob)
        let job1Id_2 = try store.id(forJob: job1)
        let job2Id_2 = try store.id(forJob: job2)
        XCTAssertNotEqual(job1Id, job1Id_2)
        XCTAssertNotEqual(job2Id, job2Id_2)
        let session1_2 = try store.sessionId(forJob: job1)
        let session2_2 = try store.sessionId(forJob: job2)
        XCTAssertNotEqual(session1, session1_2)
        XCTAssertNotEqual(session2, session2_2)
    }

    func testSessions() throws {
        let job = try newJob
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

    func testSessionStatus() throws {
        let job1 = try newJob
        let job2 = try newJob
        let session1 = try store.sessionId(forJob: job1)
        let session2 = try store.sessionId(forJob: job2)
        try store.completePendingSession(session: session1, result: nil)
        let result = ModelCheckerError.notSupported(expression: .language(expression: .vhdl(expression: .false)))
        try store.completePendingSession(session: session2, result: .some(result))
        XCTAssertEqual(result, try store.sessionStatus(session: session2))
    }

}
