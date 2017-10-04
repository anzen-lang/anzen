---
layout: page
title: Constants, Variables and Types
permalink: /manual/chapter-1/
---

Anzen distinguishes
[variables](https://en.wikipedia.org/wiki/Variable_(computer_science)) and
[constants](https://en.wikipedia.org/wiki/Constant_(computer_programming)).
Both are an association between a name and a value.
Variables can have their value modified, whereas constants cannot.

Constants and variables are declared with the keyword `let`,
followed by their name:

```anzen
let pokemon_level = 1
```

Anzen is an opinionated language,
as you will discover thorough this manual.
One of its opinionated choices is to prefer constant to variables,
which is why the above statement declares a **constant**.
To declare a variable, the type modifier `@mut` must be specified at the declaration:

```anzen
let pokemon_level: @mut = 1
pokemon_level = 2
```

> In fact, Anzen assumes you used the `@cst` modifier by default.
> That means declaring a constant can be done explicitly by writing:
> ```
> let pokemon_level: @cst = 1
> ```

Only variables can be mutated.
Trying to mutate a constant will trigger an error:

```anzen
let pokemon_species = "Bulbasaur"
pokemon_species = "Pikachu"
# cannot assign to value: 'pokemon_species' is a constant
```

> You are encouraged to always use the most restrictive construct,
> for instance `@cst` (the default modifier) rather than `@mut`.
> This particular choice is called
> [const correctness](https://isocpp.org/wiki/faq/const-correctness)
> in other languages, and helps to avoid some bugs.

The value of variable and constants can be printed with the built-in function `print(_:)`:

```anzen
let pokemon_level = 1
print(pokemon_level)
# 1
```

> We'll discuss functions (and methods) with their syntax and semantics
> at length later in this manual.
> For the time being, just use them as presented in the examples.

From now on, we will talk about variables and constants under the denomination of "variables".

## References and Shared Variables

In the previous section, we saw that variables in Anzen are names
to which some value can be assigned.
Behind the scenes, those values are stored at some location of the computer's memory,
and the name of a variable simply refers to that location.
Anzen allows several names to refer to the same memory location.
In other languages, this concept is called
[aliasing](https://en.wikipedia.org/wiki/Aliasing_(computing)).

```anzen
let pikachu_level = 1
let bulbasaur_level = 2
let strongest_level &- bulbasaur_level
print(strongest_level)
# 2
```

In the above example, the variable `strongest_level` is a *reference*
to the value associated with `bulbasaur_level`.
That is, both names refer to the same memory location.

Notice the use of a new operator `&-` to initialize the value of `strongest_level`.
This operator is called the **reference assignment operator**,
and as its name suggests, it lets us create references to what's on its right.
Because this operator produces references,
type inference can automatically decide that `strongest_level` should be a reference.
Alternatively, you can use the `@ref` type modifier to explicitly declare a reference:

```anzen
let strongest_level: @ref
```

> The same way Anzen assumes you used the `@cst` modifier by default,
> it also assumes you used the `@val` modifier by default,
> which declares values (i.e. not references).
> That means declaring a value can be done explicitly by writing:
> ```
> let pokemon_level: @val = 1
> ```

Like other variables, references are constant by default.
To declare a mutable reference,
the type modifier `@mut` must be specified at the declaration:

```anzen
let bulbasaur_level: @mut = 2
let strongest_level: @mut &- strongest_level
strongest_level = 3
print(strongest_level)
# 3
print(bulbasaur_level)
# 3
```

Note that it isn't possible to create mutable references to constant values.
That's the reason why we declared `bulbasaur_level` mutable in the above example.
Doing otherwise would have triggered an error:

```anzen
let bulbasaur_level = 2
let strongest_level: @mut &- strongest_level
# cannot assign to reference: 'bulbasaur_level' is a constant
```

A reference always references a memory location,
and not the variable it is associated with.
As a result, it is not possible to create references to references.

```anzen
let bulbasaur_level = 2
let strongest_level &- strongest_level
let weakest_level &- strongest_level
```

In the above example,
`weakest_level` is a reference to the value associated with `bulbasaur_level`.
It has no relationship with `strongest_level`.

> Behind the scenes,
> Anzen keeps track of what variable is the original name a value was associated with.
> We will discuss this at length in the chapter about
> [Anzen's memory model]({{ site.baseurl }}manual/chapter-n).

The same way it isn't possible to create mutable references to constant values,
it isn't possible to create mutable references using constant references,
even if the original value is mutable.

```anzen
let bulbasaur_level: @mut = 2
let strongest_level &- strongest_level
let weakest_level: @mut &- strongest_level
# cannot assign to reference: 'strongest_level' is a constant reference
```

## Types

Although the previous examples do not specify what can be stored in a variable,
the Anzen compiler prevents putting arbitrary values in variables.
For instance, it is impossible to put a floating point number
into a variable that has been initialized with an integer:

```anzen
let pokemon_level: @mut = 1
pokemon_level = 2.3
# error: cannot assign value of type 'Double' to type 'Int'
```

Anzen is [strongly typed](https://en.wikipedia.org/wiki/Strong_and_weak_typing).
Every variable is given a unique [type](https://en.wikipedia.org/wiki/Type_system),
and can only store values that correspond to this type.
Weakly typed languages do not have this restriction.
Static typing also helps to ensure [type safety](https://en.wikipedia.org/wiki/Type_safety),
that prevents bugs in programs.

Type correctness is checked by the Anzen compiler.
Anzen ensures that each variable is unambiguously associated with a single type,
and that each operation on that variable is well defined for that type.
The language is thus said [statically typed](https://en.wikipedia.org/wiki/Type_system#STATIC).
On the contrary, a dynamically typed language performs type checking at runtime,
during the program execution.
Static typing also helps to ensure [type safety](https://en.wikipedia.org/wiki/Type_safety).

The type of a variable may not be explicit, but it always exists.
Anzen provides [type inference](https://en.wikipedia.org/wiki/Type_inference).
If the compiler can infer the type of a variable,
it automatically associates this type with the variable.

It is sometimes necessary to explicitly specify the type of a variable,
with what is called *type annotations*.
In the example below, the variable `pokemon_weight` is explicitly typed with `Double`
(for double precision floating point number),
which tells Anzen that it should consider it as a `Double` value:

```anzen
let pokemon_weight: Double
```

> Type inference should be preferred to explicit type annotation,
> as the latter can impair the code readability with unnecessary information.
> For instance, it is **highly discouraged** to write things like:
> ```anzen
> let weight: Kilogram = Kilogram(5.6)
> ```

The type of an expression can be retrieved with the built-in function `type(of:)`:

```anzen
let pokemon_weight = 5.1
print(type(of: pokemon_weight))
# Double
print(type(of: "Pikachu"))
# String
```

Types are first-class citizen in Anzen.
It means that they are also considered as values.
They can be assigned to variables, like any other value,
and can also be passed as parameters to the `print(_:)` or `type(of:)` functions.

```anzen
let t1 = type(of: "Pikachu")
print(t1)
# String
let t2 = type(of: t1)
print(t2)
# String.Type
let t3 = type(of: t2)
print(t3)
# String.Type.Type
```

First-class types are complex and come with some limitations.
They'll be covered in other parts of this manual.

## Enumerations

An enumeration defines a set of possible values for a type.
It can also be named
[union type](https://en.wikipedia.org/wiki/Union_type) in other programming languages.
An enumeration is used to represent types that can have a *fixed* set of possible contents.
Enumerations are not possible if the set of possible contents can be extended,
for instance by the programmer.
They must be fully defined in only one place of the source code.
Enumerations can represent very abstract concepts, like a set of possible shapes,
or more concrete data, like the possible configurations of a library.

An enumeration type is declared using the keyword `enum`,
and its different values with the keyword `case`:

```anzen
enum SpeciesType {
  case grass
  case fire
  case water
}
```

> An enumeration is a type.
> By convention, all type names start with a capital letter (`Int`, `String`, ...)
> and so should enumerations.
> The name of an enumeration should also be singular rather than plural,
> so that its use makes more sense in the code.

A variable of an enumeration type can only be of *one* of the enumeration cases.
Assignment is written using the qualified name of the case:

```anzen
let bulbasaur_species_type = SpeciesType.grass
```

If the type of the variable is explicitly defined or has already been inferred,
it is possible (and preferred) to omit the name of the enumeration:

```anzen
let bulbasaur_species_type: SpeciesType
bulbasaur_species_type = .grass
```

Enumeration cases can store *associated values*.
This allows to add information to particular cases:

```anzen
enum Consumable {
  case pokeball(catch_rate_multiplier: Double)
  case potion(restoration: Int)
}
let ultra_ball = Consumable.pokeball(catch_rate_multiplier: 2.0)
```

Notice that the above `ultra_ball` variable has type `Consumable`.
Hence, it is not possible to directly consider it as a `pokeball`
and access its `catch_rate_multiplier`.
This manual explains later how to obtain such information.

```anzen
ultra_ball.catch_rate_multiplier
// error: value of type 'Consumable' has no member 'catch_rate_multiplier'
```

Enumeration types can be *recursive*.
This is very useful for naturally recursive data structures,
such as [lists](https://en.wikipedia.org/wiki/List_(abstract_data_type)) or [trees](https://en.wikipedia.org/wiki/Tree_(data_structure)).

```anzen
enum IntList {
  case empty
  case cons(head: Int, tail: IntList)
}
let some_list: IntList = .cons(head: 1, tail: .cons(head: 2, tail: .empty))
```

In all above examples, we declared associated values with a label.
In some situations, it may be desirable to omit such information:

```anzen
enum BinaryTree {
  case leaf
  case node(_: BinaryTree, _: BinaryTree)
}
let some_tree : BinaryTree = .node(.leaf, right: .node(.leaf, .leaf))
```

> The use of labels of associated values is highly encouraged,
> unless their meaning is clearly obvious and would only impair code readability.

Enumerations are a very powerful tool in Anzen, and there is much more to talk about.
We'll cover more use cases in later chapters.

## Optionals

We've seen earlier that Anzen lets us declare references to arbitrary memory locations.
However, Anzen requires references to always refer to a valid and initialized memory location.
This makes sure you can safely use the value they reference at any time,
but the drawback is that it isn't possible to use
to represent memory locations that have yet to be initialized.

> In other programming languages, this is often represented by a
> [null pointer](https://en.wikipedia.org/wiki/Null_pointer).
> For instance, all objects in Java can be initialized with `null`,
> which represent the absence of a value.
> Anzen explicitly disallows this practice, because it is error-prone.

Instead, Anzen provides optional types to explicitly state what can be null.
An [optional type](https://en.wikipedia.org/wiki/Option_type) denotes a value
that may be present or not.
It is specified by appending the operator `?` to any type.
The original type is *wrapped* to add the case where it represents the absence of a value:

```anzen
let trainer1: String? = .nothing
let trainer2: String? = .some("Ash")
```

In the above example, the variable `trainer1` is declared to represent the absence of a value.
The variable `trainer2` is declared to represent a some value,
i.e. the string `"Ash"` in that example.

> The reader will notice that optionals look very similar to enumerations.
> That's because they are!
> In fact, Anzen just comes with a few syntactic sugars around optionals,
> which make their use easier.

Optional types take part in [type safety](https://en.wikipedia.org/wiki/Type_safety).
Their use is not transparent to the programmer: it differs from non-optionals.
Assignment to another variable requires that the other variable is also an optional.

```anzen
let trainer1: String? = .some("Ash")
let trainer2: String? = trainer1
let trainer3: String = trainer1
// error: value of optional type 'String?' not unwrapped; did you mean to use '!' or '?'?
```

Any optional can be converted to a non-optional value using the `!` operator.
Anzen returns the wrapped value if it exists,
or throws a runtime error if the optional value was in fact `.nothing`.
This operation is called *forced-unwrapping*:

```anzen
let trainer1: @mut String? = .some("Ash")
let trainer2: String = trainer1!

trainer1 = .nothing
trainer2 = trainer1!
// fatal error: found .nothing while forcibly unwrapping an optional
```

> Runtime errors are not recoverable.
> Hence you should never force-unwrap an optional
> unless your algorithm makes sure it will be assigned to a value before you do it.
> We'll see a way to do that later.

## Tuple

A [tuple](https://en.wikipedia.org/wiki/Tuple) is a container composed of two or more values.
It is a kind of [record data structure](https://en.wikipedia.org/wiki/Record_(computer_science)).
It can be initialized with a comma-separated list of bindings, enclosed in parentheses:

```anzen
let bulbasaur = (number = 001, name = "Bulbasaur")
```

> Unlike some other languages, adding padding zeros doesn't have any effect in Anzen.
> To seize numbers in binary, octal or hexadecimal,
> prefix your number with respectively `0b`, `0o` and `0x`.

Type inference makes sure that the `bulbasaur` constant is typed consistently
with the tuple type `struct { number: Int, name: String }`.
Nevertheless, such type information can be annotated as well:

```anzen
let bulbasaur: struct { number: Int, name: String }
bulbasaur = (number = 001, name = "Bulbasaur")
```

Assignment of a tuple value to a tuple variable must be valid with respect to typing,
as all other assignments.

```anzen
let pokemon: @mut = (number: 001, name: "Bulbasaur")
pokemon = (number = 002, name = "Ivysaur")
pokemon = (number = "003", name = "Venusaur")
// error: cannot assign value of type 'String' to type 'Int'
```

The values of a tuple are accessed by suffixing a tuple expression with `.label`,
where `label` is the tuple's value:

```anzen
print(bulbasaur.number)
// "Bulbasaur"
```

As with enumerations' associated values, it is possible to omit tuples value labels:

```
let pokemon: struct { _: Int, _: String }
let pokemon = (001, "Bulbasaur")
```

However, doing makes it impossible to retrieve values individually,
as we did with labels in previous examples.
This manual explains later how to obtain such information.

Tuple types (as well as other types) can become quite wordy.
Thanks to type inference, defining the tuple type is implicit in most situations.
But as we have seen, explicit typing may sometimes be desirable.
In order to avoid writing several times the same type (at different places in the code),
it is possible to create type aliases:

```anzen
type Species = struct { number: Int, name: String }
let bulbasaur: Species = (number = 001, name = "Bulbasaur")
let ivysaur: Species = (number = 002, name = "Ivysaur")
```

## Arrays

An array is a [collection](https://en.wikipedia.org/wiki/List_(abstract_data_type))
of values of homogeneous type (e.g. a collection of `String` values).
Arrays are declared with a comma-separated list of expressions, enclosed in square brackets `[]`:

```anzen
let species = [
  (number = 001, name = "Bulbasaur"),
  (number = 004, name = "Charmander"),
  (number = 007, name = "Squirtle"),
]
```

Type inference considers this array as an array of tuples `struct { number: Int, name: String }`,
as we have put values of such tuples within.

If the values of an array are not given upon initialization,
or if the array is initially empty,
it is necessary to explicitly type the array.
This behavior is similar to the declaration of any variable,
and more precisely similar to how optionals work.

```anzen
let species = []
# error: empty collection literal requires an explicit type

type Species = struct { number: Int, name: String }
let species: Array<Species>
species = [
  (number = 001, name = "Bulbasaur"),
  (number = 004, name = "Charmander"),
  (number = 007, name = "Squirtle"),
]
```

> Notice the use of angled brackets `<>` to specify the type of the array.
> This notation is used to denote the specialization of a generic type.
> We'll cover it at length later in this manual.

An empty array can be initialized with explicit type annotation using the following syntax:

```anzen
type Species = struct { number: Int, name: String }
let species = Array<Species>()
```

> Behind the scene, the above line calls an initializer of the Array<Species> type,
> which builds an empty array of Pokemon species.
> Then, the type inference is able to determine the type of the expression
> and thus the type of the variable.

Arrays are collections: they are indexed by `Int` values, starting at 0.
Their values can be accessed by subscripting the array
(i.e. using the square brackets `[]`) with the desired index.
Using a negative number or an index equal to or greater than the size of the array
will trigger a runtime error:

```anzen
let species = [
  (number = 001, name = "Bulbasaur"),
  (number = 004, name = "Charmander"),
  (number = 007, name = "Squirtle"),
]
print(species[1].name)
# Charmander
print(species[3].name)
# fatal error: index out of range
```

Slices are subparts of an array. They are themselves considered as arrays.
They can be accessed using a range rather than an `Int` value as the index of the subscript:

```anzen
print(species[1 .. 2][0])
# Charmander
```

The number of elements in an array is obtained by its `count` property:

```anzen
print(species.count)
# 3
```

> Trying to access or modify a value for an index that is outside of an array’s existing bounds
> will trigger a runtime error.
> Except when the array is empty,
> its valid indices are always comprised between 0
> and the its number of elements (its `count` property) - 1.

Notice that in all the examples above,
the `species` array was declared constant.
As a result, it is an immutable collection.
It is impossible to add or remove values to it, or change the value at a given index:

```anzen
let species = [
  (number = 001, name = "Bulbasaur"),
  (number = 004, name = "Charmander"),
  (number = 007, name = "Squirtle"),
]
species[0] = (number = 025, name = "Pikachu")
// error: cannot assign to value: 'species' is a constant
```

Mutable arrays have to be declared with the `@mut` type modifier:

```anzen
let species: @mut = [
  (number = 001, name = "Bulbasaur"),
  (number = 004, name = "Charmander"),
  (number = 007, name = "Squirtle"),
]
species[2] = (number = 025, name = "Pikachu")
species[1 .. 2] = [
  (number = 043, name = "Oddish"),
  (number = 016, name = "Pidgey")
]
```

Inserting a new value in an array is not possible with a subscript assignment.
Instead, the programmer must use the `Array.insert(element:at:)` function.
It inserts a new element at the position `at` and moves all remaining elements one index after:

```anzen
species[3] = (number = 025, name = "Pikachu")
// fatal error: index out of range
species.insert(element = (number = 025, name = "Pikachu"), at = 0)
```

Similarly, removing a value is performed with the `Array.remove(at:)` function.
It removes the element at index `at` and moves all remaining elements one index before:

```anzen
species.remove(at: 1)
```

## Sets

A [set](https://en.wikipedia.org/wiki/Set_(abstract_data_type))
is a collection of values of homogeneous type.
Arrays are declared with a comma-separated list of expressions suffixed by the symbol `:`,
enclosed in square brackets `[]`:

```anzen
let species_names = ["Bulbasaur":, "Charmander":, "Squirtle":]
```

If the values of a set are not given upon initialization,
or if the set is initially empty,
it is necessary to explicitly type the set.
This behavior is similar to the declaration of any variable,
and more precisely similar to how optionals work.

```anzen
let species_names: Set<String> = [-:]
```

> Notice the use of angled brackets `<>` to specify the type of the set.
> This notation is used to denote the specialization of a generic type.
> We'll cover it at length later in this manual.

An empty set can be initialized with explicit type annotation using the following syntax:

```anzen
let species_name = Set<String>()
```

> Behind the scene, the above line calls an initializer of the Set<String> type,
> which builds an empty array of species names.
> Then, the type inference is able to determine the type of the expression
> and thus the type of the variable.

As arrays, sets are immutable by default, and mutable if declared with the `@mut` type modifier.
They also define similar `Set.insert(_:)` and `Set.remove(_:)` functions,
and the `count` property.
A call to `remove(_:)` does not change anything if the value does not belong to the set.

```anzen
let species_names = ["Bulbasaur":, "Charmander":, "Squirtle":]
speciesNames.insert("Pidgey")
print(speciesNames.count)
# 4
speciesNames.remove("Pidgey")
print(speciesNames.count)
# 3
```

## Dictionaries

A [dictionary](https://en.wikipedia.org/wiki/Associative_array) is a mapping from keys to values.
Each key is associated with exactly one value or nothing.
Like a set, a key cannot appear more than once in a dictionary.
A same value can however be associated with multiple keys.
Dictionaries are written as a comma-separated list of key-value pairs `k: v`,
where `k` is a key and `v` its associated value:

```anzen
enum SpeciesType {
  case grass
  case fire
  case water
}
let species_types = ["Bulbasaur": SpeciesType.grass, "Charmander": SpeciesType.fire]
```

If the values of a dictionary are not given upon initialization,
or if the dictionary is initially empty,
it is necessary to explicitly type the dictionary.
This behavior is similar to the declaration of any variable,
and more precisely similar to how optionals work.

```anzen
let species_names: Dictionary<Key = String, Value = SpeciesType> = [-:]
```

> Notice the use of angled brackets `<>` to specify the type of the dictionary.
> This notation is used to denote the specialization of a generic type.
> We'll cover it at length later in this manual.

An empty dictionary can be initialized with explicit type annotation using the following syntax:

```anzen
let species = Dictionary<Key = String, Value = SpeciesType>()
```

> Behind the scene, the above line calls an initializer of the
> Dictionary<Key = String, Value = SpeciesType> type,
> which builds an empty array of species names.
> Then, the type inference is able to determine the type of the expression
> and thus the type of the variable.

Dictionaries are indexed by their keys.
This differs from arrays that are indexed by integers.
The values of a dictionary can be accessed by subscripting the dictionary,
using the square brackets `[]`, with the desired key.
+
```anzen
enum SpeciesType {
  case grass
  case fire
  case water
}
let species_types = ["Bulbasaur": SpeciesType.grass, "Charmander": SpeciesType.fire]
let bulbasaur_species = species_types["Bulbasaur"]!
```

Notice that the result is an optional.
The values returned by dictionary subscripts are optionals,
because the `.nothing` value is returned if the key does not exist.
This behavior differs from arrays, that raise an error in case of access outside the indices.
If the programmer knows that the key exists,
the `!` operator can be used to get a non-optional value.

As arrays, dictionaries are immutable by default,
and mutable if declared with the `@mut` type modifier.
Modification of the value associated to a key is similar to arrays:

```anzen
species_types["Bulbasaur"] = .water
```

Insertion and deletion differ from arrays,
as they are possible using subscripts:

```anzen
species_types["Oddish"] = .water
species_types["Charmander"] = nil
```

## Structures

Structures are [record types](https://en.wikipedia.org/wiki/Record_(computer_science)).
They allow to group together data.
They are similar to tuples, but have much more powerful features that will be seen later.

A structure is declared with the keyword `struct`,
and contains typed properties declared as variables or constants:

```anzen
type Species = struct { number: Int, name: String }
struct Pokemon {
  let species: Species
  let level: @mut Int
}
```

Structs can be initialized by providing them with a value for all their properties:

```anzen
let rainer = @mut Pokemon(species = (number = 134, name = "Vaporeon"), level = 58)
let sparky = Pokemon(species = (number = 135, name = "Jolteon"), level = 31)
```

> Anzen provides a default initializer for the `Pokemon` struct,
> as there is none explicitly defined.
> This initializer is called *memberwise initializer*,
> and requires to define values for all properties of the struct.
> We will see later how to declare custom initializers.

The `Pokemon` struct initializer is used to initialize the `rainer` variable,
which in turn initializes the properties of the struct (namely `species` and `level`).
Accessing the properties of a type instance is performed using the *dot syntax*:

```azen
print(rainer.level)
# 58
```

The property `rainer.level` can be mutated,
as the `rainer` is mutable **and** the `level` property is also a mutable.
On the contrary, it is impossible to assign `rainer.species`,
because the property declared constant,
or to assign `sparky.level`, because `sparky` is a constant.
If a struct is initialized as a constant, then none of its properties can be mutated,
no matter how they were declared:

```anzen
rainer.level = rainer.level + 1
print(rainer.level)
# 59
rainer.species = (number: 001, name: "Bulbasaur")
# error: cannot assign to property: 'species' is a constant
sparky.level = sparky.level + 1
# error: cannot assign to property: 'sparky' is a constant
```
