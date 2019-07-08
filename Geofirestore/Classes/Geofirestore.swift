import Foundation
import CoreLocation
import FirebaseCore
import FirebaseFirestore
import GeoFire

public extension GeoPoint {
    class func geopointWithLocation(location: CLLocation) -> GeoPoint {
        return GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
    
    public func locationValue() -> CLLocation {
        return CLLocation(latitude: self.latitude, longitude: self.longitude)
    }
}

public extension CLLocation {
    class func locationWithGeopoint(geopoint: GeoPoint) -> CLLocation {
        return CLLocation(latitude: geopoint.latitude, longitude: geopoint.longitude)
    }
    
    public func geopointValue() -> GeoPoint {
        return GeoPoint(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
    }
}

/**
 * A GeoFirestore instance is used to store geo location data at a Firestore document.
 */
public class GeoFirestore {
    
    public typealias GFSCompletionBlock = (Error?) -> Void
    public typealias GFSLocationCallback = (CLLocation?, Error?) -> Void
    public typealias GFSGeoPointCallback = (GeoPoint?, Error?) -> Void
    
    /**
     * The Firestore collection reference this GeoFirestore instance uses.
     */
    public var collectionRef: CollectionReference
    
    /**
     * The dispatch queue this GeoFirestore object and all its GFSQueries use for callbacks.
     */
    internal var callbackQueue: DispatchQueue
    
    /** @name Creating new `GeoFirestore` objects */
    
    /**
     * Initializes a new GeoFirestore instance using a given Firestore collection.
     * @param collectionRef The Firestore collection to attach this `GeoFirestore` instance to
     */
    public init(collectionRef: CollectionReference) {
        self.collectionRef = collectionRef
        self.callbackQueue = DispatchQueue.main
    }
    
    public func getCollectionReference() -> CollectionReference {
        return collectionRef
    }
    
    /**
     * Updates the location for a document and calls the completion callback once the location was successfully updated on the
     * server.
     * @param geopoint The location as a geographic coordinate (`GeoPoint`)
     * @param documentID The documentID of the document for which this location is saved
     * @param completion The completion block that is called once the location was successfully updated on the server
     */
    public func setLocation(geopoint: GeoPoint, forDocumentWithID documentID: String, completion: GFSCompletionBlock? = nil) {
        let location = geopoint.locationValue()
        if CLLocationCoordinate2DIsValid(location.coordinate) {
            if let geoHash = GFGeoHash(location: location.coordinate).geoHashValue {
                self.collectionRef.document(documentID).setData(["l": geopoint, "g": geoHash], mergeFields: ["g", "l"], completion: completion)
            }
            else {
                print("GEOFIRESTORE ERROR: Couldn't calculate geohash.")
            }
        }
        else {
            NSException.raise(NSExceptionName.invalidArgumentException, format: "Invalid coordinates!", arguments: getVaList(["nil"]))
        }
    }
    
    /**
     * Updates the location for a document and calls the completion callback once the location was successfully updated on the
     * server.
     * @param location The location as a geographic coordinate (`CLLocation`)
     * @param documentID The documentID of the document for which this location is saved
     * @param completion The completion block that is called once the location was successfully updated on the server
     */
    public func setLocation(location: CLLocation, forDocumentWithID documentID: String, completion: GFSCompletionBlock? = nil) {
        if CLLocationCoordinate2DIsValid(location.coordinate) {
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            if let geoHash = GFGeoHash(location: location.coordinate).geoHashValue {
                self.collectionRef.document(documentID).setData(["l": [lat, lon], "g": geoHash], mergeFields: ["g", "l"], completion: completion)
            }
            else {
                print("GEOFIRESTORE ERROR: Couldn't calculate geohash.")
            }
        }
        else {
            NSException.raise(NSExceptionName.invalidArgumentException, format: "Invalid coordinates!", arguments: getVaList(["nil"]))
        }
    }
    
    /**
     * Removes the location for a document with a given documentID and calls the completion callback once the location was successfully updated on
     * the server.
     * @param documentID The documentID of the document for which this location is removed
     * @param completion The completion block that is called once the location was successfully updated on the server
     */
    public func removeLocation(forDocumentWithID documentID: String, completion: GFSCompletionBlock? = nil){
        self.collectionRef.document(documentID).updateData(["l": FieldValue.delete(), "g": FieldValue.delete()], completion: completion)
    }
    
