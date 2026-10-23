# Readest próprio

Fork do [readest/readest](https://github.com/readest/readest) (AGPL-3.0) para uso pessoal:
app Android `com.matheus.readest` falando com um servidor Readest self-hosted no VPS,
com o Calibre-Web como fonte dos livros e o kosync como **única** referência de posição.

- Ramo de trabalho: **`proprio`**, criado a partir da tag `v0.12.16`.
- Servidor e infraestrutura: repositório **[TheusSales/reading-stack](https://github.com/TheusSales/reading-stack)** (pasta `readest/`).

## Como as peças se encaixam

| | Livros | Posição | Estatísticas |
|---|---|---|---|
| Celular (S25, este app) | OPDS do Calibre-Web | kosync | servidor Readest |
| Kindle (KOReader) | OPDS do Calibre-Web | kosync | `readest.koplugin` deste fork |
| Xteink X4 (firmware CrossInk) | OPDS do Calibre-Web | kosync (HTTP puro) | nenhuma |
| PC | envio pelo Calibre-Web | | |

URLs (todas atrás do Caddy do pulso-bot no VPS `vps-reading`):

- Livros / OPDS: `https://books.pulsobot.duckdns.org/opds`
- kosync: `https://sync.pulsobot.duckdns.org` (o X4 usa `http://`)
- Servidor Readest: `https://readest.pulsobot.duckdns.org`, origem única para
  `/auth/v1` e `/rest/v1` (Kong), `/readest-files/` (MinIO) e o resto (cliente Next.js)

## O que mudou em relação ao upstream

Veja `git log v0.12.16..proprio`. Em resumo:

1. **Build próprio** (`apps/readest-app/.env.proprio`, `apps/readest-app/scripts/build-proprio.sh`):
   `NEXT_PUBLIC_SELF_HOSTED=true` (chave oficial do upstream que libera todas as funções
   premium), URLs e chave anônima do servidor, sem PostHog e sem Sentry.
   `applicationId` = `com.matheus.readest`. O namespace Kotlin continua `com.bilingify.readest`.
2. **Tela da conta** (`src/utils/access.ts`, `SettingsMenu.tsx`): as cotas fixas
   da build (`NEXT_PUBLIC_*_FIXED_QUOTA`) passam a valer no cliente, e o menu deixa de
   oferecer "Atualizar para Premium" quando a build é self-hosted. O selo "Plano gratuito"
   na página da conta é só visual.
3. **`apps/readest.koplugin`**: os padrões apontam para o servidor próprio, e há o modo
   **só estatísticas** (`auto_sync_stats`, ligado por padrão). Ao fechar o livro, ele envia
   apenas estatísticas, sem posição, configuração ou anotações. Opção no menu:
   "Auto sync reading stats only".

## Compilar o APK em outro computador

Pré-requisitos (versões usadas em 22/10/2026):

- Node 24 e pnpm 11.1.1 (`corepack enable pnpm`)
- Rust 1.97 com o alvo `aarch64-linux-android` (`rustup target add aarch64-linux-android`)
- JDK 21, Android SDK e NDK `28.2.13676358`
- **Chave de assinatura**: `~/.android/readest-release.jks` e `~/.android/readest-release.properties`
  (`keyAlias`, `password`, `storeFile`). **Ela não está no GitHub.** Traga do computador
  antigo. Sem ela, o APK sai com outra assinatura e o Android não atualiza o app instalado
  (seria preciso desinstalar e perder os dados locais).

```bash
git clone -b proprio https://github.com/TheusSales/readest.git && cd readest
git submodule update --init --depth 1 packages/foliate-js packages/tauri packages/simplecc-wasm \
  packages/qcms packages/js-mdict apps/readest-app/src-tauri/plugins/tauri-plugin-turso \
  apps/readest-app/src-tauri/plugins/tauri-plugin-webview-upgrade
pnpm install --frozen-lockfile
pnpm --filter @readest/readest-app setup-vendors

cd apps/readest-app
# ajuste JAVA_HOME / ANDROID_HOME / ADB no topo do script, se os caminhos forem outros
ADB_SERIAL=<ip:porta do celular> scripts/build-proprio.sh --install
```

A primeira compilação leva uns 15 minutos (Rust); as seguintes, poucos minutos.
Os testes do upstream continuam valendo: `pnpm test`, `pnpm lint` e, para o plugin,
`pnpm test:lua` (LuaJIT + busted).

### Plugin do KOReader

Empacote como o CI (`.github/workflows/release.yml`, passo do koplugin): copie
`apps/readest.koplugin` **sem** `scripts/`, `docs/`, `spec/`, `.busted` e `native/`,
acrescente `version = "<versão>",` ao `_meta.lua` e coloque em
`koreader/plugins/readest.koplugin` no Kindle. No Kindle, o armazenamento USB só aparece
com o KOReader **fechado**. **Não use "atualizar plugin"** no menu Readest do KOReader:
ele baixa a versão oficial por cima da modificada.

## Estado em 22/10/2026

Feito:

- [x] Fork, APK próprio assinado e instalado no S25. O Readest oficial foi removido.
- [x] Servidor Readest no VPS (`reading-stack/readest`), com conta criada e cadastro fechado (`DISABLE_SIGNUP=true`).
- [x] App configurado: OPDS "Calibre", kosync (`matheus`, método "Conteúdo do arquivo",
      estratégia "Perguntar em caso de conflito", aparelho "S25") e categoria
      "Progresso de leitura" desligada em Gerenciar Sincronização.
      Download automático do OPDS desligado.
- [x] Teste de ida e volta da posição: Kindle → celular (51,9% caiu no mesmo ponto) e
      celular → kosync (xpointer no formato do KOReader).
- [x] Plugin no Kindle com login feito. 11 livros e 2.647 registros de estatística no servidor.

Falta:

- [ ] **OPDS do celular usa a conta `admin`** do Calibre-Web. Trocar para `user-odps`
      quando a senha dela for encontrada (a senha testada foi recusada), ou redefinir essa
      senha e atualizar também no X4 e no KOReader.
- [ ] **Nome no lançador**: ainda aparece "Readest", igual ao oficial.
- [ ] **Releases para o Obtainium**, como no xm6: `versionCode` crescente e
      `gh release create` com o APK assinado.
- [ ] **Estatísticas do X4**: o CrossInk não roda o plugin CrossPoint do Readest.
      Investigar se ele grava algum registro de leitura no SD que dê para importar.
- [ ] Testar a posição saindo do celular para o X4 e para o Kindle (até agora só foi
      verificada no servidor).
- [ ] Atualizar o upstream: `git fetch upstream --tags`, rebase do `proprio` na nova tag,
      e atualizar a tag da imagem e `volumes/` em `reading-stack/readest` (ver o README de lá).

## Armadilhas já encontradas

- **MinIO**: as imagens oficiais deixaram de ser publicadas. O servidor usa `pgsty/minio`.
- **Imagem do cliente**: a tag no ghcr é `0.12.16`, sem o `v`.
- **Caddy do pulso-bot**: recompile com `docker compose up -d --no-deps frontend`.
  Sem `--no-deps`, o compose recria api, db e redis do pulso-bot (cerca de 30 s fora do ar).
- **Hook de pre-push** do upstream (format, lint e testes): se uma execução instável
  falhar, rode `pnpm test` à mão e use `git push --no-verify`.
- **adb pelo WSL**: use o `adb.exe` do Windows (o do WSL trava). Se o celular aparecer duas
  vezes (IP e mDNS), passe `ADB_SERIAL`.
- **Automação por adb**: confira se o app está em primeiro plano antes de cada toque.
  Notificações e o Bitwarden roubam o foco no meio do caminho.
- **Hash do kosync**: o livro só compartilha posição se for o mesmo arquivo nos dois
  aparelhos. Baixe sempre pelo OPDS. `reading-stack/tools/kosync-scan.py` lista quais
  livros da biblioteca têm posição no kosync.
