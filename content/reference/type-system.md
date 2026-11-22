---
title: "Type System"
tags: ["types", "primitives", "arrays", "pointers", "simd"]
sortorder: 3
---

## Primitive Types

### Integer Types

```cesium
// Integer types
u8 byte_val = 255;
u16 short_val = 65535;
u32 int_val = 4294967295;
u64 long_val = 18446744073709551615;
u34 arbitrary_bit_width = 9192631770;

i8 signed_byte = -128;
i16 signed_short = -32768;
i32 signed_int = -2147483648;
i64 signed_long = -9223372036854775808;
i34 signed_arbitrary_bit_width = -9192631770;

// Word-sized integer (pointer-sized)
uword size = 1024;

// No separate bool or char - use u8
u8 is_valid = 1;  // true
u8 letter = 65;   // 'A'
u8 also_letter = 'A';
```

### Floating Point Types

```cesium
f16 small_float = 3.14;
f32 single = 3.14159;
f64 double = 3.141592653589793;
f128 quad;
```

## Array Types

### Fixed Arrays

```cesium
// Fixed arrays
i32 numbers[10];
f64 matrix[3][3];  // 3x3 matrix

// Array type syntax (for function parameters)
void = process_data(f64 values[], uword count);
```

### Dynamic Arrays

```cesium
// Dynamic arrays
list[i32] dynamic_numbers;
slice[f64] array_view;  // non-owning view
```

## SIMD Types

```cesium
simd f32 vec4[4];     // 4-element float vector
simd f64 vec2[2];     // 2-element double vector
simd u32 vec8[8];     // 8-element integer vector

// SIMD operations work with existing operators
simd f32 a[4], b[4], result[4];
result = a + b;  // vectorized addition
```

## Pointer Types

The sigil says whether the data can be modified through the pointer: `#T` is a pointer to read-only data, `~T` a pointer to read-write data. Sigils nest, reading left to right.

```cesium
#i32 int_ptr;         // pointer to i32; the i32 cannot be modified through it
~i32 mut_ptr;         // pointer to i32; the i32 can be modified through it
##i32 ptr_to_ptr;     // immutable pointer to immutable pointer to i32
~#i32 mut_ptr_to_ptr; // mutable pointer to immutable pointer to i32
#~i32 ptr_to_mut_ptr; // immutable pointer to mutable pointer to i32
```

Pointers are **dereferenced by default**: using a pointer in a value context reads or writes the data it points to. There is no dereference operator. The address itself is only touched by the address-context operators.

```cesium
// Ownership and borrowing
~Matrix m := create_matrix(3, 3);  // owning pointer
#Matrix borrowed_m #= m;           // immutable borrow

~Matrix n := create_matrix(3, 3);  // another owning pointer
~Matrix mutable_n ~= n;            // mutable borrow

// ... and once the borrows are no longer in use:
free(m);
free(n);

Matrix v;                          // plain value
#Matrix borrowed_v #= #v;          // borrowing a plain value: take its address
```

Owned pointers that cross a boundary are written with a leading `:` — `:#T` or `:~T` — in return types, parameters and struct fields. See [Memory Management](memory-management.md).

