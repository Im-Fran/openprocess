# Graph Report - openprocess  (2026-09-30)

## Corpus Check
- 38 files · ~180,264 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 10 file(s) not represented in the graph (top: (none) 7, .entitlements 1, .plist 1)

## Summary
- 687 nodes · 1633 edges · 29 communities (14 shown, 15 thin omitted)
- Extraction: 86% EXTRACTED · 14% INFERRED · 0% AMBIGUOUS · INFERRED: 232 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `dd263920`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- String
- support.js
- UIState
- OpenProcess README (native open-source Activity Monitor replacement)
- HelperClient
- Coordinator
- OpenProcess icon, dark, 1024px (master)
- View
- SMC
- SamplingTests
- .build
- .sample
- Sampler
- .sample
- ProcessRow
- .sample
- RawProcStats
- .sample
- OpenProcess

## God Nodes (most connected - your core abstractions)
1. `SystemMonitor` - 43 edges
2. `ProcessRow` - 32 edges
3. `UIState` - 27 edges
4. `AppSection` - 23 edges
5. `get()` - 23 edges
6. `Coordinator` - 22 edges
7. `ProcessTable` - 22 edges
8. `createRuntime()` - 22 edges
9. `ProcessColumn` - 19 edges
10. `OpenProcess README (native open-source Activity Monitor replacement)` - 18 edges

## Surprising Connections (you probably didn't know these)
- `Optional privileged helper (SMAppService launch daemon + XPC)` --references--> `SettingsView`  [INFERRED]
  README.md → OpenProcess/App/SettingsView.swift
- `Per-process network via nettop once per cycle` --rationale_for--> `NetworkSampler`  [INFERRED]
  README.md → OpenProcess/Sampling/NetworkSampler.swift
- `Optional privileged helper (SMAppService launch daemon + XPC)` --rationale_for--> `HelperClient`  [INFERRED]
  README.md → OpenProcess/Helper/HelperClient.swift
- `Repository structure (App, Model, Sampling, Helper, Shared, Views, Resources)` --references--> `SystemMonitor`  [EXTRACTED]
  README.md → OpenProcess/Model/SystemMonitor.swift
- `Private Apple APIs with graceful degradation (IOReport, SMC, IOHIDEventSystemClient)` --rationale_for--> `IOReportEnergy`  [INFERRED]
  README.md → OpenProcess/Sampling/PowerSampler.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **macOS Packaging Assets** — packaging_dmg_background, packaging_dmg_background_2x, openprocess_app [EXTRACTED 0.90]
