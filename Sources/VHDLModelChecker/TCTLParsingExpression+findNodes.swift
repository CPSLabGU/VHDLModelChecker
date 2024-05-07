// TCTLParsingExpression+findNodes.swift
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
import VHDLParsing

extension TCTLParser.Expression {

    func findNodes(
        for requirement: GloballyQuantifiedExpression,
        seen: inout Set<Requirement>,
        nodes: [UUID: KripkeNode],
        edges: [UUID: [NodeEdge]],
        exactly: Bool = false,
        _ f: @escaping (UUID, VHDLParsing.Expression) -> Requirement
    ) -> [Requirement] {
        switch self {
        case .implies(let lhs, let rhs):
            let validNodes = lhs.findNodes(
                for: requirement, seen: &seen, nodes: nodes, edges: edges, exactly: true, f
            )
            let allEdges = validNodes.flatMap {
                guard let newEdges: [NodeEdge] = edges[$0.requirement.node] else {
                    fatalError("Missing destination from edge.")
                }
                return newEdges.map { $0.destination }
            }
            let newNodes = Dictionary(uniqueKeysWithValues: Set(allEdges).map {
                guard let node = nodes[$0] else {
                    fatalError("Failed to get nodes!")
                }
                return ($0, node)
            })
            return rhs.findNodes(for: requirement, seen: &seen, nodes: newNodes, edges: edges, f)
        case .vhdl(let expression):
            return expression.findNodes(for: requirement, seen: &seen, nodes: nodes, exactly: exactly, f)
        }
    }

}

extension VHDLExpression {

    func findNodesExactly(
        for requirement: GloballyQuantifiedExpression,
        seen: inout Set<Requirement>,
        nodes: [UUID: KripkeNode],
        _ f: @escaping (UUID, VHDLParsing.Expression) -> Requirement
    ) -> [Requirement] {
        nodes.compactMap { key, val -> Requirement? in
            guard self.expression.evaluate(node: val) else {
                return nil
            }
            return f(key, self.expression)
        }
        .filter { !seen.contains($0) }
    }

    func findNodes(
        for requirement: GloballyQuantifiedExpression,
        seen: inout Set<Requirement>,
        nodes: [UUID: KripkeNode],
        exactly: Bool = false,
        _ f: @escaping (UUID, VHDLParsing.Expression) -> Requirement
    ) -> [Requirement] {
        if exactly {
            return self.findNodesExactly(for: requirement, seen: &seen, nodes: nodes, f)
        }
        let variables = Set(self.allVariables)
        return nodes.compactMap {
            guard $0.value.properties.keys.contains(where: { variables.contains($0) }) else {
                return nil
            }
            return f($0.key, self.expression)
        }
        .filter { !seen.contains($0) }
    }

}

extension SubExpression {

    func findNodes(
        for requirement: GloballyQuantifiedExpression,
        seen: inout Set<Requirement>,
        nodes: [UUID: KripkeNode],
        edges: [UUID: [NodeEdge]],
        _ f: @escaping (UUID, VHDLParsing.Expression) -> Requirement
    ) -> [Requirement] {
        switch self {
        case .quantified(let expression):
            return requirement.findNodes(for: expression, seen: &seen, nodes: nodes, edges: edges)
        case .expression(let expression):
            return expression.findNodes(for: requirement, seen: &seen, nodes: nodes, edges: edges, f)
        }
    }

}

extension GloballyQuantifiedExpression {

    func findNodes(
        for requirement: GloballyQuantifiedExpression? = nil,
        seen: inout Set<Requirement>,
        nodes: [UUID: KripkeNode],
        edges: [UUID: [NodeEdge]]
    ) -> [Requirement] {
        let req1s: [Requirement]
        switch self {
        case .always(let expression):
            switch expression {
            case .globally(let expression):
                req1s = expression.findNodes(for: self, seen: &seen, nodes: nodes, edges: edges) {
                    Requirement.now(requirement: NodeRequirement(node: $0, requirements: [$1]))
                }
                .filter { !seen.contains($0) }
            }
        }
        guard let req2 = requirement else {
            return req1s
        }
        return req1s + req2.findNodes(for: nil, seen: &seen, nodes: nodes, edges: edges)
    }

}
