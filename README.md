# VHDLModelChecker
[![Swift Coverage Test](https://github.com/CPSLabGU/VHDLModelChecker/actions/workflows/cov.yml/badge.svg)](https://github.com/CPSLabGU/VHDLModelChecker/actions/workflows/cov.yml)
[![Swift Lint](https://github.com/CPSLabGU/VHDLModelChecker/actions/workflows/swiftlint.yml/badge.svg)](https://github.com/CPSLabGU/VHDLModelChecker/actions/workflows/swiftlint.yml)
[![Linux CI](https://github.com/CPSLabGU/VHDLModelChecker/actions/workflows/ci-linux.yml/badge.svg)](https://github.com/CPSLabGU/VHDLModelChecker/actions/workflows/ci-linux.yml)
[![MacOS CI](https://github.com/CPSLabGU/VHDLModelChecker/actions/workflows/ci-macOS.yml/badge.svg)](https://github.com/CPSLabGU/VHDLModelChecker/actions/workflows/ci-macOS.yml)
[![Windows CI](https://github.com/CPSLabGU/VHDLModelChecker/actions/workflows/ci-windows.yml/badge.svg)](https://github.com/CPSLabGU/VHDLModelChecker/actions/workflows/ci-windows.yml)

> [!IMPORTANT]
> This package is currently under active development and not production-ready.

`VHDLModelChecker` is a Swift package that allows the formal verification of *Logic-Labelled Finite-State Machines* (LLFSMs).
This package focuses on verifying the `VHDL` flavour of LLFSMs with specifications written in temporal logics.

## Requirements and Supported Platforms

- Swift 5.7 or later (See [Installing Swift](#installing-swift)).
- macOS 13 (Ventura) or later.
- Linux (Ubuntu 20.04 or later).
- Windows 10 or later.
- Windows Server Edition 2022 or later.

## Usage
This package consists of two main products:
- A binary called `llfsm-verify` for verifying machines represented using the LLFSM machine format.
- A swift module called `VHDLModelChecker` containing the types for performing the formal verification.

You may compile the package products by invoking a `swift build` within the package directory.
```shell
cd VHDLModelChecker
swift build -c release
```

After the compilation, you will find the binary at `.build/release/llfsm-verify`. It is preferred that the
binary is installed within a location accessible by your `PATH` variable. For example, you may install the
program within `/usr/local/`:
```shell
install -m 0755 .build/release/llfsm-verify /usr/local/bin
```

To depend on the swift module, you may add the `VHDLModelChecker` product to your dependencies within your
package manifest.
```swift
import PackageDescription

let package = Package(
    name: <Package Name>,
    products: [
        <products>...
    ],
    dependencies: [
        .package(url: "https://github.com/cpslabgu/VHDLModelChecker", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: <Target_Name>,
            dependencies: [
                .product(name: "VHDLModelChecker", package: "VHDLModelChecker")
            ]
        ),
    ]
)
```

The `llfsm-verify` binary allows the verification of LLFSM models that contain `VHDL` code within their
state actions. The `llfsm-verify` binary requires a Kripke structure derived from target hardware that the LLFSM
executes on. To see the full instructions for compiling and generating the Kripke structure, see the
[llfsmgenerate](https://github.com/cpslabgu/LLFSMGenerate) command-line utility and the
[LLFSM editor](https://github.com/cpslabgu/editor).

Verifying a machine is as simply as specifying the machine's location on the file-system and a requirements specification.
For example, to verify an LLFSM called `PingPong.machine` against requirements located in `spec.tctl`,
you may invoke the `llfsm-verify` command using the following parameters.

```shell
llfsm-verify --machine PingPong.machine spec.tctl
```

This command will formally verify the machine against the specification placing the entire Kripke structure within memory.

> [!IMPORTANT]
> Please make sure the LLFSM path contains a `.machine` extension.

Currently the only supported specification language is *Computation Tree Logic* (CTL) with support for adding
constraints to each globally quantified expression (e.g. supporting TCTL, RTCTL, etc.). LLFSM Kripke structures
are designed to contain many measurable properties within their structures. The [CTL parser](https://github.com/cpslabgu/TCTLParser)
thus contains support for constraining CTL expressions with any type of quantifiable property. This allows other domains of
formal verification such as time and energy (power analysis and verification).

Please see the *help* section of the binary for a complete list of parameters and sub-commands.
```shell
OVERVIEW: Verify a Kripke structure against a specification.

USAGE: llfsm-verify [--machine] <structure-path> [--query] <requirements> ... [--write-graphviz] [--branch-depth <branch-depth>] [--entire-structure] [--store <store>] [--store-path <store-path>]

ARGUMENTS:
  <structure-path>        The location of the Kripke structure. This path may also be a URL to a machine by specifying the --machine flag
  <requirements>          The paths to the requirements specification files.

OPTIONS:
  --machine               Whether the structure path is a URL to a machine.
  --query                 Whether the requirements are raw CTL queries.
  --write-graphviz        Write the counter example to a graphviz file called branch.dot
  --branch-depth <branch-depth>
                          The maximum number of states to return in the counter example.
  --entire-structure      Write the entire Kripke Structure. This flag must also be used with the --write-graphviz flag.
                          The --branch-depth option is also ignored when this flag is present.
  --store <store>         The store to use for verification jobs. Please make sure libsqlite-dev is installed on your system
                          before choosing the sqlite store. (values: in-memory, sqlite; default: in-memory)
  --store-path <store-path>
                          The path to the database file when specifying the SQLite store via the --store option. If the
                          --machine flag is present, then this path is ignored and the database will be located in
                          the build/verification folder in the machine. (default: verification.db)
  --version               Show the version.
  -h, --help              Show help information.
```

## Documentation

The latest documentation may be found on the
[documentation website](https://cpslabgu.github.io/VHDLModelChecker/).

## Installing Swift

You may verify your swift installation by performing `swift --version`. The minimum required version for
this package is `5.7`. To install swift, follow the instructions below for your operating system.

### Linux

We prefer that you use [swiftenv](https://github.com/kylef/swiftenv) to install swift on linux. To install
`swiftenv`, clone the repository in your home directory.

```shell
git clone https://github.com/kylef/swiftenv.git ~/.swiftenv
```

Then place the following in your `.bash_profile` (or equivalent if using a different shell). Please note,
some systems will require modifying your `.bashrc` instead of `.bash_profile`.

```shell
echo 'export SWIFTENV_ROOT="$HOME/.swiftenv"' >> ~/.bash_profile
echo 'export PATH="$SWIFTENV_ROOT/bin:$PATH"' >> ~/.bash_profile
echo 'eval "$(swiftenv init -)"' >> ~/.bash_profile
```

You may now install swift via:

```shell
source ~/.bash_profile
swiftenv install 6.0
```

The full instructions are provided in the
[swiftenv documentation](https://swiftenv.fuller.li/en/latest/installation.html).

### MacOS

Make sure you install the latest version of XCode through your App store or
[developer website](https://developer.apple.com/xcode/).

### Windows

The full instructions for installing swift may be found on the [swift website](https://www.swift.org/install/windows/).
