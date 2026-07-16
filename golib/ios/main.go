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
	"encoding/json"
	"sync"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/option"
)

var (
	instance *box.Box
	mu       sync.Mutex
)

// LogCallback is the callback interface for log messages.
type LogCallback interface {
	OnLog(message string)
}

var logCb LogCallback

// SetLogCallback registers a callback for receiving sing-box log messages.
func SetLogCallback(cb LogCallback) {
	logCb = cb
}

func logMessage(level, msg string) {
	if logCb != nil {
		logCb.OnLog("[" + level + "] " + msg)
	}
}

// Start initializes and starts sing-box with the given configuration JSON.
// Returns empty string on success, or error message on failure.
func Start(configJSON string, tunFd int) string {
	mu.Lock()
	defer mu.Unlock()

	logMessage("info", "Starting sing-box...")

	options, err := box.ParseConfig(configJSON)
	if err != nil {
		logMessage("error", "Parse config: "+err.Error())
		return err.Error()
	}

	// If tunFd >= 0, configure TUN inbound with the provided fd.
	if tunFd >= 0 {
		foundTun := false
		for i, inbound := range options.Inbounds {
			if inbound.Type == "tun" {
				options.Inbounds[i].TUNOptions.FileDescriptor = int32(tunFd)
				foundTun = true
				break
			}
		}
		if !foundTun {
			options.Inbounds = append(options.Inbounds, option.Inbound{
				Type: "tun",
				Tag:  "tun-in",
				TUNOptions: option.TUNOptions{
					InterfaceName:  "ForgeVPN",
					MTU:            1500,
					Inet4Address:   []option.ListenPrefix{option.ListenPrefix("172.19.0.1/30")},
					AutoRoute:      true,
					StrictRoute:    true,
					FileDescriptor: int32(tunFd),
					Stack:          option.TUNStackSystem,
				},
			})
		}
	}

	// Enable logging
	if options.Log == nil {
		options.Log = &option.LogOptions{}
	}
	options.Log.Disabled = false
	options.Log.Level = "info"

	// Create and start sing-box
	newInstance, err := box.New(box.Options{
		Options: options,
	})
	if err != nil {
		logMessage("error", "New: "+err.Error())
		return err.Error()
	}

	if err := newInstance.Start(); err != nil {
		logMessage("error", "Start: "+err.Error())
		return err.Error()
	}

	instance = newInstance
	logMessage("info", "sing-box started successfully")
	return ""
}

// Stop gracefully stops the sing-box instance.
func Stop() {
	mu.Lock()
	defer mu.Unlock()

	if instance != nil {
		logMessage("info", "Stopping sing-box...")
		instance.Close()
		instance = nil
		logMessage("info", "sing-box stopped")
	}
}

// GetVersion returns the sing-box version string.
func GetVersion() string {
	return box.Version
}

// GetStatus returns a JSON string with basic runtime status.
func GetStatus() string {
	mu.Lock()
	defer mu.Unlock()

	if instance == nil {
		data, _ := json.Marshal(map[string]interface{}{
			"running": false,
		})
		return string(data)
	}

	data, _ := json.Marshal(map[string]interface{}{
		"running": true,
		"version": box.Version,
	})
	return string(data)
}
