#!/usr/bin/env python3
"""
Parse a GPX file and extract km-by-km altitude profile for race strategy generation.

Usage:
    python parse_gpx.py <path_to_gpx_file>

Output:
    JSON with distance, elevation gain/loss, and altitude per km / per 0.25 km.
"""

import sys
import json
import math
import xml.etree.ElementTree as ET
from typing import List, Tuple


def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance between two points in meters."""
    R = 6371000  # Earth radius in meters
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmbda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlmbda / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


def parse_gpx(path: str) -> List[Tuple[float, float, float]]:
    """Parse GPX and return list of (lat, lon, elevation) tuples."""
    tree = ET.parse(path)
    root = tree.getroot()

    # Handle GPX namespace
    ns = {'gpx': 'http://www.topografix.com/GPX/1/1'}
    if root.tag.startswith('{'):
        # Extract the namespace from the root tag
        actual_ns = root.tag.split('}')[0].strip('{')
        ns = {'gpx': actual_ns}

    points = []
    # Try both namespaced and non-namespaced
    trkpts = root.findall('.//gpx:trkpt', ns)
    if not trkpts:
        trkpts = root.findall('.//trkpt')

    # Also try route points (rtept) if no track points
    if not trkpts:
        trkpts = root.findall('.//gpx:rtept', ns)
    if not trkpts:
        trkpts = root.findall('.//rtept')

    for trkpt in trkpts:
        lat = float(trkpt.get('lat'))
        lon = float(trkpt.get('lon'))
        ele_elem = trkpt.find('gpx:ele', ns)
        if ele_elem is None:
            ele_elem = trkpt.find('ele')
        ele = float(ele_elem.text) if ele_elem is not None and ele_elem.text else 0.0
        points.append((lat, lon, ele))

    return points


def build_profile(points: List[Tuple[float, float, float]], interval_m: float = 250.0):
    """
    Build cumulative distance + altitude profile, sampling every `interval_m` meters.
    Returns list of dicts with km and altitude.
    """
    if len(points) < 2:
        raise ValueError("GPX file contains fewer than 2 points")

    # Build cumulative distance + altitude pairs
    cumdist = [0.0]
    altitudes = [points[0][2]]

    for i in range(1, len(points)):
        d = haversine(points[i-1][0], points[i-1][1], points[i][0], points[i][1])
        cumdist.append(cumdist[-1] + d)
        altitudes.append(points[i][2])

    total_dist = cumdist[-1]

    # Sample at regular intervals
    sampled = []
    target = 0.0
    j = 0
    while target <= total_dist:
        # Find the segment containing `target` distance
        while j < len(cumdist) - 1 and cumdist[j+1] < target:
            j += 1
        if j >= len(cumdist) - 1:
            sampled.append({"km": round(target / 1000.0, 2), "alt": round(altitudes[-1], 1)})
            break
        # Linear interpolation
        d0, d1 = cumdist[j], cumdist[j+1]
        a0, a1 = altitudes[j], altitudes[j+1]
        if d1 == d0:
            alt = a0
        else:
            ratio = (target - d0) / (d1 - d0)
            alt = a0 + ratio * (a1 - a0)
        sampled.append({"km": round(target / 1000.0, 2), "alt": round(alt, 1)})
        target += interval_m

    # Always include the last point
    if sampled[-1]["km"] < total_dist / 1000.0:
        sampled.append({"km": round(total_dist / 1000.0, 2), "alt": round(altitudes[-1], 1)})

    return sampled, total_dist, altitudes


def compute_elevation_gain_loss(altitudes: List[float], threshold: float = 1.0):
    """Compute total elevation gain/loss with a small threshold to filter GPS noise."""
    gain = 0.0
    loss = 0.0
    for i in range(1, len(altitudes)):
        delta = altitudes[i] - altitudes[i-1]
        if delta >= threshold:
            gain += delta
        elif delta <= -threshold:
            loss += abs(delta)
    return round(gain), round(loss)


def main():
    if len(sys.argv) != 2:
        print("Usage: python parse_gpx.py <path_to_gpx>", file=sys.stderr)
        sys.exit(1)

    path = sys.argv[1]

    try:
        points = parse_gpx(path)
        if not points:
            raise ValueError("No track points found in GPX file")

        sampled_quarter, total_dist_m, all_altitudes = build_profile(points, interval_m=250.0)
        sampled_km, _, _ = build_profile(points, interval_m=1000.0)
        gain, loss = compute_elevation_gain_loss(all_altitudes)

        result = {
            "distance_km": round(total_dist_m / 1000.0, 2),
            "elevation_gain_m": gain,
            "elevation_loss_m": loss,
            "altitude_per_km": sampled_km,
            "altitude_per_quarter_km": sampled_quarter,
        }
        print(json.dumps(result, indent=2))

    except Exception as e:
        print(f"Error parsing GPX: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
