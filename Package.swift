// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// The package definition.
let package = Package(
    name: "VHDLModelChecker",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other
        // packages.
        .library(
            name: "VHDLModelChecker",
            targets: ["VHDLModelChecker"]
        ),
        .executable(name: "llfsm-verify", targets: ["LLFSMVerify"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
        .package(url: "https://github.com/mipalgu/VHDLParsing", from: "2.4.0"),
        .package(url: "https://github.com/cpslabgu/TCTLParser", from: "1.1.0"),
        .package(url: "https://github.com/cpslabgu/VHDLKripkeStructures", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.4.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package
        // depends on.
        .target(
            name: "VHDLModelChecker",
            dependencies: [
                .product(name: "VHDLParsing", package: "VHDLParsing"),
                .product(name: "TCTLParser", package: "TCTLParser"),
                .product(name: "VHDLKripkeStructures", package: "VHDLKripkeStructures")
            ]
        ),
        .executableTarget(
            name: "LLFSMVerify",
            dependencies: [
                .target(name: "VHDLModelChecker"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "VHDLKripkeStructures", package: "VHDLKripkeStructures")
            ]
        ),
        .testTarget(
            name: "VHDLModelCheckerTests",
            dependencies: [
                .target(name: "VHDLModelChecker"),
                .product(name: "VHDLParsing", package: "VHDLParsing"),
                .product(name: "TCTLParser", package: "TCTLParser"),
                .product(name: "VHDLKripkeStructures", package: "VHDLKripkeStructures")
            ],
            resources: [
                .process("output.json"),
                .process("modeSelector_kripkeStructure.json"),
                .process("modeSelector_kripkeStructure_old.json")
            ]
        )
    ]
)
