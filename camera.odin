package main

import "core:math"
import "vendor:raylib"


// Smart camera positioning - centers on selected body or all bodies, calculates zoom to fit view, smooth interpolation
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
