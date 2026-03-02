package main

import "core:fmt"
import "core:math"
import "core:math/rand"
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
minVisualRadius :: 8 // Minimum visible radius to help prevent flickering when zoomed out
selectedBodyZoom :: 2.0
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
		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.BLACK)
		raylib.DrawFPS(10, 10)

		deltaTime := raylib.GetFrameTime()

		for &body, i in bodies {
			// Gravity force from other bodies
			for &other, j in bodies {
				if nBodyGravityCalculation {
					if i != j {
						direction := other.position - body.position
						distance := raylib.Vector2Length(direction)
						if distance > 0 {
							forceMagnitude := (body.mass * other.mass) / (distance * distance)
							force := raylib.Vector2Normalize(direction) * forceMagnitude

							body.velocity += force * (deltaTime / body.mass)
						}
					}
				} else {
					if j == 0 {
						direction := other.position - body.position
						distance := raylib.Vector2Length(direction)
						if distance > 0 {
							forceMagnitude := (body.mass * other.mass) / (distance * distance)
							force := raylib.Vector2Normalize(direction) * forceMagnitude

							body.velocity += force * (deltaTime / body.mass)
						}
					}
				}
			}
			// Update position based on velocity
			body.position += body.velocity * deltaTime
		}
		if nBodyGravityCalculation {
			resolveBodyCollision(&bodies)
			removeStrayBodies(&bodies)
		}

		handleBodySelectorUI(bodies)
		updateCamera(bodies)

		raylib.BeginMode2D(camera)
		// Draw bodies
		for body, _ in bodies {
			visualRadius := math.max(body.radius * camera.zoom, minVisualRadius)
			raylib.DrawCircleV(body.position, visualRadius, body.color)
		}
		raylib.EndMode2D()

		drawBodySelectorUI(bodies)
		raylib.EndDrawing()
	}
}

allocBodyID :: proc() -> u64 {
	id := nextBodyID
	nextBodyID += 1
	return id
}

isPointInRect :: proc(p: raylib.Vector2, rect: raylib.Rectangle) -> bool {
	return(
		p.x >= rect.x &&
		p.x <= rect.x + rect.width &&
		p.y >= rect.y &&
		p.y <= rect.y + rect.height \
	)
}

findBodyByID :: proc(bodies: [dynamic]Body, id: u64) -> ^Body {
	for i := 0; i < len(bodies); i += 1 {
		if bodies[i].id == id {
			return &bodies[i]
		}
	}
	return nil
}

buildSelectorButtons :: proc(bodies: [dynamic]Body) -> [dynamic]SelectorButton {
	buttons: [dynamic]SelectorButton
	append(
		&buttons,
		SelectorButton {
			rect = raylib.Rectangle{},
			body_id = 0,
			label = "Reset",
			is_reset = true,
			is_active = selectedBodyID == 0,
		},
	)

	planetOrdinal := 0
	for body, i in bodies {
		if body.mass < PLANET_MASS_MIN {
			continue
		}

		label: cstring = ""
		if i == 0 {
			label = "Star"
		} else {
			planetOrdinal += 1
			label = fmt.ctprintf("Planet %d", planetOrdinal)
		}

		append(
			&buttons,
			SelectorButton {
				rect = raylib.Rectangle{},
				body_id = body.id,
				label = label,
				is_reset = false,
				is_active = selectedBodyID == body.id,
			},
		)
	}

	if len(buttons) == 0 {
		return buttons
	}

	screenW := f32(raylib.GetScreenWidth())
	screenH := f32(raylib.GetScreenHeight())

	total := len(buttons)
	rows := (total + selectorButtonsPerRow - 1) / selectorButtonsPerRow

	for row in 0 ..< rows {
		start := row * selectorButtonsPerRow
		end := math.min(start + selectorButtonsPerRow, total)
		count := end - start
		if count <= 0 {
			continue
		}

		rowWidth := f32(count) * selectorButtonWidth + f32(count - 1) * selectorButtonGapX
		x := (screenW - rowWidth) * 0.5
		y :=
			screenH -
			selectorBottomMargin -
			selectorButtonHeight -
			f32(row) * (selectorButtonHeight + selectorButtonGapY)

		for i in start ..< end {
			buttons[i].rect = raylib.Rectangle{x, y, selectorButtonWidth, selectorButtonHeight}
			x += selectorButtonWidth + selectorButtonGapX
		}
	}

	return buttons
}

