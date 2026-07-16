// Package singbox provides gomobile bindings for sing-box on iOS.
//
// Build:
//   gomobile bind -v -target=ios \
//     -iosversion=14.0 \
//     -ldflags='-s -w' \
//     -o ../../ios/Runner/Singbox.xcframework \
//     .
//
package singbox

import (
	"encoding/json"
	"sync"

	box "github.com/sagernet/sing-box"
	boxConstant "github.com/sagernet/sing-box/constant"
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
// If tunFd >= 0, inject the fd into the TUN inbound in the config.
func Start(configJSON string, tunFd int) string {
	mu.Lock()
	defer mu.Unlock()

	logMessage("info", "Starting sing-box...")

	// Parse JSON config
	options := &option.Options{}
	if err := json.Unmarshal([]byte(configJSON), options); err != nil {
		logMessage("error", "Parse: "+err.Error())
		return err.Error()
	}

	// Inject TUN fd if provided
	if tunFd >= 0 {
		options = injectTunFd(options, tunFd)
	}

	// Enable logging
	if options.Log == nil {
		options.Log = &option.LogOptions{}
	}
	options.Log.Disabled = false
	options.Log.Level = "info"

	// Create the box
	newInstance, err := box.New(box.Options{
		Options: *options,
	})
	if err != nil {
		logMessage("error", "New: "+err.Error())
		return err.Error()
	}

	// Start
	if err := newInstance.Start(); err != nil {
		logMessage("error", "Start: "+err.Error())
		return err.Error()
	}

	instance = newInstance
	logMessage("info", "sing-box started successfully")
	return ""
}

// injectTunFd manipulates the config JSON to set the TUN file descriptor.
// We do JSON-level manipulation to avoid dealing with complex option types.
func injectTunFd(opts *option.Options, tunFd int) *option.Options {
	// Re-marshal to JSON, set tun inbound's file_descriptor, re-parse
	raw, err := json.Marshal(opts)
	if err != nil {
		logMessage("warn", "injectTunFd marshal: "+err.Error())
		return opts
	}

	var rawMap map[string]interface{}
	if err := json.Unmarshal(raw, &rawMap); err != nil {
		return opts
	}

	inbounds, ok := rawMap["inbounds"].([]interface{})
	if !ok {
		// No inbounds — create one
		rawMap["inbounds"] = []interface{}{
			map[string]interface{}{
				"type":         "tun",
				"tag":          "tun-in",
				"interface_name": "ForgeVPN",
				"mtu":          1500,
				"address":      "172.19.0.1/30",
				"auto_route":   true,
				"strict_route": true,
				"stack":        "system",
				"file_descriptor": tunFd,
			},
		}
		rawJSON, _ := json.Marshal(rawMap)
		var newOpts option.Options
		json.Unmarshal(rawJSON, &newOpts)
		return &newOpts
	}

	// Find or create tun inbound
	found := false
	for i, inbound := range inbounds {
		inMap, ok := inbound.(map[string]interface{})
		if !ok {
			continue
		}
		if inMap["type"] == "tun" {
			inMap["file_descriptor"] = tunFd
			inMap["stack"] = "system"
			inbounds[i] = inMap
			found = true
			break
		}
	}

	if !found {
		inbounds = append(inbounds, map[string]interface{}{
			"type":           "tun",
			"tag":            "tun-in",
			"interface_name": "ForgeVPN",
			"mtu":            1500,
			"address":        "172.19.0.1/30",
			"auto_route":     true,
			"strict_route":   true,
			"stack":          "system",
			"file_descriptor": tunFd,
		})
	}
	rawMap["inbounds"] = inbounds

	rawJSON, _ := json.Marshal(rawMap)
	var newOpts option.Options
	if err := json.Unmarshal(rawJSON, &newOpts); err != nil {
		logMessage("warn", "injectTunFd re-parse: "+err.Error())
		return opts
	}
	return &newOpts
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
	return boxConstant.Version
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
		"version": boxConstant.Version,
	})
	return string(data)
}
