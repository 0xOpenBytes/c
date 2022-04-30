import Foundation.NSLock

public protocol Cacheable: AnyObject {
    associatedtype Key: Hashable
    
    init(initialValues: [Key: Any])
    
    /// Get the value in the `cache` using the `key`. This returns an optional value. If the value is `nil`, that means either the value doesn't exist or the value is not able to be casted as `Value`.
    func get<Value>(_ key: Key) -> Value?
    
    /// Resolve the value in the `cache` using the `key`. This function uses `get` and force casts the value. This should only be used when you know the value is always in the `cache`.
    func resolve<Value>(_ key: Key) -> Value
    
    /// Set the value in the `cache` using the `key`. This function will replace anything in the `cache` that has the same `key`.
    func set<Value>(value: Value, forKey key: Key)
}

/// Composition
public enum c {
    public class Cache: Cacheable {
        private var lock: NSLock
        private var cache: [AnyHashable: Any]
        
        required public init(initialValues: [AnyHashable: Any] = [:]) {
            lock = NSLock()
            cache = initialValues
        }
        
        public func get<Value>(_ key: AnyHashable) -> Value? {
            lock.lock()
            defer { lock.unlock() }
            return cache[key] as? Value
        }
        
        public func resolve<Value>(_ key: AnyHashable) -> Value { get(key)! }
        
        public func set<Value>(value: Value, forKey key: AnyHashable) {
            lock.lock()
            cache[key] = value
            lock.unlock()
        }
    }
    
    public class KeyedCache<Key: Hashable>: Cacheable {
        private var lock: NSLock
        private var cache: [Key: Any]
        
        required public init(initialValues: [Key: Any] = [:]) {
            lock = NSLock()
            cache = initialValues
        }
        
        public func get<Value>(_ key: Key) -> Value? {
            lock.lock()
            defer { lock.unlock() }
            return cache[key] as? Value
        }
        
        public func resolve<Value>(_ key: Key) -> Value { get(key)! }
        
        public func set<Value>(value: Value, forKey key: Key) {
            lock.lock()
            cache[key] = value
            lock.unlock()
        }
    }
    
    @frozen public struct AnyCacheable {
        public var base: Any
        
        public init<CacheType: Cacheable>(_ base: CacheType) {
            self.base = base
        }
    }
}

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

// MARK: - Global Cache

public extension c {
    private static var lock = NSLock()
    private static var caches: [AnyHashable: AnyCacheable] = [:]
    
    /// Get the Cache using the `key`. This returns an optional value. If the value is `nil`, that means the Cache doesn't exist.
    static func get<CacheType>(
        _ key: AnyHashable,
        as: CacheType.Type = CacheType.self
    ) -> CacheType? {
        lock.lock()
        defer { lock.unlock() }
        return caches[key]?.base as? CacheType
    }
    
    /// Resolve the Cache using the `key`. This function uses `get` and force casts the value. This should only be used when you know the value always exists.
    static func resolve<CacheType>(
        _ key: AnyHashable,
        as: CacheType.Type = CacheType.self
    ) -> CacheType { get(key)! }
    
    /// Set the Cache using the `key`. This function will replace anything that has the same `key`.
    static func set<CacheType: Cacheable>(value: CacheType, forKey key: AnyHashable) {
        lock.lock()
        caches[key] = AnyCacheable(value)
        lock.unlock()
    }
}
