// LLFSMVerify.swift
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

import ArgumentParser
import Foundation
import VHDLKripkeStructures
import VHDLModelChecker

/// The main command line tool for verifying VHDL Kripke structures against requirements.
@main
public struct LLFSMVerify: ParsableCommand {

    /// The command configuration.
    public static let configuration = CommandConfiguration(
        commandName: "llfsm-verify",
        abstract: "Verify a Kripke structure against a specification.",
        version: "0.1.0"
    )

    /// Whether the structure path is a URL to a machine.
    @Flag(help: "Whether the structure path is a URL to a machine.")
    public var machine = false

    // swiftlint:disable line_length

    /// The location of the Kripke structure.
    @Argument(
        help:
            "The location of the Kripke structure. This path may also be a URL to a machine by specifying the --machine flag"
    )
    public var structurePath: String

    // swiftlint:enable line_length

    /// Whether the requirements are raw CTL queries.
    @Flag(help: "Whether the requirements are raw CTL queries.")
    public var query = false

    /// The paths to the requirements specification files.
    @Argument(help: "The paths to the requirements specification files.")
    public var requirements: [String]

    /// Whether to write the counter example to a graphviz file.
    @Flag(help: "Write the counter example to a graphviz file called branch.dot")
    public var writeGraphviz = false

    /// The maximum number of states to return in the counter example.
    @Option(help: "The maximum number of states to return in the counter example.")
    public var branchDepth: UInt?

    /// Whether to write the entire Kripke structure.
    @Flag(
        help: """
            Write the entire Kripke Structure. This flag must also be used with the --write-graphviz flag.
            The --branch-depth option is also ignored when this flag is present.
            """
    )
    public var entireStructure = false

    /// The store to use for verification jobs.
    @Option(
        help: """
            The store to use for verification jobs. Please make sure libsqlite-dev is installed on your system
            before choosing the sqlite store.
            """
    )
    public var store: VerificationStore = .inMemory

    /// The path to the database file when specifying the SQLite store via the --store option.
    @Option(
        help: """
            The path to the database file when specifying the SQLite store via the --store option. If the
            --machine flag is present, then this path is ignored and the database will be located in
            the build/verification folder in the machine.
            """
    )
    public var storePath: String = "verification.db"

    /// The actual store path to use.
    @inlinable public var actualStorePath: String {
        machine ? "build/verification/verification.db" : storePath
    }

    /// The raw specification strings.
    @inlinable public var specRaw: [String] {
        get throws {
            guard !query else {
                let queries = requirements.joined(separator: "\n\n")
                return [
                    """
                    // spec:language VHDL

                    \(queries)

                    """
                ]
            }
            let specs = try requirements.compactMap {
                try String(contentsOf: URL(fileURLWithPath: $0, isDirectory: false))
            }
            guard specs.count == requirements.count else {
                throw ModelCheckerError.internalError
            }
            return specs
        }
    }

    /// Create a new instance of the command.
    public init() {}

    /// The main run function.
    @inlinable
    public func run() throws {
        let baseURL = URL(fileURLWithPath: structurePath, isDirectory: machine)
        let structureURL =
            machine
            ? baseURL.appendingPathComponent("output.json", isDirectory: false)
            : baseURL
        try self.verify(structureURL: structureURL)
    }

    /// Verify the structure against the requirements.
    @inlinable
    func verify(structureURL: URL) throws {
        let requirements = try specRaw.compactMap { RequirementsSpecification(rawValue: $0) }
        guard requirements.count == (try specRaw.count) else {
            throw ModelCheckerError.internalError
        }
        let structureData = try Data(contentsOf: structureURL)
        let decoder = JSONDecoder()
        let structure = try decoder.decode(KripkeStructure.self, from: structureData)
        let modelChecker = VHDLModelChecker()
        do {
            try modelChecker.verify(
                structure: structure,
                against: requirements,
                store: self.store,
                path: self.actualStorePath
            )
        } catch let error as ModelCheckerError {
            try handleError(error: error, structure: structure)
            throw error
        } catch {
            throw error
        }
        guard writeGraphviz else {
            return
        }
        try writeGraphvizFile(rawValue: structure.graphviz)
    }

