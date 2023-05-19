Pod::Spec.new do |spec|
    spec.name          = 'ETTrace'
    spec.version       = '0.2.2'
    spec.license       = { :type => 'MIT' }
    spec.homepage      = "https://emergetools.com"
    spec.summary       = 'A tool for accurately measuring iOS performance.'
    spec.source        = { :git => 'https://github.com/EmergeTools/PerfAnalysis.git', :tag => spec.version.to_s }
    spec.authors                = "Emerge Tools"
    spec.platform               = :ios
    spec.ios.deployment_target  = '14.0'
    spec.framework              = 'Foundation'
    spec.vendored_frameworks    = 'Prebuilt/ETTrace.xcframework'
end