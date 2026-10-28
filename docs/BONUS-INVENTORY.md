# Inventário dos bônus do concurso (T14, 2026-10-27)

Somente leitura: nenhum código do portal mudou. Evidência = arquivo:linha no repositório nesta data. Esforço em horas de trabalho, com testes e documentação. "Regra" é o critério real de cada bônus, como o usuário o passou.

Legenda: **Sim** = cumpre a regra hoje; **Parcial** = existe, mas falta algo que a regra exige; **Não** = não existe.

## Bônus de tecnologia

| Bônus | Regra | Estado | Evidência | O que falta | Esforço |
|---|---|---|---|---|---|
| Docker | Projeto sobe por Docker | **Sim** | `Dockerfile:3-4` (imagem 154 como base), `Dockerfile:23` (marcador `.install-complete`), `compose.yaml:14-16` (porta 52774), `compose.aihub.yaml:2`; instalação limpa só pelo README medida na T12 (`docs/PROGRESS.md`, seção T12) | Nada | 0 |
| Implantação ZPM | Pacote publicado e instalável por `zpm install` | **Parcial** (T20: pronto, falta publicar) | Um módulo só (`module.xml`), sem classes de teste no pacote, AI Hub compilado só onde há `%AI`, interoperabilidade habilitada antes da compilação (`preload/cls/MyOwn/Bootstrap.cls`); install, package, uninstall com a produção rodando e reinstall testados na 154 (`docs/PROGRESS.md`, T20). O registro tem 1.0.3 | Publicar 1.1.0 pelo Open Exchange (`docs/PUBLISH-CHECKLIST.md`) | 1 |
| Demo online | URL pública funcionando | **Parcial** | Modo demo pronto e testado: `compose.yaml:26-27` (`MYOWN_DEMO_MODE`), `docker/demo-start.sh`, `scripts/Test-AgentDemo.ps1` 16/16 (T11); replay de decisões reais (`README.md:138`). URL ainda é TODO: `README.md:11`, `README.md:185` | Servidor com a imagem 154 carregada localmente (a imagem não pode ir a registro público, então o build é feito no próprio servidor), `MYOWN_AI_MODE=replay`, `MYOWN_DEMO_MODE=1`, HTTPS, senha do demo só no `.env` do servidor, reset agendado; atualizar o README | 4–8 (mais custo de hospedagem) |
| Adaptador personalizado | Adaptador próprio usado na produção | **Sim** (T16) | `src/objectscript/MyOwn/Production/Adapter/TaskHistoryInbound.cls` e `LogEntriesInbound.cls` (derivados de `Ens.InboundAdapter`), usados pelos itens `TaskWatcher` e `LogWatcher` da produção (`Production/Main.cls:12-22`, com as configurações dos adaptadores); `Production/Service/TaskWatcher.cls:4`, `LogWatcher.cls:4` | Nada; teste `scripts/Test-Adapters.ps1` (AD-01..07 e o ponta a ponta AD-E2E) | 0 |
| Python embarcado | Usado de fato na aplicação | **Sim** | `src/objectscript/MyOwn/Service/HealthAnalysis.cls:49` (`AnalyzeWithPython`, score de saúde) e `:176` (`DetectAnomaliesWithPython`, z-score); `src/objectscript/MyOwn/Service/System.cls:62` (`GetDiskUsage`) e `:75` (`GetPhysicalMemoryKB`). Caminho real: Overview (`REST.cls:184`), tarefa de snapshot (`Task/HealthSnapshot.cls:15`) e a produção (`HealthMonitor` → `Agent/Context/Health.cls:6` → `GetReport`, `HealthAnalysis.cls:19,163`) | Deixar explícito no README onde roda (0,5 h) | 0,5 |
| Busca vetorial | Usada de fato | **Sim** | `src/objectscript/MyOwn/HealthPattern.cls:14` (`%Vector(DOUBLE,6)`), `HealthAnalysis.cls:87` (`VECTOR_COSINE(... TO_VECTOR(?, DOUBLE))`), padrões gravados em `Installer.cls:209`; entra no contexto do agente pelo mesmo `GetReport` | Deixar explícito no README (0,5 h) | 0,5 |
| PEX | Componente de produção em Java ou .NET (Python não conta) | **Descartado** | Nenhuma referência a `EnsLib.PEX` em `src/` ou `aihub/` (busca em 2026-10-27) | Não será feito: exigiria um gateway Java ou .NET no container, fora do escopo do projeto | — |
| Motor de fluxo de trabalho | `EnsLib.Workflow` distribuindo tarefas entre usuários dentro da produção | **Não** | Nenhum uso de `EnsLib.Workflow`. A confirmação humana hoje é REST: `REST.cls:51-52`, `Agent/Service/Agent.cls:801` (`ConfirmProposal`), `:773` (`RejectProposal`), separação de funções em `:845`; a proposta é gravada pelo BO `Production/Operation/ProposalStore.cls:18` | Ver "Workflow: avaliação" abaixo | 8–12 |

