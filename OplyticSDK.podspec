#
# Be sure to run `pod lib lint OplyticSDK.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'OplyticSDK'
  s.version          = '0.1.1'
  s.summary          = 'Oplytic SDK for attribution and deep-linking.'
  s.swift_version = '4.1'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Oplytic integrates seamlessly with your affiliate network and partners and connects to your mobile analytics platform, web analytics platform, CRM to get the full measurement picture.
                       DESC

  s.homepage         = 'https://github.com/oplytic/OplyticSDK'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'ValueMags Support' => 'support@valuemags.com' }
  s.source           = { :git => 'https://github.com/oplytic/OplyticSDK.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'

  s.source_files = 'OplyticSDK/Classes/**/*'
  
  # s.resource_bundles = {
  #   'OplyticSDK' => ['OplyticSDK/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  
  s.frameworks = 'UIKit', 'AdSupport'
  s.library = 'sqlite3'

  # s.dependency 'AFNetworking', '~> 2.3'
end
