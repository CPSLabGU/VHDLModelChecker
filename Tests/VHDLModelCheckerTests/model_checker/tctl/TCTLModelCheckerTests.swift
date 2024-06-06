// TCTLModelCheckerTests.swift
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

/// Test class for ``TCTLModelChecker``.
final class TCTLModelCheckerTests: XCTestCase {

    /// The iterator for the kripke structure.
    lazy var iterator = KripkeStructureIterator(structure: VHDLModelCheckerTests.kripkeStructure)

    /// The model checker to use when verifying the specification.
    let checker = TCTLModelChecker()

    /// Initialise the test data before every test.
    override func setUp() {
        super.setUp()
        iterator = KripkeStructureIterator(structure: VHDLModelCheckerTests.kripkeStructure)
    }

    func testSimpleAlwaysNext() throws {
        let specRaw = """
        // spec:language VHDL

        A X (currentState /= Initial)
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec)) {
            guard
                let error = $0 as? ModelCheckerError, case .unsatisfied(let branches, let expression) = error
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

    func testSimpleAlwaysGlobal() throws {
        let specRaw = """
        // spec:language VHDL

        A G failureCount < 0
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec)) {
            guard let error = $0 as? ModelCheckerError, case .internalError = error else {
                XCTFail("Got incorrect error!")
                return
            }
        }
    }

    func testIncorrectFailureCountAlwaysGlobal() throws {
        let specRaw = """
        // spec:language VHDL

        A G \(VariableName.failureCount.rawValue) < 0
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec)) {
            guard
                let error = $0 as? ModelCheckerError, case .unsatisfied(let branches, let expression) = error
            else {
                XCTFail("Got incorrect error!")
                return
            }
            // print("Failed expression: \(expression.rawValue)")
            // print("Branch nodes: \(branches.count)")
        }
    }

    func testSimpleAlwaysFinally() throws {
        let specRaw = """
        // spec:language VHDL

        A F failureCount < 0
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec)) {
            guard let error = $0 as? ModelCheckerError, case .internalError = error else {
                XCTFail("Got incorrect error!")
                return
            }
        }
    }

    func testSimpleAlwaysGlobalTrue() throws {
        let specRaw = """
        // spec:language VHDL

        A G failureCount >= 0
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec)) {
            guard let error = $0 as? ModelCheckerError, case .internalError = error else {
                XCTFail("Got incorrect error!")
                return
            }
        }
    }

    func testSimpleAlwaysFinallyTrue() throws {
        let specRaw = """
        // spec:language VHDL

        A F failureCount >= 0
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec)) {
            guard let error = $0 as? ModelCheckerError, case .internalError = error else {
                XCTFail("Got incorrect error!")
                return
            }
        }
    }

    func testSimpleAlwaysFinallyFailure() throws {
        let specRaw = """
        // spec:language VHDL

        A F \(VariableName.failureCount.rawValue) < 0
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec)) {
            guard
                let error = $0 as? ModelCheckerError, case .unsatisfied(let branches, let expression) = error
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

    func testSimpleAlwaysNextFailure() throws {
        let specRaw = """
        // spec:language VHDL

        A X \(VariableName.failureCount.rawValue) < 0
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec)) {
            guard
                let error = $0 as? ModelCheckerError, case .unsatisfied(let branches, let expression) = error
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

    func testSimpleAlwaysGlobalSuccess() throws {
        let specRaw = """
        // spec:language VHDL

        A G \(VariableName.failureCount.rawValue) >= 0
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testSimpleAlwaysFinallySuccess() throws {
        let specRaw = """
        // spec:language VHDL

        A F \(VariableName.failureCount.rawValue) >= 0
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testSimpleAlwaysNextSuccess() throws {
        let specRaw = """
        // spec:language VHDL

        A X \(VariableName.failureCount.rawValue) >= 0
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testSimpleExistsGlobalSuccess() throws {
        let specRaw = """
        // spec:language VHDL

        E G \(VariableName.failureCount.rawValue) >= 0
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testSimpleExistsFinallySuccess() throws {
        let specRaw = """
        // spec:language VHDL

        E F \(VariableName.failureCount.rawValue) >= 0
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testSimpleExistsNextSuccess() throws {
        let specRaw = """
        // spec:language VHDL

        E X \(VariableName.failureCount.rawValue) >= 0
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testSimpleExistsGlobalFailure() throws {
        let specRaw = """
        // spec:language VHDL

        E G \(VariableName.failureCount.rawValue) < 0
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec)) {
            guard
                let error = $0 as? ModelCheckerError, case .unsatisfied(let branches, let expression) = error
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

    func testSimpleExistsFinallyFailure() throws {
        let specRaw = """
        // spec:language VHDL

        E F \(VariableName.failureCount.rawValue) < 0
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec)) {
            guard
                let error = $0 as? ModelCheckerError, case .unsatisfied(let branches, let expression) = error
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

    func testSimpleExistsNextFailure() throws {
        let specRaw = """
        // spec:language VHDL

        E X \(VariableName.failureCount.rawValue) < 0
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec)) {
            guard
                let error = $0 as? ModelCheckerError, case .unsatisfied(let branches, let expression) = error
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

    func testModelCheckerBounds() throws {
        let specRaw = """
        // spec:language VHDL

        {A X recoveryMode /= '1'}_{t < 1 ns}
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec)) {
            guard
                let error = $0 as? ModelCheckerError, case .constraintViolation = error
            else {
                XCTFail("Got incorrect error! \($0)")
                return
            }
            // branches.forEach {
            //     print($0.description)
            // }
            // print("Failed expression: \(expression.rawValue)")
            // print("Branch nodes: \(branches.count)")
        }
    }

    func testImplicationFails() throws {
        let specRaw = """
        // spec:language VHDL

        A G recoveryMode = '1' -> A X recoveryMode /= '1'
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec)) {
            guard
                let error = $0 as? ModelCheckerError, case .unsatisfied(let branches, let expression) = error
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

    func testImplication() throws {
        let specRaw = """
        // spec:language VHDL

        A G recoveryMode = '1' -> A G recoveryMode = '1'
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testConjunction() throws {
        let specRaw = """
        // spec:language VHDL

        E G true ^ true
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testConjunctionFails() throws {
        let specs = [
            "A G true ^ false",
            "A G false ^ true",
            "A G false ^ false"
        ]
        let specRaw = "// spec:language VHDL"
        for spec in specs {
            let specification = Specification(rawValue: specRaw + "\n\n" + spec)!
            XCTAssertThrowsError(try checker.check(structure: iterator, specification: specification)) {
                guard
                    let error = $0 as? ModelCheckerError, case .unsatisfied(let branches, let expression) = error
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
        for spec in specs {
            let specification = Specification(rawValue: specRaw + "\n\n" + spec)!
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
                    let error = $0 as? ModelCheckerError, case .unsatisfied(let branches, let expression) = error
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

    func testModelCheckerFails() throws {
        let specRaw = """
        // spec:language VHDL

        A G recoveryMode = '1' -> {A X recoveryMode /= '1'}_{t < 2 us}
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec)) {
            guard
                let error = $0 as? ModelCheckerError, case .unsatisfied(let branches, let expression) = error
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

    func testModelCheckerFailsForTimeConstraint() throws {
        let specRaw = """
        // spec:language VHDL

        {A X recoveryMode /= '1'}_{t < 100 ns}
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec)) {
            guard
                let error = $0 as? ModelCheckerError,
                case .constraintViolation(let branches, let cost, let constraint) = error
            else {
                XCTFail("Got incorrect error!")
                return
            }
            // branches.forEach {
            //     print($0.description)
            // }
            // print("Failed constraint: \(constraint.rawValue)")
            // print("Current cost: \(cost)")
            // print("Branch nodes: \(branches.count)")
        }
    }

    func testModelCheckerFailsForImpliesTimeConstraint() throws {
        let specRaw = """
        // spec:language VHDL

        A G (recoveryMode = '1' -> {A X recoveryMode = '1'}_{t < 100 ns})
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertThrowsError(try checker.check(structure: iterator, specification: spec)) {
            guard
                let error = $0 as? ModelCheckerError,
                case .constraintViolation(let branches, let cost, let constraint) = error
            else {
                XCTFail("Got incorrect error!")
                return
            }
            // branches.forEach {
            //     print($0.description)
            // }
            // print("Failed constraint: \(constraint.rawValue)")
            // print("Current cost: \(cost)")
            // print("Branch nodes: \(branches.count)")
        }
    }

    func testModelCheckerSucceedsWithTimeConstraint() throws {
        let specRaw = """
        // spec:language VHDL

        A G (recoveryMode = '1' -> {A X recoveryMode = '1'}_{t <= 1 us})
        """
        let spec = Specification(rawValue: specRaw)!
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testImpliesCycle() throws {
        let specRaw = """
        // spec:language VHDL

        A G bootMode = '1' and bootSuccess = '1' -> {A F operationalMode = '1'}_{t <= 2 us}
        """
        let spec = Specification(rawValue: specRaw)!
        let iterator = KripkeStructureIterator(structure: KripkeStructureTestable.modeSelectorKripkeStructure)
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

    func testExistsUntil() throws {
        let specRaw = """
        // spec:language VHDL

        A G operationalMode = '1' -> E operationalMode = '1' U bootMode = '1'
        """
        let spec = Specification(rawValue: specRaw)!
        let iterator = KripkeStructureIterator(
            structure: KripkeStructureTestable.modeSelectorKripkeStructureOld
        )
        XCTAssertNoThrow(try checker.check(structure: iterator, specification: spec))
    }

}
