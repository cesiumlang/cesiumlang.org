---
title: "Functions"
tags: ["functions", "generics", "overloading", "variadics"]
---

## Function Declaration

### Basic Functions

```cesium
// Basic function
i32 = add(i32 a, i32 b) {
    return a + b;
}

// Multiple return values
i32, f64 = divide_with_remainder(i32 dividend, i32 divisor) {
    return dividend / divisor, dividend % divisor;
}

// No return value
void = print_message(str message) {
    printf("{}\n", message);
}
```

### Functions with Ownership

```cesium
// Function with ownership/borrowing
void = process_data(~Matrix data) {      // takes mutable borrow
    // can modify data in-place
    data.transpose();
}

Matrix = create_matrix(i32 rows, i32 cols) {
    Matrix result := alloc_matrix(rows, cols);  // returns owned value
    return result;
}
```

## Function Qualifiers

```cesium
struct Calculator {
    private f64 last_result;

    // Static method (no 'this' parameter)
    static Calculator = create() {
        return Calculator { last_result = 0.0 };
    }

    // Private method (module internal)
    private void = validate_input(f64 value) {
        assert(value >= 0.0);
    }

    // Secret method (class internal only)
    secret void = internal_operation() {
        // implementation details
    }
}
```

## Generic Functions

### Basic Generics

```cesium
// Basic generic function
generic<T> T = max(T a, T b) {
    return a > b ? a : b;
}

// Generic with trait constraints
generic<numeric T> T = dot_product(slice[T] a, slice[T] b) {
    assert(a.len == b.len);
    T sum = 0;
    for (uword i = 0..a.len) {
        sum += a[i] * b[i];
    }
    return sum;
}
```

### Multiple Type Parameters

```cesium
// Multiple type parameters
generic<K, V> V = dict_get(dict[K,V] d, K key, V default_value) {
    // implementation
}

// Usage
f64 result = max(3.14, 2.71);           // T inferred as f64
i32 larger = max<i32>(10, 20);          // explicit type
```

## Variadic Functions

### Type-Safe Variadics

```cesium
// Cesium-style variadics (type-safe, becomes slice)
void = print_numbers(...i32 numbers) {
    for (uword i = 0..numbers.len) {
        printf("{} ", numbers[i]);
    }
    printf("\n");
}

// Usage
print_numbers(1, 2, 3, 4, 5);
```

### C-Style Variadics

```cesium
// C-style variadics (for extern functions only)
extern libc = import('c') {
    i32 = printf(str fmt, ...);
}
```

## Operator Overloading

### Built-in Operator Overloading

```cesium
// Built-in operator overloading
struct Vector3 {
    f64 x, y, z;

    // Overload addition operator
    Vector3 = operator +(Vector3 other) {
        return Vector3 {
            x = this.x + other.x,
            y = this.y + other.y,
            z = this.z + other.z
        };
    }

    // Overload multiplication for dot product
    f64 = operator *(Vector3 other) {
        return this.x * other.x + this.y * other.y + this.z * other.z;
    }
}
```

### Custom Operators

```cesium
// Custom operator definition
Vector3 = operator $cross$(Vector3 a, Vector3 b) {
    return Vector3 {
        x = a.y * b.z - a.z * b.y,
        y = a.z * b.x - a.x * b.z,
        z = a.x * b.y - a.y * b.x
    };
}

// Usage
Vector3 a, b, result;
result = a + b;          // uses overloaded +
f64 dot = a * b;         // uses overloaded *
Vector3 cross = a $cross$ b;  // uses custom operator
```

## Function Syntax Summary

- Return type comes before the `=` sign
- Multiple return types are comma-separated
- `void` indicates no return value
- Parameters can have ownership qualifiers (`#`, `~`)
- Generic parameters use angle brackets: `<T>`
- Variadic parameters use ellipsis: `...Type name`