> [!question] Open
> Ownership rules for multi-level pointers (`##T`, `~#T`) are not settled (open question 11 of [cesiumlang/cesium#11](https://github.com/cesiumlang/cesium/issues/11)), and neither is how dereference-by-default resolves where the expected type is not fixed ([cesiumlang/cesium#26](https://github.com/cesiumlang/cesium/issues/26)).

## User-Defined Types

### Structs

```cesium
struct Point {
  f64 x = 0.0;
  f64 y = 0.0;
}
```

### Enums

```cesium
// Enums with custom backing types
enum Status { OK; ERROR; PENDING; }
enum i16 ImportantYears { Y2K = 2000; TWO_BC = -1; }
```

### Error Types

```cesium
error FileNotFound {
  str path;
  i32 errno;
}
```

### Union Types

```cesium
union Number = i32|f64;
union FileErrors = AccessDenied|FileNotFound;
```

## Type Conversion Rules

### Implicit Promotions

```cesium
// Implicit promotions
i32 x = 42;
i34 y = x; // widening of same numeric class
f32 z = x;
f64 bigz = x; // int-to-float + widening

u32 a = 96;
u64 b = a; // widening of same numeric class
f64 c = a; // int-to-float + widening

f128 d = c; // widening of same numeric class
```

### Explicit Conversions

```cesium
// Explicit conversions for narrowing
f64 pi = 3.14159;
i32 truncated = trunc(pi);  // use rounding functions

// Bit reinterpretation
u32 bits = 0x3F800000;
f32 float_val = bits as f32;

// Context-driven literal typing
u8 small = 255;      // 255 becomes u8
i16 medium = 255;    // 255 becomes i16
```

## Arithmetic Semantics

Integer arithmetic has no undefined behavior. Integer `+`, `-`, `*` and negation wrap (two's complement). Shifts by more than the operand width, division and remainder by zero, the signed minimum divided by -1, and out-of-range float-to-integer conversions each have one defined result on every target. This mirrors the compiler's middle IR, where both backends must give every program the same meaning ([cesiumlang/cesium#7](https://github.com/cesiumlang/cesium/issues/7), [cesiumlang/cesium#8](https://github.com/cesiumlang/cesium/issues/8)).

> [!question] Open
> Which defined result applies to division by zero and over-wide shifts (a trap or a value) is open question 3 of [cesiumlang/cesium#8](https://github.com/cesiumlang/cesium/issues/8). Integer division rounding, `%` on negative numbers, `^` and roots on integers, and floating-point policy are [cesiumlang/cesium#35](https://github.com/cesiumlang/cesium/issues/35).

## Rules from the Original Design

These rules were set in the September 2025 design sessions and are recorded in [cesiumlang/cesium#16](https://github.com/cesiumlang/cesium/issues/16). They are listed here so the page is complete. Several are being re-examined by the design audit, noted next to each group.

**Integers and conversions** (under review: [cesiumlang/cesium#33](https://github.com/cesiumlang/cesium/issues/33), [cesiumlang/cesium#34](https://github.com/cesiumlang/cesium/issues/34))

- Mixed signed and unsigned arithmetic is allowed; the result is cast to the type of the destination (`u8 k = i + j` behaves as `i + (j as u8)`).
- Mixed signed and unsigned *comparison* is mathematically correct, not a bit reinterpretation: a `u32` holding 3,000,000,000 compares greater than an `i32` holding 10, and any negative value is less than any unsigned value.
- `as` is bit reinterpretation only. A `#void` to `#T` conversion is spelled `q as #T`.
- Promotions apply to function arguments the same way as to assignments.

**Literals** (under review: [cesiumlang/cesium#56](https://github.com/cesiumlang/cesium/issues/56))

- There are no type suffixes. A literal takes its type from context; use `as` to force one.

**Enums**

- Values must be qualified (`Status.OK`). A bare `OK` is an error unless aliased (`alias OK = Status.OK;`).
- With no backing type, the smallest type that fits is used, preferring unsigned. Float-backed enums are allowed and need explicit values.
- Enums decay to their numeric type, and a numeric value may be passed where an enum is expected, but one enum never converts to another.

**Arrays, slices and strings** (under review: [cesiumlang/cesium#36](https://github.com/cesiumlang/cesium/issues/36), [cesiumlang/cesium#39](https://github.com/cesiumlang/cesium/issues/39), [cesiumlang/cesium#44](https://github.com/cesiumlang/cesium/issues/44))

- Arrays do not decay to pointers; a pointer must be set to an explicit element.
- Arrays have a built-in `.len`. Primitives have no methods.
- Negative indices count from the end, only for arrays and slices with known bounds. Raw pointer indexing is plain address arithmetic.
- Ranges are also slices: `arr[0..5]`, `arr[0..=5]`, `arr[0..2..=8]`.
- `str` is a built-in class, not a primitive: UTF-8, NUL-terminated internally with a tracked length, raw bytes through `.u8`.
- `list[T]` and `dict[K,V]` own and manage their memory.
- Function pointer types are written `#(i32, f64) name`.

> [!question] Open
> Not settled, and so not stated above: the type of a literal with no context and what happens when a literal does not fit; the spelling of array parameters (`f64 values[]` on this page, `str[] file_paths` on the error-handling page); the `vector[3]` and `matrix[3,3]` types used on the operators page, which are never defined ([cesiumlang/cesium#36](https://github.com/cesiumlang/cesium/issues/36)); whether there should be a boolean type ([cesiumlang/cesium#38](https://github.com/cesiumlang/cesium/issues/38)); and how to convert between integer widths ([cesiumlang/cesium#34](https://github.com/cesiumlang/cesium/issues/34)).
