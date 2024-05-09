// QuantifiedVerifyTests.swift
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

final class QuantifiedVerifyTests: XCTestCase {

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

    let trueExp = LanguageExpression.vhdl(expression: .conditional(expression: .comparison(value: .equality(
        lhs: .reference(variable: .variable(reference: .variable(name: .failureCount))),
        rhs: .literal(value: .integer(value: 2))
    ))))

    let falseExp = LanguageExpression.vhdl(expression: .conditional(expression: .comparison(value: .equality(
        lhs: .reference(variable: .variable(reference: .variable(name: .failureCount))),
        rhs: .literal(value: .integer(value: 3))
    ))))

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

    func testAlways() throws {
        let result = try GloballyQuantifiedExpression.always(
            expression: .globally(expression: .language(expression: trueExp))
        )
        .verify(currentNode: failureCount2Node, inCycle: true)
        XCTAssertEqual(result, [.completed])
        let result2 = try GloballyQuantifiedExpression.always(
            expression: .globally(expression: .language(expression: trueExp))
        )
        .verify(currentNode: failureCount2Node, inCycle: false)
        XCTAssertEqual(result2, [.progressing])
        XCTAssertThrowsError(
            try GloballyQuantifiedExpression.always(
                expression: .globally(expression: .language(expression: falseExp))
            )
            .verify(currentNode: failureCount2Node, inCycle: true)
        )
        XCTAssertThrowsError(
            try GloballyQuantifiedExpression.always(
                expression: .globally(expression: .language(expression: falseExp))
            )
            .verify(currentNode: failureCount2Node, inCycle: false)
        )
        XCTAssertEqual(
            try GloballyQuantifiedExpression.always(
                expression: .finally(expression: .language(expression: trueExp))
            )
            .verify(currentNode: failureCount2Node, inCycle: false),
            [.completed]
        )
        XCTAssertEqual(
            try GloballyQuantifiedExpression.always(
                expression: .finally(expression: .language(expression: trueExp))
            )
            .verify(currentNode: failureCount2Node, inCycle: true),
            [.completed]
        )
        XCTAssertEqual(
            try GloballyQuantifiedExpression.always(
                expression: .finally(expression: .language(expression: falseExp))
            )
            .verify(currentNode: failureCount2Node, inCycle: false),
            [.progressing]
        )
        XCTAssertThrowsError(
            try GloballyQuantifiedExpression.always(
                expression: .finally(expression: .language(expression: falseExp))
            )
            .verify(currentNode: failureCount2Node, inCycle: true)
        )
        XCTAssertEqual(
            try GloballyQuantifiedExpression.always(
                expression: .next(expression: .language(expression: trueExp))
            )
            .verify(currentNode: failureCount2Node, inCycle: false),
            [.progressing]
        )
        XCTAssertEqual(
            try GloballyQuantifiedExpression.always(
                expression: .next(expression: .language(expression: falseExp))
            )
            .verify(currentNode: failureCount2Node, inCycle: false),
            [.progressing]
        )
        XCTAssertEqual(
            try GloballyQuantifiedExpression.always(
                expression: .next(expression: .language(expression: trueExp))
            )
            .verify(currentNode: failureCount2Node, inCycle: true),
            [.progressing]
        )
        XCTAssertEqual(
            try GloballyQuantifiedExpression.always(
                expression: .next(expression: .language(expression: falseExp))
            )
            .verify(currentNode: failureCount2Node, inCycle: true),
            [.progressing]
        )
    }

    func testEventually() throws {
        let result = try GloballyQuantifiedExpression.eventually(
            expression: .globally(expression: .language(expression: trueExp))
        )
        .verify(currentNode: failureCount2Node, inCycle: true)
        XCTAssertEqual(result, [.completed])
        let result2 = try GloballyQuantifiedExpression.eventually(
            expression: .globally(expression: .language(expression: trueExp))
        )
        .verify(currentNode: failureCount2Node, inCycle: false)
        XCTAssertEqual(result2, [.progressing])
        let result3 = try GloballyQuantifiedExpression.eventually(
            expression: .finally(expression: .language(expression: trueExp))
        )
        .verify(currentNode: failureCount2Node, inCycle: true)
        XCTAssertEqual(result3, [.completed])
        let result4 = try GloballyQuantifiedExpression.eventually(
            expression: .finally(expression: .language(expression: trueExp))
        )
        .verify(currentNode: failureCount2Node, inCycle: false)
        XCTAssertEqual(result4, [.completed])
        XCTAssertThrowsError(
            try GloballyQuantifiedExpression.eventually(
                expression: .globally(expression: .language(expression: falseExp))
            )
            .verify(currentNode: failureCount2Node, inCycle: true)
        )
        XCTAssertThrowsError(
            try GloballyQuantifiedExpression.eventually(
                expression: .globally(expression: .language(expression: falseExp))
            )
            .verify(currentNode: failureCount2Node, inCycle: false)
        )
        XCTAssertEqual(
            try GloballyQuantifiedExpression.eventually(
                expression: .next(expression: .language(expression: falseExp))
            )
            .verify(currentNode: failureCount2Node, inCycle: true),
            [.progressing]
        )
        XCTAssertEqual(
            try GloballyQuantifiedExpression.eventually(
                expression: .next(expression: .language(expression: falseExp))
            )
            .verify(currentNode: failureCount2Node, inCycle: false),
            [.progressing]
        )
        XCTAssertThrowsError(
            try GloballyQuantifiedExpression.eventually(
                expression: .finally(expression: .language(expression: falseExp))
            )
            .verify(currentNode: failureCount2Node, inCycle: true)
        )
    }

}

// "E F (A X x == 3) -> y == 5"
