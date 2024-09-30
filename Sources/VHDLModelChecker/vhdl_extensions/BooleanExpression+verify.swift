// BooleanExpression+verify.swift
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

import VHDLKripkeStructures
import VHDLParsing

/// Add `verify` method.
extension BooleanExpression {

    /// Verify the `node` against this expression. This method will throw a ``VerificationError`` if the
    /// node fails to verify.
    /// - Parameter node: The node to verify against.
    /// - Throws: A ``VerificationError`` if the node violates the expression.
    func verify(node: Node) throws {
        switch self {
        case .and(let lhs, let rhs):
            try lhs.verify(node: node)
            try rhs.verify(node: node)
        case .or(let lhs, let rhs):
            do {
                try lhs.verify(node: node)
            } catch _ as VerificationError {
                try rhs.verify(node: node)
            } catch let error {
                throw error
            }
        case .not(let expression):
            do {
                try expression.verify(node: node)
            } catch _ as VerificationError {
                return
            } catch let error {
                throw error
            }
            throw VerificationError.unsatisfied(node: node)
        case .nand(let lhs, let rhs):
            try BooleanExpression.not(value: .logical(operation: .and(lhs: lhs, rhs: rhs))).verify(node: node)
        case .nor(let lhs, let rhs):
            try BooleanExpression.not(value: .logical(operation: .or(lhs: lhs, rhs: rhs))).verify(node: node)
        case .xor(let lhs, let rhs):
            try BooleanExpression.or(
                lhs: .logical(
                    operation: .and(
                        lhs: .logical(operation: .not(value: lhs)),
                        rhs: rhs
                    )
                ),
                rhs: .logical(
                    operation: .and(
                        lhs: lhs,
                        rhs: .logical(operation: .not(value: rhs))
                    )
                )
            )
            .verify(node: node)
        case .xnor(let lhs, let rhs):
            try BooleanExpression.not(value: .logical(operation: .xor(lhs: lhs, rhs: rhs))).verify(node: node)
        }
    }

}
