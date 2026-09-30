# OpenProcess

Reemplazo nativo del Monitor de Actividad para macOS (SwiftUI + AppKit, Swift 6). Ver `README.md` para compilar, probar y publicar.

## graphify

El repositorio incluye un grafo de conocimiento generado con [graphify](https://github.com/safishamsi/graphify) en `graphify-out/`. Combina los símbolos del código (AST), los conceptos y decisiones de diseño de la documentación y los assets de marca, agrupados en comunidades.

- `graphify-out/GRAPH_REPORT.md` — nodos más conectados, comunidades, conexiones sorprendentes y aristas ambiguas.
- `graphify-out/graph.json` — el grafo completo.
- `graphify-out/graph.html` — visualización interactiva.

Cómo usarlo:

- Antes de responder preguntas de arquitectura o de relaciones entre archivos, lee `graphify-out/GRAPH_REPORT.md` y consulta el grafo con `/graphify query "<pregunta>"`, `/graphify path "A" "B"` o `/graphify explain "Nodo"`, en vez de recorrer todo el código.
- Cada arista lleva `EXTRACTED`, `INFERRED` o `AMBIGUOUS`. Verifica en el código las `INFERRED` y `AMBIGUOUS` antes de darlas por ciertas.
- Después de cambiar código o documentación, ejecuta `/graphify . --update` e incluye `graph.json`, `graph.html` y `GRAPH_REPORT.md` en el commit.
- No versiones `graphify-out/cache/`, `cost.json`, `manifest.json` ni los `.graphify_*`: son estado local y están en `.gitignore`.
