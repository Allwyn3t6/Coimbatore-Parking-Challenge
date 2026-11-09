extends RefCounted
class_name VehicleCatalog
## Ten generic vehicle classes matching the size range of India's best-selling
## passenger cars (compact sedans, micro/compact SUVs, MPVs, hatchbacks).
## Meshes and names are original and de-identified - no real models or logos.
## turn = maximum front-wheel angle (degrees). speed = top speed in m/s.

const CARS := [
    {"name": "Kovai Compact Sedan", "class": "Compact sedan", "shape": "sedan", "length": 3.99, "width": 1.74, "turn": 36.0, "speed": 11.0, "accel": 3.4, "color": Color("#e1e6ea")},
    {"name": "Noyyal Compact SUV", "class": "Compact SUV", "shape": "suv", "length": 3.99, "width": 1.80, "turn": 35.0, "speed": 10.6, "accel": 3.3, "color": Color("#e39b24")},
    {"name": "Siruvani Micro SUV", "class": "Micro SUV", "shape": "micro", "length": 3.83, "width": 1.74, "turn": 37.0, "speed": 10.0, "accel": 3.1, "color": Color("#2f9c95")},
    {"name": "Kongu Family MPV", "class": "7-seat MPV", "shape": "mpv", "length": 4.40, "width": 1.74, "turn": 33.0, "speed": 9.8, "accel": 2.9, "color": Color("#4b6a99")},
    {"name": "Perur Tall Hatch", "class": "Tall hatchback", "shape": "micro", "length": 3.66, "width": 1.62, "turn": 39.0, "speed": 9.8, "accel": 3.0, "color": Color("#d4be3f")},
    {"name": "Podanur Sport Hatch", "class": "Hatchback", "shape": "hatch", "length": 3.86, "width": 1.73, "turn": 38.0, "speed": 11.6, "accel": 3.8, "color": Color("#c4373a")},
    {"name": "Ukkadam Premium Hatch", "class": "Premium hatchback", "shape": "hatch", "length": 3.99, "width": 1.75, "turn": 37.0, "speed": 11.2, "accel": 3.6, "color": Color("#2f63a8")},
    {"name": "Saravanampatti Crossover", "class": "Crossover", "shape": "suv", "length": 3.99, "width": 1.77, "turn": 36.0, "speed": 11.0, "accel": 3.5, "color": Color("#7d5ba6")},
    {"name": "Velliangiri Mid SUV", "class": "Mid-size SUV", "shape": "suv", "length": 4.33, "width": 1.79, "turn": 34.0, "speed": 10.8, "accel": 3.4, "color": Color("#2c343c")},
    {"name": "Anaikatti Big SUV", "class": "Large SUV", "shape": "suv", "length": 4.66, "width": 1.92, "turn": 31.0, "speed": 10.4, "accel": 3.2, "color": Color("#6f8590")},
]

const PAINTS := [Color("#e1e6ea"), Color("#c4373a"), Color("#2f63a8"), Color("#2c343c"), Color("#e39b24"), Color("#2f9c95"), Color("#7d5ba6"), Color("#9aa4ab")]

static func get_car(index: int) -> Dictionary:
    return CARS[clampi(index, 0, CARS.size() - 1)]