    /**
     * Gets the current location for the document with the given documentID and calls the callback with the location or nil if there is no
     * location for the document. If an error occurred, the callback will be called with the error and location
     * will be nil.
     * @param documentID The documentID of the document to observe the location for
     * @param callback The callback that is called for the current location (as a `GeoPoint`)
     */
    public func getLocation(forDocumentWithID documentID: String, callback: GFSGeoPointCallback? = nil) {
        self.collectionRef.document(documentID).getDocument { (snap, err) in
            if let l = snap?.get("l") as? [Double?], let lat = l[0], let lon = l[1] {
                let geoPoint = GeoPoint(latitude: lat, longitude: lon)
                callback?(geoPoint, err)
            } else if let geoPoint = snap?.get("l") as? GeoPoint {
                callback?(geoPoint, err)
            }
            callback?(nil, err)
        }
    }
    
    /**
     * Gets the current location for the document with the given documentID and calls the callback with the location or nil if there is no
     * location for the document. If an error occurred, the callback will be called with the error and location
     * will be nil.
     * @param documentID The documentID of the document to observe the location for
     * @param callback The callback that is called for the current location (as a `CLLocation`)
     */
    public func getLocation(forDocumentWithID documentID: String, callback: GFSLocationCallback? = nil) {
        self.collectionRef.document(documentID).getDocument { (snap, err) in
            if let l = snap?.get("l") as? [Double?], let lat = l[0], let lon = l[1] {
                let loc = CLLocation(latitude: lat, longitude: lon)
                callback?(loc, err)
            } else if let geoPoint = snap?.get("l") as? GeoPoint {
                let loc = geoPoint.locationValue()
                callback?(loc, err)
            }
            callback?(nil, err)
        }
    }
    
    /**
     * Creates a new GeoFirestore query centered at a given location with a given radius. The `GFSQuery` object can be used to query documents that enter, move, and exit the search radius.
     * @param location The location at which the query is centered (as a `GeoPoint`)
     * @param radius The radius in kilometers of the geo query
     * @return The `GFSCircleQuery` object that can be used for geo queries.
     */
    public func query(withCenter center: GeoPoint, radius: Double) -> GFSCircleQuery {
        return GFSCircleQuery(geoFirestore: self, center: center.locationValue(), radius: radius)
    }
    
    /**
     * Creates a new GeoFirestore query centered at a given location with a given radius. The `GFSQuery` object can be used to query documents that enter, move, and exit the search radius.
     * @param location The location at which the query is centered (as a CLLocation)
     * @param radius The radius in kilometers of the geo query
     * @return The `GFSCircleQuery` object that can be used for geo queries.
     */
    public func query(withCenter center: CLLocation, radius: Double) -> GFSCircleQuery {
        return GFSCircleQuery(geoFirestore: self, center: center, radius: radius)
    }
    
    /**
     * Creates a new GeoFirestore query for a given region. The GFSQuery object can be used to query
     * documents that enter, move, and exit the search region.
     * @param region The region which this query searches
     * @return The GFSRegionQuery object that can be used for geo queries.
     */
    public func query(inRegion region: MKCoordinateRegion) -> GFSRegionQuery{
        return GFSRegionQuery(geoFirestore: self, region: region)
    }
    
}



public enum GFSEventType {
    case documentEntered
    case documentExited
    case documentMoved
}



public typealias GFSQueryResultBlock = (String?, CLLocation?) -> Void
public typealias GFSReadyBlock = () -> Void
public typealias GFSQueryHandle = UInt

internal class GFSGeoHashQueryListener {
    var childAddedListener: ListenerRegistration?
    var childRemovedListener: ListenerRegistration?
    var childChangedListener: ListenerRegistration?
}


/**
 * A GFSQuery object handles geo queries in a Firestore collection.
 */
public class GFSQuery {
    internal class GFSQueryLocationInfo {
        var isInQuery: Bool?
        var location: CLLocation?
        var geoHash: GFGeoHash?
    }
    
    /**
     * The GeoFirestore this GFSQuery object uses.
     */
    public var geoFirestore: GeoFirestore
    
    /**
     * Limits the number of results from our Query
     */
    public var searchLimit: Int?
    
