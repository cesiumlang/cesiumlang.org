---
title: "Operators and Expressions"
tags: ["operators", "expressions", "precedence", "arithmetic"]
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
```

### 4. Unary Prefix Operators

```cesium
addr = #variable;         // address-of
value = #pointer;         // dereference (auto in most contexts)
root = ::x;              // square root
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
x = 42;
owned := create_value();
```

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

```cesium
i32 value = 42;
#i32 ptr = #value;              // address-of

// Default dereference - ptr automatically dereferenced
i32 copy = ptr;                 // gets value at ptr

// Address context for pointer arithmetic
#i32 incremented = ptr #+ 1;    // pointer arithmetic
i32 offset_value = (ptr #+ 2);  // value context within pointer context

// Explicit address context forcing
result = addrcontext(ptr) + offset;  // force address interpretation
```
