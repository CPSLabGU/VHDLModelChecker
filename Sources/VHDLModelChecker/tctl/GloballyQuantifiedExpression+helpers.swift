// GloballyQuantifiedExpression+helpers.swift
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

/// Add verify methods to expression.
extension GloballyQuantifiedExpression {

    /// The history expression of this expression.
    var historyExpression: Expression? {
        switch pathQuantifier {
        case .globally, .finally, .weak, .until:
            return .quantified(expression: self)
        case .next(let expression):
            return expression
        }
    }

    /// The current quantifier of this expression.
    var quantifier: GlobalQuantifiedType {
        switch self {
        case .always:
            return .always
        case .eventually:
            return .eventually
        }
    }

    /// The path quantifier of this expression.
    var pathQuantifier: PathQuantifiedExpression {
        switch self {
        case .always(let expression), .eventually(let expression):
            return expression
        }
    }

    /// Transform the expression into a normalised form.
    ///
    /// The normalised form is an equivalent expression without any `eventaully` quantifiers.
    var normalised: Expression {
        switch self {
        case .always(let expression):
            return .quantified(expression: .always(expression: expression.normalised))
        case .eventually(let path):
            switch path {
            case .globally(let expression):
                // E G e === ! A F !e
                return .not(
                    expression: .quantified(
                        expression: .always(
                            expression: .finally(expression: .not(expression: expression.normalised))
                        )
                    )
                )
            // E F e === ! A G !e
            case .finally(let expression):
                return .not(
                    expression: .quantified(
                        expression: .always(
                            expression: .globally(expression: .not(expression: expression.normalised))
                        )
                    )
                )
            // E X e === ! A X !e
            case .next(let expression):
                return .not(
                    expression: .quantified(
                        expression: .always(
                            expression: .next(expression: .not(expression: expression.normalised))
                        )
                    )
                )
            case .until(let lhs, let rhs):
                let rhsNormalised = rhs.normalised
                // E p U q === ! A !q W !q ^ !p
                return .not(
                    expression: .quantified(
                        expression: .always(
                            expression: .weak(
                                lhs: .not(expression: rhsNormalised),
                                rhs: .conjunction(
                                    lhs: .not(expression: rhsNormalised),
                                    rhs: .not(expression: lhs.normalised)
                                )
                            )
                        )
                    )
                )
            case .weak(let lhs, let rhs):
                let lhsNormalised = lhs.normalised
                let rhsNormalised = rhs.normalised
                // E p W q === E p U q  V  E G p
                // === (! A !q W !q ^ !p)  V  (! A F !p)
                return .disjunction(
                    lhs: .not(
                        expression: .quantified(
                            expression: .always(
                                expression: .weak(
                                    lhs: .not(expression: rhsNormalised),
                                    rhs: .conjunction(
                                        lhs: .not(expression: rhsNormalised),
                                        rhs: .not(expression: lhsNormalised)
                                    )
                                )
                            )
                        )
                    ),
                    rhs: .not(
                        expression: .quantified(
                            expression: .always(
                                expression: .finally(expression: .not(expression: lhsNormalised))
                            )
                        )
                    )
                )
            // newExpression = .not(expression: .quantified(expression: .always(expression: .until(
            //     lhs: .not(expression: lhs), rhs: .not(expression: rhs)
            // ))))
            }
        }
    }

    /// Create an expression from it's quantifier and path quantified expression.
    /// - Parameters:
    ///   - quantifier: The quantifier to apply to the `expression`.
    ///   - expression: The expression constrained by this expression.
    init(quantifier: GlobalQuantifiedType, expression: PathQuantifiedExpression) {
        switch quantifier {
        case .always:
            self = .always(expression: expression)
        case .eventually:
            self = .eventually(expression: expression)
        }
    }

    /// Verify the expression against the `node`.
    func verify(currentNode node: Node, inCycle: Bool) throws -> [VerifyStatus] {
        switch self {
        case .always:
            // A G e :: .noSession(.revisit(A X A G E, .required(e)))
            // A F e :: .noSession(.revisit(A X A F e, .skip(e)))
            // A X e :: .noSession(.succ(e))
            return try self.expression.verify(
                currentNode: node,
                inCycle: inCycle,
                quantifier: self.quantifier
            )
        case .eventually:
            fatalError(
                "Cannot verify eventually quantified expression! Make sure you call `normalised` first."
            )
        }
    }

}
