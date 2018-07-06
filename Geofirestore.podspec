#
# Be sure to run `pod lib lint Geofirestore.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Geofirestore'
  s.version          = '1.0.0'
  s.summary          = 'Realtime location queries with Firebase Cloud Firestore.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
An alternative to the GeoFire library provided by Firebase, but compatible with Cloud Firestore. To use, just create a Geofirestore instance and point it to a collection reference containing the documents you'd like to run location queries on.
                       DESC

  s.homepage         = 'https://github.com/imperiumlabs/Geofirestore-ios.git'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Dhruv Shah' => 'dhruv.shah@gmail.com', 'Nikhil Sridhar' => 'nik.sridhar@gmail.com' }
  s.source           = { :git => 'https://github.com/imperiumlabs/Geofirestore.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '9.0'

  s.source_files = 'Geofirestore/Classes/**/*'
  
  s.swift_version = '4.0'
  
  # s.resource_bundles = {
  #   'Geofirestore' => ['Geofirestore/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'CoreLocation'
  
  s.static_framework = true
  
  s.dependency 'Firebase', '~> 5.4'
  s.dependency 'GeoFire', '~> 3.0'
  s.dependency 'FirebaseCore', '~> 5.0'
  s.dependency 'FirebaseFirestore', '~> 0.12'

end
