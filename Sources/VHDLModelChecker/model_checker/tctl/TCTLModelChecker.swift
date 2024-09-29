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
import StringHelpers
import TCTLParser
import VHDLKripkeStructures

// swiftlint:disable file_length

/// Verify a Kripke structure against a TCTL specification.
final class TCTLModelChecker<T> where T: JobStorable {

    /// The store to use for storing pending jobs.
    private var store: T

    /// Whether to enable debug prints.
    private var debug = false

    /// Create a new model checker.
    /// 
    /// - Parameter store: The store to use when storing pending jobs.
    init(store: T) {
        self.store = store
    }

    /// Verify a Kripke structure against a TCTL specification.
    /// - Parameters:
    ///   - structure: The Kripke structure to verify.
    ///   - specification: The specification to verify `structure` against.
    func check(structure: KripkeStructureIterator, specification: Specification) throws {
        try self.store.reset()
        let clock = ContinuousClock()
        let totalRequirements = specification.requirements.count
        for (index, expression) in specification.requirements.enumerated() {
            print(
                """
                Verifying Requirement (\(index + 1)/\(totalRequirements)):
                \(expression.rawValue.indent(amount: 1))
                """
            )
            for id in structure.initialStates {
                let job = JobData(
                    nodeId: id,
                    expression: expression.normalised,
                    history: [],
                    currentBranch: [],
                    historyExpression: nil,
                    successRevisit: nil,
                    failRevisit: nil,
                    session: nil,
                    sessionRevisit: nil,
                    window: nil
                )
                try self.store.addJob(data: job)
            }
            fflush(stdout)
            let elapsedTime = try clock.measure {
                while let jobId = try self.store.next {
                    try handleJob(withId: jobId, structure: structure)
                }
            }
            print("Finished Requirement \(index + 1) in \(elapsedTime).\n\n")
            fflush(stdout)
        }
    }

    /// Find all edges that are valid successors for a job.
    /// - Parameters:
    ///   - job: The job to find successors for.
    ///   - edges: All candidate edges.
    /// - Returns: The valid successors.
    private func getValidSuccessors(
        job: Job, edges: LazySequence<[NodeEdge]>
    ) throws -> LazyFilterSequence<[NodeEdge]> {
        edges.filter {
            let newWindow = job.window?.addCost(cost: $0.cost) ?? ConstrainedWindow(cost: $0.cost)
            return newWindow.isWithinWindow
        }
    }

    /// Check whether a job is in a cycle.
    /// - Parameters:
    ///   - job: The job to check.
    ///   - edges: The edges to of the job.
    /// - Returns: Whether the job is in a cycle.
    private func inCycle<S: Sequence>(job: Job, edges: S) -> Bool where S.Iterator.Element == NodeEdge {
        guard !job.history.contains(job.nodeId) else {
            return true
        }
        return !edges.contains { _ in true }
    }

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity

