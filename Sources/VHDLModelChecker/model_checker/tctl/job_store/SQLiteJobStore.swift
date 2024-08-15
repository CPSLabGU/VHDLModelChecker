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

import CSQLite
import Foundation
import TCTLParser

final class SQLiteJobStore: JobStorable {

    private let db: OpaquePointer

    private let encoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private let decoder = JSONDecoder()

    private var expressions: [Expression] = []

    private var expressionKeys: [Expression: Int] = [:]

    private var constraints: [[PhysicalConstraint]] = []

    private var constraintKeys: [[PhysicalConstraint]: Int] = [:]

    private var currentJobs: [UUID] = {
        var arr: [UUID] = []
        arr.reserveCapacity(1000000)
        return arr
    }()

    var next: UUID? {
        get throws {
            self.currentJobs.popLast()
        }
    }

    var pendingSessionJob: Job? {
        get throws {
            let query = """
            SELECT
                j.*
            FROM
                jobs j,
                sessions s
            WHERE
                j.id = s.job_id AND
                s.is_completed = 0
            LIMIT 1;
            """
            let queryC = query.cString(using: .utf8)
            var statement: OpaquePointer?
            var tail: UnsafePointer<CChar>?
            try exec { sqlite3_prepare_v2(self.db, queryC, Int32(queryC?.count ?? 0), &statement, &tail) }
            defer { try? exec { sqlite3_finalize(statement) } }
            guard let tail, String(cString: tail).isEmpty else {
                throw SQLiteError.incompleteStatement(statement: query, tail: String(cString: tail!))
            }
            let result = sqlite3_step(statement)
            guard result != SQLITE_DONE else {
                return nil
            }
            guard result == SQLITE_ROW else {
                throw SQLiteError.connectionError(message: self.errorMessage)
            }
            return try self.createJob(statement: statement)
        }
    }

    private var errorMessage: String {
        String(cString: sqlite3_errmsg(self.db))
    }

