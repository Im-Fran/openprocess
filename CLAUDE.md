# OpenProcess

Reemplazo nativo del Monitor de Actividad para macOS (SwiftUI + AppKit, Swift 6). Ver `README.md` para compilar, probar y publicar.

## graphify

Cada uno genera localmente un grafo de conocimiento con [graphify](https://github.com/safishamsi/graphify) en `graphify-out/` (no se versiona, está en `.gitignore`; si no existe, créalo con `/graphify .`). Combina los símbolos del código (AST), los conceptos y decisiones de diseño de la documentación y los assets de marca, agrupados en comunidades.

- `graphify-out/GRAPH_REPORT.md` — nodos más conectados, comunidades, conexiones sorprendentes y aristas ambiguas.
- `graphify-out/graph.json` — el grafo completo.
- `graphify-out/graph.html` — visualización interactiva.

Cómo usarlo:

- Antes de responder preguntas de arquitectura o de relaciones entre archivos, lee `graphify-out/GRAPH_REPORT.md` y consulta el grafo con `/graphify query "<pregunta>"`, `/graphify path "A" "B"` o `/graphify explain "Nodo"`, en vez de recorrer todo el código.
- Cada arista lleva `EXTRACTED`, `INFERRED` o `AMBIGUOUS`. Verifica en el código las `INFERRED` y `AMBIGUOUS` antes de darlas por ciertas.
- Después de cambiar código o documentación, ejecuta `/graphify . --update` para mantener el grafo al día. Nunca lo agregues al commit.
