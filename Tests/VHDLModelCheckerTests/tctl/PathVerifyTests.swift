// PathVerifyTests.swift
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

/// Class that tests the `verify` function on `PathQuantifiedExpression`.
final class PathVerifyTests: KripkeStructureTestable {

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

    /// A test cost.
    let cost = Cost(time: .zero, energy: .zero)

    /// Test that the `verify` function performs correctly with the `next` quantifier.
    func testNext() throws {
        XCTAssertEqual(
            try PathQuantifiedExpression.next(expression: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false, quantifier: .always, cost: cost),
            [.successor(expression: .language(expression: trueExp))]
        )
        XCTAssertEqual(
            try PathQuantifiedExpression.next(expression: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false, quantifier: .always, cost: cost),
            [.successor(expression: .language(expression: falseExp))]
        )
        XCTAssertEqual(
            try PathQuantifiedExpression.next(expression: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: true, quantifier: .always, cost: cost),
            [.successor(expression: .language(expression: trueExp))]
        )
        XCTAssertEqual(
            try PathQuantifiedExpression.next(expression: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: true, quantifier: .always, cost: cost),
            [.successor(expression: .language(expression: falseExp))]
        )
        XCTAssertEqual(
            try PathQuantifiedExpression.next(expression: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false, quantifier: .eventually, cost: cost),
            [.successor(expression: .language(expression: trueExp))]
        )
        XCTAssertEqual(
            try PathQuantifiedExpression.next(expression: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false, quantifier: .eventually, cost: cost),
            [.successor(expression: .language(expression: falseExp))]
        )
        XCTAssertEqual(
            try PathQuantifiedExpression.next(expression: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: true, quantifier: .eventually, cost: cost),
            [.successor(expression: .language(expression: trueExp))]
        )
        XCTAssertEqual(
            try PathQuantifiedExpression.next(expression: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: true, quantifier: .eventually, cost: cost),
            [.successor(expression: .language(expression: falseExp))]
        )
    }

    /// Test that the `verify` function performs correctly with the `globally` quantifier.
    func testGlobally() throws {
        XCTAssertEqual(
            try PathQuantifiedExpression.globally(expression: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false, quantifier: .always, cost: cost),
            [
                .successor(expression: .quantified(expression: .always(
                    expression: .globally(expression: .language(expression: trueExp))
                )))
            ]
        )
        XCTAssertThrowsError(
            try PathQuantifiedExpression.globally(expression: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false, quantifier: .always, cost: cost)
        )
        XCTAssertTrue(
            try PathQuantifiedExpression.globally(expression: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: true, quantifier: .always, cost: cost)
                .isEmpty
        )
        XCTAssertThrowsError(
            try PathQuantifiedExpression.globally(expression: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: true, quantifier: .always, cost: cost)
        )
        XCTAssertEqual(
            try PathQuantifiedExpression.globally(expression: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false, quantifier: .eventually, cost: cost),
            [
                .successor(expression: .quantified(expression: .eventually(
                    expression: .globally(expression: .language(expression: trueExp))
                )))
            ]
        )
        XCTAssertThrowsError(
            try PathQuantifiedExpression.globally(expression: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false, quantifier: .eventually, cost: cost)
        )
        XCTAssertTrue(
            try PathQuantifiedExpression.globally(expression: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: true, quantifier: .eventually, cost: cost)
                .isEmpty
        )
        XCTAssertThrowsError(
            try PathQuantifiedExpression.globally(expression: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: true, quantifier: .eventually, cost: cost)
        )
    }

    // swiftlint:disable function_body_length

    /// Test that the `verify` function performs correctly with the `finally` quantifier.
    func testFinally() throws {
        XCTAssertTrue(
            try PathQuantifiedExpression.finally(expression: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false, quantifier: .always, cost: cost)
                .isEmpty
        )
        XCTAssertEqual(
            try PathQuantifiedExpression.finally(expression: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false, quantifier: .always, cost: cost),
            [
                .successor(expression: .disjunction(
                    lhs: .language(expression: falseExp),
                    rhs: .quantified(expression: .always(
                        expression: .finally(expression: .language(expression: falseExp))
                    ))
                ))
            ]
        )
        XCTAssertTrue(
            try PathQuantifiedExpression.finally(expression: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: true, quantifier: .always, cost: cost)
                .isEmpty
        )
        XCTAssertThrowsError(
            try PathQuantifiedExpression.finally(expression: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: true, quantifier: .always, cost: cost)
        )
        XCTAssertTrue(
            try PathQuantifiedExpression.finally(expression: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: false, quantifier: .eventually, cost: cost)
                .isEmpty
        )
        XCTAssertEqual(
            try PathQuantifiedExpression.finally(expression: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: false, quantifier: .eventually, cost: cost),
            [
                .successor(expression: .disjunction(
                    lhs: .language(expression: falseExp),
                    rhs: .quantified(expression: .eventually(
                        expression: .finally(expression: .language(expression: falseExp))
                    ))
                ))
            ]
        )
        XCTAssertTrue(
            try PathQuantifiedExpression.finally(expression: .language(expression: trueExp))
                .verify(currentNode: failureCount2Node, inCycle: true, quantifier: .eventually, cost: cost)
                .isEmpty
        )
        XCTAssertThrowsError(
            try PathQuantifiedExpression.finally(expression: .language(expression: falseExp))
                .verify(currentNode: failureCount2Node, inCycle: true, quantifier: .eventually, cost: cost)
        )
    }

    func testFinallyNext() throws {
        let nextTrue = Expression.quantified(expression: .always(expression: .next(
            expression: .language(expression: trueExp)
        )))
        let finallyNextTrue = Expression.quantified(expression: .always(expression: .finally(
            expression: nextTrue
        )))
        XCTAssertEqual(
            try finallyNextTrue.verify(currentNode: failureCount2Node, inCycle: false, cost: cost),
            [.successor(expression: .disjunction(lhs: .language(expression: trueExp), rhs: finallyNextTrue))]
        )
        XCTAssertEqual(
            try finallyNextTrue.verify(currentNode: failureCount2Node, inCycle: true, cost: cost),
            [.successor(expression: .language(expression: trueExp))]
        )
    }

    // swiftlint:enable function_body_length

}
