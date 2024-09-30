// VHDLModelChecker.swift
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
import VHDLParsing

/// A model checker for verifying VHDL LLFSMs.
public struct VHDLModelChecker {

    /// Creates a new model checker.
    public init() {}

    /// Verify a VHDL LLFSM against a set of requirements.
    /// - Parameters:
    ///   - structure: The Kripke structure representing the VHDL LLFSM.
    ///   - specification: The requirements to verify against the VHDL LLFSM.
    ///   - store: The store to use throughout the verification.
    ///   - path: The path to the store if required.
    public func verify(
        structure: KripkeStructure,
        against specification: [RequirementsSpecification],
        store: VerificationStore = .inMemory,
        path: String? = nil
    ) throws {
        switch store {
        case .inMemory:
            try self.verify(
                checker: TCTLModelChecker(store: InMemoryDataStore()),
                structure: structure,
                specification: specification
            )
        case .sqlite:
            throw UnrecoverableError.notSupported
        // guard let path else {
        //     throw ModelCheckerError.internalError
        // }
        // try self.verify(
        //     checker: TCTLModelChecker(store: try SQLiteJobStore(path: path)),
        //     structure: structure,
        //     specification: specification
        // )
        }
    }

    /// Verify a VHDL LLFSM against a set of TCTL requirements.
    /// - Parameters:
    ///   - checker: The model checker to use.
    ///   - structure: The Kripke structure representing the VHDL LLFSM.
    ///   - specification: The requirements to verify against the VHDL LLFSM.
    func verify<T>(
        checker: TCTLModelChecker<T>,
        structure: KripkeStructure,
        specification: [RequirementsSpecification]
    ) throws {
        let iterator = KripkeStructureIterator(structure: structure)
        let clock = ContinuousClock()
        let elapsedTime = try clock.measure {
            try specification.forEach {
                switch $0 {
                case .tctl(let specification):
                    try checker.check(structure: iterator, specification: specification)
                }
            }
        }
        print("Verification completed in \(elapsedTime) (± \(clock.minimumResolution)).")
    }

}
