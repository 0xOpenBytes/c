import XCTest
import t
@testable import c

final class cTests: XCTestCase {
    func testExample() throws {
        XCTAssert(
            t.suite {
                try t.expect("that a basic transformation works") {
                    let transformer = c.transformer(
                        from: { string in Int(string) },
                        to: { int in "\(String(describing: int))" }
                    )
                    
                    let string = transformer.to(3)
                    let int = transformer.from("3")
                    
                    try t.assert(transformer.to(int), isEqualTo: string)
                }
                
                try t.expect("that a cache works") {
                    let cache = c.cache()
                    
                    cache.set(value: Double.pi, forKey: "🥧")
                    
                    let pi: Double = cache.get("🥧") ?? 0
                    
                    try t.assert(pi, isEqualTo: .pi)
                    
                    let resolvedValue: Double = cache.resolve("🥧")
                    
                    try t.assert(resolvedValue, isEqualTo: .pi)
                }
                
                try t.expect("that the global cache works") {
                    
                    try t.expect("that we can set and get a Cache") {
                        c.set(
                            value: .init(initialValues: [:]),
                            forKey: "cache"
                        )
                        
                        try t.assert(isNotNil: c.get("cache"))
                    }
                    
                    try t.expect("that we can update a Cache and add a new one") {
                        guard let cache = c.get("cache") else { throw t.error(description: "Could not find Cache.") }
                        
                        cache.set(value: "Hello, World!", forKey: "hello")
                        
                        let value: String? = cache.get("hello")
                        
                        try t.assert(isNotNil: value)
                        try t.assert(value, isEqualTo: "Hello, World!")
                        
                        c.set(value: cache, forKey: "cache")
                        
                        c.set(
                            value: .init(initialValues: ["hello": "Hi!"]),
                            forKey: "cache2"
                        )
                    }
                    
                    try t.expect("that we can get both Caches") {
                        guard
                            let cache = c.get("cache"),
                            let cache2 = c.get("cache2")
                        else { throw t.error(description: "Missing a Cache.") }
                        
                        try t.assert(cache.get("hello"), isEqualTo: "Hello, World!")
                        try t.assert(cache2.get("hello"), isEqualTo: "Hi!")
                    }
                }
            }
        )
    }
}