- **Brand handoff spec realised in app resources and code** — assets_brand_readme_branding_handoff, assets_readme_branding_usage_map, openprocess_resources_appicon_icon_icon_appicon_composition, accentcolor_contents_accent_color, openprocess_views_menubarview_menubarglyph, packaging_dmg_settings, packaging_dmg_background [EXTRACTED 1.00]
- **Brand Identity Assets** — assets_brand_assets_icon_svg_openprocess_figura, assets_brand_assets_icon_svg_openprocess_figura_mono, assets_brand_assets_icon_svg_openprocess_icon_dark, assets_brand_assets_menubar_menubartemplate [EXTRACTED 1.00]
- **Tag to signed, notarized DMG release flow** — github_workflows_release_tag_version_parsing, github_workflows_release_unsigned_test_step, github_workflows_release_build_sign_notarize_step, github_workflows_release_verify_step, github_workflows_release_publish_github_release, readme_fastlane_lanes, project_xcodegen_spec [EXTRACTED 1.00]
- **Samplers populating SystemSnapshot each tick** — openprocess_sampling_cpusampler_cpusampler, openprocess_sampling_memorysampler_memorysampler, openprocess_sampling_iokitsamplers_gpusampler, openprocess_sampling_iokitsamplers_disksampler, openprocess_sampling_networksampler_networksampler, openprocess_sampling_networksampler_nettop, openprocess_sampling_powersampler_powersampler, openprocess_sampling_processsampler_processsampler, openprocess_model_systemmonitor_sampler, openprocess_model_snapshots_systemsnapshot [EXTRACTED 1.00]
- **Section views composed from SectionPage/Card/Stat/HistoryChart/TopProcesses** — openprocess_views_sectionviews_cpuview, openprocess_views_sectionviews_memoryview, openprocess_views_sectionviews_gpuview, openprocess_views_sectionviews_energyview, openprocess_views_sectionviews_diskview, openprocess_views_sectionviews_networkview, openprocess_views_components_sectionpage, openprocess_views_components_card, openprocess_views_components_stat, openprocess_views_components_historychart, openprocess_views_components_topprocesses [EXTRACTED 1.00]
- **Signal Delivery Flow (menu -> confirm -> kill/helper)** — openprocess_app_appcommands_signalmenu, openprocess_model_uistate_uistate_request, openprocess_model_uistate_signalrequest, openprocess_app_openprocessapp_contentview_body, openprocess_model_uistate_uistate_signal, openprocess_model_systemmonitor_systemmonitor_send, openprocess_helper_helperclient_helperclient_sendsignal, openprocesshelper_main_helper_sendsignal [EXTRACTED 1.00]
- **System Sampling Pipeline (Sampler -> Snapshot -> History)** — openprocess_model_systemmonitor_sampler, openprocess_model_systemmonitor_sampler_sample, openprocess_model_snapshots_systemsnapshot, openprocess_model_systemmonitor_systemmonitor_apply, openprocess_model_systemmonitor_metrics, openprocess_model_history_history, openprocess_model_systemmonitor_systemmonitor_start [EXTRACTED 1.00]
- **Dark icon composed from background and figure layers** — assets_brand_assets_icon_layers_01_fondo_oscuro, assets_brand_assets_icon_layers_02_figura_color, assets_brand_assets_icon_dark_openprocess_dark_1024 [INFERRED 0.85]
- **Four appearance masters of the OpenProcess icon** — assets_brand_assets_icon_dark_openprocess_dark_1024, assets_brand_assets_icon_glassdark_openprocess_glassdark_1024, assets_brand_assets_icon_light_openprocess_light_1024, assets_brand_assets_icon_tinted_openprocess_tinted_1024, concept_icon_appearance_variants [INFERRED 0.85]
- **Low-level macOS data sources (sysctl, IOKit registry, SMC, IOReport, IOHID, nettop)** — openprocess_sampling_sysctl_sysctl, openprocess_sampling_iokitsamplers_iokitregistry, openprocess_sampling_powersampler_smc, openprocess_sampling_powersampler_ioreportenergy, openprocess_sampling_powersampler_hidtemperatures, openprocess_sampling_networksampler_nettop [INFERRED 0.85]
- **App + privileged helper sharing XPC protocol under same-team signing** — readme_privileged_helper, project_openprocess_target, project_openprocesshelper_target, openprocess_helper_helperclient_helperclient, openprocess_shared_helperprotocol [INFERRED 0.85]
- **AppIcon.icon Icon Composer layers** — openprocess_resources_appicon_icon_assets_01_rejilla, openprocess_resources_appicon_icon_assets_02_figura, concept_layered_icon_composition [INFERRED 0.95]

## Communities (29 total, 15 thin omitted)

### Community 0 - "String"
Cohesion: 0.09
Nodes (37): MemoryPressure, critical, normal, warning, Metrics, SystemMonitor, String, Card (+29 more)

### Community 1 - "support.js"
Cohesion: 0.06
Nodes (74): boot(), bundledBlob(), cdnScriptFor(), collectProps(), compileAttr(), compileTemplate(), contentKey(), createComponentFactory() (+66 more)

### Community 2 - "UIState"
Cohesion: 0.05
Nodes (37): AppCommands, .body, SignalMenu, .body, AppSection, cpu, disk, energy (+29 more)

