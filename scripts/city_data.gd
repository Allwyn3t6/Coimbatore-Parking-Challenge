extends Node
## Autoload "CityData".
## Loads the bundled OpenStreetMap-derived city (res://data/city.json), prefers
## a newer copy previously downloaded from GitHub (user://city.json) and checks
## GitHub in the background for updates. Updates apply on the next launch so a
## level is never rebuilt while being played.

signal update_downloaded(generated: String)

const REMOTE_URL := "https://raw.githubusercontent.com/Allwyn3t6/Coimbatore-Parking-Challenge/main/data/city.json"
const BUNDLED := "res://data/city.json"
const CACHED := "user://city.json"
const MIN_VERSION := 2

var data: Dictionary = {}
var source := "bundled"
var _http: HTTPRequest

func _ready() -> void:
    var bundled := _read(BUNDLED)
    var cached := _read(CACHED)
    if _valid(cached) and (not _valid(bundled) or str(cached.meta.generated) > str(bundled.meta.generated)):
        data = cached
        source = "downloaded"
    else:
        data = bundled
    call_deferred("_check_remote")

func _read(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return {}
    var parsed = JSON.parse_string(f.get_as_text())
    return parsed if parsed is Dictionary else {}

func _valid(d: Dictionary) -> bool:
    return d.has("meta") and d.has("levels") and d.has("drive") and int(d.meta.get("version", 0)) >= MIN_VERSION

func generated() -> String:
    return str(data.get("meta", {}).get("generated", "?"))

func levels() -> Array:
    return data.get("levels", [])

func _check_remote() -> void:
    _http = HTTPRequest.new()
    _http.timeout = 25.0
    _http.use_threads = true
    add_child(_http)
    _http.request_completed.connect(_on_remote)
    var err := _http.request(REMOTE_URL)
    if err != OK:
        _http.queue_free()

func _on_remote(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    _http.queue_free()
    if result != HTTPRequest.RESULT_SUCCESS or code != 200:
        return
    var text := body.get_string_from_utf8()
    var parsed = JSON.parse_string(text)
    if not (parsed is Dictionary) or not _valid(parsed):
        return
    if str(parsed.meta.generated) <= generated():
        return
    var f := FileAccess.open(CACHED, FileAccess.WRITE)
    if f:
        f.store_string(text)
        f.close()
        update_downloaded.emit(str(parsed.meta.generated))
