---
title: "Error Handling"
tags: ["errors", "exceptions", "error-types", "catch"]
---

## Error Type Definition

### Defining Error Types

```cesium
// Define error types
error FileNotFound {
    str path;
    i32 errno;
}

error AccessDenied {
    str message;
    i32 permission_level;
}

error NetworkTimeout {
    str host;
    i32 timeout_ms;
}
```

### Error Union Types

```cesium
// Error union types
alias FileError = FileNotFound|AccessDenied;
alias IOError = FileError|NetworkTimeout;
```

## Error Propagation Methods

### Returning Errors

```cesium
// Return errors (exits function immediately)
FileError|file = open_file(str path) {
    if (!file_exists(path)) {
        return FileNotFound { path = path, errno = 2 };
    }
    if (!has_permission(path)) {
        return AccessDenied { message = "Read permission denied", permission_level = 0 };
    }

    file handle = create_file_handle(path);
    return handle;  // success case
}
```

### Throwing Errors

```cesium
// Throw errors (continues execution, collected for later handling)
void = batch_process_files(str[] file_paths) {
    for (str path = file_paths) {
        if (!validate_path(path)) {
            throw FileNotFound { path = path, errno = 404 };
            continue;  // process remaining files
        }

        if (!check_permissions(path)) {
            throw AccessDenied { message = "Cannot access file", permission_level = 1 };
            continue;
        }

        process_single_file(path);
    }
    // All thrown errors handled by catch after function completes
}
```

## Error Handling with Catch

### Basic Error Catching

```cesium
// Basic error catching
file_or_error = open_file("data.txt");
file_or_error catch {
    printf("Failed to open file\n");
}
```

### Pattern Matching on Errors

```cesium
// Pattern matching on error types
file_or_error catch (err) {
    case (FileNotFound) {
        printf("File not found: {}\n", err.path);
        create_default_file(err.path);
    }
    case (AccessDenied) {
        printf("Access denied: {}\n", err.message);
        request_elevated_permissions();
    }
}
```

### Multiple Error Types

```cesium
// Multiple error types
file_or_error catch (err) {
    case (FileNotFound|AccessDenied) {
        printf("File access error: cannot open file\n");
    }
    case (NetworkTimeout) {
        printf("Network timeout accessing {}\n", err.host);
    }
    else {
        printf("Unknown error occurred\n");
    }
}
```

### Catching Thrown Errors

```cesium
// Catching thrown errors from batch operations
batch_process_files(file_list) catch (err) {
    case (FileNotFound) {
        printf("Skipped missing file: {}\n", err.path);
    }
    case (AccessDenied) {
        printf("Permission denied for file\n");
    }
}
```

## Error Handling with Context Managers

```cesium
// Combining with resource management
with f = file("data.txt", "r") {
    data = read_all(f);
    result = process_data(data);
    return result;
} catch (err) {
    case (FileNotFound) {
        printf("Input file missing\n");
        return default_result();
    }
    case (AccessDenied) {
        printf("Cannot read input file\n");
        return error_result();
    }
}
// file automatically closed even if errors occur
```

## Error Handling Strategies

1. **Return Errors**: For expected failures that should halt processing
2. **Throw Errors**: For recoverable errors in batch operations
3. **Pattern Matching**: Use `case` statements to handle specific error types
4. **Resource Safety**: Combine with `with` statements for automatic cleanup
