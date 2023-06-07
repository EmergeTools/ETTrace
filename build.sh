xcodebuild archive \
 -scheme ETTrace \
 -archivePath ./ETTrace-iphonesimulator.xcarchive \
 -sdk iphonesimulator \
 -destination 'ANY=A' \
 BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
 INSTALL_PATH='Library/Frameworks' \
 SKIP_INSTALL=NO

xcodebuild archive \
 -scheme ETTrace \
 -archivePath ./ETTrace-iphoneos.xcarchive \
 -sdk iphoneos \
 -destination 'ANY=A' \
 BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
 INSTALL_PATH='Library/Frameworks' \
 SKIP_INSTALL=NO

xcodebuild -create-xcframework \
 -framework ./ETTrace-iphonesimulator.xcarchive/Products/Library/Frameworks/ETTrace.framework \
 -framework ./ETTrace-iphoneos.xcarchive/Products/Library/Frameworks/ETTrace.framework \
 -output ./ETTrace.xcframework
