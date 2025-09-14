---
title: "Control Flow"
tags: ["control-flow", "conditionals", "loops", "pattern-matching"]
---

## Conditional Statements

### If-Else Statements

```cesium
if (condition) {
    printf("Condition is true\n");
} else if (other_condition) {
    printf("Other condition is true\n");
} else {
    printf("No conditions met\n");
}
```

## Loops

### While Loops

```cesium
// While loop
i32 count = 0;
while (count < 10) {
    printf("Count: {}\n", count);
    count++;
}
```

### Do-While Loops

```cesium
// Do-while loop
do {
    input = get_user_input();
} while (input != "quit");
```

### For Loops with Ranges

```cesium
// For loops with ranges
for (i32 i = 0..10) {        // 0,1,2,...,9 (exclusive)
    printf("i = {}\n", i);
}

for (i32 i = 0..=10) {       // 0,1,2,...,10 (inclusive)
    printf("i = {}\n", i);
}

for (i32 i = 0..2..=10) {    // 0,2,4,6,8,10 (step 2)
    printf("i = {}\n", i);
}
```

### Collection Iteration

```cesium
// Iteration over collections
i32 numbers[5] = {1, 2, 3, 4, 5};
for (i32 value = numbers) {
    printf("Value: {}\n", value);
}
```

## Pattern Matching

### Switch Statements

```cesium
// Switch statements
switch (value) {
    case (1) { printf("One\n"); }
    case (2, 3) { printf("Two or Three\n"); }
    case (10..=20) { printf("Between 10 and 20\n"); }
    else { printf("Something else\n"); }
}
```

### Fallthrough Behavior

```cesium
// Optional fallthrough
fallthrough switch (status) {
    case (STARTING) {
        initialize();
        // falls through
    }
    case (RUNNING) {
        process();
        break;  // explicit break
    }
    case (STOPPED) {
        cleanup();
    }
}
```

### Type Matching

```cesium
// Type matching
Number num = get_number();  // Number = i32|f64
switch (typeof(num)) {
    case (i32) {
        i32 val = num as i32;
        printf("Integer: {}\n", val);
    }
    case (f64) {
        f64 val = num as f64;
        printf("Float: {}\n", val);
    }
}
```

## Loop Control

### Break and Continue

```cesium
for (i32 i = 0..100) {
    if (i % 2 == 0) {
        continue;  // skip even numbers
    }
    if (i > 50) {
        break;     // exit loop
    }
    printf("{}\n", i);
}
```

## Range Syntax

Cesium provides several range operators for convenient iteration:

| Syntax | Description | Example |
|--------|-------------|---------|
| `a..b` | Exclusive range | `0..10` → 0,1,2,...,9 |
| `a..=b` | Inclusive range | `0..=10` → 0,1,2,...,10 |
| `a..step..=b` | Stepped inclusive | `0..2..=10` → 0,2,4,6,8,10 |
| `a..step..b` | Stepped exclusive | `0..2..10` → 0,2,4,6,8 |
