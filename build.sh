xcodebuild archive \
 -workspace ./PerfAnalysis/PerfAnalysis.xcworkspace \
 -scheme PerfAnalysis \
 -archivePath ./PerfAnalysis-iphonesimulator.xcarchive \
 -sdk iphonesimulator \
 SKIP_INSTALL=NO

xcodebuild archive \
 -workspace ./PerfAnalysis/PerfAnalysis.xcworkspace \
 -scheme PerfAnalysis \
 -archivePath ./PerfAnalysis-iphoneos.xcarchive \
 -sdk iphoneos \
 SKIP_INSTALL=NO

xcodebuild -create-xcframework \
 -framework ./PerfAnalysis-iphonesimulator.xcarchive/Products/Library/Frameworks/PerfAnalysis.framework \
 -framework ./PerfAnalysis-iphoneos.xcarchive/Products/Library/Frameworks/PerfAnalysis.framework \
 -output ./PerfAnalysis.xcframework
