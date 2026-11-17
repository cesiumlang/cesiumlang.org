---
title: "Language Specification (Draft)"
tags: "spec"
---

> [!warning] Draft
> This specification is a **skeleton**. Only the chapters listed as "Draft" below exist, and they cover only what has been decided. Nothing here is final. Progress is tracked in [cesiumlang/cesiumlang.org#13](https://github.com/cesiumlang/cesiumlang.org/issues/13).

The [[reference/index|language reference]] explains Cesium by example, for people learning and using the language. This specification is the more technical document derived from it: the definition a compiler or tool can be checked against. The reference pages and their code examples are its source material, together with the decision records and design issues in [cesiumlang/cesium](https://github.com/cesiumlang/cesium/issues).

## How to Read This Specification

### Status Markers

Every rule carries one of three statuses.

| Marker | Meaning |
| --- | --- |
| **Decided** | Recorded as a decision. The rule cites the issue or page it comes from |
| **Provisional** | A recommendation by the editors, not a decision. Always inside a "Provisional" callout that names the issue where it is being discussed |
| **Open** | Not decided. The specification states no rule and links to the issue |

If a rule has no citation, treat it as a defect in the specification and report it.

### Citations

Rules cite their source in square brackets:

- `[cesium#11 r5]` is rule 5 of [cesiumlang/cesium#11](https://github.com/cesiumlang/cesium/issues/11). Other issues in that repository are cited the same way.
- `[ref: page]` is a page of the [[reference/index|language reference]].

### Grammar Notation

Grammars are written in EBNF:

| Notation | Meaning |
| --- | --- |
| `name = ... ;` | A production |
| `"text"` | A terminal: the literal characters |
| `a b` | `a` followed by `b` |
| `a \| b` | `a` or `b` |
| `[ a ]` | Optional `a` |
| `{ a }` | Zero or more `a` |
| `( a )` | Grouping |
| `(* ... *)` | A comment |

## Chapters

| # | Chapter | Status |
| --- | --- | --- |
| 1 | Introduction and conventions | This page |
| 2 | [[spec/lexical\|Lexical structure]] | Draft: decided parts only |
| 3 | [[spec/s0-grammar\|Syntactic grammar: the S0 subset]] | Draft |
| 3 | Syntactic grammar: S1 and the full language | Not started. Blocked on [cesiumlang/cesium#27](https://github.com/cesiumlang/cesium/issues/27), [#28](https://github.com/cesiumlang/cesium/issues/28), [#29](https://github.com/cesiumlang/cesium/issues/29) and [#57](https://github.com/cesiumlang/cesium/issues/57) |
| 4 | Types | Not started. Open: [cesiumlang/cesium#16](https://github.com/cesiumlang/cesium/issues/16), [#34](https://github.com/cesiumlang/cesium/issues/34), [#36](https://github.com/cesiumlang/cesium/issues/36), [#38](https://github.com/cesiumlang/cesium/issues/38) |
| 5 | Expressions | Not started. Open: [cesiumlang/cesium#15](https://github.com/cesiumlang/cesium/issues/15), [#26](https://github.com/cesiumlang/cesium/issues/26), [#33](https://github.com/cesiumlang/cesium/issues/33), [#35](https://github.com/cesiumlang/cesium/issues/35) |
| 6 | Statements | Not started. Open: [cesiumlang/cesium#41](https://github.com/cesiumlang/cesium/issues/41), [#49](https://github.com/cesiumlang/cesium/issues/49) |
| 7 | Declarations | Not started. Open: [cesiumlang/cesium#19](https://github.com/cesiumlang/cesium/issues/19), [#47](https://github.com/cesiumlang/cesium/issues/47), [#52](https://github.com/cesiumlang/cesium/issues/52) |
| 8 | Ownership rules | Not started. The decided rules are in [cesiumlang/cesium#11](https://github.com/cesiumlang/cesium/issues/11) and summarized in [[memory-management\|Memory Management]]. Open: [cesiumlang/cesium#21](https://github.com/cesiumlang/cesium/issues/21) to [#25](https://github.com/cesiumlang/cesium/issues/25) |
| 9 | MIR mapping | Not started. The S0 mapping is in chapter 3; the IR is described in [[compiler/mir\|Middle IR]] |
| 10 | Conformance levels | Outline below |

## Conformance Levels

The bootstrap chain defines nested subsets of the language ([cesium#9]). Each compiler stage must accept its level, and every later compiler must keep accepting the levels below it.

| Level | Defined by | Accepted by | Status |
| --- | --- | --- | --- |
| **S0** | [[spec/s0-grammar\|Chapter 3]] | Stage 0 and every later compiler | Draft |
| **S1** | To be written | `cesium1` and every later compiler | Open: the S1 feature list is a set of candidates to be confirmed ([cesiumlang/cesium#9](https://github.com/cesiumlang/cesium/issues/9)) |
| **Full** | The whole specification | The real compiler | Open: which features are core, planned or unproven is [cesiumlang/cesium#58](https://github.com/cesiumlang/cesium/issues/58) |

Each level is a strict subset of the next: a program that conforms to a level is a valid program of every higher level, with the same meaning ([cesium#9], rule 1).

A conformance test suite of valid and invalid programs for each level is planned ([cesiumlang/cesium#57](https://github.com/cesiumlang/cesium/issues/57), step 3).
