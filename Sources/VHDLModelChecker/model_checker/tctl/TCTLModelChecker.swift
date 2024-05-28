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

    var cycles: Set<CycleData> = []

    var completedSessions: [UUID: ModelCheckerError?] = [:]

    var pendingSessions: [UUID: Job] = [:]

    var sessionIds: [SessionKey: UUID] = [:]

    var sessionReferences: [UUID: UInt] = [:]

    var revisitIds: [Revisit: UUID] = [:]

    var revisits: [UUID: Revisit] = [:]

    private var debug = false

    init() {
        self.jobs.reserveCapacity(1000000)
        self.cycles.reserveCapacity(1000000)
        self.completedSessions.reserveCapacity(1000000)
        self.pendingSessions.reserveCapacity(1000000)
        self.sessionIds.reserveCapacity(1000000)
        self.sessionReferences.reserveCapacity(1000000)
        self.revisitIds.reserveCapacity(1000000)
        self.revisits.reserveCapacity(1000000)
    }

    func check(structure: KripkeStructureIterator, specification: Specification) throws {
        self.jobs.removeAll(keepingCapacity: true)
        self.cycles.removeAll(keepingCapacity: true)
        self.completedSessions.removeAll(keepingCapacity: true)
        self.pendingSessions.removeAll(keepingCapacity: true)
        self.sessionIds.removeAll(keepingCapacity: true)
        self.sessionReferences.removeAll(keepingCapacity: true)
        self.revisitIds.removeAll(keepingCapacity: true)
        self.revisits.removeAll(keepingCapacity: true)
        for id in structure.initialStates {
            for expression in specification.requirements {
                let job = Job(
                    nodeId: id,
                    expression: expression,
                    history: [],
                    currentBranch: [],
                    inSession: false,
                    constraints: [],
                    session: nil,
                    successRevisit: nil,
                    failRevisit: nil,
                    allSessionIds: SessionIdStore(sessionIds: [:])
                )
                try handleJob(job, structure: structure)
            }
        }
        while let job = jobs.popLast() {
            try handleJob(job, structure: structure)
        }
        guard !sessionReferences.contains(where: { $0.value > 0 }) else {
            throw ModelCheckerError.internalError
        }
        guard let (_, session) = pendingSessions.first else {
            return
        }
        let nodes = session.currentBranch.compactMap { structure.nodes[$0] }
        guard nodes.count == session.currentBranch.count else {
            throw ModelCheckerError.internalError
        }
        throw ModelCheckerError.unsatisfied(branch: nodes, expression: session.expression)
    }

    // swiftlint:disable:next function_body_length
    private func handleJob(_ job: Job, structure: KripkeStructureIterator) throws {
        if debug { print("\n") }
        if let session = job.session, let sessionResult = completedSessions[session] {
            if debug {
                print("job: \(job.expression.rawValue), inCycle: \(job.history.contains(job.nodeId)), sessionId: \(job.session?.description ?? "nil"), history: \(job.history.sorted { $0.description < $1.description })")
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
        let cycleData = job.cycleData
        if cycles.contains(cycleData) {
            if debug {
                print("job: \(job.expression.rawValue), inCycle: \(job.history.contains(job.nodeId)), sessionId: \(job.session?.description ?? "nil"), history: \(job.history.sorted { $0.description < $1.description })")
                print("in cycle.")
                fflush(stdout)
            }
            for (session, count) in job.allSessionIds.sessionIds {
                try decrement(session: session, amount: count)
            }
            return
        }
        cycles.insert(cycleData)
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
            results = try job.expression.verify(currentNode: node, inCycle: job.history.contains(job.nodeId))
        } catch let error as VerificationError {
            try fail(structure: structure, job: job) {
                ModelCheckerError(error: error, currentBranch: $0, expression: job.expression)
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
        for (session, amount) in job.allSessionIds.sessionIds {
            try decrement(session: session, amount: amount)
        }
        lazy var successors = structure.edges[job.nodeId] ?? []
        for result in results {
            let newSuccessRevisit = try job.successRevisit.map { Revisit(revisit: try revisit(withId: $0)) }
            newSuccessRevisit?.constraints = []
            let newSuccessRevisitId = newSuccessRevisit.map(revisitId)
            let newFailRevisit = try job.failRevisit.map { Revisit(revisit: try revisit(withId: $0)) }
            newFailRevisit?.constraints = []
            let newFailRevisitId = newFailRevisit.map(revisitId)
            let session = result.isNewSession ? try sessionId(forJob: job) : nil
            let jobs: [Job]
            switch result.status {
            case .successor(let expression):
                if successors.isEmpty {
                    return
                }
                let sessionRevisit: Revisit?
                let sessionFailRevisit: Revisit?
                let newAllSessionIds: SessionIdStore
                if let session {
                    newAllSessionIds = SessionIdStore(store: job.allSessionIds)
                    newAllSessionIds.addSession(id: session)
                    sessionRevisit = Revisit(
                        nodeId: job.nodeId,
                        expression: .language(expression: .vhdl(expression: .true)),
                        inSession: true,
                        constraints: [],
                        session: session,
                        successRevisit: newSuccessRevisitId,
                        failRevisit: newFailRevisitId,
                        history: job.history,
                        currentBranch: job.currentBranch,
                        allSessionIds: newAllSessionIds
                    )
                    sessionFailRevisit = Revisit(
                        nodeId: job.nodeId,
                        expression: .language(expression: .vhdl(expression: .false)),
                        inSession: true,
                        constraints: [],
                        session: session,
                        successRevisit: newSuccessRevisitId,
                        failRevisit: newFailRevisitId,
                        history: job.history,
                        currentBranch: job.currentBranch,
                        allSessionIds: newAllSessionIds
                    )
                } else {
                    newAllSessionIds = SessionIdStore(store: job.allSessionIds)
                    sessionRevisit = newSuccessRevisit
                    sessionFailRevisit = newFailRevisit
                }
                let sessionRevisitId = sessionRevisit.map(revisitId)
                let sessionFailRevisitId = sessionFailRevisit.map(revisitId)
                jobs = successors.map { successor in
                    let nodeId = successor.destination
                    return Job(
                        nodeId: nodeId,
                        expression: expression,
                        history: job.history.union([job.nodeId]),
                        currentBranch: job.currentBranch + [job.nodeId],
                        inSession: result.isNewSession ? true : job.inSession,
                        constraints: job.constraints.map {
                            PhysicalConstraint(cost: $0.cost + successor.cost, constraint: $0.constraint)
                        },
                        session: nil,
                        successRevisit: sessionRevisitId,
                        failRevisit: sessionFailRevisitId,
                        allSessionIds: newAllSessionIds
                    )
                }
                for (session, amount) in newAllSessionIds.sessionIds {
                    try increment(session: session, amount: amount * UInt(successors.count))
                    // try decrement(session: session, amount: 1)
                }
            case .revisitting(let expression, let revisit):
                let sessionRevisit: Revisit?
                let sessionFailRevisit: Revisit?
                let newAllSessionIds: SessionIdStore
                if let session {
                    newAllSessionIds = SessionIdStore(store: job.allSessionIds)
                    // if let jobSession = job.session {
                    //     newAllSessionIds.removeSession(id: jobSession)
                    // }
                    newAllSessionIds.addSession(id: session)
                    sessionRevisit = Revisit(
                        nodeId: job.nodeId,
                        expression: .language(expression: .vhdl(expression: .true)),
                        inSession: true,
                        constraints: [],
                        session: session,
                        successRevisit: newSuccessRevisitId,
                        failRevisit: newFailRevisitId,
                        history: job.history,
                        currentBranch: job.currentBranch,
                        allSessionIds: newAllSessionIds
                    )
                    sessionFailRevisit = Revisit(
                        nodeId: job.nodeId,
                        expression: .language(expression: .vhdl(expression: .false)),
                        inSession: true,
                        constraints: [],
                        session: session,
                        successRevisit: newSuccessRevisitId,
                        failRevisit: newFailRevisitId,
                        history: job.history,
                        currentBranch: job.currentBranch,
                        allSessionIds: newAllSessionIds
                    )
                } else {
                    newAllSessionIds = SessionIdStore(store: job.allSessionIds)
                    // if let jobSession = job.session {
                    //     newAllSessionIds.removeSession(id: jobSession)
                    // }
                    sessionRevisit = newSuccessRevisit
                    sessionFailRevisit = newFailRevisit
                }
                for (session, amount) in newAllSessionIds.sessionIds {
                    try increment(session: session, amount: amount)
                }
                let revisitConstraints = revisit.constraints.map {
                    PhysicalConstraint(cost: .zero, constraint: $0)
                }
                let newConstraints = job.constraints + revisitConstraints
                let alternativeRevisit = sessionRevisit.map(Revisit.init)
                alternativeRevisit?.constraints = newConstraints
                let sessionRevisitId = sessionRevisit.map(revisitId)
                let newRevisit = Revisit(
                    nodeId: job.nodeId,
                    expression: expression,
                    inSession: result.isNewSession ? true : job.inSession,
                    constraints: newConstraints,
                    session: nil,
                    successRevisit: sessionRevisitId,
                    failRevisit: newFailRevisitId,
                    history: job.history,
                    currentBranch: job.currentBranch,
                    allSessionIds: newAllSessionIds
                )
                let successRevisit: Revisit?
                let failRevisit: Revisit?
                switch revisit {
                case .ignored:
                    successRevisit = newRevisit
                    failRevisit = alternativeRevisit
                case .required:
                    successRevisit = newRevisit
                    failRevisit = sessionFailRevisit
                case .skip:
                    successRevisit = alternativeRevisit
                    failRevisit = newRevisit
                }
                let successRevisitId = successRevisit.map(revisitId)
                let failRevisitId = failRevisit.map(revisitId)
                let newJob = Job(
                    nodeId: job.nodeId,
                    expression: revisit.expression,
                    history: job.history,
                    currentBranch: job.currentBranch,
                    inSession: result.isNewSession ? true : job.inSession,
                    constraints: newConstraints,
                    session: job.session,
                    successRevisit: successRevisitId,
                    failRevisit: failRevisitId,
                    allSessionIds: newAllSessionIds
                )
                if let jobSession = job.session {
                    // newJob.allSessionIds.addSession(id: jobSession)
                    try increment(session: jobSession, amount: 1)
                }
                // if let session = session {
                //     try decrement(session: session, amount: 1)
                // }
                jobs = [newJob]
            }
            self.jobs.append(contentsOf: jobs)
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
        if let id = sessionIds[key] {
            out = id
        } else {
            let id = UUID()
            sessionIds[key] = id
            sessionReferences[id] = 0
            out = id
        }
        if completedSessions[out] == nil {
            pendingSessions[out] = job
        }
        return out
    }

    private func succeed(job: Job) throws {
        if let session = job.session {
            try decrement(session: session, amount: 1)
            completedSessions[session] = .some(nil)
            pendingSessions[session] = nil
        }
        if let revisitId = job.successRevisit {
            let revisit = try revisit(withId: revisitId)
            self.jobs.append(Job(revisit: revisit))
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
        _ = try job.failRevisit.map { self.jobs.append(Job(revisit: try revisit(withId: $0))) }
        guard let session = job.session else {
            if job.failRevisit != nil { return }
            throw error(structure: structure, job: job, computeError)
        }
        let currentCount = try decrement(session: session, amount: 1)
        guard currentCount == 0 else {
            if job.failRevisit != nil { return }
            throw error(structure: structure, job: job, computeError)
        }
        let error = error(structure: structure, job: job, computeError)
        completedSessions[session] = error
        pendingSessions[session] = nil
        if job.failRevisit != nil { return }
        throw error
    }

    @discardableResult
    private func increment(session: UUID, amount: UInt) throws -> UInt {
        guard let currentCount = sessionReferences[session] else {
            throw ModelCheckerError.internalError
        }
        let newValue = currentCount + amount
        sessionReferences[session] = newValue
        return newValue
    }

    @discardableResult
    private func decrement(session: UUID, amount: UInt) throws -> UInt {
        guard let currentCount = sessionReferences[session] else {
            throw ModelCheckerError.internalError
        }
        let newValue = currentCount - amount
        sessionReferences[session] = newValue
        if newValue == 0 {
            pendingSessions[session] = nil
        }
        return newValue
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

    private func revisitId(for revisit: Revisit) -> UUID {
        if let id = revisitIds[revisit] {
            return id
        }
        let id = UUID()
        revisitIds[revisit] = id
        revisits[id] = revisit
        return id
    }

    private func revisit(withId id: UUID) throws -> Revisit {
        guard let revisit = revisits[id] else {
            throw ModelCheckerError.internalError
        }
        return revisit
    }

}