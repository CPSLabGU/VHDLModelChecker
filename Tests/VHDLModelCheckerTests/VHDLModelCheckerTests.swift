import Foundation
import TCTLParser
import VHDLKripkeStructures
@testable import VHDLModelChecker
import VHDLParsing
import XCTest

/// Test class for ``VHDLModelChecker``.
final class VHDLModelCheckerTests: XCTestCase {

    /// Test a basic verification.
    func testBasicVerification() throws {
        let specRaw = """
        // spec:language VHDL

        A G RecoveryModeMachine_failureCount = 3 -> recoveryMode = '1'
        """
        guard let specification = Specification(rawValue: specRaw) else {
            XCTFail("Failed to create spec.")
            return
        }
        let path = FileManager.default.currentDirectoryPath.appending(
            "/Tests/VHDLModelCheckerTests/output.json"
        )
        let data = try Data(contentsOf: URL(fileURLWithPath: path, isDirectory: false))
        let decoder = JSONDecoder()
        let kripkeStructure = try decoder.decode(KripkeStructure.self, from: data)
        let validStates = kripkeStructure.ringlets.flatMap {
            var states: [KripkeNode] = []
            if $0.read.properties[VariableName(rawValue: "RecoveryModeMachine_failureCount")!] ==
                .integer(value: 3) {
                states.append(KripkeNode.read(node: $0.read, currentState: $0.state))
            }
            if $0.write.properties[VariableName(rawValue: "RecoveryModeMachine_failureCount")!] ==
                .integer(value: 3) {
                states.append(KripkeNode.write(node: $0.write, currentState: $0.state))
            }
            return states
        }
        print("Valid States: \(validStates.count)")
        let modelChecker = VHDLModelChecker(structure: kripkeStructure)
        _ = try modelChecker.verify(against: specification)
    }
}
