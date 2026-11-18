---
title: "S0 Grammar (Draft)"
tags: ["spec", "grammar", "s0"]
sortorder: 3
---

> [!warning] Draft
> Chapter 3 of the [[spec/index|language specification draft]]. This is a first transcription of the S0 design into a grammar. It has not yet been run through a parser generator, which is on the checklist in [cesiumlang/cesiumlang.org#13](https://github.com/cesiumlang/cesiumlang.org/issues/13). Where this chapter and [cesiumlang/cesium#9](https://github.com/cesiumlang/cesium/issues/9) disagree, the issue wins. Section 3.10 compares it with the first stage 0 implementation.

S0 is the subset of Cesium that stage 0 compiles. It is described in prose in [[compiler/s0-subset|The S0 Subset]]. This chapter gives its grammar in EBNF and traces each production to its source. See the [[spec/index|introduction]] for the notation and the citation format.

Sources used in this chapter:

| Tag | Source |
| --- | --- |
| `[S0]` | The "S0 contents" table of [cesiumlang/cesium#9](https://github.com/cesiumlang/cesium/issues/9) |
| `[S0-map]` | The "S0 to core MIR mapping" table of the same issue |
| `[S0-sample]` | The sample program of the same issue |
| `[S0-amend]` | The amendment comment on the same issue (2026-11-16) |
| `[own rN]` | Rule N of the ownership design, [cesiumlang/cesium#11](https://github.com/cesiumlang/cesium/issues/11) |
| `[ref: page]` | A page of the [[reference/index\|language reference]] |

## 3.1 Lexical Elements

S0 uses the lexical structure of [[spec/lexical|chapter 2]], restricted as follows.

```text
ident        = identifier ;                       (* 2.4 *)
int_lit      = decimal_literal ;                  (* 2.6; [S0] "integers" *)
char_lit     = "'" character "'" ;                (* [S0] "characters ('A')" *)
string_lit   = '"' { character } '"' ;            (* [S0] "strings as NUL-terminated #u8" *)
lib_name     = "'" { character } "'" ;            (* [S0] import('lib') *)
```

- Comments are as in 2.3.
- **Open.** `character` includes escape sequences, whose set is not specified (2.6). The S0 sample uses `'\n'`. Integer literal forms other than decimal are not specified (2.6).

## 3.2 Compilation Unit

```text
unit         = { top_decl } ;
top_decl     = struct_decl
             | extern_block
             | const_decl
             | global_decl
             | func_def ;
```

| Production | Source |
| --- | --- |
| `unit` | `[S0]` "Compilation unit": multiple files compiled as one unit with shared globals; no `import` of Cesium modules |
| `top_decl` | `[S0]` "Data", "Outside world", "Globals", "Functions" |

Several source files form one unit. The grammar above applies to each file; the declarations of all files share one scope. `[S0]`

## 3.3 Types

```text
type         = { sigil } base_type ;
sigil        = "#" | "~" ;
base_type    = "u8" | "i32" | "u32" | "i64" | "u64" | "uword"
             | ident ;                            (* a struct name *)
ret_type     = "void" | type ;
declarator   = ident [ "[" int_lit "]" ] ;
```

| Production | Source |
| --- | --- |
| `base_type` | `[S0]` "Types": `u8`, `i32`, `u32`, `i64`, `u64`, `uword`; "Data": `struct` |
| `sigil`, `type` | `[S0]` "Types": pointers `#T`; `~T` is parsed and treated the same; pointer-to-pointer `##T` |
| `ret_type` | `[S0]` "Functions": `void` |
| `declarator` | `[S0]` "Types": fixed arrays `T name[N]` |

- **Decided.** `#T` in a declaration is a pointer to `T` everywhere. `[S0-amend]`
- **Decided.** Stage 0 does not check borrows; it treats `~T` exactly as `#T`. `[S0]`
- **Open.** Whether the array length `N` may be a `const` global as well as an integer literal is not stated in `[S0]`. This draft allows only a literal.

## 3.4 Declarations

```text
struct_decl  = "struct" ident "{" { field_decl } "}" ;
field_decl   = type declarator ";" ;

extern_block = "extern" ident "=" "import" "(" lib_name ")"
               "{" { extern_func } "}" ;
extern_func  = ret_type "=" ident "(" [ params ] ")" ";" ;

const_decl   = "const" type ident "=" expr ";" ;
global_decl  = type declarator [ initializer ] ";" ;

func_def     = ret_type "=" ident "(" [ params ] ")" block ;
params       = param { "," param } ;
param        = type ident ;

initializer  = "=" expr                          (* plain values only *)
             | ":=" expr                         (* pointers only: ownership *)
             | "#=" expr ;                       (* pointers only: borrow *)
```

| Production | Source |
| --- | --- |
| `struct_decl`, `field_decl` | `[S0]` "Data": `struct` with fields only, no methods; `[S0-sample]` `struct Token` |
| `extern_block`, `extern_func` | `[S0]` "Outside world": `extern name = import('lib') { ... }` declaring C ABI functions; `[S0-sample]` |
| `const_decl` | `[S0]` "Globals": `const` globals; `[S0-sample]` `const i64 TOK_IDENT = 1;` |
| `global_decl` | `[S0]` "Globals": global variables |
| `func_def`, `params`, `param` | `[S0]` "Functions": `T = name(params) { ... }`, single return value, `void`, recursion |
| `initializer` | `[S0-map]` `T name = e;`; `[S0-amend]` and `[own r4, r5]`: a pointer is never initialized with plain `=` |

- **By omission.** A function is defined only at the top level of a unit: `[S0]` lists no nested functions. So in S0 the form `ret_type "=" ident "("` cannot be confused with an assignment, which occurs only inside a block. (For the full language this ambiguity is open: [cesiumlang/cesium#27](https://github.com/cesiumlang/cesium/issues/27).)
- **Decided.** There is a single return value. `[S0]`
- **Decided.** Struct literals do not exist in S0; fields are assigned one at a time. `[S0]`
- **Decided.** The entry point is `i32 = main(i32 argc, ##u8 argv)`. `[S0]`
- **Decided.** Parameters, return values and `extern` signatures use only scalar and pointer types; a struct is not passed or returned by value. `[cesium#8]`, "v0 restrictions"
- **Open.** Whether a `const` global may be an array or a pointer, and what expressions may initialize a global, are not stated in `[S0]`.
- **Open.** How a function declared in an `extern` block is named at the call site. The sample calls `write(...)` without the block's name, while the reference writes `windows.Sleep(ms)` and uses `export` or `as` to make a name global ([[modules-imports|Modules and Imports]]). See [cesiumlang/cesium#19](https://github.com/cesiumlang/cesium/issues/19).

## 3.5 Statements

```text
block        = "{" { statement } "}" ;
statement    = local_decl
             | assign_stmt
             | expr_stmt
             | if_stmt
             | while_stmt
             | "break" ";"
             | "continue" ";"
             | return_stmt ;

local_decl   = type declarator [ initializer ] ";" ;
assign_stmt  = place assign_op expr ";" ;
assign_op    = "=" | ":=" | "#=" ;
place        = ident { "[" expr "]" | "." ident } ;
expr_stmt    = expr ";" ;
if_stmt      = "if" "(" expr ")" block [ "else" ( block | if_stmt ) ] ;
while_stmt   = "while" "(" expr ")" block ;
return_stmt  = "return" [ expr ] ";" ;
```

| Production | Source |
| --- | --- |
| `local_decl` | `[S0-map]` `T name = e;` (local); `[S0-sample]` `u8 tmp[20];` |
| `assign_stmt`, `place` | `[S0-map]` `x = e;`, `p[i] = e;`, `p.f = e;` |
| `assign_op` | `=`: `[S0-map]`. `:=` and `#=`: `[S0-amend]`, `[own r2]` |
| `expr_stmt` | `[S0-sample]` `write(1, s, cstr_len(s));`; core MIR `eval` `[cesium#8]` |
| `if_stmt`, `while_stmt`, `break`, `continue`, `return_stmt` | `[S0]` "Control flow" |
| `else` followed by `if` | `[ref: control-flow]` |

- **Decided.** Plain `=` on a pointer assigns through it; a pointer is given its address only with an address-context operator. So `t.start #= "hello";` sets a pointer field, and `#Token t := alloc(1);` receives an allocation. `[S0-amend]` `[own r2, r5]`
- **Decided.** `break` and `continue` apply to the innermost `while`. `[cesium#8]`
- **Decided by use.** The bodies of `if`, `else` and `while` are blocks; the reference never writes a body without braces. `[ref: control-flow]`
- **Open.** `~=` is the mutable-borrow operator of the full language `[own r2]`, and the sigil and the operator must agree `[own r3]`. `[S0]` says that `~T` is parsed but does not list `~=`, and `[S0-amend]` does not mention it. This draft therefore leaves `~=` out of S0. Since a `~T` pointer cannot be borrowed into without it, this needs an answer in [cesiumlang/cesium#9](https://github.com/cesiumlang/cesium/issues/9).
- **By omission.** A block used as a statement by itself is not listed in `[S0]` and is not included.

### Telling a Declaration from a Statement

This is an observation about the productions above, not an additional rule. After any leading sigils, a `statement` is a `local_decl` if it continues with a primitive type name, or with two `ident` tokens in a row (`Token t;`, `#Token t := ...`); no expression has that shape. Otherwise it is an `assign_stmt` or an `expr_stmt`. No symbol table is needed to tell them apart. Whether this holds up is one of the things the parser-generator check on the [cesiumlang/cesiumlang.org#13](https://github.com/cesiumlang/cesiumlang.org/issues/13) checklist is for.

## 3.6 Expressions

The levels below follow the precedence table of the reference, from lowest to highest. `[ref: operators-expressions]`

```text
expr         = logical_or ;
logical_or   = logical_and { "||" logical_and } ;            (* level 17 *)
logical_and  = bit_or { "&&" bit_or } ;                      (* level 16 *)
bit_or       = bit_xor { "|" bit_xor } ;                     (* level 15 *)
bit_xor      = bit_and { "><" bit_and } ;                    (* level 14 *)
bit_and      = equality { "&" equality } ;                   (* level 13 *)
equality     = relational { ( "==" | "!=" ) relational } ;   (* level 12 *)
relational   = shift { ( "<" | ">" | "<=" | ">=" ) shift } ; (* level 11 *)
shift        = additive { ( "<<" | ">>" ) additive } ;       (* level 10 *)
additive     = multiplicative { ( "+" | "-" ) multiplicative } ;   (* level 9 *)
multiplicative = prefix { ( "*" | "/" | "%" ) prefix } ;     (* level 7 *)
prefix       = postfix
             | "#" prefix ;                                  (* level 4: address-of *)
postfix      = primary { "[" expr "]"                        (* level 1: indexing *)
                       | "." ident                           (* level 1: member access *)
                       | "(" [ args ] ")" } ;                (* level 1: call *)
primary      = ident
             | int_lit
             | char_lit
             | string_lit
             | "sizeof" "(" type ")"
             | "(" expr ")" ;
args         = expr { "," expr } ;
```

| Production | Source |
| --- | --- |
| The binary operators | `[S0]` "Expressions": `+ - * / %`, comparisons, `&&` and `\|\|`, bitwise `&`, `\|` and `><`, shifts `<<` and `>>` |
| Their relative precedence | `[ref: operators-expressions]`, levels 7 to 17 |
| `prefix` with `#` | `[S0]` address-of `#x`; `[S0-map]` `#x` is `addr(%x)` |
| `postfix` | `[S0]` indexing `p[i]`, field access `a.b` (auto-dereferences pointers); `[S0-map]` `f(args)` |
| `sizeof` | `[S0]` `sizeof`; `[S0-map]` `sizeof(T)` |
| Literals | `[S0]` "Literals" |

- **Decided.** There is no dereference operator. A pointer is dereferenced by default; `p[i]` and `p.f` reach through a pointer. `[S0-amend]` `[own r5, r29]`
- **Decided.** The arithmetic operators have core MIR's defined semantics: integers wrap, and shifts and division by zero have defined results. `[S0]` `[cesium#8]`
- **Decided.** `&&` and `||` short-circuit. `[S0-map]` (`land`, `lor`)
- **Decided.** `alloc(count)` is written as a call. Its element type comes from the pointer it initializes. `[S0]` "Memory"
- **Implied.** The binary operators group left to right. The reference marks only exponentiation, which is not in S0, as right-associative. `[ref: operators-expressions]`

### Operators Without a Decided Place

`[S0]` lists two more operators that the grammar above leaves out, because the reference's precedence table has no level for them ([cesiumlang/cesium#15](https://github.com/cesiumlang/cesium/issues/15)):

- logical NOT, `!a` (`lnot` in core MIR);
- the cast, `e as T` (`as(T, e)` in core MIR).

> [!warning] Provisional — not decided (cesiumlang/cesium#15)
> Until their precedence is decided, this draft recommends the following placement, which stage 0 can adopt without constraining the eventual answer for well-parenthesized code:
>
> ```text
> multiplicative = cast { ( "*" | "/" | "%" ) cast } ;
> cast           = prefix { "as" type } ;
> prefix         = postfix | "#" prefix | "!" prefix ;
> ```
>
> `!` joins address-of at the unary prefix level (level 4), which is the level [cesiumlang/cesium#15](https://github.com/cesiumlang/cesium/issues/15) describes it as missing from. `as` binds more tightly than every binary operator and less tightly than the prefix and postfix operators, so that `a + b as u8` casts only `b`, and `#x as #T` casts the address. Both uses in the S0 sample (`('0' + (v % 10)) as u8` and `t.len as u64` as an argument) parse the same way under any placement. Code in the frozen stage 1 source should parenthesize every operand of `as` and `!` that is not a primary expression, so that it keeps its meaning whatever is decided.

- **Open.** Unary minus is not in `[S0]`, and it has no place in the reference's table either. S0 source writes `0 - x`.
- **Open.** Prefix `~x`, the address-of for a mutable borrow `[own r20]`, is not listed in `[S0]`. See the note on `~=` in 3.5.
- **Open.** `null` is not listed in `[S0]`, and how two pointers are compared for identity under dereference-by-default is not defined ([cesiumlang/cesium#26](https://github.com/cesiumlang/cesium/issues/26), [cesiumlang/cesium#43](https://github.com/cesiumlang/cesium/issues/43)).
- **Open.** The result type of a comparison (`u8` in core MIR) and the type of an integer literal when its context does not determine it. `[cesium#9]`, open question 2.

## 3.7 Constraints

These are checked after parsing. Stage 0 does only "minimal type checking" `[cesium#9]`, so this list states what S0 *source* must satisfy, not what stage 0 diagnoses.

1. An `initializer` or `assign_op` of `=` is used with a plain value on the left, or to assign through a pointer. `:=` and `#=` are used only with a pointer on the left. `[own r4, r5]`
2. A pointer argument is passed bare. A plain value passed to a pointer parameter has its address taken explicitly with `#`. `[own r20]`
3. Every S0 program is a valid Cesium program with the same meaning. `[cesium#9]`, rule 1
4. **Open.** Rule 3 implies that S0 source must also satisfy the ownership rules that stage 0 does not check: owners released on every path `[own r9]`, and writes only through `~T` `[own r1]`. S0 has no `free`, and the sample program writes through `#T` pointers. How these fit together is not yet addressed in [cesiumlang/cesium#9](https://github.com/cesiumlang/cesium/issues/9).

## 3.8 Mapping to Core MIR

Each S0 construct maps onto core MIR as given in `[S0-map]`, reproduced in [[compiler/s0-subset|The S0 Subset]]. The mapping, with the lowering of each production, will become chapter 9 of this specification.

## 3.9 Not in S0

Everything else in the language. `[S0]` names these explicitly: `for`, ranges, `switch` / `case`, `enum`, unions and `typeof`, `slice` / `list` / `dict` / `str`, multiple return values, `defer`, `error` types and `catch` / `throw`, modules and `import` of Cesium code, floating point, `free` / `realloc`, methods and `this`, generics, traits, inheritance, operator overloading, the math operators (`^`, `::`, `@`, context-aware `*`, postfix `~`), SIMD, `comptime`, string interpolation, `with`, inline `asm`, `volatile` / `atomic`.

## 3.10 Comparison with the Stage 0 Implementation

The first implementation of stage 0 ([cesiumlang/cesium#60](https://github.com/cesiumlang/cesium/pull/60), under review) was written against this chapter. Its parser follows the productions above, including the precedence levels of 3.6 and the provisional placement of `!` and `as`. It differs in the places below. None of these is a decision; each is recorded in that pull request for review.

**Accepted by stage 0 but not in this grammar**

| Form | Treated as | Reason given |
| --- | --- | --- |
| `~=` as an `assign_op` and an `initializer` | `#=` | `[own r2]`; "stage 0 still parses the ownership forms without enforcing them" ([cesiumlang/cesium#11](https://github.com/cesiumlang/cesium/issues/11)) |
| Prefix `~x` | `#x` | `[own r20]`, same sentence |
| `:` before the sigils of a parameter, field or return type (`:#T`, `:~T`) | the plain pointer type | `[own r22]` to `[own r25]`, same sentence |
| A `lib_name` written as a double-quoted string | the same | none; `import('c')` is the form in `[S0]` |

**In this grammar but rejected by stage 0**

| Form | What stage 0 requires |
| --- | --- |
| Any `expr` as an `expr_stmt` | The expression is a call |
| A call on any `postfix` expression | The callee is a name |
| Any `expr` initializing a `const_decl` | An integer literal, a character literal, or the name of another constant |
| Any `expr` initializing a `global_decl` | A literal or constant for a number; a string literal for a `#u8` |
| Any number of arguments or parameters | At most 64 |
| Expressions and statements nested to any depth | At most 128 levels ([cesiumlang/cesium#69](https://github.com/cesiumlang/cesium/pull/69)). An operand, the body of an `if` or `while`, each further `else if`, and each further operator of a chain such as `a + b + c` is one level. Stage 0 recurses along the nesting, and deeper source overflowed its stack. |

**Constraints stage 0 checks beyond 3.7**

Stage 0 rejects a literal whose type no context determines, a local that reuses a name in scope, a name that is a keyword of full Cesium, and the assignment of a struct or array as a whole. Each corresponds to an open question; [[compiler/s0-subset|The S0 Subset]] lists them with their issues.
