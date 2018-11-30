# Anzen

Anzen is a programming language that aims at bridging the gap between
modern programming and software verification.

Anzen is simple and intuitive

```anzen
print("Hello, World!")
```

yet it handles very abstract concepts

```anzen
switch (a, b) {
  when (let x, let y)
    where x is Comparable
      and type(of x) == type(of y)
    {
      print("{x} < {y} = {x < y}")
    }
  else {
    print("{x} and {y} can't be compared")
  }
}
```

and can be entirely statically verified

```anzen
function f(_ a: Int) -> Int
  where a > 0
  {
    return a * 2
  }

let x = f(-9)
# error: main.anzen:7:9
# 'f(-9)' does not respect the contract 'a > 0'
```

## Run the tests

Tests of the type inference are done with actual Anzen files.
Test fixtures are placed in the directory `Tests/Anzen/inference`,
accompanied with oracles that consist of the expected annotated AST.
The test driver expects the environment variables `ANZENPATH` and `ANZENTESTPATH` to be set.
