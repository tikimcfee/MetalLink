xcrun -sdk macosx metal -c -frecord-sources -gline-tables-only Compute.metal &&
xcrun -sdk macosx metal -c -frecord-sources -gline-tables-only MetalLinkBasicShaders.metal && 
xcrun -sdk macosx metal -c -frecord-sources -gline-tables-only MetalLinkInstancedShaders.metal &&
xcrun -sdk macosx metal -c -frecord-sources -gline-tables-only MetalLinkShared.metal &&
xcrun -sdk macosx metal -frecord-sources  -gline-tables-only -o MetalLinkDEBUG.metallib Compute.air MetalLinkBasicShaders.air MetalLinkInstancedShaders.air MetalLinkShared.air &&
xcrun -sdk macosx metal-dsymutil -flat -remove-source MetalLinkDEBUG.metallib