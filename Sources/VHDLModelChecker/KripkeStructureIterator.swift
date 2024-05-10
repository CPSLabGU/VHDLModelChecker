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

struct KripkeStructureIterator {

    let nodes: [UUID: KripkeNode]

    let edges: [UUID: [NodeEdge]]

    let initialStates: Set<UUID>

    init(structure: KripkeStructure) {
        let ringlets = structure.ringlets.lazy
        var nodes: [UUID: KripkeNode] = [:]
        var edges: [UUID: [NodeEdge]] = [:]
        var ids: [KripkeNode: UUID] = [:]
        var initialStates: Set<UUID> = []
        ringlets.forEach {
            let read = KripkeNode.read(node: $0.read, currentState: $0.state)
            let write = KripkeNode.write(node: $0.write, currentState: $0.state)
            let writeID: UUID
            if let id = ids[write] {
                writeID = id
            } else {
                writeID = UUID()
                ids[write] = writeID
            }
            nodes[writeID] = write
            let nextReads = ringlets.filter { ringlet in
                let currentWrite = ringlet.write
                return ringlet.state == currentWrite.nextState &&
                    ringlet.read.executeOnEntry == currentWrite.executeOnEntry &&
                    ringlet.read.properties.allSatisfy { key, val -> Bool in
                        guard let writeVal = currentWrite.properties[key] else {
                            return true
                        }
                        return writeVal == val
                    }
            }
            guard !nextReads.isEmpty else {
                fatalError("Found accepting state \(write)")
            }
            let writeEdges = nextReads.map {
                let readID: UUID
                if let id = ids[.read(node: $0.read, currentState: $0.state)] {
                    readID = id
                } else {
                    readID = UUID()
                    ids[.read(node: $0.read, currentState: $0.state)] = readID
                }
                return NodeEdge(edge: Edge(time: 0, energy: 0), destination: readID)
            }
            edges[writeID] = Array(writeEdges)
            let readID: UUID
            if let id = ids[read] {
                readID = id
            } else {
                readID = UUID()
                ids[read] = readID
                if structure.initialStates.contains($0.read) {
                    initialStates.insert(readID)
                }
            }
            nodes[readID] = read
            edges[readID] = [NodeEdge(edge: $0.edge, destination: writeID)]
        }
        self.init(nodes: nodes, edges: edges, initialStates: initialStates)
    }

    init(nodes: [UUID: KripkeNode], edges: [UUID: [NodeEdge]], initialStates: Set<UUID>) {
        self.nodes = nodes
        self.edges = edges
        self.initialStates = initialStates
    }

}