handleBodySelectorUI :: proc(bodies: [dynamic]Body) {
	if !raylib.IsMouseButtonPressed(.LEFT) {
		return
	}

	buttons := buildSelectorButtons(bodies)
	defer delete(buttons)

	mouse := raylib.GetMousePosition()
	for button, _ in buttons {
		if !isPointInRect(mouse, button.rect) {
			continue
		}

		if button.is_reset {
			selectedBodyID = 0
		} else {
			selectedBodyID = button.body_id
		}
		return
	}
}

drawBodySelectorUI :: proc(bodies: [dynamic]Body) {
	buttons := buildSelectorButtons(bodies)
	defer delete(buttons)

	mouse := raylib.GetMousePosition()
	for button, _ in buttons {
		hovered := isPointInRect(mouse, button.rect)
		fillColor := raylib.DARKGRAY
		textColor := raylib.RAYWHITE

		if button.is_active {
			fillColor = raylib.SKYBLUE
			textColor = raylib.BLACK
		} else if hovered {
			fillColor = raylib.GRAY
		}

		raylib.DrawRectangleRec(button.rect, fillColor)
		raylib.DrawRectangleLinesEx(button.rect, 1, raylib.LIGHTGRAY)

		textWidth := raylib.MeasureText(button.label, selectorFontSize)
		textX := i32(button.rect.x + (button.rect.width - f32(textWidth)) * 0.5)
		textY := i32(button.rect.y + (button.rect.height - f32(selectorFontSize)) * 0.5)
		raylib.DrawText(button.label, textX, textY, selectorFontSize, textColor)

		// Draw line from button to body when hovering and no body is selected
		if hovered && selectedBodyID == 0 && !button.is_reset {
			body := findBodyByID(bodies, button.body_id)
			if body != nil {
				// Convert body world position to screen coordinates
				bodyScreenPos := raylib.GetWorldToScreen2D(body.position, camera)
				// Button center
				buttonCenter := raylib.Vector2 {
					button.rect.x + button.rect.width * 0.5,
					button.rect.y + button.rect.height * 0.5,
				}
				// Draw thin line in the body's color
				raylib.DrawLineV(buttonCenter, bodyScreenPos, body.color)
			}
		}
	}
}

massToRadius :: proc(mass: f32) -> f32 {
	// Assuming density is constant, radius is proportional to the cube root of mass
	density: f32 = 1.0 // You can adjust this value to scale the sizes of the bodies
	return math.pow(mass / density, 1.0 / 3.0)
}

// Linearly interpolate between two colors
lerpColor :: proc(a, b: raylib.Color, t: f32) -> raylib.Color {
	t_clamped := math.clamp(t, 0, 1)
	return raylib.Color {
		u8(f32(a.r) * (1 - t_clamped) + f32(b.r) * t_clamped),
		u8(f32(a.g) * (1 - t_clamped) + f32(b.g) * t_clamped),
		u8(f32(a.b) * (1 - t_clamped) + f32(b.b) * t_clamped),
		u8(f32(a.a) * (1 - t_clamped) + f32(b.a) * t_clamped),
	}
}

// Determine body color based on mass using a spectrum gradient
// Spectrum: Cyan (asteroids) -> Blue (moons) -> Green (planets) -> Yellow (heavy planets) -> Orange/Red (stars)
colorFromMass :: proc(mass: f32) -> raylib.Color {
	if mass >= STAR_MASS_THRESHOLD {
		// Star: Red/Orange
		return raylib.RED
	} else if mass >= HEAVY_PLANET_THRESHOLD {
		// Heavy Planet: Orange/Yellow gradient
		t := (mass - HEAVY_PLANET_THRESHOLD) / (STAR_MASS_THRESHOLD - HEAVY_PLANET_THRESHOLD)
		return lerpColor(raylib.YELLOW, raylib.ORANGE, t)
	} else if mass >= PLANET_THRESHOLD {
		// Planet: Green/Yellow gradient
		t := (mass - PLANET_THRESHOLD) / (HEAVY_PLANET_THRESHOLD - PLANET_THRESHOLD)
		return lerpColor(raylib.GREEN, raylib.YELLOW, t)
	} else if mass >= MOON_THRESHOLD {
		// Moon: Blue/Green gradient
		t := (mass - MOON_THRESHOLD) / (PLANET_THRESHOLD - MOON_THRESHOLD)
		return lerpColor(raylib.BLUE, raylib.GREEN, t)
	} else {
		// Asteroid: Cyan/Blue gradient
		t := mass / MOON_THRESHOLD
		return lerpColor(raylib.SKYBLUE, raylib.BLUE, t)
	}
}

