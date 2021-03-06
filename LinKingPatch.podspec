#
# Be sure to run `pod lib lint LinKingPatch.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'LinKingPatch'
  s.version          = '0.1.8'
  s.summary          = 'A short description of LinKingPatch.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: LinKingPatch is Overseas SDK Quick Integration Solution.
                       DESC

  s.homepage         = 'https://github.com/MrDML/LinKingPatch'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'leaon' => 'leaon' }
  s.source           = { :git => 'https://github.com/MrDML/LinKingPatch.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '9.0'

  # s.source_files = 'LinKingPatch/Classes/**/*'
  
  # s.resource_bundles = {
  #   'LinKingPatch' => ['LinKingPatch/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
  
  
  s.vendored_frameworks = "LinKingPatch/Products/LinKingPatch.framework"
#  s.resources = "LinKingPatch/Assets/*.*"
  s.dependency 'SSZipArchive',  '~> 2.2.2'
  s.xcconfig = {
      'VALID_ARCHS' =>  'arm64 x86_64 armv7',
  }
  
end
