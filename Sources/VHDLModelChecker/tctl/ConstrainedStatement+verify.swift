// ConstrainedStatement+verify.swift
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

/// Add verification support to constrained statements.
extension ConstrainedStatement {

    /// The constraint within the statement.
    var constraint: Constraint {
        switch self {
        case .equal(let constraint), .greaterThan(let constraint), .lessThan(let constraint),
            .greaterThanOrEqual(let constraint), .lessThanOrEqual(let constraint), .notEqual(let constraint):
            return constraint
        }
    }

    /// Is the constraint an Energy constraint?
    var isEnergy: Bool {
        switch self.constraint {
        case .time:
            return false
        case .energy:
            return true
        }
    }

    /// Is the constraint a Time constraint?
    var isTime: Bool {
        switch self.constraint {
        case .time:
            return true
        case .energy:
            return false
        }
    }

    // swiftlint:disable function_body_length

    /// Is the maximum value of the constraint greater than the given value?
    /// - Parameter value: The value to compare against.
    /// - Returns: Whether the maximum value is greater than the given value.
    func isMaxGreaterThan(value: ConstrainedStatement) -> Bool {
        switch self {
        case .equal(let lhs):
            switch value {
            case .equal(let rhs):
                return lhs.quantity > rhs.quantity
            case .greaterThan, .greaterThanOrEqual:
                return false
            case .lessThan(let rhs):
                return lhs.quantity >= rhs.quantity
            case .lessThanOrEqual(let rhs):
                return lhs.quantity > rhs.quantity
            case .notEqual:
                return false
            }
        case .greaterThan(let lhs):
            switch value {
            case .equal(let rhs):
                return lhs.quantity > rhs.quantity
            case .greaterThan, .greaterThanOrEqual:
                return false
            case .lessThan(let rhs):
                guard lhs.quantity != rhs.quantity else {
                    return false
                }
                return lhs.quantity >= rhs.quantity
            case .lessThanOrEqual(let rhs):
                return lhs.quantity >= rhs.quantity
            case .notEqual:
                return false
            }
        case .greaterThanOrEqual(let lhs):
            switch value {
            case .equal(let rhs):
                return lhs.quantity > rhs.quantity
            case .greaterThan, .greaterThanOrEqual:
                return false
            case .lessThan(let rhs):
                return lhs.quantity >= rhs.quantity
            case .lessThanOrEqual(let rhs):
                return lhs.quantity > rhs.quantity
            case .notEqual:
                return false
            }
        case .lessThan(let lhs):
            switch value {
            case .equal(let rhs):
                guard lhs.quantity != rhs.quantity else {
                    return false
                }
                return lhs.quantity > rhs.quantity
            case .greaterThan, .greaterThanOrEqual:
                return false
            case .lessThan(let rhs):
                return lhs.quantity > rhs.quantity
            case .lessThanOrEqual(let rhs):
                return lhs.quantity > rhs.quantity
            case .notEqual:
                return false
            }
        case .lessThanOrEqual(let lhs):
            switch value {
            case .equal(let rhs):
                return lhs.quantity > rhs.quantity
            case .greaterThan, .greaterThanOrEqual:
                return false
            case .lessThan(let rhs):
                return lhs.quantity >= rhs.quantity
            case .lessThanOrEqual(let rhs):
                return lhs.quantity > rhs.quantity
            case .notEqual:
                return false
            }
        case .notEqual:
            return false
        }
    }

