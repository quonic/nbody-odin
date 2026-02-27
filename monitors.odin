package main

/*

Center the window on the center monitor.

Supports any amount of monitors.

### Usage

```odin
raylib.InitWindow(width, height, "My Window")
SetWindowToPrimaryMonitor()
```

*/

import "vendor:glfw"
import "vendor:raylib"

// Sets a raylib window to the primary monitor
SetWindowToPrimaryMonitor :: proc(setFps: bool = false) {
	assert(raylib.GetMonitorCount() > 0, "Error: No monitors detected")

	when ODIN_OS == .Windows {
		monitorIndex := raylib.GetCurrentMonitor()
	} else when ODIN_OS == .Linux {
		monitorIndex := GetPrimaryMonitor()
	}
	assert(monitorIndex >= 0, "Error: No primary monitor detected")

	raylib.SetWindowMonitor(monitorIndex)
	if setFps {raylib.SetTargetFPS(raylib.GetMonitorRefreshRate(monitorIndex))}
}

SetWindowToSpecificMonitor :: proc(monitorIndex: i32, setFps: bool = false) {
	assert(
		monitorIndex >= 0 && monitorIndex < raylib.GetMonitorCount(),
		"Error: Invalid monitor index",
	)

	raylib.SetWindowMonitor(monitorIndex)
	if setFps {raylib.SetTargetFPS(raylib.GetMonitorRefreshRate(monitorIndex))}
}

// Returns the index of the primary monitor
GetPrimaryMonitor :: proc() -> i32 {
	primary := glfw.GetPrimaryMonitor()
	name := glfw.GetMonitorName(primary)

	for i in 0 ..< raylib.GetMonitorCount() {
		if string(raylib.GetMonitorName(i)) == name {
			return i
		}
	}
	return -1
}
