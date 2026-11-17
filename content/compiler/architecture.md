---
title: "Architecture"
tags: ["compiler", "backend", "llvm", "qbe", "targets"]
sortorder: 1
---

> [!info] Source
> [ADR 0001](https://github.com/cesiumlang/cesium/issues/4) (backend, LLVM packaging, toolchain) and [ADR 0004](https://github.com/cesiumlang/cesium/issues/7) (two backends). Status: accepted as a plan; implementation not started.

## Overview

```text
Cesium source (.csm)
        |
     frontend            parsing, type checking, borrow checking
        |
   middle IR (MIR)       the contract between frontends and backends
     /         \
   QBE         LLVM
(development,  (release: optimization, all targets,
 bootstrap,     full debug info, freestanding features)
 quick ports)
```

- **The compiler is written in Cesium.** A small stage 0 compiler written in portable C exists only to start the [[compiler/bootstrap|bootstrap chain]].
- **The middle IR is the core design asset.** It carries shapes, aliasing facts derived from the ownership rules, fusion and explicit vector operations. Numerical optimization happens there; a backend receives already-structured code. See [[compiler/mir|Middle IR]].
- **Two backends consume the same MIR.** Cesium targets QBE first and later adds LLVM.

## The Two Backends

| Backend | Role | Strengths |
| --- | --- | --- |
| **QBE** (MIT, vendored and pinned) | Development, bootstrap and porting backend; correctness first | Builds in seconds with any C compiler; very fast compiles; correct C ABI including structs by value; a new architecture port is roughly 1.5 to 2 thousand lines |
| **LLVM** (through `libcsllvm`) | Primary release backend | Optimization and vectorization, every Cesium target, full debug info (DWARF, CodeView/PDB), freestanding features |

### Phasing

1. Stage 0 and `cesium1` use QBE. QBE's output (assembly) is assembled and linked by the pinned `zig cc` in CI. No LLVM build is needed to begin.
2. The real compiler starts with the QBE backend too.
3. The LLVM backend and `libcsllvm` are added when numerics performance, more targets, full debugging or freestanding features matter.
4. From then on, releases use LLVM. QBE remains for development iteration, the bootstrap chain and quick ports.

### Capability Differences

| Feature | QBE backend | LLVM backend |
| --- | --- | --- |
| Targets | QBE's list (amd64 SysV, Apple and Windows; arm64 Linux and Apple; rv64) | All Cesium targets |
| SIMD and vector operations | Scalarized by a MIR legalization pass | Native vector types |
| Optimization | QBE's modest optimizations | Full pipeline |
| Debug info | Line tables only | Full variables and types: DWARF; CodeView/PDB on Windows |
| Freestanding attributes (interrupt calling conventions, naked functions, sections, no red zone, stack probes) | Not available: building a kernel requires LLVM | Available |
| Output | Assembly text (needs an assembler and linker) | Object files, linked by in-process LLD |

Code that needs a capability a backend lacks is legalized (for example scalarized) or rejected with a clear error naming the backend. Performance benchmarks always run on LLVM.

### Target-Specific Lowering

Frontends never compute layout. MIR keeps `sizeof(T)`, `alignof(T)`, `index` and `field` symbolic, and each backend resolves them for the target: LLVM from its data layout, the QBE wrapper from its own implementation of the C layout rules. When a frontend needs a layout value at compile time it asks the active backend through a layout-query interface.

### Differential Testing

Both backends must give every program the same meaning, so core MIR has no undefined behavior (see [[compiler/mir|Middle IR]]), and consistency is proven by testing:

1. **Corpus tests:** the test corpora through QBE, LLVM `-O0` and LLVM `-O2`; outputs must match exactly.
2. **Layout tests:** generated structs, arrays and nested aggregates; each backend prints `sizeof`, `alignof` and every field offset, compared with the equivalent C declaration compiled by `zig cc`.
3. **ABI tests:** generated calls between Cesium (built with each backend) and C in both directions.
4. **Random programs:** a generator of well-defined MIR programs with a reducer, once MIR stabilizes.
5. **Floating point:** exact bit comparison wherever the floating-point policy is strict.

## The LLVM Boundary

- LLVM and LLD are statically linked into the compiler.
- Cesium emits LLVM IR itself (textual first, bitcode later) and drives LLVM through a handful of LLVM C API calls: parse IR, run a pass pipeline, create a target machine, emit an object.
- The only C++ in the compiler is a small shim for LLD and for writing Windows import libraries.
- `libcsllvm` is one archive per host containing LLVM, LLD, the shim, libc++ and a libc, exporting only the functions Cesium calls.

The C API is used rather than the C++ API because the C++ API breaks every major release and would keep part of the compiler in C++ forever. Cesium speaks the C ABI, so the C API keeps the whole compiler portable to Cesium.

## Toolchain

- **Devkits.** CI produces per-host devkit packages from [cesiumlang/devkits](https://github.com/cesiumlang/devkits). A devkit contains the pinned official Zig, the Cesium LLVM build (LLVM core, the targets listed below and LLD; no Clang and no LLVM tools) and a pinned QBE. Stage 0 builds use the Zig from the devkit. This is the "forked devkit pipeline" of ADR 0001, decision 4.
- **Zig is the C/C++ toolchain and build orchestrator, in CI only.** The LLVM package must be built with the same Zig version as everything linked with it.
- **No toolchain dependency for users.** Users get one self-contained compiler binary (LLVM and LLD inside) plus a few small bundled platform stub files: no Zig, no SDK, no system libc.
- **Contributors**, once `cesium1` exists, download a per-host bootstrap package produced by CI and build with Cesium's own build system. See [[compiler/bootstrap|Bootstrap Chain]].
- The compiler is one executable that is also to contain the language server and the documentation generator ([cesiumlang/cesium#2](https://github.com/cesiumlang/cesium/issues/2)).

## Runtime Model of Cesium Programs

**Cesium programs are libc-free.** Cesium's own standard library talks to the operating system directly. Third-party code linked through the C ABI may use libc; Cesium-native code does not.

| Platform | How a program reaches the OS |
| --- | --- |
| Linux | Direct system calls; fully static |
| Windows | No C runtime; `kernel32` / `ntdll` through import libraries the compiler generates at link time |
| macOS | Dynamically linked `libSystem` (always present); there is no stable system call ABI |
| Freestanding, UEFI | The standard library's own platform layer; see [[compiler/freestanding\|Freestanding Targets]] |

A Cesium program that links libc-dependent C libraries uses a *hosted link mode*: libc's startup and thread creation, while Cesium code still never calls libc directly. The compiler itself is such a program, because it contains LLVM.

Other properties of compiled code: C ABI compatibility, static dispatch only, and monomorphized generics.

## Target Platforms

| Platforms | LLVM target | LLD flavor |
| --- | --- | --- |
| x86_64: Windows, freestanding, UEFI, Linux (musl, gnu), macOS 11+ | `X86` | COFF, ELF, Mach-O |
| aarch64: freestanding, UEFI, Linux, Windows, macOS 11+ | `AArch64` | ELF, COFF, Mach-O |
| `arm-freestanding-eabi` (32-bit) | `ARM` | ELF |
| `powerpc-freestanding-eabi` (PowerPC 750; soft- and hard-float) | `PowerPC` | ELF |
| `spirv32-vulkan` (shaders) | `SPIRV` | none |
| `wasm32-wasi`, `wasm32-freestanding` (tier 2) | `WebAssembly` | Wasm |

## Alternatives That Were Rejected

Forking Zig and building on its IRs, emitting Zig source, QBE as the *only* backend (no SIMD, weaker floating-point code), a native backend as the primary one, emitting C as the main path, Cranelift, and building on Odin. The reasoning for each is in [ADR 0001](https://github.com/cesiumlang/cesium/issues/4).

## Open Items

Listed in the decision records: the SPIR-V path (LLVM's backend or a direct emitter from MIR), WebAssembly FMA and NaN policy, the form of `libcsllvm` (partial link or shared library), and the future of the existing C++ prototype in the compiler repository ([cesiumlang/cesium#2](https://github.com/cesiumlang/cesium/issues/2)).