    /// Is the minimum value of the constraint less than the given value?
    /// - Parameter value: The value to compare against.
    /// - Returns: Whether the minimum value is less than the given value.
    func isMinLessThan(value: ConstrainedStatement) -> Bool {
        switch self {
        case .equal(let lhs):
            switch value {
            case .equal(let rhs):
                return lhs.quantity < rhs.quantity
            case .greaterThan(let rhs):
                return lhs.quantity <= rhs.quantity
            case .greaterThanOrEqual(let rhs):
                return lhs.quantity < rhs.quantity
            case .lessThan, .lessThanOrEqual:
                return false
            case .notEqual:
                return false
            }
        case .greaterThan(let lhs):
            switch value {
            case .equal(let rhs):
                return lhs.quantity < rhs.quantity
            case .greaterThan(let rhs):
                return lhs.quantity < rhs.quantity
            case .greaterThanOrEqual(let rhs):
                return lhs.quantity < rhs.quantity
            case .lessThan, .lessThanOrEqual:
                return false
            case .notEqual:
                return false
            }
        case .greaterThanOrEqual(let lhs):
            switch value {
            case .equal(let rhs):
                return lhs.quantity < rhs.quantity
            case .greaterThan(let rhs):
                return lhs.quantity <= rhs.quantity
            case .greaterThanOrEqual(let rhs):
                return lhs.quantity < rhs.quantity
            case .lessThan, .lessThanOrEqual:
                return false
            case .notEqual:
                return false
            }
        case .lessThan, .lessThanOrEqual:
            switch value {
            case .equal(let rhs):
                return .zero < rhs.quantity
            case .greaterThan(let rhs):
                return .zero <= rhs.quantity
            case .greaterThanOrEqual(let rhs):
                return .zero < rhs.quantity
            case .lessThan, .lessThanOrEqual:
                return false
            case .notEqual:
                return false
            }
        case .notEqual:
            return true
        }
    }

    // swiftlint:enable function_body_length

    /// The maximum value of the constraint.
    /// - Parameter granularity: The granularity of the constraint.
    /// - Returns: The maximum value of the constraint.
    func max(granularity: ScientificQuantity) throws -> ScientificQuantity {
        switch self {
        case .greaterThan, .greaterThanOrEqual:
            return .max
        case .equal(let constraint):
            return constraint.quantity
        case .notEqual(let constraint):
            let amount = constraint.quantity
            let difference = ScientificQuantity.max - amount
            return difference > granularity ? .max : .max - granularity
        case .lessThan(let constraint):
            let quantity = constraint.quantity
            guard quantity.coefficient != 0 else {
                throw ModelCheckerError.internalError
            }
            guard constraint.quantity > granularity else {
                return .zero
            }
            return constraint.quantity - granularity
        case .lessThanOrEqual(let constraint):
            return constraint.quantity
        }
    }

    /// The minimum value of the constraint.
    /// - Parameter granularity: The granularity of the constraint.
    /// - Returns: The minimum value of the constraint.
    func min(granularity: ScientificQuantity) throws -> ScientificQuantity {
        switch self {
        case .lessThan, .lessThanOrEqual:
            return .zero
        case .equal(let constraint):
            return constraint.quantity
        case .notEqual(let constraint):
            let amount = constraint.quantity
            return amount < granularity ? granularity : .zero
        case .greaterThan(let constraint):
            return constraint.quantity + granularity
        case .greaterThanOrEqual(let constraint):
            return constraint.quantity
        }
    }

    /// Verify that a node satisfies the cost constraint.
    /// - Parameters:
    ///   - node: The node to verify.
    ///   - cost: The current elapsed cost of the entire branch.
    /// - Throws: A `VerificationError` if the node does not satisfy the constraint.
    func verify(node: Node, cost: Cost) throws {
        let value: ScientificQuantity
        let other: ScientificQuantity
        let constraint = self.constraint
        switch constraint {
        case .time(let amount, let unit):
            value = cost.time
            other = ScientificQuantity(amount: amount, unit: unit)
        case .energy(let amount, let unit):
            value = cost.energy
            other = ScientificQuantity(amount: amount, unit: unit)
        }
        switch self {
        case .equal:
            guard value.quantity == other.quantity else {
                throw VerificationError.costViolation(node: node, cost: cost, constraint: self)
            }
        case .notEqual:
            guard value.quantity != other.quantity else {
                throw VerificationError.costViolation(node: node, cost: cost, constraint: self)
            }
        case .greaterThan:
            guard value.quantity > other.quantity else {
                throw VerificationError.costViolation(node: node, cost: cost, constraint: self)
            }
        case .greaterThanOrEqual:
            guard value.quantity >= other.quantity else {
                throw VerificationError.costViolation(node: node, cost: cost, constraint: self)
            }
        case .lessThan:
            guard value.quantity < other.quantity else {
                throw VerificationError.costViolation(node: node, cost: cost, constraint: self)
            }
        case .lessThanOrEqual:
            guard value.quantity <= other.quantity else {
                throw VerificationError.costViolation(node: node, cost: cost, constraint: self)
            }
        }
    }

}
