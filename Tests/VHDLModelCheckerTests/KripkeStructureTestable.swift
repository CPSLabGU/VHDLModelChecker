// KripkeStructureTestable.swift
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

import TCTLParser
import VHDLKripkeStructures
@testable import VHDLModelChecker
import XCTest

/// A test class that tests the kripke structure.
class KripkeStructureTestable: XCTestCase {

    /// The kripke structure to test.
    static let kripkeStructure = {
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

    // swiftlint:disable implicitly_unwrapped_optional

    /// A `10 us` constraint.
    let constraint10us = Constraint.time(amount: 10, unit: .us)

    /// A `100 us` constraint.
    let constraint100us = Constraint.time(amount: 100, unit: .us)

    /// A `200 us` constraint.
    let constraint200us = Constraint.time(amount: 200, unit: .us)

    /// A `10 mJ` constraint.
    let constraint10mJ = Constraint.energy(amount: 10, unit: .mJ)

    /// A `20 mJ` constraint.
    let constraint20mJ = Constraint.energy(amount: 20, unit: .mJ)

    /// A `200 mJ` constraint.
    let constraint200mJ = Constraint.energy(amount: 200, unit: .mJ)

    /// The current cost.
    let cost = Cost(
        time: ScientificQuantity(amount: 100, unit: .us), energy: ScientificQuantity(amount: 20, unit: .mJ)
    )

    /// A node with a failure count of 2.
    lazy var failureCount2Node: Node! = Self.kripkeStructure.nodes.lazy.first { (node: Node) -> Bool in
        node.properties[.failureCount] == .integer(value: 2)
    }

    // swiftlint:enable implicitly_unwrapped_optional

    /// Initialise the failure count node before every test.
    override func setUp() {
        failureCount2Node = Self.kripkeStructure.nodes.lazy.first { (node: Node) -> Bool in
            node.properties[.failureCount] == .integer(value: 2)
        }
    }

}
