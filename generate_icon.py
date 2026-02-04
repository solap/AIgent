#!/usr/bin/env python3
"""Generate a cooler AIgent app icon with gradient background."""

from PIL import Image, ImageDraw
import math
import os

def create_gradient(width, height):
    """Create a vibrant purple-to-orange gradient background."""
    img = Image.new('RGB', (width, height))
    pixels = img.load()

    # Gradient colors: deep purple -> magenta -> coral orange
    colors = [
        (88, 28, 135),    # Deep purple
        (168, 85, 247),   # Bright purple
        (236, 72, 153),   # Pink/magenta
        (251, 146, 60),   # Coral orange
    ]

    for y in range(height):
        # Calculate position in gradient (0 to 1)
        t = y / height

        # Determine which color segment we're in
        segment = t * (len(colors) - 1)
        idx = int(segment)
        if idx >= len(colors) - 1:
            idx = len(colors) - 2

        # Interpolate between two colors
        local_t = segment - idx
        c1 = colors[idx]
        c2 = colors[idx + 1]

        r = int(c1[0] + (c2[0] - c1[0]) * local_t)
        g = int(c1[1] + (c2[1] - c1[1]) * local_t)
        b = int(c1[2] + (c2[2] - c1[2]) * local_t)

        for x in range(width):
            # Add slight diagonal variation for more interest
            offset = (x / width) * 0.15
            t2 = min(1, max(0, t + offset - 0.075))
            segment2 = t2 * (len(colors) - 1)
            idx2 = int(segment2)
            if idx2 >= len(colors) - 1:
                idx2 = len(colors) - 2
            local_t2 = segment2 - idx2
            c1 = colors[idx2]
            c2 = colors[idx2 + 1]
            r = int(c1[0] + (c2[0] - c1[0]) * local_t2)
            g = int(c1[1] + (c2[1] - c1[1]) * local_t2)
            b = int(c1[2] + (c2[2] - c1[2]) * local_t2)
            pixels[x, y] = (r, g, b)

    return img

def draw_rounded_rect(draw, bbox, radius, fill, outline=None, outline_width=0):
    """Draw a rounded rectangle."""
    x1, y1, x2, y2 = bbox

    # Draw the main rectangle body
    draw.rectangle([x1 + radius, y1, x2 - radius, y2], fill=fill)
    draw.rectangle([x1, y1 + radius, x2, y2 - radius], fill=fill)

    # Draw the four corners
    draw.pieslice([x1, y1, x1 + radius * 2, y1 + radius * 2], 180, 270, fill=fill)
    draw.pieslice([x2 - radius * 2, y1, x2, y1 + radius * 2], 270, 360, fill=fill)
    draw.pieslice([x1, y2 - radius * 2, x1 + radius * 2, y2], 90, 180, fill=fill)
    draw.pieslice([x2 - radius * 2, y2 - radius * 2, x2, y2], 0, 90, fill=fill)

def draw_4point_star(draw, cx, cy, outer_r, inner_r, fill):
    """Draw a 4-pointed star sparkle."""
    points = []
    for i in range(8):
        angle = math.radians(i * 45 - 90)
        r = outer_r if i % 2 == 0 else inner_r
        x = cx + r * math.cos(angle)
        y = cy + r * math.sin(angle)
        points.append((x, y))
    draw.polygon(points, fill=fill)

def create_icon(size):
    """Create the app icon at the specified size."""
    # Create gradient background
    img = create_gradient(size, size)
    draw = ImageDraw.Draw(img)

    # Scale factors
    s = size / 1024.0

    # Draw shadow for speech bubble
    shadow_offset = int(8 * s)
    bubble_x1 = int(140 * s)
    bubble_y1 = int(120 * s)
    bubble_x2 = int(920 * s)
    bubble_y2 = int(750 * s)
    corner_radius = int(100 * s)

    # Shadow
    draw_rounded_rect(draw,
        (bubble_x1 + shadow_offset, bubble_y1 + shadow_offset,
         bubble_x2 + shadow_offset, bubble_y2 + shadow_offset),
        corner_radius, fill=(0, 0, 0, 80))

    # Speech bubble tail (shadow)
    tail_points_shadow = [
        (int(180 * s) + shadow_offset, int(750 * s) + shadow_offset),
        (int(120 * s) + shadow_offset, int(900 * s) + shadow_offset),
        (int(350 * s) + shadow_offset, int(750 * s) + shadow_offset),
    ]
    draw.polygon(tail_points_shadow, fill=(0, 0, 0, 60))

    # Main speech bubble (white)
    draw_rounded_rect(draw, (bubble_x1, bubble_y1, bubble_x2, bubble_y2),
                     corner_radius, fill=(255, 255, 255))

    # Speech bubble tail
    tail_points = [
        (int(180 * s), int(750 * s)),
        (int(120 * s), int(900 * s)),
        (int(350 * s), int(750 * s)),
    ]
    draw.polygon(tail_points, fill=(255, 255, 255))

    # Draw sparkle stars with gradient colors
    # Large main star - gradient purple to pink
    main_star_color = (147, 51, 234)  # Vivid purple
    draw_4point_star(draw, int(480 * s), int(420 * s), int(220 * s), int(45 * s), main_star_color)

    # Small star top-right - cyan/teal
    small_star_color = (34, 211, 238)  # Cyan
    draw_4point_star(draw, int(720 * s), int(300 * s), int(70 * s), int(15 * s), small_star_color)

    # Small star bottom-left - coral/orange
    accent_star_color = (251, 146, 60)  # Coral orange
    draw_4point_star(draw, int(300 * s), int(580 * s), int(65 * s), int(14 * s), accent_star_color)

    # Extra tiny star - pink
    pink_star_color = (244, 114, 182)  # Pink
    draw_4point_star(draw, int(750 * s), int(520 * s), int(40 * s), int(10 * s), pink_star_color)

    return img

def main():
    # Icon sizes needed for iOS
    sizes = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024]

    output_dir = "AIgent/Assets.xcassets/AppIcon.appiconset"

    for size in sizes:
        icon = create_icon(size)
        filename = f"icon-{size}.png"
        filepath = os.path.join(output_dir, filename)
        icon.save(filepath, "PNG")
        print(f"Generated {filepath}")

    print("\nDone! All icons generated with the new gradient design.")

if __name__ == "__main__":
    main()
