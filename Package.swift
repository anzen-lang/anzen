// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "anzen",
    products: [
        .executable(name: "anzenc", targets: ["anzenc"]),
        .library(name: "AnzenLib", type: .static, targets: ["AnzenLib"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/kyouko-taiga/Parsey.git", .branch("master")),
        .package(url: "https://github.com/kyouko-taiga/SwiftProductGenerator.git", from: "1.0.1"),
        // .package(url: "https://github.com/trill-lang/LLVMSwift.git", .branch("master")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a
        // test suite. Targets can depend on other targets in this package, and on products in
        // packages which this package depends on.
        .target(name: "anzenc"    , dependencies: ["AnzenLib"]),
        .target(name: "AnzenLib"  , dependencies: ["AnzenAST"]),
        .target(name: "AnzenAST"  , dependencies: ["Parsey", "AnzenTypes"]),
        // .target(name: "AnzenSema" , dependencies: ["AnzenAST", "AnzenTypes"]),
        .target(name: "AnzenTypes"),
    ]
)
