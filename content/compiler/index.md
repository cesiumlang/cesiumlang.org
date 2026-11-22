---
title: "Compiler and Toolchain"
tags: "compiler"
---

This section describes how the Cesium compiler is put together: its backends, how it bootstraps, the middle IR every frontend lowers to, and the small language subset the first compiler stage accepts.

> [!info] Status
> These pages summarize decision records kept as issues in [cesiumlang/cesium](https://github.com/cesiumlang/cesium/issues?q=is%3Aissue+label%3Adecision). Stage 0 (`cesium0`) and `cesium1`, a compiler for S0 written in S0, are implemented and tested in CI on Linux, macOS and Windows with the QBE backend; the rest is a plan. Where a page and its decision record disagree, the decision record wins.

## Pages

- [Architecture](architecture.md) - Two backends behind a middle IR, the toolchain, the runtime model and the target platforms
- [Bootstrap Chain](bootstrap.md) - Stage 0 in portable C, `cesium1` in S0, then the real compiler; what CI builds and what contributors download
- [Middle IR (MIR)](mir.md) - The core level of the IR that every frontend lowers to
- [The S0 Subset](s0-subset.md) - The tiny subset of Cesium that stage 0 compiles
- [Stage 0 C Dialect](stage0-c-dialect.md) - The portable C subset stage 0 is written in
- [Freestanding Targets](freestanding.md) - What bare-metal targets require of the language, library and compiler

## Decision Records

| Record | Subject |
| --- | --- |
| [cesiumlang/cesium#4](https://github.com/cesiumlang/cesium/issues/4) | ADR 0001: compiler backend, LLVM packaging and toolchain |
| [cesiumlang/cesium#5](https://github.com/cesiumlang/cesium/issues/5) | ADR 0002: bootstrap strategy and hosting the compiler |
| [cesiumlang/cesium#6](https://github.com/cesiumlang/cesium/issues/6) | ADR 0003: freestanding targets |
| [cesiumlang/cesium#7](https://github.com/cesiumlang/cesium/issues/7) | ADR 0004: two backends, QBE first and LLVM as the primary release backend |
| [cesiumlang/cesium#8](https://github.com/cesiumlang/cesium/issues/8) | Design: Cesium middle IR (MIR) |
| [cesiumlang/cesium#9](https://github.com/cesiumlang/cesium/issues/9) | Design: stage 0 and the S0 subset |
| [cesiumlang/cesium#10](https://github.com/cesiumlang/cesium/issues/10) | Design: stage 0 C dialect |
| [cesiumlang/cesium#11](https://github.com/cesiumlang/cesium/issues/11) | Design: ownership, borrowing and lifetimes |

Requirements carried over from the removed C++ prototype (documentation generator, command-line interface, logging) are in [cesiumlang/cesium#64](https://github.com/cesiumlang/cesium/issues/64).

See also the [language specification draft](../spec/index.md) and the [language reference](../reference/index.md).
