// swift-tools-version:5.1
import PackageDescription

let package = Package(
  name: "anzen",
  products: [
    .executable(name: "anzen", targets: ["anzen"]),
  ],
  dependencies: [
    .package(url: "https://github.com/anzen-lang/SystemKit", .branch("master")),
  ],
  targets: [
    // The Anzen compiler CLI.
    .target(name: "anzen", dependencies: ["AnzenLib"]),

    // The Anzen compiler library, which exposes the compiler driver.
    .target(name: "AnzenLib", dependencies: ["Parser", "Sema"]),

    // Internal libraries.
    .target(name: "AST", dependencies: ["Utils"]),
    .target(name: "Parser", dependencies: ["AST", "Utils"]),
    .target(name: "Sema", dependencies: ["AST", "Parser", "Utils", "SystemKit"]),
    .target(name: "Utils", dependencies: ["SystemKit"]),
    // .target(name: "AnzenIR", dependencies: ["AST", "Utils"]),
    // .target(name: "Interpreter", dependencies: ["AnzenIR"]),

    // Utility targets.
    .target(name: "AssertThat"),

    // Test targets.
    // .testTarget(name: "AnzenTests", dependencies: ["AnzenLib"]),
    .testTarget(name: "ParserTests", dependencies: ["AssertThat", "Parser"]),
    .testTarget(name: "SemaTests", dependencies: ["AssertThat", "AnzenLib"]),
  ]
)
