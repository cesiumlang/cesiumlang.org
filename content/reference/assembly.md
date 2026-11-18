---
title: "Inline Assembly"
tags: ["assembly"]
sortorder: 13
---

> [!info] Status
> This page records what the September 2025 design sessions settled about inline assembly, as listed in [cesiumlang/cesiumlang.org#11](https://github.com/cesiumlang/cesiumlang.org/issues/11). No syntax beyond what is stated here has been designed, so there are no examples yet.

## What Is Settled

- Inline assembly is written in `asm { ... }` blocks. `asm` is a keyword.
- A block contains raw, unqualified assembly in Intel syntax (the MSVC style). There are no GCC-style constraint strings.
- Variables are referenced by name inside the block.
- The hardware qualifiers `volatile`, `atomic`, `register` and `simd` were added in the same discussion; see [[variables-constants|Variables and Constants]]. Existing operators work on `simd` types.

Inline assembly is not part of the S0 subset that the first compiler stage accepts.

## What the Compiler Must Support

Freestanding targets (kernels, bootloaders, firmware) need inline assembly together with naked functions, interrupt calling conventions and control over sections. These are requirements on the compiler, recorded in [ADR 0003](https://github.com/cesiumlang/cesium/issues/6) and summarized in [[compiler/freestanding|Freestanding Targets]]. They are available only with the LLVM backend.

> [!question] Open
> Not designed: how a block names the registers it reads, writes and clobbers; how the same source serves more than one architecture; and how `asm` relates to the borrow checker, since assembly can read and write memory the checker knows nothing about ([cesiumlang/cesium#45](https://github.com/cesiumlang/cesium/issues/45)). Whether `register` stays in the language is part of the scope question in [cesiumlang/cesium#58](https://github.com/cesiumlang/cesium/issues/58).