generateSolarSystem :: proc() -> [dynamic]Body {
	bodies: [dynamic]Body

	starPosition := raylib.Vector2{screenWidth * 0.5, screenHeight * 0.5}
	star := Body {
		id       = allocBodyID(),
		position = starPosition,
		velocity = raylib.Vector2{0, 0},
		mass     = STAR_MASS_VALUE,
		radius   = massToRadius(STAR_MASS_VALUE),
		color    = colorFromMass(STAR_MASS_VALUE),
	}
	append(&bodies, star)

	planetCount := int(rand.float32_range(f32(minPlanetCount), f32(maxPlanetCount + 1)))
	if planetCount < minPlanetCount {
		planetCount = minPlanetCount
	}
	if planetCount > maxPlanetCount {
		planetCount = maxPlanetCount
	}

	planetOrbits: [dynamic]f32
	range: f32 = PLANET_MAX_ORBIT_VALUE - PLANET_MIN_ORBIT_VALUE
	for i in 0 ..< planetCount {
		t := f32(i)
		if planetCount > 1 {
			t /= f32(planetCount - 1)
		}

		slotOrbit := PLANET_MIN_ORBIT_VALUE + range * t
		orbitRadius :=
			slotOrbit +
			rand.float32_range(
				-PLANET_ORBIT_VARIANCE_FACTOR * PLANET_MIN_GAP_VALUE,
				PLANET_ORBIT_VARIANCE_FACTOR * PLANET_MIN_GAP_VALUE,
			)
		if i > 0 {
			minAllowed := planetOrbits[i - 1] + PLANET_MIN_GAP_VALUE
			if orbitRadius < minAllowed {
				orbitRadius = minAllowed
			}
		}
		if orbitRadius > PLANET_MAX_ORBIT_VALUE {
			orbitRadius = PLANET_MAX_ORBIT_VALUE
		}

		append(&planetOrbits, orbitRadius)

		mass := rand.float32_range(PLANET_MASS_MIN, PLANET_MASS_MAX)
		append(
			&bodies,
			makeOrbitingBody(
				star,
				orbitRadius,
				mass,
				massToRadius(mass),
				rand.float32_range(PLANET_SPEED_VARIANCE_MIN, PLANET_SPEED_VARIANCE_MAX),
			),
		)
	}

	midIndex := planetCount / 2
	innerReferenceIndex := 1
	if planetCount <= 2 {
		innerReferenceIndex = 0
	}
	if midIndex <= innerReferenceIndex {
		midIndex = innerReferenceIndex + 1
	}
	if midIndex >= len(planetOrbits) {
		midIndex = len(planetOrbits) - 1
	}

	innerBeltMin := planetOrbits[innerReferenceIndex] + INNER_BELT_PADDING_VALUE
	innerBeltMax := planetOrbits[midIndex] - INNER_BELT_PADDING_VALUE
	if innerBeltMax <= innerBeltMin {
		innerBeltCenter := (planetOrbits[0] + planetOrbits[len(planetOrbits) - 1]) * 0.5
		innerBeltMin = innerBeltCenter - 50
		innerBeltMax = innerBeltCenter + 50
	}
	appendAsteroidBelt(&bodies, star, innerBeltMin, innerBeltMax, innerBeltAsteroidCount)

	outerBeltMin := planetOrbits[len(planetOrbits) - 1] + OUTER_BELT_INNER_PADDING_VALUE
	outerBeltMax := outerBeltMin + OUTER_BELT_WIDTH_VALUE
	appendAsteroidBelt(&bodies, star, outerBeltMin, outerBeltMax, outerBeltAsteroidCount)

	return bodies
}

