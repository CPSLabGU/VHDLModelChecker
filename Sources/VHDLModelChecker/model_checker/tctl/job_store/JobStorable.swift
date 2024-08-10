// JobStorable.swift
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

/// A protocol that represents a store of data associated with a particular
/// `TCTLModelChecker`.
protocol JobStorable {

    /// Fetches (and removes from the queue of pending jobs) the id of the
    /// next pending job to handle within the model checker.
    var next: UUID? { mutating get throws }

    /// Fetches a job in a pending session.
    var pendingSessionJob: Job? { get throws }

    /// Store the id of the given job within the queue of pending jobs.
    /// 
    /// This method first checks the existence of the job within the queue before adding it to the pending
    /// jobs. If the data already exists, then the ID of the existing job is used.
    ///
    /// - Parameter data: The data to store within this store.
    ///
    /// - Returns: The unique identifier associated with the job that is now
    /// stored on the queue of pending jobs.
    @discardableResult
    mutating func addJob(data: JobData) throws -> UUID

    /// Stores a job into the queue of pending jobs.
    /// 
    /// This method assumes that the job already exists within the store but is not currently on the queue
    /// of pending jobs.
    /// - Parameter job: The job to place on the queue of pending jobs. 
    mutating func addJob(job: Job) throws

    /// Store all given jobs into the queue of pending jobs.
    ///
    /// - Parameter jobs: The jobs to store.
    mutating func addManyJobs(jobs: [JobData]) throws

    /// Sets a pending session as completed with a given result.
    ///
    /// - Parameter session: The id of the pending session to complete.
    ///
    /// - Parameter result: The result (either an error or nil) indicating
    /// whether the session succeeded (when result is nil) or not (when result
    /// is an error).
    func completePendingSession(session: UUID, result: ModelCheckerError?) throws

    /// Have we seen this cycle before?
    ///
    /// - Parameter cycle: The data used to identify the cycle.
    ///
    /// - Returns: A value of `true` when a cycle has been detected, otherwise
    /// `false`.
    mutating func inCycle(_ job: Job) throws -> Bool

    /// Is the session associated with the given session id pending?
    ///
    /// - Parameter session: The id of the session we are querying.
    ///
    /// - Returns: The value `true` if the session is pending, otherwise
    /// `false`.
    func isPending(session: UUID) throws -> Bool

    /// Fetch a job containg the given data, if a job does not exist yet, generate
    /// one.
    ///
    /// - Parameter data: The data associated with the job we are fetching.
    ///
    /// - Returns: The job associated with `data`.
    mutating func job(forData data: JobData) throws -> Job

    /// Fetch the job associated with the given id.
    ///
    /// - Parameter id: The unique identifier of the job we are fetching.
    ///
    /// - Returns: The job associated with `id`.
    func job(withId id: UUID) throws -> Job

    /// Set `self` to its initial configuration.
    mutating func reset() throws

    /// Fetches the session if associated with the given job.
    ///
    /// - Parameter job: The job to handle within the session.
    ///
    /// - Returns: The id associated with the session containing `job`.
    func sessionId(forJob job: Job) throws -> UUID

    /// Fetches the result of a specific session.
    ///
    /// - Returns: nil when the session is still pending, otherwise an
    /// optional error where nil represents that the session evaluated to
    /// true and when set to an error, indicates that the session evaluated
    /// to false with the corresponding error.
    func sessionStatus(session: UUID) throws -> ModelCheckerError??

}
