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
import VHDLKripkeStructures

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

    private var constraints: [Set<ConstrainedStatement>] = []

    private var constraintKeys: [Set<ConstrainedStatement>: Int] = [:]

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

    private var selectSessionStatement: OpaquePointer

    private var selectSessionCountStatement: OpaquePointer

    private var updateSessionCount: OpaquePointer

    private var updateSessionError: OpaquePointer

    private var insertSession: OpaquePointer

    var next: UUID? {
        get throws {
            guard let id = self.currentJobs.popLast() else {
                return nil
            }
            let job = try self.job(withId: id)
            guard let session = job.session else {
                return id
            }
            guard let currentCount = try self.sessionCount(id: session), currentCount > 0 else {
                throw SQLiteError.corruptDatabase
            }
            try self.updateSessionCount(id: session, count: currentCount - 1)
            return id
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
                fail_revisit VARCHAR(36),
                current_time_coefficient INTEGER NOT NULL,
                current_time_exponent INTEGER NOT NULL,
                current_energy_coefficient INTEGER NOT NULL,
                current_energy_exponent INTEGER NOT NULL,
                time_minimum_coefficient INTEGER NOT NULL,
                time_minimum_exponent INTEGER NOT NULL,
                time_maximum_coefficient INTEGER NOT NULL,
                time_maximum_exponent INTEGER NOT NULL,
                energy_minimum_coefficient INTEGER NOT NULL,
                energy_minimum_exponent INTEGER NOT NULL,
                energy_maximum_coefficient INTEGER NOT NULL,
                energy_maximum_exponent INTEGER NOT NULL,
                session VARCHAR(36),
                session_revisit VARCHAR(36)
            );
            """,
            """
            CREATE UNIQUE INDEX IF NOT EXISTS job_data_index ON jobs(
                node_id, expression, history, current_branch, history_expression, constraints,
                success_revisit, fail_revisit, current_time_coefficient, current_time_exponent,
                current_energy_coefficient, current_energy_exponent, time_minimum_coefficient,
                time_minimum_exponent, time_maximum_coefficient, time_maximum_exponent,
                energy_minimum_coefficient, energy_minimum_exponent, energy_maximum_coefficient,
                energy_maximum_exponent, session, session_revisit
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
                current_time_coefficient INTEGER NOT NULL,
                current_time_exponent INTEGER NOT NULL,
                current_energy_coefficient INTEGER NOT NULL,
                current_energy_exponent INTEGER NOT NULL,
                time_minimum_coefficient INTEGER NOT NULL,
                time_minimum_exponent INTEGER NOT NULL,
                time_maximum_coefficient INTEGER NOT NULL,
                time_maximum_exponent INTEGER NOT NULL,
                energy_minimum_coefficient INTEGER NOT NULL,
                energy_minimum_exponent INTEGER NOT NULL,
                energy_maximum_coefficient INTEGER NOT NULL,
                energy_maximum_exponent INTEGER NOT NULL,
                session VARCHAR(36),
                session_revisit VARCHAR(36),
                PRIMARY KEY (
                    node_id, expression, in_cycle, history_expression, constraints, success_revisit,
                    fail_revisit, current_time_coefficient, current_time_exponent,
                    current_energy_coefficient, current_energy_exponent, time_minimum_coefficient,
                    time_minimum_exponent, time_maximum_coefficient, time_maximum_exponent,
                    energy_minimum_coefficient, energy_minimum_exponent, energy_maximum_coefficient,
                    energy_maximum_exponent, session, session_revisit
                )
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS sessions(
                id VARCHAR(36) PRIMARY KEY,
                count INTEGER NOT NULL,
                error TEXT
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
                fail_revisit, current_time_coefficient, current_time_exponent,
                current_energy_coefficient, current_energy_exponent, time_minimum_coefficient,
                time_minimum_exponent, time_maximum_coefficient, time_maximum_exponent,
                energy_minimum_coefficient, energy_minimum_exponent, energy_maximum_coefficient,
                energy_maximum_exponent, session, session_revisit
            ) VALUES(
                ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20, ?21
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
                fail_revisit = ?7 AND
                current_time_coefficient = ?8 AND
                current_time_exponent = ?9 AND
                current_energy_coefficient = ?10 AND
                current_energy_exponent = ?11 AND
                time_minimum_coefficient = ?12 AND
                time_minimum_exponent = ?13 AND
                time_maximum_coefficient = ?14 AND
                time_maximum_exponent = ?15 AND
                energy_minimum_coefficient = ?16 AND
                energy_minimum_exponent = ?17 AND
                energy_maximum_coefficient = ?18 AND
                energy_maximum_exponent = ?19 AND
                session = ?20 AND
                session_revisit = ?21;
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
                fail_revisit = ?8 AND
                current_time_coefficient = ?9 AND
                current_time_exponent = ?10 AND
                current_energy_coefficient = ?11 AND
                current_energy_exponent = ?12 AND
                time_minimum_coefficient = ?13 AND
                time_minimum_exponent = ?14 AND
                time_maximum_coefficient = ?15 AND
                time_maximum_exponent = ?16 AND
                energy_minimum_coefficient = ?17 AND
                energy_minimum_exponent = ?18 AND
                energy_maximum_coefficient = ?19 AND
                energy_maximum_exponent = ?20 AND
                session = ?21 AND
                session_revisit = ?22;
            """
        )
        let pluckJobSelectID = try OpaquePointer(db: db, query: "SELECT * FROM jobs WHERE id = ?1;")
        let insertJobStatement = try OpaquePointer(
            db: db,
            query: """
            INSERT INTO jobs(
                id, node_id, expression, history, current_branch, history_expression, constraints,
                success_revisit, fail_revisit, current_time_coefficient, current_time_exponent,
                current_energy_coefficient, current_energy_exponent, time_minimum_coefficient,
                time_minimum_exponent, time_maximum_coefficient, time_maximum_exponent,
                energy_minimum_coefficient, energy_minimum_exponent, energy_maximum_coefficient,
                energy_maximum_exponent, session, session_revisit
            ) VALUES(
                ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20,
                ?21, ?22, ?23
            );
            """
        )
        let selectSessionStatement = try OpaquePointer(
            db: db, query: "SELECT error FROM sessions where id = ?1;"
        )
        let selectSessionCountStatement = try OpaquePointer(
            db: db, query: "SELECT count FROM sessions where id = ?1;"
        )
        let updateSessionCount = try OpaquePointer(
            db: db, query: "UPDATE sessions SET count = ?1 WHERE id = ?2;"
        )
        let updateSessionError = try OpaquePointer(
            db: db, query: "UPDATE sessions SET error = ?1 WHERE id = ?2;"
        )
        let insertSession = try OpaquePointer(
            db: db, query: "INSERT INTO sessions(id, count, error) VALUES(?1, ?2, ?3);"
        )
        self.init(
            db: db,
            inCycleInsertStatement: inCycleInsertStatement,
            inCycleSelectStatement: inCycleSelectStatement,
            pluckJobSelect: pluckJobSelect,
            pluckJobSelectID: pluckJobSelectID,
            insertJobStatement: insertJobStatement,
            selectSessionStatement: selectSessionStatement,
            selectSessionCountStatement: selectSessionCountStatement,
            updateSessionCount: updateSessionCount,
            updateSessionError: updateSessionError,
            insertSession: insertSession
        )
    }

    private init(
        db: OpaquePointer,
        inCycleInsertStatement: OpaquePointer,
        inCycleSelectStatement: OpaquePointer,
        pluckJobSelect: OpaquePointer,
        pluckJobSelectID: OpaquePointer,
        insertJobStatement: OpaquePointer,
        selectSessionStatement: OpaquePointer,
        selectSessionCountStatement: OpaquePointer,
        updateSessionCount: OpaquePointer,
        updateSessionError: OpaquePointer,
        insertSession: OpaquePointer
    ) {
        self.db = db
        self.inCycleInsertStatement = inCycleInsertStatement
        self.inCycleSelectStatement = inCycleSelectStatement
        self.pluckJobSelect = pluckJobSelect
        self.pluckJobSelectID = pluckJobSelectID
        self.insertJobStatement = insertJobStatement
        self.selectSessionStatement = selectSessionStatement
        self.selectSessionCountStatement = selectSessionCountStatement
        self.updateSessionCount = updateSessionCount
        self.updateSessionError = updateSessionError
        self.insertSession = insertSession
    }

    @discardableResult
    func addJob(data: JobData) throws -> UUID {
        let job = try self.job(forData: data)
        try self.addJob(job: job)
        return job.id
    }

    func addJob(job: Job) throws {
        if let session = job.session {
            guard let currentCount = try self.sessionCount(id: session) else {
                throw SQLiteError.corruptDatabase
            }
            try self.updateSessionCount(id: session, count: currentCount + 1)
        }
        self.currentJobs.append(job.id)
    }

    func error(session: UUID) throws -> ModelCheckerError? {
        guard let cStr = session.uuidString.cString(using: .utf8) else {
            throw ModelCheckerError.internalError
        }
        return try self.bind(data: cStr, statement: self.selectSessionStatement) {
            guard $1 == SQLITE_ROW else {
                throw SQLiteError.corruptDatabase
            }
            guard sqlite3_column_type(self.selectSessionStatement, 0) != SQLITE_NULL else {
                return nil
            }
            let data = Data(try String(statement: self.selectSessionStatement, offset: 0).utf8)
            return try self.decoder.decode(ModelCheckerError.self, from: data)
        }
    }

    func failSession(id: UUID, error: ModelCheckerError?) throws {
        try self.updateSessionError(id: id, error: error)
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
        let session = data.session?.uuidString
        if let session {
            guard let cStr = session.cString(using: .utf8) else {
                throw ModelCheckerError.internalError
            }
            strings.append(cStr)
            parameters.append(20)
        } else {
            try exec { sqlite3_bind_null(self.inCycleSelectStatement, 20) }
        }
        let sessionRevisit = data.sessionRevisit?.uuidString
        if let sessionRevisit {
            guard let cStr = sessionRevisit.cString(using: .utf8) else {
                throw ModelCheckerError.internalError
            }
            strings.append(cStr)
            parameters.append(21)
        } else {
            try exec { sqlite3_bind_null(self.inCycleSelectStatement, 21) }
        }
        try exec {
            sqlite3_bind_int64(self.inCycleSelectStatement, 8, Int64(clamping: job.cost.time.coefficient))
        }
        try exec {
            sqlite3_bind_int64(self.inCycleSelectStatement, 9, Int64(job.cost.time.exponent))
        }
        try exec {
            sqlite3_bind_int64(self.inCycleSelectStatement, 10, Int64(clamping: job.cost.energy.coefficient))
        }
        try exec {
            sqlite3_bind_int64(self.inCycleSelectStatement, 11, Int64(job.cost.energy.exponent))
        }
        try exec {
            sqlite3_bind_int64(self.inCycleSelectStatement, 12, Int64(clamping: job.timeMinimum.coefficient))
        }
        try exec {
            sqlite3_bind_int64(self.inCycleSelectStatement, 13, Int64(job.timeMinimum.exponent))
        }
        try exec {
            sqlite3_bind_int64(self.inCycleSelectStatement, 14, Int64(clamping: job.timeMaximum.coefficient))
        }
        try exec {
            sqlite3_bind_int64(self.inCycleSelectStatement, 15, Int64(job.timeMaximum.exponent))
        }
        try exec {
            sqlite3_bind_int64(
                self.inCycleSelectStatement, 16, Int64(clamping: job.energyMinimum.coefficient)
            )
        }
        try exec {
            sqlite3_bind_int64(self.inCycleSelectStatement, 17, Int64(job.energyMinimum.exponent))
        }
        try exec {
            sqlite3_bind_int64(
                self.inCycleSelectStatement, 18, Int64(clamping: job.energyMaximum.coefficient)
            )
        }
        try exec {
            sqlite3_bind_int64(self.inCycleSelectStatement, 19, Int64(job.energyMaximum.exponent))
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
            if let session {
                guard let cStr = session.cString(using: .utf8) else {
                    throw ModelCheckerError.internalError
                }
                insertStrings.append(cStr)
                insertParameters.append(20)
            } else {
                try exec { sqlite3_bind_null(self.inCycleInsertStatement, 20) }
            }
            if let sessionRevisit {
                guard let cStr = sessionRevisit.cString(using: .utf8) else {
                    throw ModelCheckerError.internalError
                }
                insertStrings.append(cStr)
                insertParameters.append(21)
            } else {
                try exec { sqlite3_bind_null(self.inCycleInsertStatement, 21) }
            }
            try exec {
                sqlite3_bind_int64(self.inCycleInsertStatement, 8, Int64(clamping: job.cost.time.coefficient))
            }
            try exec {
                sqlite3_bind_int64(self.inCycleInsertStatement, 9, Int64(job.cost.time.exponent))
            }
            try exec {
                sqlite3_bind_int64(
                    self.inCycleInsertStatement, 10, Int64(clamping: job.cost.energy.coefficient)
                )
            }
            try exec {
                sqlite3_bind_int64(self.inCycleInsertStatement, 11, Int64(job.cost.energy.exponent))
            }
            try exec {
                sqlite3_bind_int64(
                    self.inCycleInsertStatement, 12, Int64(clamping: job.timeMinimum.coefficient)
                )
            }
            try exec {
                sqlite3_bind_int64(self.inCycleInsertStatement, 13, Int64(job.timeMinimum.exponent))
            }
            try exec {
                sqlite3_bind_int64(
                    self.inCycleInsertStatement, 14, Int64(clamping: job.timeMaximum.coefficient)
                )
            }
            try exec {
                sqlite3_bind_int64(self.inCycleInsertStatement, 15, Int64(job.timeMaximum.exponent))
            }
            try exec {
                sqlite3_bind_int64(
                    self.inCycleInsertStatement, 16, Int64(clamping: job.energyMinimum.coefficient)
                )
            }
            try exec {
                sqlite3_bind_int64(self.inCycleInsertStatement, 17, Int64(job.energyMinimum.exponent))
            }
            try exec {
                sqlite3_bind_int64(
                    self.inCycleInsertStatement, 18, Int64(clamping: job.energyMaximum.coefficient)
                )
            }
            try exec {
                sqlite3_bind_int64(self.inCycleInsertStatement, 19, Int64(job.energyMaximum.exponent))
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

    func isComplete(session: UUID) throws -> Bool {
        guard let cStr = session.uuidString.cString(using: .utf8) else {
            throw ModelCheckerError.internalError
        }
        return try self.bind(data: cStr, statement: self.selectSessionCountStatement) {
            guard $1 == SQLITE_ROW else {
                throw SQLiteError.corruptDatabase
            }
            return sqlite3_column_int64(self.selectSessionCountStatement, 0) == 0
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
        let costTimeCoefficient = sqlite3_column_int64(statement, 9)
        let costTimeExponent = sqlite3_column_int64(statement, 10)
        let costEnergyCoefficient = sqlite3_column_int64(statement, 11)
        let costEnergyExponent = sqlite3_column_int64(statement, 12)
        let costTime = try ScientificQuantity(
            sqliteCoefficient: costTimeCoefficient, sqliteExponent: costTimeExponent
        )
        let costEnergy = try ScientificQuantity(
            sqliteCoefficient: costEnergyCoefficient, sqliteExponent: costEnergyExponent
        )
        let cost = Cost(time: costTime, energy: costEnergy)
        let timeMinimumCoefficient = sqlite3_column_int64(statement, 13)
        let timeMinimumExponent = sqlite3_column_int64(statement, 14)
        let timeMaximumCoefficient = sqlite3_column_int64(statement, 15)
        let timeMaximumExponent = sqlite3_column_int64(statement, 16)
        let energyMinimumCoefficient = sqlite3_column_int64(statement, 17)
        let energyMinimumExponent = sqlite3_column_int64(statement, 18)
        let energyMaximumCoefficient = sqlite3_column_int64(statement, 19)
        let energyMaximumExponent = sqlite3_column_int64(statement, 20)
        let data = JobData(
            nodeId: nodeId,
            expression: self.expressions[expressionIndex],
            history: Set(history),
            currentBranch: currentBranch,
            historyExpression: historyExpression,
            constraints: Array(self.constraints[constraintsIndex]),
            successRevisit: successRevisit,
            failRevisit: failRevisit,
            session: nil,
            sessionRevisit: nil,
            cost: cost,
            timeMinimum: try ScientificQuantity(
                sqliteCoefficient: timeMinimumCoefficient, sqliteExponent: timeMinimumExponent
            ),
            timeMaximum: try ScientificQuantity(
                sqliteCoefficient: timeMaximumCoefficient, sqliteExponent: timeMaximumExponent
            ),
            energyMinimum: try ScientificQuantity(
                sqliteCoefficient: energyMinimumCoefficient, sqliteExponent: energyMinimumExponent
            ),
            energyMaximum: try ScientificQuantity(
                sqliteCoefficient: energyMaximumCoefficient, sqliteExponent: energyMaximumExponent
            )
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
                fail_revisit VARCHAR(36),
                current_time_coefficient INTEGER NOT NULL,
                current_time_exponent INTEGER NOT NULL,
                current_energy_coefficient INTEGER NOT NULL,
                current_energy_exponent INTEGER NOT NULL,
                time_minimum_coefficient INTEGER NOT NULL,
                time_minimum_exponent INTEGER NOT NULL,
                time_maximum_coefficient INTEGER NOT NULL,
                time_maximum_exponent INTEGER NOT NULL,
                energy_minimum_coefficient INTEGER NOT NULL,
                energy_minimum_exponent INTEGER NOT NULL,
                energy_maximum_coefficient INTEGER NOT NULL,
                energy_maximum_exponent INTEGER NOT NULL,
                session VARCHAR(36),
                session_revisit VARCHAR(36)
            );
            """,
            """
            CREATE UNIQUE INDEX IF NOT EXISTS job_data_index ON jobs(
                node_id, expression, history, current_branch, history_expression, constraints,
                success_revisit, fail_revisit, current_time_coefficient, current_time_exponent,
                current_energy_coefficient, current_energy_exponent, time_minimum_coefficient,
                time_minimum_exponent, time_maximum_coefficient, time_maximum_exponent,
                energy_minimum_coefficient, energy_minimum_exponent, energy_maximum_coefficient,
                energy_maximum_exponent, session, session_revisit
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
                current_time_coefficient INTEGER NOT NULL,
                current_time_exponent INTEGER NOT NULL,
                current_energy_coefficient INTEGER NOT NULL,
                current_energy_exponent INTEGER NOT NULL,
                time_minimum_coefficient INTEGER NOT NULL,
                time_minimum_exponent INTEGER NOT NULL,
                time_maximum_coefficient INTEGER NOT NULL,
                time_maximum_exponent INTEGER NOT NULL,
                energy_minimum_coefficient INTEGER NOT NULL,
                energy_minimum_exponent INTEGER NOT NULL,
                energy_maximum_coefficient INTEGER NOT NULL,
                energy_maximum_exponent INTEGER NOT NULL,
                session VARCHAR(36),
                session_revisit VARCHAR(36),
                PRIMARY KEY (
                    node_id, expression, in_cycle, history_expression, constraints, success_revisit,
                    fail_revisit, current_time_coefficient, current_time_exponent,
                    current_energy_coefficient, current_energy_exponent, time_minimum_coefficient,
                    time_minimum_exponent, time_maximum_coefficient, time_maximum_exponent,
                    energy_minimum_coefficient, energy_minimum_exponent, energy_maximum_coefficient,
                    energy_maximum_exponent, session, session_revisit
                )
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS sessions(
                id VARCHAR(36) PRIMARY KEY,
                count INTEGER NOT NULL,
                error TEXT
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
        DROP TABLE IF EXISTS sessions;
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
        try exec { sqlite3_finalize(self.selectSessionStatement) }
        try exec { sqlite3_finalize(self.selectSessionCountStatement) }
        try exec { sqlite3_finalize(self.updateSessionCount) }
        try exec { sqlite3_finalize(self.updateSessionError) }
        try exec { sqlite3_finalize(self.insertSession) }
    }

    private func getConstraints(constraint: Set<ConstrainedStatement>) -> Int {
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
            sqlite3_bind_int(
                self.insertJobStatement, 7, Int32(getConstraints(constraint: Set(data.constraints)))
            )
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
        if let session = data.session?.uuidString {
            guard let cStr = session.cString(using: .utf8) else {
                throw ModelCheckerError.internalError
            }
            strings.append(cStr)
            parameters.append(22)
        } else {
            try exec { sqlite3_bind_null(self.insertJobStatement, 22) }
        }
        if let sessionRevisit = data.sessionRevisit?.uuidString {
            guard let cStr = sessionRevisit.cString(using: .utf8) else {
                throw ModelCheckerError.internalError
            }
            strings.append(cStr)
            parameters.append(23)
        } else {
            try exec { sqlite3_bind_null(self.insertJobStatement, 23) }
        }
        try exec {
            sqlite3_bind_int64(self.insertJobStatement, 10, Int64(clamping: data.cost.time.coefficient))
        }
        try exec {
            sqlite3_bind_int64(self.insertJobStatement, 11, Int64(data.cost.time.exponent))
        }
        try exec {
            sqlite3_bind_int64(
                self.insertJobStatement, 12, Int64(clamping: data.cost.energy.coefficient)
            )
        }
        try exec {
            sqlite3_bind_int64(self.insertJobStatement, 13, Int64(data.cost.energy.exponent))
        }
        try exec {
            sqlite3_bind_int64(
                self.insertJobStatement, 14, Int64(clamping: data.timeMinimum.coefficient)
            )
        }
        try exec {
            sqlite3_bind_int64(self.insertJobStatement, 15, Int64(data.timeMinimum.exponent))
        }
        try exec {
            sqlite3_bind_int64(
                self.insertJobStatement, 16, Int64(clamping: data.timeMaximum.coefficient)
            )
        }
        try exec {
            sqlite3_bind_int64(self.insertJobStatement, 17, Int64(data.timeMaximum.exponent))
        }
        try exec {
            sqlite3_bind_int64(
                self.insertJobStatement, 18, Int64(clamping: data.energyMinimum.coefficient)
            )
        }
        try exec {
            sqlite3_bind_int64(self.insertJobStatement, 19, Int64(data.energyMinimum.exponent))
        }
        try exec {
            sqlite3_bind_int64(
                self.insertJobStatement, 20, Int64(clamping: data.energyMaximum.coefficient)
            )
        }
        try exec {
            sqlite3_bind_int64(self.insertJobStatement, 21, Int64(data.energyMaximum.exponent))
        }
        try self.bind(data: strings, parameters: parameters, statement: self.insertJobStatement) {
            guard $1 == SQLITE_DONE else {
                throw SQLiteError.cDriverError(errno: $1, message: self.errorMessage)
            }
            guard let session = data.session, try self.sessionCount(id: session) == nil else {
                return
            }
            try self.insertSession(id: session, count: 0, error: nil)
        }
        return id
    }

    private func insertSession(id: UUID, count: Int, error: ModelCheckerError?) throws {
        guard let cStr = id.uuidString.cString(using: .utf8) else {
            throw ModelCheckerError.internalError
        }
        var strings = [cStr]
        var parameters: [Int32] = [1]
        if let error {
            let data = try encoder.encode(error)
            let jsonString = String(decoding: data, as: UTF8.self)
            guard let jsonCStr = jsonString.cString(using: .utf8) else {
                throw ModelCheckerError.internalError
            }
            strings.append(jsonCStr)
            parameters.append(3)
        } else {
            try exec { sqlite3_bind_null(self.insertSession, 3) }
        }
        try exec { sqlite3_bind_int64(self.insertSession, 2, Int64(count)) }
        try self.bind(data: strings, parameters: parameters, statement: self.insertSession) {
            guard $1 == SQLITE_DONE else {
                throw SQLiteError.cDriverError(errno: $1, message: self.errorMessage)
            }
        }
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
            sqlite3_bind_int(self.pluckJobSelect, 6, Int32(getConstraints(constraint: Set(data.constraints))))
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
        if let session = data.session?.uuidString {
            guard let cStr = session.cString(using: .utf8) else {
                throw ModelCheckerError.internalError
            }
            strings.append(cStr)
            parameters.append(21)
        } else {
            try exec { sqlite3_bind_null(self.pluckJobSelect, 21) }
        }
        if let sessionRevisit = data.sessionRevisit?.uuidString {
            guard let cStr = sessionRevisit.cString(using: .utf8) else {
                throw ModelCheckerError.internalError
            }
            strings.append(cStr)
            parameters.append(22)
        } else {
            try exec { sqlite3_bind_null(self.pluckJobSelect, 22) }
        }
        try exec {
            sqlite3_bind_int64(self.pluckJobSelect, 9, Int64(clamping: data.cost.time.coefficient))
        }
        try exec {
            sqlite3_bind_int64(self.pluckJobSelect, 10, Int64(data.cost.time.exponent))
        }
        try exec {
            sqlite3_bind_int64(
                self.pluckJobSelect, 11, Int64(clamping: data.cost.energy.coefficient)
            )
        }
        try exec {
            sqlite3_bind_int64(self.pluckJobSelect, 12, Int64(data.cost.energy.exponent))
        }
        try exec {
            sqlite3_bind_int64(
                self.pluckJobSelect, 13, Int64(clamping: data.timeMinimum.coefficient)
            )
        }
        try exec {
            sqlite3_bind_int64(self.pluckJobSelect, 14, Int64(data.timeMinimum.exponent))
        }
        try exec {
            sqlite3_bind_int64(
                self.pluckJobSelect, 15, Int64(clamping: data.timeMaximum.coefficient)
            )
        }
        try exec {
            sqlite3_bind_int64(self.pluckJobSelect, 16, Int64(data.timeMaximum.exponent))
        }
        try exec {
            sqlite3_bind_int64(
                self.pluckJobSelect, 17, Int64(clamping: data.energyMinimum.coefficient)
            )
        }
        try exec {
            sqlite3_bind_int64(self.pluckJobSelect, 18, Int64(data.energyMinimum.exponent))
        }
        try exec {
            sqlite3_bind_int64(
                self.pluckJobSelect, 19, Int64(clamping: data.energyMaximum.coefficient)
            )
        }
        try exec {
            sqlite3_bind_int64(self.pluckJobSelect, 20, Int64(data.energyMaximum.exponent))
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
            let costTimeCoefficient = sqlite3_column_int64($0, 9)
            let costTimeExponent = sqlite3_column_int64($0, 10)
            let costEnergyCoefficient = sqlite3_column_int64($0, 11)
            let costEnergyExponent = sqlite3_column_int64($0, 12)
            let costTime = try ScientificQuantity(
                sqliteCoefficient: costTimeCoefficient, sqliteExponent: costTimeExponent
            )
            let costEnergy = try ScientificQuantity(
                sqliteCoefficient: costEnergyCoefficient, sqliteExponent: costEnergyExponent
            )
            let cost = Cost(time: costTime, energy: costEnergy)
            let timeMinimumCoefficient = sqlite3_column_int64($0, 13)
            let timeMinimumExponent = sqlite3_column_int64($0, 14)
            let timeMaximumCoefficient = sqlite3_column_int64($0, 15)
            let timeMaximumExponent = sqlite3_column_int64($0, 16)
            let energyMinimumCoefficient = sqlite3_column_int64($0, 17)
            let energyMinimumExponent = sqlite3_column_int64($0, 18)
            let energyMaximumCoefficient = sqlite3_column_int64($0, 19)
            let energyMaximumExponent = sqlite3_column_int64($0, 20)
            let session = sqlite3_column_type($0, 21) != SQLITE_NULL
                ? try UUID(statement: $0, offset: 21) : nil
            let sessionRevisit = sqlite3_column_type($0, 22) != SQLITE_NULL
                ? try UUID(statement: $0, offset: 22) : nil
            let data = JobData(
                nodeId: nodeId,
                expression: self.expressions[expressionIndex],
                history: Set(history),
                currentBranch: currentBranch,
                historyExpression: historyExpression,
                constraints: Array(self.constraints[constraintsIndex]),
                successRevisit: successRevisit,
                failRevisit: failRevisit,
                session: session,
                sessionRevisit: sessionRevisit,
                cost: cost,
                timeMinimum: try ScientificQuantity(
                    sqliteCoefficient: timeMinimumCoefficient, sqliteExponent: timeMinimumExponent
                ),
                timeMaximum: try ScientificQuantity(
                    sqliteCoefficient: timeMaximumCoefficient, sqliteExponent: timeMaximumExponent
                ),
                energyMinimum: try ScientificQuantity(
                    sqliteCoefficient: energyMinimumCoefficient, sqliteExponent: energyMinimumExponent
                ),
                energyMaximum: try ScientificQuantity(
                    sqliteCoefficient: energyMaximumCoefficient, sqliteExponent: energyMaximumExponent
                )
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
                fail_revisit, current_time_coefficient, current_time_exponent,
                current_energy_coefficient, current_energy_exponent, time_minimum_coefficient,
                time_minimum_exponent, time_maximum_coefficient, time_maximum_exponent,
                energy_minimum_coefficient, energy_minimum_exponent, energy_maximum_coefficient,
                energy_maximum_exponent
            ) VALUES(
                ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19
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
                fail_revisit = ?7 AND
                current_time_coefficient = ?8 AND
                current_time_exponent = ?9 AND
                current_energy_coefficient = ?10 AND
                current_energy_exponent = ?11 AND
                time_minimum_coefficient = ?12 AND
                time_minimum_exponent = ?13 AND
                time_maximum_coefficient = ?14 AND
                time_maximum_exponent = ?15 AND
                energy_minimum_coefficient = ?16 AND
                energy_minimum_exponent = ?17 AND
                energy_maximum_coefficient = ?18 AND
                energy_maximum_exponent = ?19 AND
                session = ?20 AND
                session_revisit = ?21;
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
                fail_revisit = ?8 AND
                current_time_coefficient = ?9 AND
                current_time_exponent = ?10 AND
                current_energy_coefficient = ?11 AND
                current_energy_exponent = ?12 AND
                time_minimum_coefficient = ?13 AND
                time_minimum_exponent = ?14 AND
                time_maximum_coefficient = ?15 AND
                time_maximum_exponent = ?16 AND
                energy_minimum_coefficient = ?17 AND
                energy_minimum_exponent = ?18 AND
                energy_maximum_coefficient = ?19 AND
                energy_maximum_exponent = ?20 AND
                session = ?21 AND
                session_revisit = ?22;
            """
        )
        self.pluckJobSelectID = try OpaquePointer(db: self.db, query: "SELECT * FROM jobs WHERE id = ?1;")
        self.insertJobStatement = try OpaquePointer(
            db: db,
            query: """
            INSERT INTO jobs(
                id, node_id, expression, history, current_branch, history_expression, constraints,
                success_revisit, fail_revisit, current_time_coefficient, current_time_exponent,
                current_energy_coefficient, current_energy_exponent, time_minimum_coefficient,
                time_minimum_exponent, time_maximum_coefficient, time_maximum_exponent,
                energy_minimum_coefficient, energy_minimum_exponent, energy_maximum_coefficient,
                energy_maximum_exponent, session, session_revisit
            ) VALUES(
                ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20,
                ?21, ?22, ?23
            );
            """
        )
        self.selectSessionStatement = try OpaquePointer(
            db: db,
            query: "SELECT error FROM failed_sessions where id = ?1;"
        )
        self.selectSessionCountStatement = try OpaquePointer(
            db: db,
            query: "SELECT count FROM sessions where id = ?1;"
        )
        self.updateSessionCount = try OpaquePointer(
            db: db, query: "UPDATE sessions SET count = ?1 WHERE id = ?2;"
        )
        self.updateSessionError = try OpaquePointer(
            db: db, query: "UPDATE sessions SET error = ?1 WHERE id = ?2;"
        )
        self.insertSession = try OpaquePointer(
            db: db, query: "INSERT INTO sessions(id, count, error) VALUES(?1, ?2, ?3);"
        )
    }

    private func sessionCount(id: UUID) throws -> Int? {
        guard let cStr = id.uuidString.cString(using: .utf8) else {
            throw ModelCheckerError.internalError
        }
        return try self.bind(data: cStr, statement: self.selectSessionCountStatement) {
            guard $1 == SQLITE_ROW else {
                return nil
            }
            return Int(sqlite3_column_int64(self.selectSessionCountStatement, 0))
        }
    }

    private func updateSessionCount(id: UUID, count: Int) throws {
        guard let cStr = id.uuidString.cString(using: .utf8) else {
            throw ModelCheckerError.internalError
        }
        try self.bind(data: cStr, statement: self.selectSessionCountStatement) {
            guard $1 == SQLITE_ROW else {
                throw SQLiteError.corruptDatabase
            }
            let currentCount = sqlite3_column_int64(self.selectSessionCountStatement, 0)
            let newCount = Int64(count)
            guard newCount != currentCount else {
                return
            }
            try exec { sqlite3_bind_int64(self.updateSessionCount, 1, newCount) }
            try self.bind(data: cStr, offsets: [0], parameters: [2], statement: self.updateSessionCount) {
                guard $1 == SQLITE_DONE else {
                    throw SQLiteError.cDriverError(errno: $1, message: self.errorMessage)
                }
            }
        }
    }

    private func updateSessionError(id: UUID, error: ModelCheckerError?) throws {
        guard let cStr = id.uuidString.cString(using: .utf8) else {
            throw ModelCheckerError.internalError
        }
        try self.bind(data: cStr, statement: self.selectSessionStatement) {
            guard $1 == SQLITE_ROW else {
                // try self.insertSession(id: id, count: 1, error: error)
                // return
                throw SQLiteError.corruptDatabase
            }
            var strings = [cStr]
            var parameters: [Int32] = [2]
            switch (error, sqlite3_column_type(self.selectSessionStatement, 0)) {
            case (nil, SQLITE_NULL):
                return
            case (nil, SQLITE_TEXT):
                try exec { sqlite3_bind_null(self.updateSessionError, 1) }
            case (.some(let lhs), SQLITE_NULL):
                let data = try encoder.encode(lhs)
                let jsonString = String(decoding: data, as: UTF8.self)
                guard let jsonCStr = jsonString.cString(using: .utf8) else {
                    throw ModelCheckerError.internalError
                }
                strings.append(jsonCStr)
                parameters.append(1)
            case (.some(let lhs), SQLITE_TEXT):
                let columnString = Data(try String(statement: self.selectSessionStatement, offset: 0).utf8)
                let columnValue = try self.decoder.decode(ModelCheckerError.self, from: columnString)
                guard lhs != columnValue else {
                    return
                }
                let data = try encoder.encode(lhs)
                let jsonString = String(decoding: data, as: UTF8.self)
                guard let jsonCStr = jsonString.cString(using: .utf8) else {
                    throw ModelCheckerError.internalError
                }
                strings.append(jsonCStr)
                parameters.append(1)
            default:
                throw SQLiteError.corruptDatabase
            }
            try self.bind(data: strings, parameters: parameters, statement: self.updateSessionError) {
                guard $1 == SQLITE_DONE else {
                    throw SQLiteError.cDriverError(errno: $1, message: self.errorMessage)
                }
            }
        }
    }

    deinit {
        _ = sqlite3_finalize(self.inCycleInsertStatement)
        _ = sqlite3_finalize(self.inCycleSelectStatement)
        _ = sqlite3_finalize(self.pluckJobSelect)
        _ = sqlite3_finalize(self.pluckJobSelectID)
        _ = sqlite3_finalize(self.insertJobStatement)
        _ = sqlite3_finalize(self.selectSessionStatement)
        _ = sqlite3_finalize(self.selectSessionCountStatement)
        _ = sqlite3_finalize(self.updateSessionCount)
        _ = sqlite3_finalize(self.updateSessionError)
        _ = sqlite3_finalize(self.insertSession)
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

private extension ScientificQuantity {

    init(sqliteCoefficient coefficient: Int64, sqliteExponent exponent: Int64) throws {
        guard coefficient >= 0 else {
            throw SQLiteError.corruptDatabase
        }
        guard (coefficient == Int64(clamping: UInt.max)) && exponent == .max else {
            self.init(coefficient: UInt(coefficient), exponent: Int(exponent))
            return
        }
        self = .max
    }

}
