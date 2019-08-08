// swift-tools-version:4.2
import PackageDescription

let package = Package(
  name: "anzen",
  products: [
    .executable(name: "anzen", targets: ["anzen"]),
  ],
  dependencies: [
    .package(url: "https://github.com/kyouko-taiga/ArgParse.git", from: "1.1.0"),
    .package(url: "https://github.com/anzen-lang/SystemKit", .branch("master")),
  ],
  targets: [
    .target(name: "anzen", dependencies: ["Parser", "Sema", "ArgParse"]),
    // .target(name: "AnzenIR", dependencies: ["AST", "Utils"]),
    // .target(name: "AnzenLib", dependencies: ["Parser", "Interpreter", "Sema"]),
    .target(name: "AST", dependencies: ["Utils"]),
    // .target(name: "Interpreter", dependencies: ["AnzenIR"]),
    .target(name: "Parser", dependencies: ["AST", "Utils"]),
    .target(name: "Sema", dependencies: ["AST", "Parser", "Utils", "SystemKit"]),
    .target(name: "Utils", dependencies: ["SystemKit"]),

    .target(name: "AssertThat", dependencies: ["Utils"]),

    // .testTarget(name: "AnzenTests", dependencies: ["AnzenLib"]),
    .testTarget(name: "ParserTests", dependencies: ["AssertThat", "Parser"]),
    .testTarget(name: "SemaTests", dependencies: ["AssertThat", "Parser", "Sema"]),
  ]
)
