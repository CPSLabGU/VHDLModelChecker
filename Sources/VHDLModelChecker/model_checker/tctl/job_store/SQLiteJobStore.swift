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

    var next: UUID? {
        get throws {
            throw SQLiteError.corruptDatabase
        }
    }

    var pendingSessionJob: Job? {
        get throws {
            throw SQLiteError.corruptDatabase
        }
    }

    private var errorMessage: String {
        String(cString: sqlite3_errmsg(self.db))
    }

    private var expressions: [Expression] = []

    private var expressionKeys: [Expression: Int] = [:]

    private var constraints: [[PhysicalConstraint]] = []

    private var constraintKeys: [[PhysicalConstraint]: Int] = [:]

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
        throw SQLiteError.corruptDatabase
    }

    func addJob(job: Job) throws {
        throw SQLiteError.corruptDatabase
    }

    func addManyJobs(jobs: [JobData]) throws {
        throw SQLiteError.corruptDatabase
    }

    func completePendingSession(session: UUID, result: ModelCheckerError?) throws {
        throw SQLiteError.corruptDatabase
    }

    func inCycle(_ job: Job) throws -> Bool {
        throw SQLiteError.corruptDatabase
    }

    func isPending(session: UUID) throws -> Bool {
        throw SQLiteError.corruptDatabase
    }

    func job(forData data: JobData) throws -> Job {
        guard let job = try self.pluckJob(data: data) else {
            return Job(id: try self.insertJob(data: data), data: data)
        }
        return job
        // try self.insertJob(data: data)
    }

    func job(withId id: UUID) throws -> Job {
        throw SQLiteError.corruptDatabase
    }

    func reset() throws {
        throw SQLiteError.corruptDatabase
    }

    func sessionId(forJob job: Job) throws -> UUID {
        throw SQLiteError.corruptDatabase
    }

    func sessionStatus(session: UUID) throws -> ModelCheckerError?? {
        throw SQLiteError.corruptDatabase
    }

    private func createSchema() throws {
        let query = """
        CREATE TABLE IF NOT EXISTS jobs(
            id TEXT PRIMARY KEY,
            node_id TEXT NOT NULL,
            expression INTEGER NOT NULL,
            history TEXT NOT NULL,
            current_branch TEXT NOT NULL,
            in_session INTEGER NOT NULL,
            history_expression INTEGER,
            constraints INTEGER NOT NULL,
            session TEXT,
            success_revisit TEXT,
            fail_revisit TEXT
        );
        CREATE UNIQUE INDEX IF NOT EXISTS job_data_index ON jobs(
            node_id, expression, history, current_branch, in_session, history_expression, constraints,
            session, success_revisit, fail_revisit
        );
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

    // private func id(data: JobData) throws -> UUID {

    // }

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
        guard let tail, String(cString: tail).isEmpty else {
            try exec { sqlite3_finalize(statement) }
            throw SQLiteError.incompleteStatement(statement: query, tail: String(cString: tail!))
        }
        do {
            try exec(result: SQLITE_DONE) { sqlite3_step(statement) }
        } catch let error {
            try exec { sqlite3_finalize(statement) }
            throw error
        }
        try exec { sqlite3_finalize(statement) }
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
        do {
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
        } catch let error {
            throw error
        }
    }

    deinit {
        sqlite3_close(self.db)
    }

}

private extension Bool {

    var sqlVal: Int32 {
        self ? 1 : 0
    }

}
