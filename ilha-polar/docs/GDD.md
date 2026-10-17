# Ilha Polar: documento do jogo

> Nome provisório. Jogo social de pinguins para o Roblox, inspirado no Club Penguin, mas em **primeira pessoa**.

## 1. A ideia

Um lugar para encontrar amigos numa ilha nevada. Você é um pinguim, anda pelas salas, conversa, joga bola de neve, ganha moedas em minigames e gasta essas moedas para personalizar o pinguim (e, mais para frente, o iglu).

A diferença para o original é a câmera: tudo é visto **pelos olhos do pinguim**. Isso deixa a guerra de bola de neve com cara de jogo de tiro (leve e sem dano), a pesca mais imersiva e as salas mais "de verdade".

## 2. O que dá e o que não dá para copiar

O Club Penguin é da Disney. O Roblox remove jogos que usam marca ou arte de outras empresas, e isso pode até levar a conta a ser punida.

| Pode (são mecânicas e ideias) | Não pode (é propriedade da Disney) |
|---|---|
| Pinguins como avatar | O nome "Club Penguin" ou parecidos |
| Salas ligadas por um mapa | Os "Puffles" (crie bichinhos próprios) |
| Moedas, minigames, loja de roupas, iglus | Personagens como Rockhopper, Aunt Arctic, Gary |
| Bola de neve, pesca, festas temáticas | Arte, músicas, logos, textos e nomes de salas copiados |

Regra prática: **mecânicas iguais, nomes e visual nossos.**

## 3. Pilares

1. **Social primeiro.** Tudo serve para juntar gente: salas pequenas, chat em balão, emotes.
2. **Diversão rápida.** Minigames de 1 a 3 minutos que dão moedas.
3. **Identidade.** Cor, roupas, iglu e bichinho mostram quem você é.
4. **Seguro para crianças.** O chat usa o filtro do Roblox e não há PvP com dano.

## 4. Primeira pessoa: problemas e soluções

| Problema | Solução |
|---|---|
| Você não vê o seu próprio pinguim | Espelho na loja; modo "foto" que mostra a câmera em 3ª pessoa por alguns segundos; nadadeiras aparecendo na tela (viewmodel) |
| Emotes não aparecem para quem faz | O emote aparece para os outros; para você, um ícone na tela confirma |
| Cliques ficam presos (mouse no centro) | Janelas soltam o mouse ao abrir (`Modal`); atalhos de teclado (M = mapa) |
| Enjoo de câmera | Sem balanço de câmera; FOV padrão; opção de 3ª pessoa no futuro, se os testes pedirem |

## 5. Salas

| Sala | Função | Estado |
|---|---|---|
| **Vila** | Centro. Café e Loja de Cores. Ponto de nascimento. | ✅ protótipo |
| **Praça** | Palco, fonte congelada, fortes de neve para guerra de bola de neve | ✅ protótipo |
| **Doca** | Píer com pontos de pesca | ✅ protótipo |
| **Montanha** | Pista de trenó | 🟡 cenário pronto, minigame em breve |
| Iglu (privado) | Casa de cada jogador, decorável | ⏳ fase 2 |

Trocar de sala: pelo **mapa** ou pelos **portais** azuis no chão de cada sala.

**Mapa ilustrado:** botão redondo 🗺️ no canto esquerdo (ou tecla M). Abre uma ilha desenhada do zero com montanhas, pinheiros, píer e lago. Cada lugar é um ícone clicável que teleporta; o marcador "Você está aqui" flutua sobre a sala atual; lugares futuros (Farol, Bairro dos Iglus, Lago Congelado) aparecem com cadeado. Em primeira pessoa, segurar **Alt** solta o mouse para clicar nos botões da tela.

## 6. O que já está feito (versão 0.1)

- Câmera travada em primeira pessoa.
- Avatar de pinguim montado por código, colorido pela cor do jogador.
- 4 salas, mapa e portais. Quem cai no mar volta para a sala.
- **Bola de neve:** clique para jogar. O servidor cria a bola, controla o intervalo entre arremessos e avisa quem foi atingido (a tela fica branca).
- **Pesca:** espere morder e puxe a tempo. Dá de 1 a 20 moedas. O tempo é contado no servidor, então não dá para trapacear.
- **Moedas e Loja de Cores:** 9 cores de 0 a 60 moedas.
- **Progresso salvo** (DataStore): moedas, cores compradas, cor atual, peixes pescados.
- Funciona no PC, no celular (botões de toque) e no controle.

## 7. Próximas fases

**Fase 2: Iglus**
- Cada jogador tem um iglu (servidor reservado ou área privada).
- Móveis comprados com moedas; modo de edição para posicionar.
- Visitar o iglu dos amigos.

**Fase 3: Roupas e bichinhos**
- Chapéus, óculos, roupas e cachecóis encaixados no pinguim.
- Catálogo que muda todo mês (como no original).
- Bichinho de estimação próprio (nome e design nossos) que segue o jogador.

**Fase 4: Mais minigames**
- Corrida de trenó na Montanha.
- Café: atender pedidos (jogo de servir).
- Dança no palco da Praça (ritmo).
- Guerra de neve por times, com placar.

**Fase 5: Vida ao vivo**
- Festas temáticas (Halloween, Natal, verão) que mudam a decoração.
- Itens grátis escondidos durante as festas.
- Emotes e chat rápido (frases prontas) para o público mais novo.

**Monetização (depois de ter jogadores):** Game Pass "Sócio" com roupas exclusivas e acesso a uma sala VIP, e pacotes de moedas. Nada que dê vantagem nos minigames.

## 8. Arquitetura técnica

- **Rojo + Luau.** O código vive no Git; o Studio só recebe os arquivos.
- **Servidor manda.** O cliente só pede ("quero jogar uma bola nessa direção", "quero comprar a cor X"). O servidor valida tudo: intervalo entre ações, distância, saldo e tempo da pesca.
- **Atributos do Player** (`Coins`, `Color`, `OwnedColors`, `Room`) espelham os dados para o cliente, sem precisar de remotes extras.
- **Tags do CollectionService** (`Portal`, `ShopCounter`, `FishingSpot`) ligam o mapa aos sistemas. Quando o mapa de protótipo for trocado por um modelo feito no Studio, basta manter as tags.
- Valores de balanceamento ficam todos em `src/shared/Config.luau`.

```
src/
  shared/        Config (salas, preços, pesca, bola de neve) e Remotes
  server/
    Main.server.luau
    Services/    MapBuilder, DataService, PenguinAvatar, RoomService,
                 SnowballService, FishingService, ShopService
  client/
    Main.client.luau
    Controllers/ Hud, MapController, ShopController, FishingController, SnowballController
```
