-- BApet (Blue Archive Desktop Pet): https://github.com/kagdakj/BApet
-- Pets are frameless XWayland windows that the app moves around itself. These
-- rules make them overlays: floating, pinned to every workspace, no borders,
-- shadows, blur or Hyprland animations, and no focus stealing when they appear.
-- The app's dialogs (Add Pet, Settings) have other titles, so they stay normal windows.
local pet = { class = "^BlueArchiveDesktopPet$", title = "^Desktop Pet( — .*)?$", xwayland = true }

o.window(pet, {
  float = true,
  pin = true,
  border_size = 0,
  rounding = 0,
  no_shadow = true,
  no_blur = true,
  no_anim = true,
  no_dim = true,
  no_initial_focus = true,
})

-- Ghost mode. The app limits its clickable area with X11 SHAPE, but Hyprland
-- ignores that, so the whole pet window would catch clicks, transparent parts
-- included. By default every click goes through the pets. The "bapet-touch" tag
-- lets you drag and click them. `bapet-ghost` (SUPER+ALT+P or the bar menu)
-- switches between the two.
o.window(pet, { no_focus = true })
o.window({ class = "^BlueArchiveDesktopPet$", tag = "bapet-touch" }, { no_focus = false })

o.bind("SUPER + ALT + P", "Desktop pets: drag or click through", "bapet-ghost toggle")
