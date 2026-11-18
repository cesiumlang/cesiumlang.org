---
title: "Functions"
tags: ["functions", "generics", "overloading", "variadics"]
sortorder: 7
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

Pointer parameters and return values say whether they borrow or own. A leading `:` marks ownership; without it the pointer is a borrow.

```cesium
// Borrows: the caller keeps ownership
f64 = determinant(#Matrix m) { ... }        // immutable borrow: can read m
void = scale_inplace(~Matrix m, f64 k) {    // mutable borrow: can modify m
  // modify m in place
}

// Returns ownership of a new Matrix to the caller
:~Matrix = create_matrix(i32 rows, i32 cols) {
  ~Matrix result := alloc(1);
  // ... initialize ...
  return result;                            // ownership leaves with the return value
}

// Takes ownership of its argument
void = consume(:#Matrix m) {
  free(m);
}

// Returns a borrow: it must derive from a parameter or a global
#f64 = first_element(#Matrix m) { ... }
```

At the call site a pointer is passed bare, and a plain value has its address taken explicitly with `#` (for a `#T` parameter) or `~` (for a `~T` parameter):

```cesium
~Matrix a := create_matrix(3, 3);
f64 d = determinant(a);          // a is a pointer: passed bare (~ to # is allowed)
scale_inplace(a, 2.0);
consume(a);                      // ownership moves into consume; a cannot be used afterwards

Matrix v;                        // plain value
f64 dv = determinant(#v);        // address taken explicitly
scale_inplace(~v, 2.0);
// determinant(v);               // error: a plain value is not passed implicitly
```

Owned return values are marked one by one, so mixed returns work: `:~Matrix, u8 = try_invert(#Matrix m) { ... }`. See [[memory-management|Memory Management]] for the full rules.

### Read-Only Methods

Inside a struct, an unprefixed method takes `this` as a mutable borrow and so cannot be called through a `#` pointer. A read-only method is declared with `#` before its name:

```cesium
struct Point {
  f64 x, y;

  f64 = #distance_from_origin() {   // read-only: can be called through a #Point
    return ::(x^2 + y^2);
  }

  void = translate(f64 dx, f64 dy) { // mutable this: cannot be called through a #Point
    x += dx;
    y += dy;
  }
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

## Rules from the Original Design

These rules were set in the September 2025 design sessions and are recorded in [cesiumlang/cesium#18](https://github.com/cesiumlang/cesium/issues/18). Some are being re-examined by the design audit ([cesiumlang/cesium#33](https://github.com/cesiumlang/cesium/issues/33), [cesiumlang/cesium#46](https://github.com/cesiumlang/cesium/issues/46)).

- **Overloading** uses compile-time multiple dispatch: an exact type match first, then promotions; the most specific overload wins; ambiguity is a compile error. Operators are sugar for functions.
- **No prototypes or forward declarations.** Declaration order does not matter.
- **Variadics:** C-style `...` is allowed only in `extern` import blocks and is a compile error elsewhere. A Cesium-style variadic that is `export`ed gets a generated C-compatible wrapper.
- **Operator overloading** is limited to the predefined operators and `$name$` operators. New symbol sequences cannot be invented.
- **Function qualifiers:** `operator`, `context`, `property`, `static`, `private`, `secret`, `destruct`.

> [!question] Open
> The form `T = name(params) {` cannot always be told apart from an assignment ([cesiumlang/cesium#27](https://github.com/cesiumlang/cesium/issues/27)), angle-bracket generics collide with comparison operators ([cesiumlang/cesium#29](https://github.com/cesiumlang/cesium/issues/29)), the ternary operator used on this page has no precedence level yet ([cesiumlang/cesium#15](https://github.com/cesiumlang/cesium/issues/15)), and there is no example of receiving multiple return values because that syntax has not been written down ([cesiumlang/cesium#18](https://github.com/cesiumlang/cesium/issues/18)). The generic `max` example on this page also shares its name with the built-in `max` over slices ([cesiumlang/cesium#20](https://github.com/cesiumlang/cesium/issues/20)).

## Function Syntax Summary

- Return type comes before the `=` sign
- Multiple return types are comma-separated
- `void` indicates no return value
- `#T` and `~T` parameters borrow (read-only and read-write); `:#T` and `:~T` parameters take ownership
- `:#T` and `:~T` return values hand ownership to the caller; plain `#T` and `~T` return values are borrows
- A method declared with `#` before its name (`T = #name() { ... }`) is read-only; other methods take a mutable `this`
- Generic parameters use angle brackets: `<T>`
- Variadic parameters use ellipsis: `...Type name`
