// ConstrainedStatementVerifyTests.swift
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

/// Test class for `verify` function in `ConstrainedStatement` extensions.
final class ConstrainedStatementVerifyTests: KripkeStructureTestable {

    /// The current cost.
    let cost = Cost(
        time: ScientificQuantity(amount: 100, unit: .us), energy: ScientificQuantity(amount: 20, unit: .mJ)
    )

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

    /// Test the `constraint` computed property.
    func testConstraint() {
        XCTAssertEqual(ConstrainedStatement.equal(constraint: constraint10us).constraint, constraint10us)
        XCTAssertEqual(
            ConstrainedStatement.greaterThan(constraint: constraint10us).constraint, constraint10us
        )
        XCTAssertEqual(ConstrainedStatement.lessThan(constraint: constraint10us).constraint, constraint10us)
        XCTAssertEqual(
            ConstrainedStatement.greaterThanOrEqual(constraint: constraint10us).constraint, constraint10us
        )
        XCTAssertEqual(
            ConstrainedStatement.lessThanOrEqual(constraint: constraint10us).constraint, constraint10us
        )
        XCTAssertEqual(ConstrainedStatement.notEqual(constraint: constraint10us).constraint, constraint10us)
    }

    /// Test that `verify` fails correctly for time.
    func testFailingTime() {
        XCTAssertThrowsError(
            try ConstrainedStatement.lessThan(constraint: constraint10us)
                .verify(node: failureCount2Node, cost: cost)
        )
        XCTAssertThrowsError(
            try ConstrainedStatement.lessThanOrEqual(constraint: constraint10us)
                .verify(node: failureCount2Node, cost: cost)
        )
        XCTAssertThrowsError(
            try ConstrainedStatement.equal(constraint: constraint10us)
                .verify(node: failureCount2Node, cost: cost)
        )
        XCTAssertThrowsError(
            try ConstrainedStatement.notEqual(constraint: constraint100us)
                .verify(node: failureCount2Node, cost: cost)
        )
        XCTAssertThrowsError(
            try ConstrainedStatement.greaterThan(constraint: constraint200us)
                .verify(node: failureCount2Node, cost: cost)
        )
        XCTAssertThrowsError(
            try ConstrainedStatement.greaterThanOrEqual(constraint: constraint200us)
                .verify(node: failureCount2Node, cost: cost)
        )
    }

    /// Tests that `verify` fails correctly for energy.
    func testFailingEnergy() {
        XCTAssertThrowsError(
            try ConstrainedStatement.lessThan(constraint: constraint10mJ)
                .verify(node: failureCount2Node, cost: cost)
        )
        XCTAssertThrowsError(
            try ConstrainedStatement.lessThanOrEqual(constraint: constraint10mJ)
                .verify(node: failureCount2Node, cost: cost)
        )
        XCTAssertThrowsError(
            try ConstrainedStatement.equal(constraint: constraint10mJ)
                .verify(node: failureCount2Node, cost: cost)
        )
        XCTAssertThrowsError(
            try ConstrainedStatement.notEqual(constraint: constraint20mJ)
                .verify(node: failureCount2Node, cost: cost)
        )
        XCTAssertThrowsError(
            try ConstrainedStatement.greaterThan(constraint: constraint200mJ)
                .verify(node: failureCount2Node, cost: cost)
        )
        XCTAssertThrowsError(
            try ConstrainedStatement.greaterThanOrEqual(constraint: constraint200mJ)
                .verify(node: failureCount2Node, cost: cost)
        )
    }

    /// Test that `verify` succeeds correctly for time.
    func testSuccessTime() throws {
        try ConstrainedStatement.lessThan(constraint: constraint200us)
            .verify(node: failureCount2Node, cost: cost)
        try ConstrainedStatement.lessThanOrEqual(constraint: constraint200us)
            .verify(node: failureCount2Node, cost: cost)
        try ConstrainedStatement.equal(constraint: constraint100us)
            .verify(node: failureCount2Node, cost: cost)
        try ConstrainedStatement.notEqual(constraint: constraint10us)
            .verify(node: failureCount2Node, cost: cost)
        try ConstrainedStatement.greaterThan(constraint: constraint10us)
            .verify(node: failureCount2Node, cost: cost)
        try ConstrainedStatement.greaterThanOrEqual(constraint: constraint10us)
            .verify(node: failureCount2Node, cost: cost)
    }

    /// Test that `verify` succeeds correctly for energy.
    func testSuccessEnergy() throws {
        try ConstrainedStatement.lessThan(constraint: constraint200mJ)
            .verify(node: failureCount2Node, cost: cost)
        try ConstrainedStatement.lessThanOrEqual(constraint: constraint200mJ)
            .verify(node: failureCount2Node, cost: cost)
        try ConstrainedStatement.equal(constraint: constraint20mJ)
            .verify(node: failureCount2Node, cost: cost)
        try ConstrainedStatement.notEqual(constraint: constraint10mJ)
            .verify(node: failureCount2Node, cost: cost)
        try ConstrainedStatement.greaterThan(constraint: constraint10mJ)
            .verify(node: failureCount2Node, cost: cost)
        try ConstrainedStatement.greaterThanOrEqual(constraint: constraint10mJ)
            .verify(node: failureCount2Node, cost: cost)
    }

}
