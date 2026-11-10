-- BApet (Blue Archive Desktop Pet) — https://github.com/kagdakj/BApet
-- Os pets são janelas XWayland sem moldura que o app move sozinho. Aqui elas
-- viram overlays: flutuam, aparecem em todos os workspaces, sem decoração,
-- sem animação do Hyprland e sem roubar foco ao abrir. Diálogos do app
-- (Add Pet, Settings) não casam com o título e continuam janelas normais.
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

-- Modo fantasma: o Hyprland não respeita o recorte de clique (X11 SHAPE) que
-- o app aplica, então a janela inteira do pet pega cliques, inclusive a parte
-- transparente. Por padrão os pets deixam todos os cliques passarem; com a tag
-- "bapet-touch" dá para arrastar e clicar neles. `bapet-ghost` (SUPER+ALT+P ou
-- menu da barra) alterna o modo.
o.window(pet, { no_focus = true })
o.window({ class = "^BlueArchiveDesktopPet$", tag = "bapet-touch" }, { no_focus = false })

o.bind("SUPER + ALT + P", "Desktop pets: arrastar/atravessar", "bapet-ghost toggle")