### Community 3 - "OpenProcess README (native open-source Activity Monitor replacement)"
Cohesion: 0.08
Nodes (34): AccentColor colorset (light #1E7BE6, dark #268CFF), MenuBar Template (SVG), Menu bar template icon @2x (36px), MenuBar Template (PNG), App Screenshot: Resumen (Light), OpenProcess Branding design canvas (HTML visual reference, options 1a-1n), Branding handoff spec (Claude Design), support.js: generated dc-runtime bundle that renders the x-dc design canvas (+26 more)

### Community 4 - "HelperClient"
Cohesion: 0.07
Nodes (12): .body, HelperClient, .isEnabled, ResumeOnce, State, enabled, notInstalled, requiresApproval (+4 more)

### Community 5 - "Coordinator"
Cohesion: 0.07
Nodes (4): ClosureMenuItem, Coordinator, Item, ProcessTable

### Community 6 - "OpenProcess icon, dark, 1024px (master)"
Cohesion: 0.06
Nodes (39): OpenProcess icon, dark, 1024px (master), OpenProcess icon, dark, 128px, OpenProcess icon, dark, 16px, OpenProcess icon, dark, 256px, OpenProcess icon, dark, 32px, OpenProcess icon, dark, 512px, OpenProcess icon, dark, 64px, OpenProcess icon, glass dark, 1024px (master) (+31 more)

### Community 7 - "View"
Cohesion: 0.06
Nodes (28): Charts, AppDelegate, ContentView, .body, .signalTitle, OpenProcessApp, .body, SampleReportView (+20 more)

### Community 8 - "SMC"
Cohesion: 0.09
Nodes (9): Foundation, IOKit, IOKit.ps, HIDTemperatures, IOReportEnergy, KeyInfo, Param, PowerSampler (+1 more)

### Community 9 - "SamplingTests"
Cohesion: 0.20
Nodes (4): Darwin, OpenProcess, SamplingTests, XCTest

### Community 10 - ".build"
Cohesion: 0.26
Nodes (4): BSDProcess, Previous, ProcessDetails, ProcessSampler

### Community 12 - "Sampler"
Cohesion: 0.29
Nodes (5): AppKit, Sampler, .topology, CPUSampler, Ticks

### Community 13 - ".sample"
Cohesion: 0.15
Nodes (4): Nettop, NetworkSampler, OpenFile, ProcessInspector

### Community 14 - "ProcessRow"
Cohesion: 0.08
Nodes (24): History, Point, BatteryInfo, CoreLoad, .total, CPUSnapshot, .total, GPUSnapshot (+16 more)

## Ambiguous Edges - Review These
- `.sample()` → `.sample()`  [AMBIGUOUS]
  OpenProcess/Model/UIState.swift · relation: semantically_similar_to
- `Icon background layer, dark (01-fondo-oscuro)` → `OpenProcess icon, glass dark, 1024px (master)`  [AMBIGUOUS]
  assets/brand/assets/icon/glassdark/OpenProcess-glassdark-1024.png · relation: references

## Knowledge Gaps
- **60 isolated node(s):** `.enabled`, `.detail`, `.body`, `.body`, `.body` (+55 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 173 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **15 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `.sample()` and `.sample()`?**
  _Edge tagged AMBIGUOUS (relation: semantically_similar_to) - confidence is low._
- **What is the exact relationship between `Icon background layer, dark (01-fondo-oscuro)` and `OpenProcess icon, glass dark, 1024px (master)`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **Why does `parseDcDocument()` connect `OpenProcess README (native open-source Activity Monitor replacement)` to `support.js`?**
  _High betweenness centrality (0.215) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `SystemMonitor` (e.g. with `.body` and `HistoryChart`) actually correct?**
  _`SystemMonitor` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `ProcessRow` (e.g. with `RawProcStats` and `.body`) actually correct?**
  _`ProcessRow` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 5 inferred relationships involving `UIState` (e.g. with `.body` and `.body`) actually correct?**
  _`UIState` has 5 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.enabled`, `.detail`, `.body` to the rest of the system?**
  _60 weakly-connected nodes found - possible documentation gaps or missing edges._