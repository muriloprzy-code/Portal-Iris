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
- Chave de LLM: variáveis de ambiente / `.env` (`MYOWN_AI_PROVIDER`, `MYOWN_AI_MODEL`, `MYOWN_AI_API_KEY`; opcionais `MYOWN_AI_MODE`, `MYOWN_AI_TIMEOUT_SECONDS`, `MYOWN_AI_MAX_OUTPUT_TOKENS`, `MYOWN_AI_THINKING`). Com Gemini free tier, o modelo que funciona é `gemini-3.8-flash`. Provedores oficiais: OpenAI, Anthropic, Gemini, Bedrock. Ollama é experimental, nunca padrão.

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

Corpus adversarial (20/10): `MyOwn.Test.AgentAdversarial`, 92 casos, `scripts/Test-AgentAdversarial.ps1` → 92/92. Achou e corrigiu 20 falhas reais (Validator 12, Gate 1, Sanitize 7); detalhes em `docs/PROGRESS.md`. Refs de `evidence` agora passam por `Agent.SanitizeEvidence` antes de gravar (ADV-E01); `Agent.PublicDecision` faz a resposta do REST, a mensagem do trace e o detalhe da decisão saírem iguais ao banco (ADV-E02/E03). Frontend sem `dangerouslySetInnerHTML`; rationale/evidence/conditions ainda não aparecem na UI.

Etapas de 20/10 (commits separados): pedido de acesso assíncrono (IT-13), Gate e proposta como passos do BP (`Process.Steps`), auditoria `MyOwn/Agent/*` com marcador (UT-14, IT-14), painel de detalhes na aba Decisions (IT-15). Resultados: corpus 92/92, core 14/14, integração 19/19, REST 24/0/1, UI 14/14. Reinstalação reinicia a produção sozinha; S2/S3 pela tela usam a tarefa de demo (IT-16). Tela verificada por Playwright isolado (`scripts/Test-AgentsUI.ps1`, sem erro de console). Propostas vencidas viram `expired` ao listar; o Gate não duplica proposta por tarefa e ação (pendente ou executada no cooldown); StableKey usa faixa de falhas.

