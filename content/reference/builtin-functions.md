---
title: "Built-in Functions"
tags: ["builtin", "functions", "io", "math", "introspection"]
sortorder: 12
---

> [!question] Open
> Much of this page was generated with the first draft of the reference and has no recorded decision behind it. Which of these functions and constants exist, which names are reserved and which can be shadowed, and how this page relates to the list in [[lexical-structure|Lexical Structure]] is being decided in [cesiumlang/cesium#20](https://github.com/cesiumlang/cesium/issues/20). Treat everything here except the allocation section as unconfirmed. Specific doubts: `typeof` returning a `str`; the C-style `strlen` / `strcmp` / `strcat` / `strcpy` (when `str` tracks its length and `**` concatenates); `move` as a memory function; and `copy`, `zero`, `compare`, `getenv`, `system`, `exit`, `e`, `sqrt2`, `ln2`, `POINTER_SIZE`, `TARGET_OS` and `TARGET_ARCH`, of which only `copy` was ever discussed.

## I/O Functions

### Formatted Output

```cesium
// Formatted output
printf("Hello, {}!\n", name);                    // stdout
printf(stderr, "Error: {}\n", error_message);    // explicit stream
debugf("Debug info: value = {}\n", debug_value); // stderr shortcut

// Standard streams
file output = stdout;
file input = stdin;
file errors = stderr;
```

## Mathematical Functions

### Trigonometric Functions

```cesium
// Trigonometric functions (built-in, shadowable)
f64 angle = 1.57;
f64 sine = sin(angle);
f64 cosine = cos(angle);
f64 tangent = tan(angle);
```

### Rounding Functions

```cesium
// Rounding functions (required for float->int conversion)
f64 value = 3.7;
i32 down = floor(value);    // 3
i32 up = ceil(value);       // 4
i32 nearest = round(value); // 4
i32 toward_zero = trunc(value); // 3
```

### Root Functions

```cesium
// Root functions (also available as operators)
f64 square_root = sqrt(25.0);  // or ::25.0
f64 cube_root = cbrt(27.0);    // or 3::27.0
```

## Type Introspection

### Type and Size Information

```cesium
// Type and size information
uword int_size = sizeof(i32);           // 4
uword array_size = sizeof(numbers);     // total array size in bytes
str type_name = typeof(variable);       // "i32", "Vector3", etc.

// Usage in generic functions
generic<T> void = print_type_info(T value) {
  printf("Type: {}, Size: {} bytes\n", typeof(value), sizeof(T));
}
```

## Assertion and Debugging

### Runtime Assertions

```cesium
// Runtime assertions
void = validate_input(i32 value) {
  assert(value >= 0);  // program terminates if false
  assert(value < MAX_VALUE, "Value too large: {}", value);
}
```

### Compile-time Assertions

```cesium
// Compile-time assertions
comptime {
  assert(sizeof(i32) == 4);  // verified at compile time
}
```

## Memory Management Functions

### Basic Allocation

```cesium
// alloc takes an element count; the element type comes from the pointer being initialized
~i32 numbers := alloc(100);             // owner of 100 i32s
~f64 zeros := alloc(50, 0.0);           // allocate and initialize

// free runs the type's destruct, releases the memory and resets the pointer to undefined
free(numbers);
free(zeros);
```

`alloc` returns ownership, so its result is received with `:=`. Only the owner may `free`; `free` on a `null` or `undefined` pointer is a no-op. See [[memory-management|Memory Management]].

> [!question] Open
> How `realloc` is typed under the ownership rules, and what `alloc` does on failure, are not decided ([cesiumlang/cesium#17](https://github.com/cesiumlang/cesium/issues/17); open question 12 of [cesiumlang/cesium#11](https://github.com/cesiumlang/cesium/issues/11)).

### Memory Operations

```cesium
// Memory manipulation
void = copy(#void dest, #void src, uword size);    // copy memory
void = move(#void dest, #void src, uword size);    // move memory (overlap-safe)
void = zero(#void ptr, uword size);                // zero memory
i32 = compare(#void a, #void b, uword size);       // compare memory
```

## String Functions

### String Operations

```cesium
// String manipulation (when std.string is not used)
uword = strlen(str s);                  // string length
i32 = strcmp(str a, str b);             // string comparison
str = strcat(str dest, str src);        // string concatenation
str = strcpy(str dest, str src);        // string copy
```

## Aggregate Functions

### Statistical Functions

```cesium
// Statistical operations on arrays
generic<numeric T> T = min(slice[T] values);
generic<numeric T> T = max(slice[T] values);
generic<numeric T> T = sum(slice[T] values);
generic<numeric T> f64 = mean(slice[T] values);
generic<numeric T> f64 = norm(slice[T] values);
```

## System Functions

### Environment Access

```cesium
// Environment and system information
str = getenv(str name);                 // get environment variable
i32 = system(str command);              // execute system command
void = exit(i32 code);                  // terminate program
```

## Built-in Constants

### Mathematical Constants

```cesium
const f64 pi = 3.141592653589793;
const f64 e = 2.718281828459045;
const f64 sqrt2 = 1.414213562373095;
const f64 ln2 = 0.693147180559945;
```

### System Constants

```cesium
const uword POINTER_SIZE = sizeof(#void);
const str TARGET_OS = "linux";    // or "windows", "macos", etc.
const str TARGET_ARCH = "x86_64"; // or "arm64", etc.
```
