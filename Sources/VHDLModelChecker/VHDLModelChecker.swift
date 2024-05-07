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
        repeat {
            if let nextNode = nodes.popLast() {
                nodes.append(contentsOf: try self.satisfy(node: nextNode))
                guard nodes.isEmpty else {
                    continue
                }
            }
            if let nextRequirement = requirements.popLast() {
                nodes.append(contentsOf: try self.findNodes(for: nextRequirement))
            }
        } while !nodes.isEmpty
        return true
    }

    func findNodes(for requirement: GloballyQuantifiedExpression) throws -> [Requirement] {
        switch requirement {
        case .always(let expression):
            switch expression {
            case .globally(let expression):
                switch expression {
                case .implies(let lhs, let rhs):
                    return []
                case .vhdl(let expression):
                    let variables = Set(expression.allVariables)
                    return try self.iterator.nodes.compactMap {
                        guard $0.value.properties.keys.contains(where: { variables.contains($0) }) else {
                            return nil
                        }
                        guard let propertyReq = PropertyRequirement(constraint: expression) else {
                            throw VerificationError.invalidRequirement(requirement: requirement)
                        }
                        let nodeReq = NodeRequirement(node: $0.key, requirements: [propertyReq])
                        return Requirement.now(requirement: nodeReq)
                    }
                }
            }
        }
    }

    func satisfy(node: Requirement) throws -> [Requirement] {
        switch node {
        case .now(let requirement):
            guard let req = self.iterator.nodes[requirement.node] else {
                throw VerificationError.unsatisfied(requirement: node)
            }
            _ = try requirement.requirements.allSatisfy {
                guard $0.requirement(req.properties) else {
                    throw VerificationError.unsatisfied(requirement: node)
                }
                return true
            }
            guard let edges = self.iterator.edges[requirement.node] else {
                return []
            }
            return edges.map {
                Requirement.now(
                    requirement: NodeRequirement(node: $0.destination, requirements: requirement.requirements)
                )
            }
        case .later(let requirement):
            guard let req = self.iterator.nodes[requirement.node] else {
                throw VerificationError.unsatisfied(requirement: node)
            }
            if requirement.requirements.allSatisfy({ $0.requirement(req.properties) }) {
                return []
            }
        }
        throw VerificationError.unsatisfied(requirement: node)
    }

}

enum VerificationError: Error {

    case unsatisfied(requirement: Requirement)

    case invalidRequirement(requirement: GloballyQuantifiedExpression)

}
