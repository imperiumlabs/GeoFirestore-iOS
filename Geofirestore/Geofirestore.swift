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

typealias GFQueryCallback = (() -> Void)

class Geofirestore {
    var geofirestoreCollectionRef: CollectionReference!
    
    init(collectionRef: CollectionReference!) {
        self.geofirestoreCollectionRef = collectionRef
    }
    
}

