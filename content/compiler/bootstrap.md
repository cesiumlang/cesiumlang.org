---
title: "Bootstrap Chain"
tags: ["compiler", "bootstrap", "stage0"]
sortorder: 2
---

> [!info] Source
> [ADR 0002](https://github.com/cesiumlang/cesium/issues/5) (bootstrap strategy), [ADR 0004](https://github.com/cesiumlang/cesium/issues/7) (QBE first) and the [stage 0 design](https://github.com/cesiumlang/cesium/issues/9). Status: accepted as a plan.

The Cesium compiler is written in Cesium. Something else has to compile it the first time, and that is done by a layered chain that starts from a small compiler written in C.

## The Ladder

| Layer | Written in | Compiles | Notes |
| --- | --- | --- | --- |
| Stage 0 | Portable C | S0 | A tiny S0 frontend plus `libcsmir` (QBE first); runs only in CI |
| Stage 1 (`cesium1`) | S0 | S1 | Frontend only: parses S1, emits core MIR text, hands it to `libcsmir`. Verbose by design; frozen once the next layer works |
| Real compiler | S1 | Full Cesium | Reimplements MIR (both levels) and both lowerings in Cesium; borrow checking, generics, math operators, freestanding support; starts on QBE and adds LLVM |

- **S0** is a deliberately tiny subset of Cesium; see [The S0 Subset](s0-subset.md).
- **S1** is a comfortable language for writing the real compiler. Its feature list is a set of candidates to be confirmed when stage 1 is designed.
- Convenience features (`for`, `switch`, tagged unions, strings, modules, floats) are implemented in stage 1, written in S0, not in stage 0. They are defined as rewrites into core MIR.
- More layers are added only if a later compiler genuinely needs features its predecessor cannot compile.

### Rules for the Chain

1. **Each subset is a strict subset of Cesium.** Every S0 program is a valid Cesium program with the same meaning.
2. **Every later compiler must still compile the frozen layers**, so the from-source check in CI can run down the whole chain.
3. The chain ends with the full compiler rebuilding itself, checked for identical output.
4. Frozen layers keep their own `libcsmir`, so the real compiler's MIR can evolve freely.

## Stage 0

Stage 0 is written in portable C: the intersection of C99 and C11 that every mainstream compiler implements, with no extensions, only the ISO C standard library and a list of banned functions. See [Stage 0 C Dialect](stage0-c-dialect.md).

It consists of:

- the S0 frontend (lexer, recursive-descent and Pratt parser, minimal type checking, the S0 to MIR mapping);
- `libcsmir`: core MIR data structures, text parser, printer, verifier, the QBE lowering, later the LLVM lowering, and a small arena runtime;
- vendored QBE, with its entry point renamed so it can be called in-process. Stage 0 does not spawn processes; assembling and linking are done by the build system.

**Pipeline (phase 1, QBE only):**

```text
S0 source files -> lexer -> parser -> type checking -> core MIR
  -> libcsmir: verify -> lower to QBE IL -> QBE -> assembly file
  -> build.zig assembles and links with zig cc -> cesium1
```

Stage 0's output does not need to be efficient, and stage 0 has no optimization design.

### Why C and Not Zig

- **Stability.** Zig is pre-1.0 and its releases bring breaking changes. The root of the chain should not need rework on every Zig upgrade. ISO C is frozen.
- **Native fit with LLVM.** LLVM's C API is C.
- **Portability of the root.** Stage 0 can be built by Clang, GCC or MSVC, so Cesium can move away from `zig cc` later without touching it.
- **Zig's churn stays in `build.zig`,** which only orchestrates.

The C dialect's limits apply only to stage 0 and `libcsmir`. They do not affect Cesium's design or the real compiler.

## `cesium1`

Stage 1 is only a frontend. It emits core MIR text and calls a coarse C ABI exported by `libcsmir` (pointers, `uword` and `i32` only; no by-value structs, callbacks or variadics):

```cesium
extern csmir = import('csmir') {
  i32 = cs_backend_init();
  i32 = cs_compile_mir(#u8 mir, uword len,
                       i32 backend,              // 0 = QBE (writes assembly), 1 = LLVM (writes an object)
                       #u8 triple, #u8 cpu, #u8 features,
                       i32 opt_level, #u8 out_path);
  i32 = cs_lld_link(i32 argc, ##u8 argv, #i32 can_run_again);  // once libcsllvm is linked
  #u8 = cs_last_error();                         // owned by the library; never freed
}
```

It becomes self-contained in two phases: first it writes assembly that `build.zig` assembles and links; once `libcsllvm` exists it assembles QBE output through LLVM's integrated assembler and links with in-process LLD, or uses the LLVM backend directly.

## What CI Builds

`build.zig` runs only in CI pipelines. It orchestrates the LLVM build, stage 0, `libcsmir`, `libcsllvm` and the chain.

1. **Devkits** ([cesiumlang/devkits](https://github.com/cesiumlang/devkits)): per-host packages containing the pinned official Zig, the Cesium LLVM build (core, the Cesium targets and LLD; no Clang) and a pinned QBE. Stage 0 builds use the Zig from the devkit.
2. Build the LLD shim and `libcsllvm` per host.
3. Build stage 0 and `libcsmir`, run the portability and banned-function checks, and run the layer chain up to the full compiler; verify that the compiler rebuilds itself identically.
4. Cross-compile the compiler for every host triple and smoke-test it.
5. Publish one **bootstrap package** per host, with a manifest (Zig version, LLVM version, target list, chain commits, checksums).

## What Contributors Need

| Phase | Requirement |
| --- | --- |
| Before `cesium1` is published | The pinned Zig (as C compiler and build system), from the devkit |
| After `cesium1` is published | Only the bootstrap package for the host, and Cesium's own build system: no Zig, no C or C++ toolchain, no CMake |

## Bootstrap Models That Were Considered

| Model | Cost |
| --- | --- |
| Previous-release binary (Rust, Go) | Trust in binaries; new hosts need cross-compiling |
| Wasm seed plus `wasm2c` (Zig) | A permanent C backend and a checked-in blob |
| Layered chain from a maintained root | The chain grows; from-scratch builds are slower |

Chosen: the layered chain, run only in CI, combined with previous-release-style distribution to contributors. The chain gives auditability and reproducibility; the packages keep setup trivial.

## Porting to a New Host

1. Add the LLVM target if the architecture is new.
2. Write Cesium's platform layer for the new operating system.
3. In CI, cross-compile LLVM, `libcsllvm` and the compiler for the new host and publish its package.

Bare metal can be a *target* but not a compiler *host*: LLVM needs files, memory mapping and threads.
