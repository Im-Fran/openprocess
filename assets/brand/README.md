# Handoff: Branding OpenProcess

## Overview
Sistema de marca para **OpenProcess** (app nativa macOS 26+, SwiftUI/AppKit, Liquid Glass, Bundle ID `cl.franciscosolis.openprocess`). Incluye ícono de app en capas, glifo de barra de menús, paleta, wordmark/lockup, fondo del DMG, hero para README y imagen Open Graph.

## About the Design Files
`OpenProcess Branding.dc.html` es una **referencia de diseño en HTML** (abrir en navegador junto a `support.js`). No es código para embarcar. La tarea es **recrear estos activos en el proyecto Xcode**: Icon Composer (`.icon`), `Assets.xcassets`, `NSStatusItem`, script de `create-dmg`, y los PNG de `docs/`/README. Los PNG/SVG de `assets/` sí son entregables finales.

## Fidelity
**Hi-fi.** Colores, geometría y tipografía son finales. Ícono elegido: opción **1c** (oscuro con rejilla técnica).

## Ícono de app (Icon Composer)
Rejilla 1024×1024; squircle de 824×824 en (100,100), radio 186 (continuo).
- **Capa 1 · Fondo**: degradado vertical `#1A1F33 → #05080F`; rejilla de 8×8 celdas (103 pt) trazo 3 pt blanco al 6 %; borde interior 4 pt blanco al 8 %.
- **Capa 2 · Figura**: 5 barras redondeadas, ancho 84, radio 42, base en y=676, gap 46, x = 210/340/470/600/730, alturas 270/450/180/390/300. Color por barra izq→der: `#33D98C · #2FC7B0 · #2AB0D0 · #279CEA · #268CFF`. Glow (blur 40, color de la barra, ~55 %) solo ≥64 px.
- **Variantes**: `dark` (default), `light` (vidrio claro `#E9F1FF→#C9D9F2`, rejilla oscura 7 %, rim highlight 5 pt), `glassdark` (vidrio oscuro), `tinted` (fondo `#3A3F4B`, barras blancas 92 %; en Icon Composer dejar la figura en blanco y que el sistema tinte el fondo).
- Fuentes vectoriales en `assets/icon/svg/`; PNG 16–1024 en `assets/icon/<variante>/`; capas en `assets/icon/layers/`.
- A 16–32 px sin glow y sin rejilla (ya aplicado en los PNG).

## Glifo de barra de menús
Template image 18×18 pt (`assets/menubar/MenuBarTemplate.svg|.png|-2x.png`): 5 barras ancho 2.4, gap 1, radio 1.2, x = 1/4.4/7.8/11.2/14.6. `isTemplate = true`.
**Comportamiento vivo**: cada barra representa la carga de un cluster/núcleo (o 5 buckets de núcleos), altura = `2 + carga × 12` pt (mín. 2 pt, nunca desaparece), actualizada cada ~1 s con animación implícita suave (≈0.3 s easeOut). A la derecha, `% CPU` con `monospacedDigit`. Fondo del item: cápsula 5 pt de radio, negro 6 % (claro) / blanco 10 % (oscuro) — opcional.

## Paleta
| Rol | Modo oscuro | Modo claro | Uso |
|---|---|---|---|
| Primario · Menta | `#33D98C` | `#1FA86A` | marca, actividad, positivo |
| Secundario · Azul | `#268CFF` | `#1E7BE6` | CPU, enlaces, selección |
| Acento · Verde azulado | `#2FC7B0` | `#1FA898` | gráficos, hover |
| Marino | `#1A1F33 → #05080F` | — | fondo ícono/hero oscuro |
| Fondo claro / tinta | — | `#F4F6F9` / `#0D1120` | |

Degradado de marca: 5 pasos fijos `#33D98C #2FC7B0 #2AB0D0 #279CEA #268CFF`. Reservados y **no** de marca: amarillo/rojo (presión de memoria), cian (GPU).

## Wordmark y lockup
Tipografía **Manrope** (Google Fonts, SIL OFL). `Open` peso 300 + `Process` peso 700, sin espacio, tracking −0.02em (−0.01em bajo 20 px), line-height 1.
- Horizontal: ícono a la izquierda, gap = 0.25× altura del texto; ícono con su margen recortado (−10 % del tamaño) para que alinee ópticamente.
- Vertical: ícono arriba, wordmark centrado debajo, gap 8 pt a 34 px.
- Tamaños de referencia: 56/30/16 px (claro) y 34 px sobre marino (blanco).
- Familia: `OpenBattery` / `OpenProcess` con el mismo patrón bitono.

## Fondo del DMG (800×500 pt, `assets/dmg/`)
- Fondo `#F4F6F9`, rejilla 40 pt trazo 1 px `#0D1120` al 5.5 %, viñeta radial blanca 90 % centrada en (400,225) r 320.
- Wordmark 22 px centrado en y≈62; subtítulo "Arrastra el ícono a la carpeta Aplicaciones para instalar" 11.5 px `#0D1120` 50 % en y≈86.
- Guía: línea 2 pt de x=300 a 500 en y=230, degradado `#33D98C → #268CFF`, punta triangular 12×16 `#268CFF` en x=494–506.
- Ícono de la app centrado en **(200,230)**, alias Aplicaciones en **(600,230)**, ambos a 128 pt. Pie monoespaciado 10 px 35 % en y≈482.
- `create-dmg --window-size 800 500 --icon-size 128 --icon OpenProcess.app 200 230 --app-drop-link 600 230 --background dmg-background@2x.png`. Renombrar `-2x` → `@2x`.

## Hero README (1280×640) y Open Graph (1200×630)
Ver secciones 1l/1m/1n del HTML. Fondo marino (o `#FBFCFE→#EEF2F8` claro) + rejilla 48 px al 4.5 % + dos halos radiales (menta abajo-izq, azul arriba-der). Columna izquierda (x=80, y=80, w=480): ícono 160, wordmark 58 px, tagline 22 px al 72 %, badges cápsula 11.5 px 600 ("macOS 26+", "Apple Silicon", "Código abierto" en menta). Ventana a la derecha (x=600, y=96, 900×600, radio 14, borde 1 px blanco 12 %, sombra 0 40 80 negro 50 %) con la captura real (`assets/screenshots/`). Tagline oficial: **«Todo lo que hace tu Mac, en tiempo real.»**

## Interactions & Behavior
Solo el glifo de menú es dinámico (ver arriba). Todo lo demás es estático.

## Assets
- `assets/icon/` PNG por variante y tamaño, capas y SVG.
- `assets/menubar/` template del status item.
- `assets/dmg/` fondo 1x/2x.
- `assets/screenshots/` capturas de la app (aportadas por el autor).
- `assets/app-*.png` copias usadas por el HTML.

## Files
- `OpenProcess Branding.dc.html` + `support.js` — referencia visual completa (abrir en navegador).
