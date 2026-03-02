package main

import "core:math"
import "core:math/rand"
import "vendor:raylib"


// Creates entire solar system: star, planets in orbits, inner/outer asteroid belts
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

// Creates a single body in circular orbit around a star with proper initial velocity
makeOrbitingBody :: proc(star: Body, orbitRadius, mass, radius: f32, speedMultiplier: f32) ->


	Body {// Populates asteroid belt region with randomized orbital bodies
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
