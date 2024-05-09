// VHDLExpression+allVariables.swift
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
import VHDLParsing

extension VHDLExpression {

    var allVariables: [Variable] {
        switch self {
        case .boolean(let expression):
            return VHDLParsing.Expression.logical(operation: expression).allVariables.map {
                Variable(rawValue: $0)
            }
        case .conditional(let expression):
            return VHDLParsing.Expression.conditional(condition: expression).allVariables.map {
                Variable(rawValue: $0)
            }
        }
    }

    var expression: VHDLParsing.Expression {
        switch self {
        case .boolean(let expression):
            return .logical(operation: expression)
        case .conditional(let expression):
            return .conditional(condition: expression)
        }
    }

    func verify(node: KripkeNode) throws {
        switch self {
        case .boolean(let expression):
            try expression.verify(node: node)
        case .conditional(let expression):
            try expression.verify(node: node)
        }
    }

}

extension VHDLParsing.Expression {

    func verify(node: KripkeNode) throws {
        switch self {
        case .conditional(let condition):
            try condition.verify(node: node)
        case .logical(let operation):
            try operation.verify(node: node)
        case .precedence(let value):
            try value.verify(node: node)
        case .reference(let variable):
            guard case .variable(let reference) = variable, case .variable(let name) = reference else {
                throw VerificationError.unsatisfied(node: node)
            }
            switch name {
            case .executeOnEntry:
                guard node.executeOnEntry else {
                    throw VerificationError.unsatisfied(node: node)
                }
            default:
                guard let value = node.properties[name]?.boolean, value else {
                    throw VerificationError.unsatisfied(node: node)
                }
            }
        default:
            throw VerificationError.notSupported
        }
    }

}

extension ConditionalExpression {

    func verify(node: KripkeNode) throws {
        switch self {
        case .literal(let value):
            guard value else {
                throw VerificationError.unsatisfied(node: node)
            }
        case .edge:
            throw VerificationError.notSupported
        case .comparison(let comparison):
            try comparison.verify(node: node)
        }
    }

}

extension ComparisonOperation {

    func verify(node: KripkeNode) throws {
        switch self {
        case .equality(let lhs, let rhs):
            guard let variable = lhs.variable else {
                throw VerificationError.unsatisfied(node: node)
            }
            guard variable != .currentState, variable != .executeOnEntry, variable != .nextState else {
                switch variable {
                case .currentState:
                    guard let rhs = rhs.variable, node.currentState == rhs else {
                        throw VerificationError.unsatisfied(node: node)
                    }
                case .executeOnEntry:
                    guard let rhs = rhs.literal?.boolean, node.executeOnEntry == rhs else {
                        throw VerificationError.unsatisfied(node: node)
                    }
                case .nextState:
                    guard let rhs = rhs.variable, node.nextState == rhs else {
                        throw VerificationError.unsatisfied(node: node)
                    }
                default:
                    throw VerificationError.unsatisfied(node: node)
                }
                return
            }
            guard let rhs = rhs.literal, let value = node.properties[variable], value == rhs else {
                throw VerificationError.unsatisfied(node: node)
            }
        case .notEquals(let lhs, let rhs):
            try BooleanExpression.not(
                value: .conditional(condition: .comparison(value: .equality(lhs: lhs, rhs: rhs)))
            )
            .verify(node: node)
        case .greaterThan(let lhs, let rhs):
            guard let variable = lhs.variable, let rhs = rhs.literal else {
                guard
                    let lhs = lhs.literal,
                    let rhs = rhs.variable,
                    let value = node.properties[rhs],
                    lhs > value
                else {
                    throw VerificationError.unsatisfied(node: node)
                }
                return
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
            try BooleanExpression.or(
                lhs: .conditional(condition: .comparison(value: .lessThan(lhs: lhs, rhs: rhs))),
                rhs: .conditional(condition: .comparison(value: .equality(lhs: lhs, rhs: rhs)))
            )
            .verify(node: node)
        }
    }

}

extension BooleanExpression {

    func verify(node: KripkeNode) throws {
        switch self {
        case .and(let lhs, let rhs):
            try lhs.verify(node: node)
            try rhs.verify(node: node)
        case .or(let lhs, let rhs):
            do {
                try lhs.verify(node: node)
            } catch {
                try rhs.verify(node: node)
            }
        case .not(let expression):
            guard (try? expression.verify(node: node)) != nil else {
                return
            }
            throw VerificationError.unsatisfied(node: node)
        case .nand(let lhs, let rhs):
            try BooleanExpression.not(value: .logical(operation: .and(lhs: lhs, rhs: rhs))).verify(node: node)
        case .nor(let lhs, let rhs):
            try BooleanExpression.not(value: .logical(operation: .or(lhs: lhs, rhs: rhs))).verify(node: node)
        case .xor(let lhs, let rhs):
            switch (try? lhs.verify(node: node), try? rhs.verify(node: node)) {
            case (nil, .some), (.some, nil):
                return
            default:
                throw VerificationError.unsatisfied(node: node)
            }
        case .xnor(let lhs, let rhs):
            try BooleanExpression.not(value: .logical(operation: .xor(lhs: lhs, rhs: rhs))).verify(node: node)
        }
    }

}
