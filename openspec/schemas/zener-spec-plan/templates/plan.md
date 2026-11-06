---
name: "<!-- change name -->"
description: "<!-- one sentence -->"
created_at: "<!-- YYYY-MM-DDTHH:MM:SSZ -->"

created_by:
  tool: "<!-- e.g. Claude Code -->"
  model:
    name: "<!-- e.g. Claude Opus -->"
    version: "<!-- e.g. 4.6 -->"
    reasoning_effort: "<!-- low | medium | high -->"
---

# <!-- Plan title -->

## Objetivo

<!-- 1-3 sentences: what gets built and why it matters -->

## Decisiones

- <!-- choice or assumption (instead of <discarded alternative>, when not obvious) -->
- Fuera del alcance: <!-- what this change does not do -->

## Fases

### Fase 1: <!-- vertical slice -->

<!-- What this phase delivers -->

#### Contratos

```<!-- project language -->
<!-- Contract type, as a comment -->
<!-- signature -->
```

#### Tests

- `<!-- test suite -->`: <!-- behaviours it covers -->

- [ ] <!-- task -->
- [ ] Verifica los cambios en cuanto a comprobación de tipos, linting y pruebas utilizando el comando de verificación del proyecto. Busca el comando en el archivo AGENTS.md o en la configuración del proyecto. Corrige cualquier problema que aparezca.

## Siguiente paso

Ejecuta `/openspec-apply-change` para implementar la Fase.
