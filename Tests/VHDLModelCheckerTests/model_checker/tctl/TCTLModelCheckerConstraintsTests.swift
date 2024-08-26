// TCTLModelCheckerConstraintsTests.swift
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
@testable import VHDLModelChecker
import VHDLParsing
import XCTest

final class TCTLModelCheckerConstraintsTests: XCTestCase {

    let a = VariableName(rawValue: "A")!

    let x = VariableName(rawValue: "x")!

    let y = VariableName(rawValue: "y")!

    let z = VariableName(rawValue: "z")!

    // MARK: Always Global

    func testConstraintsAlwaysFutureGlobalPassesSimple() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .zero)),
                    Edge(target: cNode, cost: Cost(time: .oneus, energy: .zero))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A G x = true}_{t < 2 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsAlwaysFutureGlobalPassesOverlappingWindow() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .tenuJ)),
                    Edge(target: cNode, cost: Cost(time: .oneus, energy: .tenuJ))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .tenuJ))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .tenuJ))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A G x = true}_{E > 5 uJ, t < 2 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsAlwaysFutureGlobalFails() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .zero)),
                    Edge(target: cNode, cost: Cost(time: .oneus, energy: .zero))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A G x = true}_{t < 2 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsAlwaysFutureGlobalFailsOverlappingWindow() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .tenuJ)),
                    Edge(target: cNode, cost: Cost(time: .oneus, energy: .tenuJ))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .tenuJ))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .tenuJ))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A G x = true}_{E > 15 uJ, t <= 10 us, t < 2 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification)) {
            guard let error = $0 as? ModelCheckerError else {
                XCTFail("Expected ModelCheckerError")
                return
            }
            guard case .mismatchedConstraints(let constraints) = error else {
                XCTFail("Expected mismatchedConstraints ModelCheckerError, got \(error)")
                return
            }
            XCTAssertEqual(constraints, [
                ConstrainedStatement.greaterThan(constraint: Constraint.energy(amount: 15, unit: .uJ)),
                ConstrainedStatement.lessThanOrEqual(constraint: Constraint.time(amount: 10, unit: .us)),
                ConstrainedStatement.lessThan(constraint: Constraint.time(amount: 2, unit: .us))
            ])
        }
    }

    // MARK: Always Finally

    func testConstraintsAlwaysFutureFinallyPasses() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .zero)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .zero))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A F x = true}_{t <= 2 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsAlwaysFutureFinallyFailsBadBranch() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .zero)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .zero))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A F x = true}_{t < 2 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsAlwaysFutureFinallyPassesOverlappingWindow() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .tenuJ)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .tenuJ))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .tenuJ))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .tenuJ))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A F x = true}_{E > 5 uJ, t <= 2 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsAlwaysFutureFinallyFailsBadBranchOverlappingWindow() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .tenuJ)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .tenuJ))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .tenuJ))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .tenuJ))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A F x = true}_{E > 5 uJ, t <= 1 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsAlwaysFutureFinallyFails() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .zero)),
                    Edge(target: cNode, cost: Cost(time: .oneus, energy: .zero))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A F x = true}_{t < 2 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsAlwaysFutureFinallyFailsOverlappingWindow() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .tenuJ)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .tenuJ))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .tenuJ))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .tenuJ))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A F x = true}_{t < 10 us, E > 15 uJ, t < 2 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification)) {
            guard let error = $0 as? ModelCheckerError else {
                XCTFail("Expected ModelCheckerError")
                return
            }
            guard case .mismatchedConstraints(let constraints) = error else {
                XCTFail("Expected mismatchedConstraints ModelCheckerError, got \(error)")
                return
            }
            XCTAssertEqual(
                constraints,
                [
                    ConstrainedStatement.lessThan(constraint: Constraint.time(amount: 10, unit: .us)),
                    ConstrainedStatement.greaterThan(constraint: Constraint.energy(amount: 15, unit: .uJ)),
                    ConstrainedStatement.lessThan(constraint: Constraint.time(amount: 2, unit: .us))
                ]
            )
        }
    }

    // MARK: Always Next

    func testConstraintsAlwaysFutureNextPasses() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .zero)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .zero))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A X x = true}_{t >= 0 us, t <= 2 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsAlwaysFutureNextFailsWithBadBranch() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .zero)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .zero))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A X x = true}_{t < 1500 ns}

        {A X x = true}_{t >= 0 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsAlwaysFutureNextPassesOverlappingWindow() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .tenuJ)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .twentyuJ))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A X x = true}_{t <= 2 us, E > 5 uJ, E <= 20 uJ}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsAlwaysFutureNextFailsUnsatisfiedOverlappingWindow() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .tenuJ)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .twentyuJ))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A X x = true}_{t <= 2 us, E > 5 uJ, E <= 20 uJ}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsAlwaysFutureNextFailsBadBranchOverlappingWindow() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .tenuJ)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .twentyuJ))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A X x = true}_{t <= 2 us, E > 5 uJ, E < 20 uJ}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsAlwaysFutureNextFails() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .zero)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .zero))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A X x = true}_{t < 1500 ns}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsAlwaysFutureNextFailsOverlappingWindow() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .tenuJ)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .twentyuJ))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A X x = true}_{t <= 2 us, E > 20 uJ}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))  {
            guard let error = $0 as? ModelCheckerError else {
                XCTFail("Expected ModelCheckerError")
                return
            }
            guard case .mismatchedConstraints(let constraints) = error else {
                XCTFail("Expected mismatchedConstraints ModelCheckerError, got \(error)")
                return
            }
            XCTAssertEqual(
                constraints,
                [
                    ConstrainedStatement.lessThanOrEqual(constraint: Constraint.time(amount: 2, unit: .us)),
                    ConstrainedStatement.greaterThan(constraint: Constraint.energy(amount: 20, unit: .uJ))
                ]
            )
        }
    }

    // MARK: Always Until

    func testConstraintsAlwaysFutureUntilPasses() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .zero)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .zero))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL
        {A x = true U y = true}_{t <= 3 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsAlwaysFutureUntilFailsUnsatisfied() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .zero)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .zero))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL
        {A x = true U y = true}_{t <= 3 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsAlwaysFutureUntilFailsBadBranch() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .zero)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .zero))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A x = true U y = true}_{t < 1500 ns}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsLowerAlwaysFutureUntilPasses() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .zero)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .zero))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A x = true U y = true}_{t >= 3 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsAlwaysFutureUntilFails() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .zero)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .zero))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A x = true U y = true}_{t <= 2 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    // MARK: Always Weak

    func testConstraintsAlwaysFutureWeakPasses() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .zero)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .zero))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A x = true W y = true}_{t < 1500 ns}

        {A x = true W y = true}_{t <= 2 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

    func testConstraintsAlwaysFutureWeakFails() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .zero)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .zero))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {A x = true W y = true}_{t <= 2 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    // MARK: Eventually Next

    func testConstraintsEventuallyFutureNextPassesWithBadBranch() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [
                    Edge(target: bNode, cost: Cost(time: .oneus, energy: .zero)),
                    Edge(target: cNode, cost: Cost(time: .twous, energy: .zero))
                ],
                bNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                cNode: [Edge(target: dNode, cost: Cost(time: .twous, energy: .zero))],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        {E X x = true}_{t < 1500 ns}

        {E X x = true}_{t >= 0 us}
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

}
