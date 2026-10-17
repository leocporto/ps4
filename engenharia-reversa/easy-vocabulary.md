# Engenharia reversa: easy-vocabulary.com

Análise feita a partir de um arquivo HAR capturado no navegador em 17/10/2026. O HAR tem 122 requisições: a página `game/writing.html` (jogo "Writing"), seus scripts, CSS, imagens e dados.

**Limites desta análise**
- Só uma página foi capturada (o jogo de escrita). Os outros ~35 jogos e páginas aparecem só como links no menu. A estrutura deles foi deduzida, não lida.
- Nenhum arquivo de áudio (`.mp3`) foi capturado. O HAR não fez nenhuma chamada ao servidor (Supabase), porque o usuário não estava logado. O formato do backend vem só da leitura do código.
- Não testei o backend nem a segurança dele.
- Este documento descreve a arquitetura com minhas palavras. Não copia o conteúdo do site (histórias, frases, imagens, áudios) nem o código dele.

---

## 1. Resumo em uma frase

É um **site estático em JavaScript puro (sem framework e sem build)**, servido pelo **Cloudflare**. Todo o conteúdo fica em **arquivos `.js` com variáveis globais**, o progresso fica no **`localStorage`** e, opcionalmente, é **sincronizado com o Supabase** (login por código no e-mail). Também funciona como **PWA** instalável.

---

## 2. Stack técnica

| Camada | O que usam | Evidência |
|---|---|---|
| Hospedagem/CDN | Cloudflare (cache, HTTP/3, compressão zstd) | headers `server: cloudflare`, `cf-cache-status: HIT`, `alt-svc: h3` |
| Frontend | HTML + CSS + JavaScript ES5 puro, cada página em um `.html` separado | `<script src>` em sequência, sem bundler, sem React/Vue |
| Módulos | Padrão IIFE `(function(){ ... })()` com objetos globais (`FORTSCHRITT`, `PFAD`, `TASTENTON`...) | todos os `.js` em `game/` |
| Dados | Arquivos `.js` que declaram variáveis globais (`var LESEN_TEXTE = [...]`) | `daten/*.js` |
| Estado | `localStorage` com chaves prefixadas `ev_` e `ddd_` | `fortschritt.js`, `einstellungen.js` |
| Backend | Supabase (Auth + PostgREST), acessado com `fetch` direto, sem o SDK | `konto.js`, `konto-einstellung.js` |
| Áudio | `<audio>`/`new Audio()` para as vozes em MP3; Web Audio API para os sons gerados (teclas, comemoração) | `tastenton.js`, jogo de escrita |
| PWA | `manifest.webmanifest`, `beforeinstallprompt`, modo `standalone` | `installieren.js` |
| Analytics | Nenhum encontrado nesta página (sem Google Analytics, Plausible etc.) | nenhuma requisição de terceiros no HAR |

**Curiosidade:** o código usa nomes em **alemão** (`fortschritt` = progresso, `konto` = conta, `einstellungen` = configurações, `seitenleiste` = barra lateral, `daten` = dados, `bilder` = imagens, `ton` = som, `mutter` = língua materna). O autor provavelmente fala alemão, e a primeira língua planejada além do inglês é o alemão (`DE_KAPITEL`).

Também há cabeçalhos de segurança: HSTS, `X-Frame-Options: SAMEORIGIN`, `nosniff` e `Permissions-Policy` bloqueando câmera, microfone e localização. A página do jogo tem `noindex, nofollow`, então só as páginas de entrada aparecem no Google.

---

## 3. Estrutura de pastas (deduzida das URLs)

