//  
//
//  Created on 11/11/23.
//  

import Foundation

//// Make this an extension for a target value because hell yes why double up on objects..
//// Can't believe I used a struct. wut. muh memory.
public class CachedValue<T> {
    public private(set) lazy var value: T = update()
    
    public private(set) var willUpdate = true
    public var update: () -> T
    
    public init(update: @escaping () -> T) {
        self.update = update
    }
    
    public func dirty() {
        willUpdate = true
    }
    
    public func set(_ new: T) {
        willUpdate = false
        value = new
    }
    
    public func updateNow() {
        value = update()
        willUpdate = false
    }
    
    public func get() -> T {
        guard willUpdate
        else { return value }
        value = update()
        willUpdate = false
        return value
    }
}
