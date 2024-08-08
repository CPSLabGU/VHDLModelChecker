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

final class SQLiteJobStore: JobStorable {

    private let db: Connection

    private let jobs = Table("jobs")

    private let cycles = Table("cycles")

    private let completedSessions = Table("completed_sessions")

    private let pendingSessions = Table("pending_sessions")

    private let revisits = Table("revisits")

    private let sessionKeys = Table("session_keys")

    private let currentJobs = Table("current_jobs")

    private let id = Expression<Int64>("id")

    private let uuid = Expression<UUID>("id")

    private let jobsData = Expression<Data>("job")

    private let cycleData = Expression<Data>("cycle")

    private let status = Expression<Data?>("status")

    private let jobId = Expression<Int64>("job")

    private let revisit = Expression<Data>("revisit")

    private let key = Expression<Data>("key")

    private let encoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private let decoder = JSONDecoder()

    var next: Job? {
        get throws {
            guard let row = try db.pluck(currentJobs.order(id.desc)) else {
                return nil
            }
            try db.run(currentJobs.order(id.desc).limit(1).delete())
            let jobId = row[jobId]
            guard let jobRow = try db.prepare(jobs.order(id.desc)).first(where: { $0[id] == jobId }) else {
                throw SQLiteError.corruptDatabase
            }
            return try decoder.decode(Job.self, from: jobRow[jobsData])
        }
    }

    var nextPendingSession: (UUID, Job)? {
        get throws {
            guard
                let row = try db.pluck(pendingSessions),
                let job = try db.prepare(jobs).first(where: { $0[id] == row[jobId] })
            else {
                return nil
            }
            return (row[uuid], try decoder.decode(Job.self, from: job[jobsData]))
        }
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

    private func clearDatabase() throws {
        try db.transaction {
            try db.run(currentJobs.drop(ifExists: true))
            try db.run(sessionKeys.drop(ifExists: true))
            try db.run(completedSessions.drop(ifExists: true))
            try db.run(pendingSessions.drop(ifExists: true))
            try db.run(cycles.drop(ifExists: true))
            try db.run(jobs.drop(ifExists: true))
            try db.run(revisits.drop(ifExists: true))
        }
    }

    private func createSchema() throws {
        try db.transaction {
            try db.run(jobs.create {
                $0.column(id, primaryKey: .autoincrement)
                $0.column(jobsData)
            })
            try db.run(jobs.createIndex(jobsData))
            try db.run(cycles.create {
                $0.column(id, primaryKey: .autoincrement)
                $0.column(cycleData)
            })
            try db.run(cycles.createIndex(cycleData))
            try db.run(completedSessions.create {
                $0.column(uuid, primaryKey: true)
                $0.column(status)
            })
            try db.run(pendingSessions.create {
                $0.column(uuid, primaryKey: true)
                $0.column(jobId)
                $0.foreignKey(jobId, references: jobs, id)
            })
            try db.run(revisits.create {
                $0.column(uuid, primaryKey: true)
                $0.column(revisit)
            })
            try db.run(revisits.createIndex(revisit))
            try db.run(sessionKeys.create {
                $0.column(uuid, primaryKey: true)
                $0.column(key)
            })
            try db.run(sessionKeys.createIndex(key))
            try db.run(currentJobs.create {
                $0.column(id, primaryKey: .autoincrement)
                $0.column(jobId)
                $0.foreignKey(jobId, references: jobs, id)
            })
            try db.run(currentJobs.createIndex(jobId))
        }
    }

    func addCycle(cycle: CycleData) throws {
        let data = try encoder.encode(cycle)
        try db.run(cycles.insert(cycleData <- data))
    }

    func addJob(job: Job) throws {
        let data = try encoder.encode(job)
        try db.transaction {
            let id = try db.run(jobs.insert(jobsData <- data))
            try db.run(currentJobs.insert([jobId <- id]))
        }
    }
    func addKey(key: SessionKey) throws -> UUID {
        let id = UUID()
        let data = try encoder.encode(key)
        try db.run(sessionKeys.insert(uuid <- id, self.key <- data))
        return id
    }

    func addManyJobs(jobs: [Job]) throws {
        try db.transaction {
            let firstId = (try db.pluck(self.jobs.order(id.desc)).map { $0[id] + 1 }) ?? Int64.zero
            let data = try jobs.map {
                [jobsData <- try encoder.encode($0)]
            }
            let lastId = try db.run(self.jobs.insertMany(data))
            try db.run(self.currentJobs.insertMany((firstId...lastId).map { [jobId <- $0] }))
        }
    }

    func addRevisit(revisit: Revisit) throws -> UUID {
        let id = UUID()
        try db.run(revisits.insert([uuid <- id, self.revisit <- try encoder.encode(revisit)]))
        return id
    }

    func addSessionJob(session: UUID, job: Job) throws {
        let data = try encoder.encode(job)
        try db.transaction {
            let jobId: Int64
            if let selectedJob = try db.prepare(jobs).first(where: { $0[jobsData] == data }) {
                jobId = selectedJob[id]
            } else {
                jobId = try db.run(jobs.insert([jobsData <- data]))
            }
            try db.run(pendingSessions.filter(uuid == session).delete())
            try db.run(pendingSessions.insert([uuid <- session, self.jobId <- jobId]))
        }
    }

    func hasCycle(cycle: CycleData) throws -> Bool {
        let data = try encoder.encode(cycle)
        return try db.prepare(cycles.select(cycleData)).contains { $0[cycleData] == data }
    }

    func pendingSession(session: UUID) throws -> Job? {
        guard let row = try db.prepare(pendingSessions).first(where: { $0[uuid] == session }) else {
            return nil
        }
        let jobId = row[jobId]
        guard let job = try db.prepare(jobs).first(where: { $0[id] == jobId }) else {
            return nil
        }
        return try self.decoder.decode(Job.self, from: job[jobsData])
    }

    func removePendingSession(session: UUID) throws {
        try db.transaction {
            let row = pendingSessions.filter(uuid == session)
            try db.run(row.delete())
            let status: ModelCheckerError? = nil
            let data = try encoder.encode(status)
            try db.run(completedSessions.insert([uuid <- session, self.status <- data]))
        }
    }

    func reset() throws {
        try self.clearDatabase()
        try self.createSchema()
    }

    func revisit(id: UUID) throws -> Revisit? {
        guard let row = try db.prepare(revisits).first(where: { $0[uuid] == id }) else {
            return nil
        }
        return try self.decoder.decode(Revisit.self, from: row[revisit])
    }

    func revisitID(revisit: Revisit) throws -> UUID? {
        let data = try encoder.encode(revisit)
        guard let row = try db.prepare(revisits).first(where: { $0[self.revisit] == data }) else {
            return nil
        }
        return row[uuid]
    }

    func sessionId(key: SessionKey) throws -> UUID? {
        let data = try encoder.encode(key)
        guard let row = try db.prepare(sessionKeys).first(where: { $0[self.key] == data }) else {
            return nil
        }
        return row[uuid]
    }

    func sessionStatus(session: UUID) throws -> ModelCheckerError?? {
        guard let row = try db.prepare(completedSessions).first(where: { $0[uuid] == session }) else {
            return nil
        }
        guard let data = row[status] else {
            return .some(nil)
        }
        return try self.decoder.decode(ModelCheckerError.self, from: data)
    }

}
