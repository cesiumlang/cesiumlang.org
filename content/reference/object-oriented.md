---
title: "Object-Oriented Programming"
tags: ["oop", "structs", "inheritance", "traits", "properties"]
sortorder: 9
---

## Struct Definition and Usage

### Basic Struct Definition

```cesium
struct Point {
  f64 x = 0.0;
  f64 y = 0.0;
  private f64 internal_id;     // accessible to subclasses
  secret f64 truly_private;    // not accessible to subclasses

  // Constructor
  Point(f64 px, f64 py) {
    x = px;
    y = py;
    internal_id = generate_id();
  }

  // Destructor
  destruct Point() {
    cleanup_resources();
  }

  // Static method
  static Point = origin() {
    return Point(0.0, 0.0);
  }

  // Read-only instance method: # before the name
  f64 = #distance_from_origin() {
    return ::(x^2 + y^2);  // sqrt of sum of squares
  }

  // Instance method with mutable access to this
  void = translate(f64 dx, f64 dy) {
    x += dx;
    y += dy;
  }
}
```

### Usage

```cesium
Point p1(3.0, 4.0);
Point origin = Point.origin();      // static method call
f64 dist = p1.distance_from_origin();
p1.translate(1.0, -1.0);
```

An unprefixed method takes `this` as a mutable borrow, so it cannot be called through a `#Point` pointer. A method declared with `#` before its name is read-only and can.

```cesium
void = report(#Point p) {
  f64 d = p.distance_from_origin();   // fine: read-only method
  // p.translate(1.0, 0.0);           // error: translate needs a mutable this
}
```

## Inheritance

### Single Inheritance

```cesium
// Single inheritance
struct Point3D(Point) {
  f64 z = 0.0;

  Point3D(f64 px, f64 py, f64 pz) {
    super Point(px, py);  // call parent constructor
    z = pz;
  }

  destruct Point3D() {
    // local cleanup
  }

  // Override parent method
  f64 = #distance_from_origin() {
    return ::(x^2 + y^2 + z^2);
  }
}
```

> [!question] Open
> How a destructor calls its parent's destructor has no agreed spelling. The original example used the C++-style `super ~Point();`, but destructors were renamed to `destruct Name()` because prefix `~` now means a mutable borrow. See [cesiumlang/cesium#18](https://github.com/cesiumlang/cesium/issues/18) and, for destructors and overrides reached through a base pointer, [cesiumlang/cesium#31](https://github.com/cesiumlang/cesium/issues/31).

### Multiple Inheritance

```cesium
// Multiple inheritance
struct ColoredPoint(Point, Colored) {
  ColoredPoint(f64 x, f64 y, Color c) {
    super Point(x, y);     // left-to-right constructor calls
    super Colored(c);
  }

  // Method resolution override (use Point's version instead of Colored's)
  str = Point.to_string;
}
```

## Properties

### Property Definition

```cesium
struct Circle {
  private f64 radius;

  // Getter property (read-only: # before the name)
  f64 = property #area() {
    return 3.14159 * radius^2;
  }

  // Setter property (returns assigned value for chaining)
  f64 = property.set radius(f64 r) {
    assert(r >= 0.0);
    this.radius = r;
    return r;  // enables: x = circle.radius = 5.0
  }

  // Read-only property (getter only)
  f64 = property #circumference() {
    return 2.0 * 3.14159 * radius;
  }
}
```

### Property Usage

```cesium
Circle c;
c.radius = 5.0;              // calls setter
f64 area = c.area;           // calls getter
// c.circumference = 10.0;   // error: read-only property
```

## Traits and Implementation

### Defining Traits

```cesium
// Define trait interface
trait Drawable {
  void = draw();
  void = resize(f64 scale);

  // Default implementation
  void = highlight() {
    printf("Highlighting drawable object\n");
  }
}

trait Comparable {
  i32 = #compare(type other);  // type refers to implementing type
}
```

### Implementing Traits

```cesium
// Implement traits for types
impl Drawable(Circle) {
  void = draw() {
    printf("Drawing circle with radius {}\n", this.radius);
  }

  void = resize(f64 scale) {
    this.radius *= scale;
  }

  // highlight() uses default implementation
}

impl Comparable(Circle) {
  i32 = #compare(Circle other) {
    if (this.radius < other.radius) {
      return -1;
    }
    if (this.radius > other.radius) {
      return 1;
    }
    return 0;
  }
}
```

### Generic Functions with Traits

```cesium
// Generic functions using traits
generic<Drawable T> void = render_object(T obj) {
  obj.draw();
  obj.highlight();
}
```

## Access Modifiers

| Modifier | Visibility |
| --- | --- |
| (default) | Public - accessible everywhere |
| `private` | Module-scoped - accessible within the same module |
| `secret` | Class-scoped - accessible only within the class/struct |

> [!question] Open
> `private` is described two ways in the reference: module-scoped (this table) and "accessible to subclasses" (the `Point` example at the top of this page). Which one holds, or whether both do in different places, is being decided in [cesiumlang/cesium#13](https://github.com/cesiumlang/cesium/issues/13).

## Method Types

- **Instance methods**: Access `this` implicitly, as a mutable borrow
- **Read-only methods**: Declared with `#` before the name; can be called through a `#T` pointer
- **Static methods**: No `this` parameter, called on type
- **Properties**: Special methods for field-like access
- **Constructors**: Named same as struct, initialize instances
- **Destructors**: Declared as `destruct Name()`. Run when a plain value goes out of scope, and as part of `free` for an owned pointer

## Rules from the Original Design

These rules were set in the September 2025 design sessions and are recorded in [cesiumlang/cesium#18](https://github.com/cesiumlang/cesium/issues/18). They are listed here so the page is complete; several are being re-examined by the design audit ([cesiumlang/cesium#30](https://github.com/cesiumlang/cesium/issues/30), [cesiumlang/cesium#31](https://github.com/cesiumlang/cesium/issues/31)).

- There are no virtual functions. All dispatch is static.
- `static` is required on a method that does not use `this`; leaving it out is a compile error, and so is using `this` in a `static` method.
- A default constructor is generated when none is written. It calls the parent constructors left to right and applies the field defaults.
- With multiple inheritance, constructors run left to right. For conflicting members the rightmost parent wins; `T = Parent.method;` overrides that choice.
- Properties can be overridden in subclasses.
- Traits may contain `private` and `secret` members.

> [!question] Open
> Some examples on this page are known not to fit together yet and are waiting on [cesiumlang/cesium#18](https://github.com/cesiumlang/cesium/issues/18): three different ways of constructing a struct appear in the reference (`Point p1(3.0, 4.0);`, `Point(0.0, 0.0)` and the literal `Calculator { last_result = 0.0 }`) with no rule for when each applies; `Circle` has both a field and a setter property named `radius`; and the trait `Comparable` declares `compare(type other)` while its implementation writes `compare(Circle other)`.
