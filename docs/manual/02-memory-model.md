---
layout: page
title: Memory Model
permalink: /manual/chapter-2/
---

There are two ways of allocating memory in a program:
on the program stack or on the heap.
The former usually leads to better performances,
because it lets topologically close variables to live in topographically close memory locations.
Heap allocation can't benefit from the same advantage,
because it requires actual memory locations to dereferenced before it is accessed.
Besides stack allocation makes it easier to deallocate memory:
whenever the stacked is popped, its associated memory is freed.
That's why, Anzen memory is primarily based on the stack:

```anzen
scope {
  # The variable `x` is allocated on the stack
  let x = 42
}
# The variable `x` no longer exists and its memory has been deallocated
```

Anzen also supports references:

```anzen
let x = 42
let y &- x
print(y)
# Prints "42"
```

But remember, since Anzen focuses on stack allocation,
one should worry about the lifetime of her variables:

```anzen
let x
scope {
  let y = 42
  x &- y
  # error: main.anzen:4:5
  # cannot assign reference: 'y' is deallocated before 'x'
}
print(x)
```

To solve the above problem, one should either make a copy of the variable `y`.
But if that's too expensive, one can also *move* the value of `y`:

```anzen
let x
scope {
  let y = (0 .. 10_000).map(functon(i) { return i })
  x <- y
}
print(x)
# Prints "[0, 1, ..., 10000]"
```

The move operator `<-` *steals* the value associated with the variable `y`
and gives it to the variable `x`,
so as to avoid an unnecessary copy.

> If you are familiar with C++,
> Anzen's move operator `<-` corresponds to C++'s `std::move`.
