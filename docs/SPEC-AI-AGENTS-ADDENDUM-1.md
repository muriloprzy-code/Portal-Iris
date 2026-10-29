# Adendo 1 à SPEC-AI-AGENTS.md — respostas oficiais da organização (16/10/2026)

> **Este adendo SOBREPÕE** as seções citadas de `docs/SPEC-AI-AGENTS.md`. Em caso de conflito, vale este documento.
> Fonte: resposta de organizadores do concurso no thread da Dev Community (perguntas sobre imagem, licença e demo).

## A. O que ficou decidido (fatos fornecidos pela organização)

| Tema | Resposta oficial |
|---|---|
| Imagem | Usar a **build 154** do AI Hub (Early Access). Imagens aceitas: `iris-community-2026.3.0AI.154.0-docker.tar.gz` (x64) / `iris_arm64-community-...` (ARM64) e `irishealth-community-2026.3.0AI.154.0-docker.tar.gz` (x64) / `irishealth_arm64-community-...` (ARM64). **IRIS e IRIS for Health são ambos aceitos.** |
| Docker no README | O README pode mandar o avaliador **baixar a imagem do portal EAP e carregá-la**. A imagem carregada tem nome interno longo → **re-etiquetar** para nome local curto e usar esse nome no `Dockerfile`/`compose`. |
| Proibido | **Não** publicar a imagem do AI Hub, nem imagem construída sobre ela, em Docker Hub ou qualquer registro público. Compartilhar apenas `Dockerfile` e `docker-compose.yml`; os avaliadores constroem a partir deles. |
| Licença | **Pode** usar a build 154 para **desenvolver**, **gravar o vídeo** e **fazer demo pública online**. |
| Chaves/LLM | Sem créditos para participantes: usar **chave própria**; **não** colocar no repositório; ler de `.env` ou variável de ambiente. **Os avaliadores usam as chaves deles.** AI Hub suporta oficialmente: OpenAI, Anthropic, Gemini, Amazon Bedrock. **Experimentais:** Vertex AI, Meta, NVIDIA NIM, xAI, DeepSeek, Kimi, OpenRouter, **Ollama**. |
| Template | `ai-hub-dev-template` é da comunidade (não oficial), ainda aponta versão antiga; até atualizarem, trocar o nome da imagem na **linha 1 do Dockerfile**. |
| Dados sintéticos | Permitidos. |
| Ideia do Ideas Portal | Opcional implementar e linkar no README (já temos DPI-I-512 do AI Instance Monitor; pode ser linkada como base). |
| Bônus de tecnologia | Serão anunciados **após o início** do concurso; **não** vinculados a recursos específicos do AI Hub. |
| Preparar antes de 26/10 | **Permitido** começar agora. |

## B. Alterações na especificação

### B.1 Riscos (§19)
- **R2 — RESOLVIDO.** Remover a restrição "sem demo pública com AI Hub". Demo pública é permitida.
- **R6 — RESOLVIDO.** Trabalho anterior a 26/10 é permitido. Ainda assim, publicar a release `1.1.0` dentro da janela do concurso.
- **R8 — AUMENTA.** A build alvo agora é **2026.3** (a SysAdmin API v2 foi validada em 2026.2). Rodar `Test-MyOwn.ps1` e `Test-SysAdminMutations.ps1` na imagem 154 **já na T01**, nas duas edições (IRIS e IRIS for Health).
- **NOVO R13 — abuso de chave na demo pública.** Uma demo pública com a chave do autor pode gerar custo. Mitigações obrigatórias: chave com **limite de gasto no provedor**; `DailyTokenBudget` baixo; rate limit por IP/usuário; contas de demo somente com `simulate` e sem mutações reais fora do namespace de demo; kill switch acessível; após o orçamento, a engine cai para `Rules` (a demo continua funcionando).
- **NOVO R14 — imagem EAP no servidor da demo.** Carregar o `.tar.gz` no servidor manualmente (`docker image load`), **sem** `docker push` para registro público.

### B.2 Docker e empacotamento (§4.3, §13.2, §13.3)
- **O alvo principal passa a ser a imagem 154**, e os testes devem rodar nas **duas** edições. Nomes locais padronizados:
  - `iris-community:2026.3.0AI.154.0`
  - `irishealth-community:2026.3.0AI.154.0`
