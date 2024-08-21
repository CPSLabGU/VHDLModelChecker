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

// 1. Create initial jobs.
// 2. For current job, check if not in session ID and return if not there, otherwise forward.
// 3. Call verify.
// 4. Check results for 2 cases:
//    - Case 1: No new session ID. Handle as normal.
//    - Case 2: New Session ID. Create new session ID and assign to new jobs. Store new session ID in pending
//              sessions.
// 5. If no jobs left and no pending sessions, return, otherwise throw error.

final class TCTLModelChecker<T> where T: JobStorable {

    private var store: T

    private var debug = false

    init(store: T) {
        self.store = store
    }

    func check(structure: KripkeStructureIterator, specification: Specification) throws {
        try self.store.reset()
        for id in structure.initialStates {
            for expression in specification.requirements {
                let job = JobData(
                    nodeId: id,
                    expression: expression,
                    history: [],
                    currentBranch: [],
                    historyExpression: nil,
                    constraints: [],
                    successRevisit: nil,
                    failRevisit: nil
                )
                try self.store.addJob(data: job)
            }
        }
        while let jobId = try self.store.next {
            try handleJob(withId: jobId, structure: structure)
        }
    }

    // swiftlint:disable:next function_body_length
    private func handleJob(withId jobId: UUID, structure: KripkeStructureIterator) throws {
        let job = try self.store.job(withId: jobId)
        guard !(try store.inCycle(job)) else {
            return
        }
        guard let node = structure.nodes[job.nodeId] else {
            throw ModelCheckerError.internalError
        }
        if let historyExpression = job.expression.historyExpression, job.historyExpression != historyExpression {
            let newJob = JobData(
                nodeId: job.nodeId,
                expression: job.expression,
                history: [],
                currentBranch: [],
                historyExpression: historyExpression,
                constraints: job.constraints,
                successRevisit: job.successRevisit,
                failRevisit: job.failRevisit
            )
            try self.store.addJob(data: newJob)
            return
        }
        let results: [VerifyStatus]
        do {
            results = try job.expression.verify(currentNode: node, inCycle: job.history.contains(job.nodeId))
        } catch let error as VerificationError {
            try fail(structure: structure, job: job) {
                ModelCheckerError(
                    error: error, currentBranch: $0, expression: job.expression, base: job.historyExpression
                )
            }
            return
        } catch let error as UnrecoverableError {
            throw ModelCheckerError(error: error, expression: job.expression)
        } catch let error {
            throw error
        }
        guard !results.isEmpty else {
            if let failingConstraint = job.constraints.first(where: {
                (try? $0.verify(node: node)) == nil
            }) {
                try fail(structure: structure, job: job) {
                    ModelCheckerError.constraintViolation(
                        branch: $0 + [node],
                        cost: failingConstraint.cost,
                        constraint: failingConstraint.constraint
                    )
                }
            }
            try succeed(job: job)
            return
        }
        try self.store.addManyJobs(
            jobs: try createNewJobs(currentJob: job, structure: structure, results: results)
        )
    }

    private func createNewJobs(
        currentJob job: Job, structure: KripkeStructureIterator, results: [VerifyStatus]
    ) throws -> [JobData] {
        lazy var successors = structure.edges[job.nodeId] ?? []
        return try results.flatMap { (result: VerifyStatus) -> [JobData] in
            let jobs: [JobData]
            switch result {
            case .addConstraints(let expression, let constraints):
                let newJob = JobData(expression: expression, constraints: constraints, job: job)
                jobs = [newJob]
            case .successor(let expression):
                if successors.isEmpty {
                    return []
                }
                jobs = successors.map { JobData(expression: expression, successor: $0, job: job) }
            case .revisitting(let expression, let revisit):
                let newJob = try JobData(
                    expression: expression, revisit: revisit, job: job, store: &self.store
                )
                jobs = [newJob]
            }
            return jobs
        }
    }

    private func succeed(job: Job) throws {
        if let revisitId = job.successRevisit {
            let revisit = try self.store.job(withId: revisitId)
            try self.store.addJob(job: revisit)
        }
    }

    private func fail(
        structure: KripkeStructureIterator, job: Job, error: ModelCheckerError
    ) throws {
        try fail(structure: structure, job: job) { _ in error }
    }

    private func fail(
        structure: KripkeStructureIterator, job: Job, computeError: ([Node]) -> ModelCheckerError
    ) throws {
        _ = try job.failRevisit.map { try self.store.addJob(job: try self.store.job(withId: $0)) }
        if job.failRevisit == nil {
            throw error(structure: structure, job: job, computeError)
        }
    }

    private func error(
        structure: KripkeStructureIterator, job: Job, _ computeError: ([Node]) -> ModelCheckerError
    ) -> ModelCheckerError {
        let currentNodes = job.currentBranch.compactMap { structure.nodes[$0] }
        guard currentNodes.count == job.currentBranch.count else {
            return ModelCheckerError.internalError
        }
        return computeError(currentNodes)
    }

}

private extension JobData {

    convenience init(expression: Expression, successor: NodeEdge, job: Job) {
        self.init(
            nodeId: successor.destination,
            expression: expression,
            history: job.history.union([job.nodeId]),
            currentBranch: job.currentBranch + [job.nodeId],
            historyExpression: job.historyExpression,
            constraints: job.constraints.map {
                PhysicalConstraint(cost: $0.cost + successor.cost, constraint: $0.constraint)
            },
            successRevisit: job.successRevisit,
            failRevisit: job.failRevisit
        )
    }

    convenience init(expression: Expression, constraints: [ConstrainedStatement], job: Job) {
        self.init(
            nodeId: job.nodeId,
            expression: expression,
            history: job.history,
            currentBranch: job.currentBranch,
            historyExpression: job.historyExpression,
            constraints: job.constraints + constraints.map {
                PhysicalConstraint(cost: .zero, constraint: $0)
            },
            successRevisit: job.successRevisit,
            failRevisit: job.failRevisit
        )
    }

    convenience init<T>(
        expression: Expression, revisit: RevisitExpression, job: Job, store: inout T
    ) throws where T: JobStorable {
        let successRevisit = job.successRevisit
        let failRevisit = job.failRevisit
        let newRevisit = try store.job(
            forData: JobData(
                nodeId: job.nodeId,
                expression: expression,
                history: job.history,
                currentBranch: job.currentBranch,
                historyExpression: job.historyExpression,
                constraints: job.constraints,
                successRevisit: successRevisit,
                failRevisit: failRevisit
            )
        ).id
        let revisitSuccess: UUID?
        let revisitFail: UUID?
        switch revisit {
        case .ignored:
            revisitSuccess = newRevisit
            if let successRevisit {
                revisitFail = successRevisit
            } else {
                revisitFail = try store.job(forData: JobData(
                    nodeId: job.nodeId,
                    expression: .language(expression: .vhdl(expression: .conditional(
                        expression: .literal(value: true)
                    ))),
                    history: job.history,
                    currentBranch: job.currentBranch,
                    historyExpression: job.historyExpression,
                    constraints: job.constraints,
                    successRevisit: nil,
                    failRevisit: nil
                )).id
            }
        case .required:
            revisitSuccess = newRevisit
            revisitFail = failRevisit
        case .skip:
            revisitSuccess = successRevisit
            revisitFail = newRevisit
        }
        self.init(
            nodeId: job.nodeId,
            expression: revisit.expression,
            history: job.history,
            currentBranch: job.currentBranch,
            historyExpression: job.historyExpression,
            constraints: job.constraints,
            successRevisit: revisitSuccess,
            failRevisit: revisitFail
        )
    }

}
