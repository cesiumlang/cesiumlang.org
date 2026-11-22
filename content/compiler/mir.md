---
title: "Middle IR (MIR)"
tags: ["compiler", "mir", "ir"]
sortorder: 3
---

> [!info] Source
> [Design: Cesium middle IR](https://github.com/cesiumlang/cesium/issues/8). Status: draft sketch. The text syntax shown here is illustrative and open to change.

Every Cesium frontend lowers to MIR, and MIR lowers to a backend: QBE or LLVM (see [Architecture](architecture.md)). Language features are defined by how they lower:

- **Core features** map directly onto core MIR constructs.
- **Composite features** are rewrites into the core: `for` becomes `while`, `switch` becomes `if` chains or jump tables, `defer` becomes cleanup blocks, error unions become tagged structs, methods become functions taking `this`.

## Two Levels

1. **Core level (now).** Close to "C with structured control flow": scalars, pointers, structs, arrays, calls, structured `if` / `while`, named mutable locals. It is **not SSA**: locals are stack slots that the backends promote. Stage 0 implements only this level.
2. **Numerics level (later).** Shapes and array descriptors, alias facts from the borrow checker, vector types and FMA, loop nests over index spaces, fusion regions, per-operation floating-point policy. These lower into the core level plus hints that only LLVM uses.

Structured control flow at the core level also suits SPIR-V and WebAssembly.

## Who Implements It

| Component | Language | Lifetime |
| --- | --- | --- |
| `libcsmir`: core MIR text parser, verifier, printer; the QBE lowering (first), the LLVM lowering (later); vendored QBE | Portable C, part of stage 0 | Used by stage 0 and linked into `cesium1`; frozen with the bootstrap chain |
| The real compiler's MIR (both levels) and both lowerings | Cesium | Replaces `libcsmir` in the real compiler |

## No Undefined Behavior

Both backends must give every core MIR program the same meaning, otherwise differential testing cannot be trusted:

- Integer `add`, `sub`, `mul` and `neg` wrap (two's complement).
- Shift amounts are reduced modulo the operand width, or follow another single defined rule applied by both lowerings.
- Division and remainder by zero, and the signed minimum divided by -1, have one defined behavior in both lowerings.
- Out-of-range float to integer conversions have one defined result.
- The LLVM lowering must not add flags that produce poison or undefined behavior (`nsw`, `nuw`, `exact`, unproven `inbounds`, fast-math) unless MIR semantics or a verified fact allows it.

## Core Level Sketch

### Lexical Conventions

- `@name` for globals and functions, `%name` for parameters and locals. Bare names are types and operations.
- Constants carry their type: `0:u8`, `1:uword`, `-5:i64`.
- `;` starts a comment. A file starts with a version header: `cesium-mir 0`.

### Types

- Integers: `u8 u16 u32 u64 i8 i16 i32 i64`, and `uword` (pointer-sized, resolved by target). Signedness lives in the type, so operations need no signed and unsigned variants.
- Floats: `f32 f64`.
- Pointers: `ptr<T>`. Arrays: `[N x T]`. Structs: `struct Name { field: T, ... }`. `void`.

Layout is owned by the backend. MIR keeps `sizeof(T)`, `alignof(T)`, `index` and `field` symbolic.

### Declarations

```text
cesium-mir 0

struct Token { kind: i64, start: ptr<u8>, len: uword }

extern func @write(i32, ptr<u8>, uword) -> i64 callconv(c)

const @str.0: [6 x u8] = "hello\00"
global @counter: i64 = 0:i64

export func @main(%argc: i32, %argv: ptr<ptr<u8>>) -> i32 { ... }
func @cstr_len(%s: ptr<u8>) -> uword { ... }
```

- `func` is module-internal; `export func` is externally visible with the C ABI; `extern func` declares an external C ABI function.
- Function attributes are reserved for [freestanding targets](freestanding.md) (`callconv(...)`, `section(...)`, `align(...)`, `target_features(...)`, `noredzone`, `naked`, `probe_stack(...)`). Version 0 implements `callconv(c)` only.
- A global name used as an expression yields its address.

### Statements

| Statement | Meaning |
| --- | --- |
| `local %x: T [= expr]` | Mutable local (stack slot) |
| `set %x = expr` | Assign a local |
| `store ptr_expr, value_expr` | Store through a pointer |
| `eval expr` | Evaluate for side effects |
| `if cond { ... } [else { ... }]` | Structured conditional; `cond` is an integer, nonzero is true |
| `while cond { ... }` | Structured loop |
| `break` / `continue` | Innermost loop |
| `return [expr]` | Return |

Any statement may carry a source location, used for debug information.

### Expressions

Expressions are trees, not three-address code; the lowerings flatten them.

| Expression | Meaning |
| --- | --- |
| `%x` | Value of a local or parameter |
| `addr(%x)` | Address of a local |
| `load(p)` | Load through `p: ptr<T>` |
| `index(p, i)` | `ptr<T>` to element `i` |
| `field(p, name)` | Pointer to field `name` of the struct `p` points to |
| `call @f(args...)` | Call |
| `add sub mul div rem` | Arithmetic; signedness from the operand type |
| `and or xor shl shr not neg` | Bitwise |
| `eq ne lt le gt ge` | Comparisons; the result type is `u8` |
| `land(a, b)`, `lor(a, b)`, `lnot(a)` | Short-circuit logical operations; result `u8` |
| `as(T, v)` | Conversion with fixed rules |
| `sizeof(T)`, `alignof(T)` | Resolved by the backend; result `uword` |

The verifier checks types, that `break` and `continue` are inside loops, and that non-`void` functions return on every path.

### Example

The S0 function

```cesium
uword = cstr_len(#u8 s) {
  uword n = 0;
  while (s[n] != 0) {
    n = n + 1;
  }
  return n;
}
```

lowers to

```text
func @cstr_len(%s: ptr<u8>) -> uword {
  local %n: uword = 0:uword
  while ne(load(index(%s, %n)), 0:u8) {
    set %n = add(%n, 1:uword)
  }
  return %n
}
```

### Version 0 Restrictions

- Parameters, return values and `extern` / `export` signatures use only scalars and pointers. Struct-by-value arguments and returns come later.
- No floating-point operations beyond `as` conversions until a frontend needs them.

## Lowering

**To QBE IL (first backend):** locals become stack slots; structured control flow becomes labels and jumps; 8- and 16-bit integers use sized loads and stores with explicit extension and truncation; `index` and `field` become explicit address arithmetic; source locations become line directives. The output is assembly text.

**To LLVM IR (release backend):** locals become `alloca`s that `mem2reg` promotes; `index` and `field` become `getelementptr`; signedness chooses the signed or unsigned instruction; source locations and type information become full debug metadata.

## Open Questions

From the design record:

1. Text syntax details (sigils, statement and expression boundaries, constant syntax, location annotations).
2. Whether the real compiler needs an SSA form internally for its own analyses.
3. The exact defined semantics for division by zero and over-wide shifts (trap or defined value), and their cost in the LLVM lowering.
4. The shape of the layout-query interface between frontends and backends.
