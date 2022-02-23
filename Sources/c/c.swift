import Foundation.NSLock

/// Composition
public enum c { }

// MARK: - Transformations

public extension c {
    typealias UniDirectionalTransformation<From, To> = (From) -> To
    typealias BiDirectionalTransformation<From, To> = (
        from: UniDirectionalTransformation<From, To>,
        to: UniDirectionalTransformation<To, From>
    )
    
    static func transformer<From, To>(
        from: @escaping (From) -> To
    ) -> UniDirectionalTransformation<From, To> { from }
    
    static func transformer<From, To>(
        from: @escaping (From) -> To,
        to: @escaping (To) -> From
    ) -> BiDirectionalTransformation<From, To> { (from: from, to: to) }
}

//MARK: - Cache

public extension c {
    private static var lock = NSLock()
    private static var cache: [AnyHashable: Any] = [:]
    
    static func get<Value>(_ key: AnyHashable) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key] as? Value
    }
    static func resolve<Value>(_ key: AnyHashable) -> Value { get(key)! }
    
    static func set<Value>(value: Value, forKey key: AnyHashable) {
        lock.lock()
        cache[key] = value
        lock.unlock()
    }
}
