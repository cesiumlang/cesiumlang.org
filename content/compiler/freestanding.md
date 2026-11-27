---
title: "Freestanding Targets"
tags: ["compiler", "freestanding", "targets"]
sortorder: 6
---

> [!info] Source
> [ADR 0003: freestanding targets](https://github.com/cesiumlang/cesium/issues/6). Status: accepted as a plan; implementation not started.

The Cesium compiler only needs to *run* on hosted platforms, but it must *produce* code for freestanding targets: Cesium must be usable to write an operating system that runs on bare metal. This is primarily a requirement on the language, the standard library and the runtime.

## Host and Target Are Independent

- The target triple is a first-class compiler input; nothing about the host leaks into the output.
- A freestanding target implies: no implicit startup code, no OS layer, no heap unless the program supplies one, no threads or thread-local storage unless the program supplies them.
- Using an OS-dependent API from freestanding code is a compile error, not a link error.

## Library Layering

The standard library is split in the style of Rust's `core` / `alloc` / `std`:

| Layer | Contents |
| --- | --- |
| **core** | No OS, no allocation: math, linear algebra kernels, formatting into caller-provided buffers, atomics |
| **alloc** | The allocator interface; the program provides the allocator |
| **os** | Platform layers (Linux, Windows, macOS, WASI, UEFI, ...) |

On freestanding targets the panic handler is user-provided and there is no unwinding.

## Compiler-Runtime Builtins

A backend emits calls to helper functions when the target lacks an instruction, so Cesium must ship these for every target: 64-bit division on 32-bit ARM and PowerPC, all floating point on soft-float PowerPC, atomics on older cores, and `memcpy`, `memset`, `memmove` and `memcmp`.

## Controls for Kernel Code

Most of these map onto LLVM IR attributes and target features, so the [semantic IR](sir.md) must carry them through:

| Need | Mechanism |
| --- | --- |
| Inline assembly, naked functions | inline asm, `naked` |
| Interrupt and exception handlers | special calling conventions |
| Kernel code that must not touch FPU or SIMD registers | per-function target features |
| No red zone in x86-64 kernel code | `noredzone` |
| Kernel code models; static, PIC or PIE relocation models | target machine options |
| Explicit sections and symbol placement | `section`, `align` |
| Memory-mapped I/O and device registers | `volatile` loads and stores; explicit layout and packing |
| Atomics with explicit memory ordering | atomic instructions |
| Stack probes off or controlled | `probe-stack` |

These attributes are available only with the LLVM backend. Building a kernel requires LLVM; the QBE lowering rejects them with a clear error.

> [!question] Open
> How these controls are *spelled in Cesium source* is not designed. ADR 0003 states what the compiler must be able to express, not the syntax. The layout and performance features drafted for the reference (`align()`, `pack()`, `inline`) were never decided: [cesiumlang/cesium#56](https://github.com/cesiumlang/cesium/issues/56).

## Output Formats

- ELF kernels with linker scripts.
- PE/COFF UEFI applications.
- Raw flat binaries for bootloaders and firmware.
- DWARF debug information for debugging under an emulator.

## Consequences

- The `core` layer and the compiler-runtime builtins must exist before any freestanding target works. They are also what hosted targets build on.
- The semantic IR needs per-function attributes (calling convention, target features, red zone, stack probes, sections) from the start.
- Stage 0 does not need freestanding support, but the compiler written in Cesium should not assume a hosted target anywhere in its code generation path.
