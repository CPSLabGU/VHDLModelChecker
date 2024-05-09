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

import Foundation
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

    public func verify(against specification: Specification) throws {
        var requirements = specification.requirements
        var constraints: [Constraint] = []
        var seen: Set<Constraint> = []
        repeat {
            print("Number of reqs: \(requirements.count)")
            // nodes.forEach { print(self.iterator.nodes[$0.requirement.node]!) }
            if let nextConstraint = constraints.popLast() {
                constraints.append(contentsOf: try self.satisfy(constraint: nextConstraint, seen: &seen))
            }
            if let nextRequirement = requirements.popLast() {
                constraints.append(
                    contentsOf: try self.createConstraints(requirement: nextRequirement, seen: &seen)
                )
            }
        } while !requirements.isEmpty || !constraints.isEmpty
    }

    func createConstraints(
        requirement: GloballyQuantifiedExpression, seen: inout Set<Constraint>
    ) throws -> [Constraint] {
        let pathExpression = requirement.expression
        let nodes = try self.validNodes(for: pathExpression)
        return []
    }

    func satisfy(constraint: Constraint, seen: inout Set<Constraint>) throws -> [Constraint] {
        []
    }

    func validNodes(for expression: GloballyQuantifiedExpression) throws -> [UUID] {
        try self.validNodes(for: expression.expression)
    }

    func validNodesExactly(for expression: GloballyQuantifiedExpression) throws -> [UUID] {
        try self.validNodesExactly(for: expression.expression)
    }

    func validNodes(for expression: PathQuantifiedExpression) throws -> [UUID] {
        switch expression {
        case .globally(let expression):
            return try self.validNodes(for: expression)
        default:
            throw VerificationError.notSupported
        }
    }

    func validNodesExactly(for expression: PathQuantifiedExpression) throws -> [UUID] {
        switch expression {
        case .globally(let expression):
            return try self.validNodesExactly(for: expression)
        default:
            throw VerificationError.notSupported
        }
    }

    func validNodes(for expression: TCTLParser.Expression) throws -> [UUID] {
        switch expression {
        case .implies(let lhs, _):
            return try self.validNodesExactly(for: lhs)
        case .language(let expression):
            let allVariables = Set(expression.allVariables)
            guard
                !allVariables.contains(.currentState),
                !allVariables.contains(.nextState),
                !allVariables.contains(.executeOnEntry)
            else {
                return Array(self.iterator.nodes.keys)
            }
            let ids = self.iterator.nodes.filter {
                $0.value.properties.keys.contains { allVariables.contains(Variable(rawValue: $0)) }
            }
            .keys
            return Array(ids)
        case .precedence(let expression):
            return try self.validNodes(for: expression)
        case .quantified(let expression):
            return try self.validNodes(for: expression)
        }
    }

    func validNodesExactly(for expression: TCTLParser.Expression) throws -> [UUID] {
        switch expression {
        case .implies(let lhs, _):
            return try self.validNodesExactly(for: lhs)
        case .language(let expression):
            return try self.validNodesExactly(for: expression)
        case .precedence(let expression):
            return try self.validNodesExactly(for: expression)
        case .quantified(let expression):
            return try self.validNodesExactly(for: expression)
        }
    }

    func validNodesExactly(for expression: LanguageExpression) throws -> [UUID] {
        switch expression {
        case .vhdl(let expression):
            guard let propertyRequirement = PropertyRequirement(constraint: expression) else {
                throw VerificationError.notSupported
            }
            let ids = self.iterator.nodes.filter { propertyRequirement.requirement($0.value) }.keys
            return Array(ids)
        }
    }

}
