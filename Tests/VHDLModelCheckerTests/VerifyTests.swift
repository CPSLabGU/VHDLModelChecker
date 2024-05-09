// VerifyTests.swift
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

final class VerifyTests: XCTestCase {

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

    let trueExp = VHDLParsing.Expression.conditional(condition: .comparison(value: .equality(
        lhs: .reference(variable: .variable(reference: .variable(name: .failureCount))),
        rhs: .literal(value: .integer(value: 2))
    )))

    let falseExp = VHDLParsing.Expression.conditional(condition: .comparison(value: .equality(
        lhs: .reference(variable: .variable(reference: .variable(name: .failureCount))),
        rhs: .literal(value: .integer(value: 3))
    )))

    /// A node with a failure count of 3.
    var failureCount2Node: KripkeNode! {
        kripkeStructure.ringlets.lazy.compactMap { ringlet -> KripkeNode? in
            guard ringlet.write.properties[.failureCount] == .integer(value: 2) else {
                return nil
            }
            return KripkeNode.write(node: ringlet.write, currentState: ringlet.state)
        }
        .first
    }

    func testEquality() {
        XCTAssertNoThrow(
            try VHDLExpression.conditional(expression: .comparison(value: .equality(
                lhs: .reference(variable: .variable(reference: .variable(name: .failureCount))),
                rhs: .literal(value: .integer(value: 2))
            )))
            .verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try VHDLExpression.conditional(expression: .comparison(value: .equality(
                lhs: .reference(variable: .variable(reference: .variable(name: .currentState))),
                rhs: .reference(variable: .variable(reference: .variable(
                    name: failureCount2Node.currentState
                )))
            )))
            .verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try VHDLExpression.conditional(expression: .comparison(value: .equality(
                lhs: .reference(variable: .variable(reference: .variable(name: .nextState))),
                rhs: .reference(variable: .variable(reference: .variable(
                    name: failureCount2Node.nextState!
                )))
            )))
            .verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try VHDLExpression.conditional(expression: .comparison(value: .equality(
                lhs: .reference(variable: .variable(reference: .variable(name: .executeOnEntry))),
                rhs: .literal(value: .boolean(value: failureCount2Node.executeOnEntry))
            )))
            .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.conditional(expression: .comparison(value: .equality(
                lhs: .reference(variable: .variable(reference: .variable(name: .failureCount))),
                rhs: .literal(value: .integer(value: 3))
            )))
            .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.conditional(expression: .comparison(value: .equality(
                lhs: .reference(variable: .variable(reference: .variable(name: .currentState))),
                rhs: .reference(variable: .variable(reference: .variable(name: .failureCount)))
            )))
            .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.conditional(expression: .comparison(value: .equality(
                lhs: .reference(variable: .variable(reference: .variable(name: .nextState))),
                rhs: .reference(variable: .variable(reference: .variable(name: .failureCount)))
            )))
            .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.conditional(expression: .comparison(value: .equality(
                lhs: .reference(variable: .variable(reference: .variable(name: .executeOnEntry))),
                rhs: .literal(value: .boolean(value: !failureCount2Node.executeOnEntry))
            )))
            .verify(node: failureCount2Node)
        )
    }

    func testGreaterThan() {
        XCTAssertNoThrow(
            try VHDLExpression.conditional(expression: .comparison(value: .greaterThan(
                lhs: .reference(variable: .variable(reference: .variable(name: .failureCount))),
                rhs: .literal(value: .integer(value: 1))
            )))
            .verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try VHDLExpression.conditional(expression: .comparison(value: .greaterThan(
                lhs: .literal(value: .integer(value: 3)),
                rhs: .reference(variable: .variable(reference: .variable(name: .failureCount)))
            )))
            .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.conditional(expression: .comparison(value: .greaterThan(
                lhs: .literal(value: .integer(value: 1)),
                rhs: .reference(variable: .variable(reference: .variable(name: .failureCount)))
            )))
            .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.conditional(expression: .comparison(value: .greaterThan(
                lhs: .reference(variable: .variable(reference: .variable(name: .failureCount))),
                rhs: .literal(value: .integer(value: 3))
            )))
            .verify(node: failureCount2Node)
        )
    }

    func testNot() {
        XCTAssertNoThrow(
            try VHDLExpression.boolean(expression: .not(value: .conditional(
                condition: .comparison(value: .equality(
                    lhs: .reference(variable: .variable(reference: .variable(name: .executeOnEntry))),
                    rhs: .literal(value: .boolean(value: !failureCount2Node.executeOnEntry))
                ))
            )))
            .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.boolean(expression: .not(value: .conditional(
                condition: .comparison(value: .equality(
                    lhs: .reference(variable: .variable(reference: .variable(name: .executeOnEntry))),
                    rhs: .literal(value: .boolean(value: failureCount2Node.executeOnEntry))
                ))
            )))
            .verify(node: failureCount2Node)
        )
    }

    func testNotEquals() {
        XCTAssertThrowsError(
            try VHDLExpression.conditional(expression: .comparison(value: .notEquals(
                lhs: .reference(variable: .variable(reference: .variable(name: .failureCount))),
                rhs: .literal(value: .integer(value: 2))
            )))
            .verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try VHDLExpression.conditional(expression: .comparison(value: .notEquals(
                lhs: .reference(variable: .variable(reference: .variable(name: .failureCount))),
                rhs: .literal(value: .integer(value: 3))
            )))
            .verify(node: failureCount2Node)
        )
    }

