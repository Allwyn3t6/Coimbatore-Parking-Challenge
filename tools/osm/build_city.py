#!/usr/bin/env python3
"""Build the game's city data from OpenStreetMap.

Downloads roads, buildings, car parks, parks, water and trees for a box in
central Coimbatore through the Overpass API, removes every name/identifying
tag, cleans the geometry and auto-generates parking levels, a race loop and
traffic lanes. Output: data/city.json (rendered directly by the game).

Map data (c) OpenStreetMap contributors, available under the ODbL 1.0:
https://www.openstreetmap.org/copyright

Usage:
  python3 tools/osm/build_city.py                 # fetch + build
  python3 tools/osm/build_city.py --raw raw.json  # build from a saved Overpass response
"""
import argparse
import heapq
import json
import math
import random
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone

import mapbox_earcut as earcut
import numpy as np
from shapely import affinity
from shapely.geometry import LineString, MultiLineString, MultiPolygon, Point, Polygon, box
from shapely.ops import linemerge, nearest_points, unary_union

# Central Coimbatore (bus-stand / market district). Names are never exported.
CENTER_LAT = 11.0168
CENTER_LON = 76.9680
HALF = 650.0  # metres from centre to each edge
DATA_VERSION = 2

MIRRORS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
]

DRIVE_WIDTH = {
    "motorway": 16, "trunk": 15, "primary": 13, "secondary": 11, "tertiary": 9,
    "motorway_link": 7, "trunk_link": 7, "primary_link": 7, "secondary_link": 7, "tertiary_link": 6.5,
    "unclassified": 7, "residential": 6.5, "living_street": 5.5, "service": 4.6, "road": 6,
}
MAJOR = {"motorway", "trunk", "primary", "secondary", "tertiary", "motorway_link", "trunk_link", "primary_link", "secondary_link", "tertiary_link"}
MINOR_PARK = {"residential", "unclassified", "tertiary", "living_street"}

rng = random.Random(20261109)


def log(*a):
    print(*a, file=sys.stderr, flush=True)


# ----------------------------------------------------------------------------- fetch
def bbox():
    dlat = HALF / 110540.0
    dlon = HALF / (111320.0 * math.cos(math.radians(CENTER_LAT)))
    return CENTER_LAT - dlat, CENTER_LON - dlon, CENTER_LAT + dlat, CENTER_LON + dlon


def fetch():
    s, w, n, e = bbox()
    b = f"{s:.6f},{w:.6f},{n:.6f},{e:.6f}"
    q = f"""[out:json][timeout:180];
(
  way["highway"]({b});
  way["building"]({b});
  way["amenity"~"^(parking|bus_station|place_of_worship|hospital|school|college|marketplace)$"]({b});
  way["leisure"~"^(park|garden|pitch|playground|stadium|sports_centre)$"]({b});
  way["landuse"~"^(grass|recreation_ground|village_green|cemetery|meadow)$"]({b});
  way["natural"~"^(water|wood|scrub|grassland)$"]({b});
  node["natural"="tree"]({b});
);
out geom tags;"""
    body = urllib.parse.urlencode({"data": q}).encode()
    last = None
    for attempt in range(3):
        for url in MIRRORS:
            try:
                log("fetching", url)
                req = urllib.request.Request(url, data=body, headers={"User-Agent": "coimbatore-parking-challenge-data-builder/1.0"})
                with urllib.request.urlopen(req, timeout=240) as r:
                    data = json.loads(r.read().decode("utf-8"))
                if data.get("elements"):
                    return data
            except Exception as ex:  # noqa: BLE001
                last = ex
                log("  failed:", ex)
        time.sleep(15)
    raise SystemExit(f"Overpass fetch failed: {last}")


# ----------------------------------------------------------------------------- helpers
COS_LAT = math.cos(math.radians(CENTER_LAT))


def proj(lat, lon):
    return ((lon - CENTER_LON) * 111320.0 * COS_LAT, -(lat - CENTER_LAT) * 110540.0)


def r1(v):
    return round(float(v), 2)


def flat(coords):
    out = []
    for x, z in coords:
        out.append(r1(x))
        out.append(r1(z))
    return out


def polys_of(geom):
    if geom is None or geom.is_empty:
        return []
    if isinstance(geom, Polygon):
        return [geom]
    if isinstance(geom, MultiPolygon):
        return list(geom.geoms)
    if hasattr(geom, "geoms"):
        out = []
        for g in geom.geoms:
            out.extend(polys_of(g))
        return out
    return []


