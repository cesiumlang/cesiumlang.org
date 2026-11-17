---
title: "Operators and Expressions"
tags: ["operators", "expressions", "precedence", "arithmetic"]
sortorder: 5
---

## Operator Precedence (highest to lowest)

### 1. Primary Expressions

```cesium
result = func(a, b);      // function call
element = array[index];   // indexing
member = obj.field;       // member access
```

### 2. Custom Unary Operators

```cesium
result = $negate$x;       // custom unary operator
```

### 3. Postfix Operators

```cesium
transposed = matrix~;     // matrix transpose
result = value..;         // unary postfix range/spread operator
```

### 4. Unary Prefix Operators

```cesium
addr #= #variable;        // address-of (immutable)
waddr ~= ~variable;       // address-of (mutable)
root = ::x;              // square root
result = ..array;        // unary prefix range/spread operator
```

### 5. Binary Root Operator

```cesium
cube_root = 3::27;       // nth root
```

### 6. Exponentiation (right-associative)

```cesium
power = base^exponent;
```

### 7. Multiplicative

```cesium
product = a * b;         // context-aware multiplication
quotient = a / b;
remainder = a % b;
cross = vec1 @ vec2;     // cross product
```

### 8. String Concatenation

```cesium
message = "Hello" ** " " ** "World";
```

### 9. Additive

```cesium
sum = a + b;
difference = a - b;
```

### 10. Bit Shifts

```cesium
shifted = value << 2;
shifted = value >> 1;
```

### 11. Comparison Operators

```cesium
less = a < b;
greater = a > b;
less_equal = a <= b;
greater_equal = a >= b;
```

### 12. Equality Operators

```cesium
equal = a == b;
not_equal = a != b;
```

### 13. Bitwise AND

```cesium
masked = value & 0xFF;
```

### 14. Bitwise XOR

```cesium
flipped = a >< b;
```

### 15. Bitwise OR

```cesium
combined = flags | new_flag;
```

### 16. Logical AND

```cesium
result = condition1 && condition2;
```

### 17. Logical OR

```cesium
result = condition1 || condition2;
```

### 18. Custom Binary Operators

```cesium
result = a $dot$ b;      // custom binary operator
```

### 19. Assignment

```cesium
x = 42;                             // assign a value (through the pointer, if x is one)
#i32 reader #= #x;                  // immutable borrow: set the address
~i32 writer ~= ~y;                  // mutable borrow: set the address
~Matrix owned := create_matrix();   // take ownership: set the address
```

`#=`, `~=` and `:=` are the *address-context* assignment operators. They are only meaningful with a pointer on the left. See [[memory-management|Memory Management]].

> [!question] Open
> This table is incomplete. Unary `-`, `+` and `!`, a bitwise NOT, `++` / `--`, the compound assignments (`+=` and the rest), the ternary `?:`, the comma operator, elementwise multiplication and the meaning of unary `..` are all used somewhere in the reference or were part of the original design, but have no agreed place in the table. They are being settled in [cesiumlang/cesium#15](https://github.com/cesiumlang/cesium/issues/15); the clash between decorated operators and postfix `~` is [cesiumlang/cesium#28](https://github.com/cesiumlang/cesium/issues/28).

## Context-Aware Multiplication

Cesium's multiplication operator (`*`) behaves differently based on the types of its operands:

```cesium
// Scalar multiplication
f64 scalar = 2.0;
f64 result = scalar * 3.14;

// Vector operations
vector[3] v1, v2;
f64 dot_product = v1 * v2;      // dot product
vector[3] cross_product = v1 @ v2;  // cross product

// Matrix operations
matrix[3,3] A, B;
matrix[3,3] C = A * B;          // matrix multiplication
vector[3] v = A * v1;           // matrix-vector multiplication

// Mixed operations
vector[3] scaled = 2.0 * v1;    // scalar-vector multiplication
```

## Bitwise Operations

Cesium uses `><` for XOR to distinguish it clearly from other operations:

```cesium
u32 flags = 0b11110000;
u32 mask = 0b00001111;

u32 masked = flags & mask;        // bitwise AND
u32 flipped = flags >< 0b11111111; // bitwise XOR (toggle bits)
u32 combined = flags | mask;       // bitwise OR
u32 shifted_left = flags << 2;     // left shift
u32 shifted_right = flags >> 2;    // right shift

// XOR for encryption/decryption
u8 data = 0x42;
u8 key = 0x5A;
u8 encrypted = data >< key;        // encrypt
u8 decrypted = encrypted >< key;   // decrypt (data == decrypted)
```

## Pointer Operations and Contexts

Address space and data space are separate, and the rule is not to mix them.

- **Data context (the default).** A pointer used with ordinary operators is dereferenced automatically. There is no dereference operator. `a + p` with a pointer `p` reads the value `p` points to and yields a number; assigning that number to a pointer-typed variable is a compile error.
- **Address context.** The address-context assignments (`#=`, `~=`, `:=`) and the *decorated* operators work on the address itself. Ordinary operators never do address arithmetic.

```cesium
i32 value = 42;
#i32 ptr #= #value;             // address-of a plain value

// Default dereference: ptr is automatically dereferenced
i32 copy = ptr;                 // gets the value at ptr
i32 doubled = ptr + ptr;        // ordinary arithmetic on the value: 84
```

### Decorated Operators

Address arithmetic uses operators decorated with the pointer's sigil. There are two families: `#`-decorated (such as `#+`) and `~`-decorated (such as `~+`), including in-place forms such as `p#++`. They are only valid in a pointer context; both kinds of borrow are pointer contexts.

```cesium
i32 samples[8];

#i32 p #= #samples[0];
#i32 third #= p #+ 2;           // address arithmetic in an immutable borrow
p#++;                           // step p to the next element in place

~i32 w ~= ~samples[0];
w ~= w ~+ 1;                    // advancing a mutable borrow borrows the new address
w = 7;                          // data context: writes samples[1]
```

- Arrays do not decay to pointers: a pointer is set to an explicit element, and `#q[i]` means `#(q[i])`.
- Advancing a mutable borrow is a request to borrow the new address.
- The result of a `~`-decorated operation may be assigned to an immutable (`#T`) pointer, because the receiver is more restrictive.

> [!question] Open
> The full list of decorated operators, the spelling of prefix increment, the rule that parentheses open a value context inside an address context, and `addrcontext()` come from the September 2025 design and have not been reconciled with the rules above. See item 6 of [cesiumlang/cesium#15](https://github.com/cesiumlang/cesium/issues/15). Whether the result of a `#`-decorated operation may go into a `~T` pointer was assumed to be an error but not confirmed ([cesiumlang/cesium#12](https://github.com/cesiumlang/cesium/issues/12), round 5).