```
/                      index.html, account.html, legal.html, manifest.webmanifest, favicon.svg, teilen.png (imagem de compartilhamento)
/app/                  ícones do PWA e /app/js/<hash>.js (o motor de cada jogo, com nome em hash)
/game/                 uma página .html por jogo + módulos .js e .css compartilhados + bandeiras .svg
/daten/                dados de conteúdo em .js (histórias, listas de palavras, frases, mapa de áudio)
/daten/kapitel/        arquivos de capítulo carregados sob demanda (erros de carga aqui são ignorados)
/bilder/               imagens das palavras:  wNNNN-<nome-em-alemão>.png
/bilder/buttons/menu/  ícones dos jogos (.webp)
/bilder/background/    fundos (.webp)
/ton/en/writing/<id>/zNN.mp3   áudio de cada frase das histórias
/ton/effekte/          efeitos sonoros engraçados (som de erro)
```

**Convenção de IDs:** as palavras têm IDs como `w0001`, `w0286` (com imagem) e `e12813` (frases/entradas de vocabulário). O nome da imagem junta o ID e a palavra em alemão (`w0307-hund.png` = cachorro), o que sugere que o banco de palavras foi montado primeiro em alemão.

---

## 4. Páginas e jogos (mapa do produto)

Encontrados no menu lateral (`seitenleiste.js`) e nos ícones dos jogos:

**Jogos de vocabulário (por capítulo):** `play` (escolher a imagem certa, "pick"), `type` (digitar a palavra), `match` (ligar pares), `search` (caça-palavras), `recall` (lembrar), `sentence` (montar frase), `dictation` (ditado), `build` (montar a palavra)

**Prática com textos:** `writing` (copiar uma história linha por linha), `reading` (leitura), `shadowing` (ouvir e repetir), `quotes` / `quotes-play` (citações)

**Gramática e extras:** `tenses` (tempos verbais), `antonyms` (antônimos), `upgrade` (trocar por palavra mais avançada), `artikel` (artigos do alemão), `monster` (jogo com níveis fácil/médio/difícil), `for-fun`

**Revisão e progresso:** `spaced` (repetição espaçada / SRS), `easiest` (as 200 palavras mais fáceis, em rodadas de 10), `vocab-road` (trilha de capítulos), `statistics`, `level`

**Cursos e configuração:** `courses`, `course-*` (versões dos jogos para outras línguas), `language` (língua que você aprende), `native` (sua língua materna), `settings`, `account`

**Línguas:** só o **inglês** está ativo. Alemão, italiano, espanhol, polonês, francês, turco, russo, bósnio e árabe aparecem como "em breve". O português só aparece em ambiente local (`localhost`). Há cerca de 28 **línguas maternas** para traduções e interface (português incluído).

---

## 5. Como uma página funciona (ordem de carregamento)

1. **Script inline 1:** cria um aviso "parte da página não carregou" se algum `<script>` do próprio site falhar. Também corrige o parâmetro `?native=` da URL quando você volta pelo histórico.
2. **`mutter.js`:** define a língua materna (`ev_mutter`) e a lista de línguas maternas.
3. **Script inline 2:** aplica o tema claro/escuro salvo (`ev_theme`) antes de desenhar a página, para não piscar.
4. **Módulos de interface:** `installieren.js` (PWA), `language-flag.js`, `kopf-knoepfe.js` / `kopf-fest.js` (cabeçalho), `einstellungen.js` (configurações), `seitenleiste.js` (menu lateral).
5. **Dados:** `daten/*.js` definem variáveis globais com o conteúdo.
6. **Núcleo:** `languages.js` (regras por língua), `fortschritt.js` (progresso), `pfad.js` (trilha com estrelas), `tastenton.js` / `klick.js` / `falschzeichen.js` (sons e feedback de erro), `restart-game.js`.
7. **Motor do jogo:** `/app/js/<hash>.js`.
8. **Conta:** `konto-einstellung.js` (URL e chave pública do Supabase) + `konto.js` (login e sincronização).
9. **`bruh.js`:** com 90% de chance, toca um som engraçado ("bruh", "nope", "huh") em volume baixo quando você erra. Dá para desligar.

Parâmetros de URL usados em todo o site: `lang` (língua que aprende), `native` (língua materna), `chapter`, `text`, `visit`.

---

## 6. Modelo de dados do conteúdo

