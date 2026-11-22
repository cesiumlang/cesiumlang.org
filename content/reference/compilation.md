---
title: "Compilation Model"
tags: ["compilation"]
sortorder: 15
---

This page summarizes how Cesium programs are compiled, from the point of view of someone writing Cesium. The compiler's internals are described in [Compiler and Toolchain](../compiler/index.md).

> [!info] Source
> Decision records [cesiumlang/cesium#4](https://github.com/cesiumlang/cesium/issues/4), [#5](https://github.com/cesiumlang/cesium/issues/5), [#6](https://github.com/cesiumlang/cesium/issues/6) and [#7](https://github.com/cesiumlang/cesium/issues/7). These are accepted plans; the compiler is not yet implemented.

## Source Files

- Cesium source files use the `.csm` extension.
- Module interface files use the `.csi` extension.

## The Compiler

- **One self-contained binary.** The compiler needs no separate toolchain: no C compiler, no SDK and no system libc on the user's machine. The linker is built in.
- **The compiler is written in Cesium** and reaches its first working version through a [bootstrap chain](../compiler/bootstrap.md) that starts from a small compiler written in portable C.
- **Two backends behind a middle IR.** Every program is lowered to Cesium's [middle IR](../compiler/mir.md), and from there to one of two backends:
  - **QBE** for development, bootstrapping and quick ports to new architectures;
  - **LLVM** as the release backend, for optimization, vectorization, full debug information and every supported target.

  QBE comes first; LLVM is added later and is what releases use.

## Properties of Compiled Programs

- **libc-free.** Natively built Cesium programs do not depend on a C library. The standard library talks to the operating system directly. Programs that link C libraries which need libc use a hosted link mode.
- **C ABI compatible.** Cesium functions can call and be called from C.
- **Static dispatch only.** There are no virtual calls; overloads are resolved at compile time.
- **Generics are monomorphized.**
- **No undefined behavior in arithmetic.** Integer arithmetic wraps, and shifts and division by zero have defined results, the same on every backend. See [Type System](type-system.md).

## Target Platforms

| Architecture | Platforms |
| --- | --- |
| x86_64 | Windows, Linux, macOS 11+, UEFI, freestanding |
| aarch64 | Windows, Linux, macOS 11+, UEFI, freestanding |
| 32-bit ARM | freestanding |
| PowerPC 750 | freestanding |
| SPIR-V | Vulkan shaders |
| WebAssembly | WASI and freestanding (tier 2) |

Bare-metal targets are a first-class goal: see [Freestanding Targets](../compiler/freestanding.md).

> [!question] Open
> The parts of the compilation model that a programmer sees most directly are not designed yet: how files map to namespaces, separate compilation, what an interface file contains, and symbol naming ([cesiumlang/cesium#47](https://github.com/cesiumlang/cesium/issues/47)); the accepted signatures of `main` (the reference shows `void = main()` and `i32 = main()`, and the S0 subset uses `i32 = main(i32 argc, ##u8 argv)`; tracked in [cesiumlang/cesiumlang.org#10](https://github.com/cesiumlang/cesiumlang.org/issues/10)); and what `comptime` means ([cesiumlang/cesium#55](https://github.com/cesiumlang/cesium/issues/55)). The compiler's command line has not been specified either.
