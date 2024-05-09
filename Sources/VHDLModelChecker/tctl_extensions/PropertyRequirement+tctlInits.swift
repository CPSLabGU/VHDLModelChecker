// PropertyRequirement+tctlInits.swift
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

extension PropertyRequirement {

    init?(constraint: Expression) {
        switch constraint {
        case .language(let expression):
            self.init(constraint: expression)
        case .precedence(let expression):
            guard let subExpression = PropertyRequirement(constraint: expression) else {
                return nil
            }
            self.init { (subExpression.requirement($0)) }
        case .implies(let lhs, let rhs):
            guard
                let lhsReq = PropertyRequirement(constraint: lhs),
                let rhsReq = PropertyRequirement(constraint: rhs)
            else {
                return nil
            }
            self.init { lhsReq.requirement($0) ? rhsReq.requirement($0) : true }
        case .quantified(let expression):
            self.init(constraint: expression)
        }
    }

    init?(constraint: LanguageExpression) {
        switch constraint {
        case .vhdl(let expression):
            self.init(constraint: expression)
        }
    }

    init?(constraint: GloballyQuantifiedExpression) {
        switch constraint {
        case .always(let expression), .eventually(let expression):
            guard let requirement = PropertyRequirement(constraint: expression) else {
                return nil
            }
            self.init { requirement.requirement($0) }
        }
    }

    init?(constraint: PathQuantifiedExpression) {
        switch constraint {
        case .finally(let expression), .globally(let expression):
            guard let req = PropertyRequirement(constraint: expression) else {
                return nil
            }
            self.init { req.requirement($0) }
        default:
            return nil
        }
    }

}
