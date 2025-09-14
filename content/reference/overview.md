---
title: "Overview"
tags: ["overview", "design", "goals"]
---

Cesium is a compiled, statically-typed systems programming language designed for mathematical computing and linear algebra applications. It prioritizes performance, explicit memory management, and mathematical expressiveness while maintaining C ABI compatibility.

The language borrows design and syntactic elements from languages as varied as Python, Fortran, Rust, Go, Odin, and C++, but ultimately derives the bulk of its original design inspiration and goals from C, Zig, and MATLAB. As such, an early placeholder name for the language was CZM for those three languages.

Ultimately, the name is a reference to the atomic element cesium (American Chemical Society spelling). Since one of the primary objectives of the language is runtime performance, it seemed fitting to share a name with the primary element used for standard atomic clocks. In fact, a second in timekeeping is officially defined in SI by assuming the unperturbed ground-state hyperfine transition frequency of the cesium-133 atom to be exactly 9,192,631,770 Hz. It takes 34 bits to represent that number as an integer in binary.

## Design Goals

- Math-first language with built-in mathematical operators and types
- Compile-time dispatch and optimization
- Memory safety through ownership tracking and explicit management
- Strong typing with minimal implicit conversions
- ASCII-only syntax for universal accessibility
- C interoperability for existing library integration

## Basic Program Structure

```cesium
// hello.cs
void = main() {
    printf("Hello, Cesium!\n");
}
```

This simple example demonstrates the basic structure of a Cesium program:

- Function definitions use the syntax `return_type = function_name(parameters)`
- `void` indicates no return value
- Built-in functions like `printf` are available without imports
- String literals use standard C-style double quotes
