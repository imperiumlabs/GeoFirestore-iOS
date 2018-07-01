# GeoFirestore for iOS — Realtime location queries with Firestore

GeoFirestore is an open-source library for Swift that allows you to store and query a set of documents based on their geographic location.

At its heart, GeoFirestore simply stores locations with string keys. Its main benefit however, is the possibility of querying documents within a given geographic area - all in realtime.

GeoFirestore uses the Firestore database for data storage, allowing query results to be updated in realtime as they change. GeoFirestore selectively loads only the data near certain locations, keeping your applications light and responsive, even with extremely large datasets.

### Integrating GeoFirestore with your data

GeoFirestore is designed as a lightweight add-on to Firestore. However, to keep things simple, GeoFirestore stores data in its own format and its own location within your Firestore database. This allows your existing data format and security rules to remain unchanged and for you to add GeoFirestore as an easy solution for geo queries without modifying your existing data.

### Example usage

Assume you are building an app to rate bars, and you store all information for a bar (e.g. name, business hours and price range) at `collection(bars).document(bar-id)`. Later, you want to add the possibility for users to search for bars in their vicinity. This is where GeoFirestore comes in. You can store the location for each bar document using GeoFirestore. GeoFirestore then allows you to easily query which bar are nearby.

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Downloading GeoFirestore for iOS

If you're using [CocoaPods](https://cocoapods.org/) add the following to your Podfile:

```
pod ‘Geofirestore'
```

## Getting Started with Firestore