    internal var locationInfos = [String: GFSQueryLocationInfo]()
    internal var queries = Set<GFGeoHashQuery>()
    internal var handles = [GFGeoHashQuery: GFSGeoHashQueryListener]()
    internal var outstandingQueries = Set<GFGeoHashQuery>()
    
    internal var keyEnteredObservers = [GFSQueryHandle: GFSQueryResultBlock]()
    internal var keyExitedObservers = [GFSQueryHandle: GFSQueryResultBlock]()
    internal var keyMovedObservers = [GFSQueryHandle: GFSQueryResultBlock]()
    internal var readyObservers = [GFSQueryHandle: GFSReadyBlock]()
    
    internal var currentHandle: UInt
    
    internal var listenerForHandle = [GFSQueryHandle: ListenerRegistration]()
    
    internal init(geoFirestore: GeoFirestore) {
        self.geoFirestore = geoFirestore
        currentHandle = 1
        self.reset()
    }
    
    internal func fireStoreQueryForGeoHashQuery(query: GFGeoHashQuery) -> Query {
        var query = self.geoFirestore.collectionRef.order(by: "g").whereField("g", isGreaterThanOrEqualTo: query.startValue).whereField("g", isLessThanOrEqualTo: query.endValue)
        if let limit = self.searchLimit {
            query = query.limit(to: limit)
        }
        return query
    }
    
    //overriden
    internal func locationIsInQuery(loc: CLLocation) -> Bool {
        fatalError("Override in subclass.")
    }
    
    internal func queriesForCurrentCriteria() -> Set<AnyHashable> {
        fatalError("Override in subclass.")
    }
    
    internal func updateLocationInfo(_ location: CLLocation, forKey key: String) {
        var info: GFSQueryLocationInfo? = locationInfos[key]
        var isNew = false
        if info == nil {
            isNew = true
            info = GFSQueryLocationInfo()
            locationInfos[key] = info
        }
        
        let changedLocation: Bool = !isNew && !(info?.location?.coordinate.latitude == location.coordinate.latitude && info?.location!.coordinate.longitude == location.coordinate.longitude)
        let wasInQuery = info?.isInQuery
        
        // we know it exists now so force unwrap is ok
        info!.location = location
        info!.isInQuery = locationIsInQuery(loc: location)
        info!.geoHash = GFGeoHash.new(withLocation: location.coordinate)
        
        if (isNew || !(wasInQuery ?? false)) && info?.isInQuery != nil {
            for (offset: _, element: (key: _, value: block)) in keyEnteredObservers.enumerated() {
                self.geoFirestore.callbackQueue.async {
                    block(key, info!.location)
                }
            }
        } else if !isNew && changedLocation && info?.isInQuery != nil {
            for (offset: _, element: (key: _, value: block)) in keyMovedObservers.enumerated() {
                self.geoFirestore.callbackQueue.async {
                    block(key, info!.location)
                }
            }
        } else if wasInQuery ?? false && info?.isInQuery == nil {
            for (offset: _, element: (key: _, value: block)) in keyExitedObservers.enumerated() {
                self.geoFirestore.callbackQueue.async {
                    block(key, info!.location)
                }
            }
        }
    }
    
    internal func queriesContain(_ geoHash: GFGeoHash?) -> Bool {
        for query: GFGeoHashQuery? in queries {
            if query?.contains(geoHash) != nil {
                return true
            }
        }
        return false
    }
    
    internal func childAdded(_ snapshot: DocumentSnapshot?) {
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            
            if let key = snapshot?.documentID {
                if let l = snapshot?.get("l") as? [Double?], let lat = l[0], let lon = l[1] {
                    let location = CLLocation(latitude: lat, longitude: lon)
                    updateLocationInfo(location, forKey: key)
                } else if let l = snapshot?.get("l") as? GeoPoint {
                    let location = l.locationValue()
                    updateLocationInfo(location, forKey: key)
                } else{
                    //TODO: error??
                }
                
            }
        }
    }
    
