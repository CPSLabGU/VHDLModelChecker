// JobData.swift
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
import TCTLParser
import VHDLKripkeStructures

/// The data contained within a job.
final class JobData: Equatable, Hashable {

    /// The node ID.
    var nodeId: UUID

    /// The expression.
    var expression: TCTLParser.Expression

    /// The history of the job.
    var history: Set<UUID>

    /// The current branch.
    var currentBranch: [UUID]

    /// The history expression.
    var historyExpression: TCTLParser.Expression?

    /// The job to revisit on success.
    var successRevisit: UUID?

    /// The job to revisit on failure.
    var failRevisit: UUID?

    /// The session ID.
    var session: UUID?

    /// The session to revisit.
    var sessionRevisit: UUID?

    /// The window of valid successors.
    var window: ConstrainedWindow?
    // var allSessionIds: SessionIdStore

    /// The cycle data for the job.
    var cycleData: CycleData {
        CycleData(
            nodeId: nodeId,
            expression: expression,
            inCycle: history.contains(nodeId),
            historyExpression: historyExpression,
            successRevisit: successRevisit,
            failRevisit: failRevisit,
            session: session,
            sessionRevisit: sessionRevisit,
            window: window
        )
    }

    /// Whether the job is within a constrained window.
    var isAboveWindow: Bool {
        self.window?.isAboveWindow ?? false
    }

    /// Whether the job is below a constrained window.
    var isBelowWindow: Bool {
        self.window?.isBelowWindow ?? false
    }

    /// Initialise a new job data.
    init(
        nodeId: UUID,
        expression: TCTLParser.Expression,
        history: Set<UUID>,
        currentBranch: [UUID],
        historyExpression: TCTLParser.Expression?,
        successRevisit: UUID?,
        failRevisit: UUID?,
        session: UUID?,
        sessionRevisit: UUID?,
        window: ConstrainedWindow?
    ) {
        self.nodeId = nodeId
        self.expression = expression
        self.history = history
        self.currentBranch = currentBranch
        self.historyExpression = historyExpression
        self.successRevisit = successRevisit
        self.failRevisit = failRevisit
        self.session = session
        self.sessionRevisit = sessionRevisit
        self.window = window
    }

    /// Equality conformance.
    static func == (lhs: JobData, rhs: JobData) -> Bool {
        lhs.nodeId == rhs.nodeId
            && lhs.expression == rhs.expression
            && lhs.history == rhs.history
            && lhs.currentBranch == rhs.currentBranch
            && lhs.historyExpression == rhs.historyExpression
            && lhs.successRevisit == rhs.successRevisit
            && lhs.failRevisit == rhs.failRevisit
            && lhs.session == rhs.session
            && lhs.sessionRevisit == rhs.sessionRevisit
            && lhs.window == rhs.window
    }

    /// Hash conformance.
    func hash(into hasher: inout Hasher) {
        hasher.combine(nodeId)
        hasher.combine(expression)
        hasher.combine(history)
        hasher.combine(currentBranch)
        hasher.combine(historyExpression)
        hasher.combine(successRevisit)
        hasher.combine(failRevisit)
        hasher.combine(session)
        hasher.combine(sessionRevisit)
        hasher.combine(window)
    }

}

/// Add `Codable` Conformance.
extension JobData: Codable {

    /// The coding keys.
    private enum CodingKeys: CodingKey {
        /// The node ID.
        case nodeId

        /// The expression.
        case expression

        /// The history of the job.
        case history

        /// The current branch.
        case currentBranch

        /// The history expression.
        case historyExpression

        /// The job to revisit on success.
        case successRevisit

        /// The job to revisit on failure.
        case failRevisit

        /// The session ID.
        case session

        /// The session to revisit.
        case sessionRevisit

        /// The window of valid successors.
        case window
    }

    /// Create from decoder.
    convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let expressionRawValue = try container.decode(String.self, forKey: .expression)
        guard let expression = Expression(rawValue: expressionRawValue) else {
            throw DecodingError.dataCorruptedError(
                forKey: .expression,
                in: container,
                debugDescription: "Invalid expression value"
            )
        }
        let historyExpression: TCTLParser.Expression?
        if let historyExpressionRawValue = try container.decode(String?.self, forKey: .historyExpression) {
            guard let historyExpressionConverted = Expression(rawValue: historyExpressionRawValue) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .historyExpression,
                    in: container,
                    debugDescription: "Invalid history expression value"
                )
            }
            historyExpression = historyExpressionConverted
        } else {
            historyExpression = nil
        }
        self.init(
            nodeId: try container.decode(UUID.self, forKey: .nodeId),
            expression: expression,
            history: Set(try container.decode([UUID].self, forKey: .history)),
            currentBranch: try container.decode([UUID].self, forKey: .currentBranch),
            historyExpression: historyExpression,
            successRevisit: try container.decode(UUID?.self, forKey: .successRevisit),
            failRevisit: try container.decode(UUID?.self, forKey: .failRevisit),
            session: try container.decode(UUID?.self, forKey: .session),
            sessionRevisit: try container.decode(UUID?.self, forKey: .sessionRevisit),
            window: try container.decode(ConstrainedWindow?.self, forKey: .window)
        )
    }

    /// Encode.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodeId, forKey: .nodeId)
        try container.encode(expression.rawValue, forKey: .expression)
        try container.encode(history.sorted { $0.uuidString < $1.uuidString }, forKey: .history)
        try container.encode(currentBranch, forKey: .currentBranch)
        try container.encode(historyExpression?.rawValue, forKey: .historyExpression)
        try container.encode(successRevisit, forKey: .successRevisit)
        try container.encode(failRevisit, forKey: .failRevisit)
        try container.encode(session, forKey: .session)
        try container.encode(sessionRevisit, forKey: .sessionRevisit)
        try container.encode(window, forKey: .window)
    }

}
