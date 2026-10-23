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
   Nome no lançador: **Readest+**, em `src-tauri/gen/android/app/src/release/res/values/strings.xml`
   (o source set release sobrepõe o `strings.xml` gerado pelo `tauri android init`).
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

### Publicar uma release (Obtainium)

O celular atualiza pelo Obtainium a partir das releases deste fork.

1. Em `apps/readest-app/src-tauri/gen/android/app/build.gradle.kts`, incremente
   `proprioBuild`. Volte a `1` quando trocar de versão do upstream.
   `versionCode` = código do upstream × 100 + `proprioBuild`; `versionName` = `<versão>-p<build>`.
2. Rode `scripts/build-proprio.sh` e confirme com
   `aapt2 dump badging <apk> | head -1` (pacote, `versionCode` e `versionName`).
3. `gh release create v<versão>-p<build> <apk renomeado> -R TheusSales/readest --target proprio`.
   A tag precisa ser igual ao `versionName` com `v` na frente, para o Obtainium casar a versão.

No Obtainium, adicione o app pela URL do fork, `https://github.com/TheusSales/readest`,
e não pela do upstream: só o fork tem os APKs `com.matheus.readest` com esta assinatura.

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
- [x] Releases no fork para o Obtainium (primeira: `v0.12.16-p1`).
- [x] Servidor Readest no VPS (`reading-stack/readest`), com conta criada e cadastro fechado (`DISABLE_SIGNUP=true`).
- [x] App configurado: OPDS "Calibre", kosync (`matheus`, método "Conteúdo do arquivo",
      estratégia "Perguntar em caso de conflito", aparelho "S25") e categoria
      "Progresso de leitura" desligada em Gerenciar Sincronização.
      Download automático do OPDS desligado.
- [x] Teste de ida e volta da posição: Kindle → celular (51,9% caiu no mesmo ponto) e
      celular → kosync (xpointer no formato do KOReader).
- [x] Plugin no Kindle com login feito. 11 livros e 2.647 registros de estatística no servidor.

Falta:

- [ ] **OPDS nos aparelhos com a conta `user-odps`**: a senha foi redefinida em 23/10/2026
      (OPDS responde 200) e a do `admin` já não é a padrão. Falta trocar no celular
      (hoje usa `admin`), no X4 e no KOReader. Opcional: deixar o `user-odps` só com
      `download` e `viewer`.
- [ ] **Nome no lançador**: "Readest+" já está no código; falta compilar, publicar a release
      (incrementar `proprioBuild`) e conferir no S25.
- [ ] **Estatísticas do X4**: ponte `reading-stack/x4-stats` pronta (no GitHub, ainda sem
      deploy). O CrossInk só guarda totais (`/.crosspoint/global_stats.bin`, `stats_v5.bin`
      por livro e contadores diários em `/.crosspoint/daily_reading`) e os envia por
      `/api/v1/stats/*` ao servidor do KOReader Sync **só no ramo `development`** (a v1.6.1
      não envia). Falta: deploy (Caddy + `link`), firmware `development` no X4 e um teste.
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
- **Senha de usuário do Calibre-Web pela linha de comando** (sem reiniciar):
  `docker exec reading-calibre-web /lsiopy/bin/python3 /app/calibre-web/cps.py -p /config/app.db -s 'usuario:senha'`.
- **Hash do kosync**: o livro só compartilha posição se for o mesmo arquivo nos dois
  aparelhos. Baixe sempre pelo OPDS. `reading-stack/tools/kosync-scan.py` lista quais
  livros da biblioteca têm posição no kosync.
