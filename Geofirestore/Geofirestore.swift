import Foundation
import Firebase
import CoreLocation
import GeoFire



// COMPLETE
extension GeoPoint {
    class func geopointWithLocation(location: CLLocation) -> GeoPoint {
        return GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
    
    func locationValue() -> CLLocation {
        return CLLocation(latitude: self.latitude, longitude: self.longitude)
    }
}

// COMPLETE
extension CLLocation {
    class func locationWithGeopoint(geopoint: GeoPoint) -> CLLocation {
        return CLLocation(latitude: geopoint.latitude, longitude: geopoint.longitude)
    }
    
    func geopointValue() -> GeoPoint {
        return GeoPoint(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
    }
}



class GeoFireStore {
    typealias GFCompletionBlock = (Error?) -> Void
    typealias GFCallback = (CLLocation?, Error?) -> Void
    
    var collectionRef: CollectionReference
    internal var callbackQueue: DispatchQueue

    init(collectionRef: CollectionReference) {
        self.collectionRef = collectionRef
        self.callbackQueue = DispatchQueue.main
    }
    
    func getCollectionReference() -> CollectionReference {
        return collectionRef
    }
    
    //COMPLETE
    func setLocation(geopoint: GeoPoint, forDocumentWithID documentID: String, completion: GFCompletionBlock? = nil) {
        setLocation(location: geopoint.locationValue(), forDocumentWithID: documentID, completion: completion)
    }
    
    //COMPLETE
    func setLocation(location: CLLocation, forDocumentWithID documentID: String, completion: GFCompletionBlock? = nil) {
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
    
    //COMPLETE
    func getLocation(forDocumentWithID documentID: String, callback: GFCallback? = nil) {
        self.collectionRef.document(documentID).getDocument { (snap, err) in
            let l = snap?.get("l") as? [Double?]
            if let lat = l?[0], let lon = l?[1] {
                let loc = CLLocation(latitude: lat, longitude: lon)
                callback?(loc, err)
            }
            callback?(nil, err)
        }
    }
    
    func query(withCenter center: GeoPoint, radius: Double) {
        
    }
    
    static func distance(location1: GeoPoint, location2: GeoPoint) -> Double{
        return 0
    }
}



// COMPLETE
enum GFSEventType {
    case GFSEventTypeDocumentEntered
    case GFSEventTypeDocumentExited
    case GFSEventTypeDocumentMoved
}

typealias GFSQueryResultBlock = (String?, CLLocation?) -> Void
typealias GFSReadyBlock = () -> Void
typealias GFSQueryHandle = UInt

internal class GFSGeoHashQueryHandle {
    var childAddedHandle: GFSQueryHandle?
    var childRemovedHandle: GFSQueryHandle?
    var childChangedHandle: GFSQueryHandle?
}



class GFSQuery {
    internal class GFSQueryLocationInfo {
        var isInQuery: Bool?
        var location: CLLocation?
        var geoHash: GFGeoHash?
    }
    
    var geoFireStore: GeoFireStore
    
    internal var locationInfos = [String: GFSQueryLocationInfo]()
    internal var queries = Set<GFGeoHashQuery>()
    internal var handles = [GFGeoHashQuery: GFSGeoHashQueryHandle]()
    internal var outstandingQueries = Set<GFGeoHashQuery>()
    
    internal var keyEnteredObservers = [GFSQueryHandle: GFSQueryResultBlock]()
    internal var keyExitedObservers = [GFSQueryHandle: GFSQueryResultBlock]()
    internal var keyMovedObservers = [GFSQueryHandle: GFSQueryResultBlock]()
    internal var readyObservers = [GFSQueryHandle: GFSReadyBlock]()

    internal var currentHandle: UInt?
    
    internal init(geoFireStore: GeoFireStore) {
        self.geoFireStore = geoFireStore
    }
    
    // COMPLETE
    internal func fireStoreQueryForGeoHashQuery(query: GFGeoHashQuery) {
        self.geoFireStore.collectionRef.whereField("g", isGreaterThanOrEqualTo: query.startValue).whereField("g", isLessThanOrEqualTo: query.endValue)
    }
    
