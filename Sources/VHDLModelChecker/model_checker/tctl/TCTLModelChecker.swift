// TCTLModelChecker.swift
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

final class TCTLModelChecker {

    var jobs: [Job] = []

    var cycles: Set<Job> = []

    init() {}

    func check(structure: KripkeStructureIterator, specification: Specification) throws {
        for id in structure.initialStates {
            for expression in specification.requirements {
                let job = Job(
                    nodeId: id,
                    expression: expression,
                    history: [],
                    cost: Cost(time: .zero, energy: .zero),
                    revisit: nil
                )
                try handleJob(job, structure: structure)
            }
        }
        while let job = jobs.popLast() {
            try handleJob(job, structure: structure)
        }
    }

    // swiftlint:disable:next function_body_length
    private func handleJob(_ job: Job, structure: KripkeStructureIterator) throws {
        if cycles.contains(job) {
            return
        }
        cycles.insert(job)
        guard let node = structure.nodes[job.nodeId] else {
            throw VerificationError.internalError
        }
        let results: [VerifyStatus]
        do {
            results = try job.expression.verify(
                currentNode: node,
                inCycle: job.history.contains(job.nodeId),
                cost: job.cost
            )
        } catch let error as VerificationError {
            guard let revisit = job.revisit else {
                throw error
            }
            switch revisit.type {
            case .required:
                throw error
            case .ignored:
                return
            case .skip:
                self.jobs.append(Job(revisit: revisit))
                return
            }
        } catch let error {
            throw error
        }
        guard !results.isEmpty else {
            guard let revisit = job.revisit else {
                return
            }
            switch revisit.type {
            case .skip:
                return
            case .ignored, .required:
                self.jobs.append(Job(revisit: revisit))
                return
            }
        }
        lazy var successors = structure.edges[job.nodeId] ?? []
        for result in results {
            switch result {
            case .successor(let expression):
                self.jobs.append(contentsOf: successors.map {
                    let nodeId = $0.destination
                    return Job(
                        nodeId: nodeId,
                        expression: expression,
                        history: job.history.union([job.nodeId]),
                        cost: job.cost + $0.cost,
                        revisit: job.revisit
                    )
                })
            case .revisitting(let expression, let revisit):
                self.jobs.append(contentsOf: successors.map {
                    let nodeId = $0.destination
                    let newRevisit = Revisit(
                        nodeId: job.nodeId,
                        expression: expression,
                        type: revisit.type,
                        cost: job.cost,
                        revisit: job.revisit,
                        history: job.history
                    )
                    return Job(
                        nodeId: nodeId,
                        expression: revisit.expression,
                        history: job.history.union([job.nodeId]),
                        cost: job.cost + $0.cost,
                        revisit: newRevisit
                    )
                })
            }
        }
    }

}
