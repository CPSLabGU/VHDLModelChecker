import ArgumentParser

/// The `arrangement` subcommand.
public struct ArrangementCommand: ParsableCommand {

    /// The command configuration.
    public static let configuration = CommandConfiguration(
        commandName: "arrangement",
        abstract: "Verify the arrangement of a Kripke structure against a specification.",
    )

    /// Default init.
    public init() {}

}
