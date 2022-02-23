import XCTest
import t
@testable import c

final class cTests: XCTestCase {
    func testExample() throws {
        XCTAssert(
            t.suite {
                try t.expect("that a basic transformation") {
                    let transformer = c.transformer(
                        from: { string in Int(string) },
                        to: { int in "\(String(describing: int))" }
                    )
                    
                    let string = transformer.to(3)
                    let int = transformer.from("3")
                    
                    try t.assert(transformer.to(int), isEqualTo: string)
                }
                
                try t.expect("that a cache works") {
                    c.set(value: Double.pi, forKey: "🥧")
                    
                    let pi: Double = c.get("🥧") ?? 0
                    
                    try t.assert(pi, isEqualTo: .pi)
                    
                    let resolvedValue: Double = c.resolve("🥧")
                    
                    try t.assert(resolvedValue, isEqualTo: .pi)
                }
            }
        )
    }
}
