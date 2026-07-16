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

// ── Logging ─────────────────────────────────────────────────────

// LogCallback is the callback interface for log messages.
// gomobile exports this as an ObjC protocol: SingboxLogCallback
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

// ── Start / Stop ────────────────────────────────────────────────

// Start initializes and starts sing-box with the given configuration JSON.
// Returns empty string on success, or error message on failure.
// If tunFd >= 0, inject the fd into the TUN inbound in the config.
//
// gomobile bridge: func Start(_ configJson: String?, _ tunFd: Int32) -> String?
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
func injectTunFd(opts *option.Options, tunFd int) *option.Options {
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
		rawMap["inbounds"] = []interface{}{
			map[string]interface{}{
				"type":            "tun",
				"tag":             "tun-in",
				"interface_name":  "ForgeVPN",
				"mtu":             1500,
				"address":         "172.19.0.1/30",
				"auto_route":      true,
				"strict_route":    true,
				"stack":           "system",
				"file_descriptor": tunFd,
			},
		}
		rawJSON, _ := json.Marshal(rawMap)
		var newOpts option.Options
		json.Unmarshal(rawJSON, &newOpts)
		return &newOpts
	}

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
			"type":            "tun",
			"tag":             "tun-in",
			"interface_name":  "ForgeVPN",
			"mtu":             1500,
			"address":         "172.19.0.1/30",
			"auto_route":      true,
			"strict_route":    true,
			"stack":           "system",
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

// ── Packet flow bridge (for iOS packetFlow mode when tunFd is unavailable) ──

// packetFlowBuf is a simple thread-safe buffer that holds one packet at a time.
// The Swift side feeds packets in via FeedTunPacket, and reads processed packets
// out via ReadTunPacket.
var (
	packetBuf      []byte
	packetBufMu    sync.Mutex
	packetBufReady bool
	packetBufAF    int32
)

// FeedTunPacket feeds a raw TUN packet into sing-box for processing.
// af is the address family (AF_INET=2 or AF_INET6=30).
// gomobile bridge: func FeedTunPacket(_ data: Data?, _ af: Int32)
func FeedTunPacket(data []byte, af int32) {
	packetBufMu.Lock()
	defer packetBufMu.Unlock()

	// In fd mode, sing-box handles packets internally.
	// In packetFlow mode, we buffer the packet for sing-box to process.
	// For now, this is a simple 1-packet buffer placeholder.
	// Full implementation would route through sing-box's TUN input.
	packetBuf = append([]byte{}, data...)
	packetBufAF = af
	packetBufReady = true
}

// ReadTunPacket reads a processed packet from sing-box's output.
// Returns nil when no packet is available.
// gomobile bridge: func ReadTunPacket(_ mtu: Int32) -> Data?
func ReadTunPacket(mtu int32) []byte {
	packetBufMu.Lock()
	defer packetBufMu.Unlock()

	if !packetBufReady {
		return nil
	}

	// In this simple bridge mode, we pass packets through unchanged.
	// A full implementation would route through sing-box's tun.in handler.
	packetBufReady = false
	result := packetBuf
	packetBuf = nil
	return result
}

// ── Version / Status ────────────────────────────────────────────

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
