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

    private var inCycleInsertStatement: OpaquePointer

    private var inCycleSelectStatement: OpaquePointer

    private var pluckJobSelect: OpaquePointer

    private var pluckJobSelectID: OpaquePointer

    private var insertJobStatement: OpaquePointer

    var next: UUID? {
        get throws {
            self.currentJobs.popLast()
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
        try self.init(db: db)
    }

    private convenience init(db: OpaquePointer) throws {
        let exec: (Int32, () -> Int32) throws -> Void = {
            guard $1() == $0 else {
                throw SQLiteError.cDriverError(errno: $0, message: String(cString: sqlite3_errmsg(db)))
            }
        }
        let queries = [
            """
            CREATE TABLE IF NOT EXISTS jobs(
                id VARCHAR(36) PRIMARY KEY,
                node_id VARCHAR(36) NOT NULL,
                expression INTEGER NOT NULL,
                history TEXT NOT NULL,
                current_branch TEXT NOT NULL,
                history_expression INTEGER,
                constraints INTEGER NOT NULL,
                success_revisit VARCHAR(36),
                fail_revisit VARCHAR(36)
            );
            CREATE UNIQUE INDEX IF NOT EXISTS job_data_index ON jobs(
                node_id, expression, history, current_branch, history_expression, constraints,
                success_revisit, fail_revisit
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS cycles(
                node_id VARCHAR(36) NOT NULL,
                expression INTEGER NOT NULL,
                in_cycle INTEGER NOT NULL,
                history_expression INTEGER,
                constraints INTEGER NOT NULL,
                success_revisit VARCHAR(36),
                fail_revisit VARCHAR(36),
                PRIMARY KEY (
                    node_id, expression, in_cycle, history_expression, constraints, success_revisit,
                    fail_revisit
                )
            );
            """
        ]
        for query in queries {
            var queryC = query.cString(using: .utf8)
            var statement: OpaquePointer?
            var tail: UnsafePointer<CChar>?
            repeat {
                try exec(SQLITE_OK) {
                    sqlite3_prepare_v2(db, queryC, Int32(queryC?.count ?? 0), &statement, &tail)
                }
                defer { try? exec(SQLITE_OK) { sqlite3_finalize(statement) } }
                try exec(SQLITE_DONE) { sqlite3_step(statement) }
                queryC = tail.flatMap { String(cString: $0).cString(using: .utf8) }
            } while (tail.map { String(cString: $0) }?.isEmpty == false)
            guard tail != nil else {
                throw SQLiteError.incompleteStatement(statement: query, tail: String(cString: tail!))
            }
        }
        let inCycleInsertStatement = try OpaquePointer(
            db: db,
            query: """
            INSERT INTO cycles(
                node_id, expression, in_cycle, history_expression, constraints, success_revisit,
                fail_revisit
            ) VALUES(
                ?1, ?2, ?3, ?4, ?5, ?6, ?7
            );
            """
        )
        let inCycleSelectStatement = try OpaquePointer(
            db: db,
            query: """
            SELECT
                in_cycle
            FROM
                cycles
            WHERE
                node_id = ?1 AND
                expression = ?2 AND
                in_cycle = ?3 AND
                history_expression = ?4 AND
                constraints = ?5 AND
                success_revisit = ?6 AND
                fail_revisit = ?7;
            """
        )
        let pluckJobSelect = try OpaquePointer(
            db: db,
            query: """
            SELECT
                id
            FROM
                jobs
            WHERE
                node_id = ?1 AND
                expression = ?2 AND
                history = ?3 AND
                current_branch = ?4 AND
                history_expression = ?5 AND
                constraints = ?6 AND
                success_revisit = ?7 AND
                fail_revisit = ?8;
            """
        )
        let pluckJobSelectID = try OpaquePointer(db: db, query: "SELECT * FROM jobs WHERE id = ?1;")
        let insertJobStatement = try OpaquePointer(
            db: db,
            query: """
            INSERT INTO jobs(
                id, node_id, expression, history, current_branch, history_expression, constraints,
                success_revisit, fail_revisit
            ) VALUES(
                ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9
            );
            """
        )
        self.init(
            db: db,
            inCycleInsertStatement: inCycleInsertStatement,
            inCycleSelectStatement: inCycleSelectStatement,
            pluckJobSelect: pluckJobSelect,
            pluckJobSelectID: pluckJobSelectID,
            insertJobStatement: insertJobStatement
        )
    }

    private init(
        db: OpaquePointer,
        inCycleInsertStatement: OpaquePointer,
        inCycleSelectStatement: OpaquePointer,
        pluckJobSelect: OpaquePointer,
        pluckJobSelectID: OpaquePointer,
        insertJobStatement: OpaquePointer
    ) {
        self.db = db
        self.inCycleInsertStatement = inCycleInsertStatement
        self.inCycleSelectStatement = inCycleSelectStatement
        self.pluckJobSelect = pluckJobSelect
        self.pluckJobSelectID = pluckJobSelectID
        self.insertJobStatement = insertJobStatement
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

    func inCycle(_ job: Job) throws -> Bool {
        let data = job.cycleData
        var strings: [[CChar]] = []
        var parameters: [Int32] = []
        guard let nodeStr = data.nodeId.uuidString.cString(using: .utf8) else {
            throw ModelCheckerError.internalError
        }
        strings.append(nodeStr)
        parameters.append(1)
        let expressionIndex = Int32(getExpression(expression: data.expression))
        try exec { sqlite3_bind_int(self.inCycleSelectStatement, 2, expressionIndex) }
        let inCycle = data.inCycle.sqlVal
        try exec { sqlite3_bind_int(self.inCycleSelectStatement, 3, inCycle) }
        let historyExpression = data.historyExpression.map { Int32(getExpression(expression: $0)) }
        if let historyExpression {
            try exec { sqlite3_bind_int(self.inCycleSelectStatement, 4, historyExpression) }
        } else {
            try exec { sqlite3_bind_null(self.inCycleSelectStatement, 4) }
        }
        let constraintIndex = Int32(getConstraints(constraint: data.constraints))
        try exec { sqlite3_bind_int(self.inCycleSelectStatement, 5, constraintIndex) }
        let successStr = data.successRevisit.map { $0.uuidString }
        if let successStr {
            guard let cStr = successStr.cString(using: .utf8) else {
                throw ModelCheckerError.internalError
            }
            strings.append(cStr)
            parameters.append(6)
        } else {
            try exec { sqlite3_bind_null(self.inCycleSelectStatement, 6) }
        }
        let failStr = data.failRevisit.map { $0.uuidString }
        if let failStr {
            guard let cStr = failStr.cString(using: .utf8) else {
                throw ModelCheckerError.internalError
            }
            strings.append(cStr)
            parameters.append(7)
        } else {
            try exec { sqlite3_bind_null(self.inCycleSelectStatement, 7) }
        }
        return try self.bind(data: strings, parameters: parameters, statement: self.inCycleSelectStatement) {
            guard $1 == SQLITE_DONE else {
                guard $1 == SQLITE_ROW else {
                    throw SQLiteError.connectionError(message: self.errorMessage)
                }
                return true
            }
            var insertStrings: [[CChar]] = [nodeStr]
            var insertParameters: [Int32] = [1]
            try exec { sqlite3_bind_int(self.inCycleInsertStatement, 2, expressionIndex) }
            try exec { sqlite3_bind_int(self.inCycleInsertStatement, 3, inCycle) }
            if let historyExpression {
                try exec { sqlite3_bind_int(self.inCycleInsertStatement, 4, historyExpression) }
            } else {
                try exec { sqlite3_bind_null(self.inCycleInsertStatement, 4) }
            }
            try exec { sqlite3_bind_int(self.inCycleInsertStatement, 5, constraintIndex) }
            if let successStr {
                guard let cStr = successStr.cString(using: .utf8) else {
                    throw ModelCheckerError.internalError
                }
                insertStrings.append(cStr)
                insertParameters.append(6)
            } else {
                try exec { sqlite3_bind_null(self.inCycleInsertStatement, 6) }
            }
            if let failStr {
                guard let cStr = failStr.cString(using: .utf8) else {
                    throw ModelCheckerError.internalError
                }
                insertStrings.append(cStr)
                insertParameters.append(7)
            } else {
                try exec { sqlite3_bind_null(self.inCycleInsertStatement, 7) }
            }
            try self.bind(
                data: insertStrings, parameters: insertParameters, statement: self.inCycleInsertStatement
            ) {
                guard $1 == SQLITE_DONE else {
                    throw SQLiteError.cDriverError(errno: $1, message: self.errorMessage)
                }
            }
            return false
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
        try self.finalizeStatements()
        try self.dropSchema()
        try self.createSchema()
        try self.prepareStatements()
        self.currentJobs.removeAll(keepingCapacity: true)
        self.expressions.removeAll()
        self.expressionKeys.removeAll()
        self.constraints.removeAll()
        self.constraintKeys.removeAll()
    }

    private func bind<T>(
        data: [[CChar]],
        parameters: [Int32],
        statement: OpaquePointer,
        _ callback: (OpaquePointer, Int32) throws -> T
    ) throws -> T {
        guard !data.isEmpty, data.count == parameters.count else {
            throw ModelCheckerError.internalError
        }
        guard data.count != 1 else {
            return try self.bind(
                data: data[0], offsets: [0], parameters: parameters, statement: statement, callback
            )
        }
        var offsets: [Int] = []
        for index in data.indices {
            guard index != 0 else {
                offsets.append(0)
                continue
            }
            offsets.append(offsets[index - 1] + data[index - 1].count * MemoryLayout<CChar>.stride)
        }
        return try self.bind(
            data: data.flatMap { $0 },
            offsets: offsets,
            parameters: parameters,
            statement: statement,
            callback
        )
    }

    private func bind<T>(
        data: [CChar],
        offsets: [Int] = [0],
        parameters: [Int32] = [1],
        statement: OpaquePointer,
        _ callback: (OpaquePointer, Int32) throws -> T
    ) throws -> T {
        guard !data.isEmpty, !offsets.isEmpty, offsets.count == parameters.count else {
            throw ModelCheckerError.internalError
        }
        guard let result: T = try data.withContiguousStorageIfAvailable({
            defer {
                sqlite3_clear_bindings(statement)
                sqlite3_reset(statement)
            }
            let lastIndex = offsets.count - 1
            let stride = MemoryLayout<CChar>.stride
            for index in offsets.indices {
                let offset = offsets[index]
                guard let pointer = $0.baseAddress?.advanced(by: offset) else {
                    throw ModelCheckerError.internalError
                }
                let totalBytes = index == lastIndex ? data.count * stride - offset
                    : offsets[index + 1] - offset
                // Don't include null-termination in size.
                let size = Int32(totalBytes - stride)
                try exec {
                    sqlite3_bind_text(statement, parameters[index], pointer, size, nil)
                }
            }
            return try callback(statement, sqlite3_step(statement))
        }) else {
            throw ModelCheckerError.internalError
        }
        return result
    }

    private func createJob(statement: OpaquePointer) throws -> Job {
        let endExpressionsIndex = self.expressions.count
        let endConstraintsIndex = self.constraints.count
        let expressionIndex = Int(sqlite3_column_int(statement, 2))
        let constraintsIndex = Int(sqlite3_column_int(statement, 6))
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
        let historyRaw = Data(try String(statement: statement, offset: 3).utf8)
        let history = try self.decoder.decode([UUID].self, from: historyRaw)
        let currentBranchRaw = Data(try String(statement: statement, offset: 4).utf8)
        let currentBranch = try self.decoder.decode([UUID].self, from: currentBranchRaw)
        let historyExpression: Expression?
        if sqlite3_column_type(statement, 5) != SQLITE_NULL {
            let expressionIndex = Int(sqlite3_column_int(statement, 5))
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
        let successRevisit = sqlite3_column_type(statement, 7) != SQLITE_NULL
            ? try UUID(statement: statement, offset: 7) : nil
        let failRevisit = sqlite3_column_type(statement, 8) != SQLITE_NULL
            ? try UUID(statement: statement, offset: 8) : nil
        let data = JobData(
            nodeId: nodeId,
            expression: self.expressions[expressionIndex],
            history: Set(history),
            currentBranch: currentBranch,
            historyExpression: historyExpression,
            constraints: self.constraints[constraintsIndex],
            successRevisit: successRevisit,
            failRevisit: failRevisit
        )
        return Job(id: id, data: data)
    }

    private func createSchema() throws {
        let queries = [
            """
            CREATE TABLE IF NOT EXISTS jobs(
                id VARCHAR(36) PRIMARY KEY,
                node_id VARCHAR(36) NOT NULL,
                expression INTEGER NOT NULL,
                history TEXT NOT NULL,
                current_branch TEXT NOT NULL,
                history_expression INTEGER,
                constraints INTEGER NOT NULL,
                success_revisit VARCHAR(36),
                fail_revisit VARCHAR(36)
            );
            CREATE UNIQUE INDEX IF NOT EXISTS job_data_index ON jobs(
                node_id, expression, history, current_branch, history_expression, constraints,
                success_revisit, fail_revisit
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS cycles(
                node_id VARCHAR(36) NOT NULL,
                expression INTEGER NOT NULL,
                in_cycle INTEGER NOT NULL,
                history_expression INTEGER,
                constraints INTEGER NOT NULL,
                success_revisit VARCHAR(36),
                fail_revisit VARCHAR(36),
                PRIMARY KEY (
                    node_id, expression, in_cycle, history_expression, constraints, success_revisit,
                    fail_revisit
                )
            );
            """
        ]
        for query in queries {
            var queryC = query.cString(using: .utf8)
            var statement: OpaquePointer?
            var tail: UnsafePointer<CChar>?
            repeat {
                try exec { sqlite3_prepare_v2(self.db, queryC, Int32(queryC?.count ?? 0), &statement, &tail) }
                defer { try? exec { sqlite3_finalize(statement) } }
                try exec(result: SQLITE_DONE) { sqlite3_step(statement) }
                queryC = tail.flatMap { String(cString: $0).cString(using: .utf8) }
            } while (tail.map { String(cString: $0) }?.isEmpty == false)
            guard tail != nil else {
                throw SQLiteError.incompleteStatement(statement: query, tail: String(cString: tail!))
            }
        }
    }

    private func dropSchema() throws {
        let query = """
        DROP TABLE IF EXISTS cycles;
        DROP INDEX IF EXISTS job_data_index;
        DROP TABLE IF EXISTS jobs;
        """
        var queryC = query.cString(using: .utf8)
        var statement: OpaquePointer?
        var tail: UnsafePointer<CChar>?
        repeat {
            try exec { sqlite3_prepare_v2(self.db, queryC, Int32(queryC?.count ?? 0), &statement, &tail) }
            defer { try? exec { sqlite3_finalize(statement) } }
            try exec(result: SQLITE_DONE) { sqlite3_step(statement) }
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

    private func finalizeStatements() throws {
        try exec { sqlite3_finalize(self.inCycleInsertStatement) }
        try exec { sqlite3_finalize(self.inCycleSelectStatement) }
        try exec { sqlite3_finalize(self.pluckJobSelect) }
        try exec { sqlite3_finalize(self.pluckJobSelectID) }
        try exec { sqlite3_finalize(self.insertJobStatement) }
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

    @discardableResult
    private func insertJob(data: JobData) throws -> UUID {
        let id = UUID()
        let history = String(
            decoding: try self.encoder.encode(data.history.map(\.uuidString).sorted()),
            as: UTF8.self
        )
        let currentBranch = String(
            decoding: try self.encoder.encode(data.currentBranch.map(\.uuidString)), as: UTF8.self
        )
        guard
            let idStr = id.uuidString.cString(using: .utf8),
            let nodeIDStr = data.nodeId.uuidString.cString(using: .utf8),
            let historyStr = history.cString(using: .utf8),
            let currentBranchStr = currentBranch.cString(using: .utf8)
        else {
            throw ModelCheckerError.internalError
        }
        var strings = [idStr, nodeIDStr, historyStr, currentBranchStr]
        var parameters: [Int32] = [1, 2, 4, 5]
        try exec {
            sqlite3_bind_int(self.insertJobStatement, 3, Int32(getExpression(expression: data.expression)))
        }
        if let historyExpression = data.historyExpression {
            try exec {
                sqlite3_bind_int(
                    self.insertJobStatement, 6, Int32(getExpression(expression: historyExpression))
                )
            }
        } else {
            try exec { sqlite3_bind_null(self.insertJobStatement, 6) }
        }
        try exec {
            sqlite3_bind_int(self.insertJobStatement, 7, Int32(getConstraints(constraint: data.constraints)))
        }
        if let success = data.successRevisit?.uuidString {
            guard let cStr = success.cString(using: .utf8) else {
                throw ModelCheckerError.internalError
            }
            strings.append(cStr)
            parameters.append(8)
        } else {
            try exec { sqlite3_bind_null(self.insertJobStatement, 8) }
        }
        if let fail = data.failRevisit?.uuidString {
            guard let cStr = fail.cString(using: .utf8) else {
                throw ModelCheckerError.internalError
            }
            strings.append(cStr)
            parameters.append(9)
        } else {
            try exec { sqlite3_bind_null(self.insertJobStatement, 9) }
        }
        try self.bind(data: strings, parameters: parameters, statement: self.insertJobStatement) {
            guard $1 == SQLITE_DONE else {
                throw SQLiteError.cDriverError(errno: $1, message: self.errorMessage)
            }
        }
        return id
    }

    private func pluckJob(data: JobData) throws -> Job? {
        let historyData = String(
            decoding: try self.encoder.encode(data.history.map(\.uuidString).sorted()),
            as: UTF8.self
        )
        let currentBranchData = String(
            decoding: try self.encoder.encode(data.currentBranch.map(\.uuidString)), as: UTF8.self
        )
        guard
            let historyString = historyData.cString(using: .utf8),
            let currentBranchString = currentBranchData.cString(using: .utf8),
            let nodeIDString = data.nodeId.uuidString.cString(using: .utf8)
        else {
            throw ModelCheckerError.internalError
        }
        var strings = [historyString, currentBranchString, nodeIDString]
        var parameters: [Int32] = [3, 4, 1]
        try exec {
            sqlite3_bind_int(self.pluckJobSelect, 2, Int32(getExpression(expression: data.expression)))
        }
        let historyExpression = data.historyExpression.map { Int32(getExpression(expression: $0)) }
        if let historyExpression {
            try exec { sqlite3_bind_int(self.pluckJobSelect, 5, historyExpression) }
        } else {
            try exec { sqlite3_bind_null(self.pluckJobSelect, 5) }
        }
        try exec {
            sqlite3_bind_int(self.pluckJobSelect, 6, Int32(getConstraints(constraint: data.constraints)))
        }
        if let success = data.successRevisit?.uuidString {
            guard let cStr = success.cString(using: .utf8) else {
                throw ModelCheckerError.internalError
            }
            strings.append(cStr)
            parameters.append(7)
        } else {
            try exec { sqlite3_bind_null(self.pluckJobSelect, 7) }
        }
        if let fail = data.failRevisit?.uuidString {
            guard let cStr = fail.cString(using: .utf8) else {
                throw ModelCheckerError.internalError
            }
            strings.append(cStr)
            parameters.append(8)
        } else {
            try exec { sqlite3_bind_null(self.pluckJobSelect, 8) }
        }
        return try self.bind(data: strings, parameters: parameters, statement: self.pluckJobSelect) {
            guard $1 == SQLITE_ROW else {
                return nil
            }
            guard
                let id = sqlite3_column_text($0, 0).flatMap(String.init(cString:)),
                let uuid = UUID(uuidString: id)
            else {
                throw SQLiteError.corruptDatabase
            }
            return Job(id: uuid, data: data)
        }
    }

    private func pluckJob(id: UUID) throws -> Job? {
        guard let idStr = id.uuidString.cString(using: .utf8) else {
            throw ModelCheckerError.internalError
        }
        return try self.bind(data: idStr, offsets: [0], parameters: [1], statement: self.pluckJobSelectID) {
            guard $1 == SQLITE_ROW else {
                return nil
            }
            let endExpressionsIndex = self.expressions.count
            let endConstraintsIndex = self.constraints.count
            let expressionIndex = Int(sqlite3_column_int($0, 2))
            let constraintsIndex = Int(sqlite3_column_int($0, 6))
            guard
                expressionIndex >= 0,
                expressionIndex < endExpressionsIndex,
                constraintsIndex >= 0,
                constraintsIndex < endConstraintsIndex
            else {
                throw SQLiteError.corruptDatabase
            }
            let nodeId = try UUID(statement: $0, offset: 1)
            let historyRaw = Data(try String(statement: $0, offset: 3).utf8)
            let history = try self.decoder.decode([UUID].self, from: historyRaw)
            let currentBranchRaw = Data(try String(statement: $0, offset: 4).utf8)
            let currentBranch = try self.decoder.decode([UUID].self, from: currentBranchRaw)
            let historyExpression: Expression?
            if sqlite3_column_type($0, 5) != SQLITE_NULL {
                let expressionIndex = Int(sqlite3_column_int($0, 5))
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
            let successRevisit = sqlite3_column_type($0, 7) != SQLITE_NULL
                ? try UUID(statement: $0, offset: 7) : nil
            let failRevisit = sqlite3_column_type($0, 8) != SQLITE_NULL
                ? try UUID(statement: $0, offset: 8) : nil
            let data = JobData(
                nodeId: nodeId,
                expression: self.expressions[expressionIndex],
                history: Set(history),
                currentBranch: currentBranch,
                historyExpression: historyExpression,
                constraints: self.constraints[constraintsIndex],
                successRevisit: successRevisit,
                failRevisit: failRevisit
            )
            return Job(id: id, data: data)
        }
    }

    private func prepareStatements() throws {
        self.inCycleInsertStatement = try OpaquePointer(
            db: self.db,
            query: """
            INSERT INTO cycles(
                node_id, expression, in_cycle, history_expression, constraints, success_revisit,
                fail_revisit
            ) VALUES(
                ?1, ?2, ?3, ?4, ?5, ?6, ?7
            );
            """
        )
        self.inCycleSelectStatement = try OpaquePointer(
            db: self.db,
            query: """
            SELECT
                in_cycle
            FROM
                cycles
            WHERE
                node_id = ?1 AND
                expression = ?2 AND
                in_cycle = ?3 AND
                history_expression = ?4 AND
                constraints = ?5 AND
                success_revisit = ?6 AND
                fail_revisit = ?7;
            """
        )
        self.pluckJobSelect = try OpaquePointer(
            db: self.db,
            query: """
            SELECT
                id
            FROM
                jobs
            WHERE
                node_id = ?1 AND
                expression = ?2 AND
                history = ?3 AND
                current_branch = ?4 AND
                history_expression = ?5 AND
                constraints = ?6 AND
                success_revisit = ?7 AND
                fail_revisit = ?8;
            """
        )
        self.pluckJobSelectID = try OpaquePointer(db: self.db, query: "SELECT * FROM jobs WHERE id = ?1;")
        self.insertJobStatement = try OpaquePointer(
            db: db,
            query: """
            INSERT INTO jobs(
                id, node_id, expression, history, current_branch, history_expression, constraints,
                success_revisit, fail_revisit
            ) VALUES(
                ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9
            );
            """
        )
    }

    deinit {
        _ = sqlite3_finalize(self.inCycleInsertStatement)
        _ = sqlite3_finalize(self.inCycleSelectStatement)
        _ = sqlite3_finalize(self.pluckJobSelect)
        _ = sqlite3_finalize(self.pluckJobSelectID)
        _ = sqlite3_finalize(self.insertJobStatement)
        _ = sqlite3_close(self.db)
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

private extension Array where Element == CChar {

    var bytes: Int32 {
        // Don't include null-termination in calculation.
        Int32(MemoryLayout<CChar>.stride * (self.count - 1))
    }

}

private extension OpaquePointer {

    init(db: OpaquePointer, query: String) throws {
        guard let queryC = query.cString(using: .utf8) else {
            throw ModelCheckerError.internalError
        }
        var statement: OpaquePointer?
        var tail: UnsafePointer<CChar>?
        let result = sqlite3_prepare_v2(db, queryC, queryC.bytes, &statement, &tail)
        guard result == SQLITE_OK else {
            throw SQLiteError.cDriverError(errno: result, message: String(cString: sqlite3_errmsg(db)))
        }
        guard let tail, String(cString: tail).isEmpty else {
            if let tail {
                throw SQLiteError.incompleteStatement(statement: query, tail: String(cString: tail))
            }
            throw SQLiteError.corruptDatabase
        }
        guard let statement else {
            throw SQLiteError.corruptDatabase
        }
        self = statement
    }

}
