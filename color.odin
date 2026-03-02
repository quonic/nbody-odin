package main

import "core:math"
import "vendor:raylib"


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