- `Dockerfile`: `ARG IMAGE=irishealth-community:2026.3.0AI.154.0` (e documentar a variante IRIS). `compose.yaml` lê `IRIS_IMAGE` do `.env`. **Nada de `docker push`.**
- Comandos de carga/re-etiquetagem (para o README e para o script de apoio):

```text
docker image load -i irishealth-community-2026.3.0AI.154.0-docker.tar.gz
docker images
docker tag <loaded-image-name> irishealth-community:2026.3.0AI.154.0
```
  (para IRIS: usar `iris-community-...` e a tag `iris-community:2026.3.0AI.154.0`).
- **Divisão em dois módulos IPM: mantida, mas deixa de ser crítica.** Como a imagem alvo sempre tem `%AI.*`, é aceitável **unificar em um módulo** se o prazo apertar. Se mantiver a divisão, o núcleo continua compilando na imagem 2026.2 padrão (caminho do Open Exchange atual) e o gateway continua com dispatch dinâmico e fallback `Rules`.
- Porta: manter `IRIS_WEB_PORT` configurável (padrão do Meu Portal 52774; usar porta livre se houver IRIS local em 52773).
- Chave: `MYOWN_AI_API_KEY` (valor lido do ambiente/`.env`), `MYOWN_AI_PROVIDER` e `MYOWN_AI_MODEL`. `.env.example` sem valores reais; `.env` no `.gitignore` (já está).

### B.3 Provedor padrão (§7.2)
- O README deve declarar **um provedor esperado** e a **variável da chave**. Escolher entre os **oficiais** (OpenAI, Anthropic, Gemini, Bedrock). **Ollama é experimental** → só como opção documentada, nunca como padrão.
- Decisão a registrar em `docs/AI-HUB-NOTES.md` (responsável: o autor do projeto): provedor padrão e modelo padrão.
- Sem chave, o app sobe e funciona com a engine `Rules` (o avaliador sempre vê algo funcionando).

### B.4 README — conteúdo obrigatório adicional (§16.1)
Acrescentar uma seção **"Run the AI Hub build"** com, exatamente:
1. imagem e versão EAP usadas (`2026.3.0AI.154.0`, IRIS e/ou IRIS for Health);
2. passos de **carga e re-etiquetagem** da imagem (acima), com o link do portal EAP;
3. **provedor LLM** esperado e **variável de ambiente** da chave;
4. **comandos para iniciar** o app;
5. **comandos para verificar** que funciona (ex.: `GET /myown/api/health`, `GET /myown/api/agent/status`, `scripts/Test-Agents.ps1`);
6. aviso: "Do not push the AI Hub image or images built on it to a public registry."
- Remover do §16.1 a frase sobre "sem demo pública até esclarecimento".
- Link opcional para a ideia do Ideas Portal (DPI-I-512).

### B.5 Testes (§15)
- Matriz IT-*/AH-*/SEC-* executa em **ambas** as imagens (IRIS e IRIS for Health 154); o relatório JSON (§15.6) registra `iris.image` e a edição.
- Acrescentar **IT-16**: instalação limpa seguindo **somente** o README (load → tag → compose up → verify) numa máquina/pasta limpa.
- Acrescentar **SEC-11**: varredura de segredos também em `docker-compose.yml`, `Dockerfile`, `.env.example` e histórico git recente.
- Acrescentar **IT-17**: demo pública (se publicada): budget cap e rate limit funcionam; ao esgotar, cai para `Rules`.

### B.6 Backlog (§17)
- **T01** passa a incluir: carregar e etiquetar **as duas** imagens 154; rodar os testes existentes de regressão (R8).
- **T21** passa a incluir: `Dockerfile`/`compose` parametrizados pela imagem local; instruções de carga no README.
- **NOVO T29 (S, M):** demo pública online (servidor próprio, imagem carregada manualmente, HTTPS, limites do R13, `DemoMode=1`).
- **NOVO T30 (M, P):** em **26/10**, ler o anúncio dos **bônus de tecnologia** e reavaliar o backlog (bônus não estarão ligados a recursos do AI Hub).
- **NOVO T31 (S, P):** ajustar o nome da imagem se o `ai-hub-dev-template` for atualizado para a 154; usar o template apenas como referência.

### B.7 Cronograma (§18)
Sem mudança de datas. O preparo pode seguir já. A janela 14–25/10 é válida para T01–T11 (a Fase A, que não depende do AI Hub). Nesse mesmo período, **T01 deve ser a primeira tarefa** (imagens 154 + regressão), pois decide o R8.
