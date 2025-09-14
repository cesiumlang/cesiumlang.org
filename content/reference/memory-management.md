---
title: "Memory Management"
tags: ["memory", "ownership", "allocation", "defer"]
---

## Basic Memory Operations

### Allocation and Deallocation

```cesium
// Allocation and deallocation
#i32 numbers = alloc(100);        // allocate array of 100 i32s
#f64 zeros = alloc(50, 0.0);      // allocate and initialize
free(numbers);                    // deallocate

// Reallocation (expand or relocate existing allocation)
numbers = realloc(numbers, 200);  // expand or move allocation
if (numbers == null) {
    // realloc failed, original memory still valid
}

// Memory copying
copy(destination, source, count); // built-in memory copy
```

## Automatic Resource Management

### Defer Statements

```cesium
// Defer statements (execute at function return)
void = process_file(str filename) {
    #u8 buffer = alloc(1024);
    defer free(buffer);           // executed when function returns

    if (some_condition) {
        return;  // defer executes here
    }

    // defer also executes at normal function end
}

// Defer with blocks
void = complex_processing() {
    defer {
        cleanup_temp_files();
        reset_global_state();
    };

    // multiple operations deferred together
}
```

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
        data = read_all(f);
        process_config(data);
        // file automatically closed on exit
    } catch (err) {
        case (FileNotFound) {
            printf("Config file not found\n");
        }
    }
}
```

## Ownership and Borrowing

### Ownership Transfer

```cesium
// Ownership transfer
Matrix = create_identity(i32 size) {
    Matrix result := allocate_matrix(size, size);  // owned
    // ... initialize
    return result;  // ownership transferred to caller
}
```

### Borrowing for Access

```cesium
// Borrowing for read-only access
f64 = calculate_determinant(#Matrix m) {
    // can read m, cannot modify
    // caller retains ownership
}

// Mutable borrowing for in-place operations
void = transpose_inplace(~Matrix m) {
    // exclusive access to modify m
    // caller retains ownership after function returns
}
```

### Usage Example

```cesium
Matrix mat := create_identity(3);           // takes ownership
f64 det = calculate_determinant(#mat);      // lends for reading
transpose_inplace(~mat);                    // lends for modification
// mat still owned and valid here
```

## Memory Safety Rules

1. **Ownership Transfer**: Use `:=` to transfer ownership
2. **Borrowing**: Use `#=` for immutable borrows, `~=` for mutable borrows
3. **No Use After Move**: Cannot access moved values
4. **Exclusive Mutable Access**: Only one mutable borrow at a time
5. **Automatic Cleanup**: `defer` statements ensure resource cleanup