    func testGreaterOrEqual() {
        XCTAssertNoThrow(
            try VHDLExpression.conditional(expression: .comparison(value: .greaterThanOrEqual(
                lhs: .reference(variable: .variable(reference: .variable(name: .failureCount))),
                rhs: .literal(value: .integer(value: 1))
            )))
            .verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try VHDLExpression.conditional(expression: .comparison(value: .greaterThanOrEqual(
                lhs: .literal(value: .integer(value: 3)),
                rhs: .reference(variable: .variable(reference: .variable(name: .failureCount)))
            )))
            .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.conditional(expression: .comparison(value: .greaterThanOrEqual(
                lhs: .literal(value: .integer(value: 1)),
                rhs: .reference(variable: .variable(reference: .variable(name: .failureCount)))
            )))
            .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.conditional(expression: .comparison(value: .greaterThanOrEqual(
                lhs: .reference(variable: .variable(reference: .variable(name: .failureCount))),
                rhs: .literal(value: .integer(value: 3))
            )))
            .verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try VHDLExpression.conditional(expression: .comparison(value: .greaterThanOrEqual(
                lhs: .reference(variable: .variable(reference: .variable(name: .failureCount))),
                rhs: .literal(value: .integer(value: 2))
            )))
            .verify(node: failureCount2Node)
        )
    }

    func testAnd() {
        XCTAssertNoThrow(
            try VHDLExpression.boolean(expression: .and(lhs: trueExp, rhs: trueExp))
                .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.boolean(expression: .and(lhs: trueExp, rhs: falseExp))
                .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.boolean(expression: .and(lhs: falseExp, rhs: trueExp))
                .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.boolean(expression: .and(lhs: falseExp, rhs: falseExp))
                .verify(node: failureCount2Node)
        )
    }

    func testOr() {
        XCTAssertNoThrow(
            try VHDLExpression.boolean(expression: .or(lhs: trueExp, rhs: trueExp))
                .verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try VHDLExpression.boolean(expression: .or(lhs: trueExp, rhs: falseExp))
                .verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try VHDLExpression.boolean(expression: .or(lhs: falseExp, rhs: trueExp))
                .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.boolean(expression: .or(lhs: falseExp, rhs: falseExp))
                .verify(node: failureCount2Node)
        )
    }

    func testXOR() {
        XCTAssertNoThrow(
            try VHDLExpression.boolean(expression: .xor(lhs: trueExp, rhs: falseExp))
                .verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try VHDLExpression.boolean(expression: .xor(lhs: falseExp, rhs: trueExp))
                .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.boolean(expression: .xor(lhs: trueExp, rhs: trueExp))
                .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.boolean(expression: .xor(lhs: falseExp, rhs: falseExp))
                .verify(node: failureCount2Node)
        )
    }

    func testNAND() {
        XCTAssertNoThrow(
            try VHDLExpression.boolean(expression: .nand(lhs: trueExp, rhs: falseExp))
                .verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try VHDLExpression.boolean(expression: .nand(lhs: falseExp, rhs: trueExp))
                .verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try VHDLExpression.boolean(expression: .nand(lhs: falseExp, rhs: falseExp))
                .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.boolean(expression: .nand(lhs: trueExp, rhs: trueExp))
                .verify(node: failureCount2Node)
        )
    }

    func testNOR() {
        XCTAssertNoThrow(
            try VHDLExpression.boolean(expression: .nor(lhs: falseExp, rhs: falseExp))
                .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.boolean(expression: .nor(lhs: trueExp, rhs: falseExp))
                .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.boolean(expression: .nor(lhs: falseExp, rhs: trueExp))
                .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.boolean(expression: .nor(lhs: trueExp, rhs: trueExp))
                .verify(node: failureCount2Node)
        )
    }

    func testXNOR() {
        XCTAssertNoThrow(
            try VHDLExpression.boolean(expression: .xnor(lhs: trueExp, rhs: trueExp))
                .verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try VHDLExpression.boolean(expression: .xnor(lhs: falseExp, rhs: falseExp))
                .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.boolean(expression: .xnor(lhs: trueExp, rhs: falseExp))
                .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.boolean(expression: .xnor(lhs: falseExp, rhs: trueExp))
                .verify(node: failureCount2Node)
        )
    }

    func testLiteral() {
        XCTAssertNoThrow(
            try VHDLExpression.conditional(expression: .literal(value: true)).verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.conditional(expression: .literal(value: false)).verify(node: failureCount2Node)
        )
    }

    func testPrecedence() {
        XCTAssertNoThrow(
            try VHDLExpression.boolean(expression: .and(lhs: trueExp, rhs: .precedence(value: trueExp)))
                .verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try VHDLExpression.boolean(expression: .and(lhs: trueExp, rhs: .precedence(value: falseExp)))
                .verify(node: failureCount2Node)
        )
    }

    func testReference() {
        guard failureCount2Node.executeOnEntry else {
            XCTAssertThrowsError(
                try VHDLExpression.boolean(expression: .and(
                    lhs: trueExp,
                    rhs: .reference(variable: .variable(reference: .variable(name: .executeOnEntry)))
                ))
                .verify(node: failureCount2Node)
            )
            return
        }
        XCTAssertNoThrow(
            try VHDLExpression.boolean(expression: .and(
                lhs: trueExp,
                rhs: .reference(variable: .variable(reference: .variable(name: .executeOnEntry)))
            ))
            .verify(node: failureCount2Node)
        )
    }

}
