// TCTLModelCheckerGlobalTests.swift
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

final class TCTLModelCheckerGlobalTests: XCTestCase {

    let a = VariableName(rawValue: "A")!

    let x = VariableName(rawValue: "x")!

    let y = VariableName(rawValue: "y")!

    let z = VariableName(rawValue: "z")!

    // MARK: Always Quantifier.

    func testAlwaysFutureGlobalPasses() {
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
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode],
            edges: [
                aNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: aNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        A G x = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

    func testAlwaysFutureGlobalFails() {
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
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode],
            edges: [
                aNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: aNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        A G x = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testAlwaysFutureFinallyPasses() {
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
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode],
            edges: [
                aNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: aNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        A F x = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

    func testAlwaysFutureFinallyFails() {
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
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode],
            edges: [
                aNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: aNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        A F x = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testAlwaysFutureNextPasses() {
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
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode],
            edges: [
                aNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: aNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        A X x = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

    func testAlwaysNextGlobalFails() {
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
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode],
            edges: [
                aNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: aNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        A X x = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testAlwaysFutureUntilPasses() {
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
            properties: [x: .boolean(value: true), y: .boolean(value: true)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode],
            edges: [
                aNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: aNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        A x = true U y = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

    func testAlwaysFutureUntilFails() {
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
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode],
            edges: [
                aNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: aNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        A x = true U y = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testAlwaysFutureWeakPasses() {
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
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode],
            edges: [
                aNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: aNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        A x = true W y = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

    func testAlwaysFutureWeakFails() {
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
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode],
            edges: [
                aNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: aNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        A x = true W y = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    // MARK: Eventually Quantifier.

    func testEventuallyFutureGlobalPasses() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let initial = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let aNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [initial, aNode, bNode, cNode, dNode],
            edges: [
                initial: [Edge(target: aNode, cost: .zero), Edge(target: dNode, cost: .zero)],
                aNode: [Edge(target: bNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: dNode, cost: .zero)],
                dNode: [Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [initial]
        ))
        let specRaw = """
        // spec:language VHDL

        E G x = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

    func testEventuallyFutureGlobalFails() {
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
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: aNode, cost: .zero)],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode, dNode]
        ))
        let specRaw = """
        // spec:language VHDL

        E G x = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testEventuallyFutureFinallyPasses() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let initial = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let aNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let bNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [initial, aNode, bNode, cNode, dNode],
            edges: [
                initial: [Edge(target: aNode, cost: .zero), Edge(target: dNode, cost: .zero)],
                aNode: [Edge(target: bNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: dNode, cost: .zero)],
                dNode: [Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [initial]
        ))
        let specRaw = """
        // spec:language VHDL

        E F x = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

    func testEventuallyFutureFinallyFails() {
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
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode, dNode],
            edges: [
                aNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: aNode, cost: .zero)],
                dNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [aNode, dNode]
        ))
        let specRaw = """
        // spec:language VHDL

        E F x = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testEventuallyFutureNextPasses() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let initial = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let aNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let bNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [initial, aNode, bNode, cNode, dNode],
            edges: [
                initial: [Edge(target: aNode, cost: .zero), Edge(target: dNode, cost: .zero)],
                aNode: [Edge(target: bNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: dNode, cost: .zero)],
                dNode: [Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [initial]
        ))
        let specRaw = """
        // spec:language VHDL

        E X x = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

    func testEventuallyFutureNextFails() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let initial = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let aNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: true)]
        )
        let bNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: true)]
        )
        let dNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [initial, aNode, bNode, cNode, dNode],
            edges: [
                initial: [Edge(target: aNode, cost: .zero), Edge(target: dNode, cost: .zero)],
                aNode: [Edge(target: bNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: dNode, cost: .zero)],
                dNode: [Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [initial]
        ))
        let specRaw = """
        // spec:language VHDL

        E X x = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testEventuallyFutureWeakPasses() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let initial = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false), z: .boolean(value: false)]
        )
        let aNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false), z: .boolean(value: false)]
        )
        let bNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false), z: .boolean(value: false)]
        )
        let cNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false), z: .boolean(value: false)]
        )
        let dNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false), z: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [initial, aNode, bNode, cNode],
            edges: [
                initial: [Edge(target: aNode, cost: .zero), Edge(target: bNode, cost: .zero)],
                aNode: [Edge(target: bNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: dNode, cost: .zero)],
                dNode: [Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [initial]
        ))
        let specRaw = """
        // spec:language VHDL

        E x = true W y = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

    func testEventuallyFutureWeakFails() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false), z: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false), z: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false), z: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode],
            edges: [
                aNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: aNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        E x = true W y = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }

    func testEventuallyFutureUntilPasses() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let initial = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let aNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let bNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false)]
        )
        let cNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: false), y: .boolean(value: false)]
        )
        let dNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [initial, aNode, bNode, cNode, dNode],
            edges: [
                initial: [Edge(target: aNode, cost: .zero), Edge(target: bNode, cost: .zero)],
                aNode: [Edge(target: bNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: dNode, cost: .zero)],
                dNode: [Edge(target: cNode, cost: .zero)]
            ],
            initialStates: [initial]
        ))
        let specRaw = """
        // spec:language VHDL

        E x = true U y = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
    }

    func testEventuallyFutureUntilFails() {
        let checker = TCTLModelChecker(store: InMemoryDataStore())
        let aNode = Node(
            type: .read,
            currentState: a,
            executeOnEntry: true,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false), z: .boolean(value: false)]
        )
        let bNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false), z: .boolean(value: false)]
        )
        let cNode = Node(
            type: .write,
            currentState: a,
            executeOnEntry: false,
            nextState: a,
            properties: [x: .boolean(value: true), y: .boolean(value: false), z: .boolean(value: true)]
        )
        let iterator = KripkeStructureIterator(structure: KripkeStructure(
            nodes: [aNode, bNode, cNode],
            edges: [
                aNode: [Edge(target: bNode, cost: .zero), Edge(target: cNode, cost: .zero)],
                bNode: [Edge(target: aNode, cost: .zero)],
                cNode: [Edge(target: aNode, cost: .zero)]
            ],
            initialStates: [aNode]
        ))
        let specRaw = """
        // spec:language VHDL

        E x = true U y = true
        """
        let specification = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
    }


}
