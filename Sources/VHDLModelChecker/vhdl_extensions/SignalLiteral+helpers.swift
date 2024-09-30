// SignalLiteral+helpers.swift
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

import VHDLParsing

/// Add boolean property.
extension SignalLiteral {

    // swiftlint:disable discouraged_optional_boolean

    /// The boolean value of the signal literal.
    var boolean: Bool? {
        guard case .boolean(let value) = self else {
            return nil
        }
        return value
    }

    // swiftlint:enable discouraged_optional_boolean

}

/// Add equality operator.
extension SignalLiteral {

    /// Value-based equality.
    static func == (lhs: SignalLiteral, rhs: SignalLiteral) -> Bool {
        switch (lhs, rhs) {
        case (.bit(let lhs), .bit(let rhs)):
            return lhs == rhs
        case (.boolean(let lhs), .boolean(let rhs)):
            return lhs == rhs
        case (.decimal(let lhs), .decimal(let rhs)):
            return lhs == rhs
        case (.integer(let lhs), .integer(let rhs)):
            return lhs == rhs
        case (.integer(let lhs), .decimal(let rhs)):
            return Double(lhs) == rhs
        case (.decimal(let lhs), .integer(let rhs)):
            return lhs == Double(rhs)
        case (.logic(let lhs), .logic(let rhs)):
            return lhs == rhs
        case (.bit(let lhs), .logic(let rhs)):
            return LogicLiteral(bit: lhs) == rhs
        case (.logic(let lhs), .bit(let rhs)):
            return lhs == LogicLiteral(bit: rhs)
        case (.vector(let lhs), .vector(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }

}

/// Add equality.
extension VectorLiteral {

    /// Value-based equality.
    static func == (lhs: VectorLiteral, rhs: VectorLiteral) -> Bool {
        switch (lhs, rhs) {
        case (.bits(let lhs), .bits(let rhs)):
            return lhs == rhs
        case (.hexademical(let lhs), .hexademical(let rhs)):
            return lhs == rhs
        case (.octal(let lhs), octal(let rhs)):
            return lhs == rhs
        case (.logics(let lhs), .logics(let rhs)):
            return lhs == rhs
        case (.bits(let lhs), .logics(let rhs)):
            return lhs.values.map(LogicLiteral.init(bit:)) == rhs.values
        case (.logics(let lhs), .bits(let rhs)):
            return lhs.values == rhs.values.map(LogicLiteral.init(bit:))
        case (.indexed(let lhs), .indexed(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }

}

/// Add `Comparable` conformance.
extension SignalLiteral: Comparable {

    /// `Comparable` implementation.
    public static func < (lhs: SignalLiteral, rhs: SignalLiteral) -> Bool {
        switch (lhs, rhs) {
        case (.decimal(let lhs), .decimal(let rhs)):
            return lhs < rhs
        case (.integer(let lhs), .integer(let rhs)):
            return lhs < rhs
        default:
            return false
        }
    }

}
