xcodebuild archive \
 -scheme ETTraceRunner \
 -archivePath ./ETTraceRunner.xcarchive \
 -sdk macosx \
 -destination 'generic/platform=macOS' \
 SKIP_INSTALL=NO

codesign --entitlements ./ETTrace/ETTraceRunner/ETTraceRunner.entitlements -f -s $SIGNING_IDENTITY ETTraceRunner.xcarchive/Products/usr/local/bin/ETTraceRunner

cp ETTraceRunner.xcarchive/Products/usr/local/bin/ETTraceRunner ETTraceRunner