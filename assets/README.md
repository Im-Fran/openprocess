# assets/

Branding de OpenProcess. **Fuente de verdad:** todo lo que está en `brand/` viene tal cual de `Branding OpenProcess.zip` (handoff generado con Claude Design, 27-09-2026). La única modificación es que `brand/assets/app-*.png`, que eran duplicados de `brand/assets/screenshots/`, ahora son symlinks a esas capturas.

La especificación completa (geometría del ícono, paleta, tipografía, glifo de la barra de menús, DMG, hero y Open Graph) está en [`brand/README.md`](brand/README.md). La referencia visual es `brand/OpenProcess Branding.dc.html`, que se abre en el navegador junto a `support.js`.

```
brand/
├─ README.md                       especificación del handoff
├─ OpenProcess Branding.dc.html    referencia visual (+ support.js)
└─ assets/
   ├─ icon/svg/        ícono completo y figura (color / mono), lienzo 1024 con squircle 824 en (100,100)
   ├─ icon/layers/     capas PNG (fondo claro/oscuro/tintado, figura color/mono)
   ├─ icon/<variante>/ PNG 16–1024: dark (el elegido, "1c"), light, glassdark, tinted
   ├─ menubar/         MenuBarTemplate.svg / .png / -2x.png (18×18 pt, template)
   ├─ dmg/             fondo del DMG 800×500 (1x y 2x)
   └─ screenshots/     capturas reales de la app
```

## Dónde se usa cada archivo

| Uso | Archivo del proyecto | Cómo | Origen |
|---|---|---|---|
| Ícono de la app (Icon Composer, Liquid Glass) | `OpenProcess/Resources/AppIcon.icon/Assets/02-figura.svg` | **copia transformada** | `brand/assets/icon/svg/OpenProcess-figura.svg` |
| Rejilla técnica del ícono | `OpenProcess/Resources/AppIcon.icon/Assets/01-rejilla.svg` | generada | `brand/README.md` → "Capa 1 · Fondo" (8×8 celdas, blanco 6 %) |
| Degradado de fondo del ícono | `OpenProcess/Resources/AppIcon.icon/icon.json` → `fill` | valores | `#1A1F33 → #05080F` |
| Glifo de la barra de menús | `OpenProcess/Views/MenuBarView.swift` → `MenuBarGlyph` | **redibujado en código** | geometría de `brand/assets/menubar/MenuBarTemplate.svg` |
| Color de acento | `OpenProcess/Resources/Assets.xcassets/AccentColor.colorset` | valores | Secundario · Azul: claro `#1E7BE6`, oscuro `#268CFF` |
| Fondo del DMG (1x) | `packaging/dmg-background.png` | **symlink** | `brand/assets/dmg/dmg-background.png` |
| Fondo del DMG (Retina) | `packaging/dmg-background@2x.png` | **symlink** (renombra `-2x` → `@2x`) | `brand/assets/dmg/dmg-background-2x.png` |
| Posiciones de íconos en el DMG | `packaging/dmg-settings.py` → `icon_locations` | valores | app en (200,230), Aplicaciones en (600,230), 128 pt |

### Por qué algunas cosas son copias y otras symlinks

- **Capas del ícono → copias.** El exportador de Icon Composer que usa `actool` falla con symlinks dentro de un `.icon` (`Icon export exited with status 255`). Esto se vio en openvault.
- **Además, las capas están transformadas.** El handoff dibuja sobre el lienzo clásico de macOS (squircle de 824 px en (100,100) dentro de 1024). En Icon Composer, en cambio, el lienzo completo de 1024 **es** el squircle y el sistema aplica la máscara y el margen. Por eso la figura va envuelta en `scale(1024/824) translate(-100 -100)`. El borde interior del 8 % del diseño no se copia: Liquid Glass pone su propio borde especular.
- **Fondo del DMG → symlinks.** `dmgbuild` los sigue sin problema. El symlink `@2x` además hace el renombrado que pide el handoff sin duplicar el archivo. `dmgbuild` combina 1x + 2x en un `.background.tiff` (el DMG pesa unos 3 MB en vez de 1,2 MB).
- **Glifo de la barra de menús → código.** La especificación pide que sea "vivo": cada barra es la carga media de un grupo de núcleos, con altura `2 + carga × 12` pt. Por eso se dibuja un `NSImage` template en cada tick con la misma geometría del SVG, en vez de cargar el PNG. La animación de 0,3 s que sugiere el diseño no está implementada, porque la etiqueta de un `MenuBarExtra` es una imagen estática.

## Qué no se usa (todavía)

- **Variantes PNG `light`, `glassdark` y `tinted`.** En macOS 26+ las variantes oscura y tintada del ícono las genera el sistema a partir de las capas del `.icon`. Los PNG quedan como referencia y para usos fuera de la app (web, prensa).
- **`brand/assets/icon/layers/*.png` y `menubar/*.png`.** Son equivalentes rasterizados de lo anterior.
- **Hero del README (1280×640) y Open Graph (1200×630).** El handoff los describe (secciones 1l/1m/1n del HTML) pero no los entrega como PNG. Hay que exportarlos desde el HTML cuando exista el README del proyecto y subir el Open Graph en GitHub → *Settings → Social preview*.
- **Tipografía Manrope** (wordmark: `Open` 300 + `Process` 700). Solo aparece horneada en el fondo del DMG; la app usa la fuente del sistema.

## Actualizar el branding

1. Descomprime el nuevo handoff y reemplaza `brand/` completo (mismos nombres). Si vuelve a traer duplicados `brand/assets/app-*.png`, puedes dejarlos o volver a convertirlos en symlinks.
2. Si cambió la figura del ícono, regenera la capa:
   ```sh
   python3 - <<'EOF'
   import re
   svg = open("assets/brand/assets/icon/svg/OpenProcess-figura.svg").read()
   svg = re.sub(r"<metadata>.*?</metadata>", "", svg, flags=re.S)
   rects = "".join(re.findall(r"<rect[^>]*>(?:</rect>)?", svg))
   open("OpenProcess/Resources/AppIcon.icon/Assets/02-figura.svg", "w").write(
       '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">'
       f'<g transform="scale({1024/824:.6f}) translate(-100 -100)">{rects}</g></svg>\n')
   EOF
   ```
3. Si cambiaron colores, actualiza `AppIcon.icon/icon.json` (`fill`) y `AccentColor.colorset`.
4. Si cambió la geometría del glifo, ajusta `MenuBarGlyph` en `OpenProcess/Views/MenuBarView.swift` (posiciones `xs`, ancho 2.4, radio 1.2, base en y=17).
5. Si cambió el DMG, no hay que tocar nada más que `dmg-settings.py` cuando se muevan las posiciones de los íconos.
6. Verifica con `bundle exec fastlane build && bundle exec fastlane dmg`. Revisa el ícono en el Dock (claro, oscuro y tintado) y monta el DMG.

Para retocar el ícono a mano, abre `OpenProcess/Resources/AppIcon.icon` en Icon Composer (`/Applications/Xcode.app/Contents/Applications/Icon Composer.app`).
