# Migflow — Contexto da conversa (referência para futuras sessões)

Este documento resume o projeto Migflow, a estrutura de arquivos, decisões tomadas e ajustes feitos durante a conversa, para ser usado como referência em outras conversas.

---

## O que é o Migflow

**Migflow** é uma gem Ruby que funciona como **Rails Engine**. Ao montar em uma aplicação Rails (`mount Migflow::Engine => "/migflow"`), expõe um painel visual em `/migflow` para:

- Visualizar o histórico de migrations
- Auditar o schema (warnings: índices faltando, FKs, strings sem limit, etc.)
- Comparar migrations (diff entre duas versões)
- Ver um ERD interativo com tabelas, colunas, FKs e highlights de diff

---

## Stack técnica

- **Backend:** Ruby, Rails 7+, engine isolada (`Migflow::Engine`)
- **API JSON:** rotas em `/migflow/api/` (migrations, diff, warnings)
- **Frontend:** React 19, TypeScript, Vite, Tailwind, TanStack Query, Zustand, React Flow (@xyflow/react)
- **Build do frontend:** `cd frontend && npm run build` → gera arquivos em `app/assets/migflow/` (app.js, app.css). O engine registra esses assets no Sprockets.

---

## Estrutura principal de arquivos

```
migflow/
├── lib/migflow.rb
├── lib/migflow/engine.rb
├── lib/migflow/configuration.rb
├── lib/migflow/version.rb
├── lib/migflow/parsers/migration_parser.rb
├── lib/migflow/parsers/schema_parser.rb
├── lib/migflow/models/migration_snapshot.rb
├── lib/migflow/models/schema_diff.rb
├── lib/migflow/models/warning.rb
├── lib/migflow/analyzers/audit_analyzer.rb
├── lib/migflow/analyzers/rules/*.rb
├── lib/migflow/services/schema_builder.rb
├── lib/migflow/services/diff_builder.rb
├── config/routes.rb                    # Engine routes
├── app/controllers/migflow/application_controller.rb
├── app/controllers/migflow/api/migrations_controller.rb
├── app/controllers/migflow/api/diff_controller.rb
├── app/controllers/migflow/api/warnings_controller.rb
├── app/views/migflow/application/index.html.erb
├── app/assets/migflow/                 # Saída do Vite (app.js, app.css)
│
frontend/
├── vite.config.ts                      # outDir: ../app/assets/migflow
├── src/
│   ├── main.tsx
│   ├── App.tsx
│   ├── index.css
│   ├── types/migration.ts
│   ├── api/client.ts                   # getMigrations, getMigrationDetail, getDiff, getWarnings
│   ├── store/useSchemaStore.ts
│   ├── utils/parseMigrationChanges.ts  # Extrai create_table, add_column, remove_column, etc.
│   └── components/
│       ├── Timeline.tsx
│       ├── SchemaCanvas.tsx
│       ├── TableNode.tsx
│       ├── RelationshipEdge.tsx       # Edge customizada (hover, flow, diff)
│       ├── DetailPanel.tsx
│       ├── CompareBar.tsx
│       └── ResizablePanel.tsx
```

---

## API da engine

- `GET /migflow` → HTML com div `#schema-trail-root` e `data-api-base=".../migflow/api"`
- `GET /migflow/api/migrations` → lista com version, name, filename, summary
- `GET /migflow/api/migrations/:id` → detalhe com raw_content, schema.tables, warnings
- `GET /migflow/api/diff?from=&to=` → diff entre duas versões
- `GET /migflow/api/warnings` → warnings do schema atual

O `render_json` no `ApplicationController` usa assinatura `render_json(status: :ok, **data)` para compatibilidade com Ruby 3.0+ (keyword args).

---

## Assets e pipeline

- **Problema inicial:** 404 em `/stylesheets/migflow/app.css` e `/javascripts/migflow/app.js` ao usar `skip_pipeline: true`.
- **Solução:** Remover `skip_pipeline: true` e fazer o build do Vite apontar para `app/assets/migflow/` (não `lib/migflow/app/assets/migflow/`), para o Sprockets da app host encontrar `migflow/app.js` e `migflow/app.css`.
- Na view: `stylesheet_link_tag "migflow/app"` e `javascript_include_tag "migflow/app", defer: true`. O CSS é necessário porque o Vite gera arquivo separado.

---

## Store Zustand (useSchemaStore)

