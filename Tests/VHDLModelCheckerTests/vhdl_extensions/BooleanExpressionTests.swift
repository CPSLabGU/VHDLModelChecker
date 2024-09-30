// BooleanExpressionTests.swift
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
@testable import VHDLModelChecker
import VHDLParsing
import XCTest

/// Test class for ``BooleanExpression``.
final class BooleanExpressionTests: KripkeStructureTestable {

    /// A true expression.
    let trueExp = VHDLParsing.Expression.conditional(condition: .literal(value: true))

    /// A false expression.
    let falseExp = VHDLParsing.Expression.conditional(condition: .literal(value: false))

    /// Test `and` operation.
    func testAnd() {
        XCTAssertNoThrow(
            try BooleanExpression.and(lhs: trueExp, rhs: trueExp).verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try BooleanExpression.and(lhs: trueExp, rhs: falseExp).verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try BooleanExpression.and(lhs: falseExp, rhs: trueExp).verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try BooleanExpression.and(lhs: falseExp, rhs: falseExp).verify(node: failureCount2Node)
        )
    }

    /// Test `or` operation.
    func testOr() {
        XCTAssertNoThrow(
            try BooleanExpression.or(lhs: trueExp, rhs: trueExp).verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try BooleanExpression.or(lhs: trueExp, rhs: falseExp).verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try BooleanExpression.or(lhs: falseExp, rhs: trueExp).verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try BooleanExpression.or(lhs: falseExp, rhs: falseExp).verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try BooleanExpression.or(lhs: .literal(value: .boolean(value: true)), rhs: trueExp)
                .verify(node: failureCount2Node)
        )
    }

    /// Test `not` operation.
    func testNot() {
        XCTAssertThrowsError(
            try BooleanExpression.not(value: trueExp).verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try BooleanExpression.not(value: falseExp).verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try BooleanExpression.not(value: .literal(value: .boolean(value: false)))
                .verify(node: failureCount2Node)
        )
    }

    /// Test `nand` operation.
    func testNand() {
        XCTAssertThrowsError(
            try BooleanExpression.nand(lhs: trueExp, rhs: trueExp).verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try BooleanExpression.nand(lhs: trueExp, rhs: falseExp).verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try BooleanExpression.nand(lhs: falseExp, rhs: trueExp).verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try BooleanExpression.nand(lhs: falseExp, rhs: falseExp).verify(node: failureCount2Node)
        )
    }

    /// Test `nor` operation.
    func testNor() {
        XCTAssertThrowsError(
            try BooleanExpression.nor(lhs: trueExp, rhs: trueExp).verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try BooleanExpression.nor(lhs: trueExp, rhs: falseExp).verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try BooleanExpression.nor(lhs: falseExp, rhs: trueExp).verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try BooleanExpression.nor(lhs: falseExp, rhs: falseExp).verify(node: failureCount2Node)
        )
    }

    /// Test `xor` operation.
    func testXor() {
        XCTAssertThrowsError(
            try BooleanExpression.xor(lhs: trueExp, rhs: trueExp).verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try BooleanExpression.xor(lhs: trueExp, rhs: falseExp).verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try BooleanExpression.xor(lhs: falseExp, rhs: trueExp).verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try BooleanExpression.xor(lhs: falseExp, rhs: falseExp).verify(node: failureCount2Node)
        )
    }

    /// Test `xnor` operation.
    func testXnor() {
        XCTAssertNoThrow(
            try BooleanExpression.xnor(lhs: trueExp, rhs: trueExp).verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try BooleanExpression.xnor(lhs: trueExp, rhs: falseExp).verify(node: failureCount2Node)
        )
        XCTAssertThrowsError(
            try BooleanExpression.xnor(lhs: falseExp, rhs: trueExp).verify(node: failureCount2Node)
        )
        XCTAssertNoThrow(
            try BooleanExpression.xnor(lhs: falseExp, rhs: falseExp).verify(node: failureCount2Node)
        )
    }

}
