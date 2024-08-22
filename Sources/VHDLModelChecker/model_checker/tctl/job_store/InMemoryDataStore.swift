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

    private final class SessionData {

        var count: UInt

        var error: ModelCheckerError?

        init(count: UInt, error: ModelCheckerError? = nil) {
            self.count = count
            self.error = error
        }

    }

    private var jobs: [UUID: Job] = [:]

    private var jobIds: [JobData: UUID] = [:]

    private var pendingJobs: [UUID] = []

    private var cycles: Set<CycleData> = []

    private var sessions: [UUID: SessionData] = [:]

    // var sessionReferences: [UUID: UInt] = [:]

    var next: UUID? {
        get throws {
            guard let id = pendingJobs.popLast() else {
                return nil
            }
            if let session = try self.job(withId: id).session {
                try self.decrementSession(id: session)
            }
            return id
        }
    }

    init() {
        self.jobIds.reserveCapacity(1000000)
        self.jobs.reserveCapacity(1000000)
        self.pendingJobs.reserveCapacity(1000000)
        self.cycles.reserveCapacity(1000000)
    }

    @discardableResult
    func addJob(data: JobData) throws -> UUID {
        let job = try job(forData: data)
        try self.addJob(job: job)
        return job.id
    }

    func addJob(job: Job) throws {
        if let session = job.session {
            self.incrementSession(id: session)
        }
        self.pendingJobs.append(job.id)
    }

    func addManyJobs(jobs: [JobData]) throws {
        let ids = try jobs.map {
            if let session = $0.session {
                self.incrementSession(id: session)
            }
            return try self.job(forData: $0).id
        }
        self.pendingJobs.append(contentsOf: ids)
    }

    func error(session: UUID) throws -> ModelCheckerError? {
        guard let session = self.sessions[session] else {
            throw ModelCheckerError.internalError
        }
        return session.error
    }

    func failSession(id: UUID, error: ModelCheckerError?) throws {
        guard let session = self.sessions[id] else {
            throw ModelCheckerError.internalError
        }
        self.sessions[id] = SessionData(count: session.count, error: error)
    }

    func inCycle(_ job: Job) throws -> Bool {
        let cycleData = job.cycleData
        let inCycle = self.cycles.contains(cycleData)
        if !inCycle {
            self.cycles.insert(cycleData)
        }
        return inCycle
    }

    func isComplete(session: UUID) throws -> Bool {
        guard let session = self.sessions[session] else {
            throw ModelCheckerError.internalError
        }
        // swiftlint:disable:next empty_count
        return session.count == 0
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
            throw JobStoreError.missingJob(id: id)
        }
        return job
    }

    func reset() throws {
        self.jobIds.removeAll(keepingCapacity: true)
        self.jobs.removeAll(keepingCapacity: true)
        self.pendingJobs.removeAll(keepingCapacity: true)
        self.cycles.removeAll(keepingCapacity: true)
    }

    private func incrementSession(id: UUID) {
        guard let session = sessions[id] else {
            sessions[id] = SessionData(count: 1)
            return
        }
        session.count += 1
    }

    private func decrementSession(id: UUID) throws {
        // swiftlint:disable:next empty_count
        guard let session = sessions[id], session.count > 0 else {
            throw ModelCheckerError.internalError
        }
        session.count -= 1
    }

}
