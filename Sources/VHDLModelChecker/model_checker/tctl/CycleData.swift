// CycleData.swift
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

/// The data in a job for detecting a cycle.
final class CycleData: Equatable, Hashable, Codable {

    /// The node id.
    var nodeId: UUID

    /// The expression to check.
    var expression: TCTLParser.Expression

    /// Whether the node is in a cycle.
    var inCycle: Bool

    /// The history expression.
    var historyExpression: TCTLParser.Expression?

    /// The job to revisit on success.
    var successRevisit: UUID?

    /// The job to revisit on failure.
    var failRevisit: UUID?

    /// The session id.
    var session: UUID?

    /// The session to revisit.
    var sessionRevisit: UUID?

    /// The window of valid successors.
    var window: ConstrainedWindow?

    /// Initialise a new cycle data.
    init(
        nodeId: UUID,
        expression: TCTLParser.Expression,
        inCycle: Bool,
        historyExpression: TCTLParser.Expression?,
        successRevisit: UUID?,
        failRevisit: UUID?,
        session: UUID?,
        sessionRevisit: UUID?,
        window: ConstrainedWindow?
    ) {
        self.nodeId = nodeId
        self.expression = expression
        self.inCycle = inCycle
        self.historyExpression = historyExpression
        self.successRevisit = successRevisit
        self.failRevisit = failRevisit
        self.session = session
        self.sessionRevisit = sessionRevisit
        self.window = window
    }

    /// Equality conformance.
    static func == (lhs: CycleData, rhs: CycleData) -> Bool {
        lhs.nodeId == rhs.nodeId
            && lhs.expression == rhs.expression
            && lhs.inCycle == rhs.inCycle
            && lhs.historyExpression == rhs.historyExpression
            && lhs.successRevisit == rhs.successRevisit
            && lhs.failRevisit == rhs.failRevisit
            && lhs.session == rhs.session
            && lhs.sessionRevisit == rhs.sessionRevisit
            && lhs.window == rhs.window
    }

    /// Hashable conformance.
    func hash(into hasher: inout Hasher) {
        hasher.combine(nodeId)
        hasher.combine(expression)
        hasher.combine(inCycle)
        hasher.combine(historyExpression)
        hasher.combine(successRevisit)
        hasher.combine(failRevisit)
        hasher.combine(session)
        hasher.combine(sessionRevisit)
        hasher.combine(window)
    }

}
