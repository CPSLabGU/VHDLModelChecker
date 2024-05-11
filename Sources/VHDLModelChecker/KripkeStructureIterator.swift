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
        let kripkeStructureNodes = structure.nodes.lazy
        var nodes: [UUID: KripkeNode] = [:]
        var edges: [UUID: [NodeEdge]] = [:]
        var ids: [KripkeNode: UUID] = [:]
        var initialStates: Set<UUID> = []
        kripkeStructureNodes.forEach {
            switch $0 {
            case .read(let node):
                let read = KripkeNode.read(node: node)
                let readID: UUID
                if let id = ids[read] {
                    readID = id
                } else {
                    readID = UUID()
                    ids[read] = readID
                    if structure.initialStates.contains($0) {
                        initialStates.insert(readID)
                    }
                }
                nodes[readID] = read
                guard let edge: [Edge] = structure.edges[$0] else {
                    fatalError("No edge found for \(read)")
                }
                let readEdges = edge.map {
                    let writeID: UUID
                    let node = KripkeNode(node: $0.target)
                    if let id = ids[node] {
                        writeID = id
                    } else {
                        writeID = UUID()
                        ids[node] = writeID
                    }
                    return NodeEdge(time: $0.time, energy: $0.energy, destination: writeID)
                }
                guard let currentEdges: [NodeEdge] = edges[readID] else {
                    edges[readID] = readEdges
                    return
                }
                edges[readID] = currentEdges + readEdges
            case .write(let node):
                let write = KripkeNode.write(node: node)
                let writeID: UUID
                if let id = ids[write] {
                    writeID = id
                } else {
                    writeID = UUID()
                    ids[write] = writeID
                }
                nodes[writeID] = write
                guard let edge: [Edge] = structure.edges[$0] else {
                    fatalError("Found accepting statue \($0)")
                }
                let writeEdges: [NodeEdge] = edge.map { (edge: Edge) -> NodeEdge in
                    let readID: UUID
                    let node = KripkeNode(node: edge.target)
                    if let id = ids[node] {
                        readID = id
                    } else {
                        readID = UUID()
                        ids[node] = readID
                    }
                    return NodeEdge(time: edge.time, energy: edge.energy, destination: readID)
                }
                guard let currentEdges: [NodeEdge] = edges[writeID] else {
                    edges[writeID] = writeEdges
                    return
                }
                edges[writeID] = currentEdges + writeEdges
            }
        }
        self.init(nodes: nodes, edges: edges, initialStates: initialStates)
    }

    init(nodes: [UUID: KripkeNode], edges: [UUID: [NodeEdge]], initialStates: Set<UUID>) {
        self.nodes = nodes
        self.edges = edges
        self.initialStates = initialStates
    }

}

extension KripkeNode {

    init(node: Node) {
        switch node {
        case .read(let node):
            self = .read(node: node)
        case .write(let node):
            self = .write(node: node)
        }
    }

}
