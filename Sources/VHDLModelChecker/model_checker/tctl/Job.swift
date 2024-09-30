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

// swiftlint:disable type_name

/// A `TCTL` job to process in a model checker.
final class Job: Equatable, Hashable, Identifiable {

// swiftlint:enable type_name

    /// The ID of the job.
    let id: UUID

    /// The data contained within the job.
    let data: JobData
    // var allSessionIds: SessionIdStore

    /// The cycle data.
    var cycleData: CycleData {
        data.cycleData
    }

    /// The node ID.
    var nodeId: UUID {
        data.nodeId
    }

    /// The expression.
    var expression: TCTLParser.Expression {
        data.expression
    }

    /// The history of the job.
    var history: Set<UUID> {
        data.history
    }

    /// The current branch.
    var currentBranch: [UUID] {
        data.currentBranch
    }

    /// The history expression.
    var historyExpression: TCTLParser.Expression? {
        data.historyExpression
    }

    /// The job to revisit on success.
    var successRevisit: UUID? {
        data.successRevisit
    }

    /// The job to revisit on failure.
    var failRevisit: UUID? {
        data.failRevisit
    }

    /// The session ID.
    var session: UUID? {
        data.session
    }

    /// The session to revisit.
    var sessionRevisit: UUID? {
        data.sessionRevisit
    }

    /// The window of valid successors.
    var window: ConstrainedWindow? {
        data.window
    }

    /// Whether the job is within a constrained window.
    var isAboveWindow: Bool {
        data.isAboveWindow
    }

    /// Whether the job is below a constrained window.
    var isBelowWindow: Bool {
        data.isBelowWindow
    }

    /// Initialise a new job from it's data.
    convenience init(
        id: UUID,
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
        self.init(
            id: id,
            data: JobData(
                nodeId: nodeId,
                expression: expression,
                history: history,
                currentBranch: currentBranch,
                historyExpression: historyExpression,
                successRevisit: successRevisit,
                failRevisit: failRevisit,
                session: session,
                sessionRevisit: sessionRevisit,
                window: window
            )
        )
    }

    /// Initialise a new job.
    init(id: UUID, data: JobData) {
        self.id = id
        self.data = data
    }

    /// Equatable conformance.
    static func == (lhs: Job, rhs: Job) -> Bool {
        lhs.id == rhs.id && lhs.data == rhs.data
    }

    /// Hashable conformance.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(data)
    }

}

/// Codable conformance.
extension Job: Codable {

    /// Coding keys.
    enum CodingKeys: CodingKey {

        /// The ID of the job.
        case id

        /// The data contained within the job.
        case data

    }

    /// Initialise a new job from a decoder.
    convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            data: try container.decode(JobData.self, forKey: .data)
        )
    }

    /// Encode the job.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(data, forKey: .data)
    }

}
