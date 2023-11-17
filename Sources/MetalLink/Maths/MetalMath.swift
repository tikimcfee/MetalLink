//
//  BasicMatrixOperations.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 6/11/22.
//
import simd

public let X_AXIS = LFloat3(1, 0, 0)
public let Y_AXIS = LFloat3(0, 1, 0)
public let Z_AXIS = LFloat3(0, 0, 1)

public extension LFloat3 {
    func translated(dX: Float = 0, dY: Float = 0, dZ: Float = 0) -> LFloat3 {
        LFloat3(x + dX, y + dY, z + dZ)
    }
    
    @discardableResult
    mutating func translateBy(dX: Float = 0, dY: Float = 0, dZ: Float = 0) -> LFloat3 {
        self = LFloat3(x + dX, y + dY, z + dZ)
        return self
    }
    
    @discardableResult
    mutating func translateBy(_ vector: LFloat3) -> LFloat3 {
        self = LFloat3(x + vector.x, y + vector.y, z + vector.z)
        return self
    }
    
    @discardableResult
    mutating func preMultipy(matrix: matrix_float4x4) -> LFloat3 {
        let multiplied = matrix_multiply(matrix, LFloat4(x, y, z, 1))
        self = LFloat3(multiplied.x, multiplied.y, multiplied.z)
        return self
    }
    
    func preMultiplied(matrix: matrix_float4x4) -> LFloat3 {
        let multiplied = matrix_multiply(matrix, LFloat4(x, y, z, 1))
        return LFloat3(multiplied.x, multiplied.y, multiplied.z)
    }
    
    @discardableResult
    mutating func clamped(min: LFloat3, max: LFloat3) -> LFloat3 {
        self.x = x > max.x ? max.x : x < min.x ? min.x : x
        self.y = y > max.y ? max.y : y < min.y ? min.y : y
        self.z = z > max.z ? max.z : z < min.z ? min.z : z
        return self
    }
}

public extension LFloat3 {
    var debugString: String {
        String(
            format: "(%.4d, %.4d, %.4d)",
            x, y, z
        )
    }
}

public extension matrix_float4x4 {
    mutating func scale(amount: LFloat3) {
        self = matrix_multiply(self, .init(scaleBy: amount))
    }
    
    mutating func rotateAbout(axis: LFloat3, by radians: Float) {
        self = matrix_multiply(self, .init(rotationAbout: axis, by: radians))
    }
    
    mutating func translate(vector: LFloat3) {
        self = matrix_multiply(self, .init(translationBy: vector))
    }
}

public extension matrix_float4x4 {
    init(scaleBy s: SIMD3<Float>) {
        self.init(SIMD4(s.x,  0,   0, 0),
                  SIMD4(0,  s.y,   0, 0),
                  SIMD4(0,    0, s.z, 0),
                  SIMD4(0,    0,   0, 1))
    }
    
    init(rotationAbout axis: SIMD3<Float>, by angleRadians: Float) {
        let x = axis.x, y = axis.y, z = axis.z
        let c = cosf(angleRadians)
        let s = sinf(angleRadians)
        let t = 1 - c
        self.init(SIMD4( t * x * x + c,     t * x * y + z * s, t * x * z - y * s, 0),
                  SIMD4( t * x * y - z * s, t * y * y + c,     t * y * z + x * s, 0),
                  SIMD4( t * x * z + y * s, t * y * z - x * s,     t * z * z + c, 0),
                  SIMD4(                 0,                 0,                 0, 1))
    }
    
    init(translationBy t: SIMD3<Float>) {
        self.init(SIMD4(   1,    0,    0, 0),
                  SIMD4(   0,    1,    0, 0),
                  SIMD4(   0,    0,    1, 0),
                  SIMD4(t[0], t[1], t[2], 1))
    }
    
    
    init(perspectiveProjectionFov fovRadians: Float, aspectRatio aspect: Float, nearZ: Float, farZ: Float) {
        let yScale = 1 / tan(fovRadians * 0.5)
        let xScale = yScale / aspect
        let zRange = farZ - nearZ
        let zScale = -(farZ + nearZ) / zRange
        let wzScale = -2 * farZ * nearZ / zRange
        
        let xx = xScale
        let yy = yScale
        let zz = zScale
        let zw = Float(-1)
        let wz = wzScale
        
        self.init(SIMD4(xx,  0,  0,  0),
                  SIMD4( 0, yy,  0,  0),
                  SIMD4( 0,  0, zz, zw),
                  SIMD4( 0,  0, wz,  0))
    }
}

public extension SIMD3 where Scalar == Int {
    var volume: Int { x * y * z }
}

public extension SIMD2 where Scalar == Int {
    var area: Int { x * y }
}

public extension simd_float4x4 {
    init(orthographicProjectionWithLeft left: Float, top: Float, right: Float, bottom: Float, near: Float, far: Float) {
        let xs = 2 / (right - left)
        let ys = 2 / (top - bottom)
        let zs = 1 / (near - far)
        let tx = (left + right) / (left - right)
        let ty = (top + bottom) / (bottom - top)
        let tz = near / (near - far)
        self.init(columns: (simd_float4(xs,  0,  0, 0),
                            simd_float4( 0, ys,  0, 0),
                            simd_float4( 0,  0, zs, 0),
                            simd_float4(tx, ty, tz, 1)))
    }
}
