# PerfAnalysis

Locally measure performance of your app, without Xcode or Instruments.

## Building and Installing

Run ./build.sh to build the xcframework `PerfAnalysis.xcframework`. Link the xcframework to your app.

## Using

Launch your app and run `./Runner/perf_analysis -b [YOUR_BUNDLE_ID] -i [YOUR_SIM_UUID]`. Get the sim UUID from `xcrun xctrace list devices`.
After profiling, open the output.json file on https://emergetools.com/flamegraph

