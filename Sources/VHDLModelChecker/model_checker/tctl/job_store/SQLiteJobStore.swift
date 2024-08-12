// SQLiteJobStore.swift
// VHDLModelChecker
// 
// Created by Morgan McColl.
// Copyright © 2024 Morgan McColl. All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 
// 2. Redistributions in binary form must reproduce the above
//    copyright notice, this list of conditions and the following
//    disclaimer in the documentation and/or other materials
//    provided with the distribution.
// 
// 3. All advertising materials mentioning features or use of this
//    software must display the following acknowledgement:
// 
//    This product includes software developed by Morgan McColl.
// 
// 4. Neither the name of the author nor the names of contributors
//    may be used to endorse or promote products derived from this
//    software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// 
// -----------------------------------------------------------------------
// This program is free software; you can redistribute it and/or
// modify it under the above terms or under the terms of the GNU
// General Public License as published by the Free Software Foundation;
// either version 2 of the License, or (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program; if not, see http://www.gnu.org/licenses/
// or write to the Free Software Foundation, Inc., 51 Franklin Street,
// Fifth Floor, Boston, MA  02110-1301, USA.

import Foundation
import SQLite
import TCTLParser

final class SQLiteJobStore: JobStorable {

    private let db: Connection

    private let jobs = Table("jobs")

    private let cycles = Table("cycles")

    private let completedSessions = Table("completed_sessions")

    private let pendingSessions = Table("pending_sessions")

    private let sessionKeys = Table("session_keys")

    private let currentJobs = Table("current_jobs")

    private let id = SQLite.Expression<Int64>("id")

    private let uuid = SQLite.Expression<UUID>("id")

    private let status = SQLite.Expression<Data?>("status")

    private let jobId = SQLite.Expression<UUID>("job")

    private let key = SQLite.Expression<Data>("key")

    private let encoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private let decoder = JSONDecoder()

    private var expressions: [UUID: TCTLParser.Expression] = [:]

    private var expressionKeys: [TCTLParser.Expression: UUID] = [:]

    private var constraintsKeys: [[PhysicalConstraint]: UUID] = [:]

    private var constraints: [UUID: [PhysicalConstraint]] = [:]

    private let nodeId = SQLite.Expression<UUID>("node_id")

    private let expression = SQLite.Expression<UUID>("expression")

    private let inCycle = SQLite.Expression<Bool>("in_cycle")

    private let historyExpression = SQLite.Expression<UUID?>("history_expression")

    private let session = SQLite.Expression<UUID?>("session")

    private let constraint = SQLite.Expression<UUID>("constraints")

    private let successRevisit = SQLite.Expression<UUID?>("success_revisit")

    private let failRevisit = SQLite.Expression<UUID?>("fail_revisit")

    private let inSession = SQLite.Expression<Bool>("in_session")

    private let history = SQLite.Expression<Data>("history")

    private let currentBranch = SQLite.Expression<Data>("current_branch")

    private var _next: UUID? {
        get throws {
            guard let row = try db.pluck(currentJobs.order(id.desc)) else {
                return nil
            }
            try db.run(currentJobs.filter(id == row[id]).delete())
            return row[jobId]
        }
    }

    var next: UUID? {
        get throws {
            try tx { try _next }
        }
    }

    private var _pendingSessionJob: Job? {
        get throws {
            guard
                let row = try db.pluck(pendingSessions),
                let job = try db.pluck(jobs.filter(uuid == row[jobId]))
            else {
                return nil
            }
            // print(String(data: job[jobsData], encoding: .utf8))
            // fflush(stdout)
            return try self.createJob(job: job)
        }
    }

    var pendingSessionJob: Job? {
        get throws {
            try tx { try _pendingSessionJob }
        }
    }

    /// Create an `in-memory` database.
    convenience init() throws {
        let db = try Connection(.inMemory, readonly: false)
        self.init(db: db)
        try self.createSchema()
    }

    convenience init(path: String) throws {
        try self.init(url: URL(fileURLWithPath: path, isDirectory: false))
    }

