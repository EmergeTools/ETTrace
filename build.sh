xcodebuild archive \
 -scheme ETTrace \
 -archivePath ./ETTrace-iphonesimulator.xcarchive \
 -sdk iphonesimulator \
 -destination 'generic/platform=iOS Simulator' \
 BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
 INSTALL_PATH='Library/Frameworks' \
 SKIP_INSTALL=NO \
 CLANG_CXX_LANGUAGE_STANDARD=c++17

xcodebuild archive \
 -scheme ETTrace \
 -archivePath ./ETTrace-iphoneos.xcarchive \
 -sdk iphoneos \
 -destination 'generic/platform=iOS' \
 BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
 INSTALL_PATH='Library/Frameworks' \
 SKIP_INSTALL=NO \
 CLANG_CXX_LANGUAGE_STANDARD=c++17

xcodebuild -create-xcframework \
 -framework ./ETTrace-iphonesimulator.xcarchive/Products/Library/Frameworks/ETTrace.framework \
 -framework ./ETTrace-iphoneos.xcarchive/Products/Library/Frameworks/ETTrace.framework \
 -output ./ETTrace.xcframework