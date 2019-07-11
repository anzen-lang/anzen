# Anzen

Anzen is a general purpose programming language that aims to make assignments easier to understand and manipulate.
Its most distinguishing characteristic is that it features three different assignment operators.
These are independent of their operands' types and provide the following strategies:

- An aliasing operator `&-` assigns an alias on the object on its right to the reference on its left.
  Its semantics is the closest to what is generally understood as an assignment in languages that abstract over pointers (e.g. Python or Java).
- A copy operator `:=` assigns a deep copy of the object's value on its right to the reference on its left.
  If the left operand was already bound to an object, the copy operator mutates its value rather than reassigning the reference to a different one.
- A move operator `<-` moves the object on its right to the reference on its left.
  If the right operand was a reference, the move operator removes its binding, effectively leaving it unusable until it is reassigned.

Here is an example:

```anzen
let x: @mut <- "Hello, World!"
print(x)
// Prints "Hello, World!"

let y: @mut &- x
print(y)
// Prints "Hello, World!"

x := "Hi, Universe!"
print(y)
// Prints "Hi, Universe!"
```

To learn more about the programming language, please visit [anzen-lang.org](https://www.anzen-lang.org).

## Build Anzen

Anzen's compiler is written in Swift, and distributed as a Swift package.
It is recommended to build it with the [Swift Package Manager (SPM)](https://swift.org/getting-started/#using-the-package-manager).

You can compile the compiler's executable with the `swift build` command and then run it from the `.build` directory.

```bash
swift build
.build/debug/anzen hello.anzen
```

Alternatively, you can build it with Xcode on macOS by creating an Xcode project with SPM.

**Disclaimer**: Anzen is under active development and has not yet hit its first stable release.
While we aim at keeping the master branch buildable, updates and improvements are continuously pushed on it.

## Run the tests

Tests are done with actual Anzen files.
Test fixtures are placed in the directory `Tests/Anzen/`, accompanied with oracles that consist of the expected output.
The test driver expects the environment variables `ANZENPATH` and `ANZENTESTPATH` to be set.

## Contribute

Contributions are more than welcomed.
Some things are already in progress, or have already been drafted on paper, so be sure to check the issues and/or open one before starting anything crazy.

We are also eager to get as many opinions as possible on Anzen, so be sure to give yours in the issues.
