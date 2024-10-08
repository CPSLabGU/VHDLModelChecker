// TCTLExpression+helpers.swift
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

/// Add helpers.
extension Expression {

    // var granularity: ScientificQuantity? {
    //     switch self {
    //     case .conjunction(let lhs, let rhs), .disjunction(let lhs, let rhs), .implies(let lhs, let rhs):
    //         return [lhs, rhs].compactMap { $0.granularity }.min()
    //     case .not(let expression), .precedence(let expression):
    //         return expression.granularity
    //     case .language:
    //         return nil
    //     case .quantified(let expression):
    //         let path = expression.pathQuantifier
    //         switch path {
    //         case .globally(let expression), .finally(let expression), .next(let expression):
    //             return expression.granularity
    //         case .until(let lhs, let rhs), .weak(let lhs, let rhs):
    //             return [lhs, rhs].compactMap { $0.granularity }.min()
    //         }
    //     case .constrained(let expression):
    //         return expression.granularity
    //     }
    // }

    /// Get the history expression.
    var historyExpression: Expression? {
        switch self {
        case .quantified(let expression):
            return expression.historyExpression
        case .constrained(let expression):
            return expression.expression.historyExpression
        default:
            return nil
        }
    }

    /// The constraints for the expression.
    var constraints: [ConstrainedStatement]? {
        switch self {
        case .constrained(let expression):
            return expression.constraints
        default:
            return nil
        }
    }

    /// Normalise the expression in terms of A's.
    var normalised: Expression {
        switch self {
        case .conjunction(let lhs, let rhs):
            return .conjunction(lhs: lhs.normalised, rhs: rhs.normalised)
        case .constrained(let expression):
            switch expression.expression.normalised {
            case .quantified(let quantified):
                return .constrained(
                    expression: ConstrainedExpression(
                        expression: quantified,
                        constraints: expression.constraints
                    )
                )
            case .not(.quantified(let quantified)):
                return .not(
                    expression: .constrained(
                        expression: ConstrainedExpression(
                            expression: quantified,
                            constraints: expression.constraints
                        )
                    )
                )
            case .disjunction(lhs: .not(.quantified(let lhs)), rhs: .not(.quantified(let rhs))):
                return .disjunction(
                    lhs: .not(
                        expression: .constrained(
                            expression: ConstrainedExpression(
                                expression: lhs,
                                constraints: expression.constraints
                            )
                        )
                    ),
                    rhs: .not(
                        expression: .constrained(
                            expression: ConstrainedExpression(
                                expression: rhs,
                                constraints: expression.constraints
                            )
                        )
                    )
                )
            default:
                fatalError("Cannot normalise invalid constrained expression!\n\(self.rawValue)")
            }
        case .disjunction(let lhs, let rhs):
            return .disjunction(lhs: lhs.normalised, rhs: rhs.normalised)
        case .implies(let lhs, let rhs):
            return .implies(lhs: lhs.normalised, rhs: rhs.normalised)
        case .language(let language):
            return .language(expression: language.normalised)
        case .not(let expression):
            return .not(expression: expression.normalised)
        case .precedence(let expression):
            return .precedence(expression: expression.normalised)
        case .quantified(let expression):
            return expression.normalised
        }
    }

    /// Verify the expression.
    func verify(currentNode node: Node, inCycle: Bool) throws -> [VerifyStatus] {
        // Verifies a node but does not take into consideration successor nodes.
        switch self {
        case .language(let expression):
            try expression.verify(node: node)
            return []
        case .precedence(let expression):
            return try expression.verify(currentNode: node, inCycle: inCycle)
        case .quantified(let expression):
            return try expression.verify(currentNode: node, inCycle: inCycle)
        case .conjunction(let lhs, let rhs):
            return [
                .revisitting(
                    expression: rhs,
                    precondition: .required(expression: lhs)
                )
            ]
        case .disjunction(let lhs, let rhs):
            return [
                .revisitting(
                    expression: rhs,
                    precondition: .skip(expression: lhs)
                )
            ]
        case .not(let expression):
            return [
                .revisitting(
                    expression: .language(
                        expression: .vhdl(
                            expression: .conditional(
                                expression: .literal(value: false)
                            )
                        )
                    ),
                    precondition: .ignored(expression: expression)
                )
            ]
        case .implies(let lhs, let rhs):
            return [
                .revisitting(
                    expression: rhs,
                    precondition: .ignored(expression: lhs)
                )
            ]
        case .constrained(let expression):
            return try expression.verify(currentNode: node, inCycle: inCycle)
        }
    }

}
