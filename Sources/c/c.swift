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
    
    /// Remove the value in the `cache` using the `key`.
    func remove(_ key: Key)
}

/// Composition
public enum c {
    public class KeyedCache<Key: Hashable>: Cacheable {
        fileprivate var lock: NSLock
        fileprivate var cache: [Key: Any]
        
        required public init(initialValues: [Key: Any] = [:]) {
            lock = NSLock()
            cache = initialValues
        }
        
        public func get<Value>(_ key: Key) -> Value? {
            lock.lock()
            defer { lock.unlock() }
            guard let value = cache[key] as? Value else {
                return nil
            }
            
            let mirror = Mirror(reflecting: value)
            
            if mirror.displayStyle != .optional {
                return value
            }
            
            if mirror.children.isEmpty {
                return nil
            }
            
            guard let (_, unwrappedValue) = mirror.children.first else { return nil }
            
            guard let value = unwrappedValue as? Value else {
                return nil
            }
            
            return value
        }
        
        public func resolve<Value>(_ key: Key) -> Value { get(key)! }
        
        public func set<Value>(value: Value, forKey key: Key) {
            lock.lock()
            cache[key] = value
            lock.unlock()
        }
        
        public func remove(_ key: Key) {
            lock.lock()
            cache[key] = nil
            lock.unlock()
        }
    }
    
    public class Cache: KeyedCache<AnyHashable> {
        required public init(initialValues: [Key: Any] = [:]) {
            super.init(initialValues: initialValues)
        }
    }
    
    public class JSON<Key: RawRepresentable & Hashable>: KeyedCache<Key> where Key.RawValue == String {
        convenience public init(data: Data) {
            var initialValues: [Key: Any] = [:]
            
            if
                let json = try? JSONSerialization.jsonObject(with: data),
                let jsonDictionary: [String: Any] = json as? [String: Any]
            {
                jsonDictionary.forEach { jsonKey, jsonValue in
                    guard let key = Key(rawValue: jsonKey) else { return }
                    
                    initialValues[key] = jsonValue
                }
            }
            
            self.init(initialValues: initialValues)
        }
        
        required public init(initialValues: [Key: Any]) {
            super.init(initialValues: initialValues)
        }
        
        public static func array(data: Data) -> [JSON] {
            guard
                let json = try? JSONSerialization.jsonObject(with: data),
                let jsonArray = json as? [Any]
            else { return [] }
            
            return jsonArray.compactMap { jsonObject in
                guard let jsonDictionary = jsonObject as? [String: Any] else { return nil }
                
                var initialValues: [Key: Any] = [:]
                
                jsonDictionary.forEach { jsonKey, jsonValue in
                    guard let key = Key(rawValue: jsonKey) else { return }
                    
                    initialValues[key] = jsonValue
                }
                
                return JSON(initialValues: initialValues)
            }
        }
        
        public func json<Value: JSON<JSONKey>, JSONKey: RawRepresentable & Hashable>(
            _ key: Key,
            keyed: JSONKey.Type = JSONKey.self
        ) -> JSON<JSONKey>? {
            lock.lock()
            defer { lock.unlock() }
            guard let jsonDictionary = cache[key] as? [String: Any] else {
                return nil
            }
            
            var initialValues: [JSONKey: Any] = [:]
            
            jsonDictionary.forEach { jsonKey, jsonValue in
                guard let key = JSONKey(rawValue: jsonKey) else { return }
                
                initialValues[key] = jsonValue
            }
            
            return JSON<JSONKey>(initialValues: initialValues)
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
