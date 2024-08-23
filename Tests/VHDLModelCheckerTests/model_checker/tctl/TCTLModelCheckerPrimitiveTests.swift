// TCTLModelCheckerPrimitiveTests.swift
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

final class TCTLModelCheckerPrimitiveTests: XCTestCase {

    /// The iterator for the kripke structure.
    lazy var iterator = KripkeStructureIterator(structure: VHDLModelCheckerTests.kripkeStructure)

    /// The model checker to use when verifying the specification.
    var checker: TCTLModelChecker<InMemoryDataStore>!

    /// Initialise the test data before every test.
    override func setUp() {
        super.setUp()
        iterator = KripkeStructureIterator(structure: VHDLModelCheckerTests.kripkeStructure)
        // checker = TCTLModelChecker(store: try! SQLiteJobStore())
        // checker = TCTLModelChecker(store: try! SQLiteJobStore(path: FileManager.default.currentDirectoryPath + "/test.db"))
        checker = TCTLModelChecker(store: InMemoryDataStore())
    }

    // MARK: Primitive Values.

    /// Test true.
    func testTrue() throws {
        let specRaw = """
        // spec:language VHDL

        true
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    /// Test false.
    func testFalse() throws {
        let specRaw = """
        // spec:language VHDL

        false
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec))
    }

    // MARK: Always Global.

    /// Always true.
    func testAlwaysTrue() throws {
        let specRaw = """
        // spec:language VHDL

        A G true
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testAlwaysFalse() throws {
        let specRaw = """
        // spec:language VHDL

        A G false
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec))
    }

    // MARK: Eventually Global.

    /// Eventually true.
    func testEventuallyTrue() throws {
        let specRaw = """
        // spec:language VHDL

        E G true
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testEventuallyFalse() throws {
        let specRaw = """
        // spec:language VHDL

        E G false
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec))
    }

    // MARK: Always Weak.

    func testAlwaysWeak() throws {
        let specRaw = """
        // spec:language VHDL

        A false W true
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testAlwaysWeakThrowsTrue() throws {
        let specRaw = """
        // spec:language VHDL

        A true W true
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testAlwaysWeakThrowsFalse() throws {
        let specRaw = """
        // spec:language VHDL

        A false W false
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec))
    }

    func testAlwaysWeakTrue() throws {
        let specRaw = """
        // spec:language VHDL

        A true W false
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    // MARK: Always Until.

    func testAlwaysUntil() throws {
        let specRaw = """
        // spec:language VHDL

        A false U true
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testAlwaysUntilThrows() throws {
        let specRaw = """
        // spec:language VHDL

        A true U true
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testAlwaysUntilThrowsWithoutCompletion() throws {
        let specRaw = """
        // spec:language VHDL

        A true U false
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec))
    }

    func testAlwaysUntilThrowsWithoutCompletionFalse() throws {
        let specRaw = """
        // spec:language VHDL

        A false U false
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec))
    }

    // MARK: Eventually Weak.

    func testEventuallyWeak() throws {
        let specRaw = """
        // spec:language VHDL

        E false W true
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testEventuallyWeakThrowsTrue() throws {
        let specRaw = """
        // spec:language VHDL

        E true W true
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testEventuallyWeakThrowsFalse() throws {
        let specRaw = """
        // spec:language VHDL

        E false W false
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec))
    }

    func testEventuallyWeakTrue() throws {
        let specRaw = """
        // spec:language VHDL

        E true W false
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    // MARK: Eventually Until.

    func testEventuallyUntil() throws {
        let specRaw = """
        // spec:language VHDL

        E false U true
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testEventuallyUntilThrows() throws {
        let specRaw = """
        // spec:language VHDL

        E true U true
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testEventuallyUntilThrowsWithoutCompletion() throws {
        let specRaw = """
        // spec:language VHDL

        E true U false
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec))
    }

    func testEventuallyUntilThrowsWithoutCompletionFalse() throws {
        let specRaw = """
        // spec:language VHDL

        E false U false
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec))
    }

    // MARK: Conjunction.

    func testConjunctionTrueTrue() throws {
        let specRaw = """
        // spec:language VHDL

        true ^ true
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testConjunctionTrueFalse() throws {
        let specRaw = """
        // spec:language VHDL

        true ^ false
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec))
    }

    func testConjunctionFalseTrue() throws {
        let specRaw = """
        // spec:language VHDL

        false ^ true
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec))
    }

    func testConjunctionFalseFalse() throws {
        let specRaw = """
        // spec:language VHDL

        false ^ false
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec))
    }

    func testConjunction() throws {
        let specs = [
            "A G true ^ true",
            "E G true ^ true",
            "A F true ^ true",
            "E F true ^ true",
            "A X true ^ true",
            "E X true ^ true",
            "A true ^ true U true",
            "E true ^ true U true",
            "A true U true ^ true",
            "E true U true ^ true",
            "A false U true ^ true",
            "E false U true ^ true",
            "A true ^ true W true",
            "E true ^ true W true",
            "A true ^ true W false",
            "E true ^ true W false",
            "A true W true ^ true",
            "E true W true ^ true",
            "A false W true ^ true",
            "E false W true ^ true",
            "A true W true ^ false",
            "E true W true ^ false",
            "A true W false ^ true",
            "E true W false ^ true",
            "A true W false ^ false",
            "E true W false ^ false"
        ]
        let specRaw = "// spec:language VHDL"
        for spec in specs {
            let specification = Specification(rawValue: specRaw + "\n\n" + spec)!
            XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
        }
    }

    func testConjunctionFails() throws {
        let specs = [
            "A G true ^ false",
            "A G false ^ true",
            "A G false ^ false",
            "E G true ^ false",
            "E G false ^ true",
            "E G false ^ false",
            "A F true ^ false",
            "A F false ^ true",
            "A F false ^ false",
            "E F true ^ false",
            "E F false ^ true",
            "E F false ^ false",
            "A X true ^ false",
            "A X false ^ true",
            "A X false ^ false",
            "E X true ^ false",
            "E X false ^ true",
            "E X false ^ false",
            "A true ^ false U false",
            "A false ^ true U false",
            "A false ^ false U false",
            "E true ^ false U false",
            "E false ^ true U false",
            "E false ^ false U false",
            "A false U true ^ false",
            "A false U false ^ true",
            "A false U false ^ false",
            "E false U true ^ false",
            "E false U false ^ true",
            "E false U false ^ false",
            "A true ^ false W false",
            "A false ^ true W false",
            "A false ^ false W false",
            "E true ^ false W false",
            "E false ^ true W false",
            "E false ^ false W false"
        ]
        let specRaw = "// spec:language VHDL"
        for spec in specs {
            let specification = Specification(rawValue: specRaw + "\n\n" + spec)!
            XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification)) {
                guard
                    let error = $0 as? ModelCheckerError,
                    case .unsatisfied(let branches, let expression, let base) = error
                else {
                    XCTFail("Got incorrect error!")
                    return
                }
                // branches.forEach {
                //     print($0.description)
                // }
                // print("Failed expression: \(expression.rawValue)")
                // print("Branch nodes: \(branches.count)")
            }
        }
    }

    // MARK: Disjunction.

    func testDisjunctionTrueTrue() throws {
        let specRaw = """
        // spec:language VHDL

        true V true
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testDisjunctionTrueFalse() throws {
        let specRaw = """
        // spec:language VHDL

        true V false
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testDisjunctionFalseTrue() throws {
        let specRaw = """
        // spec:language VHDL

        false V true
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testDisjunctionFalseFalse() throws {
        let specRaw = """
        // spec:language VHDL

        false V false
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec))
    }

    func testDisjunction() throws {
        let specs = [
            "E G true V false",
            "E G false V true",
            "E G true V true",
            "E F true V false",
            "E F false V true",
            "E F true V true",
            "E X true V false",
            "E X false V true",
            "E X true V true",
            "A G true V false",
            "A G false V true",
            "A G true V true",
            "A F true V false",
            "A F false V true",
            "A F true V true",
            "A X true V false",
            "A X false V true",
            "A X true V true"
        ]
        let specRaw = "// spec:language VHDL"
        for (index, spec) in specs.enumerated() {
            print("Checking \(index + 1) of \(specs.count)")
            fflush(stdout)
            let specification = Specification(rawValue: specRaw + "\n\n" + spec + "\n")!
            XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
        }
    }

    func testDisjunctionFails() throws {
        let specs = [
            "A G false V false",
            "A F false V false",
            "A X false V false",
            "E G false V false",
            "E F false V false",
            "E X false V false",
        ]
        let specRaw = "// spec:language VHDL"
        for spec in specs {
            let specification = Specification(rawValue: specRaw + "\n\n" + spec)!
            XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification)) {
                guard
                    let error = $0 as? ModelCheckerError,
                    case .unsatisfied(let branches, let expression, let base) = error
                else {
                    XCTFail("Got incorrect error!")
                    return
                }
                // branches.forEach {
                //     print($0.description)
                // }
                // print("Failed expression: \(expression.rawValue)")
                // print("Branch nodes: \(branches.count)")
            }
        }
    }

    // MARK: Negation.

    func testNegationTrue() throws {
        let specRaw = """
        // spec:language VHDL

        !true
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec))
    }

    func testNegationFalse() throws {
        let specRaw = """
        // spec:language VHDL

        !false
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testNegation() throws {
        let specs = [
            "A G !false",
            "!A G false",
            "E G !false",
            "!E G false",
            "A F !false",
            "!A F false",
            "E F !false",
            "!E F false",
            "A X !false",
            "!A X false",
            "E X !false",
            "!E X false",
            "!A false U false",
            "!E false U false",
            "!A false W false",
            "!E false W false"
        ]
        let specRaw = "// spec:language VHDL"
        for spec in specs {
            guard let specification = Specification(rawValue: specRaw + "\n\n" + spec) else {
                XCTFail("Failed to parse \(spec)")
                return
            }
            XCTAssertNoThrow(try checker.check(structure: iterator, specification: specification))
        }
    }

    func testNegationFails() throws {
        let specs = [
            "A G !true",
            "!A G true",
            "E G !true",
            "!E G true",
            "A F !true",
            "!A F true",
            "E F !true",
            "!E F true",
            "A X !true",
            "!A X true",
            "E X !true",
            "!E X true",
            "!A false U true",
            "!E false U true",
            "!A true U true",
            "!E true U true",
            "!A false W true",
            "!E false W true",
            "!A true W true",
            "!E true W true"
        ]
        let specRaw = "// spec:language VHDL"
        for spec in specs {
            guard let specification = Specification(rawValue: specRaw + "\n\n" + spec) else {
                XCTFail("Failed to parse \(spec)")
                return
            }
            XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification))
        }
    }

    // MARK: Constraints.

    func testTruePassingConstraint() throws {
        let specRaw = """
        // spec:language VHDL

        {A G true}_{t >= 0 us}

        {A F true}_{t >= 0 us}

        {A X true}_{t >= 0 us}

        {A true U true}_{t >= 0 us}

        {A true W true}_{t >= 0 us}
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testTrueFailingConstraint() throws {
        let specRaw = """
        // spec:language VHDL

        {A F true}_{t < 0 us}
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec))
    }

    func testFalsePassingConstraint() throws {
        let specRaw = """
        // spec:language VHDL

        {A G false}_{t >= 0 us}

        {A F false}_{t >= 0 us}

        {A X false}_{t >= 0 us}

        {A true U false}_{t >= 0 us}

        {A false W false}_{t >= 0 us}
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec))
    }

    func testFalseFailingConstraint() throws {
        let specRaw = """
        // spec:language VHDL

        {A F false}_{t < 0 us}
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec))
    }

}
