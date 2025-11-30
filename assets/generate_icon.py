#!/usr/bin/env python3
"""
Script to generate app icon PNG files
Requires: pip install pillow
"""

import os
import sys
import math

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Installing required packages...")
    os.system(f"{sys.executable} -m pip install pillow")
    from PIL import Image, ImageDraw

def generate_icon(output_dir, size=1024):
    """Generate a beautiful minimalistic FinanceFlow app icon"""
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Calculate scaling factor
    scale = size / 1024.0
    center = size // 2
    
    # Create image with elegant solid background
    # Beautiful deep indigo-purple
    img = Image.new('RGB', (size, size), color=(99, 102, 241))  # #6366F1
    draw = ImageDraw.Draw(img)
    
    # Create subtle gradient using layered circles for depth
    max_radius = int(size * 0.72)
    num_layers = 30
    
    for i in range(num_layers):
        radius = int(max_radius * (1 - i / num_layers))
        if radius <= 0:
            break
        
        # Subtle gradient: #6366F1 -> #8B5CF6
        ratio = i / num_layers
        r = int(99 + (139 - 99) * ratio)
        g = int(102 + (92 - 102) * ratio)
        b = int(241 + (246 - 241) * ratio)
        
        draw.ellipse([center - radius, center - radius, 
                     center + radius, center + radius], 
                    fill=(r, g, b))
    
    # Draw ultra-minimalistic flowing design
    # Single elegant curve that represents flow
    line_width = int(16 * scale)
    
    def draw_elegant_curve():
        """Draw a single, beautiful flowing curve"""
        points = []
        num_points = 150
        
        for i in range(num_points):
            t = i / num_points
            
            # Create a beautiful, smooth S-curve
            # Starts from bottom-left, flows gracefully to top-right
            start_x, start_y = 200, 750
            end_x, end_y = 800, 250
            
            # Base linear interpolation
            base_x = start_x + (end_x - start_x) * t
            base_y = start_y + (end_y - start_y) * t
            
            # Add elegant wave motion - smooth and minimal
            # Single sine wave for elegance
            wave_amplitude = 80
            wave_frequency = 1.2
            offset_x = wave_amplitude * math.sin(t * math.pi * wave_frequency) * (1 - t * 0.3)
            offset_y = wave_amplitude * 0.6 * math.cos(t * math.pi * wave_frequency * 1.1) * (1 - t * 0.2)
            
            x = int((base_x + offset_x) * scale)
            y = int((base_y + offset_y) * scale)
            points.append((x, y))
        
        # Draw the curve with smooth, rounded ends
        for i in range(len(points)):
            x, y = points[i]
            
            # Vary line width slightly for elegance (thinner at ends)
            if i < 10 or i > len(points) - 10:
                current_width = int(line_width * 0.6)
            elif i < 20 or i > len(points) - 20:
                current_width = int(line_width * 0.8)
            else:
                current_width = line_width
            
            draw.ellipse([x - current_width//2, y - current_width//2, 
                         x + current_width//2, y + current_width//2], 
                        fill='white')
        
        # Connect points smoothly
        for i in range(len(points) - 1):
            x1, y1 = points[i]
            x2, y2 = points[i + 1]
            
            steps = max(int(math.sqrt((x2-x1)**2 + (y2-y1)**2) / 4), 8)
            for j in range(1, steps):
                t = j / steps
                x = int(x1 + (x2 - x1) * t)
                y = int(y1 + (y2 - y1) * t)
                
                # Determine width for this point
                point_idx = i + t
                if point_idx < 10 or point_idx > len(points) - 10:
                    current_width = int(line_width * 0.6)
                elif point_idx < 20 or point_idx > len(points) - 20:
                    current_width = int(line_width * 0.8)
                else:
                    current_width = line_width
                
                draw.ellipse([x - current_width//2, y - current_width//2, 
                             x + current_width//2, y + current_width//2], 
                            fill='white')
    
    # Draw the elegant curve
    draw_elegant_curve()
    
    # Save the PNG
    output_path = os.path.join(output_dir, f"AppIcon-{size}x{size}.png")
    img.save(output_path, 'PNG')
    
    print(f"✓ Generated {output_path} ({size}x{size})")
    return output_path

if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.join(script_dir, "icon_output")
    
    # Generate 1024x1024 icon (required for iOS)
    icon_path = generate_icon(output_dir, size=1024)
    
    # Copy to AppIcon.appiconset
    appicon_dir = os.path.join(script_dir, "..", "FinanceFlow", "Assets.xcassets", "AppIcon.appiconset")
    appicon_dir = os.path.normpath(appicon_dir)
    
    if os.path.exists(appicon_dir):
        import shutil
        dest_path = os.path.join(appicon_dir, "AppIcon-1024x1024.png")
        shutil.copy2(icon_path, dest_path)
        print(f"✓ Copied icon to {dest_path}")
    else:
        print(f"⚠ AppIcon directory not found at {appicon_dir}")
        print(f"  Please manually copy {icon_path} to the AppIcon.appiconset folder")
    
    print(f"\n✓ Icon generation complete!")
