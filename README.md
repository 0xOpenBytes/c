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
let cache = c.cache()

cache.set(value: Double.pi, forKey: "🥧")

let pi: Double = cache.get("🥧") ?? 0

try t.assert(pi, isEqualTo: .pi)

let resolvedValue: Double = cache.resolve("🥧")

try t.assert(resolvedValue, isEqualTo: .pi)
```


### Global Cache

```swift
let someCache: Cache = ...

// Set the value of a Cache with any hashable key
c.set(value: someCache, forKey: "someCache")

// Get an optional Cache using any hashable key
let anotherCache: Cache? = c.get(0)

// Require that a Cache exist using a `.get` with a force unwrap
let requiredCache: Cache = c.resolve(0)
```
