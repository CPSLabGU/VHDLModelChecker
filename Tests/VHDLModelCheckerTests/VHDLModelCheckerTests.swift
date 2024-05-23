import Foundation
import TCTLParser
import VHDLKripkeStructures
@testable import VHDLModelChecker
import VHDLParsing
import XCTest

/// Test class for ``VHDLModelChecker``.
final class VHDLModelCheckerTests: KripkeStructureTestable {

    /// A raw specification to test again.
    let specRaw = """
    // spec:language VHDL

    A G operationalMode = '1' and currentState = WaitForFailureReset -> A F RecoveryModeMachine_failureCount = 0
    """

    // swiftlint:disable implicitly_unwrapped_optional

    /// The specification to test against.
    lazy var specification: RequirementsSpecification = .tctl(
        // swiftlint:disable:next force_unwrapping
        specification: Specification(rawValue: specRaw)!
    )

    // swiftlint:enable implicitly_unwrapped_optional

    lazy var iterator = KripkeStructureIterator(structure: VHDLModelCheckerTests.kripkeStructure)

    /// The model checker to use when verifying the specification.
    let modelChecker = VHDLModelChecker()

    /// Initialise the test data before every test.
    override func setUp() {
        super.setUp()
        // swiftlint:disable:next force_unwrapping
        specification = .tctl(specification: Specification(rawValue: specRaw)!)
        iterator = KripkeStructureIterator(structure: VHDLModelCheckerTests.kripkeStructure)
    }

    func testSimpleAlwaysNext() throws {
        let checker = TCTLModelChecker()
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
            branches.forEach {
                print($0.description)
            }
            print("Failed expression: \(expression.rawValue)")
            print("Branch nodes: \(branches.count)")
        }
    }

    func testSimpleAlwaysGlobal() throws {
        let checker = TCTLModelChecker()
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

    func testSimpleAlwaysGlobalFailure() throws {
        let checker = TCTLModelChecker()
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
            branches.forEach {
                print($0.description)
            }
            print("Failed expression: \(expression.rawValue)")
            print("Branch nodes: \(branches.count)")
        }
    }

    func testModelCheckerFails() throws {
        let checker = TCTLModelChecker()
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
            branches.forEach {
                print($0.description)
            }
            print("Failed expression: \(expression.rawValue)")
            print("Branch nodes: \(branches.count)")
        }
    }

    func testModelCheckerFailsForTimeConstraint() throws {
        let checker = TCTLModelChecker()
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
            print("Failed constraint: \(constraint.rawValue)")
            print("Current cost: \(cost)")
            print("Branch nodes: \(branches.count)")
        }
    }

    func testModelCheckerFailsForImpliesTimeConstraint() throws {
        let checker = TCTLModelChecker()
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
            print("Failed constraint: \(constraint.rawValue)")
            print("Current cost: \(cost)")
            print("Branch nodes: \(branches.count)")
        }
    }

    func testModelCheckerSucceedsWithTimeConstraint() throws {
        let checker = TCTLModelChecker()
        let specRaw = """
        // spec:language VHDL

        A G (recoveryMode = '1' -> {A X recoveryMode = '1'}_{t == 1 us})
        """
        let spec = Specification(rawValue: specRaw)!
        try checker.check(structure: iterator, specification: spec)
    }

    // /// Test a basic verification.
    // func testBasicVerification() throws {
    //     let validStates = kripkeStructure.ringlets.flatMap {
    //         var states: [KripkeNode] = []
    //         if $0.read.properties[VariableName(rawValue: "RecoveryModeMachine_failureCount")!] ==
    //             .integer(value: 3) {
    //             states.append(KripkeNode.read(node: $0.read, currentState: $0.state))
    //         }
    //         if $0.write.properties[VariableName(rawValue: "RecoveryModeMachine_failureCount")!] ==
    //             .integer(value: 3) {
    //             states.append(KripkeNode.write(node: $0.write, currentState: $0.state))
    //         }
    //         return states
    //     }
    //     print("Valid States: \(validStates.count)")
    //     try modelChecker.verify(against: specification)
    // }

    // /// Test that the `validNodeExactly` method fetches the correct nodes.
    // func testLanguageValidNodesExactly() throws {
    //     let requirement = LanguageExpression.vhdl(expression: .conditional(expression: .comparison(
    //         value: .equality(
    //             lhs: .reference(variable: .variable(reference: .variable(name: .failureCount))),
    //             rhs: .literal(value: .integer(value: 3))
    //         )
    //     )))
    //     let validNodes = try modelChecker.validNodesExactly(for: requirement)
    //     var expected: [KripkeNode] = []
    //     kripkeStructure.ringlets.forEach {
    //         if $0.read.properties[.failureCount] == .integer(value: 3) {
    //             expected.append(KripkeNode.read(node: $0.read, currentState: $0.state))
    //         }
    //         if $0.write.properties[.failureCount] == .integer(value: 3) {
    //             expected.append(KripkeNode.write(node: $0.write, currentState: $0.state))
    //         }
    //     }
    //     let expectedSet = Set(expected)
    //     let result = Set(validNodes.compactMap { self.modelChecker.iterator.nodes[$0] })
    //     let validNodes2 = try modelChecker.validNodes(for: GloballyQuantifiedExpression.always(
    //         expression: .globally(expression: .implies(
    //             lhs: .language(expression: requirement),
    //             rhs: .language(expression: .vhdl(expression: .conditional(expression: .comparison(
    //                 value: .equality(
    //                     lhs: .reference(variable: .variable(reference: .variable(name: .recoveryMode))),
    //                     rhs: .literal(value: .bit(value: .high))
    //                 )
    //             ))))
    //         ))
    //     ))
    //     let result2 = Set(validNodes2.compactMap { self.modelChecker.iterator.nodes[$0] })
    //     XCTAssertEqual(expectedSet, result)
    //     XCTAssertEqual(expectedSet, result2)
    // }
}