makeOrbitingBody :: proc(
	star: Body,
	orbitRadius, mass, radius: f32,
	speedMultiplier: f32,
) -> Body {
	angle := rand.float32_range(0, FULL_ROTATION * raylib.PI)
	radial := raylib.Vector2{math.cos(angle), math.sin(angle)}
	tangent := raylib.Vector2{-radial.y, radial.x}
	orbitalSpeed := math.sqrt(star.mass / orbitRadius) * ORBIT_SPEED_SCALE_VALUE * speedMultiplier

	return Body {
		id = allocBodyID(),
		position = star.position + radial * orbitRadius,
		velocity = star.velocity + tangent * orbitalSpeed,
		mass = mass,
		radius = radius,
		color = colorFromMass(mass),
	}
}

appendAsteroidBelt :: proc(
	bodies: ^[dynamic]Body,
	star: Body,
	minOrbit, maxOrbit: f32,
	asteroidCount: int,
) {
	if asteroidCount <= 0 {
		return
	}

	coreCount := int(f32(asteroidCount) * 0.9)
	w := maxOrbit - minOrbit
	if w < 1 {
		w = 1
	}
	extendedMin := minOrbit - w * 0.35
	extendedMax := maxOrbit + w * 0.35

	for i in 0 ..< asteroidCount {
		orbitRadius := rand.float32_range(minOrbit, maxOrbit)
		if i >= coreCount {
			orbitRadius = rand.float32_range(extendedMin, extendedMax)
		}
		mass := rand.float32_range(ASTEROID_MASS_MIN, ASTEROID_MASS_MAX)
		append(
			bodies,
			makeOrbitingBody(
				star,
				orbitRadius,
				mass,
				massToRadius(mass),
				rand.float32_range(ASTEROID_SPEED_VARIANCE_MIN, ASTEROID_SPEED_VARIANCE_MAX),
			),
		)
	}
}

// Generate a random velocity vector tangential to the initial position to create more interesting motion
randomVelocity :: proc() -> raylib.Vector2 {
	angle := rand.float32_range(0, FULL_ROTATION * raylib.PI)
	speed := rand.float32_range(0, ASTEROID_VELOCITY_MAX) // Random speed between 0 and 10
	return raylib.Vector2{math.cos(angle) * speed, math.sin(angle) * speed}
}

averageBodyPosition :: proc(bodies: [dynamic]Body) -> raylib.Vector2 {
	if len(bodies) == 0 {
		return raylib.Vector2{0, 0}
	}

	avgPosition := raylib.Vector2{0, 0}
	for body, _ in bodies {
		avgPosition += body.position
	}

	return avgPosition / f32(len(bodies))
}

// Removes the smaller mass body and adds the mass to the larger body when two bodies collide, simulating inelastic collisions and preventing extreme forces from close proximity
resolveBodyCollision :: proc(bodies: ^[dynamic]Body) {
	if len(bodies^) <= 1 {
		return
	}

	for {
		if len(bodies^) <= 1 {
			return
		}

		mergedAny := false
		removed := make([]bool, len(bodies^))

		for i in 0 ..< len(bodies^) {
			if removed[i] {
				continue
			}

			for j in i + 1 ..< len(bodies^) {
				if removed[j] {
					continue
				}

				a := bodies^[i]
				b := bodies^[j]

				delta := b.position - a.position
				radiusSum := a.radius + b.radius
				if raylib.Vector2LengthSqr(delta) > radiusSum * radiusSum {
					continue
				}

				survivorIndex := i
				mergedIndex := j
				if b.mass > a.mass {
					survivorIndex = j
					mergedIndex = i
				}

				survivor := bodies^[survivorIndex]
				merged := bodies^[mergedIndex]

				totalMass := survivor.mass + merged.mass
				if totalMass <= 0 {
					continue
				}

				survivor.velocity =
					(survivor.velocity * survivor.mass + merged.velocity * merged.mass) / totalMass
				survivor.mass = totalMass
				survivor.radius = math.sqrt(
					survivor.radius * survivor.radius + merged.radius * merged.radius,
				)
				survivor.color = colorFromMass(survivor.mass)

				bodies^[survivorIndex] = survivor
				removed[mergedIndex] = true
				mergedAny = true

				if survivorIndex == i {
					continue
				}

				break
			}
		}

		if !mergedAny {
			return
		}

		writeIndex := 0
		for readIndex in 0 ..< len(bodies^) {
			if removed[readIndex] {
				continue
			}

			if writeIndex != readIndex {
				bodies^[writeIndex] = bodies^[readIndex]
			}
			writeIndex += 1
		}

		resize(bodies, writeIndex)
	}

}

