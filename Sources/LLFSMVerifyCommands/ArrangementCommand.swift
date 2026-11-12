import ArgumentParser
import Foundation
import JavascriptModel
import VHDLArrangementStructures
import VHDLKripkeStructures
import VHDLMachines
import VHDLParsing

/// The `arrangement` subcommand.
public struct ArrangementCommand: ParsableCommand {

    /// The command configuration.
    public static let configuration = CommandConfiguration(
        commandName: "arrangement",
        abstract: "Verify an Arrangement of machines against a specification.",
    )

    /// The arrangements path.
    @ArgumentParser.Argument(help: "The path to the arrangement folder.")
    public var path: String

    /// Whether the specification is a raw query.
    @Option(help: "Whether the specification is a raw query.")
    public var query: Bool = false

    /// The specification to verify against.
    @ArgumentParser.Argument(help: "The specifications to verify against.")
    public var specifications: [String]

    /// The arrangement path as a `URL`.
    var pathURL: URL {
        URL(fileURLWithPath: self.path, isDirectory: true)
    }

    /// The path of the arrangements type-aware model.
    var arrangementModel: URL {
        self.pathURL.appending(component: "arrangement.json", directoryHint: .notDirectory)
    }

    /// The path to the Javascript model file.
    var jsModel: URL {
        self.pathURL.appending(component: "model.json", directoryHint: .notDirectory)
    }

    /// The path to the verification folder.
    var verificationFolder: URL {
        self.pathURL.appending(component: "verification", directoryHint: .isDirectory)
    }

    /// The path to the kripke structure file.
    var kripkeStructurePath: URL {
        self.verificationFolder.appending(components: "output.json", directoryHint: .notDirectory)
    }

    /// The raw arguments to the `machine` command.
    var rawArguments: [String] {
        var arguments = [self.path]
        if query {
            arguments.append("--query")
        }
        arguments.append(contentsOf: specifications)
        return arguments
    }

    /// Default init.
    public init() {}

    /// The main entry point.
    public func run() throws {
        let decoder = JSONDecoder()
        let content = try Data(contentsOf: arrangementModel)
        let jsContent = try Data(contentsOf: jsModel)
        let model = try decoder.decode(Arrangement.self, from: content)
        let jsModel = try decoder.decode(ArrangementModel.self, from: jsContent)
        let rawStructures = try jsModel.machines.map { reference in
            let path = URL(fileURLWithPath: reference.path, isDirectory: true)
                .appending(path: "output.json", directoryHint: .notDirectory)
            let contents = try Data(contentsOf: path)
            let structure = try decoder.decode(KripkeStructure.self, from: contents)
            // swiftlint:disable:next force_unwrapping
            let instance = model.machines.keys.first { $0.name == VariableName(rawValue: reference.name)! }!
            return (instance, structure)
        }
        let structures: [MachineInstance: KripkeStructure] = Dictionary(uniqueKeysWithValues: rawStructures)
        let kripkeStructure = KripkeStructure(
            arrangement: model,
            kripkeStructures: structures
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(kripkeStructure)
        let manager = FileManager.default
        if manager.fileExists(atPath: self.verificationFolder.path) {
            try manager.removeItem(at: self.verificationFolder)
        }
        try manager.createDirectory(at: self.verificationFolder, withIntermediateDirectories: true)
        try data.write(to: self.kripkeStructurePath)
        var machineCommand = try MachineCommand.parseAsRoot(self.rawArguments)
        try machineCommand.run()
    }

}