### História (jogos Writing / Reading)
```
{
  id:     string   // slug, ex.: "a-lost-key"
  stufe:  "A1" | "A2"         // nível CEFR
  titel:  string
  kurz:   string   // título curto
  bild:   string   // imagem de uma palavra do banco (wNNNN-*.png)
  zeichen?: string // emoji (só em parte dos textos)
  zeilen: string[] // uma frase por linha; "" = quebra de parágrafo; linha que começa com "*" = moral/frase final em destaque
}
```
As histórias vêm de três fontes (uma lista dentro do motor + `LESEN_TEXTE` + `LESEN_TEXTE_A2`). São juntadas sem duplicar e ordenadas: A1 primeiro, depois A2.

### Mapa de áudio (`WRITING_TON`)
```
{ "<id-da-história>": [1, 3, 4, 5, ...] }   // números das linhas que têm um MP3
```
O áudio fica em `/ton/en/writing/<id>/zNN.mp3`. Cada MP3 cobre uma frase que pode ocupar várias linhas. Para saber qual áudio toca na linha *n*, o código pega o primeiro número da lista que seja **≥ n**. Um número que falta na lista indica que aquela linha continua a frase da próxima.

### Configuração de cada língua (`SPRACHEN` e `KURS_DATEN`)
- `SPRACHEN`: `{ id, name, flagge, aktiv, bald, fertig: { <jogo>: [capítulos prontos] } }`
- `KURS_DATEN[lang]`: regras de digitação daquela língua. Inclui o alfabeto aceito, letras equivalentes (por exemplo, variações do alif no árabe), sinais a ignorar (diacríticos), direção `rtl`, prefixos que grudam na palavra, palavras a esconder (`ohne`), quais arquivos de palavras e frases carregar e se a língua tem `tenses` e `upgrade`.

---

## 7. Progresso (tudo no `localStorage`)

| Chave | Conteúdo |
|---|---|
| `ev_kapitel:<lang>:<jogo>:<capítulo>` | progresso de um capítulo/história (veja abaixo) |
| `ev_kapitel:<lang>:srs:<..>` | dados da repetição espaçada |
| `ev_kapitel:<lang>:stat:<data>:<..>` | estatísticas por dia (`{s, r, f}` por data) |
| `ev_kapitel:<lang>:shadow`, `...:monster:<nível>` | progresso de jogos específicos |
| `ev_srs_dazu:<lang>` | IDs de palavras já aprendidas que entram na revisão SRS (no máximo 3000) |
| `ev_schwer`, `ev_schwer_tenses` | palavras difíceis/marcadas |
| `ev_taeglich` | meta/sequência diária |
| `ev_lern`, `ev_mutter`, `ev_level` | língua que aprende, língua materna, nível |
| `ev_theme`, `ev_stil`, `ev_ruhig`, `ev_blass`, `ev_wiederholen`, `ev_ohne_download` | preferências (tema, estilo, menos animação, letras-guia, repetir, economia de dados) |
| `ddd_sound_enabled_v1`, `ddd_fun_sounds_v1` | som ligado, sons engraçados |
| `ev_konto_sitzung`, `ev_konto_abgleich` | sessão do Supabase e último estado sincronizado |

O prefixo `ddd_` é provavelmente de uma versão antiga do app.

**Formato do progresso de um capítulo:**
```
em andamento: { fertig: false, stand: { geloest: [...ids resolvidos], schlange: [...fila], fehler: [...], erster: [...], hilfe: [...], datum } }
concluído:    { fertig: true, erster: <acertos de primeira>, von: <total>, ... }
```
- Depois que um capítulo é marcado como concluído, salvar "em andamento" não desfaz isso.
- **Estrelas** (`pfad.js`): acertos de primeira dividido pelo total. 90% ou mais dá 3 estrelas, 60% ou mais dá 2, abaixo disso 1. Se não houver esses dados, dá 3.
- **Próximo capítulo:** o seguinte da lista, se não estiver concluído. Se estiver, o primeiro não concluído.
- **Migrações:** o módulo converte chaves antigas (`ev_fertige_kapitel`, chaves com `lang.xx`) para o formato novo quando a página carrega.

