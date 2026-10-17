# Ilha Polar (Roblox)

Jogo social de pinguins em primeira pessoa, inspirado no Club Penguin. A ideia completa e o plano das próximas fases estão em [`docs/GDD.md`](docs/GDD.md).

## Como abrir no Roblox Studio

O projeto usa o [Rojo](https://rojo.space), que leva os arquivos `.luau` desta pasta para dentro do Studio.

### 1. Instalar as ferramentas (uma vez só)

1. Instale o [Rokit](https://github.com/rojo-rbx/rokit) (gerenciador de ferramentas do Roblox).
2. Nesta pasta, rode:
   ```
   rokit install
   ```
   Isso instala o Rojo, o selene (lint) e o StyLua (formatação) nas versões do `rokit.toml`.
3. No Roblox Studio, instale o plugin do Rojo: rode `rojo plugin install`, ou pegue o plugin "Rojo" na loja do Studio.

### 2. Jogar

**Opção A: sincronizar ao vivo (para desenvolver)**
1. Nesta pasta: `rojo serve`
2. No Studio, abra um place vazio (Baseplate), apague a peça "Baseplate", abra o plugin do Rojo e clique em **Connect**.
3. Aperte **Play**. Toda vez que você salvar um arquivo aqui, o Studio atualiza sozinho.

**Opção B: gerar o arquivo do place (com o mapa já montado)**
```
rojo build -o build/base.rbxlx
lune run tools/bake-map build/base.rbxlx IlhaPolar.rbxlx
```
O segundo comando roda o construtor do mapa e grava as salas dentro do arquivo,
então elas aparecem no Studio sem apertar Play. Depois é só abrir o
`IlhaPolar.rbxlx` no Studio.

No modo da opção A (`rojo serve`), o mapa só aparece quando você aperta Play.

### 3. Salvar progresso no Studio

O progresso usa DataStore. Para testar no Studio, publique o place e ative
**Game Settings → Security → Enable Studio Access to API Services**.
Sem isso o jogo funciona normalmente, só não salva (aparece um aviso no Output).

### 4. Avatar

O avatar de pinguim funciona com R15 e R6. O projeto já desliga a aparência do avatar do Roblox (`LoadCharacterAppearance = false`), então todo mundo aparece como pinguim.

## Controles

| Ação | PC | Celular | Controle |
|---|---|---|---|
| Jogar bola de neve | Clique | Botão ❄ | R2 |
| Mapa | M (ou Alt + clique no botão 🗺️) | Botão 🗺️ | (botão na tela) |
| Soltar o mouse | Segurar Alt | — | — |
| Interagir (loja, pesca) | E | Tocar no balão | X |
| Puxar o peixe | Clique ou Espaço | Tocar no aviso | A |

## Antes de enviar mudanças

```
stylua src          # formata
selene src          # lint
rojo build -o build/base.rbxlx && lune run tools/bake-map build/base.rbxlx build/IlhaPolar.rbxlx   # monta e testa o mapa
```

## Onde mexer

- **Preços, recompensas, salas, velocidade da bola de neve:** `src/shared/Config.luau`
- **Mapa ilustrado (botão 🗺️):** posição e ícone de cada lugar em `Config.Rooms[...].map` e `Config.MapComingSoon`; o desenho da ilha fica em `src/client/Controllers/MapController.luau`
- **Visual das salas:** `src/server/Services/MapBuilder.luau`. Dá para trocar uma sala por um modelo feito no Studio, desde que as tags `Portal`, `ShopCounter` e `FishingSpot` continuem nas peças certas.
- **Formato do pinguim:** tabela `PIECES` em `src/server/Services/PenguinAvatar.luau`
