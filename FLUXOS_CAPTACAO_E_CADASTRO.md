# Fluxos de Captação e Cadastro de Imóveis — Salute

Documento de alinhamento dos dois fluxos de entrada de imóvel e das validações entre as etapas.
Inclui o caso real **8638** (vídeo 02) como exemplo confirmado.

---

## Fluxo 1 — Captação do corretor (`/admin/captacoes`)

- **Quem usa:** somente o **corretor/captador**. Só ele vê e mexe nas próprias captações.
- **O que faz:** cadastro inicial via wizard (mobile-first), etapa por etapa.
- **Envia para revisão:** ao concluir, **envia para a administração** revisar e inserir dados que faltam.
- **Devolução:** a administração revisa e **devolve para o corretor**, e **o corretor publica** (libera no site).
- **Quem publica no site:** **sempre o corretor/captador responsável** — nunca o administrativo.
- **Visibilidade:** enquanto é **rascunho do corretor**, fica **somente no `/admin/captacoes` dele** — não aparece no Catálogo. *(Correto, não é bug.)*

### Etapas do wizard
`intro → proprietário → endereço → características → infraestrutura → negociação → visitas → fotos → review`

---

## Fluxo 2 — Cadastro direto da administração (`/admin/habitations/new`)

- **Quem usa:** a **administração**, quando cadastra o imóvel diretamente.
- **O que faz:** cadastra os dados e **seleciona o captador** responsável.
- **Ações de salvar:**
  - **Salvar** → grava e **permanece no cadastro** para continuar editando.
  - **Salvar e enviar ao captador** → grava e **encaminha ao corretor** (aguardando aceite/publicação dele).
  - *(Opcional)* **Salvar e sair** → grava e volta para a listagem.

---

## Ciclo de vida (status da captação / `intake_status`)

| Status | Significado | Onde aparece | Corretor pode publicar? |
|---|---|---|---|
| `draft` | Rascunho | Só em `/admin/captacoes` (do corretor) | Não (ainda preenchendo) |
| `submitted_for_admin_review` | Em revisão administrativa | Catálogo → "Pendente de revisão" | Não (com o admin) |
| `admin_approved` | Aguardando aceite do corretor | Catálogo → "Pendente de revisão" | **Sim** ✅ |
| `returned_to_broker` | Devolvido ao corretor | `/admin/captacoes` (do corretor) | **Sim** ✅ |
| `internal` | Disponível internamente | Catálogo (visível, "FORA SITE") | **Não** ⚠️ (beco sem saída p/ publicar) |
| `published` | Liberado para o site | Catálogo + site público | — (já publicado) |

> **Botão "Publicar no site" (corretor):** só aparece quando o status é **`admin_approved`** ou **`returned_to_broker`** (`BROKER_RELEASABLE_INTAKE_STATUSES`) **e** o usuário logado é o **captador responsável**. Ref.: `can_broker_release_to_site?` (`habitation_intakes_controller.rb:280`), `broker_release_pending?` / `broker_can_release_to_site?` (`habitation.rb:821` e `:920`).

> **Visibilidade no Catálogo:** captações de corretor só aparecem no Catálogo quando estão em **`internal`** ou **`published`** (`CATALOG_VISIBLE_INTAKE_STATUSES`). Rascunho/revisão/devolvido ficam no fluxo de Captações.

---

## Caso confirmado — 8638 (vídeo 02, corretora Luciana)

**Relato:** "8638 da Luciana não está publicado no site, e **não tem o botão Publicar no site** no perfil dela. Ele aparece em Todos como se já estivesse disponível pra todos, mas está FORA do site. Deveria ter voltado pra ela, que é quem publica. Os erros sumiram, só que o botão também sumiu."

**Diagnóstico (verificado em produção, id 21989):**
- `intake_status = "internal"`, `exibir_no_site_flag = false` → aparece no Catálogo ("Todos", badge **FORA SITE**), mas **não está no site**.
- As pendências **já foram resolvidas** (inclusive o falso positivo de "cidade do proprietário", já corrigido).
- **Mas** o botão "Publicar no site" **não aparece** porque o status é **`internal`**, que **não** é um status liberável pelo corretor (`broker_release_pending? = false`).
- Resultado: o imóvel ficou num **beco** — o administrativo o deixou **interno** em vez de **devolver para a corretora** (`admin_approved` / `returned_to_broker`), e por isso ela não tem como publicar.

**Regra correta esperada:** depois da revisão do administrativo, o imóvel deve **voltar para a corretora** num status liberável, para ela publicar no site. `internal` não pode ser um caminho que tranca a publicação do corretor.

---

## Validações entre as etapas

Validações de campos obrigatórios ao avançar cada etapa e ao liberar/publicar. Pendências comuns: dados do proprietário, valores (venda/locação), garantia locatícia, características, fotos/autorização, chaves, dias de visita.

**Já ajustado:**
- **Terreno** não exige Ocupação, Situação nem Vagas.
- **Cidade do proprietário** não bloqueia mais a liberação (nome + contato já identificam o proprietário).

---

## Problemas em aberto (a tratar, por fluxo)

1. **Botão "Publicar no site" some quando o imóvel vai para `internal`** (Fluxo 1): após a revisão, o imóvel deve **voltar à corretora** em status liberável; hoje vira `internal` e tranca a publicação. *(Caso 8638.)*
2. **Botão "Devolver para o corretor"** ausente em alguns estados da ficha (administração não consegue devolver).
3. **Publicação direta indevida:** garantir que o administrativo **não** publique no site direto — a liberação é sempre do corretor.
4. **Botão "Salvar" tira o usuário do cadastro** (Fluxo 2): "Salvar" deve **permanecer** no cadastro; está indo para a listagem.
5. **Rascunho do corretor que "some" ao salvar** (Fluxo 1): o corretor salva e não retoma a captação do ponto em que estava (passo do wizard não avança). *(Caso 8927.)*

---

## Princípio geral

> Existem **dois fluxos distintos** (corretor × administração) e, **no meio deles, validações**. Cada correção deve respeitar de qual fluxo o imóvel veio (`intake_origin` / `intake_status`), manter a publicação no site como ação **do corretor**, e não misturar as visibilidades (Captações × Catálogo).