def lines_of(geom):
    if geom is None or geom.is_empty:
        return []
    if isinstance(geom, LineString):
        return [geom]
    if hasattr(geom, "geoms"):
        out = []
        for g in geom.geoms:
            out.extend(lines_of(g))
        return out
    return []


def triangulate(geom, min_area=1.0):
    verts, idx = [], []
    for p in polys_of(geom):
        if p.area < min_area:
            continue
        p = p.buffer(0)
        for q in polys_of(p):
            rings = [np.array(q.exterior.coords[:-1], dtype=np.float64)]
            rings += [np.array(r.coords[:-1], dtype=np.float64) for r in q.interiors if len(r.coords) > 3]
            rings = [r for r in rings if len(r) >= 3]
            if not rings:
                continue
            allv = np.vstack(rings)
            ends = np.cumsum([len(r) for r in rings]).astype(np.uint32)
            tri = earcut.triangulate_float64(allv, ends)
            base = len(verts) // 2
            verts.extend(flat(allv))
            idx.extend(int(t) + base for t in tri)
    return {"v": verts, "i": idx}


def width_of(tags):
    hw = tags.get("highway", "")
    w = DRIVE_WIDTH.get(hw)
    if w is None:
        return None
    try:
        if "width" in tags:
            w = float(str(tags["width"]).split()[0].replace("m", ""))
        elif "lanes" in tags:
            w = float(str(tags["lanes"]).split(";")[0]) * 3.1 + 1.0
    except ValueError:
        pass
    return max(3.5, min(24.0, w))


def left_of(fx, fz):
    return fz, -fx


def yaw_of(fx, fz):
    # Car forward is (-sin(yaw), -cos(yaw)) in x/z.
    return math.atan2(-fx, -fz)


def rect(cx, cz, w, l, yaw):
    """Footprint of a car-sized rectangle centred on (cx, cz) facing yaw."""
    fx, fz = -math.sin(yaw), -math.cos(yaw)
    lx, lz = left_of(fx, fz)
    hw, hl = w / 2.0, l / 2.0
    pts = []
    for a, b in ((hl, hw), (hl, -hw), (-hl, -hw), (-hl, hw)):
        pts.append((cx + fx * a + lx * b, cz + fz * a + lz * b))
    return Polygon(pts)


