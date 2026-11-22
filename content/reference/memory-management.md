---
title: "Memory Management"
tags: ["memory", "ownership", "allocation", "defer"]
sortorder: 8
---

Cesium has no garbage collector and no reference counting. Memory is managed explicitly, and the compiler checks that every owned object is released exactly once.

> [!info] Source
> The rules on this page are the ownership design recorded in [cesiumlang/cesium#11](https://github.com/cesiumlang/cesium/issues/11) (decided 2026-11-16). Questions that design leaves open are marked "Open" with a link to the issue where they are being discussed.

## The Model

Ownership and borrowing are properties of **pointers only**. A plain value is just a value, and `=` on it copies.

A pointer either *borrows* the memory it points at or *owns* it. Separately, the sigil in its type says whether the data can be modified through it: `#T` is read-only, `~T` is read-write.

| Declaration | Kind | Data through the pointer |
| --- | --- | --- |
| `#T p #= q;` | immutable borrow | read-only |
| `~T p ~= q;` | mutable borrow | read-write |
| `#T p := f();` | owner | read-only |
| `~T p := f();` | owner | read-write |

- `#=`, `~=` and `:=` are *address-context* operators: they set where the pointer points. `#=` borrows immutably, `~=` borrows mutably, `:=` takes ownership.
- The sigil and the operator must agree. `~T p #= q;` and `#T p ~= q;` are compile errors.
- `:=` needs a pointer on the left. `Matrix m := f();` is a compile error.
- Plain `=` on a pointer assigns *through* it (pointers are dereferenced by default), so it is never how a pointer is initialized.
- A borrow may be re-pointed with a later `#=` or `~=`.

```cesium
i32 value = 42;

#i32 r #= #value;        // immutable borrow of a plain value: take its address with #
~i32 w ~= ~value;        // mutable borrow of a plain value: take its address with ~
w = 43;                  // plain = assigns through the pointer: value is now 43

#i32 r2 #= r;            // r is already a pointer, so no sigil on the right
```

## Allocation and Deallocation

`alloc(count)` allocates `count` elements. The element type comes from the pointer being initialized, and the result is owned, so it is received with `:=`.

```cesium
~i32 numbers := alloc(100);       // owner of 100 i32s, read-write
~f64 zeros := alloc(50, 0.0);     // allocate and initialize
#Config cfg := load_config();     // owner; the data is read-only through cfg

free(numbers);
free(zeros);
free(cfg);                        // an immutable owner can still free
```

### `free`

- Only the owner may `free`. A borrower never can.
- `free(p)` runs the type's `destruct` function, releases the memory, and resets `p` to `undefined`.
- `free` on a `null` or `undefined` pointer is a defined no-op.
- A `free` that the compiler can prove is redundant, such as a second `free` in straight-line code, is a compile error. The no-op covers only the cases the compiler cannot decide.

### `null` and `undefined`

- `undefined` is a keyword. For a pointer it is a defined "owns nothing" state: null in optimized builds, and optionally a distinct trap sentinel in debug or sanitizer builds. For a plain value it means truly uninitialized.
- `null` is a value assigned deliberately. `undefined` means never assigned, or freed. The two are different.
- There is no test for `undefined`.

> [!question] Open
> `realloc`, `copy` and the behavior of `alloc` on failure are not settled: how `realloc` is typed under the ownership rules (it consumes an owner and returns one), the argument list of `copy`, and whether allocation failure is reported as an error value or as `null`. See [cesiumlang/cesium#17](https://github.com/cesiumlang/cesium/issues/17) and open question 12 of [cesiumlang/cesium#11](https://github.com/cesiumlang/cesium/issues/11).

## Owners

1. **Every owner must be released.** An owner that reaches the end of its scope without being freed, moved or returned is a compile error. (This is stricter than Rust, which frees automatically at the end of the scope.)
2. **Reassigning an owner that still owns is a compile error.** Free or move the old memory first.
3. **Moving:** `#T b := a;` where `a` is an owner transfers ownership to `b`. Using `a` afterwards is a compile error.
4. **Mutability on transfer:** the receiver may be more restrictive than the source, never less. A `~` owner can be received as `#T`; a `#` owner cannot be received as `~T`.
5. In-place modification of owned data needs a `~` owner. Taking a mutable borrow from a `#` owner is a compile error.

```cesium
~Matrix m := create_matrix(3, 3);
defer free(m);                      // frees whatever m owns when this block exits
// m := create_matrix(4, 4);        // error: m still owns the 3x3 matrix
free(m);
m := create_matrix(4, 4);           // fine; the defer will free this one

~Matrix a := create_matrix(2, 2);
#Matrix b := a;                     // move; ~ to # is allowed
// transpose_inplace(a);            // error: a was moved
free(b);
```

## Ownership in Function Signatures

Arguments are type-checked strictly:

- A pointer is passed bare: `f(p)`. A `~T` pointer may be passed to a `#T` parameter, but nothing that is not mutable may be passed to a `~T` parameter.
- A plain value needs its address taken explicitly: `f(#x)` for a `#T` parameter, `f(~x)` for a `~T` parameter. Bare `f(x)` with a plain `x` is a compile error.

Ownership that crosses a function boundary is marked with `:` in front of the sigil:

| Spelling | Where | Meaning |
| --- | --- | --- |
| `#T` / `~T` | parameter | the function borrows the argument |
| `:#T` / `:~T` | parameter | the function takes ownership of the argument |
| `:#T` / `:~T` | return value | the caller receives ownership |
| `#T` / `~T` | return value | the caller receives a borrow, which must derive from the function's parameters or from globals |
| `:#T` / `:~T` | struct field | the field owns what it points to |

```cesium
// Returns ownership of a mutable Matrix.
:~Matrix = create_matrix(i32 rows, i32 cols) {
  ~Matrix m := alloc(1);
  // ... initialize ...
  return m;                         // ownership leaves with the return value
}

f64  = determinant(#Matrix m) { ... }        // immutable borrow
void = transpose_inplace(~Matrix m) { ... }  // mutable borrow
void = consume(:#Matrix m) { free(m); }      // takes ownership

void = demo() {
  ~Matrix a := create_matrix(3, 3);
  defer free(a);                    // runs when this block exits

  f64 d = determinant(a);           // pointer passed bare; ~ to # is allowed
  transpose_inplace(a);

  #Matrix b := create_matrix(2, 2); // received as immutable: allowed
  consume(b);                       // b is moved; using b after this is an error

  Matrix v;                         // plain value
  f64 dv = determinant(#v);         // plain value: address taken explicitly
  transpose_inplace(~v);
}
```

Because owned return values are marked one by one, a function can return a mix of owned and plain values:

```cesium
:~Matrix, u8 = try_invert(#Matrix m) { ... }
```

## Defer Statements

`defer` schedules a statement or block to run when the enclosing **block** exits. Deferred statements run in last-in, first-out order.

```cesium
void = process_file(str filename) {
  ~u8 buffer := alloc(1024);
  defer free(buffer);           // runs when this block exits

  if (some_condition) {
    return;                     // the deferred free runs here
  }

  for (i32 i = 0..3) {
    ~u8 scratch := alloc(64);
    defer free(scratch);        // runs at the end of every iteration
    // ...
  }
}                               // and the deferred free(buffer) runs here

// Defer with blocks
void = complex_processing() {
  defer {
    cleanup_temp_files();
    reset_global_state();
  };

  // multiple operations deferred together
}
```

- The deferred statement is evaluated **when it runs**, so it sees the values variables hold at that moment. `defer free(p);` frees whatever `p` owns when the block exits.
- The compiler checks a deferred statement as if it were written at every exit from the block. A deferred `free(p)` on a pointer that provably owns nothing at that point is a compile error; one that only *might* own nothing is allowed and is a no-op at run time.

## Context Managers

### Defining Context Managers

```cesium
// Define context manager for file handling
file = context enter(str path, str mode) {
  // open file and return handle
}

void = context exit(file f) {
  // close file automatically
}
```

### Using Context Managers

```cesium
// Usage with automatic cleanup
void = read_config() {
  with f = file("config.txt", "r") {
    process_config(read_all(f));
    // file automatically closed on exit
  } catch (err) {
    case (FileNotFound) {
      printf("Config file not found\n");
    }
  }
}
```

A `defer` inside a `with` body runs at the end of that body, before the context `exit`. To keep something alive past the `with` block, declare its owner outside the block, put the `defer` there, and assign ownership inside:

```cesium
void = load() {
  ~Buffer buf;                      // owns nothing yet (undefined)
  defer free(buf);                  // no-op if buf was never assigned

  with f = file("data.bin") {
    if (f.size == 0) { return; }    // early exit: the deferred free is a no-op
    buf := read_all(f);
  }
  // buf is still valid here
}
```

> [!question] Open
> Whether an unassigned owner may be declared bare (`~Buffer buf;`) or must be written out is not decided ([cesiumlang/cesium#25](https://github.com/cesiumlang/cesium/issues/25)). The rest of `with` (what `enter` and `exit` may do, and how errors inside the block are handled) is under review in [cesiumlang/cesium#41](https://github.com/cesiumlang/cesium/issues/41).

## `destruct`

A type's `destruct` function runs in two situations:

- when an owned pointer to the type is released with `free`, before the memory is released;
- when a plain (non-pointer) value of the type goes out of scope.

See [Object-Oriented Programming](object-oriented.md) for how a destructor is declared.

## Memory Safety Rules

1. **Ownership**: `:=` takes ownership; only pointers can own.
2. **Borrowing**: `#=` for immutable borrows, `~=` for mutable borrows; the sigil and the operator must agree.
3. **No use after move**: a moved-from owner cannot be used.
4. **No leaks**: every owner must be freed, moved or returned on every path.
5. **No double free**: a provably redundant `free` is a compile error; `free` resets the pointer to `undefined`.
6. **Deterministic cleanup**: `defer` runs at block exit; `free` runs `destruct`.

## Open Questions

These are part of the ownership design but not yet decided. The reference does not state a rule for them.

| Question | Issue |
| --- | --- |
| Borrow exclusivity (many immutable borrows or one mutable borrow) and when a borrow ends | [cesiumlang/cesium#21](https://github.com/cesiumlang/cesium/issues/21) |
| What `=` does to a value that owns memory (`str`, `list`, a struct with `:#T` fields) | [cesiumlang/cesium#22](https://github.com/cesiumlang/cesium/issues/22) |
| The state of an owner after branches that disagree | [cesiumlang/cesium#23](https://github.com/cesiumlang/cesium/issues/23) |
| Whether a move at a call site should be marked | [cesiumlang/cesium#24](https://github.com/cesiumlang/cesium/issues/24) |
| How an unassigned owner is declared | [cesiumlang/cesium#25](https://github.com/cesiumlang/cesium/issues/25) |
| Pointers that come from C, pointer arithmetic and `asm` in relation to the checker | [cesiumlang/cesium#45](https://github.com/cesiumlang/cesium/issues/45) |

> [!warning] Provisional — not decided (cesiumlang/cesium#21)
> Until borrow exclusivity is confirmed, read the September 2025 rule as the working assumption: at any moment a piece of memory has either any number of immutable borrows or exactly one mutable borrow, never both, and a borrow ends when the borrowing pointer goes out of scope or is re-pointed. Freeing or moving an owner while a borrow of it is live would then be a compile error. This is the rule the examples on this page were written to satisfy, but it was not revisited when the rest of the ownership design was decided.
