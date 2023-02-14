<div align="center">
   <img src="https://openbytes.dev/assets/projects/images/openbytes-c.png" alt="Icon representing the OpenBytes c project." width="35%"/>
   <h1>c</h1>
   <h3>Micro Composition</h3>
   <a href="https://github.com/0xOpenBytes/c/blob/main/LICENSE">
     <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT License"/>
   </a>
   <img src="https://img.shields.io/github/v/release/0xOpenBytes/c"/>
   <a href="https://discord.gg/HUmaDXVsW7">
     <img src="https://img.shields.io/discord/933406727150391376" alt="Community Chat"/>
   </a>
 </div>

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
let cache = c.Cache()

cache.set(value: Double.pi, forKey: "🥧")

let pi: Double = cache.get("🥧") ?? 0

try t.assert(pi, isEqualTo: .pi)

let resolvedValue: Double = try cache.resolve("🥧")

try t.assert(resolvedValue, isEqualTo: .pi)
                    
cache.remove("🥧")

let nilValue: Double? = cache.get("🥧")

try t.assert(isNil: nilValue)
```

### KeyedCache

```swift
enum CacheKey: Hashable { ... }

let cache = c.KeyedCache<CacheKey>()

cache.set(value: Double.pi, forKey: CacheKey.piKey)

let pi: Double = cache.get(.piKey) ?? 0

try t.assert(pi, isEqualTo: .pi)

let resolvedValue: Double = try cache.resolve(.piKey)

try t.assert(resolvedValue, isEqualTo: .pi)
                    
cache.remove(.piKey)

let nilValue: Double? = cache.get(.piKey)

try t.assert(isNil: nilValue)
```

### JSON
```swift
enum MockJSONKey: String, Hashable {
    case name, number, bool, invalid_key
}

struct MockJSON: Codable {
    var name: String
    var number: Int
    var bool: Bool
}

let jsonData: Data = try! JSONEncoder().encode(MockJSON(name: "Twitch", number: 5, bool: false))

let json: c.JSON<MockJSONKey> = .init(data: jsonData)

XCTAssertEqual(try! json.resolve(.name), "Twitch")
XCTAssertEqual(try! json.resolve(.number), 5)
XCTAssertEqual(try! json.resolve(.bool), false)

let invalid_key: Bool? = json.get(.invalid_key)

XCTAssertNil(json.get(.invalid_key))
XCTAssertNil(invalid_key)

json.set(value: "Leif", forKey: .name)

XCTAssertEqual(try! json.resolve(.name), "Leif")
```


### Global Cache

```swift
let someCache: Cache = ...

// Set the value of a Cache with any hashable key
c.set(value: someCache, forKey: "someCache")

// Get an optional Cache using any hashable key
let anotherCache: Cache? = c.get(0)

// Require that a Cache exist using a `.get` with a force unwrap
let requiredCache: Cache = try c.resolve(0)

let keyedCache: KeyedCache<String> = try c.resolve(...)
```
