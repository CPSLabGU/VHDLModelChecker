// ModelChecker.swift
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

final class Job: Equatable, Hashable {
    var nodeId: UUID
    var node: KripkeNode
    var expression: Expression
    var ignoreFailure: Bool
    var history: Set<UUID>
    var revisits: [Revisit]

    init(
        nodeId: UUID,
        node: KripkeNode,
        expression: Expression,
        ignoreFailure: Bool,
        history: Set<UUID>,
        revisits: [Revisit]
    ) {
        self.nodeId = nodeId
        self.node = node
        self.expression = expression
        self.ignoreFailure = ignoreFailure
        self.history = history
        self.revisits = revisits
    }

    static func == (lhs: Job, rhs: Job) -> Bool {
        lhs.nodeId == rhs.nodeId
            && lhs.node == rhs.node
            && lhs.expression == rhs.expression
            && lhs.ignoreFailure == rhs.ignoreFailure
            && lhs.history == rhs.history
            && lhs.revisits == rhs.revisits
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(nodeId)
        hasher.combine(node)
        hasher.combine(expression)
        hasher.combine(ignoreFailure)
        hasher.combine(history)
        hasher.combine(revisits)
    }

}

final class Revisit: Equatable, Hashable {
    var nodeId: UUID
    var node: KripkeNode
    var expression: Expression

    init(nodeId: UUID, node: KripkeNode, expression: Expression) {
        self.nodeId = nodeId
        self.node = node
        self.expression = expression
    }

    static func == (lhs: Revisit, rhs: Revisit) -> Bool {
        lhs.nodeId == rhs.nodeId
            && lhs.node == rhs.node
            && lhs.expression == rhs.expression
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(nodeId)
        hasher.combine(node)
        hasher.combine(expression)
    }

}

extension KripkeStructureIterator {
    var initialNodes: [(UUID, KripkeNode)] {
        []
    }
}

final class ModelChecker {

    var jobs: [Job] = []

    var cycles: Set<Job> = []

    init() {}

    func check(structure: KripkeStructureIterator, specification: Specification) throws {
        for (id, initialNode) in structure.initialNodes {
            for expression in specification.requirements {
                let job = Job(
                    nodeId: id,
                    node: initialNode,
                    expression: .quantified(expression: expression),
                    ignoreFailure: false,
                    history: [],
                    revisits: []
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
        let results: [VerifyStatus]
        do {
            results = try job.expression.verify(
                currentNode: job.node,
                inCycle: job.history.contains(job.nodeId)
            )
        } catch let error as VerificationError {
            if job.ignoreFailure {
                return
            }
            throw error
        } catch let error {
            throw error
        }
        let successors = structure.edges[job.nodeId]?.compactMap { edge in
            structure.nodes[edge.destination].map { (edge.destination, $0) }
        } ?? []
        for result in results {
            switch result {
            case .completed:
                job.revisits.forEach {
                    self.jobs.append(Job(
                        nodeId: $0.nodeId,
                        node: $0.node,
                        expression: $0.expression,
                        ignoreFailure: false,
                        history: job.history.union([job.nodeId]),
                        revisits: []
                    ))
                }
            case .successor(let expression):
                self.jobs.append(contentsOf: successors.map { nodeId, node in
                    Job(
                        nodeId: nodeId,
                        node: node,
                        expression: expression,
                        ignoreFailure: job.ignoreFailure,
                        history: job.history.union([job.nodeId]),
                        revisits: job.revisits
                    )
                })
            case .revisitting(let expression, let successorExpressions):
                self.jobs.append(contentsOf: successors.flatMap { nodeId, node in
                    successorExpressions.map {
                        Job(
                            nodeId: nodeId,
                            node: node,
                            expression: $0.expression,
                            ignoreFailure: !$0.isRequired,
                            history: job.history.union([job.nodeId]),
                            revisits: job.revisits + [
                                Revisit(
                                    nodeId: nodeId,
                                    node: node,
                                    expression: expression
                                )
                            ]
                        )
                    }
                })
            }
        }
    }

}