    /// Create an `in-memory` database.
    convenience init() throws {
        try self.init(resource: ":memory:")
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
        }
        try self.init(resource: url.path)
    }

    private convenience init(resource: String) throws {
        var db: OpaquePointer?
        let result = sqlite3_open(resource.cString(using: .utf8), &db)
        guard result == SQLITE_OK, let db else {
            sqlite3_close(db)
            throw SQLiteError.connectionError(message: String(cString: sqlite3_errmsg(db)))
        }
        self.init(db: db)
        try self.createSchema()
    }

    private init(db: OpaquePointer) {
        self.db = db
    }

    @discardableResult
    func addJob(data: JobData) throws -> UUID {
        let job = try self.job(forData: data)
        try self.addJob(job: job)
        return job.id
    }

    func addJob(job: Job) throws {
        self.currentJobs.append(job.id)
    }

    func addManyJobs(jobs: [JobData]) throws {
        self.currentJobs.append(contentsOf: try jobs.map { try self.job(forData: $0).id })
    }

    func completePendingSession(session: UUID, result: ModelCheckerError?) throws {
        let encodedResult = try result.map {
            "\'" + String(decoding: try self.encoder.encode($0), as: UTF8.self) + "\'"
        } ?? "NULL"
        let query = """
        UPDATE sessions SET is_completed = 1, status = \(encodedResult) WHERE id = '\(session.uuidString)';
        """
        let queryC = query.cString(using: .utf8)
        var statement: OpaquePointer?
        var tail: UnsafePointer<CChar>?
        try exec { sqlite3_prepare_v2(self.db, queryC, Int32(queryC?.count ?? 0), &statement, &tail) }
        defer { try? exec { sqlite3_finalize(statement) } }
        guard let tail, String(cString: tail).isEmpty else {
            throw SQLiteError.incompleteStatement(statement: query, tail: String(cString: tail!))
        }
        try exec(result: SQLITE_DONE) { sqlite3_step(statement) }
        guard sqlite3_changes(self.db) == 1 else {
            throw SQLiteError.corruptDatabase
        }
    }

    func inCycle(_ job: Job) throws -> Bool {
        throw SQLiteError.corruptDatabase
    }

    func isPending(session: UUID) throws -> Bool {
        let query = """
        SELECT is_completed FROM sessions WHERE id = '\(session.uuidString)';
        """
        let queryC = query.cString(using: .utf8)
        var statement: OpaquePointer?
        var tail: UnsafePointer<CChar>?
        try exec { sqlite3_prepare_v2(self.db, queryC, Int32(queryC?.count ?? 0), &statement, &tail) }
        defer { try? exec { sqlite3_finalize(statement) } }
        guard let tail, String(cString: tail).isEmpty else {
            throw SQLiteError.incompleteStatement(statement: query, tail: String(cString: tail!))
        }
        let stepResult = sqlite3_step(statement)
        switch stepResult {
        case SQLITE_ROW:
            return !(try Bool(statement: statement, offset: 0))
        case SQLITE_DONE:
            return false
        default:
            throw SQLiteError.connectionError(message: self.errorMessage)
        }
    }

    func job(forData data: JobData) throws -> Job {
        guard let job = try self.pluckJob(data: data) else {
            return Job(id: try self.insertJob(data: data), data: data)
        }
        return job
    }

    func job(withId id: UUID) throws -> Job {
        guard let job = try self.pluckJob(id: id) else {
            throw SQLiteError.corruptDatabase
        }
        return job
    }

    func reset() throws {
        try self.dropSchema()
        try self.createSchema()
    }

    func sessionId(forJob job: Job) throws -> UUID {
        let key = job.sessionKey
        let expressionIndex = self.getExpression(expression: key.expression)
        let constraintIndex = self.getConstraints(constraint: key.constraints)
        let query = """
        SELECT
            id
        FROM
            sessions
        WHERE
            job_id = '\(job.id.uuidString)' AND
            node_id = '\(key.nodeId.uuidString)' AND
            expression = \(expressionIndex) AND
            constraints = \(constraintIndex)
        LIMIT 1;
        """
        let queryC = query.cString(using: .utf8)
        var statement: OpaquePointer?
        var tail: UnsafePointer<CChar>?
        try exec { sqlite3_prepare_v2(self.db, queryC, Int32(queryC?.count ?? 0), &statement, &tail) }
        guard let tail, String(cString: tail).isEmpty else {
            try exec { sqlite3_finalize(statement) }
            throw SQLiteError.incompleteStatement(statement: query, tail: String(cString: tail!))
        }
        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_ROW else {
            try exec { sqlite3_finalize(statement) }
            let id = UUID()
            let insertQuery = """
            INSERT INTO sessions(
                id, job_id, node_id, expression, constraints, is_completed
            ) VALUES (
                '\(id.uuidString)', '\(job.id.uuidString)', '\(key.nodeId.uuidString)', \(expressionIndex),
                \(constraintIndex), 0
            );
            """
            let insertQueryC = insertQuery.cString(using: .utf8)
            var insertStatement: OpaquePointer?
            var insertTail: UnsafePointer<CChar>?
            try exec {
                sqlite3_prepare_v2(
                    self.db, insertQueryC, Int32(insertQueryC?.count ?? 0), &insertStatement, &insertTail
                )
            }
            defer { try? exec { sqlite3_finalize(insertStatement) } }
            guard let insertTail, String(cString: insertTail).isEmpty else {
                throw SQLiteError.incompleteStatement(
                    statement: insertQuery, tail: String(cString: insertTail!)
                )
            }
            try exec(result: SQLITE_DONE) { sqlite3_step(insertStatement) }
            return id
        }
        defer { try? exec { sqlite3_finalize(statement) } }
        return try UUID(statement: statement, offset: 0)
    }

    func sessionStatus(session: UUID) throws -> ModelCheckerError?? {
        let query = """
        SELECT
            is_completed, status
        FROM
            sessions
        WHERE
            id = '\(session.uuidString)';
        """
        let queryC = query.cString(using: .utf8)
        var statement: OpaquePointer?
        var tail: UnsafePointer<CChar>?
        try exec { sqlite3_prepare_v2(self.db, queryC, Int32(queryC?.count ?? 0), &statement, &tail) }
        defer { try? exec { sqlite3_finalize(statement) } }
        guard let tail, String(cString: tail).isEmpty else {
            throw SQLiteError.incompleteStatement(statement: query, tail: String(cString: tail!))
        }
        let stepResult = sqlite3_step(statement)
        guard stepResult != SQLITE_DONE else {
            return nil
        }
        guard stepResult == SQLITE_ROW else {
            throw SQLiteError.connectionError(message: self.errorMessage)
        }
        let isCompleted = try Bool(statement: statement, offset: 0)
        guard isCompleted else {
            return nil
        }
        guard sqlite3_column_type(statement, 1) != SQLITE_NULL else {
            return .some(nil)
        }
        let statusRaw = Data(try String(statement: statement, offset: 1).utf8)
        return try self.decoder.decode(ModelCheckerError.self, from: statusRaw)
    }

    private func createJob(statement: OpaquePointer?) throws -> Job {
        let endExpressionsIndex = self.expressions.count
        let endConstraintsIndex = self.constraints.count
        let expressionIndex = Int(sqlite3_column_int(statement, 2))
        let constraintsIndex = Int(sqlite3_column_int(statement, 7))
        guard
            expressionIndex >= 0,
            expressionIndex < endExpressionsIndex,
            constraintsIndex >= 0,
            constraintsIndex < endConstraintsIndex
        else {
            throw SQLiteError.corruptDatabase
        }
        let id = try UUID(statement: statement, offset: 0)
        let nodeId = try UUID(statement: statement, offset: 1)
        let inSession = try sqlite3_column_int(statement, 5).boolValue
        let historyRaw = Data(try String(statement: statement, offset: 3).utf8)
        let history = try self.decoder.decode([UUID].self, from: historyRaw)
        let currentBranchRaw = Data(try String(statement: statement, offset: 4).utf8)
        let currentBranch = try self.decoder.decode([UUID].self, from: currentBranchRaw)
        let historyExpression: Expression?
        if sqlite3_column_type(statement, 6) != SQLITE_NULL {
            let expressionIndex = Int(sqlite3_column_int(statement, 6))
            guard
                expressionIndex >= 0,
                expressionIndex < endExpressionsIndex
            else {
                throw SQLiteError.corruptDatabase
            }
            historyExpression = self.expressions[expressionIndex]
        } else {
            historyExpression = nil
        }
        let session = sqlite3_column_type(statement, 8) != SQLITE_NULL
            ? try UUID(statement: statement, offset: 8) : nil
        let successRevisit = sqlite3_column_type(statement, 9) != SQLITE_NULL
            ? try UUID(statement: statement, offset: 9) : nil
        let failRevisit = sqlite3_column_type(statement, 10) != SQLITE_NULL
            ? try UUID(statement: statement, offset: 10) : nil
        let data = JobData(
            nodeId: nodeId,
            expression: self.expressions[expressionIndex],
            history: Set(history),
            currentBranch: currentBranch,
            inSession: inSession,
            historyExpression: historyExpression,
            constraints: self.constraints[constraintsIndex],
            session: session,
            successRevisit: successRevisit,
            failRevisit: failRevisit
        )
        return Job(id: id, data: data)
    }

    private func createSchema() throws {
        let query = """
        CREATE TABLE IF NOT EXISTS jobs(
            id VARCHAR(36) PRIMARY KEY,
            node_id VARCHAR(36) NOT NULL,
            expression INTEGER NOT NULL,
            history TEXT NOT NULL,
            current_branch TEXT NOT NULL,
            in_session INTEGER NOT NULL,
            history_expression INTEGER,
            constraints INTEGER NOT NULL,
            session VARCHAR(36),
            success_revisit VARCHAR(36),
            fail_revisit VARCHAR(36)
        );
        CREATE UNIQUE INDEX IF NOT EXISTS job_data_index ON jobs(
            node_id, expression, history, current_branch, in_session, history_expression, constraints,
            session, success_revisit, fail_revisit
        );
        CREATE TABLE IF NOT EXISTS sessions(
            id VARCHAR(36) PRIMARY KEY,
            job_id VARCHAR(36) NOT NULL,
            node_id VARCHAR(36) NOT NULL,
            expression INTEGER NOT NULL,
            constraints INTEGER NOT NULL,
            is_completed INTEGER NOT NULL,
            status TEXT,
            FOREIGN KEY(job_id) REFERENCES jobs(id)
        );
        CREATE UNIQUE INDEX IF NOT EXISTS session_key ON sessions(node_id, expression, constraints);
        """
        var queryC = query.cString(using: .utf8)
        var statement: OpaquePointer?
        var tail: UnsafePointer<CChar>?
        repeat {
            try exec { sqlite3_prepare_v2(self.db, queryC, Int32(queryC?.count ?? 0), &statement, &tail) }
            do {
                try exec(result: SQLITE_DONE) { sqlite3_step(statement) }
            } catch let error {
                try exec { sqlite3_finalize(statement) }
                throw error
            }
            queryC = tail.flatMap { String(cString: $0).cString(using: .utf8) }
        } while (tail.map { String(cString: $0) }?.isEmpty == false)
        guard tail != nil else {
            throw SQLiteError.incompleteStatement(statement: query, tail: String(cString: tail!))
        }
    }

    private func dropSchema() throws {
        let query = """
        DROP INDEX IF EXISTS session_key;
        DROP TABLE IF EXISTS sessions;
        DROP INDEX IF EXISTS job_data_index;
        DROP TABLE IF EXISTS jobs;
        """
        var queryC = query.cString(using: .utf8)
        var statement: OpaquePointer?
        var tail: UnsafePointer<CChar>?
        repeat {
            try exec { sqlite3_prepare_v2(self.db, queryC, Int32(queryC?.count ?? 0), &statement, &tail) }
            do {
                try exec(result: SQLITE_DONE) { sqlite3_step(statement) }
            } catch let error {
                try exec { sqlite3_finalize(statement) }
                throw error
            }
            queryC = tail.flatMap { String(cString: $0).cString(using: .utf8) }
        } while (tail.map { String(cString: $0) }?.isEmpty == false)
        guard tail != nil else {
            throw SQLiteError.incompleteStatement(statement: query, tail: String(cString: tail!))
        }
    }

    private func exec(result: Int32 = SQLITE_OK, fn: () -> Int32) throws {
        guard fn() == result else {
            throw SQLiteError.cDriverError(errno: result, message: self.errorMessage)
        }
    }

    private func getConstraints(constraint: [PhysicalConstraint]) -> Int {
        guard let key = self.constraintKeys[constraint] else {
            let constraintId = self.constraints.count
            self.constraintKeys[constraint] = constraintId
            self.constraints.append(constraint)
            return constraintId
        }
        return key
    }

    private func getExpression(expression: TCTLParser.Expression) -> Int {
        guard let key = self.expressionKeys[expression] else {
            let expressionId = self.expressions.count
            self.expressionKeys[expression] = expressionId
            self.expressions.append(expression)
            return expressionId
        }
        return key
    }

    private func insertCurrentJob(job: Job) throws -> Int32 {
        let query = """
        INSERT INTO current_jobs(job_id) VALUES('\(job.id.uuidString)');
        """
        let queryC = query.cString(using: .utf8)
        var statement: OpaquePointer?
        var tail: UnsafePointer<CChar>?
        try exec { sqlite3_prepare_v2(self.db, queryC, Int32(queryC?.count ?? 0), &statement, &tail) }
        defer { try? exec { sqlite3_finalize(statement) } }
        guard let tail, String(cString: tail).isEmpty else {
            throw SQLiteError.incompleteStatement(statement: query, tail: String(cString: tail!))
        }
        try exec(result: SQLITE_DONE) { sqlite3_step(statement) }
        let id = sqlite3_column_int(statement, 0)
        return id
    }

    @discardableResult
    private func insertJob(data: JobData) throws -> UUID {
        let id = UUID()
        let expressionId = getExpression(expression: data.expression)
        let history = String(
            decoding: try self.encoder.encode(data.history.map(\.uuidString).sorted()),
            as: UTF8.self
        )
        let currentBranch = String(
            decoding: try self.encoder.encode(data.currentBranch.map(\.uuidString)), as: UTF8.self
        )
        let historyExpression = data.historyExpression.map { getExpression(expression: $0) }
        let constraints = getConstraints(constraint: data.constraints)
        let session = data.session.map { "\'\($0.uuidString)\'" } ?? "NULL"
        let successRevisit = data.successRevisit.map { "\'\($0.uuidString)\'" } ?? "NULL"
        let failRevisit = data.failRevisit.map { "\'\($0.uuidString)\'" } ?? "NULL"
        let query: String = """
        INSERT INTO jobs(
            id, node_id, expression, history, current_branch, in_session, history_expression, constraints,
            session, success_revisit, fail_revisit
        ) VALUES(
            '\(id.uuidString)', '\(data.nodeId.uuidString)', \(expressionId), '\(history)',
            '\(currentBranch)', \(data.inSession.sqlVal), \(historyExpression.map { String($0) } ?? "NULL"),
            \(constraints), \(session), \(successRevisit), \(failRevisit)
        );
        """
        let queryC = query.cString(using: .utf8)
        var statement: OpaquePointer?
        var tail: UnsafePointer<CChar>?
        try exec { sqlite3_prepare_v2(self.db, queryC, Int32(queryC?.count ?? 0), &statement, &tail) }
        defer { try? exec { sqlite3_finalize(statement) } }
        guard let tail, String(cString: tail).isEmpty else {
            throw SQLiteError.incompleteStatement(statement: query, tail: String(cString: tail!))
        }
        try exec(result: SQLITE_DONE) { sqlite3_step(statement) }
        return id
    }

    private func pluckJob(data: JobData) throws -> Job? {
        let query = """
        SELECT
            id
        FROM
            jobs
        WHERE
            node_id = '\(data.nodeId.uuidString)' AND
            expression = \(getExpression(expression: data.expression)) AND
            history = '\(String(
                decoding: try self.encoder.encode(data.history.map(\.uuidString).sorted()),
                as: UTF8.self
            ) )' AND
            current_branch = '\(String(
                decoding: try self.encoder.encode(data.currentBranch.map(\.uuidString)), as: UTF8.self
            ) )' AND
            in_session = \(data.inSession.sqlVal) AND
            history_expression = \(data.historyExpression.map { String(getExpression(expression: $0)) } ?? "NULL") AND
            constraints = \(getConstraints(constraint: data.constraints)) AND
            session = \(data.session.map { "\'\($0.uuidString)\'" } ?? "NULL") AND
            success_revisit = \(data.successRevisit.map { "\'\($0.uuidString)\'" } ?? "NULL") AND
            fail_revisit = \(data.failRevisit.map { "\'\($0.uuidString)\'" } ?? "NULL");
        """
        let queryC = query.cString(using: .utf8)
        var statement: OpaquePointer?
        var tail: UnsafePointer<CChar>?
        try exec { sqlite3_prepare_v2(self.db, queryC, Int32(queryC?.count ?? 0), &statement, &tail) }
        defer { try? exec { sqlite3_finalize(statement) } }
        guard let tail, String(cString: tail).isEmpty else {
            throw SQLiteError.incompleteStatement(statement: query, tail: String(cString: tail!))
        }
        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_ROW else {
            return nil
        }
        guard
            let id = sqlite3_column_text(statement, 0).flatMap(String.init(cString:)),
            let uuid = UUID(uuidString: id)
        else {
            throw SQLiteError.corruptDatabase
        }
        return Job(id: uuid, data: data)
    }

    private func pluckJob(id: UUID) throws -> Job? {
        let query = """
        SELECT
            *
        FROM
            jobs
        WHERE
            id = '\(id.uuidString)';
        """
        let queryC = query.cString(using: .utf8)
        var statement: OpaquePointer?
        var tail: UnsafePointer<CChar>?
        try exec { sqlite3_prepare_v2(self.db, queryC, Int32(queryC?.count ?? 0), &statement, &tail) }
        defer { try? exec { sqlite3_finalize(statement) } }
        guard let tail, String(cString: tail).isEmpty else {
            throw SQLiteError.incompleteStatement(statement: query, tail: String(cString: tail!))
        }
        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_ROW else {
            return nil
        }
        let endExpressionsIndex = self.expressions.count
        let endConstraintsIndex = self.constraints.count
        let expressionIndex = Int(sqlite3_column_int(statement, 2))
        let constraintsIndex = Int(sqlite3_column_int(statement, 7))
        guard
            expressionIndex >= 0,
            expressionIndex < endExpressionsIndex,
            constraintsIndex >= 0,
            constraintsIndex < endConstraintsIndex
        else {
            throw SQLiteError.corruptDatabase
        }
        let nodeId = try UUID(statement: statement, offset: 1)
        let inSession = try sqlite3_column_int(statement, 5).boolValue
        let historyRaw = Data(try String(statement: statement, offset: 3).utf8)
        let history = try self.decoder.decode([UUID].self, from: historyRaw)
        let currentBranchRaw = Data(try String(statement: statement, offset: 4).utf8)
        let currentBranch = try self.decoder.decode([UUID].self, from: currentBranchRaw)
        let historyExpression: Expression?
        if sqlite3_column_type(statement, 6) != SQLITE_NULL {
            let expressionIndex = Int(sqlite3_column_int(statement, 6))
            guard
                expressionIndex >= 0,
                expressionIndex < endExpressionsIndex
            else {
                throw SQLiteError.corruptDatabase
            }
            historyExpression = self.expressions[expressionIndex]
        } else {
            historyExpression = nil
        }
        let session = sqlite3_column_type(statement, 8) != SQLITE_NULL
            ? try UUID(statement: statement, offset: 8) : nil
        let successRevisit = sqlite3_column_type(statement, 9) != SQLITE_NULL
            ? try UUID(statement: statement, offset: 9) : nil
        let failRevisit = sqlite3_column_type(statement, 10) != SQLITE_NULL
            ? try UUID(statement: statement, offset: 10) : nil
        let data = JobData(
            nodeId: nodeId,
            expression: self.expressions[expressionIndex],
            history: Set(history),
            currentBranch: currentBranch,
            inSession: inSession,
            historyExpression: historyExpression,
            constraints: self.constraints[constraintsIndex],
            session: session,
            successRevisit: successRevisit,
            failRevisit: failRevisit
        )
        return Job(id: id, data: data)
    }

    deinit {
        sqlite3_close(self.db)
    }

}

private extension UUID {

    init(statement: OpaquePointer?, offset: Int32) throws {
        let id = try String(statement: statement, offset: offset)
        guard let uuid = UUID(uuidString: id) else {
            throw SQLiteError.corruptDatabase
        }
        self = uuid
    }

}

private extension String {

    init(statement: OpaquePointer?, offset: Int32) throws {
        guard let cString = sqlite3_column_text(statement, offset) else {
            throw SQLiteError.corruptDatabase
        }
        self.init(cString: cString)
    }

}

private extension Bool {

    var sqlVal: Int32 {
        self ? 1 : 0
    }

    init(statement: OpaquePointer?, offset: Int32) throws {
        let value = sqlite3_column_int(statement, offset)
        self = try value.boolValue
    }

}

private extension Int32 {

    var boolValue: Bool {
        get throws {
            switch self {
            case 1:
                return true
            case 0:
                return false
            default:
                throw SQLiteError.corruptDatabase
            }
        }
    }

}