    internal func childChanged(_ snapshot: DocumentSnapshot?) {
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            
            if let key = snapshot?.documentID {
                if let l = snapshot?.get("l") as? [Double?], let lat = l[0], let lon = l[1] {
                    let location = CLLocation(latitude: lat, longitude: lon)
                    updateLocationInfo(location, forKey: key)
                } else if let l = snapshot?.get("l") as? GeoPoint {
                    let location = l.locationValue()
                    updateLocationInfo(location, forKey: key)
                } else{
                    //TODO: error??
                }
                
            }
            
        }
    }
    
    internal func childRemoved(_ snapshot: DocumentSnapshot?) {
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            
            if let snapshot = snapshot {
                
                var info: GFSQueryLocationInfo? = nil
                let key = snapshot.documentID
                info = locationInfos[key]
                if info != nil {
                    if let l = snapshot.get("l") as? [Double?], let lat = l[0], let lon = l[1]{
                        let location = CLLocation(latitude: lat, longitude: lon)
                        let geoHash = GFGeoHash(location: location.coordinate)
                        // Only notify observers if key is not part of any other geohash query or this actually might not be
                        // a key exited event, but a key moved or entered event. These events will be triggered by updates
                        // to a different query
                        if self.queriesContain(geoHash) {
                            let info: GFSQueryLocationInfo? = self.locationInfos[key]
                            self.locationInfos.removeValue(forKey: key)
                            // Key was in query, notify about key exited
                            if info?.isInQuery != nil {
                                for (offset: _, element: (key: _, value: block)) in self.keyExitedObservers.enumerated() {
                                    self.geoFirestore.callbackQueue.async {
                                        block(key, info!.location)
                                    }
                                }
                            }
                        }
                    } else if let l = snapshot.get("l") as? GeoPoint {
                        let location = l.locationValue()
                        let geoHash = GFGeoHash(location: location.coordinate)
                        // Only notify observers if key is not part of any other geohash query or this actually might not be
                        // a key exited event, but a key moved or entered event. These events will be triggered by updates
                        // to a different query
                        if self.queriesContain(geoHash) {
                            let info: GFSQueryLocationInfo? = self.locationInfos[key]
                            self.locationInfos.removeValue(forKey: key)
                            // Key was in query, notify about key exited
                            if info?.isInQuery != nil {
                                for (offset: _, element: (key: _, value: block)) in self.keyExitedObservers.enumerated() {
                                    self.geoFirestore.callbackQueue.async {
                                        block(key, info!.location)
                                    }
                                }
                            }
                        }
                    }
                    
                }
            }
            
        }
    }
    
    internal func searchCriteriaDidChange() {
        if !queries.isEmpty {
            updateQueries()
        }
    }
    
    internal func checkAndFireReadyEvent() {
        if outstandingQueries.count == 0 {
            for (offset: _, element: (key: _, value: block)) in readyObservers.enumerated() {
                self.geoFirestore.callbackQueue.async {
                    block()
                }
            }
        }
    }
    
    internal func updateQueries() {
        let oldQueries = queries
        let newQueries = queriesForCurrentCriteria()
        
        var toDelete = (Set<AnyHashable>().union(oldQueries))
        toDelete.subtract(newQueries)
        var toAdd = (Set<AnyHashable>().union(newQueries))
        toAdd.subtract(oldQueries)
        
        for (offset: _, element: query) in toDelete.enumerated(){
            if let query = query as? GFGeoHashQuery{
                
                let handle: GFSGeoHashQueryListener? = handles[query]
                if handle == nil {
                    NSException.raise(.internalInconsistencyException, format: "Wanted to remove a geohash query that was not registered!", arguments: getVaList(["nil"]))
                }
                
                
                handle!.childAddedListener?.remove()
                handle!.childRemovedListener?.remove()
                handle!.childChangedListener?.remove()
                
                self.handles.removeValue(forKey: query)
                self.outstandingQueries.remove(query)
                
            }
            
        }
        
        for (offset: _, element: query) in toAdd.enumerated(){
            if let query = query as? GFGeoHashQuery{
                
                self.outstandingQueries.insert(query)
                let handle = GFSGeoHashQueryListener()
                let queryFirestore: Query = self.fireStoreQueryForGeoHashQuery(query: query)
                
                handle.childAddedListener = queryFirestore.addSnapshotListener { (querySnapshot: QuerySnapshot?, err) in
                    if let snapshot = querySnapshot, err == nil {
                        for docChange in snapshot.documentChanges {
                            if docChange.type == DocumentChangeType.added {
                                self.childAdded(docChange.document)
                            }
                        }
                    }
                }
                
                handle.childChangedListener = queryFirestore.addSnapshotListener { (querySnapshot: QuerySnapshot?, err) in
                    if let snapshot = querySnapshot, err == nil {
                        for docChange in snapshot.documentChanges {
                            if docChange.type == DocumentChangeType.modified {
                                self.childChanged(docChange.document)
                            }
                        }
                    }
                }
                
                handle.childRemovedListener = queryFirestore.addSnapshotListener { (querySnapshot: QuerySnapshot?, err) in
                    if let snapshot = querySnapshot, err == nil {
                        for docChange in snapshot.documentChanges {
                            if docChange.type == DocumentChangeType.removed {
                                self.childRemoved(docChange.document)
                            }
                        }
                    }
                }
                
                self.handles[query] = handle
                
                queryFirestore.getDocuments { (snapshot, error) in
                    if error == nil {
                        let lockQueue = DispatchQueue(label: "self")
                        lockQueue.sync {
                            while let elementIndex = self.outstandingQueries.index(of: query) { self.outstandingQueries.remove(at: elementIndex) }
                            self.checkAndFireReadyEvent()
                        }
                    }
                }
                
            }
        }
        
        queries = newQueries as! Set<GFGeoHashQuery>
        for (offset: _, element: (key: key, value: info)) in self.locationInfos.enumerated(){
            if let location = info.location{
                self.updateLocationInfo(location, forKey: key)
            }
        }
        var oldLocations = [String]()
        for (offset: _, element: (key: key, value: info)) in self.locationInfos.enumerated(){
            if !self.queriesContain(info.geoHash) {
                oldLocations.append(key)
            }
        }
        for k in oldLocations { locationInfos.removeValue(forKey: k) }
        checkAndFireReadyEvent()
    }
    
    internal func reset() {
        for query in queries {
            guard let handle = self.handles[query] else {
                NSException.raise(.internalInconsistencyException, format: "Wanted to remove a geohash query that was not registered!", arguments: getVaList(["nil"]))
                return
            }
            handle.childAddedListener?.remove()
            handle.childChangedListener?.remove()
            handle.childRemovedListener?.remove()
        }

        locationInfos.removeAll()
        queries.removeAll()
        handles.removeAll()
        outstandingQueries.removeAll()
        
        keyEnteredObservers.removeAll()
        keyExitedObservers.removeAll()
        keyMovedObservers.removeAll()
        readyObservers.removeAll()
    }
    
    public func totalObserverCount() -> Int {
        return keyEnteredObservers.count + keyExitedObservers.count + keyMovedObservers.count + readyObservers.count
    }
    
    /*!
     Adds an observer for an event type.
     The following event types are supported:
     typedef NS_ENUM(NSUInteger, GFEventType) {
     GFSEventType.documentEntered, // A document entered the search area
     GFSEventType.documentExited,  // A document exited the search area
     GFSEventType.documentMoved    // A document moved within the search area
     };
     The block is called for each event and document.
     Use removeObserver:withHandle: to stop receiving callbacks.
     @param eventType The event type to receive updates for
     @param block The block that is called for updates
     @return A handle to remove the observer with
     */
    public func observe(_ eventType: GFSEventType, with block: @escaping GFSQueryResultBlock) -> GFSQueryHandle {
        let lockQueue = DispatchQueue(label: "self")
        var firebaseHandle: GFSQueryHandle = 0
        lockQueue.sync {
            
            currentHandle += 1
            firebaseHandle = currentHandle
            
            switch eventType {
            case .documentEntered:
                keyEnteredObservers[firebaseHandle] = block
                currentHandle += 1
                
                geoFirestore.callbackQueue.async(execute: {
                    lockQueue.sync {
                        for (offset: _, element: (key: key, value: info)) in self.locationInfos.enumerated(){
                            if info.isInQuery != nil{
                                block(key, info.location)
                            }
                        }
                    }
                })
            case .documentExited:
                keyExitedObservers[firebaseHandle] = block
                currentHandle += 1
            case .documentMoved:
                keyMovedObservers[firebaseHandle] = block
                currentHandle += 1
            default:
                NSException.raise(.invalidArgumentException, format: "Event type was not a GFEventType!", arguments: getVaList(["nil"]))
            }
            if self.queries.isEmpty {
                self.updateQueries()
            }
        }
        return firebaseHandle
        
    }
    
    /**
     * Adds an observer that is called once all initial GeoFirestore data has been loaded and the relevant events have
     * been fired for this query. Every time the query criteria is updated, this observer will be called after the
     * updated query has fired the appropriate document entered or document exited events.
     *
     * @param block The block that is called for the ready event
     * @return A handle to remove the observer with
     */
    public func observeReady(withBlock block: @escaping GFSReadyBlock) -> GFSQueryHandle {
        let lockQueue = DispatchQueue(label: "self")
        var firebaseHandle: GFSQueryHandle = 0
        lockQueue.sync {
            
            currentHandle += 1
            firebaseHandle = currentHandle
            readyObservers[firebaseHandle] = block
            if self.queries.isEmpty {
                self.updateQueries()
            }
            if self.outstandingQueries.count == 0{
                self.geoFirestore.callbackQueue.async {
                    block()
                }
            }
            
        }
        return firebaseHandle
    }
    
    /**
     * Removes a callback with a given GFSQueryHandle. After this no further updates are received for this handle.
     * @param handle The handle that was returned by observe:with:
     */
    public func removeObserver(withHandle handle: GFSQueryHandle) {
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            listenerForHandle[handle]?.remove()
            keyEnteredObservers.removeValue(forKey: handle)
            keyExitedObservers.removeValue(forKey: handle)
            keyMovedObservers.removeValue(forKey: handle)
            readyObservers.removeValue(forKey: handle)
            
            if totalObserverCount() == 0 {
                reset()
            }
            
        }
    }
    
    /**
     * Removes all observers for this GFSQuery object. Note that with multiple GFSQuery objects only this object stops
     * its callbacks.
     */
    public func removeAllObservers() {
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            reset()
        }
    }
    
}