    //overriden
    internal func locationIsInQuery(loc: CLLocation) -> Bool {
        fatalError("Override in subclass.")
    }
    
    internal func queriesForCurrentCriteria() -> Set<AnyHashable> {
        fatalError("Override in subclass.")
    }
    
    // COMPLETE
    func updateLocationInfo(_ location: CLLocation, forKey key: String) {
        var info: GFSQueryLocationInfo? = locationInfos[key]
        var isNew = false
        if info == nil {
            isNew = true
            info = GFSQueryLocationInfo()
            locationInfos[key] = info
        }
        let changedLocation: Bool = !(info?.location!.coordinate.latitude == location.coordinate.latitude && info?.location!.coordinate.longitude == location.coordinate.longitude)
        let wasInQuery = info?.isInQuery
        // we know it exists now so force unwrap is ok
        info!.location = location
        info!.isInQuery = locationIsInQuery(loc: location)
        info!.geoHash = GFGeoHash.new(withLocation: location.coordinate)
        if (isNew || !(wasInQuery ?? false)) && info?.isInQuery != nil {
            for (offset: _, element: (key: _, value: block)) in keyEnteredObservers.enumerated() {
                self.geoFireStore.callbackQueue.async {
                    block(key, info!.location)
                }
            }
        } else if !isNew && changedLocation && info?.isInQuery != nil {
            for (offset: _, element: (key: _, value: block)) in keyMovedObservers.enumerated() {
                self.geoFireStore.callbackQueue.async {
                    block(key, info!.location)
                }
            }
        } else if wasInQuery ?? false && info?.isInQuery == nil {
            for (offset: _, element: (key: _, value: block)) in keyExitedObservers.enumerated() {
                self.geoFireStore.callbackQueue.async {
                    block(key, info!.location)
                }
            }
        }
    }
    
    //COMPLETE
    func queriesContain(_ geoHash: GFGeoHash?) -> Bool {
        for query: GFGeoHashQuery? in queries {
            if query?.contains(geoHash) != nil {
                return true
            }
        }
        return false
    }
    
    //COMPLETE
    func childAdded(_ snapshot: DataSnapshot?) {
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            let location: CLLocation? = GeoFire.location(fromValue: snapshot?.value)
            if let loc = location, let key = snapshot?.key {
                updateLocationInfo(loc, forKey: key)
            }
            else {
                // TODO: error??
            }
        }
    }
    
    
    func childChanged(_ snapshot: DataSnapshot?) {
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            let location: CLLocation? = GeoFire.location(fromValue: snapshot?.value)
            if let loc = location, let key = snapshot?.key {
                updateLocationInfo(loc, forKey: key)
            } else {
                // TODO: error?
            }
        }
    }
    
    func childRemoved(_ snapshot: DataSnapshot?) {
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            let key = snapshot?.key
            var info: GFSQueryLocationInfo? = nil
            if let aKey = snapshot?.key {
                info = locationInfos[aKey]
            }
            if info != nil {
                geoFireStore.firebaseRef(forLocationKey: snapshot?.key).observeSingleEventOfType(FIRDataEventTypeValue, withBlock: { snapshot in
                    let lockQueue = DispatchQueue(label: "self")
                    lockQueue.sync {
                        let location: CLLocation? = GeoFire.location(fromValue: snapshot?.value)
                        let geoHash = (location) != nil ? GFGeoHash(location: location?.coordinate) : nil
                        // Only notify observers if key is not part of any other geohash query or this actually might not be
                        // a key exited event, but a key moved or entered event. These events will be triggered by updates
                        // to a different query
                        if !self.queriesContain(geoHash) {
                            let info: GFQueryLocationInfo? = self.locationInfos[key ?? ""]
                            self.locationInfos.removeValueForKey(key)
                            // Key was in query, notify about key exited
                            if info?.isInQuery != nil {
                                self.keyExitedObservers.enumerateKeysAndObjects(usingBlock: { observerKey, block, stop in
                                    self.geoFire.callbackQueue.async(execute: {
                                        block(key, location)
                                    })
                                })
                            }
                        }
                    }
                })
            }
        }
    }
    
