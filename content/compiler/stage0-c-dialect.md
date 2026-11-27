---
title: "Stage 0 C Dialect"
tags: ["compiler", "stage0", "c"]
sortorder: 5
---

> [!info] Source
> [Design: stage 0 C dialect, the portable C subset](https://github.com/cesiumlang/cesium/issues/10). Status: draft. Applies to stage 0 and `libcsir` only. It does not constrain Cesium's language design or the real compiler, which is written in Cesium.

Stage 0 and `libcsir` must compile unchanged with any mainstream C compiler, and should stay small, auditable and hard to misuse. "C11" alone is not enough: C11 made several features optional, and some compilers never implemented parts of earlier standards. The rule is therefore the **intersection that every mainstream compiler implements**, plus a list of banned functions modeled on git's `banned.h` and the Linux kernel's list of deprecated interfaces.

Reference compilers: Clang (including `zig cc`), GCC, MSVC, and a small independent compiler such as TinyCC or cproc as a canary.

## The Rule

Write ISO C that is valid as **both C99 and C11**, using only features every reference compiler implements, with **no compiler extensions**, **only the ISO C standard library**, and **none of the banned functions**.

### Allowed

- Core C89/C99 language: `//` comments, declarations mixed with code, `for (int i = 0; ...)`, designated initializers, compound literals, `static inline` functions, flexible array members.
- Headers: `<stddef.h>`, `<stdint.h>`, `<inttypes.h>`, `<stdbool.h>`, `<limits.h>`, `<stdarg.h>`, `<assert.h>`, `<string.h>`, `<stdio.h>`, `<stdlib.h>`, `<errno.h>`.
- Fixed-width integer types, `size_t`, `ptrdiff_t`, `intptr_t` / `uintptr_t`, `PRIu64`-style format macros.
- Bounded string and formatting functions: `memcpy`, `memmove`, `memset`, `memcmp`, `strlen`, `strcmp`, `strncmp`, `memchr`, `strchr`, `snprintf`, `vsnprintf`, and `fprintf` / `printf` with constant format strings.
- Number parsing only with the `strtol` family, checking `errno`, the end pointer and the range.
- Include guards for headers.

### Not Allowed

- **Optional or weakly supported standard features:** variable-length arrays, `_Complex`, `<threads.h>`, `<stdatomic.h>` / `_Atomic`, `_Thread_local`, `_Generic`, `_Alignas` / `_Alignof`, `_Noreturn`, Annex K, Annex L.
- **Static assertions** except through one project macro (`CS_STATIC_ASSERT`) defined in a single header.
- **Compiler extensions:** `__attribute__`, `__declspec`, `__builtin_*`, statement expressions, `typeof`, computed `goto`, case ranges, zero-length and one-element trailing arrays, nested functions, `__int128`, inline assembly, `alloca`, `#pragma` (including `#pragma once`).
- **Non-ISO libraries:** no POSIX or Win32 calls. File I/O uses `fopen` / `fread` / `fwrite`; the arena allocates large blocks with `malloc`.
- **Floating point:** not needed in stage 0.
- **Implicit `switch` fall-through:** every non-empty `case` ends in `break`, `return`, `continue` or `goto`.

### Banned Functions

| Banned | Why | Use instead |
| --- | --- | --- |
| `strcpy`, `strcat`, `strncpy`, `strncat`, `strlcpy`, `strlcat` | Unbounded copies, or results that may not be NUL-terminated | Explicit lengths with `memcpy`; project string helpers |
| `sprintf`, `vsprintf` | No bounds | `snprintf`, `vsnprintf` (check the return value) |
| `gets` | No bounds | `fgets` / `fread` |
| `scanf`, `fscanf`, `sscanf` and their `v` variants | Unbounded `%s`, weak error reporting | Hand-written lexing, the `strtol` family |
| `atoi`, `atol`, `atoll`, `atof` | No error detection | The `strtol` family with checks |
| `strtok`, `strtok_r` | Hidden state, modifies input | Explicit scanning |
| `gmtime`, `localtime`, `ctime`, `asctime` (and `_r`), `time`, `clock` | Shared static buffers; time makes output nondeterministic | Not needed in stage 0 |
| `tmpnam`, `mktemp`, `tmpfile` | Race-prone temporary files | The build system provides paths |
| `system`, `getenv`, `signal`, `raise` | Shell injection, nondeterminism, async hazards | Command-line arguments |
| `setjmp`, `longjmp` | Non-local control flow complicates review and cleanup | Error codes |
| `rand`, `srand` | Nondeterminism | Not needed |
| `realloc` used directly | Easy to leak or misuse on failure | Arena allocation; a checked wrapper if growth is needed |

Additional rules in the same spirit:

- **No open-coded arithmetic in allocation sizes.** Sizes go through an overflow-checked helper (`cs_mul_size`, `cs_add_size`).
- **No `%p` and no printing of pointer values,** and nothing else that depends on addresses, time or environment, so that stage 0's output is deterministic.
- **No `qsort` with comparators that can return equal for distinct items.** Comparators must define a total order.

### Undefined and Implementation-Defined Behavior

- Do not assume `long` is 64-bit: use `int64_t` / `uint64_t`.
- Do not assume `char` signedness: use `unsigned char` / `uint8_t` for bytes.
- Use unsigned types where wraparound is intended; no signed overflow.
- No shifts by negative amounts or by at least the operand width; no left shifts of negative values.
- No type punning except through `memcpy`; no unaligned access; no reliance on struct padding or layout.
- No dependence on the order of evaluation of function arguments or operands.
- Pointer and integer conversion only through `uintptr_t`.
- `memmove`, not `memcpy`, whenever regions may overlap.

## Flags

- Clang, `zig cc` and GCC: `-std=c99` and `-std=c11` builds, both with `-pedantic-errors -Wall -Wextra -Wvla -Wconversion -Wformat=2 -Wformat-nonliteral -Wimplicit-fallthrough -Wstrict-prototypes -Wmissing-prototypes -Werror`.
- MSVC: `/std:c11 /W4 /WX`.
- Debug and test builds additionally with `-fsanitize=undefined,address`.

## Enforcement in CI

- **Banned-functions header:** a `cs_banned.h` in the style of git's `banned.h`, included last by a common project header, redefines each banned function as a macro that expands to an undefined identifier, so any use fails to compile.
- **Source check:** a script fails the build if a banned identifier appears in project sources or if a `.c` file does not include the common header.
- Build stage 0 and `libcsir` with `zig cc` and GCC, as both C99 and C11.
- A compile-only check with a small independent compiler as a canary for accidental extensions.
- An MSVC build on a Windows runner when practical.
- Run the stage 0 golden tests under UBSan and ASan.

Vendored QBE is third-party code and is exempt from this dialect and from the banned-functions list.

## Sources

- git `banned.h`: <https://github.com/git/git/blob/master/banned.h>
- Linux kernel deprecated interfaces: <https://docs.kernel.org/process/deprecated.html>