GeoFirestore requires the Firestore database in order to store location data. You can [learn more about Firestore here](https://firebase.google.com/docs/firestore/).

## Using GeoFirestore

### GeoFirestore

A `GeoFirestore` object is used to read and write geo location data to your Firestore database and to create queries. To create a new `GeoFirestore` instance you need to attach it to a Firestore collection reference:

````swift
let geoFirestoreRef = Firestore.firestore().collection("my-collection")
let geoFirestore = GeoFirestore(collectionRef: geoFirestoreRef)
````

#### Setting location data

To set the location of a document simply call the `setLocation` method:

````swift
geoFirestore.setLocation(location: CLLocation(latitude: 37.7853889, longitude: -122.4056973), forDocumentWithID: "que8B9fxxjcvbC81h32VRjeBSUW2") { (error) in
    if (error != nil) {
        print("An error occured: \(error)")
    } else {
        print("Saved location successfully!")
    }
}
````
Alternatively set the location using a `GeoPoint` :

````swift
geoFirestore.setLocation(geopoint: GeoPoint(latitude: 37.7853889, longitude: -122.4056973), forDocumentWithID: "que8B9fxxjcvbC81h32VRjeBSUW2") { (error) in
    if (error != nil) {
        print("An error occured: \(error)")
    } else {
        print("Saved location successfully!")
    }
}
````
To remove a location and delete the location from your database simply call:

````swift
geoFirestore.removeLocation(forDocumentWithID: "que8B9fxxjcvbC81h32VRjeBSUW2") 
````

#### Retrieving a location

Retrieving locations happens with callbacks. If the document is not present in GeoFirestore, the callback will be called with `nil`. If an error occurred, the callback is passed the error and the location will be `nil`.

````swift
geoFirestore.getLocation(forDocumentWithID: "que8B9fxxjcvbC81h32VRjeBSUW2") { (location: CLLocation?, error) in
    if (error != nil) {
        print("An error occurred: \(error)")
    } else if (location != nil) {
        print("Location: [\(location!.coordinate.latitude), \(location!.coordinate.longitude)]")
    } else {
        print("GeoFirestore does not contain a location for this document")
    }
}
````

Alternatively get the location as a `GeoPoint` :

````swift
geoFirestore.getLocation(forDocumentWithID: "que8B9fxxjcvbC81h32VRjeBSUW2") { (location: GeoPoint?, error) in
    if (error != nil) {
        print("An error occurred: \(error)")
    } else if (location != nil) {
        print("Location: [\(location!.latitude), \(location!.longitude)]")
    } else {
        print("GeoFirestore does not contain a location for this document")
    }
}
````
### GeoFirestore Queries

GeoFirestore allows you to query all documents within a geographic area using `GFSQuery`
objects. As the locations for documents change, the query is updated in realtime and fires events
letting you know if any relevant documents have moved. `GFSQuery` parameters can be updated
later to change the size and center of the queried area.

````swift
// Query using CLLocation
let center = CLLocation(latitude: 37.7832889, longitude: -122.4056973)
// Query locations at [37.7832889, -122.4056973] with a radius of 600 meters
var circleQuery = geoFirestore.query(withCenter: center, radius: 0.6)

// Query using GeoPoint
let center2 = GeoPoint(latitude: 37.7832889, longitude: -122.4056973)
// Query locations at [37.7832889, -122.4056973] with a radius of 600 meters
var circleQuery2 = geoFirestore.query(withCenter: center2, radius: 0.6)

// Query location by region
let span = MKCoordinateSpanMake(0.001, 0.001)
let region = MKCoordinateRegionMake(center.coordinate, span)
var regionQuery = geoFirestore.query(inRegion: region)
````
#### Receiving events for geo queries

There are three kinds of events that can occur with a geo query:

1. **Document Entered**: The location of a document now matches the query criteria.
2. **Document Exited**: The location of a document no longer matches the query criteria.
3. **Document Moved**: The location of a document changed but the location still matches the query criteria.

Document entered events will be fired for all documents initially matching the query as well as any time
afterwards that a document enters the query. Document moved and document exited events are guaranteed to be preceded by a document entered event.

To observe events for a geo query you can register a callback with `observe:with:`:

````swift
let queryHandle = query.observe(.documentEntered, with: { (key, location) in
    print("The document with documentID '\(key)' entered the search area and is at location '\(location)'")
})
````

To cancel one or all callbacks for a geo query, call
`removeObserver:withHandle:` or `removeAllObservers:`, respectively.

#### Waiting for queries to be "ready"

Sometimes you want to know when the data for all the initial documents has been
loaded from the server and the corresponding events for those documents have been
fired. For example, you may want to hide a loading animation after your data has
fully loaded. `GFSQuery` offers a method to listen for these ready events:

````swift
query.observeReady {
    print("All initial data has been loaded and events have been fired!")
}
````
Note that locations might change while initially loading the data and document moved and document
exited events might therefore still occur before the ready event was fired.

When the query criteria is updated, the existing locations are re-queried and the
ready event is fired again once all events for the updated query have been
fired. This includes document exited events for documents that no longer match the query.

#### Updating the query criteria

To update the query criteria you can use the `center` and `radius` properties on
the `GFSQuery` object. Document exited and document entered events will be fired for
documents moving in and out of the old and new search area, respectively. No document moved
events will be fired as a result of the query criteria changing; however, document moved
events might occur independently.

#### Convenient extensions 

To make it easier to convert between a `GeoPoint`  and a `CLLocation` we have provided some useful extensions: 

````swift
let cllocation = CLLocation(latitude: 37.7832889, longitude: -122.4056973)
let geopoint = GeoPoint(latitude: 37.7832889, longitude: -122.4056973)

// Converting from CLLocation to Geopoint
let loc1: GeoPoint = cllocation.geopointValue()
let loc2: GeoPoint = GeoPoint.geopointWithLocation(location: cllocation)

// Converting from Geopoint to CLLocation
let loc3: CLLocation = geopoint.locationValue()
let loc4: CLLocation = CLLocation.locationWithGeopoint(geopoint: geopoint)
````

## API Reference & Documentation

Full API reference and documentation is available [here](apilink)

## License

GeoFirestore is available under the MIT license. See the LICENSE file for more info.

Copyright (c) 2018 Imperium Labs


