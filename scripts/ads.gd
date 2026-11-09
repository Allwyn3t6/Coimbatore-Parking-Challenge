extends Node
## Autoload "Ads" - placeholder for small, non-intrusive ads.
##
## Policy built into the game: ads may appear ONLY on menu and results screens
## as a small banner (the HUD calls show_banner/hide_banner at those moments).
## Nothing is ever shown while driving, and there are no forced full-screen ads.
##
## To monetise later: install an AdMob plugin for Godot 4 (e.g. the
## "godot-admob" Android plugin), enable it in the Android export preset, and
## implement the three functions below using the plugin's banner API.
## Until then every call is a safe no-op.

const ENABLED := false
const BANNER_HEIGHT := 56.0   # space the UI keeps free at the bottom of menus

var banner_visible := false

func show_banner(_placement: String) -> void:
    if not ENABLED:
        return
    banner_visible = true

func hide_banner() -> void:
    if not ENABLED:
        return
    banner_visible = false

func reserved_height() -> float:
    return BANNER_HEIGHT if ENABLED else 0.0
