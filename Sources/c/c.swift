import Foundation.NSLock

public protocol Cacheable: AnyObject {
    associatedtype Key: Hashable
    
    init(initialValues: [Key: Any])
    
    /// Get the value in the `cache` using the `key`. This returns an optional value. If the value is `nil`, that means either the value doesn't exist or the value is not able to be casted as `Value`.
    func get<Value>(_ key: Key, as: Value.Type) -> Value?
    
    /// Resolve the value in the `cache` using the `key`. This function uses `get` and force casts the value. This should only be used when you know the value is always in the `cache`.
    func resolve<Value>(_ key: Key, as: Value.Type) -> Value
    
    /// Set the value in the `cache` using the `key`. This function will replace anything in the `cache` that has the same `key`.
    func set<Value>(value: Value, forKey key: Key)
    
    /// Remove the value in the `cache` using the `key`.
    func remove(_ key: Key)
    
    /// Checks if the given `key` has a value or not
    func contains(_ key: Key) -> Bool
    
    /// Checks to make sure the cache has the required keys, otherwise it will throw an error
    func require(keys: Set<Key>) throws -> Self
    
    /// Checks to make sure the cache has the required key, otherwise it will throw an error
    func require(_ key: Key) throws -> Self
    
    /// Returns a Dictionary containing only the key value pairs where the value is the same type as the generic type `Value`
    func valuesInCache<Value>(
        ofType: Value.Type
    ) -> [Key: Value]
}

/// Composition
public enum c {
    public struct MissingRequiredKeysError<Key: Hashable>: Error {
        public let keys: Set<Key>
        
        public init(keys: Set<Key>) {
            self.keys = keys
        }
    }
    
    open class KeyedCache<Key: Hashable>: Cacheable {
        fileprivate var lock: NSLock
        fileprivate var cache: [Key: Any]
        
        required public init(initialValues: [Key: Any] = [:]) {
            lock = NSLock()
            cache = initialValues
        }
        
        open func get<Value>(_ key: Key, as: Value.Type = Value.self) -> Value? {
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
        
        open func resolve<Value>(_ key: Key, as: Value.Type = Value.self) -> Value { get(key)! }
        
        open func set<Value>(value: Value, forKey key: Key) {
            lock.lock()
            cache[key] = value
            lock.unlock()
        }
        
        open func remove(_ key: Key) {
            lock.lock()
            cache[key] = nil
            lock.unlock()
        }
        
        open func contains(_ key: Key) -> Bool {
            cache[key] != nil
        }
        
        open func require(keys: Set<Key>) throws -> Self {
            let missingKeys = keys
                .filter { contains($0) == false }
    
            guard missingKeys.isEmpty else {
                throw MissingRequiredKeysError(keys: missingKeys)
            }
    
            return self
        }
        
        open func require(_ key: Key) throws -> Self {
            try require(keys: [key])
        }
        
        open func valuesInCache<Value>(
            ofType: Value.Type = Value.self
        ) -> [Key: Value] {
            cache.compactMapValues { $0 as? Value }
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