removeStrayBodies :: proc(bodies: ^[dynamic]Body) {
	if len(bodies^) <= 1 {
		return
	}

	avgPosition := averageBodyPosition(bodies^)
	maxDx := (screenWidth * 0.5 / maxZoomOut) + massToRadius(STAR_MASS_VALUE)
	maxDy := (screenHeight * 0.5 / maxZoomOut) + massToRadius(STAR_MASS_VALUE)
	cullRadius := math.max(maxDx, maxDy) * strayCullMultiplier
	cullRadiusSq := cullRadius * cullRadius

	writeIndex := 1
	for readIndex in 1 ..< len(bodies^) {
		body := bodies^[readIndex]
		dx := body.position.x - avgPosition.x
		dy := body.position.y - avgPosition.y
		distanceSq := dx * dx + dy * dy
		if distanceSq <= cullRadiusSq {
			if writeIndex != readIndex {
				bodies^[writeIndex] = body
			}
			writeIndex += 1
		}
	}

	resize(bodies, writeIndex)
}

// Update the camera target to keep it centered on all the bodies, zooming out if they spread too far apart
updateCamera :: proc(bodies: [dynamic]Body) {
	if len(bodies) == 0 {
		return
	}

	camera.offset = raylib.Vector2 {
		f32(raylib.GetScreenWidth()) * 0.5,
		f32(raylib.GetScreenHeight()) * 0.5,
	}
	deltaTime := raylib.GetFrameTime()
	alpha := 1.0 - math.exp(-zoomSmoothing * deltaTime)

	if selectedBodyID != 0 {
		for body, _ in bodies {
			if body.id != selectedBodyID {
				continue
			}

			camera.target += (body.position - camera.target) * alpha
			targetZoom := math.clamp(selectedBodyZoom, maxZoomOut, maxZoomIn)
			camera.zoom = math.clamp(
				camera.zoom + (targetZoom - camera.zoom) * alpha,
				maxZoomOut,
				maxZoomIn,
			)
			return
		}

		selectedBodyID = 0
	}

	// Calculate the average position of all bodies to center the camera
	avgPosition := averageBodyPosition(bodies)
	camera.target += (avgPosition - camera.target) * alpha

	// Calculate max axis extents from the average position
	maxDx := f32(0)
	maxDy := f32(0)
	for body, _ in bodies {
		dx := math.abs(body.position.x - avgPosition.x) + massToRadius(body.mass)
		dy := math.abs(body.position.y - avgPosition.y) + massToRadius(body.mass)
		if dx > maxDx {
			maxDx = dx
		}
		if dy > maxDy {
			maxDy = dy
		}
	}

	margin := f32(0.9)
	halfScreenWidth := f32(raylib.GetScreenWidth()) * 0.5
	halfScreenHeight := f32(raylib.GetScreenHeight()) * 0.5

	zoomX := f32(4.0)
	zoomY := f32(4.0)
	if maxDx > 0 {
		zoomX = halfScreenWidth / maxDx
	}
	if maxDy > 0 {
		zoomY = halfScreenHeight / maxDy
	}

	fitZoom := math.min(zoomX, zoomY) * margin
	targetZoom := math.clamp(fitZoom, maxZoomOut, maxZoomIn)
	camera.zoom = math.clamp(
		camera.zoom + (targetZoom - camera.zoom) * alpha,
		maxZoomOut,
		maxZoomIn,
	)

}
