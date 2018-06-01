// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "anzen",
    products: [
        .executable(name: "anzen", targets: ["anzen"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "anzen"       , dependencies: ["Parser", "Interpreter", "Sema"]),
        .target(name: "AST"         , dependencies: ["Utils"]),
        .target(name: "Interpreter" , dependencies: ["AST", "Utils"]),
        .target(name: "Parser"      , dependencies: ["AST", "Utils"]),
        .target(name: "Sema"        , dependencies: ["AST", "Parser", "Utils"]),
        .target(name: "Utils"),

        .testTarget(name: "SemaTests", dependencies: ["Parser", "Sema"]),
    ]
)
