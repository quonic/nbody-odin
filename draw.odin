package main

import "core:fmt"
import "core:math"
import "vendor:raylib"


// Constructs selector button layout (grid-based) with labels for Star/Planets
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

// Input handling for body selection buttons, updates selectedBodyID
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

// Renders selector buttons with visual states (active/hovered), draws connection lines to bodies
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
