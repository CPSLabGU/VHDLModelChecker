// PropertyRequirement.swift
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
import VHDLParsing

struct PropertyRequirement {

    let requirement: ([VariableName: SignalLiteral]) -> Bool

    init(_ requirement: @escaping ([VariableName: SignalLiteral]) -> Bool) {
        self.requirement = requirement
    }

    init?(constraint: VHDLExpression) {
        switch constraint {
        case .boolean(let boolean):
            self.init(constraint: boolean)
        case .conditional(let conditional):
            self.init(constraint: conditional)
        }
    }

    init?(constraint: VHDLParsing.Expression) {
        if let boolean = constraint.boolean {
            self.init(constraint: boolean)
            return
        }
        if let conditional = constraint.conditional {
            self.init(constraint: conditional)
            return
        }
        return nil
    }

    init?(constraint: BooleanExpression) {
        switch constraint {
        case .not(let expression):
            guard let req = PropertyRequirement(constraint: expression) else {
                return nil
            }
            self.init { !req.requirement($0) }
        case .and(let lhs, let rhs):
            guard
                let lhs = PropertyRequirement(constraint: lhs), let rhs = PropertyRequirement(constraint: rhs)
            else {
                return nil
            }
            self.init { lhs.requirement($0) && rhs.requirement($0) }
        case .nand(let lhs, let rhs):
            guard
                let lhs = PropertyRequirement(constraint: lhs), let rhs = PropertyRequirement(constraint: rhs)
            else {
                return nil
            }
            self.init { !(lhs.requirement($0) && rhs.requirement($0)) }
        case .nor(let lhs, let rhs):
            guard
                let lhs = PropertyRequirement(constraint: lhs), let rhs = PropertyRequirement(constraint: rhs)
            else {
                return nil
            }
            self.init { !(lhs.requirement($0) || rhs.requirement($0)) }
        case .or(let lhs, let rhs):
            guard
                let lhs = PropertyRequirement(constraint: lhs), let rhs = PropertyRequirement(constraint: rhs)
            else {
                return nil
            }
            self.init { lhs.requirement($0) || rhs.requirement($0) }
        case .xnor(let lhs, let rhs):
            guard
                let lhs = PropertyRequirement(constraint: lhs), let rhs = PropertyRequirement(constraint: rhs)
            else {
                return nil
            }
            self.init { lhs.requirement($0) == rhs.requirement($0) }
        case .xor(let lhs, let rhs):
            guard
                let lhs = PropertyRequirement(constraint: lhs), let rhs = PropertyRequirement(constraint: rhs)
            else {
                return nil
            }
            self.init { lhs.requirement($0) != rhs.requirement($0) }
        }
    }

    init?(constraint: ConditionalExpression) {
        switch constraint {
        case .literal, .edge:
            return nil
        case .comparison(let comparison):
            self.init(constraint: comparison)
        }
    }

    init?(constraint: ComparisonOperation) {
        switch constraint {
        case .equality(let lhs, let rhs):
            guard let variable = lhs.variable, let rhs = rhs.literal else {
                return nil
            }
            self.init { $0[variable] == rhs }
        case .notEquals(let lhs, let rhs):
            guard let variable = lhs.variable, let rhs = rhs.literal else {
                return nil
            }
            self.init { $0[variable] != rhs }
        case .greaterThan(let lhs, let rhs):
            guard let variable = lhs.variable, let rhs = rhs.literal else {
                guard let lhs = lhs.literal, let rhs = rhs.variable else {
                    return nil
                }
                self.init { $0[rhs].flatMap { lhs > $0 } ?? false }
                return
            }
            self.init { $0[variable].flatMap { $0 > rhs } ?? false }
        case .greaterThanOrEqual(let lhs, let rhs):
            guard let variable = lhs.variable, let rhs = rhs.literal else {
                guard let lhs = lhs.literal, let rhs = rhs.variable else {
                    return nil
                }
                self.init { $0[rhs].flatMap { lhs >= $0 } ?? false }
                return
            }
            self.init { $0[variable].flatMap { $0 >= rhs } ?? false }
        case .lessThan(let lhs, let rhs):
            guard let variable = lhs.variable, let rhs = rhs.literal else {
                guard let lhs = lhs.literal, let rhs = rhs.variable else {
                    return nil
                }
                self.init { $0[rhs].flatMap { lhs < $0 } ?? false }
                return
            }
            self.init { $0[variable].flatMap { $0 < rhs } ?? false }
        case .lessThanOrEqual(let lhs, let rhs):
            guard let variable = lhs.variable, let rhs = rhs.literal else {
                guard let lhs = lhs.literal, let rhs = rhs.variable else {
                    return nil
                }
                self.init { $0[rhs].flatMap { lhs <= $0 } ?? false }
                return
            }
            self.init { $0[variable].flatMap { $0 <= rhs } ?? false }
        }
    }

}

extension VHDLParsing.Expression {

    var variable: VariableName? {
        guard
            case .reference(let variable) = self,
            case .variable(let variable) = variable,
            case .variable(let variable) = variable
        else {
            return nil
        }
        return variable
    }

    var literal: SignalLiteral? {
        guard case .literal(let literal) = self else {
            return nil
        }
        return literal
    }

    var conditional: ConditionalExpression? {
        guard case .conditional(let condition) = self else {
            return nil
        }
        return condition
    }

    var boolean: BooleanExpression? {
        guard case .logical(let boolean) = self else {
            return nil
        }
        return boolean
    }

}

extension SignalLiteral: Comparable {

    // var bit: BitLiteral? {
    //     guard case .bit(let value) = self else {
    //         return nil
    //     }
    //     return value
    // }

    // var boolean: Bool? {
    //     guard case .boolean(let value) = self else {
    //         return nil
    //     }
    //     return value
    // }

    // var decimal: Double? {
    //     guard case .decimal(let value) = self else {
    //         return nil
    //     }
    //     return value
    // }

    // var integer: Int? {
    //     guard case .integer(let value) = self else {
    //         return nil
    //     }
    //     return value
    // }

    // var logic: LogicLiteral? {
    //     guard case .logic(let value) = self else {
    //         return nil
    //     }
    //     return value
    // }

    // var vector: VectorLiteral? {
    //     guard case .vector(let value) = self else {
    //         return nil
    //     }
    //     return value
    // }

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