    /// Verify a single job.
    /// - Parameters:
    ///   - jobId: The ID of the job to verify.
    ///   - structure: The Kripke structure to verify against.
    private func handleJob(withId jobId: UUID, structure: KripkeStructureIterator) throws {
        let job = try self.store.job(withId: jobId)
        // print("""
        // Job:
        //     node id: \(job.nodeId.uuidString)
        //     expression: \(job.expression.rawValue)
        //     Cost: \(job.cost)
        //     Session Revisit ID: \(job.sessionRevisit?.uuidString ?? "nil")
        //     Window:
        //         Time: [\(job.timeMinimum), \(job.timeMaximum)]
        //         Energy: [\(job.energyMinimum), \(job.energyMaximum)]
        //     properties:
        //         \(structure.nodes[job.nodeId]!.properties)
        // """)
        // fflush(stdout)
        guard !job.isAboveWindow else {
            // print("Above Window\n\n")
            // fflush(stdout)
            try fail(structure: structure, job: job) { _ in
                ModelCheckerError.mismatchedConstraints(constraints: [])
            }
            return
        }
        guard !job.isBelowWindow else {
            // print("Below Window\n\n")
            // fflush(stdout)
            let successors = structure.edges[job.nodeId] ?? []
            for successor in successors {
                let newJob = JobData(
                    nodeId: successor.destination,
                    expression: job.expression,
                    history: [],
                    currentBranch: [],
                    historyExpression: job.historyExpression,
                    successRevisit: job.successRevisit,
                    failRevisit: job.failRevisit,
                    session: job.session,
                    sessionRevisit: job.sessionRevisit,
                    window: job.window?.addCost(cost: successor.cost)
                )
                try self.store.addJob(data: newJob)
            }
            return
        }
        guard !(try store.inCycle(job)) else {
            // print("In Cycle\n\n")
            // fflush(stdout)
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
            // print("Session Error\n\n")
            // fflush(stdout)
            return
        }
        guard let node = structure.nodes[job.nodeId] else {
            throw ModelCheckerError.internalError
        }
        if let historyExpression = job.expression.historyExpression,
            job.historyExpression != historyExpression {
            // print("New session\n\n")
            // fflush(stdout)
            let newJob = try JobData(
                newSessionFor: job, historyExpression: historyExpression, structure: structure
            )
            try self.store.addJob(data: newJob)
            return
        }
        // if job.expression.historyExpression == nil {
        //     print("Removing Constraints!")
        //     fflush(stdout)
        //     let newJob = JobData(
        //         nodeId: job.nodeId,
        //         expression: job.expression,
        //         history: job.history,
        //         currentBranch: job.currentBranch,
        //         historyExpression: job.historyExpression,
        //         constraints: job.constraints,
        //         successRevisit: job.successRevisit,
        //         failRevisit: job.failRevisit,
        //         session: job.session,
        //         sessionRevisit: job.sessionRevisit,
        //         cost: .zero,
        //         timeMinimum: .zero,
        //         timeMaximum: .max,
        //         energyMinimum: .zero,
        //         energyMaximum: .max
        //     )
        //     try self.store.addJob(data: newJob)
        //     return
        // }
        guard let allEdges = structure.edges[job.nodeId]?.lazy, !allEdges.isEmpty else {
            throw ModelCheckerError.corruptKripkeStructure(
                node: node, edges: structure.edges[job.nodeId]?.count ?? 0
            )
        }
        let allSuccessors = allEdges.map { Successor(job: job, edge: $0) }
        let successors = allSuccessors.filter { $0.isValid }.map { $0.edge }
        let invalidSuccessors = allSuccessors.filter { !$0.isValid }.map { $0.edge }
        // print("""
        // Verifying:
        //     inCycle: \(self.inCycle(job: job, edges: successors))\n\n
        // """)
        // fflush(stdout)
        let invalidResults: [VerifyStatus]
        let results: [VerifyStatus]
        let inCycle = self.inCycle(job: job, edges: successors)
        do {
            if !inCycle && !invalidSuccessors.isEmpty {
                invalidResults = (try job.expression.verify(currentNode: node, inCycle: true)).filter {
                    !$0.isSuccessor
                }
            } else {
                invalidResults = []
            }
            results = try job.expression.verify(
                currentNode: node, inCycle: self.inCycle(job: job, edges: successors)
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
        if !invalidResults.isEmpty {
            try createNewJobs(
                currentJob: job, structure: structure, results: invalidResults, successors: invalidSuccessors
            )
            if results.isEmpty {
                return
            }
        }
        guard results.isEmpty else {
            try createNewJobs(currentJob: job, structure: structure, results: results, successors: successors)
            return
        }
        // if let failingConstraint = job.constraints.first(where: {
        //     (try? $0.verify(node: node, cost: job.cost)) == nil
        // }) {
        //     try fail(structure: structure, job: job) {
        //         ModelCheckerError.constraintViolation(
        //             branch: $0 + [node],
        //             cost: job.cost,
        //             constraint: failingConstraint
        //         )
        //     }
        // }
        try succeed(job: job)
    }

    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

    /// Create new jobs based on the results of a job.
    /// - Parameters:
    ///   - job: The job to create new jobs for.
    ///   - structure: The Kripke structure to verify against.
    ///   - results: The results of the job.
    ///   - successors: The successors of the job.
    private func createNewJobs<S: Sequence>(
        currentJob job: Job,
        structure: KripkeStructureIterator,
        results: [VerifyStatus],
        successors: S
    ) throws where S.Iterator.Element == NodeEdge {
        for result in results {
            switch result {
            // case .addConstraints(let expression, let constraints):
            case .addConstraints:
                fatalError("Should never add constraints!")
                // try self.store.addJob(
                //     data: JobData(expression: expression, constraints: constraints, job: job)
                // )
            case .successor(let expression):
                guard successors.contains(where: { _ in true }) else {
                    if job.window == nil {
                        throw ModelCheckerError.internalError
                    } else {
                        try fail(structure: structure, job: job) { _ in
                            ModelCheckerError.mismatchedConstraints(constraints: [])
                        }
                        return
                    }
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

    /// Handle a successful job.
    /// - Parameter job: The job that succeeded.
    private func succeed(job: Job) throws {
        if let revisitId = job.successRevisit {
            // print("Revisiting success revisit: \(revisitId)")
            // fflush(stdout)
            let revisit = try self.store.job(withId: revisitId)
            try self.store.addJob(job: revisit)
        }
        if let revisit = job.sessionRevisit {
            // print("Revisiting Session: \(revisit)")
            // fflush(stdout)
            guard let session = job.session else {
                throw ModelCheckerError.internalError
            }
            if try self.store.isComplete(session: session) {
                let revisit = try self.store.job(withId: revisit)
                try self.store.addJob(job: revisit)
            }
        }
    }

    /// Handle a failed job.
    /// - Parameters:
    ///   - structure: The Kripke structure to verify against.
    ///   - job: The job that failed.
    ///   - error: The error that caused the job to fail.
    private func fail(
        structure: KripkeStructureIterator, job: Job, error: ModelCheckerError
    ) throws {
        try fail(structure: structure, job: job) { _ in error }
    }

    /// Handle a failed job.
    /// - Parameters:
    ///   - structure: The Kripke structure to verify against.
    ///   - job: The job that failed.
    ///   - computeError: A function that computes the error that caused the job to fail.
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

    /// Compute the error that caused a job to fail.
    /// - Parameters:
    ///   - structure: The Kripke structure to verify against.
    ///   - job: The job that failed.
    ///   - computeError: The function that computes the error that caused the job to fail.
    /// - Returns: The error that caused the job to fail.
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

/// Add helper inits for successors.
private extension JobData {

    /// Create a new session for a job.
    /// - Parameters:
    ///   - job: The job to create a new session for.
    ///   - historyExpression: The history expression to use for the new session.
    ///   - structure: The Kripke structure to verify against.
    convenience init(
        newSessionFor job: Job, historyExpression: TCTLParser.Expression, structure: KripkeStructureIterator
    ) throws {
        guard case .constrained(let jobExpression) = job.expression else {
            self.init(
                nodeId: job.nodeId,
                expression: job.expression,
                history: [],
                currentBranch: [],
                historyExpression: historyExpression,
                successRevisit: nil,
                failRevisit: job.failRevisit,
                session: UUID(),
                sessionRevisit: job.successRevisit ?? job.sessionRevisit,
                window: nil
            )
            return
        }
        let minimums = try jobExpression.minimums(granularities: structure.granularities)
        let maximums = try jobExpression.maximums(granularities: structure.granularities)
        guard
            minimums.allSatisfy({ $0.value <= maximums[$0.key] ?? .max }),
            maximums.allSatisfy({ $0.value >= minimums[$0.key] ?? .zero })
        else {
            throw ModelCheckerError.mismatchedConstraints(constraints: [])
        }
        self.init(
            nodeId: job.nodeId,
            expression: Expression.quantified(expression: jobExpression.expression),
            history: [],
            currentBranch: [],
            historyExpression: historyExpression,
            successRevisit: nil,
            failRevisit: job.failRevisit,
            session: UUID(),
            sessionRevisit: job.successRevisit ?? job.sessionRevisit,
            window: ConstrainedWindow(minimums: minimums, maximums: maximums)
        )
    }

    /// Create a new job for a successor.
    /// - Parameters:
    ///   - expression: The expression to use for the new job.
    ///   - successor: The successor to use for the new job.
    ///   - job: The current job.
    convenience init(expression: TCTLParser.Expression, successor: NodeEdge, job: Job) {
        self.init(
            nodeId: successor.destination,
            expression: expression,
            history: job.history.union([job.nodeId]),
            currentBranch: job.currentBranch + [job.nodeId],
            historyExpression: job.historyExpression,
            successRevisit: job.successRevisit,
            failRevisit: job.failRevisit,
            session: job.session,
            sessionRevisit: job.sessionRevisit,
            window: job.window?.addCost(cost: successor.cost)
        )
    }

    /// Add constraints.
    ///
    /// This should never be called.
    convenience init(expression: TCTLParser.Expression, constraints: [ConstrainedStatement], job: Job) {
        fatalError("Should never add constraints!")
        // let allConstraints = constraints.lazy
        // let timeConstraints = allConstraints.filter {
        //     switch $0.constraint {
        //     case .time:
        //         return true
        //     default:
        //         return false
        //     }
        // }
        // let energyConstraints = allConstraints.filter {
        //     switch $0.constraint {
        //     case .energy:
        //         return true
        //     default:
        //         return false
        //     }
        // }
        // self.init(
        //     nodeId: job.nodeId,
        //     expression: expression,
        //     history: job.history,
        //     currentBranch: job.currentBranch,
        //     historyExpression: job.historyExpression,
        //     constraints: constraints,
        //     successRevisit: job.successRevisit,
        //     failRevisit: job.failRevisit,
        //     session: job.session,
        //     sessionRevisit: job.sessionRevisit,
        //     cost: .zero,
        //     timeMinimum: timeConstraints.min { $0.isMinLessThan(value: $1) }?.constraint.quantity ?? .zero,
        //     timeMaximum: timeConstraints.max { $0.isMaxGreaterThan(value: $1) }?.constraint.quantity
        //       ?? .max,
        //     energyMinimum: energyConstraints.min { $0.isMinLessThan(value: $1) }?.constraint.quantity
        //         ?? .zero,
        //     energyMaximum: energyConstraints.max { $0.isMaxGreaterThan(value: $1) }?.constraint.quantity
        //         ?? .max
        // )
    }

    // swiftlint:disable function_body_length

    /// Create a new job for a revisitting expression.
    /// - Parameters:
    ///   - expression: The expression to use for the new job.
    ///   - revisit: The revisitting expression to use for the new job.
    ///   - job: The current job.
    ///   - store: The store to use for storing the new job.
    convenience init<T>(
        expression: TCTLParser.Expression, revisit: RevisitExpression, job: Job, store: inout T
    ) throws where T: JobStorable {
        switch revisit {
        case .ignored:
            let newRevisit = JobData(
                nodeId: job.nodeId,
                expression: expression,
                history: job.history,
                currentBranch: job.currentBranch,
                historyExpression: job.historyExpression,
                successRevisit: job.successRevisit,
                failRevisit: job.failRevisit,
                session: job.session,
                sessionRevisit: job.sessionRevisit,
                window: job.window
            )
            let trueJob = JobData(
                nodeId: job.nodeId,
                expression: .language(expression: .vhdl(expression: .true)),
                history: [],
                currentBranch: [],
                historyExpression: nil,
                successRevisit: job.successRevisit,
                failRevisit: nil,
                session: job.session,
                sessionRevisit: job.sessionRevisit,
                window: nil
            )
            self.init(
                nodeId: job.nodeId,
                expression: revisit.expression,
                history: job.history,
                currentBranch: job.currentBranch,
                historyExpression: job.historyExpression,
                successRevisit: try store.job(forData: newRevisit).id,
                failRevisit: try store.job(forData: trueJob).id,
                session: nil,
                sessionRevisit: nil,
                window: job.window
            )
        case .required:
            let newRevisit = JobData(
                nodeId: job.nodeId,
                expression: expression,
                history: job.history,
                currentBranch: job.currentBranch,
                historyExpression: job.historyExpression,
                successRevisit: job.successRevisit,
                failRevisit: job.failRevisit,
                session: job.session,
                sessionRevisit: job.sessionRevisit,
                window: job.window
            )
            let id = try store.job(forData: newRevisit).id
            self.init(
                nodeId: job.nodeId,
                expression: revisit.expression,
                history: job.history,
                currentBranch: job.currentBranch,
                historyExpression: job.historyExpression,
                successRevisit: id,
                failRevisit: job.failRevisit,
                session: job.session,
                sessionRevisit: job.sessionRevisit,
                window: job.window
            )
        case .skip:
            let newRevisit = JobData(
                nodeId: job.nodeId,
                expression: expression,
                history: job.history,
                currentBranch: job.currentBranch,
                historyExpression: job.historyExpression,
                successRevisit: job.successRevisit,
                failRevisit: job.failRevisit,
                session: job.session,
                sessionRevisit: job.sessionRevisit,
                window: job.window
            )
            let trueJob = JobData(
                nodeId: job.nodeId,
                expression: .language(expression: .vhdl(expression: .true)),
                history: [],
                currentBranch: [],
                historyExpression: nil,
                successRevisit: job.successRevisit,
                failRevisit: nil,
                session: job.session,
                sessionRevisit: job.sessionRevisit,
                window: nil
            )
            self.init(
                nodeId: job.nodeId,
                expression: revisit.expression,
                history: job.history,
                currentBranch: job.currentBranch,
                historyExpression: job.historyExpression,
                successRevisit: try store.job(forData: trueJob).id,
                failRevisit: try store.job(forData: newRevisit).id,
                session: nil,
                sessionRevisit: nil,
                window: job.window
            )
        }
    }

    // swiftlint:enable function_body_length

}

// swiftlint:enable file_length
