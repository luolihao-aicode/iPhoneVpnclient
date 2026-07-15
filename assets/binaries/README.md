# sing-box Android Binaries

Place sing-box ARM64 binary here for Android builds.

## Build Instructions

From the sing-box project root:

```bash
# ARM64 (most modern phones)
GOOS=linux GOARCH=arm64 go build -o sing-box-android-arm64 -trimpath -ldflags "-s -w" ./cmd/sing-box

# ARMv7 (older phones)
GOOS=linux GOARCH=arm GOARM=7 go build -o sing-box-android-armv7 -trimpath -ldflags "-s -w" ./cmd/sing-box

# x86_64 (emulators)
GOOS=linux GOARCH=amd64 go build -o sing-box-android-amd64 -trimpath -ldflags "-s -w" ./cmd/sing-box
```

## Download Prebuilt

Or download from the [sing-box releases page](https://github.com/SagerNet/sing-box/releases):

- `sing-box-<version>-linux-arm64.tar.gz` → `sing-box-android-arm64`
- `sing-box-<version>-linux-armv7.tar.gz` → `sing-box-android-armv7`

Extract the binary and rename accordingly.
