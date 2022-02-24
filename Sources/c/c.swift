import Foundation.NSLock

/// Composition
public enum c { }

// MARK: - Transformations

public extension c {
    /// This transformation takes `From` as input and returns `To` as output.
    typealias UniDirectionalTransformation<From, To> = (From) -> To
    
    /// This transformation uses two UniDirectionalTransformations to be able to transform `From` into `To` and `To` into `From`.
    typealias BiDirectionalTransformation<From, To> = (
        from: UniDirectionalTransformation<From, To>,
        to: UniDirectionalTransformation<To, From>
    )
    /// Create a UniDirectionalTransformation.
    static func transformer<From, To>(
        from: @escaping (From) -> To
    ) -> UniDirectionalTransformation<From, To> { from }
    
    /// Create a BiDirectionalTransformation.
    static func transformer<From, To>(
        from: @escaping (From) -> To,
        to: @escaping (To) -> From
    ) -> BiDirectionalTransformation<From, To> { (from: from, to: to) }
}

//MARK: - Cache

public extension c {
    private static var lock = NSLock()
    private static var cache: [AnyHashable: Any] = [:]
    
    /// Get the value in the `cache` using the `key`. This returns an optional value. If the value is `nil`, that means either the value doesn't exist or the value is not able to be casted as `Value`.
    static func get<Value>(_ key: AnyHashable) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key] as? Value
    }
    
    /// Resolve the value in the `cache` using the `key`. This function uses `get` and force casts the value. This should only be used when you know the value is always in the `cache`.
    static func resolve<Value>(_ key: AnyHashable) -> Value { get(key)! }
    
    /// Set the value in the `cache` using the `key`. This function will replace anything in the `cache` that has the same `key`.
    static func set<Value>(value: Value, forKey key: AnyHashable) {
        lock.lock()
        cache[key] = value
        lock.unlock()
    }
}
