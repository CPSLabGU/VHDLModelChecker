// TCTLExpressionVerifyTests.swift
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
@testable import VHDLModelChecker
import VHDLParsing
import XCTest

// swiftlint:disable file_length
// swiftlint:disable type_body_length

/// Test class for the `verify` method on the `TCTLParser.Expression` enum.
final class TCTLExpressionVerifyTests: XCTestCase {

    /// The kripke structure to test.
    let kripkeStructure = {
        let path = FileManager.default.currentDirectoryPath.appending(
            "/Tests/VHDLModelCheckerTests/output.json"
        )
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path, isDirectory: false)) else {
            fatalError("No data!")
        }
        let decoder = JSONDecoder()
        guard let kripkeStructureParsed = try? decoder.decode(KripkeStructure.self, from: data) else {
            fatalError("Failed to parse kripke structure!")
        }
        return kripkeStructureParsed
    }()

    /// An expression that evaluates to `true` for `failureCount2Node`.
    let trueExp = LanguageExpression.vhdl(expression: .conditional(expression: .comparison(value: .equality(
        lhs: .reference(variable: .variable(reference: .variable(name: .failureCount))),
        rhs: .literal(value: .integer(value: 2))
    ))))

    /// An expression that evaluates to `false` for `failureCount2Node`.
    let falseExp = LanguageExpression.vhdl(expression: .conditional(expression: .comparison(value: .equality(
        lhs: .reference(variable: .variable(reference: .variable(name: .failureCount))),
        rhs: .literal(value: .integer(value: 3))
    ))))

    /// A X <trueExp>
    var nextTrue: TCTLParser.Expression {
        .quantified(
            expression: .always(expression: .next(expression: .language(expression: trueExp)))
        )
    }

    /// A X <falseExp>
    var nextFalse: TCTLParser.Expression {
        .quantified(
            expression: .always(expression: .next(expression: .language(expression: falseExp)))
        )
    }

    /// A G <trueExp>
    var globallyTrue: TCTLParser.Expression {
        .quantified(
            expression: .always(expression: .globally(expression: .language(expression: trueExp)))
        )
    }

    /// A G <falseExp>
    var globallyFalse: TCTLParser.Expression {
        .quantified(
            expression: .always(expression: .globally(expression: .language(expression: falseExp)))
        )
    }

    /// A F <trueExp>
    var finallyTrue: TCTLParser.Expression {
        .quantified(
            expression: .always(expression: .finally(expression: .language(expression: trueExp)))
        )
    }

    /// A F <falseExp>
    var finallyFalse: TCTLParser.Expression {
        .quantified(
            expression: .always(expression: .finally(expression: .language(expression: falseExp)))
        )
    }

    // swiftlint:disable implicitly_unwrapped_optional

    /// A node with a failure count of 3.
    var failureCount2Node: KripkeNode! {
        kripkeStructure.nodes.lazy.compactMap { (node: Node) -> KripkeNode? in
            guard node.properties[.failureCount] == .integer(value: 2) else {
                return nil
            }
            return KripkeNode(node: node)
        }
        .first
    }

    // swiftlint:enable implicitly_unwrapped_optional

    /// Test that language expression verifies correctly.
    func testLanguageVerify() throws {
        let result = try TCTLParser.Expression.language(expression: trueExp)
                .verify(currentNode: failureCount2Node, inCycle: false)
        XCTAssertEqual(result, [.completed])
        XCTAssertThrowsError(
            try TCTLParser.Expression.language(expression: falseExp)
                .verify(currentNode: failureCount2Node, inCycle: false)
        )
    }

    /// Test that the precedence expression verifies correctly.
    func testPrecedence() throws {
        let result = try TCTLParser.Expression.precedence(expression: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false)
        XCTAssertEqual(result, [.completed])
        XCTAssertThrowsError(
            try TCTLParser.Expression.precedence(expression: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false)
        )
    }

    /// Test that the `quantified` case verifies correctly.
    func testQuantified() throws {
        XCTAssertEqual(
            try TCTLParser.Expression.quantified(
                expression: .always(expression: .globally(expression: .language(expression: trueExp)))
            )
            .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .successor(expression: .quantified(expression: .always(
                    expression: .globally(expression: .language(expression: trueExp))
                )))
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.quantified(
                expression: .always(expression: .finally(expression: .language(expression: trueExp)))
            )
            .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.quantified(
                expression: .always(expression: .next(expression: .language(expression: trueExp)))
            )
            .verify(currentNode: failureCount2Node, inCycle: false),
            [.successor(expression: .language(expression: trueExp))]
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.quantified(
                expression: .always(expression: .globally(expression: .language(expression: falseExp)))
            )
            .verify(currentNode: failureCount2Node, inCycle: false)
        )
        XCTAssertEqual(
            try TCTLParser.Expression.quantified(
                expression: .always(expression: .finally(expression: .language(expression: falseExp)))
            )
            .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .successor(expression: .quantified(expression: .always(
                    expression: .finally(expression: .language(expression: falseExp))
                )))
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.quantified(
                expression: .always(expression: .next(expression: .language(expression: falseExp)))
            )
            .verify(currentNode: failureCount2Node, inCycle: false),
            [.successor(expression: .language(expression: falseExp))]
        )
    }

    // swiftlint:disable function_body_length

    /// Test the implies case verifies correctly for simple cases.
    func testImplies() throws {
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(
                lhs: .language(expression: trueExp), rhs: .language(expression: falseExp)
            )
            .verify(currentNode: failureCount2Node, inCycle: true)
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(
                lhs: .language(expression: trueExp), rhs: .language(expression: falseExp)
            )
            .verify(currentNode: failureCount2Node, inCycle: false)
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(
                lhs: .language(expression: trueExp), rhs: .language(expression: trueExp)
            )
            .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(
                lhs: .language(expression: trueExp), rhs: .language(expression: trueExp)
            )
            .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(
                lhs: .language(expression: falseExp), rhs: .language(expression: trueExp)
            )
            .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(
                lhs: .language(expression: falseExp), rhs: .language(expression: trueExp)
            )
            .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(
                lhs: .language(expression: falseExp), rhs: .language(expression: falseExp)
            )
            .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(
                lhs: .language(expression: falseExp), rhs: .language(expression: falseExp)
            )
            .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
    }

    /// Test the implies case verifies correctly for successor expressions.
    func testImpliesProgressive() throws {
        XCTAssertEqual(
            try TCTLParser.Expression.implies(
                lhs: nextTrue, rhs: .language(expression: falseExp)
            )
            .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .language(expression: falseExp),
                    successors: [.skip(expression: .language(expression: trueExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(
                lhs: nextTrue, rhs: .language(expression: falseExp)
            )
            .verify(currentNode: failureCount2Node, inCycle: true),
            [
                .revisitting(
                    expression: .language(expression: falseExp),
                    successors: [.skip(expression: .language(expression: trueExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(
                lhs: nextTrue, rhs: .language(expression: trueExp)
            )
            .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .language(expression: trueExp),
                    successors: [.skip(expression: .language(expression: trueExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(
                lhs: nextTrue, rhs: .language(expression: trueExp)
            )
            .verify(currentNode: failureCount2Node, inCycle: true),
            [
                .revisitting(
                    expression: .language(expression: trueExp),
                    successors: [.skip(expression: .language(expression: trueExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(
                lhs: nextFalse, rhs: .language(expression: trueExp)
            )
            .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .language(expression: trueExp),
                    successors: [.skip(expression: .language(expression: falseExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(
                lhs: nextFalse, rhs: .language(expression: trueExp)
            )
            .verify(currentNode: failureCount2Node, inCycle: true),
            [
                .revisitting(
                    expression: .language(expression: trueExp),
                    successors: [.skip(expression: .language(expression: falseExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(
                lhs: nextFalse, rhs: .language(expression: falseExp)
            )
            .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .language(expression: falseExp),
                    successors: [.skip(expression: .language(expression: falseExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(
                lhs: nextFalse, rhs: .language(expression: falseExp)
            )
            .verify(currentNode: failureCount2Node, inCycle: true),
            [
                .revisitting(
                    expression: .language(expression: falseExp),
                    successors: [.skip(expression: .language(expression: falseExp))]
                )
            ]
        )
    }

    /// Test the implies verifies correctly when creating revisitting states from next expressions.
    func testImpliesRevisittingNext() throws {
        let lhs = TCTLParser.Expression.implies(lhs: nextTrue, rhs: .language(expression: trueExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: trueExp), rhs: .language(expression: trueExp)
                    ),
                    successors: [.skip(expression: .language(expression: trueExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: true),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: trueExp), rhs: .language(expression: trueExp)
                    ),
                    successors: [.skip(expression: .language(expression: trueExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: trueExp), rhs: .language(expression: falseExp)
                    ),
                    successors: [.skip(expression: .language(expression: trueExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: true),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: trueExp), rhs: .language(expression: falseExp)
                    ),
                    successors: [.skip(expression: .language(expression: trueExp))]
                )
            ]
        )
        let lhs2 = TCTLParser.Expression.implies(lhs: nextTrue, rhs: .language(expression: falseExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: falseExp), rhs: .language(expression: trueExp)
                    ),
                    successors: [.skip(expression: .language(expression: trueExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: true),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: falseExp), rhs: .language(expression: trueExp)
                    ),
                    successors: [.skip(expression: .language(expression: trueExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: falseExp), rhs: .language(expression: falseExp)
                    ),
                    successors: [.skip(expression: .language(expression: trueExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: true),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: falseExp), rhs: .language(expression: falseExp)
                    ),
                    successors: [.skip(expression: .language(expression: trueExp))]
                )
            ]
        )
        let lhs3 = TCTLParser.Expression.implies(lhs: nextFalse, rhs: .language(expression: trueExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: trueExp), rhs: .language(expression: trueExp)
                    ),
                    successors: [.skip(expression: .language(expression: falseExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: true),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: trueExp), rhs: .language(expression: trueExp)
                    ),
                    successors: [.skip(expression: .language(expression: falseExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: trueExp), rhs: .language(expression: falseExp)
                    ),
                    successors: [.skip(expression: .language(expression: falseExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: true),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: trueExp), rhs: .language(expression: falseExp)
                    ),
                    successors: [.skip(expression: .language(expression: falseExp))]
                )
            ]
        )
        let lhs4 = TCTLParser.Expression.implies(lhs: nextFalse, rhs: .language(expression: falseExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: falseExp), rhs: .language(expression: trueExp)
                    ),
                    successors: [.skip(expression: .language(expression: falseExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: true),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: falseExp), rhs: .language(expression: trueExp)
                    ),
                    successors: [.skip(expression: .language(expression: falseExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: falseExp), rhs: .language(expression: falseExp)
                    ),
                    successors: [.skip(expression: .language(expression: falseExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: true),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: falseExp), rhs: .language(expression: falseExp)
                    ),
                    successors: [.skip(expression: .language(expression: falseExp))]
                )
            ]
        )
    }

    /// Test the implies verifies correctly when creating revisitting states from global expressions.
    func testImpliesGlobally() throws {
        let lhs = TCTLParser.Expression.implies(lhs: globallyTrue, rhs: .language(expression: trueExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: trueExp), rhs: .language(expression: trueExp)
                    ),
                    successors: [
                        .skip(expression: .quantified(expression: .always(expression: .globally(
                            expression: .language(expression: trueExp)
                        ))))
                    ]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: trueExp), rhs: .language(expression: falseExp)
                    ),
                    successors: [
                        .skip(expression: .quantified(expression: .always(expression: .globally(
                            expression: .language(expression: trueExp)
                        ))))
                    ]
                )
            ]
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: true)
        )
        let lhs2 = TCTLParser.Expression.implies(lhs: globallyTrue, rhs: .language(expression: falseExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: falseExp), rhs: .language(expression: trueExp)
                    ),
                    successors: [
                        .skip(expression: .quantified(expression: .always(expression: .globally(
                            expression: .language(expression: trueExp)
                        ))))
                    ]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: falseExp), rhs: .language(expression: falseExp)
                    ),
                    successors: [
                        .skip(expression: .quantified(expression: .always(expression: .globally(
                            expression: .language(expression: trueExp)
                        ))))
                    ]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let lhs3 = TCTLParser.Expression.implies(lhs: globallyFalse, rhs: .language(expression: trueExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false)
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: true)
        )
        let lhs4 = TCTLParser.Expression.implies(lhs: globallyFalse, rhs: .language(expression: falseExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false)
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: true)
        )
    }

    /// Test the implies verifies correctly when creating revisitting states from finally expressions.
    func testImpliesFinally() throws {
        let lhs = TCTLParser.Expression.implies(lhs: finallyTrue, rhs: .language(expression: trueExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false)
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: true)
        )
        let lhs2 = TCTLParser.Expression.implies(lhs: finallyTrue, rhs: .language(expression: falseExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let lhs3 = TCTLParser.Expression.implies(lhs: finallyFalse, rhs: .language(expression: trueExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: trueExp), rhs: .language(expression: trueExp)
                    ),
                    successors: [
                        .skip(expression: .quantified(expression: .always(expression: .finally(
                            expression: .language(expression: falseExp)
                        ))))
                    ]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: trueExp), rhs: .language(expression: falseExp)
                    ),
                    successors: [
                        .skip(expression: .quantified(expression: .always(expression: .finally(
                            expression: .language(expression: falseExp)
                        ))))
                    ]
                )
            ]
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: true)
        )
        let lhs4 = TCTLParser.Expression.implies(lhs: finallyFalse, rhs: .language(expression: falseExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: falseExp), rhs: .language(expression: trueExp)
                    ),
                    successors: [
                        .skip(expression: .quantified(expression: .always(expression: .finally(
                            expression: .language(expression: falseExp)
                        ))))
                    ]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .implies(
                        lhs: .language(expression: falseExp), rhs: .language(expression: falseExp)
                    ),
                    successors: [
                        .skip(expression: .quantified(expression: .always(expression: .finally(
                            expression: .language(expression: falseExp)
                        ))))
                    ]
                )
            ]
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: true)
        )
    }

    /// Test the implies verifies correctly when creating revisitting states from next expressions in the rhs.
    func testImpliesRevisittingNextRhs() throws {
        let lhsTrue = TCTLParser.Expression.language(expression: trueExp)
        let lhsFalse = TCTLParser.Expression.language(expression: falseExp)
        let rhs = TCTLParser.Expression.implies(lhs: nextTrue, rhs: .language(expression: trueExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .language(expression: trueExp),
                    successors: [.skip(expression: .language(expression: trueExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [
                .revisitting(
                    expression: .language(expression: trueExp),
                    successors: [.skip(expression: .language(expression: trueExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let rhs2 = TCTLParser.Expression.implies(lhs: nextTrue, rhs: .language(expression: falseExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .language(expression: falseExp),
                    successors: [.skip(expression: .language(expression: trueExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [
                .revisitting(
                    expression: .language(expression: falseExp),
                    successors: [.skip(expression: .language(expression: trueExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let rhs3 = TCTLParser.Expression.implies(lhs: nextFalse, rhs: .language(expression: trueExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .language(expression: trueExp),
                    successors: [.skip(expression: .language(expression: falseExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [
                .revisitting(
                    expression: .language(expression: trueExp),
                    successors: [.skip(expression: .language(expression: falseExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let rhs4 = TCTLParser.Expression.implies(lhs: nextFalse, rhs: .language(expression: falseExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .language(expression: falseExp),
                    successors: [.skip(expression: .language(expression: falseExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [
                .revisitting(
                    expression: .language(expression: falseExp),
                    successors: [.skip(expression: .language(expression: falseExp))]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
    }

// MARK: - Globally RHS.

    /// Test the implies verifies correctly when creating revisitting states from globally expressions in the
    /// rhs.
    /// <T | F> -> (A G <T | F> -> <T | F>)
    func testImpliesRevisittingGloballyRhs() throws {
        let lhsTrue = TCTLParser.Expression.language(expression: trueExp)
        let lhsFalse = TCTLParser.Expression.language(expression: falseExp)
        let rhs = TCTLParser.Expression.implies(lhs: globallyTrue, rhs: .language(expression: trueExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .language(expression: trueExp),
                    successors: [
                        .skip(expression: .quantified(
                            expression: .always(expression: .globally(expression: lhsTrue))
                        ))
                    ]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let rhs2 = TCTLParser.Expression.implies(lhs: globallyTrue, rhs: .language(expression: falseExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .language(expression: falseExp),
                    successors: [
                        .skip(expression: .quantified(
                            expression: .always(expression: .globally(expression: lhsTrue))
                        ))
                    ]
                )
            ]
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: true)
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let rhs3 = TCTLParser.Expression.implies(lhs: globallyFalse, rhs: .language(expression: trueExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let rhs4 = TCTLParser.Expression.implies(lhs: globallyFalse, rhs: .language(expression: falseExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
    }

// MARK: - Finally RHS.

    /// Test the implies verifies correctly when creating revisitting states from finally expressions in the
    /// rhs.
    /// <T | F> -> (A F <T | F> -> <T | F>)
    func testImpliesRevisittingFinallyRHS() throws {
        let lhsTrue = TCTLParser.Expression.language(expression: trueExp)
        let lhsFalse = TCTLParser.Expression.language(expression: falseExp)
        let rhs = TCTLParser.Expression.implies(lhs: finallyTrue, rhs: .language(expression: trueExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let rhs2 = TCTLParser.Expression.implies(lhs: finallyTrue, rhs: .language(expression: falseExp))
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: false)
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: true)
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let rhs3 = TCTLParser.Expression.implies(lhs: finallyFalse, rhs: .language(expression: trueExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .language(expression: trueExp),
                    successors: [
                        .skip(expression: .quantified(
                            expression: .always(expression: .finally(expression: lhsFalse))
                        ))
                    ]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let rhs4 = TCTLParser.Expression.implies(lhs: finallyFalse, rhs: .language(expression: falseExp))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: .language(expression: falseExp),
                    successors: [
                        .skip(expression: .quantified(
                            expression: .always(expression: .finally(expression: lhsFalse))
                        ))
                    ]
                )
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
    }

    /// Test the implies verifies correctly when creating revisitting states from next expressions in the rhs
    /// most value.
    /// <T | F> -> (<T | F> -> A X <T | F>)
    func testImpliesRevisittingNextRHS() throws {
        let lhsTrue = TCTLParser.Expression.language(expression: trueExp)
        let lhsFalse = TCTLParser.Expression.language(expression: falseExp)
        let rhs = TCTLParser.Expression.implies(lhs: .language(expression: trueExp), rhs: nextTrue)
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.successor(expression: lhsTrue)]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.successor(expression: lhsTrue)]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let rhs2 = TCTLParser.Expression.implies(lhs: .language(expression: falseExp), rhs: nextTrue)
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let rhs3 = TCTLParser.Expression.implies(lhs: .language(expression: trueExp), rhs: nextFalse)
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.successor(expression: lhsFalse)]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.successor(expression: lhsFalse)]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let rhs4 = TCTLParser.Expression.implies(lhs: .language(expression: falseExp), rhs: nextFalse)
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsTrue, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhsFalse, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
    }

    /// Test the implies verifies correctly when creating revisitting states from next expressions in the lhs
    /// most value.
    /// (<T | F> -> A X <T | F>) -> <T | F>
    func testImpliesRevisittingNextLHS() throws {
        let rhsTrue = TCTLParser.Expression.language(expression: trueExp)
        let rhsFalse = TCTLParser.Expression.language(expression: falseExp)
        let lhs = TCTLParser.Expression.implies(lhs: .language(expression: trueExp), rhs: nextTrue)
        XCTAssertEqual(
            // (P -> AX Q) -> R
            // succ(T) = undefined
            // succ(AX Q) = Q
            // where P = T
            //  AX Q -> R
            //  revisit(R): succ(AX Q) <- skip on failure.
            //  revisit(R): Q <- skip on failure...

            // (A -> B) -> R
            // revist(B -> R): succ(A) <- skip on failure.
            // revisit(R): !succ(A)    <- skip on failure.

            // A -> (B -> R)
            // revisit(B -> R): succ(A) <- skip on failure...

            // A -> B
            // revisit(B): succ(A) <- skip on failure...

            // (A -> B) -> (C -> D)
            // revisit(B -> (C -> D)): succ(A) <- skip on failure...
            // revisit(C -> D): !succ(A) <- skip on failure... 

            // (P -> A X Q) -> R
            // revisit(R): Q -> Q

            // (P -> A G Q) -> R
            // revisit(R): A G Q -> A G Q
            // (P -> A G Q) -> R = 

            // (P -> Q) -> R
            // 0     0     0    T
            // 0     0     1    T
            // 0     1     0    T
            // 0     1     1    T
            // 1     0     0    T
            // 1     0     1    T
            // 1     1     0    F
            // 1     1     1    T

            // P -> P
            // 0    0    T
            // 1    1    T
            try TCTLParser.Expression.implies(lhs: lhs, rhs: rhsTrue)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(expression: rhsTrue, successors: [.skip(expression: rhsTrue)])
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: rhsTrue)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.revisitting(expression: rhsTrue, successors: [.skip(expression: rhsTrue)])]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: rhsFalse)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.revisitting(expression: rhsFalse, successors: [.skip(expression: rhsTrue)])]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: rhsFalse)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.revisitting(expression: rhsFalse, successors: [.skip(expression: rhsTrue)])]
        )
        let lhs2 = TCTLParser.Expression.implies(lhs: .language(expression: falseExp), rhs: nextTrue)
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: rhsTrue)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: rhsTrue)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: rhsFalse)
                .verify(currentNode: failureCount2Node, inCycle: false)
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: rhsFalse)
                .verify(currentNode: failureCount2Node, inCycle: true)
        )
        let lhs3 = TCTLParser.Expression.implies(lhs: .language(expression: trueExp), rhs: nextFalse)
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: rhsTrue)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.revisitting(expression: rhsTrue, successors: [.skip(expression: rhsFalse)])]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: rhsTrue)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.revisitting(expression: rhsTrue, successors: [.skip(expression: rhsFalse)])]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: rhsFalse)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.revisitting(expression: rhsFalse, successors: [.skip(expression: rhsFalse)])]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: rhsFalse)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.revisitting(expression: rhsFalse, successors: [.skip(expression: rhsFalse)])]
        )
        let lhs4 = TCTLParser.Expression.implies(lhs: .language(expression: falseExp), rhs: nextFalse)
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: rhsTrue)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: rhsTrue)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: rhsFalse)
                .verify(currentNode: failureCount2Node, inCycle: false)
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: rhsFalse)
                .verify(currentNode: failureCount2Node, inCycle: true)
        )
    }

    /// Test the implies verifies correctly when creating revisitting states from globally expressions in the
    /// lhs most value.
    /// <T | F> -> (<T | F> -> A G <T | F>)
    func testImpliesRevisittingGloballyLHS() throws {
        let trueExp = TCTLParser.Expression.language(expression: trueExp)
        let falseExp = TCTLParser.Expression.language(expression: falseExp)
        let rhs = TCTLParser.Expression.implies(lhs: trueExp, rhs: globallyTrue)
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: trueExp, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.successor(expression: globallyTrue)]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: trueExp, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: falseExp, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: falseExp, rhs: rhs)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let rhs2 = TCTLParser.Expression.implies(lhs: falseExp, rhs: globallyTrue)
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: trueExp, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: trueExp, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: falseExp, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: falseExp, rhs: rhs2)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let rhs3 = TCTLParser.Expression.implies(lhs: trueExp, rhs: globallyFalse)
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: trueExp, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: false)
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: trueExp, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: true)
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: falseExp, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: falseExp, rhs: rhs3)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let rhs4 = TCTLParser.Expression.implies(lhs: falseExp, rhs: globallyFalse)
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: trueExp, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: trueExp, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: falseExp, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: falseExp, rhs: rhs4)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let rhs5 = TCTLParser.Expression.quantified(expression: .always(expression: .globally(
            expression: .implies(lhs: trueExp, rhs: globallyTrue)
        )))
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: trueExp, rhs: rhs5)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.successor(expression: globallyTrue), .successor(expression: rhs5)]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: trueExp, rhs: rhs5)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: falseExp, rhs: rhs5)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: falseExp, rhs: rhs5)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        // true -> (AG (AG true -> true))
        let rhs6 = TCTLParser.Expression.quantified(expression: .always(expression: .globally(
            expression: .implies(lhs: globallyTrue, rhs: trueExp)
        )))
        XCTAssertEqual(
            try rhs6.verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(expression: trueExp, successors: [.skip(expression: globallyTrue)]),
                .successor(expression: rhs6)
            ]
        )
        XCTAssertEqual(
            try rhs6.verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: trueExp, rhs: rhs6)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(expression: trueExp, successors: [.skip(expression: globallyTrue)]),
                .successor(expression: rhs6)
            ]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: trueExp, rhs: rhs6)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: falseExp, rhs: rhs6)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: falseExp, rhs: rhs6)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
    }

    /// (<T | F> -> A G <T | F>) -> <T | F>
    func testImpliesRevisittingGloballyRHS() throws {
        let trueExp = TCTLParser.Expression.language(expression: trueExp)
        let falseExp = TCTLParser.Expression.language(expression: falseExp)
        let lhs = TCTLParser.Expression.implies(lhs: trueExp, rhs: globallyTrue)
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: trueExp)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.revisitting(expression: trueExp, successors: [.skip(expression: globallyTrue)])]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: trueExp)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: falseExp)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.revisitting(expression: falseExp, successors: [.skip(expression: globallyTrue)])]
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: falseExp)
                .verify(currentNode: failureCount2Node, inCycle: true)
        )
        let lhs2 = TCTLParser.Expression.implies(lhs: falseExp, rhs: globallyTrue)
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: trueExp)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: trueExp)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: falseExp)
                .verify(currentNode: failureCount2Node, inCycle: false)
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhs2, rhs: falseExp)
                .verify(currentNode: failureCount2Node, inCycle: true)
        )
        let lhs3 = TCTLParser.Expression.implies(lhs: trueExp, rhs: globallyFalse)
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: trueExp)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: trueExp)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: falseExp)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs3, rhs: falseExp)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        let lhs4 = TCTLParser.Expression.implies(lhs: falseExp, rhs: globallyFalse)
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: trueExp)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: trueExp)
                .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: falseExp)
                .verify(currentNode: failureCount2Node, inCycle: false)
        )
        XCTAssertThrowsError(
            try TCTLParser.Expression.implies(lhs: lhs4, rhs: falseExp)
                .verify(currentNode: failureCount2Node, inCycle: true)
        )
    }

    /// (A G <T | F> -> <T | F>) -> <T | F>
    func testImpliesRevisittingGloballyRHS2() throws {
        let trueExp = TCTLParser.Expression.language(expression: trueExp)
        let falseExp = TCTLParser.Expression.language(expression: falseExp)
        let lhs = TCTLParser.Expression.implies(lhs: globallyTrue, rhs: trueExp)
        // (A -> B) -> R
        // revist(B -> R): succ(A) <- skip on failure.
        // revisit(R): !succ(A)    <- skip on failure.
        XCTAssertEqual(
            try TCTLParser.Expression.implies(lhs: lhs, rhs: trueExp)
                .verify(currentNode: failureCount2Node, inCycle: false),
            [
                .revisitting(
                    expression: trueExp,
                    successors: [.skip(expression: globallyTrue), .skip(expression: trueExp)]
                )
            ]
        )
    }

    // (A G <T | F> -> A G <T | F>) -> <T | F>

    // (A G <T | F> -> <T | F>) -> A G <T | F>

    // (<T | F> -> A G <T | F>) -> A G <T | F>

    // (A G <T | F> -> A G <T | F>) -> A G <T | F>

    // <T | F> -> (<T | F> -> A F <T | F>)

    // (<T | F> -> A F <T | F>) -> <T | F>

    // (A F <T | F> -> <T | F>) -> <T | F>

    // (A F <T | F> -> A F <T | F>) -> <T | F>

    // (A F <T | F> -> <T | F>) -> A F <T | F>

    // (<T | F> -> A F <T | F>) -> A F <T | F>

    // (A F <T | F> -> A F <T | F>) -> A F <T | F>

    // swiftlint:enable function_body_length

}

// swiftlint:enable type_body_length
// swiftlint:enable file_length
