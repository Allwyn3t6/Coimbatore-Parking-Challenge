extends RefCounted
class_name VehicleCatalog

# India model popularity reference: V3Cars, Oct 2025–Sep 2026.
# Original generic game meshes only. No manufacturer logos or third-party 3D assets.
const CARS := [
    {"name":"Maruti Suzuki Dzire", "class":"Compact sedan", "length":4.0, "width":1.72, "turn":2.35, "speed":8.2, "color":Color("#d7e0e7"), "rank":1},
    {"name":"Tata Nexon", "class":"Compact SUV", "length":4.05, "width":1.8, "turn":2.15, "speed":7.8, "color":Color("#e7a52e"), "rank":2},
    {"name":"Tata Punch", "class":"Micro SUV", "length":3.85, "width":1.78, "turn":2.2, "speed":7.5, "color":Color("#38a6a1"), "rank":3},
    {"name":"Maruti Suzuki Ertiga", "class":"MPV", "length":4.35, "width":1.8, "turn":1.9, "speed":7.0, "color":Color("#526f9c"), "rank":4},
    {"name":"Maruti Suzuki Wagon R", "class":"Tall hatchback", "length":3.75, "width":1.65, "turn":2.45, "speed":7.2, "color":Color("#d8c34b"), "rank":5},
    {"name":"Maruti Suzuki Swift", "class":"Hatchback", "length":3.85, "width":1.72, "turn":2.5, "speed":8.6, "color":Color("#c94b43"), "rank":6},
    {"name":"Maruti Suzuki Baleno", "class":"Premium hatchback", "length":3.95, "width":1.74, "turn":2.4, "speed":8.4, "color":Color("#5686bd"), "rank":7},
    {"name":"Maruti Suzuki Fronx", "class":"Crossover", "length":4.05, "width":1.76, "turn":2.25, "speed":8.1, "color":Color("#8c6bb1"), "rank":8},
    {"name":"Hyundai Creta", "class":"Mid-size SUV", "length":4.35, "width":1.82, "turn":2.0, "speed":7.8, "color":Color("#303943"), "rank":9},
    {"name":"Mahindra Scorpio-N", "class":"SUV", "length":4.55, "width":1.9, "turn":1.7, "speed":7.4, "color":Color("#78909c"), "rank":10}
]

static func get_car(index: int) -> Dictionary:
    return CARS[clampi(index, 0, CARS.size() - 1)]
