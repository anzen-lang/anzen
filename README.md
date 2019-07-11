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
let y &- x

print(y)
// Prints "Hello, World!"

x := "Hi, Universe!"
print(y)
// Prints "Hi, Universe!"
```

## Run the tests

Tests of the type inference are done with actual Anzen files.
Test fixtures are placed in the directory `Tests/Anzen/inference`,
accompanied with oracles that consist of the expected annotated AST.
The test driver expects the environment variables `ANZENPATH` and `ANZENTESTPATH` to be set.
