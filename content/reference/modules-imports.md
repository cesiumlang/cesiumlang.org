---
title: "Modules and Imports"
tags: ["modules", "imports", "namespaces", "extern"]
sortorder: 11
---

## Module Structure

### Basic Module Definition

```cesium
// File: math/vector.csm
namespace math.vector;

// Public interface
struct Vector3 {
  f64 x, y, z;

  Vector3 = operator +(Vector3 other) {
    return Vector3 { x + other.x, y + other.y, z + other.z };
  }
}

f64 = magnitude(Vector3 v) {
  return ::(v.x^2 + v.y^2 + v.z^2);
}

// Private helper function
private f64 = square(f64 x) {
  return x * x;
}
```

## Import Syntax

### Basic Imports

```cesium
// Import entire modules
import(math.vector);
import(std.io) as io;
```

### Selective Imports

```cesium
// Selective imports
import(math.matrix) { Matrix; multiply as mat_mult; invert };
import(graphics.primitives) {
  Circle;
  Rectangle as Rect;
  export Triangle;  // import as global name
}
```

### Using Imported Functions

```cesium
// Using imported functions
Vector3 v1, v2;
Vector3 sum = math.vector.add(v1, v2);
Matrix m = mat_mult(matrix1, matrix2);
Triangle tri;  // globally available due to 'export'
```

## External Library Integration

### C Library Imports

```cesium
// Import C libraries
extern libc = import('c') {
  i32 = printf(str fmt, ...);
  #void = malloc(uword size) as malloc;  // global alias
  export void = free(#void ptr);         // import as global
}

extern math_lib = import('m') {
  f64 = sin(f64 x);
  f64 = cos(f64 x);
  f64 = sqrt(f64 x) as sqrt;
}
```

### Platform-Specific Imports

```cesium
// Platform-specific imports
extern windows = import('kernel32') {
  i32 = GetCurrentProcessId();
  void = Sleep(u32 milliseconds);
}

extern posix = import('unistd') {
  i32 = getpid();
  i32 = sleep(u32 seconds);
}

// Usage
void = cross_platform_delay(u32 ms) {
  comptime {
    if (target_os == "windows") {
      windows.Sleep(ms);
    } else {
      posix.sleep(ms / 1000);
    }
  }
}
```

## Module Interface Files

Module interface files use the `.csi` extension. They exist so that a closed-source Cesium library can be imported without `extern`.

### Interface Definition

```cesium
// math_vector.csi (module interface file)
namespace math.vector;

// Public type declarations
struct Vector3 {
  f64 x, y, z;
  // method signatures without implementation
  Vector3 = operator +(Vector3 other);
}

// Public function signatures
f64 = magnitude(Vector3 v);
Vector3 = normalize(Vector3 v);
Vector3 = cross_product(Vector3 a, Vector3 b);
```

## Import Variants

### Import Styles

| Syntax | Effect | Example Usage |
| --- | --- | --- |
| `import(module)` | Import with full namespace | `module.function()` |
| `import(module) as alias` | Import with custom namespace | `alias.function()` |
| `import(module) { item }` | Selective import | `item()` |
| `import(module) { item as name }` | Selective import with rename | `name()` |
| `import(module) { export item }` | Import as global | `item()` |

## Standard Library Modules

### Core Modules

```cesium
std.builtin    // Built-in functions when shadowed
std.memory     // Advanced memory management (allocators, arenas)
std.math       // Extended mathematical functions
std.string     // String manipulation utilities
std.collections // Advanced container types
std.io         // File and stream I/O
std.os         // Operating system interfaces
std.thread     // Concurrency primitives
std.simd       // SIMD intrinsics and utilities
```

### Example Usage

```cesium
// Using standard library containers
import(std.collections) { HashMap; ArrayList }

HashMap[str, i32] word_count;
ArrayList[str] lines;

// Advanced memory management
import(std.memory) { ArenaAllocator; PoolAllocator }

ArenaAllocator arena;
#f64 temp_data = arena.alloc(1000);
// arena automatically frees all allocations when destroyed

// Extended math functions
import(std.math) { pow; log; exp }

f64 result = pow(base, exponent);
f64 natural_log = log(value);
```

## Rules from the Original Design

These rules were set in the September 2025 design sessions and are recorded in [cesiumlang/cesium#19](https://github.com/cesiumlang/cesium/issues/19). The compilation model behind them is being re-examined in [cesiumlang/cesium#47](https://github.com/cesiumlang/cesium/issues/47).

- **No transitive imports.** A name is only reachable from the module that defines it.
- A namespace name that collides with any other identifier is a compile error; alias the namespace to resolve it.
- Namespaces are not tied to file paths.
- A namespace or a sub-namespace can be imported; selective imports are preferred.
- `alias` can be used anywhere to rename things: functions, parameters, enum values, types.
- Circular dependencies are resolved by compile order across the files in a namespace.
- Generating a C header for exported functions is an opt-in compiler flag.

> [!question] Open
> Several things on this page are not settled and are tracked in [cesiumlang/cesium#19](https://github.com/cesiumlang/cesium/issues/19): the alias form (`import(std.io) as io;` here, against the assignment form `io = import(std.io)` in the original design), where semicolons go in import blocks, which `std.*` modules are available without an import, whether `HashMap` / `ArrayList` and the allocator types exist, and the single-quoted library names. Known problems in the examples: `math.vector.add` is called but never defined, `'unistd'` is a header and not a library, and `target_os` is spelled `TARGET_OS` on the built-in functions page. The `ArenaAllocator` example also initializes a pointer with plain `=`, which the ownership rules do not allow ([Memory Management](memory-management.md)); it is left as it is until the allocator types are decided.

## Module Organization Best Practices

1. **Use descriptive namespaces**: `graphics.primitives` rather than `gfx.p`
2. **Keep interfaces minimal**: Only export what's necessary
3. **Group related functionality**: Put related types and functions together
4. **Use module interface files**: For large modules, provide `.csi` files
5. **Avoid circular dependencies**: Structure modules hierarchically