- `selectedVersion`, `compareFrom`, `compareTo`, `isCompareMode` — seleção e modo compare
- `highlightedEdgeId: string | null` — edge em hover (coluna FK ou edge)
- `selectedTableId: string | null` — tabela clicada (efeito “flow” nas edges conectadas)

---

## SchemaCanvas e TableNode — comportamento atual

1. **MiniMap** — removido.
2. **fitView** — após trocar de migration, um `FitViewManager` dentro do ReactFlow chama `fitView({ nodes: changedNodes, duration: 500, padding: 0.2 })` para nodes com `tableStatus` ou colunas com `diffStatus`; se não houver mudanças, `fitView()` normal.
3. **Handles** — target: `id="table-target"`, centro do header. Source: um por coluna FK, com `style={{ top: HEADER_HEIGHT + idx * ROW_HEIGHT + ROW_HEIGHT/2, position: 'absolute' }}`. Edges usam `sourceHandle` = nome da coluna, `targetHandle="table-target"`.
4. **Edges** — tipo customizado `relationship` (`RelationshipEdge`). Padrão: stroke `#444C56`, 1.5px. Hover (edge ou coluna FK): `#58A6FF`, 2px, label `"user_id → users"`. Diff: verde (#3FB950) para adicionada, vermelho (#F85149) tracejado para removida.
5. **Flow ao clicar na tabela** — `onNodeClick` seta `selectedTableId`; edges com source ou target igual ficam azuis e com classe `.edge-flow` (animação). `onPaneClick` limpa.
6. **Offset entre edges** — múltiplas edges entre o mesmo par de nodes recebem `offset` no `data` (leque); usado em `getSmoothStepPath` para evitar sobreposição.
7. **FK só quando há edge** — `fkColumns` e `fkEdgeMap` vêm do SchemaCanvas (baseado nas edges realmente criadas). TableNode mostra handle e ícone ⇢ apenas para colunas em `fkColumns`.

---

## Diff e parse de migrations

- `parseMigrationChanges(rawContent)` em `utils/parseMigrationChanges.ts` — regex para `create_table`, `drop_table`, `add_column`, `remove_column`, `add_index`, `remove_index`. Retorna `DiffInfo` (Sets/Maps).
- TableNode: colunas com `diffStatus: 'added'` (fundo verde, +), `'removed'` (fundo vermelho, −, strikethrough). Tabelas: badge NEW (borda verde), REMOVED (borda vermelha, opacidade 60%).

---

## ResizablePanel

- Painéis esquerdo (Timeline) e direito (DetailPanel) são `ResizablePanel` com min 200px, max 600px, inicial 280 e 320. Handle de 4px na borda (cinza, hover azul), drag atualiza largura em estado local.

---

## Como testar localmente

1. **Testes unitários (sem Rails):**  
   `ruby -Itest test/migflow/parsers/migration_parser_test.rb test/migflow/parsers/schema_parser_test.rb test/migflow/analyzers/audit_analyzer_test.rb`

2. **Painel em app real:**  
   Criar app Rails, no Gemfile: `gem "migflow", path: "../migflow"`. Em `config/routes.rb`: `mount Migflow::Engine => "/migflow"`. `bundle install`, criar migrations de exemplo, `rails server`. Acessar `http://localhost:3000/migflow`.

3. **Build do frontend:**  
   `cd frontend && npm run build`. Reiniciar o servidor Rails após mudanças nos assets.

---

## Paleta de cores (tema escuro)

- Background: `#0D1117`
- Surface: `#161B22`
- Border: `#30363D`
- Texto primário: `#E6EDF3`
- Texto secundário: `#7D8590`
- Accent azul: `#58A6FF`
- Verde (adições): `#3FB950`
- Vermelho (remoções): `#F85149`
- Amarelo (warnings): `#D29922`
- Edge padrão: `#444C56`

---

## Tipos TypeScript relevantes

- `Migration`, `MigrationDetail`, `Column`, `ColumnWithDiff`, `Index`, `IndexWithDiff`, `Table`, `Schema`, `Warning`, `Diff`, `DiffChange`
- `DiffInfo`: `addedTables`, `removedTables`, `addedColumns`, `removedColumns`, `addedIndexColumns`, `removedIndexColumns`
- `TableNodeData`: `label`, `columns`, `indexes`, `warningCount`, `tableStatus`, `fkColumns`, `fkEdgeMap`
- `RelationshipEdgeData`: `diffAdded`, `diffRemoved`, `fkColumn`, `offset`

---

Fim do contexto. Use este arquivo como ponto de partida em novas conversas sobre o Migflow.
