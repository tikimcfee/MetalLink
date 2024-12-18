//
//  BasicMatrixOperations.swift
//  LookAtThat_AppKit
//
//  Created by Ivan Lugo on 6/11/22.
//
import simd

func clamp<T: Comparable>(_ value: T, min minIn: T, max maxIn: T) -> T {
    max(min(maxIn, value), minIn)
}

public let X_AXIS = LFloat3(1, 0, 0)
public let Y_AXIS = LFloat3(0, 1, 0)
public let Z_AXIS = LFloat3(0, 0, 1)

public protocol TuplePrint4 {
    var tupleString: String { get }
    var x: Float { get }
    var y: Float { get }
    var z: Float { get }
    var w: Float { get }
}

public protocol TuplePrint3 {
    var tupleString: String { get }
    var x: Float { get }
    var y: Float { get }
    var z: Float { get }
}

public protocol TuplePrint2 {
    var tupleString: String { get }
    var x: Float { get }
    var y: Float { get }
}

public extension TuplePrint4 {
    var tupleString: String { "(\(x), \(y), \(z), \(w)" }
}

public extension TuplePrint3 {
    var tupleString: String { "(\(x), \(y), \(z))" }
}

public extension TuplePrint2 {
    var tupleString: String { "(\(x), \(y))" }
}

extension LFloat4: TuplePrint4 { }
extension LFloat3: TuplePrint3 { }
extension LFloat2: TuplePrint2 { }

public extension LFloat3 {
    init(xyzSource: LFloat4) {
        self = LFloat3(x: xyzSource.x,
                       y: xyzSource.y, 
                       z: xyzSource.z)
    }
    
    init(xySource: LFloat2) {
        self = LFloat3(x: xySource.x,
                       y: xySource.y,
                       z: 0)
    }
    
    func matrix4x4Identity() -> LFloat4 {
        LFloat4(x, y, z, 1)
    }
    
    func translated(dX: Float = 0, dY: Float = 0, dZ: Float = 0) -> LFloat3 {
        LFloat3(x + dX, y + dY, z + dZ)
    }
    
    func rotated(by rotation: LFloat3) -> LFloat3 {
         let pitch = simd_quaternion(rotation.x, X_AXIS)
         let yaw = simd_quaternion(rotation.y, Y_AXIS)
         let roll = simd_quaternion(rotation.z, Z_AXIS)
         let combinedRotation = simd_mul(simd_mul(pitch, yaw), roll)
         return simd_act(combinedRotation, self)
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
    mutating func clampTo(min: LFloat3, max: LFloat3) -> LFloat3 {
//        self.clamp(lowerBound: min, upperBound: max) // hah... didn't try this...
        self.x = x > max.x ? max.x
               : x < min.x ? min.x
               : x
        self.y = y > max.y ? max.y 
               : y < min.y ? min.y 
               : y
        self.z = z > max.z ? max.z
               : z < min.z ? min.z
               : z
        return self
    }
}

public extension LFloat3 {
    static func * (_ l: LFloat3, _ m: Float) -> LFloat3 {
        LFloat3(l.x * m, l.y * m, l.z * m)
    }
}

public extension LFloat3 {
    func xyzQuaternian() -> simd_quatf {
        let pitch = simd_quaternion(x, X_AXIS)
        let yaw = simd_quaternion(y, Y_AXIS)
        let roll = simd_quaternion(z, Z_AXIS)
        return simd_mul(simd_mul(pitch, yaw), roll)
    }
    
    func dot(_ vector: LFloat3) -> Float {
        return simd_dot(self, vector)
    }
    
    func distance(to point: LFloat3) -> Float {
        return sqrt(
            pow(point.x - x, 2) +
            pow(point.y - y, 2) +
            pow(point.z - z, 2)
        )
    }
}

public extension LFloat3 {
    var magnitude: Float {
        sqrt(x * x + y * y + z * z)
    }
    
    var magnitudeSquared: Float {
        x * x + y * y + z * z
    }

    var normalized: LFloat3 {
        let magnitude = magnitude
        return magnitude == 0
            ? .zero
            : self / magnitude
    }
    
    mutating func normalize() -> LFloat3 {
        self = self / magnitude
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

public extension LFloat4 {
    var xyz: LFloat3 {
        LFloat3(xyzSource: self)
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
