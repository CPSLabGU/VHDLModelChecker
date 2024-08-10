// InMemoryDataStore.swift
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

class InMemoryDataStore: JobStorable {

    private var jobs: [UUID: Job] = [:]

    private var jobIds: [JobData: UUID] = [:]

    private var pendingJobs: [UUID] = []

    private var cycles: Set<CycleData> = []

    private var completedSessions: [UUID: ModelCheckerError?] = [:]

    private var pendingSessions: [UUID: Job] = [:]

    private var sessionIds: [SessionKey: UUID] = [:]

    // var sessionReferences: [UUID: UInt] = [:]

    var next: UUID? {
        pendingJobs.popLast()
    }

    var pendingSessionJob: Job? {
        self.pendingSessions.first?.value
    }

    init() {
        self.jobIds.reserveCapacity(1000000)
        self.jobs.reserveCapacity(1000000)
        self.pendingJobs.reserveCapacity(1000000)
        self.cycles.reserveCapacity(1000000)
        self.completedSessions.reserveCapacity(1000000)
        self.pendingSessions.reserveCapacity(1000000)
        self.sessionIds.reserveCapacity(1000000)
        // self.sessionReferences.reserveCapacity(1000000)
    }

    @discardableResult
    func addJob(data: JobData) throws -> UUID {
        let id = try job(forData: data).id
        self.pendingJobs.append(id)
        return id
    }

    func addManyJobs(jobs: [JobData]) throws {
        let ids = try jobs.map {
            try self.job(forData: $0).id
        }
        self.pendingJobs.append(contentsOf: ids)
    }

    func completePendingSession(session: UUID, result: ModelCheckerError?) throws {
        self.completedSessions[session] = .some(result)
        self.pendingSessions[session] = nil
    }

    func inCycle(_ job: Job) throws -> Bool {
        let cycleData = job.cycleData
        let inCycle = self.cycles.contains(cycleData)
        if !inCycle {
            self.cycles.insert(cycleData)
        }
        return inCycle
    }

    func isPending(session: UUID) throws -> Bool {
        self.pendingSessions[session] != nil
    }

    func job(forData data: JobData) throws -> Job {
        if let id = jobIds[data] {
            return jobs[id]!
        } else {
            let id = UUID()
            let newJob = Job(id: id, data: data)
            jobIds[data] = id
            jobs[id] = newJob
            return newJob
        }
    }

    func job(withId id: UUID) throws -> Job {
        guard let job = jobs[id] else {
            fatalError("Unable to fetch job.")
        }
        return job
    }

    func reset() throws {
        self.jobIds.removeAll(keepingCapacity: true)
        self.jobs.removeAll(keepingCapacity: true)
        self.pendingJobs.removeAll(keepingCapacity: true)
        self.cycles.removeAll(keepingCapacity: true)
        self.completedSessions.removeAll(keepingCapacity: true)
        self.pendingSessions.removeAll(keepingCapacity: true)
        self.sessionIds.removeAll(keepingCapacity: true)
        // self.sessionReferences.removeAll(keepingCapacity: true)
    }

    func sessionId(forJob job: Job) throws -> UUID {
        let key = job.sessionKey
        let out: UUID
        if let id = self.sessionIds[key] {
            out = id
        } else {
            // sessionReferences[id] = 0
            out = UUID()
            self.sessionIds[key] = out
        }
        if try self.sessionStatus(session: out) == nil {
            self.pendingSessions[out] = job
        }
        return out
    }

    func sessionStatus(session: UUID) throws -> ModelCheckerError?? {
        self.completedSessions[session]
    }

}
