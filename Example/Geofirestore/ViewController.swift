//
//  ViewController.swift
//  Geofirestore
//
//  Created by dhruvshah1214 on 06/30/2018.
//  Copyright (c) 2018 dhruvshah1214. All rights reserved.
//

import UIKit
import Firebase
import Geofirestore
import CoreLocation
import MapKit


let sfCoordinate = CLLocation(latitude: 37.7749, longitude: -122.4194)

class ViewController: UIViewController, MKMapViewDelegate {
    
    var collectionRef: CollectionReference!
    var geoFirestore: GeoFirestore!
    var sfQuery: GFSQuery!
    
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        collectionRef = Firestore.firestore().collection("geoloc-test")

        //creates the geoFirestore object and point it to a Firestore collection reference containing documents to geoquery on
        geoFirestore = GeoFirestore(collectionRef: collectionRef)

        //queries for everything within 1 km of central SF
        sfQuery = geoFirestore.query(withCenter: sfCoordinate, radius: 50.0)
        
        // for dropping pins on map
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(ViewController.mapLongPress(_:)))
        longPress.minimumPressDuration = 1
        mapView.addGestureRecognizer(longPress)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        //sets map bounds
        self.mapView.setRegion(MKCoordinateRegion(center: sfCoordinate.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)), animated: true)
        
        let _ = sfQuery.observe(.documentEntered, with: { (key, location) in
            if let key = key, let loc = location {
                let newPin = MKPointAnnotation()
                newPin.coordinate = loc.coordinate
                newPin.title = key
                self.mapView.addAnnotation(newPin)
            }
        })
        
        //uses Handles to remove queries
        let _ = sfQuery.observe(.documentExited, with: { (key, location) in
            if let key = key {
                if let ann = 
                    self.mapView.annotations.first(where: { (annotation) -> Bool in
                        return annotation.title == key
                    }) 
                {
                    DispatchQueue.main.async {
                        self.mapView.removeAnnotation(ann)
                    }
                    print("Removed \(key)!")
                }
            }
        })
    }
    
    @objc func mapLongPress(_ recognizer: UIGestureRecognizer) {
        let touchedAt = recognizer.location(in: self.mapView)
        let touchedAtCoordinate: CLLocationCoordinate2D = mapView.convert(touchedAt, toCoordinateFrom: self.mapView)
        
        //uploads to Firestore
        geoFirestore.setLocation(location: CLLocation(latitude: touchedAtCoordinate.latitude, longitude: touchedAtCoordinate.longitude), forDocumentWithID: collectionRef.document().documentID) { (err) in
            if let error = err {
                print("ERROR CREATING DOCUMENT")
                print(error)
            }
        }
    }

}

