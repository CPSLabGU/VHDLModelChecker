// KripkeStructureIteratorTests.swift
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
import VHDLKripkeStructures
@testable import VHDLModelChecker
import VHDLParsing
import XCTest

/// Test class for ``KripkeStructureIterator``.
final class KripkeStructureIteratorTests: XCTestCase {

    // swiftlint:disable implicitly_unwrapped_optional

    /// The kripke structure to test.
    let kripkeStructure: KripkeStructure = {
        let path = FileManager.default.currentDirectoryPath.appending(
            "/Tests/VHDLModelCheckerTests/output.json"
        )
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path, isDirectory: false)) else {
            fatalError("No data!")
        }
        let decoder = JSONDecoder()
        guard let kripkeStructureParsed = try? decoder.decode(KripkeStructure.self, from: data) else {
            fatalError("Failed to parse kripke structure!")
        }
        return kripkeStructureParsed
    }()

    // swiftlint:enable implicitly_unwrapped_optional

    /// The model checker to use when verifying the specification.
    lazy var iterator = KripkeStructureIterator(structure: kripkeStructure)

    /// Initialise the test data before every test.
    override func setUp() {
        iterator = KripkeStructureIterator(structure: kripkeStructure)
    }

    /// Test the property init.
    func testInit() {
        let newIterator = KripkeStructureIterator(
            nodes: iterator.nodes,
            edges: iterator.edges,
            initialStates: iterator.initialStates,
            energyGranularity: iterator.energyGranularity,
            timeGranularity: iterator.timeGranularity
        )
        XCTAssertEqual(newIterator.nodes, iterator.nodes)
        XCTAssertEqual(newIterator.edges, iterator.edges)
        XCTAssertEqual(newIterator.initialStates, iterator.initialStates)
        XCTAssertEqual(newIterator.energyGranularity, iterator.energyGranularity)
        XCTAssertEqual(newIterator.timeGranularity, iterator.timeGranularity)
    }

    /// Test that the dictionaries are created correctly.
    func testDictionaryCreation() {
        let allNodes = Set(kripkeStructure.nodes)
        let initialStates = kripkeStructure.initialStates
            .compactMap { node in iterator.nodes.first { $0.value == node }?.key }
        XCTAssertEqual(allNodes.count, iterator.nodes.count)
        XCTAssertTrue(allNodes.allSatisfy { iterator.nodes.values.contains($0) })
        XCTAssertTrue(iterator.nodes.keys.allSatisfy { iterator.edges[$0] != nil })
        XCTAssertTrue(initialStates.allSatisfy { iterator.initialStates.contains($0) })
        let edges: [UUID: [NodeEdge]] = Dictionary(
            uniqueKeysWithValues: kripkeStructure.edges.compactMap { node, edges -> (UUID, [NodeEdge])? in
                guard let id = iterator.nodes.first(where: { $0.value == node })?.key else {
                    XCTFail("Failed to store id's")
                    return nil
                }
                let nodeEdges = edges.compactMap { edge -> NodeEdge? in
                    guard
                        let targetID = iterator.nodes.first(
                            where: { $0.value == edge.target }
                        )?.key
                    else {
                        XCTFail("Failed to get target id")
                        return nil
                    }
                    return NodeEdge(cost: edge.cost, destination: targetID)
                }
                return (id, nodeEdges.sorted())
            }
        )
        let expectedEdges = Dictionary(
            uniqueKeysWithValues: iterator.edges.map { ($0.key, $0.value.sorted()) }
        )
        XCTAssertEqual(expectedEdges, edges)
    }

}

/// Add comparable.
extension NodeEdge: Comparable {

    /// Comparable conformance.
    public static func < (lhs: NodeEdge, rhs: NodeEdge) -> Bool {
        lhs.cost.energy.quantity < rhs.cost.energy.quantity
            || lhs.cost.time.quantity < rhs.cost.time.quantity
            || lhs.destination.uuidString < rhs.destination.uuidString
    }

}
