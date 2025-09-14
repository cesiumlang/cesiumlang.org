---
title: "Object-Oriented Programming"
tags: ["oop", "structs", "inheritance", "traits", "properties"]
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

    // Instance method
    f64 = distance_from_origin() {
        return ::(x^2 + y^2);  // sqrt of sum of squares
    }

    // Method with mutable access
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
        super ~Point();       // call parent destructor
    }

    // Override parent method
    f64 = distance_from_origin() {
        return ::(x^2 + y^2 + z^2);
    }
}
```

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

    // Getter property
    f64 = property area() {
        return 3.14159 * radius^2;
    }

    // Setter property (returns assigned value for chaining)
    f64 = property.set radius(f64 r) {
        assert(r >= 0.0);
        this.radius = r;
        return r;  // enables: x = circle.radius = 5.0
    }

    // Read-only property (getter only)
    f64 = property circumference() {
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
    i32 = compare(type other);  // type refers to implementing type
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
    i32 = compare(Circle other) {
        if (this.radius < other.radius) return -1;
        if (this.radius > other.radius) return 1;
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
|----------|------------|
| (default) | Public - accessible everywhere |
| `private` | Module-scoped - accessible within the same module |
| `secret` | Class-scoped - accessible only within the class/struct |

## Method Types

- **Instance methods**: Access `this` implicitly
- **Static methods**: No `this` parameter, called on type
- **Properties**: Special methods for field-like access
- **Constructors**: Named same as struct, initialize instances
- **Destructors**: Called automatically when object is destroyed
