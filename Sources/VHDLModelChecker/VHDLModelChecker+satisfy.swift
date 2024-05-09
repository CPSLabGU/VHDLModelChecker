// VHDLModelChecker+satisfy.swift
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

extension VHDLModelChecker {

    func satisfy(constraint path: ConstrainedPath, seen: inout Set<Constraint>) throws -> [ConstrainedPath] {
        switch path {
        case .all(let paths):
            return try self.satisfy(all: paths, seen: &seen)
        case .any(let paths):
            return try self.satisfy(any: paths, seen: &seen)
        }
    }

    func satisfy(all paths: [Constraint], seen: inout Set<Constraint>) throws -> [ConstrainedPath] {
        let nextPaths = try paths.flatMap { try self.satisfy(allConstraint: $0, seen: &seen) }
            .filter { !seen.contains($0) }
        guard !nextPaths.isEmpty else {
            return []
        }
        return [ConstrainedPath.all(paths: nextPaths)]
    }

    func satisfy(any paths: [Constraint], seen: inout Set<Constraint>) throws -> [ConstrainedPath] {
        let nextPaths = try paths.map { try self.satisfy(anyConstraint: $0, seen: &seen) }
        let isFinished = nextPaths.contains {
            guard case .success(let constraint) = $0, case .future = constraint.constraint else {
                return false
            }
            return true
        }
        guard !isFinished else {
            return []
        }
        let lazyPaths = nextPaths.lazy
        let nowPaths = lazyPaths.filter {
            guard case .success = $0 else {
                return false
            }
            switch $0.constraint.constraint {
            case .now:
                return true
            default:
                return false
            }
        }
        let futurePaths = lazyPaths.filter {
            switch $0.constraint.constraint {
            case .future:
                return true
            default:
                return false
            }
        }
        let constraints = (Array(nowPaths) + Array(futurePaths)).map { $0.constraint }
        let edgeConstraints = try constraints.flatMap { constraint in
            guard let edges = self.iterator.edges[constraint.node] else {
                throw VerificationError.notSupported
            }
            return edges.map { Constraint(constraint: constraint.constraint, node: $0.destination) }
        }
        .filter { !seen.contains($0) }
        guard !edgeConstraints.isEmpty else {
            throw VerificationError.notSupported
        }
        return [ConstrainedPath.any(paths: edgeConstraints)]
    }

    func satisfy(
        allConstraint constraint: Constraint, seen: inout Set<Constraint>
    ) throws -> [Constraint] {
        seen.insert(constraint)
        guard let node = self.iterator.nodes[constraint.node] else {
            throw VerificationError.notSupported
        }
        switch constraint.constraint {
        case .now(let expression), .future(let expression):
            guard let req = PropertyRequirement(constraint: expression), req.requirement(node) else {
                throw VerificationError.notSupported
            }
        default:
            throw VerificationError.notSupported
        }
        guard let edges = self.iterator.edges[constraint.node] else {
            throw VerificationError.notSupported
        }
        return edges.map { Constraint(constraint: constraint.constraint, node: $0.destination) }
    }

    func satisfy(
        anyConstraint constraint: Constraint, seen: inout Set<Constraint>
    ) throws -> VerificationState {
        seen.insert(constraint)
        guard let node = self.iterator.nodes[constraint.node] else {
            throw VerificationError.notSupported
        }
        switch constraint.constraint {
        case .now(let expression), .future(let expression):
            guard let req = PropertyRequirement(constraint: expression) else {
                throw VerificationError.notSupported
            }
            guard req.requirement(node) else {
                return .failure(constraint: constraint)
            }
            return .success(constraint: constraint)
        default:
            throw VerificationError.notSupported
        }
    }

}