---

## 8. Conta e sincronização (Supabase sem SDK)

**Login sem senha, por código no e-mail (OTP):**
1. `POST /auth/v1/otp` com `{ email, create_user: true }`. O Supabase manda um código por e-mail.
2. `POST /auth/v1/verify` com `{ type: "email", email, token: código }`. Retorna o token de acesso e o de renovação.
3. O token é renovado com `POST /auth/v1/token?grant_type=refresh_token`.
4. Também existem: trocar e-mail (`PUT /auth/v1/user` e depois verificar com `type: "email_change"`), sair (`/auth/v1/logout?scope=local`) e excluir a conta (`POST /rest/v1/rpc/konto_loeschen`, uma função no banco).

**Banco: uma única tabela chave-valor, `fortschritt`:**
```
fortschritt(user_id uuid, schluessel text, wert text, geaendert timestamp)
unique(user_id, schluessel)
```
Ou seja, a tabela **espelha o `localStorage`**: cada chave permitida vira uma linha. A lista de chaves permitidas é uma regex que aceita `ev_kapitel`, `ev_schwer`, `ev_schwer_tenses`, `ev_taeglich`, `ev_level` e `ev_mutter`. Cada valor pode ter no máximo 100 mil caracteres.

**Como funciona a sincronização:**
- **Download:** busca as linhas paginadas (1000 por vez), só as alteradas desde a última sincronização (`geaendert=gt.<data>`).
- **Upload em lote:** `POST ...?on_conflict=user_id,schluessel` com `Prefer: resolution=merge-duplicates` (um upsert).
- **Chaves que precisam de mesclagem** (progresso, SRS, estatísticas): o app usa **trava otimista**. Lê o valor e o `geaendert`, mescla e faz `PATCH ...&geaendert=eq.<valor lido>`. Se outra pessoa ou aparelho alterou no meio tempo, tenta de novo (até 6 vezes).
- **Mesclagem de três vias** (`zusammen`), com o valor local, o do servidor e o da última sincronização, com regras por tipo:
  - SRS: fica o registro com mais repetições.
  - "Hoje": fica o dia mais recente.
  - Estatísticas: o maior valor de cada dia.
  - Shadowing/monster: o máximo de cada item.
  - Capítulos: concluído vence; depois, mais itens resolvidos.
- **Quando sincroniza:**
  - Envia mudanças a cada 3 s.
  - Envia logo ao sair da aba (`visibilitychange`/`pagehide`).
  - Baixa ao voltar o foco (no mínimo 20 s entre consultas, e uma consulta por minuto).
  - Baixa ao voltar a internet.
  - Se chegou algo novo e você está num menu, recarrega a página.

A URL do projeto e a **chave publicável** do Supabase estão no código público (`game/konto-einstellung.js`). Isso é normal no Supabase, porque a proteção vem das regras **RLS** no banco. Não verifiquei se as RLS estão bem configuradas.

---

## 9. O jogo "Writing" em detalhe (a página capturada)

**Sem `?text=`:** mostra a "trilha" de histórias (`PFAD.zeichnen`). Cada parada mostra:
- nível e quantidade de palavras, ou "n / total linhas" se estiver em andamento;
- estado (em andamento/concluída);
- estrelas.

**Com `?text=<id>`:**
1. As linhas vazias viram espaçamento. As linhas com `*` ganham destaque.
2. A linha atual é desenhada **letra por letra** em `<span>`s. Só letras, números e espaço precisam ser digitados; pontuação e aspas já aparecem preenchidas.
3. Um `<input>` escondido recebe o que você digita. O texto passa por um filtro:
   - maiúsculas e minúsculas são tratadas como iguais;
   - um caractere errado é **descartado na hora** (não entra);
   - a contagem de erros sobe e a linha é marcada como "com erro";
   - toca um som de erro (às vezes o "bruh") e a letra treme.
