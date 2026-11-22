---
title: "Performance Considerations"
tags: ["performance"]
sortorder: 16
---

Run-time performance for numerical code is one of Cesium's primary goals. This page states what has been decided about how the language and compiler deliver it. The language-level tuning features are not decided yet and are listed at the end.

> [!info] Source
> [ADR 0001](https://github.com/cesiumlang/cesium/issues/4), [ADR 0004](https://github.com/cesiumlang/cesium/issues/7) and the [middle IR design](https://github.com/cesiumlang/cesium/issues/8).

## What Is Decided

- **No run-time dispatch.** All dispatch is static, and generics are monomorphized, so every call target is known at compile time.
- **No garbage collector and no reference counting.** Ownership is checked at compile time, with no run-time bookkeeping beyond the pointer's own value; see [Memory Management](memory-management.md).
- **Numerical optimization happens in the compiler's middle IR,** which knows array shapes and, from the ownership rules, which pointers cannot alias. The backend receives already-structured code together with those facts.
- **LLVM is the release backend.** Release-build code quality (vectorization, FMA, aliasing, scheduling, register allocation) matters more to Cesium than compile speed. The QBE backend is for development and bootstrapping, and performance is always measured on LLVM.
- **Defined arithmetic.** Integer arithmetic wraps and has no undefined behavior. The optimizer may only assume more (for example, that an addition does not overflow) where the compiler has proven it.
- **`simd` types** work with the existing operators; see [Type System](type-system.md). On targets or backends without SIMD, vector operations are scalarized.

> [!question] Open
> The first draft of the reference listed `align()`, `pack()`, `inline`, `likely()` and `comptime unroll()` as tuning features. None of them was ever discussed or decided, so they are not documented here. They are tracked, together with numeric literal forms, in [cesiumlang/cesium#56](https://github.com/cesiumlang/cesium/issues/56). The floating-point policy (contraction, reassociation, reproducibility) is part of [cesiumlang/cesium#35](https://github.com/cesiumlang/cesium/issues/35), and the array, vector and matrix types that most numerical code depends on are [cesiumlang/cesium#36](https://github.com/cesiumlang/cesium/issues/36).
