# Moon WGSL

This context defines the shader-language and compatibility concepts used by the MoonBit WGSL family of libraries.

## Language

**WGSL Core**:
The language-level WGSL model independent of Naga, naga-oil, WESL, or any compatibility writer.
_Avoid_: moon_wgsl core, composer core

**Official WGSL Frontend**:
The complete WGSL parser, semantic validator, and semantic IR for the official WGSL language.
_Avoid_: composer subset, partial parser

**WGSL Oracle Baseline**:
The pinned external sources used to judge WGSL frontend correctness.
_Avoid_: single implementation truth

**Workspace Release**:
A synchronized release of all publishable workspace modules with the same version number.
_Avoid_: independent module release

**Moon WGSL Facade**:
The public compatibility product that keeps the existing `moon_wgsl` identity as the recommended user entrypoint while delegating language facts to **WGSL Core**.
_Avoid_: core module, root module

**Legacy Subpackage Path**:
An old single-module package path under `Milky2018/moon_wgsl` that exposed internals such as parser, AST, IR, or lexer packages.
_Avoid_: public compatibility API

**Naga Compatibility Layer**:
The compatibility context that models Naga-specific ordering, naming, writer, and validation behavior.
_Avoid_: WGSL core, generic writer

**WGSL Semantic IR**:
The language-level intermediate representation that describes WGSL program meaning without compatibility writer policy.
_Avoid_: Naga IR, writer plan

**Naga Compatibility View**:
The Naga-shaped model derived from **WGSL Semantic IR** for Naga ordering, arena, temporary naming, and writer behavior.
_Avoid_: WGSL Semantic IR

**Generic WGSL Writer**:
A writer that emits valid WGSL from **WGSL Core** without promising Naga or naga-oil byte-level behavior.
_Avoid_: Naga writer, parity writer

**Source Edit Backend**:
A token- or span-level mechanism for applying textual edits after semantic decisions have already been made.
_Avoid_: semantic rewrite, WGSL language rule

**Compose Graph**:
The naga-oil compatibility model of modules, import edges, requested items, and module-level side effects.
_Avoid_: source rewrite plan

**Symbol Graph**:
The naga-oil compatibility model that binds imported and local declarations to stable symbol identities, scopes, aliases, and conflicts.
_Avoid_: string rename cache

**Final Name Table**:
The complete mapping from stable symbol identities to emitted names and reference spellings.
_Avoid_: generated-name heuristic

**Emission Plan**:
The ordered, already-bound plan consumed by a writer or source edit backend.
_Avoid_: rewrite pass

**naga-oil Compatibility Layer**:
The compatibility context that models naga-oil preprocessing and composer behavior.
_Avoid_: WGSL core, Naga layer

**WESL Extension Layer**:
The future compatibility context for WESL-specific syntax, composition, and language extensions.
_Avoid_: WGSL core

## Relationships

- **Moon WGSL Facade** depends on **WGSL Core** for language facts.
- **WGSL Core** aims to provide an **Official WGSL Frontend**, not a composer-oriented subset.
- **WGSL Oracle Baseline** combines GPUWeb CTS and Naga parser/validator behavior, with wgpu validation kept as an isolated tooling concern.
- **Workspace Release** publishes `wgsl`, `moon_wgsl_naga`, `moon_wgsl_naga_oil`, and `moon_wgsl` with the same version.
- **Moon WGSL Facade** is the default user-facing entrypoint for preprocessing and composition.
- **Legacy Subpackage Path** compatibility is not part of the workspace split goal.
- **Naga Compatibility Layer** depends on **WGSL Core** and must not define WGSL language semantics.
- **Generic WGSL Writer** belongs to **WGSL Core** only when it is free of Naga or naga-oil compatibility policy.
- **Naga Compatibility View** is derived from **WGSL Semantic IR** and must not be the source of WGSL language facts.
- **Source Edit Backend** must not be treated as a source of WGSL semantics.
- **Compose Graph**, **Symbol Graph**, **Final Name Table**, and **Emission Plan** are the semantic facts for naga-oil composition before any **Source Edit Backend** runs.
- **naga-oil Compatibility Layer** depends on **WGSL Core** and may depend on **Naga Compatibility Layer** only for explicitly Naga-shaped behavior.
- **WESL Extension Layer** is separate from **WGSL Core** and must not redefine base WGSL semantics.
- **WGSL Core** must not depend on **Moon WGSL Facade**, **Naga Compatibility Layer**, **naga-oil Compatibility Layer**, or **WESL Extension Layer**.

## Example dialogue

> **Dev:** "Should this identifier rule live in the naga-oil module?"
> **Domain expert:** "No. If it is a WGSL language rule, it belongs in **WGSL Core**. naga-oil-specific import behavior belongs in the **naga-oil Compatibility Layer**."

## Flagged ambiguities

- "module" can mean a MoonBit `moon.mod` module or a MoonBit package; resolved: the planned boundary split uses MoonBit `moon.mod` modules under a workspace.
