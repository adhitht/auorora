#!/usr/bin/env python3
"""
Script to create environment map metadata database from .exr files.

Usage:
    python create_env_map_metadata.py --input-dir ./env_map --output ./env_map/envmapsmetadata.json
"""

import argparse
import os
os.environ["OPENCV_IO_ENABLE_OPENEXR"] = "1"
import cv2
import numpy as np
import json


def get_luminance(img):
    """Calculate luminance of an RGB image."""
    return 0.114 * img[:, :, 0] + 0.587 * img[:, :, 1] + 0.299 * img[:, :, 2]


def analyze_env_map(filename, base_path):
    """Analyze a single environment map to extract lighting metadata."""
    full_path = os.path.join(base_path, filename)
    
    if not os.path.exists(full_path):
        print(f"Error: {full_path} not found. Skipping.")
        return None
    
    #loading img
    img = cv2.imread(full_path, cv2.IMREAD_ANYCOLOR | cv2.IMREAD_ANYDEPTH)
    
    if img is None:
        print(f"Error: Could not read {filename}")
        return None
    
    h, w, c = img.shape
    
    # Find key light
    lum = get_luminance(img)
    min_val, max_val, min_loc, max_loc = cv2.minMaxLoc(lum)
    brightest_x, brightest_y = max_loc
    
    azimuth = ((brightest_x / w) - 0.5) * 360.0
    elevation = -((brightest_y / h) - 0.5) * 180.0
    
    # Ambient color
    cutoff = np.percentile(lum, 90)
    mask = lum < cutoff
    
    avg_b = np.mean(img[:, :, 0][mask])
    avg_g = np.mean(img[:, :, 1][mask])
    avg_r = np.mean(img[:, :, 2][mask])
    
    ambient_rgb = [float(avg_r), float(avg_g), float(avg_b)]
    
    # Position tag
    if elevation > 45:
        position_tag = "top"
    elif elevation < -10:
        position_tag = "low"
    else:
        position_tag = "side"
    
    print(f"{filename} | Az: {azimuth:.1f}° | El: {elevation:.1f}°")
    
    return {
        "id": filename,
        "light_azimuth": azimuth,
        "light_elevation": elevation,
        "max_intensity": float(max_val),
        "ambient_rgb": ambient_rgb,
        "position_tag": position_tag
    }


def main():
    parser = argparse.ArgumentParser(description="Create environment map metadata database")
    parser.add_argument(
        "--input-dir",
        default="./env_map",
        help="Directory containing .exr environment map files"
    )
    parser.add_argument(
        "--output",
        default="./env_map/envmapsmetadata.json",
        help="Output path for metadata JSON file"
    )
    parser.add_argument(
        "--start-index",
        type=int,
        default=1,
        help="Starting index for envmap files (e.g., envmap1.exr)"
    )
    parser.add_argument(
        "--end-index",
        type=int,
        default=10,
        help="Ending index for envmap files"
    )
    
    args = parser.parse_args()
    
    print(f"Scanning {args.input_dir} for environment maps.\n\n")
    
    metadata = []
    
    for i in range(args.start_index, args.end_index):
        fname = f"envmap{i}.exr"
        data = analyze_env_map(fname, args.input_dir)
        if data:
            metadata.append(data)
    
    #save it in a JSON file
    os.makedirs(os.path.dirname(args.output) if os.path.dirname(args.output) else ".", exist_ok=True)
    with open(args.output, 'w') as f:
        json.dump(metadata, f, indent=4)
    
    print(f"Processed {len(metadata)} maps")
    print(f"Saved to: {args.output}")


if __name__ == "__main__":
    main()
