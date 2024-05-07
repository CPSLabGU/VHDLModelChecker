// VHDLModelChecker.swift
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

import TCTLParser
import VHDLKripkeStructures
import VHDLParsing

public struct VHDLModelChecker {

    let iterator: KripkeStructureIterator

    public init(structure: KripkeStructure) {
        self.init(iterator: KripkeStructureIterator(structure: structure))
    }

    init(iterator: KripkeStructureIterator) {
        self.iterator = iterator
    }

    public func verify(against specification: Specification) throws -> Bool {
        var requirements = specification.requirements
        var nodes: [Requirement] = []
        var seen: Set<Requirement> = []
        repeat {
            if let nextNode = nodes.popLast() {
                nodes.append(contentsOf: try self.satisfy(node: nextNode, seen: &seen))
                guard nodes.isEmpty else {
                    continue
                }
            }
            if let nextRequirement = requirements.popLast() {
                nodes.append(contentsOf: try self.findNodes(for: nextRequirement, seen: &seen))
            }
        } while !nodes.isEmpty
        return true
    }

    func findNodes(
        for requirement: GloballyQuantifiedExpression, seen: inout Set<Requirement>
    ) throws -> [Requirement] {
        requirement.findNodes(for: nil, seen: &seen, nodes: self.iterator.nodes)
    }

    func satisfy(node: Requirement, seen: inout Set<Requirement>) throws -> [Requirement] {
        guard !seen.contains(node) else {
            return []
        }
        switch node {
        case .now(let requirement):
            guard let req = self.iterator.nodes[requirement.node] else {
                throw VerificationError.missingNode(requirement: node)
            }
            _ = try requirement.requirements.allSatisfy {
                guard $0.evaluate(node: req) else {
                    throw VerificationError.unsatisfied(requirement: node, node: req)
                }
                return true
            }
            seen.insert(node)
            guard let edges = self.iterator.edges[requirement.node] else {
                return []
            }
            return edges.map {
                Requirement.now(
                    requirement: NodeRequirement(node: $0.destination, requirements: requirement.requirements)
                )
            }
            .filter { !seen.contains($0) }
        case .later(let requirement):
            guard let req = self.iterator.nodes[requirement.node] else {
                throw VerificationError.missingNode(requirement: node)
            }
            defer { seen.insert(node) }
            if requirement.requirements.allSatisfy({ $0.evaluate(node: req) }) {
                return []
            }
            guard let edges = self.iterator.edges[requirement.node] else {
                throw VerificationError.unsatisfied(requirement: node, node: req)
            }
            let newNodes = edges.map {
                Requirement.later(
                    requirement: NodeRequirement(node: $0.destination, requirements: requirement.requirements)
                )
            }
            .filter { !seen.contains($0) }
            guard !newNodes.isEmpty else {
                throw VerificationError.unsatisfied(requirement: node, node: req)
            }
            return newNodes
        }
    }

}

enum VerificationError: Error {

    case missingNode(requirement: Requirement)

    case unsatisfied(requirement: Requirement, node: KripkeNode)

    case invalidRequirement(requirement: GloballyQuantifiedExpression)

}
