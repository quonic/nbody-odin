package main

import "core:math"
import "core:math/rand"
import "vendor:raylib"


// Physics Body struct
Body :: struct {
	position: raylib.Vector2,
	velocity: raylib.Vector2,
	mass:     f32,
	radius:   f32,
	color:    raylib.Color,
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

minPlanetCount :: 6
maxPlanetCount :: 10
innerBeltAsteroidCount :: 100
outerBeltAsteroidCount :: 200

starMass: f32 = 1000000
planetMinOrbit: f32 = 1800
planetMaxOrbit: f32 = 8200
minPlanetGap: f32 = 55
innerBeltPadding: f32 = 20
outerBeltInnerPadding: f32 = 1400
outerBeltWidth: f32 = 260
orbitSpeedScale: f32 = 0.95

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
		defer raylib.EndDrawing()
		raylib.DrawFPS(10, 10)
		raylib.BeginMode2D(camera)
		defer raylib.EndMode2D()


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
		updateCamera(bodies)
		// Draw bodies
		for body, _ in bodies {
			raylib.DrawCircleV(body.position, body.radius, body.color)
		}
	}
}

massToRadius :: proc(mass: f32) -> f32 {
	// Assuming density is constant, radius is proportional to the cube root of mass
	density: f32 = 1.0 // You can adjust this value to scale the sizes of the bodies
	return math.pow(mass / density, 1.0 / 3.0)
}

generateSolarSystem :: proc() -> [dynamic]Body {
	bodies: [dynamic]Body

	starPosition := raylib.Vector2{screenWidth * 0.5, screenHeight * 0.5}
	star := Body {
		position = starPosition,
		velocity = raylib.Vector2{0, 0},
		mass     = starMass,
		radius   = massToRadius(starMass),
		color    = raylib.RED,
	}
	append(&bodies, star)

	planetCount := int(rand.float32_range(f32(minPlanetCount), f32(maxPlanetCount + 1)))
	if planetCount < minPlanetCount {
		planetCount = minPlanetCount
	}
	if planetCount > maxPlanetCount {
		planetCount = maxPlanetCount
	}

	planetColors := [8]raylib.Color {
		raylib.SKYBLUE,
		raylib.BLUE,
		raylib.GREEN,
		raylib.YELLOW,
		raylib.ORANGE,
		raylib.PINK,
		raylib.PURPLE,
		raylib.LIME,
	}

	planetOrbits: [dynamic]f32
	range := planetMaxOrbit - planetMinOrbit
	for i in 0 ..< planetCount {
		t := f32(i)
		if planetCount > 1 {
			t /= f32(planetCount - 1)
		}

		slotOrbit := planetMinOrbit + range * t
		orbitRadius := slotOrbit + rand.float32_range(-0.2 * minPlanetGap, 0.2 * minPlanetGap)
		if i > 0 {
			minAllowed := planetOrbits[i - 1] + minPlanetGap
			if orbitRadius < minAllowed {
				orbitRadius = minAllowed
			}
		}
		if orbitRadius > planetMaxOrbit {
			orbitRadius = planetMaxOrbit
		}

		append(&planetOrbits, orbitRadius)

		mass := rand.float32_range(1500, 12000)
		append(
			&bodies,
			makeOrbitingBody(
				star,
				orbitRadius,
				mass,
				massToRadius(mass),
				planetColors[i % len(planetColors)],
				rand.float32_range(0.97, 1.03),
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

	innerBeltMin := planetOrbits[innerReferenceIndex] + innerBeltPadding
	innerBeltMax := planetOrbits[midIndex] - innerBeltPadding
	if innerBeltMax <= innerBeltMin {
		innerBeltCenter := (planetOrbits[0] + planetOrbits[len(planetOrbits) - 1]) * 0.5
		innerBeltMin = innerBeltCenter - 50
		innerBeltMax = innerBeltCenter + 50
	}
	appendAsteroidBelt(&bodies, star, innerBeltMin, innerBeltMax, innerBeltAsteroidCount)

	outerBeltMin := planetOrbits[len(planetOrbits) - 1] + outerBeltInnerPadding
	outerBeltMax := outerBeltMin + outerBeltWidth
	appendAsteroidBelt(&bodies, star, outerBeltMin, outerBeltMax, outerBeltAsteroidCount)

	return bodies
}

makeOrbitingBody :: proc(
	star: Body,
	orbitRadius, mass, radius: f32,
	color: raylib.Color,
	speedMultiplier: f32,
) -> Body {
	angle := rand.float32_range(0, 2 * raylib.PI)
	radial := raylib.Vector2{math.cos(angle), math.sin(angle)}
	tangent := raylib.Vector2{-radial.y, radial.x}
	orbitalSpeed := math.sqrt(star.mass / orbitRadius) * orbitSpeedScale * speedMultiplier

	return Body {
		position = star.position + radial * orbitRadius,
		velocity = star.velocity + tangent * orbitalSpeed,
		mass = mass,
		radius = radius,
		color = color,
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
		mass := rand.float32_range(2, 14)
		append(
			bodies,
			makeOrbitingBody(
				star,
				orbitRadius,
				mass,
				massToRadius(mass),
				raylib.WHITE,
				rand.float32_range(0.93, 1.07),
			),
		)
	}
}

// Generate a random velocity vector tangential to the initial position to create more interesting motion
randomVelocity :: proc() -> raylib.Vector2 {
	angle := rand.float32_range(0, 2 * raylib.PI)
	speed := rand.float32_range(0, 10) // Random speed between 0 and 10
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
	maxDx := (screenWidth * 0.5 / maxZoomOut) + massToRadius(starMass)
	maxDy := (screenHeight * 0.5 / maxZoomOut) + massToRadius(starMass)
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

	camera.offset = raylib.Vector2{screenWidth * 0.5, screenHeight * 0.5}

	// Calculate the average position of all bodies to center the camera
	avgPosition := averageBodyPosition(bodies)
	deltaTime := raylib.GetFrameTime()
	alpha := 1.0 - math.exp(-zoomSmoothing * deltaTime)
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
	halfScreenWidth := screenWidth * 0.5
	halfScreenHeight := screenHeight * 0.5

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
