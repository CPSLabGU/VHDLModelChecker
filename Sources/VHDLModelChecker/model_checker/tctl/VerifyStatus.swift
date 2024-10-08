// VerifyStatus.swift
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

/// The status of an ongoing verification.
enum VerifyStatus: Equatable, Hashable, Codable, Sendable, CustomStringConvertible {

    /// The current verification holds at the current node, but requires
    /// traversing further nodes to evaluate it completely.
    /// - Parameter expression: The expression to evaluate at the next node.
    case successor(expression: Expression)

    /// The current verification holds but contains sub-expressions that need
    /// to be evaluated at future nodes before the verification can be considered
    /// complete.
    /// - Parameters:
    ///   - expression: The expression to re-evaluate once all successor expressions
    ///     have been evaluated.
    ///   - successors: The expressions that need to be evaluated before
    ///     `expression` can be evaulated.
    case revisitting(expression: Expression, precondition: RevisitExpression)

    /// The current verification continues by evaluation the associated
    /// expression with additional constraints.
    /// - Parameters:
    ///     - expression: The expression to evaluate.
    ///     - constraints: The new constraints to add before evaluating
    ///     `expression`.
    case addConstraints(expression: Expression, constraints: [ConstrainedStatement])

    /// A print-friendly string representing this instance.
    var description: String {
        switch self {
        case .successor(let expression):
            return "successor(" + expression.rawValue + ")"
        case .revisitting(let expression, let precondition):
            return "revisitting("
                + expression.rawValue
                + ", "
                + precondition.description
                + ")"
        case .addConstraints(let expression, let constraints):
            return "addConstraints("
                + expression.rawValue
                + ", "
                + constraints.description
                + ")"
        }
    }

    /// Whether the current status is a successor.
    var isSuccessor: Bool {
        switch self {
        case .successor:
            return true
        default:
            return false
        }
    }

    /// Whether the current status is a revisitting status.
    var isRevisitting: Bool {
        switch self {
        case .revisitting:
            return true
        default:
            return false
        }
    }

}