    //COMPLETE
    func searchCriteriaDidChange() {
        if !queries.isEmpty {
            updateQueries()
        }
    }
    
    //COMPLETE
    func checkAndFireReadyEvent() {
        if outstandingQueries.count == 0 {
            for (offset: _, element: (key: _, value: block)) in readyObservers.enumerated() {
                self.geoFireStore.callbackQueue.async {
                    block()
                }
            }
        }
    }
    
    func updateQueries() {
        let oldQueries = queries
        let newQueries = queriesForCurrentCriteria()
        var toDelete = (Set<AnyHashable>().union(oldQueries))
        toDelete.subtract(newQueries)
        var toAdd = (Set<AnyHashable>().union(newQueries))
        toAdd.subtract(oldQueries)
        toDelete.enumerateObjects(usingBlock: { query, stop in
            var handle: GFGeoHashQueryHandle? = nil
            if let aQuery = query {
                handle = self.firebaseHandles[aQuery]
            }
            if handle == nil {
                NSException.raise(.internalInconsistencyException, format: "Wanted to remove a geohash query that was not registered!", getVaList(["nil"]))
            }
            let queryFirebase: FIRDatabaseQuery? = self.firebase(for: query)
            queryFirebase?.removeObserver(withHandle: handle?.childAddedHandle)
            queryFirebase?.removeObserver(withHandle: handle?.childChangedHandle)
            queryFirebase?.removeObserver(withHandle: handle?.childRemovedHandle)
            self.firebaseHandles.removeValueForKey(handle)
            if let aQuery = query {
                while let elementIndex = self.outstandingQueries.index(of: aQuery) { self.outstandingQueries.remove(at: elementIndex) }
            }
        })
        toAdd.enumerateObjects(usingBlock: { query, stop in
            if let aQuery = query {
                self.outstandingQueries.append(aQuery)
            }
            let handle = GFGeoHashQueryHandle()
            let queryFirebase: FIRDatabaseQuery? = self.firebase(for: query)
            handle.childAddedHandle = queryFirebase?.observe(FIRDataEventTypeChildAdded, with: { snapshot in
                self.childAdded(snapshot)
            })
            handle.childChangedHandle = queryFirebase?.observe(FIRDataEventTypeChildChanged, with: { snapshot in
                self.childChanged(snapshot)
            })
            handle.childRemovedHandle = queryFirebase?.observe(FIRDataEventTypeChildRemoved, with: { snapshot in
                self.childRemoved(snapshot)
            })
            queryFirebase?.observeSingleEventOfType(FIRDataEventTypeValue, withBlock: { snapshot in
                let lockQueue = DispatchQueue(label: "self")
                lockQueue.sync {
                    if let aQuery = query {
                        while let elementIndex = self.outstandingQueries.index(of: aQuery) { self.outstandingQueries.remove(at: elementIndex) }
                    }
                    self.checkAndFireReadyEvent()
                }
            })
            if let aQuery = query {
                self.firebaseHandles[aQuery] = handle
            }
        })
        queries = newQueries
        locationInfos.enumerateKeysAndObjects(usingBlock: { key, info, stop in
            self.updateLocationInfo(info?.location, forKey: key)
        })
        var oldLocations = [String]()
        locationInfos.enumerateKeysAndObjects(usingBlock: { key, info, stop in
            if !self.queriesContainGeoHash(info?.geoHash) {
                if let aKey = key {
                    oldLocations.append(aKey)
                }
            }
        })
        for k in oldLocations { locationInfos.removeValue(forKey: k) }
        checkAndFireReadyEvent()
    }

