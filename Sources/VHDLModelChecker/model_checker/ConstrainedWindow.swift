// ConstrainedWindow.swift
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

/// A small window determined by the minimum and maximum values of a set of constraints.
struct ConstrainedWindow: Equatable, Hashable, Codable, Sendable {

    /// The costs of each constraint.
    private let costs: [ConstraintSymbol: ScientificQuantity]

    /// The minimum values of each constraint.
    private let minimums: [ConstraintSymbol: ScientificQuantity]

    /// The maximum values of each constraint.
    private let maximums: [ConstraintSymbol: ScientificQuantity]

    /// Whether the current cost is above the window.
    var isAboveWindow: Bool {
        self.maximums.contains {
            self.currentCost(constraint: $0) > $1
        }
    }

    /// Whether the current cost is below the window.
    var isBelowWindow: Bool {
        self.minimums.contains {
            self.currentCost(constraint: $0) < $1
        }
    }

    /// Whether the current cost is within the window.
    var isWithinWindow: Bool {
        !self.isAboveWindow && !self.isBelowWindow
    }

    /// Initialise from time and energy constraints.
    init(
        cost: Cost,
        timeMinimum: ScientificQuantity? = nil,
        timeMaximum: ScientificQuantity? = nil,
        energyMinimum: ScientificQuantity? = nil,
        energyMaximum: ScientificQuantity? = nil
    ) {
        self.init(
            costs: .init(cost: cost),
            minimums: [
                ConstraintSymbol.timeSymbol: timeMinimum ?? .zero,
                ConstraintSymbol.energySymbol: energyMinimum ?? .zero,
            ],
            maximums: [
                ConstraintSymbol.timeSymbol: timeMaximum ?? .max,
                ConstraintSymbol.energySymbol: energyMaximum ?? .max,
            ]
        )
    }

    /// Initialise from stored properties.
    init(
        costs: [ConstraintSymbol: ScientificQuantity] = [:],
        minimums: [ConstraintSymbol: ScientificQuantity],
        maximums: [ConstraintSymbol: ScientificQuantity]
    ) {
        self.costs = costs
        self.minimums = minimums
        self.maximums = maximums
    }

    /// Add a cost to the window.
    func addCost(cost: Cost) -> ConstrainedWindow {
        self.addCost(cost: .init(cost: cost))
    }

    /// Add a cost to the window.
    func addCost(cost: [ConstraintSymbol: ScientificQuantity]) -> ConstrainedWindow {
        let result = self.costs.merging(cost) { $0 + $1 }
        return ConstrainedWindow(costs: result, minimums: self.minimums, maximums: self.maximums)
    }

    /// The current cost of a given constraint.
    func currentCost(constraint: ConstraintSymbol) -> ScientificQuantity {
        self.costs[constraint] ?? .zero
    }

    /// The maximum cost of a given constraint.
    func maximum(constraint: ConstraintSymbol) -> ScientificQuantity {
        self.maximums[constraint] ?? .max
    }

    /// The minimum cost of a given constraint.
    func minimum(constraint: ConstraintSymbol) -> ScientificQuantity {
        self.minimums[constraint] ?? .zero
    }

}

/// Add `init` for `Cost`.
extension Dictionary where Key == ConstraintSymbol, Value == ScientificQuantity {

    /// Initialise from a `Cost`.
    fileprivate init(cost: Cost) {
        self = [
            ConstraintSymbol.timeSymbol: cost.time,
            ConstraintSymbol.energySymbol: cost.energy,
        ]
    }

}