## Próximos passos
1. ~~Recompilar, smokes e Test-Agents~~ (feito em 20/10).
4. ~~Gravar resultados de core e integração~~ (feito: `scripts/Test-AgentSmoke.ps1 -Credential` gera `agents-smoke-core.json` e `agents-smoke-integration.json`).
5. Pendências da revisão: ~~mover criação de proposta e Gate para o BP~~ (feito em 20/10: `Process.Steps`, decide → Gate → ProposalStore; reiniciar a produção após o deploy), ~~tornar o caminho de pedido de acesso assíncrono~~ (feito em 20/10: fila + `GET /agent/access-requests/:id`, IT-13), ~~alinhar eventos de auditoria com a spec~~ (feito em 20/10: `MyOwn/Agent/*` com `agent=1;decisionId=N`; falta o filtro na página Logs), reforçar SEC-01/02 com LLM real (o corpus offline já cobre SEC-01..04).
6. ~~T01 na 154 (IRIS for Health)~~ feito em 21/10: instala sozinho na 52774 (volume `myown-portal-data-154`), regressão igual à 2026.2, classes `%AI.*` presentes (ver `docs/AI-HUB-NOTES.md`). Falta a edição IRIS Community da 154 (imagem não carregada). T02 feito em 21/10 (API `%AI` em `docs/AI-HUB-NOTES.md`, seção "Mapeamento para o portal"; sem structured output, sem provider ollama). T03 feito em 21/10 (Gemini `gemini-3.8-flash`, 8/8 JSON válido, 12–83 s; achados em "Teste real" do AI-HUB-NOTES: limite de chamadas conta decisões do Rules, motivo do fallback não é gravado, latência > 60 s do gateway em rotas síncronas). T04 feito em 22/10: módulo `aihub/` (`myown-portal-aihub`, só instala onde há `%AI`) com `MyOwn.AIHub.Engine` (worker em JOB com prazo `MYOWN_AI_TIMEOUT_SECONDS`, padrão 20 s), tools somente leitura + `Policy.ReadOnlyAuth` (negação vira `ToolCall` denied e auditoria `ToolDenied`), ledger com tokens/custo/latência, modo `MYOWN_AI_MODE=replay` (respostas da T03). Motivo do fallback gravado e mostrado ("AI" ou "Rules (motivo)"). Limite de chamadas conta só IA real. Config do provider só do ambiente (`MyOwn.Agent.AIEnv`). Testes: engine 14/14 em replay na 154; regressão completa igual nas duas (corpus 92, core 14, integração 19, REST 24/0/1, UI 14). Chamadas reais: 5 de 6, todas em fallback (400 `generationConfig`, 3 timeouts, 429 de cota gratuita); latência depois das mudanças ainda não medida. Na 154 a preferência ficou em `rules` até a cota voltar. Detalhes em `docs/PROGRESS.md` e `docs/AI-HUB-NOTES.md` (seção T04). 4b feito em 24/10: fixtures de replay por cenário em `aihub/fixtures/S*.json` (decisões reais com modelo e data no cabeçalho; S1–S4, S8, S9 da T03 com contexto equivalente, S5–S7 gravados com o contexto exato, S10 não se aplica; nenhum pendente). Gerar a classe: `scripts/Build-ReplayFixtures.ps1`; gravar: `scripts/Record-ReplayFixtures.ps1` (máx. 6 chamadas, 15 s). Cenário sem gravação dá fallback `replay_missing`. Tela mostra "Replay of recorded real decisions" em `MYOWN_AI_MODE=replay`. Latência real com as configs novas: 11,6–16,4 s (3 chamadas). A 154 ficou em replay com preferência `rules`. Regravação de 24/10: só S1 saiu (18,1 s); S2 e S3 estouraram 20 s e parou em 3 chamadas. Nova tentativa em 26/10 (prazo 55 s, 2 chamadas): Gemini devolveu 503 "high demand" após retries internos; worker e loop de tools descartados com mock local. S2–S4, S8, S9 seguem da T03. 504 do gateway resolvido em 24/10: IT-14 e AH-07 esperavam a auditoria (o IRIS só mostra o registro 46–60 s depois) dentro de uma requisição, e o Web Gateway corta em 60 s (`Server_Response_Timeout`); agora as suítes devolvem essas checagens como pendentes e os scripts consultam a cada 2 s (`waitAudit=0`). Regressão completa passou de primeira em imagem e volume novos. T11 feito em 26/10: modo demo (`MYOWN_DEMO_MODE=1`): usuário `demo` (papel `MyOwnDemo`, criado no boot por `docker/demo-start.sh` com a senha de `MYOWN_DEMO_USER_PASSWORD`, gerada por `scripts/New-DemoPassword.ps1` só no `.env`); confirmação só em alvos sintéticos (`MyOwn.Demo.Target`), execução simulada (estado `simulated`, o IRIS não muda), outros alvos recusados e auditados (`DemoRefused`); rotas que mudam o sistema real bloqueadas para todos; reset a cada N h e botão "Reset demo" (`DemoReset`); limite de cenários por minuto por IP/sessão. Testes: `scripts/Test-AgentDemo.ps1` 16/16 na 154 com login real do demo. Usuário com privilégio mínimo precisa de banco e SQL SELECT via papel de aplicação `MyOwnDemoData` (o `MyOwnViewer` nunca foi testado sem `%All`). Próximo: publicar a demo online, vídeo e artigo.
   - Build da 154 nesta máquina: `docker build --build-arg IMAGE=irishealth-community:2026.3.0AI.154.0 ... -t portaliris-iris:latest .` e `docker compose -f compose.yaml -f compose.aihub.yaml up -d --no-build` (o `compose build` usa um builder buildx que não enxerga a imagem local). Um build por vez: o IRIS for Health carrega FHIR (pico ~1,3 GB). O cliente `docker build` às vezes fica pendurado depois de terminar; matar o processo no Windows **não** para o build no daemon (conferir com `docker buildx history ls`).
   - Abra o portal do container em `http://localhost:52774/myown/index.html` (o servidor web do container não serve documento padrão para `/myown/`).

## Convenções
- Testes: scripts PowerShell em `scripts/`, relatórios JSON em `test-results/`.
- Documentação viva: `docs/PROGRESS.md`, `docs/AI-HUB-NOTES.md`, `docs/ARTICLE-NOTES.md`. Atualize ao terminar cada etapa.
