import Foundation.NSLock

public protocol Cacheable: AnyObject {
    associatedtype Key: Hashable
    associatedtype Value

    /// Returns a Dictionary containing all the key value pairs of the cache
    var allValues: [Key: Value] { get }
    
    init(initialValues: [Key: Value])
    
    /// Get the value in the `cache` using the `key`. This returns an optional value. If the value is `nil`, that means either the value doesn't exist or the value is not able to be casted as `Value`.
    func get<Output>(_ key: Key, as: Output.Type) -> Output?
    
    /// Resolve the value in the `cache` using the `key`. This should only be used when you know the value is always in the `cache`.
    func resolve<Output>(_ key: Key, as: Output.Type) throws -> Output
    
    /// Set the value in the `cache` using the `key`. This function will replace anything in the `cache` that has the same `key`.
    func set(value: Value, forKey key: Key)
    
    /// Remove the value in the `cache` using the `key`.
    func remove(_ key: Key)
    
    /// Checks if the given `key` has a value or not
    func contains(_ key: Key) -> Bool
    
    /// Checks to make sure the cache has the required keys, otherwise it will throw an error
    func require(keys: Set<Key>) throws -> Self
    
    /// Checks to make sure the cache has the required key, otherwise it will throw an error
    func require(_ key: Key) throws -> Self
    
    /// Returns a Dictionary containing only the key value pairs where the value is the same type as the generic type `Value`
    func valuesInCache<Output>(
        ofType: Output.Type
    ) -> [Key: Output]
}

public extension Cacheable {
    var allValues: [Key: Value] {
        valuesInCache(ofType: Value.self)
    }
}

/// Composition
public enum c {
    /// `Error` that reports the missing keys
    public struct MissingRequiredKeysError<Key: Hashable>: LocalizedError {
        /// Required keys
        public let keys: Set<Key>

        /// init for `MissingRequiredKeysError<Key>`
        public init(keys: Set<Key>) {
            self.keys = keys
        }

        /// Error description for `LocalizedError`
        public var errorDescription: String? {
            "Missing Required Keys: \(keys.map { "\($0)" }.joined(separator: ", "))"
        }
    }

    /// `Error` that reports the expected type for a value
    public struct InvalidTypeError<ExpectedType>: LocalizedError {
        /// Expected type
        public let expectedType: ExpectedType.Type

        // Actual Value
        public let actualValue: Any?

        /// init for `InvalidTypeError<Key>`
        public init(
            expectedType: ExpectedType.Type,
            actualValue: Any?
        ) {
            self.expectedType = expectedType
            self.actualValue = actualValue
        }

        /// Error description for `LocalizedError`
        public var errorDescription: String? {
            "Invalid Type: (Expected: \(expectedType.self)) got \(type(of: actualValue))"
        }
    }
    
    open class Cache<Key: Hashable, Value>: Cacheable {
        fileprivate var lock: NSLock
        fileprivate var cache: [Key: Value]
        
        required public init(initialValues: [Key: Value] = [:]) {
            lock = NSLock()
            cache = initialValues
        }
        
        open func get<Output>(_ key: Key, as: Output.Type = Value.self) -> Output? {
            lock.lock()
            defer { lock.unlock() }
            guard let value = cache[key] as? Output else {
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
            
            guard let value = unwrappedValue as? Output else {
                return nil
            }
            
            return value
        }
        
        open func resolve<Output>(_ key: Key, as: Output.Type = Value.self) throws -> Output {
            guard contains(key) else {
                throw MissingRequiredKeysError(keys: [key])
            }

            guard let value: Output = get(key) else {
                throw InvalidTypeError(expectedType: Output.self, actualValue: get(key))
            }

            return value
        }
        
        open func set(value: Value, forKey key: Key) {
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
        
        open func valuesInCache<Output>(
            ofType: Output.Type = Output.self
        ) -> [Key: Output] {
            cache.compactMapValues { $0 as? Output }
        }
    }
    
    public struct JSON<Key: RawRepresentable & Hashable> where Key.RawValue == String {
        private var cache: [Key: Any]

        public var allValues: [Key: Any] {
            valuesInCache(ofType: Any.self)
        }

        public init(initialValues: [Key: Any]) {
            self.cache = initialValues
        }

        public init(data: Data) {
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
        
        public func json<JSONKey: RawRepresentable & Hashable>(
            _ key: Key,
            keyed: JSONKey.Type = JSONKey.self
        ) -> JSON<JSONKey>? {
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

        public func array<JSONKey: RawRepresentable & Hashable>(
            _ key: Key,
            keyed: JSONKey.Type = JSONKey.self
        ) -> [JSON<JSONKey>]? {
            guard let jsonArray = get(key, as: [[String: Any]].self) else {
                return nil
            }

            var values: [JSON<JSONKey>] = []

            jsonArray.forEach { json in
                guard let jsonData = try? JSONSerialization.data(withJSONObject: json) else { return }

                values.append(JSON<JSONKey>(data: jsonData))
            }

            return values
        }

        public func get<Value>(_ key: Key, as: Value.Type = Value.self) -> Value? {
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

        public func resolve<Value>(_ key: Key, as: Value.Type = Value.self) throws -> Value {
            guard contains(key) else {
                throw MissingRequiredKeysError(keys: [key])
            }

            guard let value: Value = get(key) else {
                throw InvalidTypeError(expectedType: Value.self, actualValue: get(key))
            }

            return value
        }

        public mutating func set<Value>(value: Value, forKey key: Key) {
            cache[key] = value
        }

        public mutating func remove(_ key: Key) {
            cache[key] = nil
        }

        public func contains(_ key: Key) -> Bool {
            cache[key] != nil
        }

        public func require(keys: Set<Key>) throws -> Self {
            let missingKeys = keys
                .filter { contains($0) == false }

            guard missingKeys.isEmpty else {
                throw MissingRequiredKeysError(keys: missingKeys)
            }

            return self
        }

        public func require(_ key: Key) throws -> Self {
            try require(keys: [key])
        }

        public func valuesInCache<Value>(
            ofType: Value.Type = Value.self
        ) -> [Key: Value] {
            cache.compactMapValues { $0 as? Value }
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

    /// Checks if the given `key` has a Cache or not
    static func contains(_ key: AnyHashable) -> Bool {
        caches[key] != nil
    }
    
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
    ) throws -> CacheType {
        guard contains(key) else {
            throw MissingRequiredKeysError(keys: [key])
        }

        guard let value: CacheType = get(key) else {
            throw InvalidTypeError(expectedType: CacheType.self, actualValue: get(key))
        }

        return value
    }
    
    /// Set the Cache using the `key`. This function will replace anything that has the same `key`.
    static func set<CacheType: Cacheable>(value: CacheType, forKey key: AnyHashable) {
        lock.lock()
        caches[key] = AnyCacheable(value)
        lock.unlock()
    }
}