    convenience init(url: URL) throws {
        guard url.isFileURL, !url.hasDirectoryPath else {
            throw SQLiteError.invalidPath(url: url)
        }
        let manager = FileManager.default
        var isDirectory: ObjCBool = false
        if manager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard !isDirectory.boolValue else {
                throw SQLiteError.invalidPath(url: url)
            }
            try manager.removeItem(at: url)
            self.init(db: try Connection(url.path, readonly: false))
        } else {
            self.init(db: try Connection(url.path, readonly: false))
        }
        try self.createSchema()
    }

    private init(db: Connection) {
        self.db = db
    }

    @discardableResult
    func addJob(data: JobData) throws -> UUID {
        try tx {
            let job = try _id(forJob: data)
            try self.addJob(job: job)
            return job.id
        }
    }

    func addJob(job: Job) throws {
        try db.run(currentJobs.insert([jobId <- job.id]))
    }

    func addManyJobs(jobs: [JobData]) throws {
        try db.transaction {
            let data = try jobs.map {
                [self.jobId <- try self._id(forJob: $0).id]
            }
            try db.run(self.currentJobs.insertMany(data))
        }
    }

    func completePendingSession(session: UUID, result: ModelCheckerError?) throws {
        let data: Data? = try result.map { try encoder.encode($0) }
        try db.transaction {
            try db.run(pendingSessions.filter(uuid == session).delete())
            guard let completed = try db.pluck(completedSessions.filter(uuid == session)) else {
                try db.run(completedSessions.insert([uuid <- session, self.status <- data]))
                return
            }
            guard completed[self.status] == data else {
                throw SQLiteError.corruptDatabase
            }
        }
    }

    func inCycle(_ job: Job) throws -> Bool {
        try tx { try _inCycle(job) }
    }

    func isPending(session: UUID) throws -> Bool {
        try db.pluck(pendingSessions.filter(uuid == session)) != nil
    }

    func job(forData data: JobData) throws -> Job {
        try tx { try _id(forJob: data) }
    }

    func job(withId id: UUID) throws -> Job {
        guard let row = try db.pluck(jobs.filter(uuid == id)) else {
            throw SQLiteError.corruptDatabase
        }
        // print(String(data: row[jobsData], encoding: .utf8))
        // fflush(stdout)
        return try self.createJob(job: row)
    }

    func reset() throws {
        try tx { try _reset() }
    }

    func sessionId(forJob job: Job) throws -> UUID {
        try tx { try _sessionId(forJob: job) }
    }

    func sessionStatus(session: UUID) throws -> ModelCheckerError?? {
        guard let row = try db.pluck(completedSessions.filter(uuid == session)) else {
            return nil
        }
        guard let data = row[status] else {
            return .some(nil)
        }
        // print(String(data: data, encoding: .utf8))
        // fflush(stdout)
        return try self.decoder.decode(ModelCheckerError.self, from: data)
    }

    private func _id(forJob job: JobData) throws -> Job {
        let expressionId = self.getExpression(expression: job.expression)
        let constraintId = self.getConstraints(constraint: job.constraints)
        let historyExpressionId = job.historyExpression.map(self.getExpression)
        let history = try encoder.encode(job.history)
        let currentBranch = try encoder.encode(job.currentBranch)
        let query = nodeId == job.nodeId && expression == expressionId && self.history == history
            && self.currentBranch == currentBranch && inSession == job.inSession
            && historyExpression == historyExpressionId && self.constraint == constraintId
            && session == job.session && successRevisit == job.successRevisit
            && failRevisit == job.failRevisit
        if let row = try db.pluck(jobs.filter(query)) {
            return Job(id: row[uuid], data: job)
        } else {
            let id = UUID()
            try db.run(jobs.insert([
                uuid <- id, nodeId <- job.nodeId, self.expression <- expressionId, self.history <- history,
                self.currentBranch <- currentBranch, inSession <- job.inSession,
                historyExpression <- historyExpressionId, self.constraint <- constraintId,
                session <- job.session, successRevisit <- job.successRevisit, failRevisit <- job.failRevisit
            ]))
            return Job(id: id, data: job)
        }
    }

    private func _inCycle(_ job: Job) throws -> Bool {
        let cycle = job.cycleData
        let expression = self.getExpression(expression: cycle.expression)
        let historyExpression = cycle.historyExpression.map(self.getExpression)
        let constraints = self.getConstraints(constraint: cycle.constraints)
        let query = nodeId == cycle.nodeId && self.expression == expression && self.inCycle == cycle.inCycle
            && self.historyExpression == historyExpression && self.session == cycle.session
            && self.constraint == constraints && self.successRevisit == cycle.successRevisit
            && self.failRevisit == cycle.failRevisit
        let inCycle = try db.pluck(cycles.select(id).filter(query)) != nil
        if !inCycle {
            try db.run(cycles.insert([
                nodeId <- cycle.nodeId, self.expression <- expression, self.inCycle <- cycle.inCycle,
                self.historyExpression <- historyExpression, session <- cycle.session,
                constraint <- constraints, successRevisit <- cycle.successRevisit,
                failRevisit <- cycle.failRevisit
            ]))
        }
        return inCycle
    }

    private func _reset() throws {
        try self.clearDatabase()
        try self.createSchema()
    }

    private func _sessionId(forJob job: Job) throws -> UUID {
        let key = try self.encoder.encode(job.sessionKey)
        let out: UUID
        if let row = try self.db.pluck(sessionKeys.filter(self.key == key)) {
            out = row[uuid]
        } else {
            out = UUID()
            try self.db.run(sessionKeys.insert([uuid <- out, self.key <- key]))
        }
        guard try self.sessionStatus(session: out) == nil else {
            return out
        }
        let jobId = job.id
        if try self.db.pluck(pendingSessions.filter(uuid == out)) != nil {
            try self.db.run(pendingSessions.filter(uuid == out).update(self.jobId <- jobId))
        } else {
            try self.db.run(pendingSessions.insert(uuid <- out, self.jobId <- jobId))
        }
        return out
    }

    // func revisitID(revisit: Revisit) throws -> UUID? {
    //     let data = try encoder.encode(revisit)
    //     guard let row = try db.prepare(revisits).first(where: { $0[self.revisit] == data }) else {
    //         return nil
    //     }
    //     return row[uuid]
    // }

    // func addKey(key: SessionKey) throws -> UUID {
    //     let id = UUID()
    //     let data = try encoder.encode(key)
    //     try db.run(sessionKeys.insert(uuid <- id, self.key <- data))
    //     return id
    // }

    // func addRevisit(revisit: Revisit) throws -> UUID {
    //     let id = UUID()
    //     try db.run(revisits.insert([uuid <- id, self.revisit <- try encoder.encode(revisit)]))
    //     return id
    // }

    // func addSessionJob(session: UUID, job: Job) throws {
    //     let data = try encoder.encode(job)
    //     try db.transaction {
    //         let jobId: Int64
    //         if let selectedJob = try db.prepare(jobs).first(where: { $0[jobsData] == data }) {
    //             jobId = selectedJob[id]
    //         } else {
    //             jobId = try db.run(jobs.insert([jobsData <- data]))
    //         }
    //         try db.run(pendingSessions.filter(uuid == session).delete())
    //         try db.run(pendingSessions.insert([uuid <- session, self.jobId <- jobId]))
    //     }
    // }

    private func clearDatabase() throws {
        try db.run(currentJobs.drop(ifExists: true))
        try db.run(sessionKeys.drop(ifExists: true))
        try db.run(completedSessions.drop(ifExists: true))
        try db.run(pendingSessions.drop(ifExists: true))
        try db.run(cycles.drop(ifExists: true))
        try db.run(jobs.drop(ifExists: true))
    }

    private func createJob(job: Row) throws -> Job {
        guard
            let expression = self.expressions[job[expression]],
            let constraints = self.constraints[job[constraint]]
        else {
            throw SQLiteError.corruptDatabase
        }
        let historyExpression = try job[historyExpression].map {
            guard let exp = self.expressions[$0] else {
                throw SQLiteError.corruptDatabase
            }
            return exp
        }
        let history = try decoder.decode(Set<UUID>.self, from: job[history])
        let currentBranch = try decoder.decode([UUID].self, from: job[currentBranch])
        return Job(
            id: job[uuid],
            nodeId: job[nodeId],
            expression: expression,
            history: history,
            currentBranch: currentBranch,
            inSession: job[inSession],
            historyExpression: historyExpression,
            constraints: constraints,
            session: job[session],
            successRevisit: job[successRevisit],
            failRevisit: job[failRevisit]
        )
    }

    private func createSchema() throws {
        try db.run(jobs.create {
            $0.column(uuid, primaryKey: true)
            $0.column(nodeId)
            $0.column(expression)
            $0.column(history)
            $0.column(currentBranch)
            $0.column(inSession)
            $0.column(historyExpression)
            $0.column(constraint)
            $0.column(session)
            $0.column(successRevisit)
            $0.column(failRevisit)
        })
        try db.run(jobs.createIndex(
            nodeId,
            expression,
            history,
            currentBranch,
            inSession,
            historyExpression,
            constraint,
            session,
            successRevisit,
            failRevisit,
            unique: true
        ))
        try db.run(cycles.create {
            $0.column(id, primaryKey: .autoincrement)
            $0.column(nodeId)
            $0.column(expression)
            $0.column(inCycle)
            $0.column(historyExpression)
            $0.column(session)
            $0.column(constraint)
            $0.column(successRevisit)
            $0.column(failRevisit)
        })
        try db.run(cycles.createIndex(
            nodeId, expression, inCycle, historyExpression, session, constraint, successRevisit, failRevisit
        ))
        try db.run(completedSessions.create {
            $0.column(uuid, primaryKey: true)
            $0.column(status)
        })
        try db.run(pendingSessions.create {
            $0.column(uuid, primaryKey: true)
            $0.column(jobId)
            $0.foreignKey(jobId, references: jobs, uuid, update: .cascade, delete: .cascade)
        })
        try db.run(sessionKeys.create {
            $0.column(uuid, primaryKey: true)
            $0.column(key)
        })
        try db.run(sessionKeys.createIndex(key))
        try db.run(currentJobs.create {
            $0.column(id, primaryKey: .autoincrement)
            $0.column(jobId)
            $0.foreignKey(jobId, references: jobs, uuid, update: .cascade, delete: .cascade)
        })
        try db.run(currentJobs.createIndex(jobId))
    }

    private func getConstraints(constraint: [PhysicalConstraint]) -> UUID {
        guard let key = self.constraintsKeys[constraint] else {
            let constraintId = UUID()
            self.constraintsKeys[constraint] = constraintId
            self.constraints[constraintId] = constraint
            return constraintId
        }
        return key
    }

    private func getExpression(expression: TCTLParser.Expression) -> UUID {
        guard let key = self.expressionKeys[expression] else {
            let expressionId = UUID()
            self.expressionKeys[expression] = expressionId
            self.expressions[expressionId] = expression
            return expressionId
        }
        return key
    }

    private func tx<T>(_ body: () throws -> T) throws -> T {
        var out: T?
        try db.transaction {
            out = try body()
        }
        return out!
    }

}
