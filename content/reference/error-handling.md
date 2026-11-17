---
title: "Error Handling"
tags: ["errors", "exceptions", "error-types", "catch"]
sortorder: 10
---

> [!question] Open
> The examples on this page come from the first draft of the reference, and the semantics behind them are still being decided in [cesiumlang/cesium#17](https://github.com/cesiumlang/cesium/issues/17) and [cesiumlang/cesium#40](https://github.com/cesiumlang/cesium/issues/40). In particular:
>
> - Variables such as `file_or_error`, `data` and `result` are declared without a type, which the language does not allow; what type a value-or-error has, and whether an error union is the same construct as `union`, is not decided.
> - The rules proposed in September 2025 for `throw` and `catch` are not yet confirmed: `throw` pushes onto a last-in, first-out error stack and `catch` loops over every error on it; `catch { ... }` with no `case` is an implied `else`; `catch (name) { ... }` binds the error to `name`; `catch` is a special case of `switch`; `error` types share struct syntax and semantics; abstract methods return a `NoImpl` error.
> - Whether allocation failure is an error value or `null` is open.
>
> What *is* decided is how cleanup interacts with errors: `defer` is block-scoped and `free` runs `destruct`. See [[memory-management|Memory Management]].

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

// Error union types
union FileError = FileNotFound|AccessDenied;
union IOError = FileError|NetworkTimeout;
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
