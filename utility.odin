package main

import "core:math"
import "core:math/rand"
import "vendor:raylib"


// Converts mass to visual radius using cube root (constant density assumption)
massToRadius :: proc(mass: f32) -> f32 {
	// Assuming density is constant, radius is proportional to the cube root of mass
	density: f32 = 1.0 // You can adjust this value to scale the sizes of the bodies
	return math.pow(mass / density, 1.0 / 3.0)
}

// Simple AABB point-in-rectangle collision check
isPointInRect :: proc(p: raylib.Vector2, rect: raylib.Rectangle) -> bool {
	return(
		p.x >= rect.x &&
		p.x <= rect.x + rect.width &&
		p.y >= rect.y &&
		p.y <= rect.y + rect.height \
	)
}

// Generates random velocity vector (angle + random speed)
randomVelocity :: proc() -> raylib.Vector2 {
	angle := rand.float32_range(0, FULL_ROTATION * raylib.PI)
	speed := rand.float32_range(0, ASTEROID_VELOCITY_MAX) // Random speed between 0 and 10
	return raylib.Vector2{math.cos(angle) * speed, math.sin(angle) * speed}
}

// Calculates centroid of all bodies for camera positioning
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
