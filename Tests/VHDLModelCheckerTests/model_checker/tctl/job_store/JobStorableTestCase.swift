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
                historyExpression: Expression.language(expression: .vhdl(expression: .false)),
                constraints: [PhysicalConstraint(cost: Cost(time: 12, energy: 12), constraint: .lessThan(constraint: .time(amount: 20, unit: .s)))],
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
            historyExpression: nil,
            constraints: [],
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

    func _testJobFromData() throws {
        let data = try newJob
        let job = try store.job(forData: data)
        XCTAssertEqual(job, try store.job(withId: job.id))
    }

    func _testJobWithID() throws {
        XCTAssertThrowsError(try store.job(withId: UUID()))
        let data = try self.newJob
        let job = try store.job(forData: data)
        let result = try store.job(withId: job.id)
        XCTAssertEqual(job, result)
    }

    func _testNext() throws {
        XCTAssertNil(try self.store.next)
        let data = try self.newJob
        let id = try self.store.addJob(data: data)
        XCTAssertEqual(id, try self.store.next)
    }

    func _testReset() throws {
        let job1 = try newJob
        let job2 = try newJob
        let job1Id = try store.addJob(data: job1)
        let job2Id = try store.addJob(data: job2)
        try store.reset()
        XCTAssertNil(try store.next)
        let job1Id_2 = try store.job(forData: job1).id
        let job2Id_2 = try store.job(forData: job2).id
        XCTAssertNotEqual(job1Id, job1Id_2)
        XCTAssertNotEqual(job2Id, job2Id_2)
    }

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

    func _testAddJobDataPerformance() throws {
        measure {
            for _ in 0..<1000 {
                let job = try! self.newJob
                _ = try! store.addJob(data: job)
            }
        }
    }

    func _testAddJobPerformance() throws {
        measure {
            for _ in 0..<1000 {
                let job = try! self.newJob
                _ = try! store.addJob(job: Job(id: UUID(), data: job))
            }
        }
    }

    func _testAddManyJobPerformance() throws {
        let jobs = try (0..<1000).map { _ in try self.newJob }
        measure {
            try! self.store.reset()
            try! store.addManyJobs(jobs: jobs)
        }
    }

    func _testInCyclePerformance() throws {
        measure {
            for _ in 0..<1000 {
                let job = try! self.newJob
                _ = try! store.inCycle(Job(id: UUID(), data: job))
            }
        }
    }

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

    func _testJobFromIDPerformance() throws {
        let jobs = try (0..<1000).map { _ in try self.newJob }
        let fetchedJobs = try jobs.map { try self.store.job(forData: $0) }
        let shuffledJobs = fetchedJobs.shuffled()
        measure {
            try! shuffledJobs.forEach { _ = try self.store.job(withId: $0.id) }
        }
    }

}
