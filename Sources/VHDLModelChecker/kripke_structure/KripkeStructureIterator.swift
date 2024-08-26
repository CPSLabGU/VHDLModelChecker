// KripkeStructureIterator.swift
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

/// An object storing the kripke structure in-memory and providing easy access to the underlying nodes and
/// edges through identifiers.
struct KripkeStructureIterator {

    /// The nodes in the Kripke structure.
    let nodes: [UUID: Node]

    /// The edges in the Kripke structure.
    let edges: [UUID: [NodeEdge]]

    /// The initial states in the Kripke structure.
    let initialStates: Set<UUID>

    let energyGranularity: ScientificQuantity

    let timeGranularity: ScientificQuantity

    /// Create the iterator from the `VHDLKripkeStructures` format.
    /// - Parameter structure: The kripke structure to store.
    init(structure: KripkeStructure) {
        let kripkeStructureNodes = structure.nodes.lazy
        var nodes: [UUID: Node] = [:]
        var edges: [UUID: [NodeEdge]] = [:]
        var ids: [Node: UUID] = [:]
        var initialStates: Set<UUID> = []
        var minEnergyExponent = Int.max
        var minTimeExponent = Int.max
        kripkeStructureNodes.forEach {
            let myID = ids.value($0)
            if case .read = $0.type, structure.initialStates.contains($0) { initialStates.insert(myID) }
            nodes[myID] = $0
            guard let edge: [Edge] = structure.edges[$0] else {
                fatalError("No edge found for \($0)")
            }
            let newEdges = edge.map {
                NodeEdge(cost: $0.cost, destination: ids.value($0.target))
            }
            let costs = newEdges.map(\.cost)
            let timeCosts = costs.map(\.time).filter { $0.coefficient != 0 }
            let energyCosts = costs.map(\.energy).filter { $0.coefficient != 0 }
            minEnergyExponent = energyCosts.map(\.exponent).min() ?? minEnergyExponent
            minTimeExponent = timeCosts.map(\.exponent).min() ?? minTimeExponent
            guard let currentEdges: [NodeEdge] = edges[myID] else {
                edges[myID] = newEdges
                return
            }
            edges[myID] = currentEdges + newEdges
        }
        let timeGranularity = minTimeExponent != .max
            ? ScientificQuantity(coefficient: 5, exponent: minTimeExponent - 2) : .zero
        let energyGranularity = minEnergyExponent != .max
            ? ScientificQuantity(coefficient: 5, exponent: minEnergyExponent - 2) : .zero
        self.init(
            nodes: nodes,
            edges: edges,
            initialStates: initialStates,
            energyGranularity: energyGranularity,
            timeGranularity: timeGranularity
        )
    }

    /// Initialise the iterator from it's stored properties.
    /// - Parameters:
    ///     - nodes: The nodes in the Kripke structure.
    ///     - edges: The edges in the Kripke structure.
    ///     - initialStates: The initial states in the Kripke structure.
    init(
        nodes: [UUID: Node],
        edges: [UUID: [NodeEdge]],
        initialStates: Set<UUID>,
        energyGranularity: ScientificQuantity,
        timeGranularity: ScientificQuantity
    ) {
        self.nodes = nodes
        self.edges = edges
        self.initialStates = initialStates
        self.energyGranularity = energyGranularity
        self.timeGranularity = timeGranularity
    }

}

/// Add `value` function.
extension Dictionary where Value == UUID {

    /// Access a value at `key` if it exists. If it doesn't, first create the entry in the dictionary before
    /// returning the new result.
    /// - Parameter key: The key to access.
    /// - Returns: The value at `key` or the newly created value at `key`.
    fileprivate mutating func value(_ key: Key) -> UUID {
        if let id = self[key] {
            return id
        } else {
            let id = UUID()
            self[key] = id
            return id
        }
    }

}
