package main

import "core:math"
import "vendor:raylib"


// Allocates unique IDs for bodies, increments global counter
allocBodyID :: proc() -> u64 {
	id := nextBodyID
	nextBodyID += 1
	return id
}

// Searches bodies array for a specific body by ID
findBodyByID :: proc(bodies: [dynamic]Body, id: u64) -> ^Body {
	for i := 0; i < len(bodies); i += 1 {
		if bodies[i].id == id {
			return &bodies[i]
		}
	}
	return nil
}

// Handles inelastic collisions - merges smaller body into larger, conserves momentum/mass
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

// Removes bodies outside view frustum (optimization)
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
