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
                    let cache = c.Cache()
                    
                    cache.set(value: Double.pi, forKey: "🥧")
                    
                    let pi: Double = cache.get("🥧") ?? 0
                    
                    try t.assert(pi, isEqualTo: .pi)
                    
                    let resolvedValue: Double = cache.resolve("🥧")
                    
                    try t.assert(resolvedValue, isEqualTo: .pi)
                    
                    cache.remove("🥧")
                    
                    let nilValue: Double? = cache.get("🥧")
                    
                    try t.assert(isNil: nilValue)
                }
                
                try t.expect("that the global cache works") {
                    
                    try t.expect("that we can set and get a Cache") {
                        c.set(
                            value: c.Cache(initialValues: [:]),
                            forKey: "cache"
                        )
                        
                        try t.assert(isNotNil: c.get("cache", as: c.Cache.self))
                    }
                    
                    try t.expect("that we can update a Cache and add a new one") {
                        guard let cache: c.Cache = c.get("cache") else { throw t.error(description: "Could not find Cache.") }
                        
                        cache.set(value: "Hello, World!", forKey: "hello")
                        
                        let value: String? = cache.get("hello")
                        
                        try t.assert(isNotNil: value)
                        try t.assert(value, isEqualTo: "Hello, World!")
                        
                        c.set(value: cache, forKey: "cache")
                        
                        c.set(
                            value: c.Cache(initialValues: ["hello": "Hi!"]),
                            forKey: "cache2"
                        )
                    }
                    
                    try t.expect("that we can get both Caches") {
                        guard
                            let cache: c.Cache = c.get("cache"),
                            let cache2: c.Cache = c.get("cache2")
                        else { throw t.error(description: "Missing a Cache.") }
                        
                        try t.assert(cache.get("hello"), isEqualTo: "Hello, World!")
                        try t.assert(cache2.get("hello"), isEqualTo: "Hi!")
                    }
                }
            }
        )
    }
    
    func testMultipleCaches() {
        let someCache = c.Cache(
            initialValues: [
                EnvironmentKey.appID: "APP-ID"
            ]
        )
        
        enum EnvironmentKey: Hashable {
            case appID
            
            static var appCache: c.KeyedCache<EnvironmentKey> = c.KeyedCache(
                initialValues: [
                    .appID: "APP-ID"
                ]
            )
        }
        
        c.set(value: EnvironmentKey.appCache, forKey: "\(EnvironmentKey.self)")
        c.set(value: someCache, forKey: "someCache")
        
        EnvironmentKey.appCache.set(value: "???", forKey: .appID)
        someCache.set(value: "!!!", forKey: EnvironmentKey.appID)
        
        struct Person {
            // Locally Accessed Cache
            let l_appID: String = EnvironmentKey.appCache.resolve(EnvironmentKey.appID)
            
            // Globally Accessed Cache
            let g_appID: String = c.resolve("\(EnvironmentKey.self)", as: c.KeyedCache<EnvironmentKey>.self).resolve(.appID)
        }
        
        XCTAssert(
            t.suite {
                let somePerson = Person()
                
                try t.expect {
                    try t.assert(
                        somePerson.l_appID,
                        isEqualTo: somePerson.g_appID
                    )
                }
                
                try t.expect {
                    try t.assert(
                        c.resolve("someCache", as: c.Cache.self).resolve(EnvironmentKey.appID),
                        isEqualTo: "!!!"
                    )
                    
                    try t.assert(
                        c.resolve("\(EnvironmentKey.self)", as: c.KeyedCache<EnvironmentKey>.self).resolve(.appID),
                        isEqualTo: "???"
                    )
                    
                    try t.assert(
                        EnvironmentKey.appCache.resolve(.appID),
                        isEqualTo: "???"
                    )
                    
                    c.resolve("\(EnvironmentKey.self)", as: c.KeyedCache<EnvironmentKey>.self).set(value: "😎", forKey: .appID)
                    
                    try t.assert(
                        c.resolve("\(EnvironmentKey.self)", as: c.KeyedCache<EnvironmentKey>.self).resolve(.appID),
                        isEqualTo: "😎"
                    )
                    
                    try t.assert(
                        EnvironmentKey.appCache.resolve(.appID),
                        isEqualTo: "😎"
                    )
                }
            }
        )
    }
    
    func testJSON() {
        typealias Compose = c
        typealias JSON = Compose.JSON
        
        enum MockJSONKey: String, Hashable {
            case name, number, bool, invalid_key
        }
        
        struct MockJSON: Codable {
            var name: String
            var number: Int
            var bool: Bool
        }
        
        let jsonData: Data = try! JSONEncoder().encode(MockJSON(name: "Twitch", number: 5, bool: false))
        
        let json: JSON<MockJSONKey> = JSON(data: jsonData)
        
        XCTAssertEqual(json.resolve(.name), "Twitch")
        XCTAssertEqual(json.resolve(.number), 5)
        XCTAssertEqual(json.resolve(.bool), false)
        
        let invalid_key: Bool? = json.get(.invalid_key)
        
        XCTAssertNil(json.get(.invalid_key))
        XCTAssertNil(invalid_key)
        
        json.set(value: "Leif", forKey: .name)
        
        XCTAssertEqual(json.resolve(.name), "Leif")
    }
    
    func testNestedJSON_integration() {
        // MARK: - Models
        
        enum UserKey: String, Hashable {
            case name, address
        }
        
        struct User: Codable, Identifiable {
            let id: Int
            let name: String
            let username: String
            let email: String
            let address: Address
            let phone: String
            let website: String
            let company: Company
        }
        
        struct Address: Codable, Equatable {
            let street: String
            let suite: String
            let city: String
            let zipcode: String
            let geo: Coordinate
        }
        
        struct Coordinate: Codable, Equatable {
            let lat: String
            let lng: String
        }
        
        struct Company: Codable {
            let name: String
            let catchPhrase: String
            let bs: String
        }
        
        // MARK: - Test
        
        let url = URL(string: "https://jsonplaceholder.typicode.com/users")!
        
        let sema = DispatchSemaphore(value: 0)
        
        var json: [c.JSON<UserKey>] = []
        
        URLSession.shared.dataTask(
            with: url,
            completionHandler: { data, response, error in
                defer { sema.signal() }
                
                guard let data = data else {
                    return
                }
                
                json = c.JSON.array(data: data)
            }
        )
            .resume()
        
        sema.wait()
        
        XCTAssertNotNil(json.first)
        XCTAssertEqual(json.first?.resolve(.name), "Leanne Graham")
        
        enum AddressKey: String, Hashable {
            case city
            case geo
        }
        
        let userAddress = Address(street: "", suite: "", city: "Gwenborough", zipcode: "", geo: Coordinate(lat: "-37.3159", lng: "81.1496"))
        let expectedJSONAddress = c.JSON<AddressKey>(data: try! JSONEncoder().encode(userAddress))
        
        guard let value = json.first else {
            XCTFail()
            return
        }
        
        let jsonAddress: c.JSON<AddressKey> = value.json(.address)!
        
        c.set(value: jsonAddress, forKey: "jsonAddress")
        
        let address: c.JSON<AddressKey> = c.resolve("jsonAddress")
        
        let jsonCity: String? = address.resolve(.city)
        let expectedCity: String = expectedJSONAddress.resolve(.city)
        
        XCTAssertEqual(jsonCity, expectedCity)
        
        enum GeoKey: String, Hashable {
            case lat
            case lng
        }
        
        let jsonGeo: c.JSON<GeoKey> = address.json(.geo)!
        let expectedJSONGeo: c.JSON<GeoKey> = expectedJSONAddress.json(.geo)!
        
        let jsonLat: String? = jsonGeo.resolve(.lat)
        let expectedLat: String = expectedJSONGeo.resolve(.lat)
        
        XCTAssertEqual(jsonLat, expectedLat)
    }
}
