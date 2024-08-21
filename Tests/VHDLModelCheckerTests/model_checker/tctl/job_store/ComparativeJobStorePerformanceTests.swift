// ComparativeJobStorePerformanceTests.swift
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
@testable import VHDLModelChecker
import XCTest

final class ComparativeJobStorePerformanceTests: XCTestCase {

    let stores: [() -> any JobStorable] = [
        InMemoryDataStore.init,
        { try! SQLiteJobStore() }
    ]

    var revisit: JobData!

    let clock = ContinuousClock()

    override func setUp() {
        self.revisit = JobData(
            nodeId: UUID(),
            expression: Expression.language(expression: .vhdl(expression: .true)),
            history: [],
            currentBranch: [],
            historyExpression: nil,
            constraints: [],
            successRevisit: nil,
            failRevisit: nil
        )
    }

    func newJob(store: inout any JobStorable) throws -> JobData {
        JobData(
            nodeId: UUID(),
            expression: Expression.language(expression: .vhdl(expression: .true)),
            history: [UUID(), UUID()],
            currentBranch: [UUID(), UUID()],
            historyExpression: Expression.language(expression: .vhdl(expression: .false)),
            constraints: [
                PhysicalConstraint(
                    cost: Cost(time: 12, energy: 12),
                    constraint: .lessThan(constraint: .time(amount: 20, unit: .s))
                )
            ],
            successRevisit: try store.job(forData: revisit).id,
            failRevisit: try store.job(forData: revisit).id
        )
    }

    func testAddJob() throws {
        let performanceFactor = try self.compare {
            try _ = $0.addJob(job: $1)
        }
        print("Performance factor: \(performanceFactor)")
        XCTAssertLessThan(performanceFactor, 2.0)
    }

    func testAddJobData() throws {
        let performanceFactor = try self.compare {
            _ = try $0.addJob(data: $1)
        }
        print("Performance factor: \(performanceFactor)")
        XCTAssertLessThan(performanceFactor, 15.0)
    }

    func testAddManyJobs() throws {
        let performanceFactor = try self.compare {
            try $0.addManyJobs(jobs: $1)
        }
        print("Performance factor: \(performanceFactor)")
        XCTAssertLessThan(performanceFactor, 15.0)
    }

    func testInCycle() throws {
        let performanceFactor = try self.compare {
            _ = try $0.inCycle($1)
        }
        print("Performance factor: \(performanceFactor)")
        XCTAssertLessThan(performanceFactor, 9.0)
    }

    func testJob() throws {
        let performanceFactor = try self.compare {
            _ = try $0.job(forData: $1)
        }
        print("Performance factor: \(performanceFactor)")
        XCTAssertLessThan(performanceFactor, 12.0)
    }

    func compare(_ fn: (inout any JobStorable, Job) throws -> Void) throws -> Double {
        let durations = try stores.map { storeFn in
            var store = storeFn()
            let durations: [Duration] = try (0..<10).map { _ in
                let datas = try (0..<1000).map { _ in try self.newJob(store: &store) }
                let jobs = (try datas.map { try store.job(forData: $0) })
                let shuffledJobs = jobs.shuffled()
                let duration = try clock.measure {
                    try shuffledJobs.forEach { try fn(&store, $0) }
                }
                try store.reset()
                return duration
            }
            return durations.reduce(Duration.zero, +) / 10.0
        }
        guard let minDuration = durations.min(), let maxDuration = durations.max() else {
            XCTFail("Failed to get durations.")
            return Double.infinity
        }
        return maxDuration / minDuration
    }

    func compare(_ fn: (inout any JobStorable, JobData) throws -> Void) throws -> Double {
        let durations = try stores.map { storeFn in
            var store = storeFn()
            let durations: [Duration] = try (0..<10).map { _ in
                let datas = try (0..<1000).map { _ in try self.newJob(store: &store) }
                let duration = try clock.measure {
                    try datas.forEach { try fn(&store, $0) }
                }
                try store.reset()
                return duration
            }
            return durations.reduce(Duration.zero, +) / 10.0
        }
        guard let minDuration = durations.min(), let maxDuration = durations.max() else {
            XCTFail("Failed to get durations.")
            return Double.infinity
        }
        return maxDuration / minDuration
    }

    func compare(_ fn: (inout any JobStorable, [JobData]) throws -> Void) throws -> Double {
        let durations = try stores.map { storeFn in
            var store = storeFn()
            let durations: [Duration] = try (0..<10).map { _ in
                let datas = try (0..<1000).map { _ in try self.newJob(store: &store) }
                let duration = try clock.measure {
                    try fn(&store, datas)
                }
                try store.reset()
                return duration
            }
            return durations.reduce(Duration.zero, +) / 10.0
        }
        guard let minDuration = durations.min(), let maxDuration = durations.max() else {
            XCTFail("Failed to get durations.")
            return Double.infinity
        }
        return maxDuration / minDuration
    }

}