### Adaptador personalizado: feito na T16 (2026-10-27)

- `TaskHistoryInbound`: o `OnTask` faz a varredura que antes estava no `OnProcessInput` do `TaskWatcher`, com a mesma consulta (`TOP 200` de `%SYS_Task.History`, mais nova primeiro), a mesma contagem de falhas seguidas (Status diferente de 1) e o mesmo filtro de namespace. Ele entrega ao serviço um `TaskState` por tarefa que passou do limite ou que está suspensa com o último run ok. Configurações na produção: `TaskNamespace`, `HistoryRows` (janela) e `FailureThreshold`; o `CallInterval` continua 120 s.
- `LogEntriesInbound`: chama `Agent.Context.Logs.Recent(MinSeverity, MaxEntries)` (2 e 10, como antes) e entrega um `LogBatch` quando há entradas.
- São dois adaptadores, e não um só, porque as fontes não têm nada em comum (histórico de tarefas por SQL e log do sistema por `MyOwn.Service.Logs`). Um adaptador único precisaria de uma configuração "classe da fonte", que esconderia a consulta e as configurações de cada serviço atrás de um nome de classe.
- Diferenças de comportamento: uma falha de consulta agora vai para o Event Log e o adaptador volta `$$$OK` (antes, o erro voltava pelo `OnProcessInput`; nos dois casos o serviço continua rodando). E o `ProcessInput` só é chamado quando há algo a entregar.
- O cursor (último `ID` lido) não foi feito, para não mudar o comportamento.

### Workflow: avaliação (sem implementar)

- **Pode representar a distribuição, não a execução.** O `EnsLib.Workflow` entrega um `TaskRequest` a um papel de workflow e os usuários do papel o veem na caixa de tarefas. Isso cobre "distribuir tarefas entre usuários dentro da produção".
- **A execução não pode passar para ele.** A resposta do workflow (`TaskResponse`) é processada no job da produção, com a conta de serviço. A regra do projeto exige que o humano execute com as próprias credenciais e que a confirmação revalide tudo (estado, expiração, separação de funções, alvo proibido, `TARGET_CHANGED`, permissão ao vivo, leitura de volta; `Agent.cls:815` em diante).
- **Desenho viável:**
  1. O `ProposalStore` grava a proposta, como hoje, e envia um `TaskRequest` para uma operação de workflow (papel `MyOwnApprovers`), com um handler que não atribui a tarefa a quem pediu.
  2. O administrador abre a proposta no portal e confirma pela rota REST atual, com as credenciais dele.
  3. O portal fecha a tarefa de workflow com o resultado: confirmada, rejeitada ou expirada.
  4. Recusar pela caixa do workflow equivale a `RejectProposal`. Confirmar pela caixa só leva ao portal.
- **Riscos:** dois estados para manter sincronizados (proposta e tarefa de workflow); a caixa de tarefas é outra tela do Management Portal; expiração e lock (`PROPOSAL_BUSY`) precisam valer nos dois lados.

## Candidatos a bug no AI Hub (build 154, sem chave de API)

Reproduzidos em 2026-10-27, salvo indicação. Servidor falso: um servidor HTTP local no container (Python da imagem, porta 18080) que imita `POST /v1/chat/completions` e grava hora e caminho de cada requisição. Provider: `%AI.Provider.Create("openai", {"api_key": "dummy", "base_url": "http://127.0.0.1:18080/<modo>/v1"})`, agente `%AI.Agent` com `Model = "m"`, `%Init()` e `CreateSession({"timeout_ms": 3000, "max_iterations": 1})`.

