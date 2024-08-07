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

    private var jobs: [Job] = []

    private var cycles: Set<CycleData> = []

    private var completedSessions: [UUID: ModelCheckerError?] = [:]

    private var pendingSessions: [UUID: Job] = [:]

    private var sessionIds: [SessionKey: UUID] = [:]

    // var sessionReferences: [UUID: UInt] = [:]

    private var revisitIds: [Revisit: UUID] = [:]

    private var revisits: [UUID: Revisit] = [:]

    var next: Job? {
        jobs.popLast()
    }

    var nextPendingSession: (UUID, Job)? {
        self.pendingSessions.first
    }

    init() {
        self.jobs.reserveCapacity(1000000)
        self.cycles.reserveCapacity(1000000)
        self.completedSessions.reserveCapacity(1000000)
        self.pendingSessions.reserveCapacity(1000000)
        self.sessionIds.reserveCapacity(1000000)
        // self.sessionReferences.reserveCapacity(1000000)
        self.revisitIds.reserveCapacity(1000000)
        self.revisits.reserveCapacity(1000000)
    }

    func addCycle(cycle: CycleData) throws {
        self.cycles.insert(cycle)
    }

    func addJob(job: Job) throws {
        self.jobs.append(job)
    }

    func addKey(key: SessionKey) throws -> UUID {
        let id = UUID()
        self.sessionIds[key] = id
        return id
    }

    func addManyJobs(jobs: [Job]) throws {
        self.jobs.append(contentsOf: jobs)
    }

    func addRevisit(revisit: Revisit) throws -> UUID {
        let id = UUID()
        self.revisitIds[revisit] = id
        self.revisits[id] = revisit
        return id
    }

    func addSessionJob(session: UUID, job: Job) throws {
        pendingSessions[session] = job
    }

    func hasCycle(cycle: CycleData) throws -> Bool {
        self.cycles.contains(cycle)
    }

    func removePendingSession(session: UUID) throws {
        self.completedSessions[session] = .some(nil)
        self.pendingSessions[session] = nil
    }

    func reset() throws {
        self.jobs.removeAll(keepingCapacity: true)
        self.cycles.removeAll(keepingCapacity: true)
        self.completedSessions.removeAll(keepingCapacity: true)
        self.pendingSessions.removeAll(keepingCapacity: true)
        self.sessionIds.removeAll(keepingCapacity: true)
        // self.sessionReferences.removeAll(keepingCapacity: true)
        self.revisitIds.removeAll(keepingCapacity: true)
        self.revisits.removeAll(keepingCapacity: true)
    }

    func revisit(id: UUID) throws -> Revisit? {
        self.revisits[id]
    }

    func revisitID(revisit: Revisit) throws -> UUID? {
        self.revisitIds[revisit]
    }

    func sessionId(key: SessionKey) throws -> UUID? {
        self.sessionIds[key]
    }

    func sessionStatus(session: UUID) throws -> ModelCheckerError?? {
        self.completedSessions[session]
    }

}
