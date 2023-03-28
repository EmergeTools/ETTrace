xcodebuild archive \
 -workspace ./ETTrace/ETTrace.xcworkspace \
 -scheme ETTrace \
 -archivePath ./ETTrace-iphonesimulator.xcarchive \
 -sdk iphonesimulator \
 SKIP_INSTALL=NO

xcodebuild archive \
 -workspace ./ETTrace/ETTrace.xcworkspace \
 -scheme ETTrace \
 -archivePath ./ETTrace-iphoneos.xcarchive \
 -sdk iphoneos \
 SKIP_INSTALL=NO

xcodebuild -create-xcframework \
 -framework ./ETTrace-iphonesimulator.xcarchive/Products/Library/Frameworks/ETTrace.framework \
 -framework ./ETTrace-iphoneos.xcarchive/Products/Library/Frameworks/ETTrace.framework \
 -output ./ETTrace.xcframework
