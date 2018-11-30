// swift-tools-version:4.0
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
    .target(name: "anzen"       , dependencies: ["AnzenLib"]),
    .target(name: "AnzenLib"    , dependencies: ["Parser", "Interpreter", "Sema"]),
    .target(name: "AST"         , dependencies: ["Utils"]),
    .target(name: "Interpreter" , dependencies: ["AST", "Utils"]),
    .target(name: "Parser"      , dependencies: ["AST", "Utils"]),
    .target(name: "Sema"        , dependencies: ["AST", "Parser", "Utils", "SystemKit"]),
    .target(name: "Utils"       , dependencies: ["SystemKit"]),

    .testTarget(name: "SemaTests", dependencies: ["AnzenLib", "Sema"]),
  ]
)
