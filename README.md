# ETTrace 👽

Locally measure performance of your app, without Xcode or Instruments.

## Building and Installing

Run `pod install` in the ETTrace folder. Modify the code signing team in `ETTrace/ETTrace.xcworkspace` to your own team. Run `./build.sh` to build the xcframework `ETTrace.xcframework`. Link the xcframework to your app.

Install the runner with `brew install emergetools/homebrew-tap/ettrace`

## Using

Launch your app and run `ettrace` or `ettrace --use-simulator`. After profiling, the result will be displayed on https://emergetools.com/flamegraph

