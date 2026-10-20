# MyOwn Portal (Meu Portal) — contexto para o Claude Code

Responda sempre em **português**, de forma **objetiva e curta**. Não faça commit nem push sem o usuário pedir.

## Projeto
- Portal de administração IRIS (backend ObjectScript em `src/objectscript/MyOwn`, frontend React/TS em `frontend/`).
- Repo: GitHub `muriloprzy-code/Portal-Iris`. IPM module `myown-portal` (versão 1.1.0).
- IRIS local: web gateway porta 52773, namespace `MYOWN`. Docker/compose do portal usa 52774.
- Credenciais ficam só no MCP/`.env` do usuário. Nunca coloque senha ou chave de API em arquivo do repositório.

## Objetivo atual
Concurso InterSystems Programming Contest "AI Agents in Interoperability Workflows" (26/10 a 15/11/2026; envio até 08/11/2026 23:59 EST; votação 09 a 15/11). Meta: ficar entre os primeiros.
- Spec: `docs/SPEC-AI-AGENTS.md`. Em conflito vale `docs/SPEC-AI-AGENTS-ADDENDUM-1.md` (respostas oficiais dos organizadores).
- Imagem alvo: AI Hub build **2026.3.0AI.154.0** (IRIS e IRIS for Health aceitas). Nunca publicar essa imagem nem imagens derivadas em registro público; só Dockerfile e compose.
- Chave de LLM: variáveis de ambiente / `.env` (`MYOWN_AI_PROVIDER`, `MYOWN_AI_MODEL`, `MYOWN_AI_API_KEY`). Provedores oficiais: OpenAI, Anthropic, Gemini, Bedrock. Ollama é experimental, nunca padrão.

## Design (não violar)
- O agente só decide e propõe, nunca escreve. Quem executa é um humano, com as credenciais dele.
- Gate determinístico + Validator + alvos proibidos. Confirmação revalida tudo: estado, expiração, separação de funções, alvo proibido, fingerprint do alvo (TARGET_CHANGED), permissão ao vivo, leitura de volta.
- Engine `Rules` é o fallback: o app tem que funcionar sem AI Hub e sem chave.
- Dados não confiáveis (logs, justificativas) entram só dentro de delimitadores; decisões do LLM passam pelo Validator.

## Estado em 20/10/2026
Feito pelo Codex (tudo sem commit): `MyOwn.Agent.*`, `MyOwn.Production.*` (BS, BP, BO), 22 rotas `/agent/*`, cenários S1 a S10, frontend (`AgentsPage`), `scripts/Test-Agents.ps1`. Resultados reportados: REST 21 pass / 0 fail / 1 skip; AI Hub 6 pulados (imagem 154 ainda não carregada).

Corrigido na revisão (compilado e testado em 20/10: core 12/12, integração 15/15, REST 21/0/1 skip):
1. Cooldown: fingerprint agora usa `StableKey` (sem métricas voláteis). `simulationRunId` mantém cada simulação única.
2. `TaskWatcher` reescrito: falhas consecutivas por tarefa (MYOWN), suspensa + último run ok; usa SQL dinâmico em `%SYS_Task.History` e `%SYS.Task`.
3. Lock por proposta em `ConfirmProposal` e `RejectProposal` (erro `PROPOSAL_BUSY`, HTTP 409).
4. Validator: `confidence` numérica 0 a 1, `rationale` obrigatório, `propose_*` exige `targetType=task`.
5. Gate lê `manageable` do candidato da tarefa escolhida.
6. `budgetScenario` só vale com `source = "simulate"`.
7. Três testes novos em `Test/AgentCore.cls` (esperado: smoke 12/12; eram 9).

Corpus adversarial (20/10): `MyOwn.Test.AgentAdversarial`, 89 casos, `scripts/Test-AgentAdversarial.ps1` → 89/89. Achou e corrigiu 20 falhas reais (Validator 12, Gate 1, Sanitize 7); detalhes em `docs/PROGRESS.md`. Pendente: sanitizar refs de `evidence` em `Agent.SaveDecision`.

## Próximos passos
1. ~~Recompilar, smokes e Test-Agents~~ (feito em 20/10).
4. ~~Gravar resultados de core e integração~~ (feito: `scripts/Test-AgentSmoke.ps1 -Credential` gera `agents-smoke-core.json` e `agents-smoke-integration.json`).
5. Pendências da revisão: mover criação de proposta e Gate para o BP, tornar o caminho de pedido de acesso assíncrono, alinhar eventos de auditoria com a spec (marcador de agente), reforçar SEC-01/02 com LLM real (o corpus offline já cobre SEC-01..04).
6. Quando a imagem 154 carregar: T01 (regressão nas duas edições), depois engine AI Hub, ferramentas, políticas e ledger. Depois README, vídeo e demo pública.

## Convenções
- Testes: scripts PowerShell em `scripts/`, relatórios JSON em `test-results/`.
- Documentação viva: `docs/PROGRESS.md`, `docs/AI-HUB-NOTES.md`, `docs/ARTICLE-NOTES.md`. Atualize ao terminar cada etapa.
