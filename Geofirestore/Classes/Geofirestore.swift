import Foundation
import CoreLocation
import FirebaseCore
import FirebaseFirestore
import GeoFire

// COMPLETE
public extension GeoPoint {
    class func geopointWithLocation(location: CLLocation) -> GeoPoint {
        return GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
    
    public func locationValue() -> CLLocation {
        return CLLocation(latitude: self.latitude, longitude: self.longitude)
    }
}

// COMPLETE
public extension CLLocation {
    class func locationWithGeopoint(geopoint: GeoPoint) -> CLLocation {
        return CLLocation(latitude: geopoint.latitude, longitude: geopoint.longitude)
    }
    
    public func geopointValue() -> GeoPoint {
        return GeoPoint(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
    }
}


public class GeoFirestore {
    
    public typealias GFSCompletionBlock = (Error?) -> Void
    public typealias GFSLocationCallback = (CLLocation?, Error?) -> Void
    public typealias GFSGeoPointCallback = (GeoPoint?, Error?) -> Void
    
    public var collectionRef: CollectionReference
    
    internal var callbackQueue: DispatchQueue

    public init(collectionRef: CollectionReference) {
        self.collectionRef = collectionRef
        self.callbackQueue = DispatchQueue.main
    }
    
    // COMPLETE
    public func getCollectionReference() -> CollectionReference {
        return collectionRef
    }
    
    // COMPLETE
    public func setLocation(geopoint: GeoPoint, forDocumentWithID documentID: String, completion: GFSCompletionBlock? = nil) {
        setLocation(location: geopoint.locationValue(), forDocumentWithID: documentID, completion: completion)
    }
    
    // COMPLETE
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
    
    // COMPLETE
    public func getLocation(forDocumentWithID documentID: String, callback: GFSLocationCallback? = nil) {
        self.collectionRef.document(documentID).getDocument { (snap, err) in
            let l = snap?.get("l") as? [Double?]
            if let lat = l?[0], let lon = l?[1] {
                let loc = CLLocation(latitude: lat, longitude: lon)
                callback?(loc, err)
            }
            callback?(nil, err)
        }
    }
    
    // COMPLETE
    public func getLocation(forDocumentWithID documentID: String, callback: GFSGeoPointCallback? = nil) {
        self.collectionRef.document(documentID).getDocument { (snap, err) in
            let l = snap?.get("l") as? [Double?]
            if let lat = l?[0], let lon = l?[1] {
                let geoPoint = GeoPoint(latitude: lat, longitude: lon)
                callback?(geoPoint, err)
            }
            callback?(nil, err)
        }
    }
    
    // COMPLETE
    public func query(withCenter center: GeoPoint, radius: Double) -> GFSCircleQuery {
        return GFSCircleQuery(geoFirestore: self, center: center.locationValue(), radius: radius)
    }
    
    // COMPLETE
    public func query(withCenter center: CLLocation, radius: Double) -> GFSCircleQuery {
        return GFSCircleQuery(geoFirestore: self, center: center, radius: radius)
    }
    
    // COMPLETE
    public func query(inRegion region: MKCoordinateRegion) -> GFSRegionQuery{
        return GFSRegionQuery(geoFirestore: self, region: region)
    }
    
}



// COMPLETE
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



public class GFSQuery {
    internal class GFSQueryLocationInfo {
        var isInQuery: Bool?
        var location: CLLocation?
        var geoHash: GFGeoHash?
    }
    
    public var geoFirestore: GeoFirestore
    
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
    
    // COMPLETE
    internal func fireStoreQueryForGeoHashQuery(query: GFGeoHashQuery) -> Query {
        return self.geoFirestore.collectionRef.order(by: "g").whereField("g", isGreaterThanOrEqualTo: query.startValue).whereField("g", isLessThanOrEqualTo: query.endValue)
    }
    
    //overriden
    internal func locationIsInQuery(loc: CLLocation) -> Bool {
        fatalError("Override in subclass.")
    }
    
    internal func queriesForCurrentCriteria() -> Set<AnyHashable> {
        fatalError("Override in subclass.")
    }
    
    // COMPLETE
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
    
    // COMPLETE
    internal func queriesContain(_ geoHash: GFGeoHash?) -> Bool {
        for query: GFGeoHashQuery? in queries {
            if query?.contains(geoHash) != nil {
                return true
            }
        }
        return false
    }
    
    // COMPLETE
    internal func childAdded(_ snapshot: DocumentSnapshot?) {
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            
            let l = snapshot?.get("l") as? [Double?]
            if let lat = l?[0], let lon = l?[1], let key = snapshot?.documentID {
                let location = CLLocation(latitude: lat, longitude: lon)
                updateLocationInfo(location, forKey: key)
            }else{
                //TODO: error??
            }
            
        }
    }
    
    // COMPLETE
    internal func childChanged(_ snapshot: DocumentSnapshot?) {
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            
            let l = snapshot?.get("l") as? [Double?]
            if let lat = l?[0], let lon = l?[1], let key = snapshot?.documentID {
                let location = CLLocation(latitude: lat, longitude: lon)
                updateLocationInfo(location, forKey: key)
            }else{
                //TODO: error??
            }
            
        }
    }
    
    // COMPLETE
    internal func childRemoved(_ snapshot: DocumentSnapshot?) {
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            
            if let snapshot = snapshot {
                
                var info: GFSQueryLocationInfo? = nil
                let key = snapshot.documentID
                info = locationInfos[key]
                if info != nil{                            
                    let l = snapshot.get("l") as? [Double?]
                    if let lat = l?[0], let lon = l?[1]{
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
                    }
                    
                }
            }
            
        }
    }
    
    // COMPLETE
    internal func searchCriteriaDidChange() {
        if !queries.isEmpty {
            updateQueries()
        }
    }
    
    // COMPLETE
    internal func checkAndFireReadyEvent() {
        if outstandingQueries.count == 0 {
            for (offset: _, element: (key: _, value: block)) in readyObservers.enumerated() {
                self.geoFirestore.callbackQueue.async {
                    block()
                }
            }
        }
    }
    
    // COMPLETE
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

    // COMPLETE
    internal func reset() {
        if !queries.isEmpty {
            for query: GFGeoHashQuery? in queries {
                var handle: GFSGeoHashQueryListener?
                if let aQuery = query {
                    handle = self.handles[aQuery]
                    if handle == nil {
                        NSException.raise(.internalInconsistencyException, format: "Wanted to remove a geohash query that was not registered!", arguments: getVaList(["nil"]))
                    }
                    handle?.childAddedListener?.remove()
                    handle?.childChangedListener?.remove()
                    handle?.childRemovedListener?.remove()
                }
                
            }
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
    
    
    // COMPLETE
    public func totalObserverCount() -> Int {
        return keyEnteredObservers.count + keyExitedObservers.count + keyMovedObservers.count + readyObservers.count
    }
    
    // COMPLETE
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
    
    // COMPLETE
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
    
    // COMPLETE
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
    
    // COMPLETE
    public func removeAllObservers() {
        let lockQueue = DispatchQueue(label: "self")
        lockQueue.sync {
            reset()
        }
    }
    
}

// COMPLETE
public class GFSCircleQuery: GFSQuery {
    public var center: CLLocation {
        didSet {
            self.searchCriteriaDidChange()
        }
    }
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

// COMPLETE
public class GFSRegionQuery: GFSQuery {
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

