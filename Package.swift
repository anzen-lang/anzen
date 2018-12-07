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
    .target(name: "anzen"       , dependencies: ["AnzenLib", "ArgParse"]),
    .target(name: "AnzenIR"     , dependencies: ["AST", "Utils"]),
    .target(name: "AnzenLib"    , dependencies: ["Parser", "Interpreter", "Sema"]),
    .target(name: "AST"         , dependencies: ["Utils"]),
    .target(name: "Interpreter" , dependencies: ["AnzenIR"]),
    .target(name: "Parser"      , dependencies: ["AST", "Utils"]),
    .target(name: "Sema"        , dependencies: ["AST", "Parser", "Utils", "SystemKit"]),
    .target(name: "Utils"       , dependencies: ["SystemKit"]),

    .testTarget(name: "SemaTests", dependencies: ["AnzenLib", "Sema"]),
  ]
)
