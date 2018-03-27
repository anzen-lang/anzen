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
        .package(url: "https://github.com/kyouko-taiga/Parsey", .branch("master")),
        .package(url: "https://github.com/kylef/Commander", from: "0.8.0")
        // .package(url: "https://github.com/trill-lang/LLVMSwift.git", .branch("master")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a
        // test suite. Targets can depend on other targets in this package, and on products in
        // packages which this package depends on.
        .target(name: "anzenc"    , dependencies: ["AnzenLib", "Commander", "IO"]),
        .target(name: "AnzenLib"  , dependencies: ["AnzenAST", "AnzenSema", "IO"]),
        .target(name: "AnzenAST"  , dependencies: ["AnzenTypes", "Parsey"]),
        .target(name: "AnzenSema" , dependencies: ["AnzenAST", "AnzenTypes"]),
        .target(name: "AnzenTypes"),
        .target(name: "IO"),
    ]
)
