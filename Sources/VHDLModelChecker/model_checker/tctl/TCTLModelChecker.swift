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

final class TCTLModelChecker {

    var jobs: [Job] = []

    var cycles: Set<Job> = []

    var pendingSessions: [UUID: Job] = [:]

    private var debug = false

    init() {
        self.jobs.reserveCapacity(1000000)
        self.cycles.reserveCapacity(1000000)
        self.pendingSessions.reserveCapacity(1000000)
    }

    func check(structure: KripkeStructureIterator, specification: Specification) throws {
        self.jobs.removeAll(keepingCapacity: true)
        self.cycles.removeAll(keepingCapacity: true)
        self.pendingSessions.removeAll(keepingCapacity: true)
        for id in structure.initialStates {
            for expression in specification.requirements {
                let job = Job(
                    nodeId: id,
                    expression: expression,
                    history: [],
                    currentBranch: [],
                    cost: .zero,
                    inSession: false,
                    constraints: [],
                    session: nil,
                    successRevisit: nil,
                    failRevisit: nil
                )
                try handleJob(job, structure: structure)
            }
        }
        while let job = jobs.popLast() {
            try handleJob(job, structure: structure)
        }
        guard let session = pendingSessions.first else {
            return
        }
        let nodes = session.value.currentBranch.compactMap { structure.nodes[$0] }
        guard nodes.count == session.value.currentBranch.count else {
            throw ModelCheckerError.internalError
        }
        throw ModelCheckerError.unsatisfied(branch: nodes, expression: session.value.expression)
    }

    // swiftlint:disable:next function_body_length
    private func handleJob(_ job: Job, structure: KripkeStructureIterator) throws {
        if debug { print("\n") }
        if let session = job.session, pendingSessions[session] == nil {
            if debug {
                print("job: \(job.expression.rawValue), inCycle: \(job.history.contains(job.nodeId)), sessionId: \(job.session?.description ?? "nil"), history: \(job.history.sorted { $0.description < $1.description })")
                print("session completed.")
                fflush(stdout)
            }
            return
        }
        if cycles.contains(job) {
            if debug {
                print("job: \(job.expression.rawValue), inCycle: \(job.history.contains(job.nodeId)), sessionId: \(job.session?.description ?? "nil"), history: \(job.history.sorted { $0.description < $1.description })")
                print("in cycle.")
                fflush(stdout)
            }
            return
        }
        cycles.insert(job)
        guard let node = structure.nodes[job.nodeId] else {
            throw ModelCheckerError.internalError
        }
        if debug {
            print("node: \(node)")
            print("job: \(job.expression.rawValue), inCycle: \(job.history.contains(job.nodeId)), sessionId: \(job.session?.description ?? "nil"), history: \(job.history.sorted { $0.description < $1.description })")
            fflush(stdout)
        }
        let results: [SessionStatus]
        do {
            results = try job.expression.verify(
                currentNode: node,
                inCycle: job.history.contains(job.nodeId),
                cost: job.cost
            )
        } catch let error as VerificationError {
            guard let revisit = job.failRevisit else {
                guard !job.inSession else {
                    return
                }
                let currentNodes = job.currentBranch.compactMap { structure.nodes[$0] }
                guard currentNodes.count == job.currentBranch.count else {
                    throw ModelCheckerError.internalError
                }
                throw ModelCheckerError(error: error, currentBranch: currentNodes, expression: job.expression)
            }
            self.jobs.append(Job(revisit: revisit))
            return
        } catch let error as UnrecoverableError {
            throw ModelCheckerError(error: error, expression: job.expression)
        } catch let error {
            throw error
        }
        guard !results.isEmpty else {
            if let failingConstraint = job.constraints.first(where: {
                (try? $0.verify(node: node, cost: job.cost)) == nil
            }) {
                if let revisit = job.failRevisit {
                    jobs.append(Job(revisit: revisit))
                    return
                }
                guard !job.inSession else {
                    return
                }
                let currentNodes = job.currentBranch.compactMap { structure.nodes[$0] }
                guard currentNodes.count == job.currentBranch.count else {
                    throw ModelCheckerError.internalError
                }
                throw ModelCheckerError.constraintViolation(
                    branch: currentNodes + [node],
                    cost: job.cost,
                    constraint: failingConstraint
                )
            }
            if let session = job.session {
                pendingSessions[session] = nil
            }
            guard let revisit = job.successRevisit else {
                return
            }
            self.jobs.append(Job(revisit: revisit))
            return
        }
        lazy var successors = structure.edges[job.nodeId] ?? []
        for result in results {
            let session = result.isNewSession ? UUID() : nil
            let sessionRevisit = Revisit(
                nodeId: job.nodeId,
                expression: .language(expression: .vhdl(expression: .true)),
                cost: job.cost,
                inSession: result.isNewSession ? true : job.inSession,
                constraints: job.constraints,
                session: session,
                successRevisit: job.successRevisit,
                failRevisit: job.failRevisit,
                history: job.history,
                currentBranch: job.currentBranch
            )
            let jobs: [Job]
            switch result.status {
            case .successor(let expression):
                jobs = successors.map {
                    let nodeId = $0.destination
                    return Job(
                        nodeId: nodeId,
                        expression: expression,
                        history: job.history.union([job.nodeId]),
                        currentBranch: job.currentBranch + [job.nodeId],
                        cost: job.cost + $0.cost,
                        inSession: result.isNewSession ? true : job.inSession,
                        constraints: job.constraints,
                        session: nil,
                        successRevisit: sessionRevisit,
                        failRevisit: job.failRevisit
                    )
                }
            case .revisitting(let expression, let revisit):
                let newRevisit = Revisit(
                    nodeId: job.nodeId,
                    expression: expression,
                    cost: job.cost,
                    inSession: result.isNewSession ? true : job.inSession,
                    constraints: job.constraints,
                    session: nil,
                    successRevisit: sessionRevisit,
                    failRevisit: job.failRevisit,
                    history: job.history,
                    currentBranch: job.currentBranch
                )
                let successRevisit: Revisit?
                let failRevisit: Revisit?
                switch revisit {
                case .ignored:
                    successRevisit = newRevisit
                    failRevisit = sessionRevisit
                case .required:
                    successRevisit = newRevisit
                    failRevisit = job.failRevisit
                case .skip:
                    successRevisit = sessionRevisit
                    failRevisit = newRevisit
                }
                if revisit.constraints.isEmpty {
                    jobs = [
                        Job(
                            nodeId: job.nodeId,
                            expression: revisit.expression,
                            history: job.history,
                            currentBranch: job.currentBranch,
                            cost: job.cost,
                            inSession: result.isNewSession ? true : job.inSession,
                            constraints: job.constraints,
                            session: job.session,
                            successRevisit: successRevisit,
                            failRevisit: failRevisit
                        )
                    ]
                } else {
                    jobs = [
                        Job(
                            nodeId: job.nodeId,
                            expression: revisit.expression,
                            history: job.history,
                            currentBranch: job.currentBranch,
                            cost: .zero,
                            inSession: result.isNewSession ? true : job.inSession,
                            constraints: revisit.constraints,
                            session: job.session,
                            successRevisit: successRevisit,
                            failRevisit: failRevisit
                        )
                    ]
                }
            }
            self.jobs.append(contentsOf: jobs)
            if let session, let job = jobs.first {
                switch result {
                case .newSession:
                    pendingSessions[session] = job
                default:
                    break
                }
            }
        }
    }

}
