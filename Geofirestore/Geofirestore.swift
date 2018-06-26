//
//  Geofirestore.swift
//  Geofirestore
//
//  Created by Dhruv Shah on 6/26/18.
//  Copyright © 2018 hello. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import Firebase
import FirebaseFirestore
import GeoFire

//Creates a GeoFirestore instance.

class Geofirestore {
    
    public typealias Block = () -> Void
    public typealias AddBlock = (DocumentReference) -> Void

    private var _collectionRef: CollectionReference!
    
    init(_collectionRef: CollectionReference) {
        self._collectionRef = _collectionRef

    }
    
    //PUBLIC METHODS
    
    //Adds document to Firestore
    
    func add(document: DocumentReference, customKey: String? = nil, completionHandler: AddBlock? = nil){
        
    }
    
    
}

