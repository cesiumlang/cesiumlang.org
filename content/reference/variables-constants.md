---
title: "Variables and Constants"
tags: ["variables", "constants", "qualifiers", "ownership"]
---

## Variable Declaration

### Basic Declaration

```cesium
// Basic declaration with no initialization
u8 x;

// Basic declaration with initialization
i32 count = 0;
f64 pi = 3.14159;
```

### Constant Variables

```cesium
// Constant variables
const i32 MAX_SIZE = 1000;
const str VERSION = "1.0.0";
```

### Ownership Assignment

```cesium
// Ownership assignment
Matrix m_owned := create_matrix();  // takes ownership
Matrix m_copy = owned;              // error - cannot copy owned value
Matrix m_moved := owned;      // explicit ownership transfer
```

The `:=` operator indicates ownership transfer, while `=` is used for copying or borrowing depending on context.

## Qualifiers

### Storage and Access Qualifiers

```cesium
// Storage and access qualifiers
static i32 global_counter = 0;    // function-scoped persistence
private void = helper();          // module-internal function
secret i32 internal_state;       // class-internal only
```

### Hardware Qualifiers

```cesium
// Hardware qualifiers
volatile u32 hardware_register;   // prevent optimization
atomic u64 shared_counter;        // thread-safe operations
register u64 hot_variable;        // register allocation hint
```

## Qualifier Descriptions

| Qualifier | Description |
|-----------|-------------|
| `const` | Value cannot be modified after initialization |
| `static` | Variable persists between function calls |
| `private` | Accessible only within the current module |
| `secret` | Accessible only within the current class/struct |
| `volatile` | Prevents compiler optimizations |
| `atomic` | Ensures thread-safe operations |
| `register` | Suggests register allocation |
| `simd` | Enables SIMD vectorization |

## Ownership Semantics

- **Owned values** (`:=`) - The variable takes full ownership
- **Borrowed values** (`#=`) - The variable borrows a reference
- **Copied values** (`=`) - The variable gets a copy (if type supports copying)

```cesium
Matrix original := create_matrix();
Matrix moved := original;           // ownership transferred
#Matrix borrowed #= moved;         // immutable borrow
~Matrix mut_borrowed #= moved;     // mutable borrow
```
