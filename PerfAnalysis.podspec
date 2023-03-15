Pod::Spec.new do |spec|
  spec.name          = 'PerfAnalysis'
  spec.version       = '1.0.0'
  spec.license       = { :type => 'MIT' }
  spec.homepage      = "https://emergetools.com"
  spec.summary       = 'A tool for accurately measuring iOS performance.'
  spec.source        = { :git => 'https://github.com/EmergeTools/PerfAnalysis.git', :tag => spec.version.to_s }
  spec.authors                = "Emerge Tools"
  spec.platform               = :ios
  spec.ios.deployment_target  = '14.0'
  spec.framework              = 'Foundation'
  spec.vendored_frameworks    = 'PerfAnalysis/PerfAnalysis.xcframework'
end