    /// Write the graphviz file.
    @inlinable
    func writeGraphvizFile(rawValue: String) throws {
        let diagram = Data(rawValue.utf8)
        let url: URL
        if machine {
            let verificationFolder = URL(fileURLWithPath: structurePath, isDirectory: true)
                .appendingPathComponent("build/verification", isDirectory: true)
            let manager = FileManager.default
            var isDirectory: ObjCBool = false
            if !manager.fileExists(atPath: verificationFolder.path, isDirectory: &isDirectory) {
                try manager.createDirectory(at: verificationFolder, withIntermediateDirectories: true)
                isDirectory = true
            }
            if !isDirectory.boolValue {
                throw ModelCheckerError.internalError
            }
            url = URL(fileURLWithPath: structurePath, isDirectory: true)
                .appendingPathComponent("build/verification/graph.dot", isDirectory: false)
        } else {
            url = URL(fileURLWithPath: "graph.dot", isDirectory: false)
        }
        try diagram.write(to: url, options: .atomic)
    }

    /// Handle the error.
    @inlinable
    func handleError(error: ModelCheckerError, structure: KripkeStructure) throws {
        guard writeGraphviz, case .unsatisfied(let branch, let expression, let base) = error else {
            return
        }
        let counterBranch: [Node]
        if let branchDepth {
            counterBranch = Array(branch.dropFirst(max(branch.count - Int(branchDepth), 0)))
        } else {
            counterBranch = branch
        }
        let newError = ModelCheckerError.unsatisfied(
            branch: counterBranch,
            expression: expression,
            base: base
        )
        try createGraphvizFile(for: counterBranch, error: newError, structure: structure)
    }

    /// Write the branch to a graphviz file.
    @inlinable
    func writeBranch(for branch: [Node], error: Error, structure: KripkeStructure) throws {
        guard let initialNode = branch.first else {
            return
        }
        var edges: [Node: [Edge]] = [:]
        let branchSet = Set(branch)
        var lastNode = initialNode
        try branch.dropFirst()
            .forEach { node in
                guard let edge = structure.edges[lastNode]?.first(where: { $0.target == node }) else {
                    throw ModelCheckerError.internalError
                }
                defer { lastNode = node }
                guard let currentEdges = edges[lastNode] else {
                    edges[lastNode] = [edge]
                    return
                }
                edges[lastNode] = Array(Set(currentEdges + [edge]))
            }
        let newStructure = KripkeStructure(
            nodes: Array(branchSet),
            edges: edges,
            initialStates: [initialNode]
        )
        try writeGraphvizFile(rawValue: newStructure.graphviz)
    }

    /// Write the structure to a graphviz file.
    @inlinable
    func writeStructure(for branch: [Node], error: Error, structure: KripkeStructure) throws {
        let branchNodes = Set(branch)
        let nodeKeys = Dictionary(uniqueKeysWithValues: structure.nodes.enumerated().map { ($1, $0) })
        let nodesString = nodeKeys.lazy.sorted { $0.value < $1.value }
            .map {
                let color = branchNodes.contains($0.key) ? "red" : "black"
                let nodeStr =
                    "\"\($0.value)\" [style=rounded shape=rectangle label=\"\($0.key.graphviz)\" "
                    + "color=\"\(color)\" fontcolor=\"\(color)\"]"
                guard structure.initialStates.contains($0.key) else {
                    return nodeStr
                }
                return "\"\($0.value)-0\" [shape=point color=\"\(color)\"]\n"
                    + "\(nodeStr)\n\"\($0.value)-0\" -> \"\($0.value)\" [color=\"\(color)\""
                    + " fontcolor=\"\(color)\"]"
            }
            .joined(separator: "\n")
            .components(separatedBy: "\n")
            .map { "    \($0)" }
            .joined(separator: "\n")
        let edges = structure.edges.lazy.filter { nodeKeys[$0.key] != nil }
            // swiftlint:disable:next force_unwrapping
            .sorted { nodeKeys[$0.key]! < nodeKeys[$1.key]! }
            .flatMap { node1, edges1 in
                // swiftlint:disable:next force_unwrapping
                let id = nodeKeys[node1]!
                return edges1.map {
                    let color =
                        branchNodes.contains(node1) && branchNodes.contains($0.target)
                        ? "red" : "black"
                    guard let id2 = nodeKeys[$0.target] else {
                        fatalError("Failed to create graphviz edge for node \($0.target)")
                    }
                    return "\"\(id)\" -> \"\(id2)\" [label=\($0.cost.graphviz) color=\"\(color)\""
                        + " fontcolor=\"\(color)\"]"
                }
            }
        let diagram = """
            digraph {
            \(nodesString)
            \(edges.map { "    \($0)" }.joined(separator: "\n"))
            }
            """
        try writeGraphvizFile(rawValue: diagram)
    }

    /// Create the graphviz file.
    @inlinable
    func createGraphvizFile(for branch: [Node], error: Error, structure: KripkeStructure) throws {
        guard entireStructure else {
            try writeBranch(for: branch, error: error, structure: structure)
            return
        }
        try writeStructure(for: branch, error: error, structure: structure)
    }

}
