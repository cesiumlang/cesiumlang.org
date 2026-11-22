---
title: "Grammar Reference"
tags: ["grammar"]
sortorder: 14
---

Cesium does not have a complete formal grammar yet. Writing one is tracked in [cesiumlang/cesium#57](https://github.com/cesiumlang/cesium/issues/57), and it is being published as part of the language specification ([cesiumlang/cesiumlang.org#13](https://github.com/cesiumlang/cesiumlang.org/issues/13)).

## What Exists Today

| Resource | What it is |
| --- | --- |
| [Language Specification (draft)](../spec/index.md) | The formal definition, in progress |
| [Specification: Lexical Structure](../spec/lexical.md) | Tokens, comments, identifiers, keywords and literals, with the undecided parts marked |
| [Specification: S0 Grammar](../spec/s0-grammar.md) | An EBNF grammar for the S0 subset, the part of the language the first compiler stage accepts |
| [cesiumlang/grammar](https://github.com/cesiumlang/grammar) | The TextMate grammar used for syntax highlighting on this site and in editors. It is regex-based and is not a definition of the language |

## Known Gaps

These syntax questions have to be answered before a grammar for the full language can be written:

| Question | Issue |
| --- | --- |
| Function definitions (`T = name(...) {`) cannot always be told apart from assignments | [cesiumlang/cesium#27](https://github.com/cesiumlang/cesium/issues/27) |
| Decorated operators collide with postfix transpose; bitwise NOT has no spelling | [cesiumlang/cesium#28](https://github.com/cesiumlang/cesium/issues/28) |
| Angle-bracket generics are ambiguous with comparison operators | [cesiumlang/cesium#29](https://github.com/cesiumlang/cesium/issues/29) |
| Several operators have no precedence level | [cesiumlang/cesium#15](https://github.com/cesiumlang/cesium/issues/15) |
| Numeric literal forms are not specified | [cesiumlang/cesium#56](https://github.com/cesiumlang/cesium/issues/56) |
| String and character literals, escapes | [cesiumlang/cesium#39](https://github.com/cesiumlang/cesium/issues/39) |
| The reserved-word list | [cesiumlang/cesium#50](https://github.com/cesiumlang/cesium/issues/50) |
