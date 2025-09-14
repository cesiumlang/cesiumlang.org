---
title: "Type System"
tags: ["types", "primitives", "arrays", "pointers", "simd"]
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

```cesium
#i32 int_ptr;         // immutable pointer to i32
##i32 ptr_to_ptr;     // immutable pointer to immutable pointer to i32
~#i32 mut_ptr_to_ptr; // mutable pointer to immutable pointer to i32
#~i32 ptr_to_mut_ptr; // immutable pointer to mutable pointer to i32

// Ownership and borrowing
#Matrix m := create_matrix();     // owned value
#Matrix borrowed_m #= m;         // immutable borrow
~Matrix mutable_m #= m;          // mutable borrow
```

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
