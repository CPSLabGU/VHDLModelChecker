// ConstrainedExpression+verify.swift
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

/// Add verification support.
extension ConstrainedExpression {

    // var energyConstraints: [ConstrainedStatement] {
    //     constraints.filter { $0.isEnergy }
    // }

    // var timeConstraints: [ConstrainedStatement] {
    //     constraints.filter { $0.isTime }
    // }

    /// Get the maximum values for the constraints.
    /// - Parameter granularities: The granularities for the constraints.
    /// - Returns: The maximum values for the constraints.
    func maximums(
        granularities: [ConstraintSymbol: ScientificQuantity]
    ) throws -> [ConstraintSymbol: ScientificQuantity] {
        var maximums: [ConstraintSymbol: ScientificQuantity] = [:]
        try self.constraints.forEach { constraint in
            let symbol = constraint.constraint.symbol
            guard let granularity = granularities[symbol] else {
                throw ModelCheckerError.internalError
            }
            let maxConstraint = try constraint.max(granularity: granularity)
            if let currentMax = maximums[symbol] {
                maximums[symbol] = min(maxConstraint, currentMax)
            } else {
                maximums[symbol] = maxConstraint
            }
        }
        return maximums
    }

    /// Get the minimum values for the constraints.
    /// - Parameter granularities: The granularities for the constraints.
    /// - Returns: The minimum values for the constraints.
    func minimums(
        granularities: [ConstraintSymbol: ScientificQuantity]
    ) throws -> [ConstraintSymbol: ScientificQuantity] {
        var minimums: [ConstraintSymbol: ScientificQuantity] = [:]
        try self.constraints.forEach { constraint in
            let symbol = constraint.constraint.symbol
            guard let granularity = granularities[symbol] else {
                throw ModelCheckerError.internalError
            }
            let minConstraint = try constraint.min(granularity: granularity)
            if let currentMin = minimums[symbol] {
                minimums[symbol] = max(minConstraint, currentMin)
            } else {
                minimums[symbol] = minConstraint
            }
        }
        return minimums
    }

    // func energyMaximum(granularity: ScientificQuantity) throws -> ScientificQuantity? {
    //     try energyConstraints.map { try $0.max(granularity: granularity) }.min()
    // }

    // func energyMinimum(granularity: ScientificQuantity) throws -> ScientificQuantity? {
    //     try energyConstraints.map { try $0.min(granularity: granularity) }.max()
    // }

    // func timeMaximum(granularity: ScientificQuantity) throws -> ScientificQuantity? {
    //     try timeConstraints.map { try $0.max(granularity: granularity) }.min()
    // }

    // func timeMinimum(granularity: ScientificQuantity) throws -> ScientificQuantity? {
    //     try timeConstraints.map { try $0.min(granularity: granularity) }.max()
    // }

    // func granularity(constraints: [ConstrainedStatement]) -> ScientificQuantity? {
    //     guard let quantity = constraints.map({ $0.constraint.quantity }).min() else {
    //         return nil
    //     }
    //     let exponent = quantity.exponent
    //     let coefficient = quantity.coefficient
    //     guard coefficient != 0 else {
    //         return ScientificQuantity(coefficient: 5, exponent: -2)
    //     }
    //     return ScientificQuantity(coefficient: 5, exponent: exponent - 2)
    // }

    /// Verify that `node` satisfies the constraints.
    /// - Parameters:
    ///   - node: The node to verify.
    ///   - inCycle: Whether this node has been visited before.
    ///   - cost: The current cost of the verification.
    /// - Returns: An array of statuses for the verification.
    func verify(currentNode node: Node, inCycle: Bool) throws -> [VerifyStatus] {
        [
            .addConstraints(expression: .quantified(expression: expression), constraints: constraints)
        ]
    }

}
