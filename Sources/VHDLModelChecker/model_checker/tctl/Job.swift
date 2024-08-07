// Job.swift
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

final class CycleData: Equatable, Hashable, Codable {

    var nodeId: UUID

    var expression: Expression

    var inCycle: Bool

    var historyExpression: Expression?

    var session: UUID?

    var constraints: [PhysicalConstraint]

    var successRevisit: UUID?

    var failRevisit: UUID?

    init(
        nodeId: UUID,
        expression: Expression,
        inCycle: Bool,
        historyExpression: Expression?,
        session: UUID?,
        constraints: [PhysicalConstraint],
        successRevisit: UUID?,
        failRevisit: UUID?
    ) {
        self.nodeId = nodeId
        self.expression = expression
        self.inCycle = inCycle
        self.historyExpression = historyExpression
        self.session = session
        self.constraints = constraints
        self.successRevisit = successRevisit
        self.failRevisit = failRevisit
    }

    static func == (lhs: CycleData, rhs: CycleData) -> Bool {
        lhs.nodeId == rhs.nodeId
            && lhs.expression == rhs.expression
            && lhs.inCycle == rhs.inCycle
            && lhs.historyExpression == rhs.historyExpression
            && lhs.session == rhs.session
            && lhs.constraints == rhs.constraints
            && lhs.successRevisit == rhs.successRevisit
            && lhs.failRevisit == rhs.failRevisit
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(nodeId)
        hasher.combine(expression)
        hasher.combine(inCycle)
        hasher.combine(historyExpression)
        hasher.combine(session)
        hasher.combine(constraints)
        hasher.combine(successRevisit)
        hasher.combine(failRevisit)
    }

}

final class Job: Equatable, Hashable, Codable {
    var nodeId: UUID
    var expression: Expression
    var history: Set<UUID>
    var currentBranch: [UUID]
    var inSession: Bool
    var historyExpression: Expression?
    var constraints: [PhysicalConstraint]
    var session: UUID?
    var successRevisit: UUID?
    var failRevisit: UUID?
    // var allSessionIds: SessionIdStore

    var cycleData: CycleData {
        CycleData(
            nodeId: nodeId,
            expression: expression,
            inCycle: history.contains(nodeId),
            historyExpression: historyExpression,
            session: session,
            constraints: constraints,
            successRevisit: successRevisit,
            failRevisit: failRevisit
        )
    }

    var sessionKey: SessionKey {
        SessionKey(nodeId: nodeId, expression: expression, constraints: constraints)
    }

    init(
        nodeId: UUID,
        expression: Expression,
        history: Set<UUID>,
        currentBranch: [UUID],
        inSession: Bool,
        historyExpression: Expression?,
        constraints: [PhysicalConstraint],
        session: UUID?,
        successRevisit: UUID?,
        failRevisit: UUID?
        // allSessionIds: SessionIdStore
    ) {
        self.nodeId = nodeId
        self.expression = expression
        self.history = history
        self.currentBranch = currentBranch
        self.inSession = inSession
        self.historyExpression = historyExpression
        self.constraints = constraints
        self.session = session
        self.successRevisit = successRevisit
        self.failRevisit = failRevisit
        // self.allSessionIds = allSessionIds
    }

    convenience init(revisit: Revisit) {
        self.init(
            nodeId: revisit.nodeId,
            expression: revisit.expression,
            history: revisit.history,
            currentBranch: revisit.currentBranch,
            inSession: revisit.inSession,
            historyExpression: revisit.historyExpression,
            constraints: revisit.constraints,
            session: revisit.session,
            successRevisit: revisit.successRevisit,
            failRevisit: revisit.failRevisit
            // allSessionIds: revisit.allSessionIds
        )
    }

    static func == (lhs: Job, rhs: Job) -> Bool {
        lhs.nodeId == rhs.nodeId
            && lhs.expression == rhs.expression
            && lhs.history == rhs.history
            && lhs.currentBranch == rhs.currentBranch
            && lhs.inSession == rhs.inSession
            && lhs.historyExpression == rhs.historyExpression
            && lhs.constraints == rhs.constraints
            && lhs.session == rhs.session
            && lhs.successRevisit == rhs.successRevisit
            && lhs.failRevisit == rhs.failRevisit
            // && lhs.allSessionIds == rhs.allSessionIds
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(nodeId)
        hasher.combine(expression)
        hasher.combine(history)
        hasher.combine(currentBranch)
        hasher.combine(inSession)
        hasher.combine(historyExpression)
        hasher.combine(constraints)
        hasher.combine(session)
        hasher.combine(successRevisit)
        hasher.combine(failRevisit)
        // hasher.combine(allSessionIds)
    }

}
