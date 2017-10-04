Anzen is a programming language that aims at bridging the gap between
modern programming and software verification.
It is primarily inspired by
[Swift](https://swift.org),
[Rust](https://www.rust-lang.org/en-US/) and
[Python](https://www.python.org).
But it also burrows ideas and concepts from many other languages that would be too long to list.

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

## Mulitple paradigms

Because no programming paradigm is better than all other in any situation,
Anzen supports several.
To give just a few examples:

* like C, it supports imperative style,
  where statements mutate variables to change the program's state:

  ```anzen
  let x: @mut = [9, 1, 4]
  sort(collection &- x)
  print(x)
  ```

* like Haskell, it supports functional style,
  that treats computation as the evaluation of functions:

  ```anzen
  print(sorted([9, 1, 4]))
  ```

* like Java, it supports object-oriented programming,
  that lets related data and operations be encapsulated in objects:

  ```anzen
  let x = [9, 1, 4]
  print(x.sorted())
  ```

## Powerful support for verification

Anezn also strongly emphasis on code correctness and safety.
As such it comes with many static and dynamic verification features.
To give just a few examples:

* like Swift, it comes with a strong static type inference system,
  that lets stray variables or invalid applications be detected:

  ```anzen
  let x = 0
  print(x + "Hello")
  # error: main.anzen:2:9
  # no candidate to call '+' with arguments '(_: Int, _: String)'
  ```

* like Rust, it keeps track of variable lifetimes,
  so that dangling references can be detected:

  ```anzen
  let x
  scope {
    let y = 42
    x &- y
    # error: main.anzen:4:5
    # cannot assign reference: 'y' is deallocated before 'x'
  }
  ```

* like Eiffel, it supports contracts,
  that can be used to ensure preconditions, invariants and postconditions:

  ```
  function f(_ a: Int) -> Int
    where a > 0
    {
      return a * 2
    }

  let x = f(-9)
  # error: main.anzen:7:9
  # 'f(-9)' does not respect the contract 'a > 0'
  ```
