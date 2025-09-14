---
title: "Lexical Structure"
tags: ["lexical", "comments", "keywords", "identifiers", "strings"]
---

## Comments

Cesium supports three types of comments:

```cesium
// Single-line comment

/*
  Multi-line comment
*/

/**
 * Documentation comment for functions
 * @param x The input parameter
 * @return The computed result
 */
i32 = documented_function(i32 x) {
    // implementation
}
```

## Keywords

Cesium reserves the following keywords:

**Core Types:** `file`, `str`, `list`, `dict`, `slice`, `struct`, `path`, `uword`

**Language Constructs:** `alias`, `catch`, `as`, `return`, `comptime`, `generic`, `sizeof`, `typeof`, `asm`, `void`, `enum`, `error`, `null`, `union`

**Control Flow:** `if`, `while`, `for`, `else`, `do`, `with`, `defer`, `break`, `continue`, `switch`, `case`, `fallthrough`, `throw`

**Function Qualifiers:** `operator`, `context`, `property`, `private`, `secret`, `static`, `destruct`

**Variable Qualifiers:** `const`, `static`, `private`, `secret`, `volatile`, `atomic`, `register`, `simd`

**C Interop:** `extern`, `export`

**OOP Constructs:** `trait`, `impl`, `type`, `this`, `super`

**Namespacing:** `std`, `namespace`

## Built-in Functions and Constants

**Memory Management:** `alloc()`, `free()`, `realloc()`

**Debugging and I/O:** `printf()`, `debugf()`, `assert()`, `stdout`, `stdin`, `stderr`

**Mathematical:** `floor()`, `ceil()`, `trunc()`, `round()`, `trueround()`, `abs()`, `min()`, `max()`, `mean()`, `norm()`, `pi`

## Identifiers

Identifiers follow C-style rules: start with letter or underscore, followed by letters, digits, or underscores.

Valid identifiers:

- `variable_name`
- `_private_var`
- `Class2D`
- `MAX_SIZE`

## String Literals and Interpolation

Cesium supports multiple string literal formats:

```cesium
str simple = "Hello, world!";
str interpolated = `Hello, {name}! You have {count} messages.`;
path file_path = path(`{home_dir}/config/settings.conf`);
```

### String Types

- **Simple strings** use double quotes and support escape sequences
- **Interpolated strings** use backticks and allow expression embedding with `{}`
- **Path strings** are a special type for filesystem paths with automatic normalization
