package main

import "vendor:raylib"


// Performs physics stepping: gravity calculations and position updates
stepPhysics :: proc(bodies: ^[dynamic]Body, deltaTime: f32) {
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
}
