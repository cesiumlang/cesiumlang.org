---
title: "Variables and Constants"
tags: ["variables", "constants", "qualifiers", "ownership"]
sortorder: 4
---

## Variable Declaration

### Basic Declaration

```cesium
// Basic declaration with initialization
i32 count = 0;
f64 pi = 3.14159;
```

### Constant Variables

```cesium
// Constant variables
const i32 MAX_SIZE = 1000;
const str VERSION = "1.0.0";
```

### Pointer Declaration

Ownership and borrowing apply to pointers only. A pointer is given its address with one of three address-context operators, never with plain `=`:

```cesium
i32 count = 0;
i32 total = 0;

#i32 reader #= #count;              // immutable borrow of a plain value
~i32 writer ~= ~total;              // mutable borrow of a plain value
~Matrix m := create_matrix(3, 3);   // owner: takes ownership of what the function returns
defer free(m);

writer = 5;                         // plain = assigns through the pointer: total is now 5
```

`:=` is only meaningful with a pointer on the left; `Matrix m := create_matrix(3, 3);` is a compile error. See [Memory Management](memory-management.md) for the full rules.

### Uninitialized Variables

```cesium
u8 x;                 // declared, not initialized
~Buffer buf;          // a pointer that owns nothing yet (undefined)
```

> [!question] Open
> Whether a pointer that owns nothing may be declared bare, as on the last line, or must be written out with `undefined`, and how `undefined` is written for a plain value, are being discussed in [cesiumlang/cesium#25](https://github.com/cesiumlang/cesium/issues/25).

`undefined` is a keyword. For a plain value it means truly uninitialized. For a pointer it is a defined "owns nothing" state, distinct from `null`, and there is no test for it.

## Qualifiers

### Storage and Access Qualifiers

```cesium
// Storage and access qualifiers
static i32 global_counter = 0;    // function-scoped persistence
private void = helper();          // module-internal function
secret i32 internal_state;       // class-internal only
```

### Hardware Qualifiers

```cesium
// Hardware qualifiers
volatile u32 hardware_register;   // prevent optimization
atomic u64 shared_counter;        // thread-safe operations
register u64 hot_variable;        // register allocation hint
```

## Qualifier Descriptions

| Qualifier | Description |
| --- | --- |
| `const` | Value cannot be modified after initialization |
| `static` | Variable persists between function calls |
| `private` | Accessible only within the current module |
| `secret` | Accessible only within the current class/struct |
| `volatile` | Prevents compiler optimizations |
| `atomic` | Ensures thread-safe operations |
| `register` | Suggests register allocation |
| `simd` | Enables SIMD vectorization |

## Assignment Operators

| Operator | Left side | Meaning |
| --- | --- | --- |
| `=` | plain value | copies the value |
| `=` | pointer | assigns *through* the pointer (the pointer is dereferenced) |
| `#=` | `#T` pointer | immutable borrow: points the pointer at an address, read-only |
| `~=` | `~T` pointer | mutable borrow: points the pointer at an address, read-write |
| `:=` | `#T` or `~T` pointer | takes ownership of the memory at an address |

The sigil in the type and the operator must agree: `~T p #= q;` and `#T p ~= q;` are compile errors.

```cesium
~Matrix original := create_matrix(3, 3);
~Matrix moved := original;          // ownership transferred; original can no longer be used
~Matrix other := create_matrix(3, 3);

#Matrix borrowed #= moved;          // immutable borrow
~Matrix mut_borrowed ~= other;      // mutable borrow

// ... and once the borrows are no longer in use:
free(moved);
free(other);
```

> [!question] Open
> What `=` does to a plain value that owns memory (a `str`, a `list`, or a struct with owning fields) is not decided: [cesiumlang/cesium#22](https://github.com/cesiumlang/cesium/issues/22).
