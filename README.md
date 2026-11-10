# bapet-omarchy

Integração do [BApet (Blue Archive Desktop Pet)](https://github.com/kagdakj/BApet) com o
[Omarchy](https://omarchy.org/) / Hyprland, sem modificar o código do BApet.

```sh
git clone <este repo> && cd bapet-omarchy
./install.sh
```

Rodar `./install.sh` de novo atualiza o BApet e reaplica a integração. `./install.sh --uninstall`
remove tudo, mas mantém os pets, as settings e os modelos baixados.

## O que o instalador faz

| Passo | Destino |
| --- | --- |
| Instala pacotes que faltam (`git jq libnotify mesa xcb-util-* libxkbcommon-x11`, e `uv` se não estiver no PATH) | via `omarchy pkg add` |
| Clona o BApet sem modificações | `~/.local/share/bapet/src` |
| Cria um venv com Python 3.12 e instala `requirements.txt` | `~/.local/share/bapet/venv` |
| Comandos `BlueArchiveDesktopPet`, `bapet-ghost`, `bapet-update` | `~/.local/bin/` |
| Atalho e ícone no launcher | `~/.local/share/applications/`, `~/.local/share/icons/` |
| Regras de janela e atalho de teclado | `~/.config/hypr/bapet.lua` + `require("hypr.bapet")` no `hyprland.lua` |
| Plugin da barra (gaveta da bandeja) e esconde o ícone cru do app | `~/.config/omarchy/plugins/bapet.desktop-pets/`, `shell.json` |

Antes de editar `hyprland.lua` ou `shell.json`, o instalador cria um `.bak.<timestamp>`.

Variáveis opcionais: `BAPET_REF=v1.0.0` fixa uma versão do BApet, `BAPET_REPO` aponta para um fork e
`BAPET_HOME` muda a pasta de instalação.

## Uso

- **Abrir:** pelo launcher, pelo ícone de pata na bandeja da barra (clique esquerdo) ou com
  `BlueArchiveDesktopPet --add "Hina"`.
- **Menu:** clique direito na pata da barra. Mostra o menu do próprio app (adicionar, pausar, esconder,
  settings, sair) e a opção **Arrastar pets**.
- **`SUPER + ALT + P`:** alterna entre dois modos:
  - **atravessável** (padrão): cliques passam pelo pet;
  - **interativo**: dá para arrastar, clicar e abrir o menu do pet.
- **Tamanho:** clique direito no pet, em **Size**, no modo interativo; ou **Settings → Pet size**, para todos.
- **Atualizar só o BApet:** `bapet-update`, depois reinicie o app.

## Por que cada peça existe

- **Binário oficial não é usado:** a OpenBLAS embutida no build PyInstaller é recusada pelo glibc do Arch
  (`ELF load command address/offset not page-aligned`). Rodar do código-fonte evita isso.
- **`QT_QPA_PLATFORM=xcb` no wrapper:** o app precisa do XWayland para posicionar as próprias janelas. Ele
  troca sozinho, mas só quando a variável não existe, e o Omarchy exporta `wayland;xcb`.
- **Modo atravessável:** o app recorta a área clicável com X11 SHAPE, mas o Hyprland não respeita esse
  recorte. A janela inteira do pet pegaria cliques, inclusive a área transparente em volta. Por isso os pets
  ficam com `no_focus` por padrão, e a tag `bapet-touch` (posta pelo `bapet-ghost`) libera o mouse.
- **Plugin lê a bandeja do app:** o widget usa o StatusNotifierItem que o BApet já publica. Itens novos no
  menu do app aparecem sozinhos.

## Limitações

- Um pet adicionado com o modo interativo ligado chega atravessável. Aperte `SUPER+ALT+P` duas vezes.
- Os pets sempre ficam por cima das janelas em tiling, porque no Hyprland janelas flutuantes ficam acima.
  "Keep pets above other windows" não muda isso.
- Se `SUPER+ALT+P` já estiver em uso, edite `hypr/bapet.lua`.
