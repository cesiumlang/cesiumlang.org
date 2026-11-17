---
title: "Lexical Structure (Draft)"
tags: ["spec", "lexical"]
sortorder: 2
---

> [!warning] Draft
> Chapter 2 of the [[spec/index|language specification draft]]. It states only what is decided. Undecided areas are marked "Open" with the issue to follow. See the [[spec/index|introduction]] for the status markers, the citation format and the grammar notation.

## 2.1 Source Files

1. **Decided.** A Cesium source file has the extension `.csm`. A module interface file has the extension `.csi`. No other extensions are used. `[cesium#14]`
2. **Decided.** The syntax of the language uses ASCII characters only. `[ref: overview, "Design Goals"]`
3. **Open.** The encoding of a source file, and which characters may appear in comments and string literals, are not stated. The reference says only that `str` values are UTF-8. See [cesiumlang/cesium#39](https://github.com/cesiumlang/cesium/issues/39).

## 2.2 Whitespace and Tokens

No decision record states how source text is divided into tokens.

> [!warning] Provisional — not decided (cesiumlang/cesium#57)
> This draft assumes the conventional rules, which every example in the reference is consistent with: space, horizontal tab, carriage return and line feed separate tokens and are otherwise not significant; and at each point the lexer takes the longest sequence of characters that forms a token. The second rule is what makes `#=` one token and not `#` followed by `=`. It also has consequences that have not been examined, for example `p#++` against `p #+ +1`, and `::` (root) against `:` followed by an owned type `:#T`; those collisions are listed in [cesiumlang/cesium#57](https://github.com/cesiumlang/cesium/issues/57) and [cesiumlang/cesium#28](https://github.com/cesiumlang/cesium/issues/28).

## 2.3 Comments

1. **Decided.** There are three forms of comment `[ref: lexical-structure]`:

   | Form | Extent |
   | --- | --- |
   | `// ...` | To the end of the line |
   | `/* ... */` | To the closing `*/` |
   | `/** ... */` | A documentation comment |

2. **Open.** Whether block comments nest is not stated anywhere.
3. **Open.** The tags recognized inside documentation comments (the reference shows `@param` and `@return`) are not specified.

## 2.4 Identifiers

1. **Decided.** An identifier starts with a letter or an underscore and continues with letters, digits or underscores. `[ref: lexical-structure]`

   ```text
   identifier = ( letter | "_" ) { letter | digit | "_" } ;
   letter     = "A" ... "Z" | "a" ... "z" ;
   digit      = "0" ... "9" ;
   ```

2. **Decided.** A keyword (2.5) is not an identifier.
3. **Open.** Whether there is a limit on identifier length, and whether identifiers that begin with an underscore are reserved, is not stated.

## 2.5 Keywords

1. **Decided.** The following words are reserved `[ref: lexical-structure]`, with `undefined` added by `[cesium#11 r15]`:

   | Group | Keywords |
   | --- | --- |
   | Core types | `file` `str` `list` `dict` `slice` `struct` `path` `uword` |
   | Language constructs | `alias` `catch` `as` `return` `comptime` `generic` `sizeof` `typeof` `asm` `void` `enum` `error` `null` `undefined` `union` |
   | Control flow | `if` `while` `for` `else` `do` `with` `defer` `break` `continue` `switch` `case` `fallthrough` `throw` |
   | Function qualifiers | `operator` `context` `property` `private` `secret` `static` `destruct` |
   | Variable qualifiers | `const` `static` `private` `secret` `volatile` `atomic` `register` `simd` |
   | C interop | `extern` `export` |
   | Object-oriented constructs | `trait` `impl` `type` `this` `super` |
   | Namespacing | `std` `namespace` |

2. **Open.** `import` is used as a keyword in the reference and in the S0 subset but is not in the list. The sized type names (`u8`, `i32`, `f64` and the arbitrary-width forms such as `u34`) are not in the list either, and the reference does not say whether they are keywords or predefined identifiers. Which built-in names (`alloc`, `free`, `printf` and others) are reserved and which can be shadowed is not decided. See [cesiumlang/cesium#20](https://github.com/cesiumlang/cesium/issues/20) and [cesiumlang/cesium#50](https://github.com/cesiumlang/cesium/issues/50).

## 2.6 Literals

### Integer Literals

1. **Decided.** There are no type suffixes. A literal takes its type from context, and `as` forces one. `[cesium#16]`
2. **Decided by use.** Decimal integer literals are a sequence of decimal digits. They appear throughout the reference and the S0 design. `[ref: type-system]` `[cesium#9]`

   ```text
   decimal_literal = digit { digit } ;
   ```

3. **Open.** No other form is specified. The reference uses hexadecimal (`0xFF`) and binary (`0b11110000`) literals in examples, and the highlighting grammar also accepts octal (`0o755`); none of these has a decision behind it, and neither do digit separators. The type of a literal with no context, and what happens when a literal does not fit its type, are also open. See [cesiumlang/cesium#56](https://github.com/cesiumlang/cesium/issues/56) and [cesiumlang/cesium#16](https://github.com/cesiumlang/cesium/issues/16).

### Floating-Point Literals

1. **Open.** The reference uses the form `3.14159` in examples. Exponents and every other detail are unspecified ([cesiumlang/cesium#56](https://github.com/cesiumlang/cesium/issues/56)). The form interacts with the range operator `..`, as in `1..2` ([cesiumlang/cesium#57](https://github.com/cesiumlang/cesium/issues/57)).

### Character Literals

1. **Decided by use.** A character literal is a character between single quotes, such as `'A'`. There is no character type; the literal is a number that can be stored in a `u8`. `[ref: type-system]` `[cesium#9]`
2. **Open.** The set of escape sequences is not specified. `'\n'` is used in the S0 design. See [cesiumlang/cesium#39](https://github.com/cesiumlang/cesium/issues/39).

### String Literals

1. **Decided.** A simple string literal is written between double quotes and supports escape sequences. `[ref: lexical-structure]`
2. **Decided.** An interpolated string literal is written between backticks, with expressions embedded in `{` `}`. `[ref: lexical-structure]`
3. **Decided (S0).** In the S0 subset a string literal denotes a NUL-terminated sequence of bytes, and its value is a `#u8`. `[cesium#9]`
4. **Open.** The set of escape sequences (the reference uses `\n`), the type of a string literal in the full language, and the grammar of interpolated expressions: [cesiumlang/cesium#39](https://github.com/cesiumlang/cesium/issues/39). Library names in `import('c')` are written between single quotes, which collides with character literals: [cesiumlang/cesium#19](https://github.com/cesiumlang/cesium/issues/19).

### Other Literals

1. **Decided.** `null` and `undefined` are keywords and are different from each other. `null` is assigned deliberately; `undefined` is the state of a pointer that owns nothing and of a plain value that is uninitialized. There is no test for `undefined`. `[cesium#11 r15, r16, r19]`

## 2.7 Operators and Punctuation

1. **Decided.** The assignment operators are `=`, `#=`, `~=` and `:=`. The last three are address-context operators. `[cesium#11 r2]`
2. **Decided.** `#` and `~` are type sigils and prefix operators (address-of for an immutable and a mutable borrow), and `:` in front of a sigil marks an owned type: `:#T`, `:~T`. `[cesium#11 r1, r20, r22]`
3. **Decided.** Address arithmetic is written with decorated operators. Two families exist, `#`-decorated and `~`-decorated, for example `#+` and `~+`, including in-place forms such as `#++`. `[cesium#11 r30]`
4. **Decided.** The binary and unary operators listed in the reference's precedence table: `::`, `^`, `*`, `/`, `%`, `@`, `**`, `+`, `-`, `<<`, `>>`, `<`, `>`, `<=`, `>=`, `==`, `!=`, `&`, `><`, `|`, `&&`, `||`, postfix `~`, the range operators `..` and `..=`, and custom operators of the form `$name$`. `[ref: operators-expressions]`
5. **Decided by use.** The punctuation `(` `)` `[` `]` `{` `}` `,` `;` `.` and, for variadic parameters, `...`. `[ref: functions]`
6. **Open.** The complete list of decorated operators; unary `-`, `+` and `!`; a bitwise NOT; `++` and `--`; the compound assignments; the ternary `?` `:`; the comma operator; and unary `..` ([cesiumlang/cesium#15](https://github.com/cesiumlang/cesium/issues/15), [cesiumlang/cesium#28](https://github.com/cesiumlang/cesium/issues/28)). The angle brackets of `generic<T>` ([cesiumlang/cesium#29](https://github.com/cesiumlang/cesium/issues/29)).
