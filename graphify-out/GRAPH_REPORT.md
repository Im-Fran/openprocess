# Graph Report - openprocess  (2026-09-30)

## Corpus Check
- 88 files · ~179,007 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 9 file(s) not represented in the graph (top: (none) 6, .entitlements 1, .plist 1)

## Summary
- 659 nodes · 1635 edges · 18 communities (13 shown, 5 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 201 edges (avg confidence: 0.86)
- Token cost: 408,048 input · 2,103 output

## Community Hubs (Navigation)
- Snapshots y vistas SwiftUI
- Runtime dc de branding (support.js)
- Comandos y estado de UI
- Marca, build y release
- Helper privilegiado XPC
- Tabla de procesos AppKit
- Variantes del icono de la app
- Arranque de la app y ventanas
- Energía y sensores IOKit
- Memoria y sysctl
- Muestreo de procesos BSD
- Disco y GPU vía IOKit
- Bucle de muestreo y CPU
- Red vía nettop
- Historial de series temporales
- Estadísticas crudas de proceso
- Detalles y argumentos de proceso

## God Nodes (most connected - your core abstractions)
1. `SystemMonitor` - 46 edges
2. `ProcessRow` - 33 edges
3. `UIState` - 30 edges
4. `AppSection` - 23 edges
5. `get()` - 23 edges
6. `ProcessTable` - 22 edges
7. `Coordinator` - 22 edges
8. `createRuntime()` - 22 edges
9. `ProcessColumn` - 19 edges
10. `HelperClient` - 18 edges

## Surprising Connections (you probably didn't know these)
- `Optional privileged helper (SMAppService launch daemon + XPC)` --references--> `SettingsView`  [INFERRED]
  README.md → OpenProcess/App/SettingsView.swift
- `Optional privileged helper (SMAppService launch daemon + XPC)` --rationale_for--> `HelperClient`  [INFERRED]
  README.md → OpenProcess/Helper/HelperClient.swift
- `Per-process network via nettop once per cycle` --rationale_for--> `NetworkSampler`  [INFERRED]
  README.md → OpenProcess/Sampling/NetworkSampler.swift
- `CPU energy estimated from per-process energy` --rationale_for--> `PowerSampler`  [INFERRED]
  README.md → OpenProcess/Sampling/PowerSampler.swift
- `Repository structure (App, Model, Sampling, Helper, Shared, Views, Resources)` --references--> `SystemMonitor`  [EXTRACTED]
  README.md → OpenProcess/Model/SystemMonitor.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Brand Identity Assets** — assets_brand_assets_icon_svg_openprocess_figura, assets_brand_assets_icon_svg_openprocess_figura_mono, assets_brand_assets_icon_svg_openprocess_icon_dark, assets_brand_assets_menubar_menubartemplate [EXTRACTED 1.00]
- **macOS Packaging Assets** — packaging_dmg_background, packaging_dmg_background_2x, openprocess_app [EXTRACTED 0.90]
- **Privileged Helper XPC Flow** — openprocess_helper_helperclient_helperclient, openprocess_shared_helperprotocol_openprocesshelperprotocol, openprocesshelper_main_helper, openprocess_shared_rawprocstats_rawprocstats, openprocess_model_systemmonitor_systemmonitor_send, helperclient_mutual_code_signing_requirement [EXTRACTED 1.00]
- **System Sampling Pipeline (Sampler -> Snapshot -> History)** — openprocess_model_systemmonitor_sampler, openprocess_model_systemmonitor_sampler_sample, openprocess_model_snapshots_systemsnapshot, openprocess_model_systemmonitor_systemmonitor_apply, openprocess_model_systemmonitor_metrics, openprocess_model_history_history, openprocess_model_systemmonitor_systemmonitor_start [EXTRACTED 1.00]
- **Signal Delivery Flow (menu -> confirm -> kill/helper)** — openprocess_app_appcommands_signalmenu, openprocess_model_uistate_uistate_request, openprocess_model_uistate_signalrequest, openprocess_app_openprocessapp_contentview_body, openprocess_model_uistate_uistate_signal, openprocess_model_systemmonitor_systemmonitor_send, openprocess_helper_helperclient_helperclient_sendsignal, openprocesshelper_main_helper_sendsignal [EXTRACTED 1.00]
- **Samplers populating SystemSnapshot each tick** — openprocess_sampling_cpusampler_cpusampler, openprocess_sampling_memorysampler_memorysampler, openprocess_sampling_iokitsamplers_gpusampler, openprocess_sampling_iokitsamplers_disksampler, openprocess_sampling_networksampler_networksampler, openprocess_sampling_networksampler_nettop, openprocess_sampling_powersampler_powersampler, openprocess_sampling_processsampler_processsampler, openprocess_model_systemmonitor_sampler, openprocess_model_snapshots_systemsnapshot [EXTRACTED 1.00]
- **Section views composed from SectionPage/Card/Stat/HistoryChart/TopProcesses** — openprocess_views_sectionviews_cpuview, openprocess_views_sectionviews_memoryview, openprocess_views_sectionviews_gpuview, openprocess_views_sectionviews_energyview, openprocess_views_sectionviews_diskview, openprocess_views_sectionviews_networkview, openprocess_views_components_sectionpage, openprocess_views_components_card, openprocess_views_components_stat, openprocess_views_components_historychart, openprocess_views_components_topprocesses [EXTRACTED 1.00]
- **Low-level macOS data sources (sysctl, IOKit registry, SMC, IOReport, IOHID, nettop)** — openprocess_sampling_sysctl_sysctl, openprocess_sampling_iokitsamplers_iokitregistry, openprocess_sampling_powersampler_smc, openprocess_sampling_powersampler_ioreportenergy, openprocess_sampling_powersampler_hidtemperatures, openprocess_sampling_networksampler_nettop [INFERRED 0.85]
- **Tag to signed, notarized DMG release flow** — github_workflows_release_tag_version_parsing, github_workflows_release_unsigned_test_step, github_workflows_release_build_sign_notarize_step, github_workflows_release_verify_step, github_workflows_release_publish_github_release, readme_fastlane_lanes, project_xcodegen_spec [EXTRACTED 1.00]
- **Brand handoff spec realised in app resources and code** — assets_brand_readme_branding_handoff, assets_readme_branding_usage_map, openprocess_resources_appicon_icon_icon_appicon_composition, accentcolor_contents_accent_color, openprocess_views_menubarview_menubarglyph, packaging_dmg_settings, packaging_dmg_background [EXTRACTED 1.00]
- **App + privileged helper sharing XPC protocol under same-team signing** — readme_privileged_helper, project_openprocess_target, project_openprocesshelper_target, openprocess_helper_helperclient_helperclient, openprocess_shared_helperprotocol [INFERRED 0.85]
- **Dark icon composed from background and figure layers** — assets_brand_assets_icon_layers_01_fondo_oscuro, assets_brand_assets_icon_layers_02_figura_color, assets_brand_assets_icon_dark_openprocess_dark_1024 [INFERRED 0.85]
- **AppIcon.icon Icon Composer layers** — openprocess_resources_appicon_icon_assets_01_rejilla, openprocess_resources_appicon_icon_assets_02_figura, concept_layered_icon_composition [INFERRED 0.95]
- **Four appearance masters of the OpenProcess icon** — assets_brand_assets_icon_dark_openprocess_dark_1024, assets_brand_assets_icon_glassdark_openprocess_glassdark_1024, assets_brand_assets_icon_light_openprocess_light_1024, assets_brand_assets_icon_tinted_openprocess_tinted_1024, concept_icon_appearance_variants [INFERRED 0.85]

## Communities (18 total, 5 thin omitted)

### Community 0 - "Snapshots y vistas SwiftUI"
Cohesion: 0.06
Nodes (60): BatteryInfo, CoreLoad, .total, CPUSnapshot, GPUSnapshot, IOSnapshot, MemoryPressure, critical (+52 more)

### Community 1 - "Runtime dc de branding (support.js)"
Cohesion: 0.06
Nodes (74): boot(), bundledBlob(), cdnScriptFor(), collectProps(), compileAttr(), compileTemplate(), contentKey(), createComponentFactory() (+66 more)

### Community 2 - "Comandos y estado de UI"
Cohesion: 0.06
Nodes (37): AppCommands, .body, SignalMenu, .body, AppSection, cpu, disk, energy (+29 more)

### Community 3 - "Marca, build y release"
Cohesion: 0.07
Nodes (36): AccentColor colorset (light #1E7BE6, dark #268CFF), MenuBar Template (SVG), Menu bar template icon @2x (36px), MenuBar Template (PNG), App Screenshot: Resumen (Light), OpenProcess Branding design canvas (HTML visual reference, options 1a-1n), Branding handoff spec (Claude Design), support.js: generated dc-runtime bundle that renders the x-dc design canvas (+28 more)

### Community 4 - "Helper privilegiado XPC"
Cohesion: 0.07
Nodes (11): .body, HelperClient, .isEnabled, ResumeOnce, State, enabled, notInstalled, requiresApproval (+3 more)

### Community 5 - "Tabla de procesos AppKit"
Cohesion: 0.07
Nodes (5): AppKit, ClosureMenuItem, Coordinator, Item, ProcessTable

### Community 6 - "Variantes del icono de la app"
Cohesion: 0.06
Nodes (39): OpenProcess icon, dark, 1024px (master), OpenProcess icon, dark, 128px, OpenProcess icon, dark, 16px, OpenProcess icon, dark, 256px, OpenProcess icon, dark, 32px, OpenProcess icon, dark, 512px, OpenProcess icon, dark, 64px, OpenProcess icon, glass dark, 1024px (master) (+31 more)

### Community 7 - "Arranque de la app y ventanas"
Cohesion: 0.09
Nodes (22): Charts, AppDelegate, ContentView, .body, .signalTitle, OpenProcessApp, .body, SampleReportView (+14 more)

### Community 8 - "Energía y sensores IOKit"
Cohesion: 0.10
Nodes (7): IOKit.ps, HIDTemperatures, IOReportEnergy, KeyInfo, Param, PowerSampler, SMC

### Community 9 - "Memoria y sysctl"
Cohesion: 0.12
Nodes (5): Darwin, OpenProcess, MemorySampler, Sysctl, XCTest

### Community 10 - "Muestreo de procesos BSD"
Cohesion: 0.17
Nodes (4): BSDProcess, Previous, ProcessSampler, SamplingTests

### Community 11 - "Disco y GPU vía IOKit"
Cohesion: 0.14
Nodes (5): Foundation, IOKit, DiskSampler, GPUSampler, IOKitRegistry

### Community 12 - "Bucle de muestreo y CPU"
Cohesion: 0.23
Nodes (4): Sampler, .topology, CPUSampler, Ticks

## Ambiguous Edges - Review These
- `.sample()` → `.sample()`  [AMBIGUOUS]
  OpenProcess/Model/UIState.swift · relation: semantically_similar_to
- `OpenProcess icon, glass dark, 1024px (master)` → `Icon background layer, dark (01-fondo-oscuro)`  [AMBIGUOUS]
  assets/brand/assets/icon/glassdark/OpenProcess-glassdark-1024.png · relation: references

## Knowledge Gaps
- **56 isolated node(s):** `notInstalled`, `requiresApproval`, `enabled`, `unavailable`, `.id` (+51 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 152 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `.sample()` and `.sample()`?**
  _Edge tagged AMBIGUOUS (relation: semantically_similar_to) - confidence is low._
- **What is the exact relationship between `OpenProcess icon, glass dark, 1024px (master)` and `Icon background layer, dark (01-fondo-oscuro)`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **Why does `String` connect `Snapshots y vistas SwiftUI` to `Comandos y estado de UI`, `Helper privilegiado XPC`, `Tabla de procesos AppKit`, `Arranque de la app y ventanas`, `Energía y sensores IOKit`, `Memoria y sysctl`, `Muestreo de procesos BSD`, `Disco y GPU vía IOKit`, `Bucle de muestreo y CPU`, `Red vía nettop`, `Detalles y argumentos de proceso`?**
  _High betweenness centrality (0.253) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `SystemMonitor` (e.g. with `.body` and `HistoryChart`) actually correct?**
  _`SystemMonitor` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `ProcessRow` (e.g. with `RawProcStats` and `.body`) actually correct?**
  _`ProcessRow` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 6 inferred relationships involving `UIState` (e.g. with `.body` and `OpenProcessApp`) actually correct?**
  _`UIState` has 6 INFERRED edges - model-reasoned connections that need verification._
- **What connects `notInstalled`, `requiresApproval`, `enabled` to the rest of the system?**
  _56 weakly-connected nodes found - possible documentation gaps or missing edges._