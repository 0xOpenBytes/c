# c

*Micro Composition*

## What is `c`?
`c` is a simple composition framework. You have the ability to create transformations that are either unidirectional or bidirectional. There is also a cache that values can be set and resolved. 

## Where can `c` be used?
`c` can be used anywhere to create transformations or interact with the cache.

## Examples

### BiDirectionalTransformation of String and Int

```swift
let transformer = c.transformer(
    from: { string in Int(string) },
    to: { int in "\(String(describing: int))" }
)

let string = transformer.to(3)
let int = transformer.from("3")

try t.assert(transformer.to(int), isEqualTo: string)
```

### Cache

```swift
c.set(value: Double.pi, forKey: "🥧")

let pi: Double = c.get("🥧") ?? 0

try t.assert(pi, isEqualTo: .pi)

let resolvedValue: Double = c.resolve("🥧")

try t.assert(resolvedValue, isEqualTo: .pi)
```
