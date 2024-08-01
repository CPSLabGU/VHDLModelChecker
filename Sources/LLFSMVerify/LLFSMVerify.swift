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

@main
struct LLFSMVerify: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "llfsm-verify",
        abstract: "Verify a Kripke structure against a specification.",
        version: "1.0.0"
    )

    @Flag(help: "Whether the structure path is a URL to a machine.")
    var machine = false

    @Argument(
        // swiftlint:disable:next line_length
        help: "The location of the Kripke structure. This path may also be a URL to a machine by specifying the --machine flag"
    )
    var structurePath: String

    @Argument(help: "The paths to the requirements specification files.")
    var requirements: [String]

    @Flag(help: "Write the counter example to a graphviz file called branch.dot")
    var writeGraphviz = false

    @Option(help: "The maximum number of states to return in the counter example.")
    var branchDepth: UInt?

    @Flag(
        help: """
        Write the entire Kripke Structure. This flag must also be used with the --write-graphviz flag.
        The --branch-depth option is also ignored when this flag is present.
        """
    )
    var entireStructure = false

    func run() throws {
        let baseURL = URL(fileURLWithPath: structurePath, isDirectory: machine)
        let structureURL = machine
            ? baseURL.appendingPathComponent("output.json", isDirectory: false)
            : baseURL
        try self.verify(structureURL: structureURL)
    }

    func verify(structureURL: URL) throws {
        let requirements = try requirements.compactMap {
            RequirementsSpecification(
                rawValue: try String(contentsOf: URL(fileURLWithPath: $0, isDirectory: false))
            )
        }
        guard requirements.count == self.requirements.count else {
            throw ModelCheckerError.internalError
        }
        let structureData = try Data(contentsOf: structureURL)
        let decoder = JSONDecoder()
        let structure = try decoder.decode(KripkeStructure.self, from: structureData)
        let modelChecker = VHDLModelChecker()
        do {
            try modelChecker.verify(structure: structure, against: requirements)
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

    func writeGraphvizFile(rawValue: String) throws {
        let diagram = Data(rawValue.utf8)
        let url = URL(fileURLWithPath: "graph.dot", isDirectory: false)
        try diagram.write(to: url)
    }

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
            branch: counterBranch, expression: expression, base: base
        )
        try createGraphvizFile(for: counterBranch, error: newError, structure: structure)
    }

    func writeBranch(for branch: [Node], error: Error, structure: KripkeStructure) throws {
        guard let initialNode = branch.first else {
            return
        }
        var edges: [Node: [Edge]] = [:]
        let branchSet = Set(branch)
        var lastNode = initialNode
        try branch.dropFirst().forEach { node in
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
            nodes: Array(branchSet), edges: edges, initialStates: [initialNode]
        )
        try writeGraphvizFile(rawValue: newStructure.graphviz)
    }

    func writeStructure(for branch: [Node], error: Error, structure: KripkeStructure) throws {
        let branchNodes = Set(branch)
        let nodeKeys = Dictionary(uniqueKeysWithValues: structure.nodes.enumerated().map { ($1, $0) })
        let nodesString = nodeKeys.lazy.sorted { $0.value < $1.value }
            .map {
                let color = branchNodes.contains($0.key) ? "red" : "black"
                let nodeStr = "\"\($0.value)\" [style=rounded shape=rectangle label=\"\($0.key.graphviz)\" " +
                    "color=\"\(color)\" fontcolor=\"\(color)\"]"
                guard structure.initialStates.contains($0.key) else {
                    return nodeStr
                }
                return "\"\($0.value)-0\" [shape=point color=\"\(color)\"]\n" +
                    "\(nodeStr)\n\"\($0.value)-0\" -> \"\($0.value)\" [color=\"\(color)\"" +
                    " fontcolor=\"\(color)\"]"
            }
            .joined(separator: "\n")
            .components(separatedBy: "\n")
            .map { "    \($0)" }
            .joined(separator: "\n")
        let edges = structure.edges.lazy.filter { nodeKeys[$0.key] != nil }
            .sorted { nodeKeys[$0.key]! < nodeKeys[$1.key]! }
            .flatMap { node1, edges1 in
                let id = nodeKeys[node1]!
                return edges1.map {
                    let color = branchNodes.contains(node1) && branchNodes.contains($0.target)
                        ? "red" : "black"
                    guard let id2 = nodeKeys[$0.target] else {
                        fatalError("Failed to create graphviz edge for node \($0.target)")
                    }
                    return "\"\(id)\" -> \"\(id2)\" [label=\($0.cost.graphviz) color=\"\(color)\"" +
                        " fontcolor=\"\(color)\"]"
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

    func createGraphvizFile(for branch: [Node], error: Error, structure: KripkeStructure) throws {
        guard entireStructure else {
            try writeBranch(for: branch, error: error, structure: structure)
            return
        }
        try writeStructure(for: branch, error: error, structure: structure)
    }

}
