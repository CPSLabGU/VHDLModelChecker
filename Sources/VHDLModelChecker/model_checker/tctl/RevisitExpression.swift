// RevisitExpression.swift
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

/// A category of successor expression defining the behaviour of the verification.
enum RevisitExpression: CustomStringConvertible, Equatable, Hashable, Codable, Sendable {

    /// This successor is required to pass for the verification to hold.
    /// 
    /// Expression e :: e ? revisit(e') : F
    case required(expression: Expression, constraints: [ConstrainedStatement])

    /// This successor may fail and the verification still holds. When this expression passes, any associated
    /// revisits will be evaluated.
    /// 
    /// Expression e :: !e ? revisit(e') : T
    case skip(expression: Expression, constraints: [ConstrainedStatement])

    /// Expression e :: e ? revisit(e') : T
    case ignored(expression: Expression, constraints: [ConstrainedStatement])

    /// A print-friendly description of the successor.
    var description: String {
        switch self {
        case .required(let expression, let constraints):
            return ".required(\(expression.rawValue), \(constraints.map(\.rawValue).joined(separator: ", ")))"
        case .skip(let expression, let constraints):
            return ".skip(\(expression.rawValue), \(constraints.map(\.rawValue).joined(separator: ", ")))"
        case .ignored(let expression, let constraints):
            return ".ignore(\(expression.rawValue), \(constraints.map(\.rawValue).joined(separator: ", ")))"
        }
    }

    /// The expression associated with this successor.
    var expression: Expression {
        switch self {
        case .required(let expression, _), .skip(let expression, _), .ignored(let expression, _):
            return expression
        }
    }

    /// Whether the successor is required.
    var isRequired: Bool {
        switch self {
        case .required:
            return true
        case .skip, .ignored:
            return false
        }
    }

    var constraints: [ConstrainedStatement] {
        switch self {
        case .skip(_, let constraints), .required(_, let constraints), .ignored(_, let constraints):
            return constraints
        }
    }

    var type: RevisitType {
        switch self {
        case .skip:
            return .skip
        case .required:
            return .required
        case .ignored:
            return .ignored
        }
    }

}