# ----------------------------------------------------------------------------- build
def build(raw):
    clip = box(-HALF, -HALF, HALF, HALF)
    roads = []          # dict(line, w, hw, oneway, nodes, major)
    lots, greens, waters, buildings_raw, trees, bus_areas = [], [], [], [], [], []
    node_use = {}
    node_xy = {}

    for el in raw.get("elements", []):
        tags = el.get("tags", {}) or {}
        if el["type"] == "node":
            if tags.get("natural") == "tree":
                trees.append(proj(el["lat"], el["lon"]))
            continue
        geo = el.get("geometry") or []
        if len(geo) < 2:
            continue
        pts = [proj(g["lat"], g["lon"]) for g in geo if g]
        hw = tags.get("highway")
        if hw and tags.get("area") != "yes":
            w = width_of(tags)
            if w is None:
                continue
            if hw == "service" and tags.get("service") in ("driveway", "emergency_access"):
                w = 3.6
            if tags.get("access") in ("private", "no") and hw != "service":
                continue
            nodes = el.get("nodes") or []
            for i, nid in enumerate(nodes):
                node_use[nid] = node_use.get(nid, 0) + 1
                if i < len(pts):
                    node_xy[nid] = pts[i]
            oneway = tags.get("oneway") in ("yes", "1", "true") or tags.get("junction") in ("roundabout", "circular")
            roads.append({"line": LineString(pts), "w": w, "hw": hw, "oneway": oneway, "nodes": nodes, "pts": pts, "major": hw in MAJOR})
            continue
        if len(pts) < 4 or pts[0] != pts[-1]:
            continue
        try:
            poly = Polygon(pts).buffer(0)
        except Exception:  # noqa: BLE001
            continue
        if poly.is_empty:
            continue
        am = tags.get("amenity")
        if "building" in tags:
            buildings_raw.append((poly, tags))
        elif am == "parking" and tags.get("parking", "surface") in ("surface", "lane", "street_side") and 250 < poly.area < 25000:
            lots.append(poly)
        elif am == "bus_station":
            bus_areas.append(poly)
        elif tags.get("leisure") or tags.get("landuse"):
            greens.append(poly)
        elif tags.get("natural") in ("water",):
            waters.append(poly)
        elif tags.get("natural") in ("wood", "scrub", "grassland"):
            greens.append(poly)

    log(f"roads={len(roads)} buildings={len(buildings_raw)} lots={len(lots)} greens={len(greens)} trees={len(trees)}")
    if len(roads) < 10:
        raise SystemExit("Too few roads in response")

    # Clip roads to box.
    for r in roads:
        r["clip"] = r["line"].intersection(clip)

    # Drivable surface: buffered roads + car parks (+ short driveways to isolated car parks).
    parts = [r["clip"].buffer(r["w"] / 2.0, cap_style=1, join_style=1, resolution=4) for r in roads if not r["clip"].is_empty]
    road_union = unary_union(parts)
    lot_polys = []
    for lot in lots:
        lot = lot.intersection(clip.buffer(-8))
        for lp in polys_of(lot):
            if lp.area < 250:
                continue
            lot_polys.append(lp)
            if lp.distance(road_union) > 0.05:
                a, b = nearest_points(lp, road_union)
                if a.distance(b) < 30:
                    parts.append(LineString([a, b]).buffer(2.8, cap_style=1))
    parts.extend(lot_polys)
    parts.extend(p for p in bus_areas if p.area < 30000)
    drivable = unary_union(parts).intersection(clip).simplify(0.12)
    drive_polys = sorted(polys_of(drivable), key=lambda p: -p.area)
    main_area = drive_polys[0]
    log(f"drivable area {drivable.area:.0f} m2 in {len(drive_polys)} parts")

    # Footpaths (verge) along every road, minus the carriageway.
    foot_parts = [r["clip"].buffer(r["w"] / 2.0 + (2.6 if r["major"] else 1.6), cap_style=1, join_style=1, resolution=3) for r in roads if not r["clip"].is_empty]
    footpath = unary_union(foot_parts).difference(drivable).intersection(clip)

    # Buildings: cut away anything overlapping the road surface.
    keep_out = drivable.buffer(0.6)
    major_union = unary_union([r["clip"].buffer(r["w"] / 2.0 + 14) for r in roads if r["major"] and not r["clip"].is_empty])
    blds = []
    for poly, tags in buildings_raw:
        poly = poly.intersection(clip)
        if poly.area < 12:
            continue
        cut = poly.difference(keep_out)
        best = max(polys_of(cut), key=lambda p: p.area, default=None)
        if best is None or best.area < 12 or best.area < poly.area * 0.55:
            continue
        best = best.simplify(0.35)
        if not isinstance(best, Polygon) or best.area < 12:
            continue
        floors = None
        try:
            if "building:levels" in tags:
                floors = int(float(str(tags["building:levels"]).split(";")[0]))
            elif "height" in tags:
                floors = int(float(str(tags["height"]).split()[0]) / 3.2)
        except ValueError:
            floors = None
        near_major = best.intersects(major_union)
        if floors is None:
            floors = rng.choice([2, 2, 3, 3, 4, 4, 5]) if near_major else rng.choice([1, 2, 2, 2, 3])
            if best.area > 1500:
                floors += 1
        floors = max(1, min(14, floors))
        btype = tags.get("building", "yes")
        kind = "generic"
        if tags.get("amenity") == "place_of_worship" or btype in ("temple", "church", "mosque", "shrine"):
            kind = {"christian": "church", "muslim": "mosque"}.get(tags.get("religion", ""), "temple")
        elif btype in ("house", "residential", "detached", "apartments", "terrace", "bungalow"):
            kind = "house" if floors <= 2 else "apartment"
        elif btype in ("hospital", "school", "college", "university", "public", "civic", "government", "office"):
            kind = "civic"
        elif near_major or btype in ("commercial", "retail", "shop", "supermarket"):
            kind = "shop"
        blds.append({"poly": best, "floors": floors, "kind": kind})
    blds.sort(key=lambda b: b["poly"].centroid.distance(Point(0, 0)))
    blds = blds[:4200]
    bld_union = unary_union([b["poly"] for b in blds]) if blds else Polygon()

    # Shop signs: on the edge closest to the road.
    for b in blds:
        if b["kind"] not in ("shop",):
            continue
        poly = b["poly"]
        if poly.distance(drivable) > 9:
            continue
        a, road_pt = nearest_points(poly.exterior, drivable)
        coords = list(poly.exterior.coords)
        best_i, best_d = 0, 1e9
        for i in range(len(coords) - 1):
            d = LineString([coords[i], coords[i + 1]]).distance(a)
            if d < best_d:
                best_i, best_d = i, d
        (x0, z0), (x1, z1) = coords[best_i], coords[best_i + 1]
        ln = math.hypot(x1 - x0, z1 - z0)
        if ln < 3.0:
            continue
        mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
        nx, nz = (z1 - z0) / ln, -(x1 - x0) / ln
        if (road_pt.x - mx) * nx + (road_pt.y - mz) * nz < 0:
            nx, nz = -nx, -nz
        b["sign"] = [r1(mx + nx * 0.25), r1(mz + nz * 0.25), round(math.atan2(nx, nz), 3), r1(min(ln - 0.8, 9.0))]

    # Greens and water.
    green = unary_union(greens).intersection(clip).difference(drivable) if greens else Polygon()
    water = unary_union(waters).intersection(clip).difference(drivable) if waters else Polygon()

    # Trees: mapped trees, park scatter and street trees on minor roads.
    def tree_ok(x, z):
        p = Point(x, z)
        return clip.contains(p) and not drivable.buffer(0.8).contains(p) and not bld_union.buffer(1.0).contains(p) and not water.contains(p)

    tree_pts = [(x, z) for x, z in trees if tree_ok(x, z)]
    for g in polys_of(green):
        n = min(int(g.area / 140), 120)
        minx, minz, maxx, maxz = g.bounds
        tries = 0
        while n > 0 and tries < n * 6:
            tries += 1
            x, z = rng.uniform(minx, maxx), rng.uniform(minz, maxz)
            if g.contains(Point(x, z)) and tree_ok(x, z):
                tree_pts.append((x, z))
                n -= 1
    for r in roads:
        if r["hw"] not in ("residential", "unclassified", "living_street") or r["clip"].is_empty:
            continue
        for line in lines_of(r["clip"]):
            d = 6.0
            side = 1
            while d < line.length - 6:
                p0 = line.interpolate(d)
                p1 = line.interpolate(min(d + 1.0, line.length))
                fx, fz = p1.x - p0.x, p1.y - p0.y
                ln = math.hypot(fx, fz) or 1.0
                lx, lz = left_of(fx / ln, fz / ln)
                off = r["w"] / 2.0 + 1.1
                x, z = p0.x + lx * off * side, p0.y + lz * off * side
                if tree_ok(x, z) and rng.random() < 0.55:
                    tree_pts.append((x, z))
                side = -side
                d += rng.uniform(14, 22)
    tree_pts = tree_pts[:1800]

    # Kerbs = boundary of the drivable surface.
    kerbs = []
    for p in drive_polys:
        for ring in [p.exterior] + list(p.interiors):
            ls = LineString(ring.coords).simplify(0.25)
            if ls.length > 2:
                kerbs.append(flat(ls.coords))

    # Junctions and centre-line markings.
    junction_pts = [Point(node_xy[n]) for n, c in node_use.items() if c >= 2 and n in node_xy]
    junction_zone = unary_union([p.buffer(10) for p in junction_pts]) if junction_pts else Polygon()
    marks = []
    for r in roads:
        if r["w"] < 8.5 or r["oneway"] or r["clip"].is_empty:
            continue
        for ln in lines_of(r["clip"].difference(junction_zone)):
            if ln.length > 8:
                marks.append(flat(ln.simplify(0.3).coords))

    # ------------------------------------------------------------------ graph
    graph = {}

    def add_edge(a, b, w, major):
        graph.setdefault(a, []).append((b, w, major))

    for r in roads:
        nodes = r["nodes"]
        for i in range(len(nodes) - 1):
            a, b = nodes[i], nodes[i + 1]
            if a not in node_xy or b not in node_xy:
                continue
            pa, pb = node_xy[a], node_xy[b]
            if not (clip.contains(Point(pa)) and clip.contains(Point(pb))):
                continue
            d = math.dist(pa, pb)
            add_edge(a, b, d, r["major"])
            add_edge(b, a, d, r["major"])

    def nearest_node(x, z, major_only=False):
        best, bd = None, 1e18
        for n in graph:
            if major_only and not any(e[2] for e in graph[n]):
                continue
            px, pz = node_xy[n]
            d = (px - x) ** 2 + (pz - z) ** 2
            if d < bd:
                best, bd = n, d
        return best

    def dijkstra(src, dst, major_only=False, penalty=None):
        dist = {src: 0.0}
        prev = {}
        pq = [(0.0, src)]
        while pq:
            d, u = heapq.heappop(pq)
            if u == dst:
                break
            if d > dist.get(u, 1e18):
                continue
            for v, w, maj in graph.get(u, []):
                if major_only and not maj:
                    continue
                cost = w * (1.0 if maj else 1.25)
                if penalty and ((u, v) in penalty or (v, u) in penalty):
                    cost *= 8.0
                nd = d + cost
                if nd < dist.get(v, 1e18):
                    dist[v] = nd
                    prev[v] = u
                    heapq.heappush(pq, (nd, v))
        if dst not in dist:
            return None
        path = [dst]
        while path[-1] != src:
            path.append(prev[path[-1]])
        return path[::-1]

    def route_pts(path):
        out = []
        for n in path:
            p = node_xy[n]
            if not out or math.dist(out[-1], p) > 0.5:
                out.append(p)
        return out

    # ------------------------------------------------------------------ levels
    levels = []
    used_spots = []

    def far_from_used(x, z, dmin=90):
        return all(math.dist((x, z), u) > dmin for u in used_spots)

    inner = drivable.buffer(-0.05)
    obstacles = bld_union.buffer(0.3)

    def route_for(sx, sz, bx, bz):
        a, b = nearest_node(sx, sz), nearest_node(bx, bz)
        if a is None or b is None:
            return []
        p = dijkstra(a, b)
        if not p:
            return []
        pts = [(sx, sz)] + route_pts(p) + [(bx, bz)]
        return flat(LineString(pts).simplify(1.0).coords)

    # Car-park levels.
    lot_levels = []
    for lp in sorted(lot_polys, key=lambda p: -p.area):
        if not main_area.buffer(1).contains(lp.representative_point()):
            continue
        mrr = lp.minimum_rotated_rectangle
        c = list(mrr.exterior.coords)
        e1 = (c[1][0] - c[0][0], c[1][1] - c[0][1])
        e2 = (c[2][0] - c[1][0], c[2][1] - c[1][1])
        u = e1 if math.hypot(*e1) >= math.hypot(*e2) else e2
        ang = math.atan2(u[1], u[0])
        cen = lp.centroid
        local = affinity.rotate(lp, -ang, origin=cen, use_radians=True)
        minx, minz, maxx, maxz = local.bounds
        inside = local.buffer(-0.25)
        rows = []
        v = minz + 0.4
        first = True
        while v + 5.2 <= maxz - 0.3:
            if first:
                rows.append((v, 1))
                v += 5.2
                first = False
                continue
            if v + 6.5 + 5.2 > maxz - 0.3:
                break
            v += 6.5
            rows.append((v, -1))
            v += 5.2
            if v + 5.2 <= maxz - 0.3:
                rows.append((v, 1))
                v += 5.2
        bays = []
        for ri, (rv, face) in enumerate(rows):
            x = minx + 0.6
            row = []
            while x + 2.6 <= maxx - 0.6:
                cxl, czl = x + 1.3, rv + 2.6
                bayl = box(x, rv, x + 2.6, rv + 5.2)
                if inside.contains(bayl):
                    wc = affinity.rotate(Point(cxl, czl), ang, origin=cen, use_radians=True)
                    row.append((wc.x, wc.y))
                x += 2.7
            bays.append(row)
        flat_bays = [(ri, i, p) for ri, row in enumerate(bays) for i, p in enumerate(row)]
        if len(flat_bays) < 8 or len(rows) < 2:
            continue
        vdir = (-math.sin(ang), math.cos(ang))  # local +z rotated
        byaw = yaw_of(vdir[0], vdir[1])
        cand = [(ri, i, p) for ri, i, p in flat_bays if 0 < i < len(bays[ri]) - 1 and not obstacles.intersects(rect(p[0], p[1], 2.6, 5.2, byaw))]
        if not cand:
            continue
        ri, ti, tp = cand[len(cand) // 2]
        if not far_from_used(*tp, dmin=40):
            continue
        parked = []
        for rj, j, p in flat_bays:
            if (rj, j) == (ri, ti):
                continue
            if (rj == ri and abs(j - ti) == 1) or rng.random() < 0.65:
                yaw = byaw if rng.random() < 0.5 else byaw + math.pi
                parked.append([r1(p[0]), r1(p[1]), round(yaw, 3)])
        # Spawn in the first aisle, at the end of the lot.
        aisle_v = rows[0][0] + 5.2 + 3.25
        sp = affinity.rotate(Point(minx + 3.0, aisle_v), ang, origin=cen, use_radians=True)
        if not inner.buffer(-1.0).contains(sp):
            continue
        syaw = yaw_of(math.cos(ang), math.sin(ang))
        lot_levels.append({
            "kind": "lot", "spawn": [r1(sp.x), r1(sp.y)], "yaw": round(syaw, 3),
            "bay": {"c": [r1(tp[0]), r1(tp[1])], "w": 2.6, "l": 5.2, "yaw": round(byaw, 3), "yaws": [round(byaw, 3), round(byaw + math.pi, 3)]},
            "parked": parked, "area": lp.area,
        })
        used_spots.append(tp)
        if len(lot_levels) >= 2:
            break

    # Kerbside parallel levels.
    par = []
    for r in roads:
        if r["hw"] not in MINOR_PARK or r["w"] < 6.0 or r["clip"].is_empty:
            continue
        for line in lines_of(r["clip"]):
            coords = list(line.coords)
            for i in range(len(coords) - 1):
                (x0, z0), (x1, z1) = coords[i], coords[i + 1]
                seg = math.hypot(x1 - x0, z1 - z0)
                if seg < 26:
                    continue
                fx, fz = (x1 - x0) / seg, (z1 - z0) / seg
                mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
                if junction_zone.contains(Point(mx, mz)):
                    continue
                lx, lz = left_of(fx, fz)
                off = r["w"] / 2.0 - 1.2
                bx, bz = mx + lx * off, mz + lz * off
                yaw = yaw_of(fx, fz)
                bay = rect(bx, bz, 2.3, 6.8, yaw)
                if not inner.contains(bay) or obstacles.intersects(bay):
                    continue
                parked = []
                for sgn in (-1, 1):
                    px, pz = bx + fx * 7.3 * sgn, bz + fz * 7.3 * sgn
                    if inner.contains(rect(px, pz, 1.8, 4.2, yaw)):
                        parked.append([r1(px), r1(pz), round(yaw, 3)])
                if not parked:
                    continue
                s = line.project(Point(mx, mz))
                if s < 34:
                    continue
                sp = line.interpolate(s - 32)
                sp2 = line.interpolate(s - 31)
                sfx, sfz = sp2.x - sp.x, sp2.y - sp.y
                sl = math.hypot(sfx, sfz) or 1.0
                slx, slz = left_of(sfx / sl, sfz / sl)
                lane = min(r["w"] / 4.0, 1.6)
                spx, spz = sp.x + slx * lane, sp.y + slz * lane
                if not main_area.contains(Point(spx, spz)) or not main_area.contains(Point(bx, bz)):
                    continue
                par.append({
                    "kind": "parallel", "w": r["w"], "spawn": [r1(spx), r1(spz)], "yaw": round(yaw_of(sfx / sl, sfz / sl), 3),
                    "bay": {"c": [r1(bx), r1(bz)], "w": 2.3, "l": 6.8, "yaw": round(yaw, 3), "yaws": [round(yaw, 3), round(yaw + math.pi, 3)]},
                    "parked": parked, "dist": math.hypot(bx, bz),
                })
    par.sort(key=lambda p: p["dist"])
    par_levels = []
    for want in ("wide", "narrow", "any"):
        for p in par:
            if p in par_levels:
                continue
            if want == "wide" and p["w"] < 7.5:
                continue
            if want == "narrow" and p["w"] > 7.0:
                continue
            if far_from_used(*p["bay"]["c"]):
                par_levels.append(p)
                used_spots.append(tuple(p["bay"]["c"]))
                break
    for p in par:
        if len(par_levels) >= 3:
            break
        if p not in par_levels and far_from_used(*p["bay"]["c"]):
            par_levels.append(p)
            used_spots.append(tuple(p["bay"]["c"]))

    tamil_lot = ["வாகன நிறுத்தம்", "பெரிய வாகன நிறுத்தம்"]
    tamil_par = ["தெரு ஓர நிறுத்தம்", "குறுகிய தெரு", "சந்து நிறுத்தம்"]
    for i, lv in enumerate(lot_levels):
        lv.update({"id": f"lot{i + 1}", "type": "park", "name": ["Market Car Park", "Bus Stand Car Park"][i % 2], "tamil": tamil_lot[i % 2],
                   "difficulty": 1 + i, "par": 50.0 + 15 * i,
                   "brief": "A real car park from the map. Find the free bay (yellow) and park inside it - nose in or reverse in.",
                   "traffic": 0.45})
        lv.pop("area", None)
        levels.append(lv)
    for i, lv in enumerate(par_levels):
        lv.update({"id": f"kerb{i + 1}", "type": "park", "name": ["Kerbside Parallel", "Narrow Street Parallel", "Back Lane Parallel"][i % 3], "tamil": tamil_par[i % 3],
                   "difficulty": 2 + i, "par": 60.0 + 10 * i,
                   "brief": "Parallel park on the left kerb between the parked cars, facing the way you are driving.",
                   "traffic": 0.5})
        lv.pop("w", None)
        lv.pop("dist", None)
        lv["bay"]["yaws"] = lv["bay"]["yaws"][:1]
        levels.append(lv)

    # Live rush hour: long cross-town drive to an existing bay.
    target = (lot_levels + par_levels)[0] if (lot_levels or par_levels) else None
    if target:
        bx, bz = target["bay"]["c"]
        best = None
        for r in roads:
            if not r["major"] or r["clip"].is_empty:
                continue
            for line in lines_of(r["clip"]):
                for k in range(0, int(line.length), 25):
                    p = line.interpolate(k)
                    d = math.dist((p.x, p.y), (bx, bz))
                    if 280 < d < 520 and main_area.buffer(-1.5).contains(p) and (best is None or abs(d - 380) < abs(best[2] - 380)):
                        q = line.interpolate(min(k + 1, line.length))
                        best = (p, q, d)
        if best:
            p, q, _ = best
            fx, fz = q.x - p.x, q.y - p.y
            ln = math.hypot(fx, fz) or 1.0
            levels.append({
                "id": "rush", "type": "park", "kind": target["kind"], "live": True, "name": "Live Rush Hour", "tamil": "நெரிசல் நேரம் (நேரலை)",
                "difficulty": 4, "par": 160.0,
                "brief": "Traffic follows the time on your phone. Drive across town, following the route, and park in the marked bay.",
                "spawn": [r1(p.x), r1(p.y)], "yaw": round(yaw_of(fx / ln, fz / ln), 3),
                "bay": target["bay"], "parked": target["parked"], "traffic": 1.0,
            })

    for lv in levels:
        lv["route"] = route_for(lv["spawn"][0], lv["spawn"][1], lv["bay"]["c"][0], lv["bay"]["c"][1])

    # Race loop on major roads.
    major_nodes = [n for n in graph if any(e[2] for e in graph[n])]
    race = None
    if len(major_nodes) > 10:
        for radius in (420, 360, 300, 240, 180):
            cands = [n for n in major_nodes if math.hypot(*node_xy[n]) < radius]
            if len(cands) < 6:
                continue
            a = min(cands, key=lambda n: (node_xy[n][0] + node_xy[n][1]))
            b = max(cands, key=lambda n: math.dist(node_xy[n], node_xy[a]))
            c = max(cands, key=lambda n: min(math.dist(node_xy[n], node_xy[a]), math.dist(node_xy[n], node_xy[b])))
            used = set()
            loop = []
            ok = True
            for s, t in ((a, b), (b, c), (c, a)):
                p = dijkstra(s, t, major_only=True, penalty=used)
                if not p:
                    ok = False
                    break
                for i in range(len(p) - 1):
                    used.add((p[i], p[i + 1]))
                loop.extend(p if not loop else p[1:])
            if not ok:
                continue
            pts = route_pts(loop)
            ls = LineString(pts + [pts[0]])
            if 900 < ls.length < 3600:
                race = ls
                break
    if race is None and major_nodes:
        log("race: falling back to any loop")
    if race is not None:
        pts = list(race.simplify(0.6).coords)
        cps = []
        d = 45.0
        while d < race.length - 20:
            p = race.interpolate(d)
            q = race.interpolate(min(d + 2, race.length))
            cps.append([r1(p.x), r1(p.y), round(yaw_of((q.x - p.x) / 2, (q.y - p.y) / 2), 3)])
            d += 55.0
        p0, p1 = race.interpolate(0), race.interpolate(3)
        levels.append({
            "id": "race", "type": "race", "name": "Kovai Grand Prix", "tamil": "கோவை கிராண்ட் ப்ரிக்ஸ்",
            "difficulty": 4, "laps": 2, "rivals": 3, "par": race.length * 2 / 9.0,
            "brief": f"Two laps of a {race.length / 1000:.1f} km loop on real main roads. Beat three rival cars and pass every gate in order.",
            "spawn": [r1(p0.x), r1(p0.y)], "yaw": round(yaw_of((p1.x - p0.x) / 3, (p1.y - p0.y) / 3), 3),
            "path": flat(pts), "checkpoints": cps, "length": r1(race.length), "traffic": 0.35,
        })
        log(f"race loop {race.length:.0f} m, {len(cps)} gates")

    # Traffic lanes along main roads (keep-left).
    lanes = []
    by_class = {}
    for r in roads:
        if not r["major"] or r["clip"].is_empty:
            continue
        key = (r["w"], r["oneway"])
        by_class.setdefault(key, []).extend(lines_of(r["clip"]))
    for (w, oneway), ls in by_class.items():
        merged = linemerge(MultiLineString(ls), directed=oneway) if len(ls) > 1 else ls[0]
        for chain in lines_of(merged):
            if chain.length < 120:
                continue
            off = 0.0 if oneway and w < 8 else w / 4.0
            dirs = [chain] if oneway else [chain, LineString(chain.coords[::-1])]
            for d in dirs:
                lane = d.offset_curve(off) if off > 0 else d
                for l2 in lines_of(lane):
                    if l2.length > 100:
                        lanes.append((l2.length, flat(l2.simplify(0.5).coords)))
    lanes.sort(key=lambda x: -x[0])
    lanes = [{"p": p} for _, p in lanes[:24]]

    # Decorative parked cars on residential kerbs (game hides any near the active bay).
    decor = []
    for r in roads:
        if r["hw"] not in ("residential", "unclassified", "living_street") or r["w"] < 6 or r["clip"].is_empty:
            continue
        for line in lines_of(r["clip"]):
            dd = rng.uniform(8, 30)
            while dd < line.length - 8 and len(decor) < 160:
                p = line.interpolate(dd)
                q = line.interpolate(min(dd + 1, line.length))
                fx, fz = q.x - p.x, q.y - p.y
                ln = math.hypot(fx, fz) or 1.0
                fx, fz = fx / ln, fz / ln
                lx, lz = left_of(fx, fz)
                off = r["w"] / 2.0 - 1.0
                cx, cz = p.x + lx * off, p.y + lz * off
                yaw = yaw_of(fx, fz)
                if inner.contains(rect(cx, cz, 1.8, 4.2, yaw)) and not junction_zone.contains(Point(cx, cz)) and not obstacles.intersects(rect(cx, cz, 1.8, 4.2, yaw)):
                    decor.append([r1(cx), r1(cz), round(yaw, 3), rng.choice(["car", "car", "car", "bike", "bike", "auto"])])
                dd += rng.uniform(25, 60)

    road_out = []
    for r in roads:
        for ln in lines_of(r["clip"]):
            if ln.length > 2:
                road_out.append({"p": flat(ln.simplify(0.8).coords), "w": r1(r["w"]), "c": "major" if r["major"] else ("service" if r["hw"] == "service" else "minor")})

    out = {
        "meta": {
            "version": DATA_VERSION,
            "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "source": "OpenStreetMap via Overpass API",
            "license": "ODbL 1.0",
            "attribution": "Map data (c) OpenStreetMap contributors",
            "half": HALF,
            "note": "Geometry only; all names and identifying tags removed.",
            "counts": {"roads": len(road_out), "buildings": len(blds), "trees": len(tree_pts), "levels": len(levels)},
        },
        "drive": triangulate(drivable),
        "foot": triangulate(footpath, 2.0),
        "grass": triangulate(green, 4.0),
        "water": triangulate(water, 4.0),
        "kerbs": kerbs,
        "marks": marks,
        "roads": road_out,
        "buildings": [dict({"p": flat(list(b["poly"].exterior.coords)[:-1]), "f": b["floors"], "k": b["kind"]}, **({"s": b["sign"]} if "sign" in b else {})) for b in blds],
        "trees": flat(tree_pts),
        "lanes": lanes,
        "decor": decor,
        "levels": levels,
    }
    log("levels:", [lv["id"] for lv in levels])
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", help="use a saved Overpass JSON instead of fetching")
    ap.add_argument("--save-raw", help="save the Overpass response here")
    ap.add_argument("--out", default="data/city.json")
    a = ap.parse_args()
    if a.raw:
        with open(a.raw, encoding="utf-8") as f:
            raw = json.load(f)
    else:
        raw = fetch()
        if a.save_raw:
            with open(a.save_raw, "w", encoding="utf-8") as f:
                json.dump(raw, f)
    out = build(raw)
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(out, f, separators=(",", ":"))
    log("wrote", a.out)


if __name__ == "__main__":
    main()
