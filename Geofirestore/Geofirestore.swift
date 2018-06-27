//
//  Geofirestore.swift
//  Geofirestore
//
//  Created by Nikhil Sridhar on 6/27/18.
//  Copyright © 2018 hello. All rights reserved.
//

import Foundation
import Firebase
import CoreLocation

class Geofirestore {
    
    typealias Block = (Error?) -> Void
    typealias LocationBlock = (GeoPoint?, Error?) -> Void
    
    var collectionRef: CollectionReference

    init(collectionRef: CollectionReference) {
        self.collectionRef = collectionRef
    }
    
    func setLocationForDocument(withDocumentID documentID: String, location: GeoPoint, completion: Block? = nil){
        let b = GeoPoint(latitude: 180, longitude: 200)
    }
    
    func getLocationForDocument(withDocumentID documentID: String, completion: LocationBlock? = nil){
        
    }
    
    func removeLocationForDocument(withDocumentID documentID: String, completion: Block? = nil){
        
    }
    
    func getCollectionReference() -> CollectionReference{
        return collectionRef
    }
    
    func query(withCenter center: GeoPoint, radius: Double){
        
    }
    
    static func distance(location1: GeoPoint, location2: GeoPoint) -> Double{
        return 0
    }
}
