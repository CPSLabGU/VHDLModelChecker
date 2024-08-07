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

    private var store: JobStorable

    private var debug = false

    init(store: JobStorable) {
        self.store = store
    }

    func check(structure: KripkeStructureIterator, specification: Specification) throws {
        try self.store.reset()
        for id in structure.initialStates {
            for expression in specification.requirements {
                let job = Job(
                    nodeId: id,
                    expression: expression,
                    history: [],
                    currentBranch: [],
                    inSession: false,
                    historyExpression: nil,
                    constraints: [],
                    session: nil,
                    successRevisit: nil,
                    failRevisit: nil
                    // allSessionIds: SessionIdStore(sessionIds: [:])
                )
                try handleJob(job, structure: structure)
            }
        }
        while let job = try self.store.next {
            try handleJob(job, structure: structure)
        }
        // guard !sessionReferences.contains(where: { $0.value > 0 }) else {
        //     throw ModelCheckerError.internalError
        // }
        guard let (_, session) = try self.store.nextPendingSession else {
            return
        }
        let nodes = session.currentBranch.compactMap { structure.nodes[$0] }
        guard nodes.count == session.currentBranch.count else {
            throw ModelCheckerError.internalError
        }
        throw ModelCheckerError.unsatisfied(
            branch: nodes, expression: session.expression, base: session.historyExpression
        )
    }

    // swiftlint:disable:next function_body_length
    private func handleJob(_ job: Job, structure: KripkeStructureIterator) throws {
        defer {
            if debug { print("_\n_") }
        }
        if let session = job.session, let sessionResult = try self.store.sessionStatus(session: session) {
            if debug {
                print("""
                    job: \(try revisitId(for: Revisit(job: job)))
                    expression: \(job.expression.rawValue),
                    inCycle: \(job.history.contains(job.nodeId)),
                    sessionId: \(job.session?.description ?? "nil"),
                    historyExpression: \(job.historyExpression?.rawValue ?? "nil"),
                    constraints: [\(job.constraints.map { "([\($0.constraint.rawValue), cost: \($0.cost))" }.joined(separator: ", "))],
                    history: \(job.history.sorted { $0.description < $1.description })
                    successRevisit: \(job.successRevisit?.description ?? "nil")
                    failRevisit: \(job.failRevisit?.description ?? "nil")
                    """)
                print("session completed: \(sessionResult?.localizedDescription ?? "nil").")
                fflush(stdout)
            }
            if sessionResult == nil {
                try succeed(job: job)
            } else if let error = sessionResult {
                try fail(structure: structure, job: job, error: error)
            }
            return
        }
        if let session = job.session, try self.store.pendingSession(session: session) == nil {
            throw ModelCheckerError.internalError
        }
        let cycleData = job.cycleData
        if try store.hasCycle(cycle: cycleData) {
            if debug {
                print("""
                    job: \(job.expression.rawValue),
                    inCycle: \(job.history.contains(job.nodeId)),
                    sessionId: \(job.session?.description ?? "nil"),
                    historyExpression: \(job.historyExpression?.rawValue ?? "nil"),
                    constraints: [\(job.constraints.map { "([\($0.constraint.rawValue), cost: \($0.cost))" }.joined(separator: ", "))],
                    history: \(job.history.sorted { $0.description < $1.description })
                    successRevisit: \(job.successRevisit?.description ?? "nil")
                    failRevisit: \(job.failRevisit?.description ?? "nil")
                    """)
                print("in cycle.")
                fflush(stdout)
            }
            // for (session, count) in job.allSessionIds.sessionIds {
            //     decrement(session: session, amount: count)
            // }
            return
        }
        try self.store.addCycle(cycle: cycleData)
        guard let node = structure.nodes[job.nodeId] else {
            throw ModelCheckerError.internalError
        }
        if debug {
            print("nodeId: \(job.nodeId), node: \(node)")
            print("""
                job: \(try revisitId(for: Revisit(job: job)))
                expression: \(job.expression.rawValue),
                inCycle: \(job.history.contains(job.nodeId)),
                sessionId: \(job.session?.description ?? "nil"),
                historyExpression: \(job.historyExpression?.rawValue ?? "nil"),
                constraints: [\(job.constraints.map { "([\($0.constraint.rawValue), cost: \($0.cost))" }.joined(separator: ", "))],
                history: \(job.history.sorted { $0.description < $1.description })
                successRevisit: \(job.successRevisit?.description ?? "nil")
                failRevisit: \(job.failRevisit?.description ?? "nil")
                """)
            fflush(stdout)
        }
        if let historyExpression = job.expression.historyExpression, job.historyExpression != historyExpression {
            let newJob = Job(
                nodeId: job.nodeId,
                expression: job.expression,
                history: [],
                currentBranch: [],
                inSession: job.inSession,
                historyExpression: historyExpression,
                constraints: job.constraints,
                session: job.session,
                successRevisit: job.successRevisit,
                failRevisit: job.failRevisit
                // allSessionIds: job.allSessionIds
            )
            try self.store.addJob(job: newJob)
            return
        }
        let results: [SessionStatus]
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
        // defer {
        //     for (session, amount) in job.allSessionIds.sessionIds {
        //         decrement(session: session, amount: amount)
        //     }
        // }
        lazy var successors = structure.edges[job.nodeId] ?? []
        for result in results {
            switch result {
            case .addConstraints(let expression, let constraints):
                let newJob = Job(
                    nodeId: job.nodeId,
                    expression: expression,
                    history: job.history,
                    currentBranch: job.currentBranch,
                    inSession: job.inSession,
                    historyExpression: job.historyExpression,
                    constraints: job.constraints + constraints.map {
                        PhysicalConstraint(cost: .zero, constraint: $0)
                    },
                    session: job.session,
                    successRevisit: job.successRevisit,
                    failRevisit: job.failRevisit
                    // allSessionIds: job.allSessionIds
                )
                // for (session, amount) in newJob.allSessionIds.sessionIds {
                //     increment(session: session, amount: amount)
                // }
                try self.store.addJob(job: newJob)
                return
            default:
                break
            }
            let session = result.isNewSession ? try sessionId(forJob: job) : nil
            let jobs: [Job]
            guard let resultStatus = result.status else {
                throw ModelCheckerError.internalError
            }
            let successRevisit: UUID?
            let failRevisit: UUID?
            // let newAllSessionIds: SessionIdStore
            if let session {
                // newAllSessionIds = SessionIdStore(store: job.allSessionIds)
                // newAllSessionIds.addSession(id: session)
                successRevisit = try revisitId(for: Revisit(
                    nodeId: job.nodeId,
                    expression: .language(expression: .vhdl(expression: .true)),
                    inSession: true,
                    historyExpression: job.historyExpression,
                    constraints: [],
                    session: session,
                    successRevisit: job.successRevisit,
                    failRevisit: job.failRevisit,
                    history: job.history,
                    currentBranch: job.currentBranch
                    // allSessionIds: newAllSessionIds
                ))
                failRevisit = try revisitId(for: Revisit(
                    nodeId: job.nodeId,
                    expression: .language(expression: .vhdl(expression: .false)),
                    inSession: true,
                    historyExpression: job.historyExpression,
                    constraints: [],
                    session: session,
                    successRevisit: job.successRevisit,
                    failRevisit: job.failRevisit,
                    history: job.history,
                    currentBranch: job.currentBranch
                    // allSessionIds: newAllSessionIds
                ))
            } else {
                // newAllSessionIds = SessionIdStore(store: job.allSessionIds)
                successRevisit = job.successRevisit
                failRevisit = job.failRevisit
            }
            switch resultStatus {
            case .successor(let expression):
                if successors.isEmpty {
                    continue
                }
                jobs = successors.map { successor in
                    let nodeId = successor.destination
                    return Job(
                        nodeId: nodeId,
                        expression: expression,
                        history: job.history.union([job.nodeId]),
                        currentBranch: job.currentBranch + [job.nodeId],
                        inSession: result.isNewSession ? true : job.inSession,
                        historyExpression: job.historyExpression,
                        constraints: job.constraints.map {
                            PhysicalConstraint(cost: $0.cost + successor.cost, constraint: $0.constraint)
                        },
                        session: nil,
                        successRevisit: successRevisit,
                        failRevisit: failRevisit
                        // allSessionIds: newAllSessionIds
                    )
                }
                // for (session, amount) in newAllSessionIds.sessionIds {
                //     increment(session: session, amount: amount * UInt(successors.count))
                // }
            case .revisitting(let expression, let revisit):
                let newRevisit = try revisitId(for: Revisit(
                    nodeId: job.nodeId,
                    expression: expression,
                    inSession: result.isNewSession ? true : job.inSession,
                    historyExpression: job.historyExpression,
                    constraints: job.constraints,
                    session: nil,
                    successRevisit: successRevisit,
                    failRevisit: failRevisit,
                    history: job.history,
                    currentBranch: job.currentBranch
                    // allSessionIds: newAllSessionIds
                ))
                // for (session, amount) in newAllSessionIds.sessionIds {
                //     increment(session: session, amount: amount)
                // }
                let revisitSuccess: UUID?
                let revisitFail: UUID?
                switch revisit {
                case .ignored:
                    revisitSuccess = newRevisit
                    revisitFail = successRevisit
                case .required:
                    revisitSuccess = newRevisit
                    revisitFail = failRevisit
                case .skip:
                    revisitSuccess = successRevisit
                    revisitFail = newRevisit
                }
                let newJob = Job(
                    nodeId: job.nodeId,
                    expression: revisit.expression,
                    history: job.history,
                    currentBranch: job.currentBranch,
                    inSession: result.isNewSession ? true : job.inSession,
                    historyExpression: job.historyExpression,
                    constraints: job.constraints,
                    session: job.session,
                    successRevisit: revisitSuccess,
                    failRevisit: revisitFail
                    // allSessionIds: newAllSessionIds
                )
                // for (session, amount) in job.allSessionIds.sessionIds {
                //     increment(session: session, amount: amount)
                // }
                jobs = [newJob]
            }
            try self.store.addManyJobs(jobs: jobs)
            // var counts: [UUID: UInt] = [:]
            // func assignCount(_ session: UUID) {
            //     if counts[session] == nil {
            //         counts[session] = 1
            //     } else {
            //         counts[session] = counts[session].map { $0 + 1 }
            //     }
            // }
            // for job in self.jobs {
            //     if let session = job.session {
            //         assignCount(session)
            //     }
            //     var revisits: [Revisit] = []
            //     if let revisit = job.successRevisit {
            //         revisits.append(revisit)
            //     } else if let revisit = job.failRevisit {
            //         revisits.append(revisit)
            //     }
            //     while !revisits.isEmpty {
            //         let revisit = revisits.removeLast()
            //         if let session = revisit.session {
            //             assignCount(session)
            //         }
            //         if let revisit = revisit.successRevisit {
            //             revisits.append(revisit)
            //         } else if let revisit = revisit.failRevisit {
            //             revisits.append(revisit)
            //         }
            //     }
            // }
            // for key in Set(self.sessionReferences.keys).subtracting(Set(counts.keys)) {
            //     counts[key] = 0
            // }
            // for (lhs, rhs) in zip(counts.sorted { $0.key.description < $1.key.description }, self.sessionReferences.sorted { $0.key.description < $1.key.description }) {
            //     if (lhs.value != rhs.value) {
            //         fatalError("Not equal: \(lhs), \(rhs).")
            //     }
            // }
        }
    }

    private func sessionId(forJob job: Job) throws -> UUID {
        let key = job.sessionKey
        let out: UUID
        if let id = try self.store.sessionId(key: key) {
            out = id
        } else {
            // sessionReferences[id] = 0
            out = try self.store.addKey(key: key)
        }
        if try self.store.sessionStatus(session: out) == nil {
            try self.store.addSessionJob(session: out, job: job)
        }
        return out
    }

    private func succeed(job: Job) throws {
        if let session = job.session {
            // decrement(session: session, amount: 1)
            try self.store.removePendingSession(session: session)
        }
        if let revisitId = job.successRevisit {
            let revisit = try revisit(withId: revisitId)
            try self.store.addJob(job: Job(revisit: revisit))
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
        _ = try job.failRevisit.map { try self.store.addJob(job: Job(revisit: try revisit(withId: $0))) }
        guard job.session != nil else {
            if job.failRevisit != nil { return }
            throw error(structure: structure, job: job, computeError)
        }
        // let currentCount = decrement(session: session, amount: 1)
        // guard currentCount == 0 else {
        //     return
        // }
        // let error = error(structure: structure, job: job, computeError)
        // if completedSessions[session] == nil {
        //     completedSessions[session] = error
        // }
        // if job.failRevisit != nil { return }
        // throw error
        return
    }

    // @discardableResult
    // private func increment(session: UUID, amount: UInt) -> UInt {
    //     let currentCount = sessionReferences[session] ?? 0
    //     let newValue = currentCount + amount
    //     sessionReferences[session] = newValue
    //     return newValue
    // }

    // @discardableResult
    // private func decrement(session: UUID, amount: UInt) -> UInt {
    //     let currentCount = sessionReferences[session] ?? 0
    //     let newValue = currentCount - amount
    //     sessionReferences[session] = newValue
    //     if newValue == 0 {
    //         sessionReferences[session] = nil
    //         pendingSessions[session] = nil
    //     }
    //     return newValue
    // }

    private func error(
        structure: KripkeStructureIterator, job: Job, _ computeError: ([Node]) -> ModelCheckerError
    ) -> ModelCheckerError {
        let currentNodes = job.currentBranch.compactMap { structure.nodes[$0] }
        guard currentNodes.count == job.currentBranch.count else {
            return ModelCheckerError.internalError
        }
        return computeError(currentNodes)
    }

    private func revisitId(for revisit: Revisit) throws -> UUID {
        if let id = try self.store.revisitID(revisit: revisit) {
            return id
        }
        return try self.store.addRevisit(revisit: revisit)
    }

    private func revisit(withId id: UUID) throws -> Revisit {
        guard let revisit = try self.store.revisit(id: id) else {
            throw ModelCheckerError.internalError
        }
        return revisit
    }

}
