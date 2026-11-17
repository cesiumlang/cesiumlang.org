---
title: "The S0 Subset"
tags: ["compiler", "stage0", "s0", "bootstrap"]
sortorder: 4
---

> [!info] Source
> [Design: stage 0 and the S0 subset](https://github.com/cesiumlang/cesium/issues/9), including its amendment comment of 2026-11-16, which applies the [file-extension decision](https://github.com/cesiumlang/cesium/issues/14) and the [ownership design](https://github.com/cesiumlang/cesium/issues/11). Status: draft. The formal grammar is in the specification: [[spec/s0-grammar|S0 Grammar]].

S0 is the deliberately tiny subset of Cesium that stage 0 compiles. Stage 0 has one job, which is to compile stage 1 (`cesium1`), and stage 1 is written in S0. See [[compiler/bootstrap|Bootstrap Chain]].

S0 is designed together with core [[compiler/mir|MIR]] so that it is essentially a readable notation for it: almost every S0 construct maps one-to-one onto a core MIR construct.

## Rules

1. **S0 is a strict subset of Cesium.** Every S0 program is a valid Cesium program with the same meaning. Later compilers must still be able to compile the frozen stage 1.
2. **Features are added to S0 only when stage 1's code genuinely needs them** and implementing them in stage 0 is cheaper than writing around them.
3. **S0 maps (nearly) one-to-one onto core MIR.** A feature that needs a nontrivial rewrite belongs in S1.
4. **Stage 0's output may be naive.**

## Contents

| Area | S0 |
| --- | --- |
| Types | `u8`, `i32`, `u32`, `i64`, `u64`, `uword`; pointers `#T` (`~T` is parsed and treated the same: no borrow checking); pointer-to-pointer (`##T`); fixed arrays `T name[N]` |
| Data | `struct` with fields only: no methods, no struct literals (assign fields one at a time) |
| Control flow | `if` / `else`, `while`, `break`, `continue`, `return` |
| Functions | `T = name(params) { ... }`, single return value, `void`, recursion |
| Expressions | `+ - * / %`, comparisons, `&& \|\| !`, bitwise `& \|` and `><` (XOR), shifts `<< >>`, indexing `p[i]`, address-of `#x`, field access `a.b` (auto-dereferences pointers), casts `as`, `sizeof` |
| Literals | integers, characters (`'A'`), strings as NUL-terminated `#u8` |
| Memory | `alloc(count)` only: a bump arena that never frees. The element type comes from the declared target |
| Globals | global variables and `const` globals (constants also stand in for enums) |
| Outside world | `extern name = import('lib') { ... }` blocks declaring C ABI functions: a few libc functions (`open`, `read`, `write`, `close`, `exit`) and the coarse `libcsmir` API |
| Compilation unit | multiple files compiled as one unit with shared globals; no `import` of Cesium modules |
| Entry point | hosted `main`: `i32 = main(i32 argc, ##u8 argv)` |
| Source files | `.csm` |

`i32` and `u32` are required for C ABI correctness: passing an `i64` where C expects an `int` happens to work on x86-64 but breaks on 32-bit targets.

S0's arithmetic follows core MIR's defined semantics (wrapping integers, defined shifts and division by zero), so stage 0's output means the same thing on both backends.

## Pointers in S0

Because S0 must be a strict subset of Cesium, S0 source follows the ownership *syntax* even though stage 0 does not enforce ownership:

- **A pointer is never initialized or re-pointed with plain `=`.** Plain `=` on a pointer assigns through it. A pointer gets its address with `:=` (ownership, as for the result of `alloc`) or with `#=` (borrow):

  ```cesium
  #Token t := alloc(1);     // not: #Token t = alloc(1);
  t.start #= "hello";       // setting a pointer field: address-context assignment
  ```

- **Dereference-by-default is confirmed.** There is no dereference operator. `p[i]` reads or writes an element, and `p.field` reaches through a pointer to a struct.
- **`#T` in a declaration is a pointer** (to data that cannot be modified through it) everywhere.
- Stage 0 parses `~T` and treats it the same as `#T`.

> [!question] Open
> The design record does not yet say how the rest of the ownership rules apply to S0 source. S0 has no `free`, while in full Cesium an owner that is never released is a compile error; and the record's sample program writes through `#T` pointers (`t.kind = ...`, `buf[i] = ...`), which the ownership design allows only through `~T`. Rule 1 above (strict subset) means these have to be reconciled before stage 1 is frozen. Track in [cesiumlang/cesium#9](https://github.com/cesiumlang/cesium/issues/9).

## S0 to Core MIR

| S0 | Core MIR |
| --- | --- |
| `T name = e;` (local) | `local %name: T = e` |
| `x = e;` (local) | `set %x = e` |
| `p[i] = e;`, `p.f = e;` | `store index(p, i), e`, `store field(p, f), e` |
| `p[i]`, `p.f` (read) | `load(index(p, i))`, `load(field(p, f))` |
| `#x` | `addr(%x)` |
| `if` / `else`, `while`, `break`, `continue`, `return` | the same structured statements |
| `a + b`, `a < b`, `a >< b`, ... | `add(a, b)`, `lt(a, b)`, `xor(a, b)`, ... |
| `a && b`, `a \|\| b`, `!a` | `land(a, b)`, `lor(a, b)`, `lnot(a)` |
| `e as T` | `as(T, e)` |
| `sizeof(T)` | `sizeof(T)` (resolved by the backend) |
| `f(args)` | `call @f(args)` |
| `"text"` | `const @str.N: [len+1 x u8] = "text\00"` and its address |
| `alloc(n)` (target `#T`) | `as(ptr<T>, call @cs_arena_alloc(mul(n, sizeof(T)), alignof(T)))` |
| `struct S { ... }` | `struct S { ... }` |
| `extern ... import(...) { ... }` | `extern func @name(...) -> T callconv(c)` |

Every statement also carries its source location, so the backends can emit debug line information.

## Not in S0

`for`, ranges, `switch` / `case`, `enum`, unions and `typeof`, `slice` / `list` / `dict` / `str`, multiple return values, `defer`, `error` types and `catch` / `throw`, modules and `import` of Cesium code, floating point, `free` / `realloc`, methods and `this`, generics, traits, inheritance, operator overloading, the math operators (`^`, `::`, `@`, context-aware `*`, postfix `~`), SIMD, `comptime`, string interpolation, `with`, inline `asm`, `volatile` / `atomic`.

Stage 1's source simulates what it needs by hand: tag fields plus casts for AST nodes, hand-written hash tables over pointers, error codes as return values, NUL-terminated strings with explicit lengths where needed.

## Sample Program

This is the sample from the design record with its amendment applied: pointers are initialized with `:=` and the pointer field is set with `#=`. It is illustrative; the exact syntax still depends on the open questions below.

```cesium
extern libc = import('c') {
  i64 = write(i32 fd, #u8 buf, uword len);
}

const i64 TOK_IDENT = 1;
const i64 TOK_NUMBER = 2;

struct Token {
  i64 kind;
  #u8 start;
  uword len;
}

uword = cstr_len(#u8 s) {
  uword n = 0;
  while (s[n] != 0) {
    n = n + 1;
  }
  return n;
}

void = print(#u8 s) {
  write(1, s, cstr_len(s));
}

// Write an unsigned integer as decimal text into buf; returns the length.
uword = fmt_u64(u64 v, #u8 buf) {
  u8 tmp[20];
  uword n = 0;
  if (v == 0) {
    buf[0] = '0';
    return 1;
  }
  while (v != 0) {
    tmp[n] = ('0' + (v % 10)) as u8;
    v = v / 10;
    n = n + 1;
  }
  uword i = 0;
  while (i < n) {
    buf[i] = tmp[n - 1 - i];
    i = i + 1;
  }
  return n;
}

i32 = main(i32 argc, ##u8 argv) {
  #Token t := alloc(1);
  t.kind = TOK_IDENT;
  t.start #= "hello";
  t.len = cstr_len(t.start);

  #u8 buf := alloc(32);
  uword n = fmt_u64(t.len as u64, buf);
  buf[n] = '\n';
  buf[n + 1] = 0;
  print("token length: ");
  print(buf);
  return 0;
}
```

> [!warning] Provisional — not decided (cesiumlang/cesium#9)
> If S0 source is to pass the full compiler's borrow checker later, the pointers this sample writes through would be declared `~T` instead of `#T` (`~Token t := alloc(1);`, `~u8 buf := alloc(32);`, and the `buf` parameter of `fmt_u64` as `~u8`). Stage 0 treats the two sigils the same, so this costs nothing now and avoids rewriting frozen stage 1 source. This is a recommendation, not part of the design record.

## Stage 1 Goals (S1)

Stage 1 is written in S0 and compiles S1. Each S1 feature is defined as a rewrite into core MIR. These are **candidates, to be confirmed** when stage 1 is designed:

- `for` with ranges and collection iteration; `switch` / `case` with values, ranges and `else`
- `enum` (including backed enums); type unions with `switch (typeof(x))`
- `str` and `slice[T]`; built-in `list[T]` and `dict[K,V]`
- multiple return values; `defer`
- `error` types, `T|Error` returns, `catch (err) { case (...) }` (return-based only)
- `namespace` and `import` of Cesium modules; `private`
- `f32` / `f64`, including exact decimal-to-IEEE conversion for literals
- a real allocator (`free`, `realloc`)
- possibly methods with `this`

## Testing

- A corpus of S0 programs with expected outputs.
- Golden MIR tests: S0 source to expected MIR text, and MIR text to expected behavior.
- Differential testing through QBE, LLVM `-O0` and LLVM `-O2` once the LLVM lowering exists.
- `cesium1` built by stage 0 must compile the S1 test corpus and the real compiler.
- Every later compiler must still compile the frozen stage 1.

## Open Questions

From the design record, after its amendment:

1. ~~File extension.~~ Decided: `.csm` ([cesiumlang/cesium#14](https://github.com/cesiumlang/cesium/issues/14)).
2. Declaration and pointer syntax. Dereference-by-default and the meaning of `#T` are confirmed. Still open: the result type of comparisons (`u8` in core MIR, since Cesium has no `bool`) and the default type of an integer literal when context does not determine it.
3. Core MIR text syntax ([cesiumlang/cesium#8](https://github.com/cesiumlang/cesium/issues/8)).
4. Which QBE version to vendor, and confirming its line-debug support and Windows output.
