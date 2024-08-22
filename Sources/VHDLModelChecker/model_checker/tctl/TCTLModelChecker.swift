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
                    failRevisit: nil,
                    session: nil,
                    sessionRevisit: nil
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
            guard
                let session = job.session,
                try self.store.isComplete(session: session),
                try self.store.error(session: session) == nil,
                let revisit = job.sessionRevisit
            else {
                return
            }
            try self.store.addJob(job: try self.store.job(withId: revisit))
            return
        }
        if let session = job.session, try self.store.error(session: session) != nil {
            return
        }
        guard let node = structure.nodes[job.nodeId] else {
            throw ModelCheckerError.internalError
        }
        if let historyExpression = job.expression.historyExpression, job.historyExpression != historyExpression {
            // print("New session:\n    node id: \(job.nodeId.uuidString)\n    expression: \(job.expression.rawValue)\n\n")
            // fflush(stdout)
            let newJob = JobData(
                nodeId: job.nodeId,
                expression: job.expression,
                history: [],
                currentBranch: [],
                historyExpression: historyExpression,
                constraints: job.constraints,
                successRevisit: nil,
                failRevisit: job.failRevisit,
                session: UUID(),
                sessionRevisit: job.successRevisit ?? job.sessionRevisit
            )
            try self.store.addJob(data: newJob)
            return
        }
        // print("Verifying:\n    node id: \(job.nodeId.uuidString)\n    expression: \(job.expression.rawValue)\n    properties: \(structure.nodes[job.nodeId]!.properties)\n\n")
        // fflush(stdout)
        let results: [VerifyStatus]
        do {
            results = try job.expression.verify(
                currentNode: node,
                inCycle: job.history.contains(job.nodeId) || (structure.edges[job.nodeId] ?? []).isEmpty
            )
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
        guard results.isEmpty else {
            try createNewJobs(currentJob: job, structure: structure, results: results)
            return
        }
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
    }

    private func createNewJobs(
        currentJob job: Job, structure: KripkeStructureIterator, results: [VerifyStatus]
    ) throws {
        lazy var successors = structure.edges[job.nodeId] ?? []
        for result in results {
            switch result {
            case .addConstraints(let expression, let constraints):
                try self.store.addJob(
                    data: JobData(expression: expression, constraints: constraints, job: job)
                )
            case .successor(let expression):
                guard !successors.isEmpty else {
                    throw ModelCheckerError.internalError
                }
                for successor in successors {
                    try self.store.addJob(
                        data: JobData(expression: expression, successor: successor, job: job)
                    )
                }
            case .revisitting(let expression, let revisit):
                try self.store.addJob(
                    data: try JobData(expression: expression, revisit: revisit, job: job, store: &self.store)
                )
            }
        }
    }

    private func succeed(job: Job) throws {
        if let revisitId = job.successRevisit {
            let revisit = try self.store.job(withId: revisitId)
            try self.store.addJob(job: revisit)
        }
        if let revisit = job.sessionRevisit {
            guard let session = job.session else {
                throw ModelCheckerError.internalError
            }
            if try self.store.isComplete(session: session) {
                let revisit = try self.store.job(withId: revisit)
                try self.store.addJob(job: revisit)
            }
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
        if let session = job.session {
            try self.store.failSession(
                id: session, error: error(structure: structure, job: job, computeError)
            )
        }
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
            failRevisit: job.failRevisit,
            session: job.session,
            sessionRevisit: job.sessionRevisit
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
            failRevisit: job.failRevisit,
            session: job.session,
            sessionRevisit: job.sessionRevisit
        )
    }

    convenience init<T>(
        expression: Expression, revisit: RevisitExpression, job: Job, store: inout T
    ) throws where T: JobStorable {
        switch revisit {
        case .ignored:
            let newRevisit = JobData(
                nodeId: job.nodeId,
                expression: expression,
                history: job.history,
                currentBranch: job.currentBranch,
                historyExpression: job.historyExpression,
                constraints: job.constraints,
                successRevisit: job.successRevisit,
                failRevisit: job.failRevisit,
                session: job.session,
                sessionRevisit: job.sessionRevisit
            )
            let trueJob = JobData(
                nodeId: job.nodeId,
                expression: .language(expression: .vhdl(expression: .true)),
                history: [],
                currentBranch: [],
                historyExpression: nil,
                constraints: [],
                successRevisit: job.successRevisit,
                failRevisit: nil,
                session: job.session,
                sessionRevisit: job.sessionRevisit
            )
            self.init(
                nodeId: job.nodeId,
                expression: revisit.expression,
                history: job.history,
                currentBranch: job.currentBranch,
                historyExpression: job.historyExpression,
                constraints: job.constraints,
                successRevisit: try store.job(forData: newRevisit).id,
                failRevisit: try store.job(forData: trueJob).id,
                session: nil,
                sessionRevisit: nil
            )
        case .required:
            let newRevisit = JobData(
                nodeId: job.nodeId,
                expression: expression,
                history: job.history,
                currentBranch: job.currentBranch,
                historyExpression: job.historyExpression,
                constraints: job.constraints,
                successRevisit: job.successRevisit,
                failRevisit: job.failRevisit,
                session: job.session,
                sessionRevisit: job.sessionRevisit
            )
            let id = try store.job(forData: newRevisit).id
            self.init(
                nodeId: job.nodeId,
                expression: revisit.expression,
                history: job.history,
                currentBranch: job.currentBranch,
                historyExpression: job.historyExpression,
                constraints: job.constraints,
                successRevisit: id,
                failRevisit: job.failRevisit,
                session: job.session,
                sessionRevisit: job.sessionRevisit
            )
        case .skip:
            let newRevisit = JobData(
                nodeId: job.nodeId,
                expression: expression,
                history: job.history,
                currentBranch: job.currentBranch,
                historyExpression: job.historyExpression,
                constraints: job.constraints,
                successRevisit: job.successRevisit,
                failRevisit: job.failRevisit,
                session: job.session,
                sessionRevisit: job.sessionRevisit
            )
            let trueJob = JobData(
                nodeId: job.nodeId,
                expression: .language(expression: .vhdl(expression: .true)),
                history: [],
                currentBranch: [],
                historyExpression: nil,
                constraints: [],
                successRevisit: job.successRevisit,
                failRevisit: nil,
                session: job.session,
                sessionRevisit: job.sessionRevisit
            )
            self.init(
                nodeId: job.nodeId,
                expression: revisit.expression,
                history: job.history,
                currentBranch: job.currentBranch,
                historyExpression: job.historyExpression,
                constraints: job.constraints,
                successRevisit: try store.job(forData: trueJob).id,
                failRevisit: try store.job(forData: newRevisit).id,
                session: nil,
                sessionRevisit: nil
            )
        }
    }

}
