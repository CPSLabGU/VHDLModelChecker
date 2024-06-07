// ComparisonOperation+verify.swift
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

import VHDLKripkeStructures
import VHDLParsing

/// Add `verify` method.
extension ComparisonOperation {

    /// Verify the `node` against this expression. This method will throw a ``VerificationError`` if the
    /// node fails to verify.
    /// - Parameter node: The node to verify against.
    /// - Throws: A ``VerificationError`` if the node violates the expression.
    func verify(node: Node) throws {
        switch self {
        case .equality(let lhs, let rhs):
            try self.verifyEquality(node: node, lhs: lhs, rhs: rhs)
        case .notEquals(let lhs, let rhs):
            try BooleanExpression.not(
                value: .conditional(condition: .comparison(value: .equality(lhs: lhs, rhs: rhs)))
            )
            .verify(node: node)
        case .greaterThan(let lhs, let rhs):
            guard let variable = lhs.variable, let rhs = rhs.literal else {
                throw UnrecoverableError.notSupported
            }
            guard let value = node.properties[variable], value > rhs else {
                throw VerificationError.unsatisfied(node: node)
            }
        case .greaterThanOrEqual(let lhs, let rhs):
            try BooleanExpression.or(
                lhs: .conditional(condition: .comparison(value: .greaterThan(lhs: lhs, rhs: rhs))),
                rhs: .conditional(condition: .comparison(value: .equality(lhs: lhs, rhs: rhs)))
            )
            .verify(node: node)
        case .lessThan(let lhs, let rhs):
            try BooleanExpression.not(value: .conditional(condition: .comparison(value: .greaterThanOrEqual(
                lhs: lhs, rhs: rhs
            ))))
            .verify(node: node)
        case .lessThanOrEqual(let lhs, let rhs):
            try BooleanExpression.not(
                value: .conditional(condition: .comparison(value: .greaterThan(lhs: lhs, rhs: rhs)))
            )
            .verify(node: node)
        }
    }

    /// Verify the equality of the `lhs` and `rhs` expressions against the `node`.
    /// - Parameters:
    ///   - node: The node to verify the equality expression against.
    ///   - lhs: The left-hand side of the equality expression.
    ///   - rhs: The right-hand side of the equality expression.
    /// - Throws: A ``VerificationError`` if the node violates the equality expression.
    private func verifyEquality(node: Node, lhs: Expression, rhs: Expression) throws {
        let lhsValue = try NameOrValue(key: lhs, node: node)
        switch lhsValue {
        case .name(let name):
            guard let rhsValue = rhs.variable, name == rhsValue else {
                throw VerificationError.unsatisfied(node: node)
            }
        case .value(let literal):
            guard let rhsLiteral = rhs.literal else {
                throw UnrecoverableError.notSupported
            }
            guard rhsLiteral == literal else {
                throw VerificationError.unsatisfied(node: node)
            }
        }
    }

}

/// A name or value.
private enum NameOrValue: Equatable {

    /// A name.
    case name(_ name: VariableName)

    /// A value.
    case value(_ value: SignalLiteral)

    init(key variable: Expression, node: Node) throws {
        guard let variable = variable.variable else {
            throw UnrecoverableError.notSupported
        }
        switch variable {
        case .currentState:
            self = .name(node.currentState)
        case .executeOnEntry:
            self = .value(.boolean(value: node.executeOnEntry))
        case .nextState:
            self = .name(node.nextState)
        default:
            guard let literal = node.properties[variable] else {
                throw UnrecoverableError.internalError
            }
            self = .value(literal)
        }
    }

}