public class GFSCircleQuery: GFSQuery {
    
    /**
     * The center of the search area. Update this value to update the query. Events are triggered for any documents that move
     * in or out of the search area.
     */
    public var center: CLLocation {
        didSet {
            self.searchCriteriaDidChange()
        }
    }
    
    /**
     * The radius of the geo query in kilometers. Update this value to update the query. Events are triggered for any documents
     * that move in or out of the search area.
     */
    public var radius: Double {
        didSet {
            self.searchCriteriaDidChange()
        }
    }
    
    public init(geoFirestore: GeoFirestore, center: CLLocation, radius: Double) {
        self.radius = radius
        self.center = center
        super.init(geoFirestore: geoFirestore)
    }
    
    override internal func locationIsInQuery(loc: CLLocation) -> Bool {
        return loc.distance(from: self.center) <= (self.radius * 1000.0)
    }
    
    override internal func queriesForCurrentCriteria() -> Set<AnyHashable> {
        return GFGeoHashQuery.queries(forLocation: self.center.coordinate, radius: (self.radius * 1000.0))
    }
}



public class GFSRegionQuery: GFSQuery {
    
    /**
     * The region to search for this query. Update this value to update the query. Events are triggered for any documents that
     * move in or out of the search area.
     */
    public var region: MKCoordinateRegion {
        didSet {
            self.searchCriteriaDidChange()
        }
    }
    
    public init(geoFirestore: GeoFirestore, region: MKCoordinateRegion) {
        self.region = region
        super.init(geoFirestore: geoFirestore)
    }
    
    override internal func locationIsInQuery(loc: CLLocation) -> Bool {
        let north = CLLocationDegrees(region.center.latitude + region.span.latitudeDelta / 2)
        let south = CLLocationDegrees(region.center.latitude - region.span.latitudeDelta / 2)
        let west = CLLocationDegrees(region.center.longitude - region.span.longitudeDelta / 2)
        let east = CLLocationDegrees(region.center.longitude + region.span.longitudeDelta / 2)
        let coordinate: CLLocationCoordinate2D = loc.coordinate
        return coordinate.latitude <= north && coordinate.latitude >= south && coordinate.longitude >= west && coordinate.longitude <= east
    }
    
    override internal func queriesForCurrentCriteria() -> Set<AnyHashable> {
        return GFGeoHashQuery.queries(for: self.region)
    }
}