4. A letra atual fica destacada. O botão **"Hide the letters"** (Ctrl+Y) esconde as letras-guia para praticar de memória.
5. **Áudio:** no começo de cada frase, toca o MP3 automaticamente. O próximo já é pré-carregado. Ctrl+X ou o botão de ouvir repete o áudio, e clicar numa linha pronta toca o áudio dela. Se o navegador bloquear o autoplay, o áudio toca no próximo clique ou tecla.
6. Ao completar a linha, ela fica verde. Depois de 380 ms vai para a próxima, salva o progresso e rola a tela para manter a linha a ~40% da altura (também considerando o teclado no celular via `visualViewport`).
7. **Fim:**
   - salva `{ fertig, ohneHilfe, von, fehler }`;
   - mostra "X de Y linhas sem erro · N teclas erradas";
   - toca um arpejo de 5 notas gerado com Web Audio;
   - solta 44 confetes em CSS (desligados se "menos animação" estiver ativo);
   - mostra o link "Próxima história".
8. **Reiniciar** apaga o progresso daquela história.

O som de digitação (`tastenton.js`) também é **sintetizado**: um ruído branco curto com variação aleatória de volume e tom, para parecer um teclado de verdade, sem arquivos de áudio.

---

## 10. Detalhes de qualidade que vale copiar (a ideia, não o código)

- Aviso amigável quando um script não carrega, com botão "Recarregar".
- Tema claro/escuro aplicado antes do primeiro desenho da página (não pisca).
- Respeita `prefers-reduced-motion` e tem uma opção própria de "menos animação".
- `translate="no"` para o Google Tradutor não estragar os exercícios.
- Atalhos de teclado no computador e `enterkeyhint`, `autocorrect=off`, `autocapitalize=off` e `spellcheck=false` no celular.
- Progresso **offline-first**: funciona sem conta. A conta só sincroniza.
- Margens que respeitam o notch do celular (`env(safe-area-inset-top)`) e unidade `100dvh` para a altura da tela.

---

## 11. Como construir algo parecido (arquitetura sugerida)

Para um app próprio (por exemplo, ensinando inglês para quem fala português), a arquitetura deles é simples e barata. Uma versão moderna equivalente:

| Parte | Sugestão |
|---|---|
| Frontend | Vite + TypeScript (ou React/Svelte), uma rota por jogo |
| Conteúdo | JSON por capítulo/história, carregado sob demanda (em vez de `.js` globais de 400 KB carregados de uma vez) |
| Imagens | banco próprio de ilustrações, com ID estável por palavra |
| Áudio | TTS (por exemplo, Azure, Google ou ElevenLabs) gerado uma vez por frase e salvo como MP3 no CDN |
| Progresso | `localStorage`/IndexedDB primeiro, com a mesma ideia de chave-valor |
| Conta | Supabase Auth com OTP por e-mail + tabela `progress(user_id, key, value, updated_at)` com **RLS** `user_id = auth.uid()` |
| Sync | upsert em lote + mesclagem por tipo de dado (os mesmos princípios da seção 8) |
| Hospedagem | Cloudflare Pages ou Vercel (site estático) |
| PWA | manifest + service worker para funcionar offline |

**Atenção:** o conteúdo do Easy Vocabulary (histórias, frases, ilustrações, áudios) é de autoria deles. Para um produto seu, crie conteúdo próprio. A estrutura, as ideias de jogo e a arquitetura podem servir de referência livremente.

---

## 12. Para completar a análise

Para cobrir os outros jogos, capture mais arquivos HAR (em janela anônima, sem login) navegando por:
- `index.html` e `games.html` (página inicial e lista de jogos)
- `vocab.html` + um jogo de capítulo (`play.html`, `match.html`, `dictation.html`)
- `spaced.html` (para entender o algoritmo de repetição espaçada)
- `account.html` **logado** (para ver as chamadas reais ao Supabase; neste caso, apague os tokens do HAR antes de enviar)