| # | Comportamento | Passos mínimos | Observado | O que a documentação da classe diz | Estado |
|---|---|---|---|---|---|
| B1 | Retry silencioso de 429 e 503 | Servidor responde sempre 503 (e depois sempre 429); `Chat(session, "hi")` | 4 requisições por chamada (1 + 3 retries, esperas de cerca de 0,5, 1 e 2 s); erro só no fim (`ProviderError ... overloaded` / `rate limited`), em 3,5 a 3,8 s. Nenhum aviso ao chamador sobre os retries; com o Gemini real, isso fez um 429 de cota parecer lentidão (T04, 27,7 s) | Os comentários de `Chat` e de `CreateSession` não mencionam retry; nenhuma chave de sessão controla isso (a lista de chaves aceitas está em `docs/AI-HUB-NOTES.md`, T04) | Reproduzido |
| B2 | `timeout_ms` não corta uma requisição lenta | Servidor demora 20 s para responder 200; `timeout_ms` 3000 | `Chat` volta com sucesso depois de 20,1 s | `timeout_ms` é descrito como limite do loop agêntico inteiro (`docs/AI-HUB-NOTES.md`, seção c); na prática só é checado entre iterações. O portal contorna com um worker `JOB` e prazo próprio (`aihub/src/MyOwn/AIHub/Engine.cls`) | Reproduzido |
| B3 | `AddTool` sem prefixo dá "erro interno" | `##class(%AI.ToolMgr).%New().AddTool("Pkg.MinhaTool")` | `%Status` com `<%AICore>InternalError: Internal AI-Core error: Failed to add tool spec ...: Invalid URI format: URI must contain scheme or default scheme must be set`. Com `"iris:Pkg.MinhaTool"` funciona | O comentário de `AddTool` lista as formas com esquema (`iris:`, `rust:`, `mcp:`) ou um objeto; erro de entrada do usuário classificado como erro interno | Reproduzido (T13) |
| B4 | Class query sem `[ SqlProc ]` é registrada e só falha ao executar, com bytes binários na mensagem | Tool com `Query Q() As %SQLQuery { SELECT 1 }` sem `SqlProc`; `AddTool("iris:...")`; `ExecuteTool("Q", {})` | O registro aceita; a execução dá `ToolExecutionFailed ... 5540 ... Stored Procedure '..._Q' not found`, com bytes de um `%Status` serializado no texto (`? \u0004\u0005T...`) | Nada sobre a exigência de `SqlProc`; esperado: erro na compilação ou no registro, e texto legível | Reproduzido (T13) |
| B5 | Métodos de uma `%Query` própria viram tools | Tool com `Query Q() As %Query(...) [ SqlProc ]` e `QExecute`/`QFetch`/`QClose` públicos; `%Discover()` | Lista `Q QClose QExecute QFetch`; com `[ Internal ]` nos três, só `Q` | A descoberta pega todo método público que não seja `Internal`; os métodos de implementação de uma query deveriam ficar de fora | Reproduzido |
| B6 | ToolSet exige `DependsOn` na classe incluída | ToolSet com `<Include Class="X"/>` compilado no mesmo lote que `X`, sem `DependsOn` | O gerador do ToolSet falha com `CLASS DOES NOT EXIST` | Nada sobre a ordem de compilação | Visto na T04; não reproduzido de novo hoje |
| B7 | Tool escondida por `%CanList` não gera auditoria | Política de autorização com `%CanList` devolvendo 0 para uma tool; `ExecuteTool` nela | `ToolNotFound`, sem `%LogDenial` (uma tool listada e negada chama `%LogDenial`) | Pode ser intencional; para auditoria, uma tentativa de chamar uma tool escondida some sem rastro | Visto na T04 |
| B8 | Configuração aceita qualquer coisa | `CreateSession({"response_format": 123})`; provider `gemini` com `http_config`/`extra_config` contendo chaves inventadas | Aceito sem erro na criação | Sem validação documentada | Visto na T04 (fraco) |

Ficaram fora por exigir chave ou provider real: o `generationConfig` recusado pelo Gemini quando vai em `extra_params` (T04), e o 503 "high demand" que só aparece com o trace ligado (2026-10-26). O servidor falso foi removido do container depois do teste; nenhuma classe temporária ficou no namespace.

## Extra: ideia do Ideas Portal (T24, 2026-10-28)

| Ideia | Estado | Evidência |
|---|---|---|
| [DPI-I-767](https://ideas.intersystems.com/ideas/DPI-I-767) "Automatically Expose Interactive API Documentation" | **Implementada no portal** | `src/objectscript/MyOwn/REST/Docs.cls` (classe base: `/openapi.json` em OpenAPI 3.0, com o spec montado a cada requisição a partir da classe compilada, sem teste de recompilação; e `/docs`, um visualizador interativo próprio, não o Swagger UI, sem CDN), aplicada a `MyOwn.REST`; `scripts/Test-ApiDocs.ps1`. Lê o `UrlMap` e os comentários do dicionário compilado do IRIS; o gerador nativo (`%REST.API.GetWebRESTApplication`, Swagger 2.0) foi avaliado e não serve para um usuário só leitura nem tem página interativa |

## Resumo de esforço

| Prioridade sugerida | Item | Horas |
|---|---|---|
| 1 | ZPM: publicar 1.1.0 pelo Open Exchange (o resto foi feito na T20) | 1 |
| ~~2~~ | ~~Adaptador personalizado (TaskWatcher e LogWatcher)~~ (feito na T16) | 0 |
| 3 | Demo online em replay | 4–8 |
| 4 | Workflow só para distribuir a revisão, mantendo a confirmação no portal | 8–12 |
| — | ~~README: deixar explícitos Python embarcado e busca vetorial~~ (feito na T15, seção "Technologies used") | 0 |
| — | Bugs do AI Hub: relatos de B1 a B3 escritos em `docs/ai-hub-bugs`, ainda não enviados; B4 e B5 ainda sem relato | 0,5–1 |
