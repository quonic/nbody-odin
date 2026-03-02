package main

import "vendor:raylib"


// Physics Body struct
Body :: struct {
	id:       u64,
	position: raylib.Vector2,
	velocity: raylib.Vector2,
	mass:     f32,
	radius:   f32,
	color:    raylib.Color,
}

SelectorButton :: struct {
	rect:      raylib.Rectangle,
	body_id:   u64,
	label:     cstring,
	is_reset:  bool,
	is_active: bool,
}

camera: raylib.Camera2D = raylib.Camera2D {
	target   = raylib.Vector2{0, 0},
	offset   = raylib.Vector2{0, 0},
	rotation = 0,
	zoom     = 0.8,
}

screenWidth: f32 = 1920
screenHeight: f32 = 1080

maxZoomOut: f32 = 0.1
maxZoomIn: f32 = 3
strayCullMultiplier: f32 = 1.5
zoomSmoothing: f32 = 4
selectedBodyZoom :: 0.75
selectorButtonsPerRow :: 10
selectorButtonWidth :: 150
selectorButtonHeight :: 36
selectorButtonGapX :: 10
selectorButtonGapY :: 8
selectorBottomMargin :: 16
selectorFontSize :: 18

nextBodyID: u64 = 1
selectedBodyID: u64 = 0

minPlanetCount :: 6
maxPlanetCount :: 10
innerBeltAsteroidCount :: 100
outerBeltAsteroidCount :: 200

// Star and orbital system constants
STAR_MASS_VALUE :: 50000000
PLANET_MIN_ORBIT_VALUE :: 1800
PLANET_MAX_ORBIT_VALUE :: 8200
PLANET_MIN_GAP_VALUE :: 55
INNER_BELT_PADDING_VALUE :: 20
OUTER_BELT_INNER_PADDING_VALUE :: 1400
OUTER_BELT_WIDTH_VALUE :: 260
ORBIT_SPEED_SCALE_VALUE :: 0.95

// Planet generation parameters
PLANET_ORBIT_VARIANCE_FACTOR :: 0.2
PLANET_MASS_MIN :: 15000
PLANET_MASS_MAX :: 120000
PLANET_SPEED_VARIANCE_MIN :: 0.97
PLANET_SPEED_VARIANCE_MAX :: 1.03

// Asteroid generation parameters
ASTEROID_MASS_MIN :: 2
ASTEROID_MASS_MAX :: 14
ASTEROID_SPEED_VARIANCE_MIN :: 0.93
ASTEROID_SPEED_VARIANCE_MAX :: 1.07
ASTEROID_VELOCITY_MAX :: 10

// Physics and angle parameters
FULL_ROTATION :: 2.0

// Color mass tier thresholds
STAR_MASS_THRESHOLD :: 5000000
HEAVY_PLANET_THRESHOLD :: 100000
PLANET_THRESHOLD :: 15000
MOON_THRESHOLD :: 1000

// Set to true to calculate gravity between all bodies, false to only calculate gravity from the star for better performance
nBodyGravityCalculation: bool = true

main :: proc() {

	raylib.InitWindow(i32(screenWidth), i32(screenHeight), "nbody-odin")
	defer raylib.CloseWindow()

	// primaryMonitorIndex := GetPrimaryMonitor()
	// screenWidth = f32(raylib.GetMonitorWidth(primaryMonitorIndex))
	// screenHeight = f32(raylib.GetMonitorHeight(primaryMonitorIndex))
	SetWindowToPrimaryMonitor(true)
	// raylib.ToggleFullscreen()

	bodies := generateSolarSystem()

	for !raylib.WindowShouldClose() {
		{
			raylib.BeginDrawing()
			raylib.ClearBackground(raylib.BLACK)
			raylib.DrawFPS(10, 10)

			deltaTime := raylib.GetFrameTime()

			stepPhysics(&bodies, deltaTime)

			if nBodyGravityCalculation {
				resolveBodyCollision(&bodies)
				removeStrayBodies(&bodies)
			}

			handleBodySelectorUI(bodies)
			updateCamera(bodies)

			{
				raylib.BeginMode2D(camera)
				// Draw bodies
				for body, _ in bodies {
					raylib.DrawCircleV(body.position, body.radius, body.color)
				}
				raylib.EndMode2D()
			}

			drawBodySelectorUI(bodies)
			raylib.EndDrawing()
		}
	}
}
