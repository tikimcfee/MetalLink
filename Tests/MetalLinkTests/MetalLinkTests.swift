import XCTest
@testable import MetalLink

final class MetalLinkTests: XCTestCase {
    
    
    func testTheThing() throws {
        // Cache characters to get their hashes. Might want to cache this somewhere.
        BIG_CHARACTER_WALL.forEach { x in x.forEach { $0.glyphComputeHash }}
        
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice(), "no system device")
        let link = try MetalLink(device: device)
        let compute = ConvertCompute(link: link)
        
        // Ue the mapped cache (this is why initial load fails, should do this on launch
        let atlas = try MetalLinkAtlas(link, compute: compute)
        atlas.reset(compute)
        atlas.preload()
        
        let testPathName = "/Users/lugo/localdev/viz/MetalLink/Sources/MetalLinkResources/Resources/Shaders/MetalLinkBasicShaders.metal"
        let testPath = URL(fileURLWithPath: testPathName)
        
        let result = compute.executeManyWithAtlas_Conc(
            in: testPath,
            atlas: atlas
        )
        
        let collection = try XCTUnwrap(result?.collection, "No Collection")
        switch collection {
        case .built(let collection):
            let query = "include".map { $0.glyphComputeHash }
            try compute.searchGlyphs_Conc(
                in: collection,
                with: query
            )
            
            
            
        case .notBuilt:
            XCTFail("no gird")
        }
    }
}
