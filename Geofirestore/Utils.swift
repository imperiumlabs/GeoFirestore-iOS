import Foundation
import Firebase
import GeoFire

class Utils {
    
    static let GEOHASH_PRECISION = 10
    static let BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz"
    static let EARTH_MERI_CIRCUMFERENCE = 40007860
    static let METERS_PER_DEGREE_LATITUDE = 110574
    static let BITS_PER_CHAR = 5
    static let MAXIMUM_BITS_PRECISION = 110
    static let EARTH_EQ_RADIUS = 6378137.0
    static let E2 = 0.00669447819799
    static let EPSILON = 1e-12
    
    func log2(x: Double) -> Double{
        return log(x)/log(2)
    }
    
    func degreesToRadians(degrees: Double) -> Double {
        return (degrees * Double.pi / 180.0);
    }
    
    func metersToLongitudeDegrees(distance: Double, latitude: Double) -> Double{
        let radians = degreesToRadians(degrees: latitude)
        //...
    }
    
    func validateLocation(location: GeoPoint) -> Error? {
        let latitude = location.latitude
        let longitude = location.longitude
        if latitude < -90 || latitude > 90{
            return LocationError.latitudeExceedsRange
        }else if longitude < -180 || longitude > 180{
            return LocationError.longitudeExceedsRange
        }
        return nil
    }
    
    func validateCriteria(center: GeoPoint, radius: Double) -> Error?{
        if let locationError = validateLocation(location: center){
            return locationError
        }else if radius < 0{
            return CriteriaError.invalidRadius
        }
        return nil
    }
    
    func encodeGeohash(location: GeoPoint, precision: Int = Utils.GEOHASH_PRECISION) -> (String?, Error?) {
        if let locationError = validateLocation(location: location){
            return (nil, locationError)
        }else if precision <= 0{
            return (nil, GeohashError.invalidPrecision)
        }else if precision > 22{
            return (nil, GeohashError.invalidPrecision)
        }
        
        let hash = GFGeoHash(location: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude), precision: UInt(precision))
        return (hash?.geoHashValue, nil)
    }
    
}

enum LocationError: Error{
    case latitudeExceedsRange
    case longitudeExceedsRange
}
extension LocationError: LocalizedError{
    var errorDescription: String? {
        switch self {
        case .latitudeExceedsRange:
            return "latitude must be within the range [-90, 90]"
        case .longitudeExceedsRange:
            return "longitude must be within the range [-180, 180]"
        }
    }
}

enum CriteriaError: Error{
    case invalidRadius
}
extension CriteriaError: LocalizedError{
    var errorDescription: String? {
        switch self {
        case .invalidRadius:
            return "radius must be greater than or equal to 0"
        }
    }
}

enum GeohashError: Error{
    case invalidPrecision
}
extension GeohashError: LocalizedError{
    var errorDescription: String? {
        switch self {
        case .invalidPrecision:
            return "precision must be greater than 0 and less than 23"
        }
    }
}
