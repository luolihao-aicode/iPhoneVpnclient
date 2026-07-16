// Package main provides gomobile bindings for sing-box on iOS.
//
// Build:
//   gomobile bind -v -target=ios \
//     -iosversion=14.0 \
//     -ldflags='-s -w' \
//     -o ../../ios/Runner/Singbox.xcframework \
//     .
//
package main

import (
	"C"
	"os"
	"runtime/debug"
	"unsafe"

	"github.com/sagernet/sing-box/option"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/common/process"
	"github.com/sagernet/sing-box/log"
	"github.com/sagernet/sing-box/tunnel"
)

var (
	instance *box.Box
	logFunc  logCallback
	tunInput func([]byte, int32) int32
)

// Callback types for bridging to Swift/ObjC.
type logCallback func(message string)

//export SetLogCallback
func SetLogCallback(cb func(message string)) {
	logFunc = cb
}

//export Start
func Start(configJSON string, tunFd int32) error {
	// Parse config
	options, err := parseConfig(configJSON)
	if err != nil {
		return err
	}

	// If tunFd >= 0, inject it into the options so sing-box uses
	// the iOS-provided TUN interface directly instead of creating one.
	if tunFd >= 0 {
		if options.Inbounds == nil {
			options.Inbounds = []option.Inbound{}
		}
		// TUN inbound with the provided fd
		options.Inbounds = append(options.Inbounds, option.Inbound{
			Type: "tun",
			Tag:  "tun-in",
			TUNOptions: option.TUNOptions{
				InterfaceName: "ForgeVPN",
				MTU:           1500,
				Inet4Address:  []option.ListenPrefix{option.ListenPrefix("172.19.0.1/30")},
				AutoRoute:     true,
				StrictRoute:   true,
				FileDescriptor: tunFd,
				Stack:         option.TUNStackSystem,
			},
		})
	}

	// Create sing-box instance
	instance, err = box.New(box.Options{
		Options: options,
	})
	if err != nil {
		return err
	}

	// Start
	err = instance.Start()
	if err != nil {
		instance = nil
		return err
	}

	return nil
}

//export Stop
func Stop() {
	if instance != nil {
		instance.Close()
		instance = nil
	}
}

//export SetTunInputCallback
func SetTunInputCallback(cb func(data unsafe.Pointer, n int32) int32) {
	tunInput = func(data []byte, n int32) int32 {
		return cb(unsafe.Pointer(&data[0]), n)
	}
}

//export ReadTunPacket
func ReadTunPacket(buf unsafe.Pointer, n int32) int32 {
	if instance == nil || tunInput == nil {
		return 0
	}
	// Read from sing-box's TUN output
	return 0 // Implement based on sing-box API
}

//export FeedTunPacket
func FeedTunPacket(data unsafe.Pointer, n int32, af int32) {
	if instance == nil {
		return
	}
	// Feed packet into sing-box's TUN input
	// sing-box handles this internally when using fd mode
}

func parseConfig(json string) (option.Options, error) {
	return box.ParseConfig(json)
}

// Prevent unused imports
var _ = process.Rule{}
```

