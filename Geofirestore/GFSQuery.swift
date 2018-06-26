//
//  GFSQuery.swift
//  Geofirestore
//
//  Created by Nikhil Sridhar on 6/26/18.
//  Copyright © 2018 hello. All rights reserved.
//

import Foundation
import CoreLocation

class GFSQuery {
    
    typealias FirebaseHandle = UInt
    
    enum GFSEventType{
        case GFSEventTypeKeyEntered
        case GFSEventTypeKeyExited
        case GFSEventTypeKeyMoved
    }
    
    typealias GFSQueryResultBlock = (String, CLLocation) -> Void
    typealias GFSReadyBlock = () -> Void
    
    var geoFirestore: Geofirestore!
    
    var locationInfos: [String: Any]!
    var keyExitedObservers: [String: Any]!
    var keyMovedObservers: [String: Any]!
    var readyObservers: [String: Any]!
    var currentHandler: UInt!
    
    func observeEventType(eventType: GFSEventType, withBlock block: GFSQueryResultBlock) -> FirebaseHandle{
        return 0
    }
    
    func observeReadyWithBlock(block: GFSReadyBlock) -> FirebaseHandle {
        return 0
    }
    
    func removeObserverWithFirebaseHandle(handle: FirebaseHandle) {
        
    }
    
    func removeAllObservers(){
        
    }
}
