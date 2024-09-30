import Foundation
import TCTLParser
import VHDLKripkeStructures
@testable import VHDLModelChecker
import VHDLParsing
import XCTest

/// Test class for ``VHDLModelChecker``.
final class VHDLModelCheckerTests: KripkeStructureTestable {

    // swiftlint:disable line_length

    /// A raw specification to test again.
    let specRaw = """
    // spec:language VHDL

    A G operationalMode = '1' and currentState = WaitForFailureReset -> A F RecoveryModeMachine_failureCount = 0
    """

    // swiftlint:enable line_length

    // swiftlint:disable implicitly_unwrapped_optional

    /// The specification to test against.
    lazy var specification: RequirementsSpecification = .tctl(
        // swiftlint:disable:next force_unwrapping
        specification: Specification(rawValue: specRaw)!
    )

    // swiftlint:enable implicitly_unwrapped_optional

    /// The iteratore to use when verifying the specification.
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