    func reset() {
        for query: GFGeoHashQuery? in queries {
            var handle: GFSGeoHashQueryHandle? = nil
            if let aQuery = query {
                handle = self.handles[aQuery]
            }
            if handle == nil {
                NSException.raise(.internalInconsistencyException, format: "Wanted to remove a geohash query that was not registered!", arguments: getVaList(["nil"]))
            }
            let queryFirebase: FIRDatabaseQuery? = firebase(for: query)
            queryFirebase?.removeObserver(withHandle: handle?.childAddedHandle)
            queryFirebase?.removeObserver(withHandle: handle?.childChangedHandle)
            queryFirebase?.removeObserver(withHandle: handle?.childRemovedHandle)
        }
        firebaseHandles = [AnyHashable: Any]()
        queries = nil
        outstandingQueries = Set<AnyHashable>()
        keyEnteredObservers = [AnyHashable: Any]()
        keyExitedObservers = [AnyHashable: Any]()
        keyMovedObservers = [AnyHashable: Any]()
        readyObservers = [AnyHashable: Any]()
        locationInfos = [AnyHashable: Any]()
    }
    
    
    
    func totalObserverCount() -> Int {
        return keyEnteredObservers.count + keyExitedObservers.count + keyMovedObservers.count + readyObservers.count
    }
    
    func observe(_ eventType: GFEventType, with block: GFQueryResultBlock) -> FirebaseHandle {
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            if block == nil {
                NSException.raise(.invalidArgumentException, format: "Block is not allowed to be nil!", arguments: getVaList(["nil"]))
            }
            let firebaseHandle: FirebaseHandle = currentHandle += 1
            let numberHandle = Int(truncating: firebaseHandle)
            switch eventType {
            case GFEventTypeKeyEntered:
                keyEnteredObservers[numberHandle] = block.copy()
                currentHandle += 1
                geoFire.callbackQueue.async(execute: {
                    let lockQueue = DispatchQueue(label: "self")
                    lockQueue.sync {
                        self.locationInfos.enumerateKeysAndObjects(usingBlock: { key, info, stop in
                            if info?.isInQuery != nil {
                                block(key, info?.location)
                            }
                        })
                    }
                })
            case GFEventTypeKeyExited:
                keyExitedObservers[numberHandle] = block.copy()
                currentHandle += 1
            case GFEventTypeKeyMoved:
                keyMovedObservers[numberHandle] = block.copy()
                currentHandle += 1
            default:
                NSException.raise(.invalidArgumentException, format: "Event type was not a GFEventType!", arguments: getVaList(["nil"]))
            }
            if queries == nil {
                updateQueries()
            }
            return firebaseHandle
        }
    }
    
    
    public func observeEvent(eventType: GFSEventType, withBlock block: GFSQueryResultBlock) -> GFSQueryHandle {
        return 0
    }
    
    public func observeReady(withBlock block: GFSReadyBlock) -> GFSQueryHandle {
        return 0
    }
    
    //COMPLETE
    func removeObserver(withHandle handle: GFSQueryHandle) {
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            keyEnteredObservers.removeValue(forKey: handle)
            keyExitedObservers.removeValue(forKey: handle)
            keyMovedObservers.removeValue(forKey: handle)
            readyObservers.removeValue(forKey: handle)
            if totalObserverCount() == 0 {
                reset()
            }
        }
    }
    
    //COMPLETE
    func removeAllObservers() {
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            reset()
        }
    }
    
}

// COMPLETE
class GFSCircleQuery: GFSQuery {
    var center: CLLocation
    var radius: Double
    
    init(geoFireStore: GeoFireStore, center: CLLocation, radius: Double) {
        self.radius = radius
        self.center = center
        super.init(geoFireStore: geoFireStore)
    }
    
    override internal func locationIsInQuery(loc: CLLocation) -> Bool {
        return loc.distance(from: self.center) <= (self.radius * 1000.0)
    }
    
    override internal func queriesForCurrentCriteria() -> Set<AnyHashable> {
        return GFGeoHashQuery.queries(forLocation: self.center.coordinate, radius: (self.radius * 1000.0))
    }
}

// COMPLETE
class GFSRegionQuery: GFSQuery {
    var region: MKCoordinateRegion
    
    init(geoFireStore: GeoFireStore, region: MKCoordinateRegion) {
        self.region = region
        super.init(geoFireStore: geoFireStore)
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

