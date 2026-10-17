-- Configuração central do jogo. Tudo que é "número de design" fica aqui,
-- para dar para balancear sem caçar valores no código.

local Config = {}

Config.GameName = "Ilha Polar"

---------------------------------------------------------------------------
-- Lugares da ilha
---------------------------------------------------------------------------
-- A ilha é uma só; cada lugar é uma região dela. O mapa da tela teleporta para
-- o `spawn` do lugar, e a sala atual do jogador (atributo "Room") é o lugar
-- mais perto dele.
--
-- Todas as posições estão em pixels da imagem do mapa (assets/mapa-ilha.png):
--   map    onde fica o ponto clicável no mapa da tela
--   spawn  onde o jogador aparece ao escolher o lugar
--   look   para onde ele olha ao chegar

-- ID da imagem do mapa depois de enviada ao Roblox (veja o README).
-- Enquanto estiver vazio, o mapa da tela desenha a ilha a partir do layout.
Config.MapImage = ""

Config.Rooms = {
	{
		id = "Praca",
		name = "Praça",
		icon = "⛲",
		description = "O coração da ilha, com a fonte da estátua do pinguim.",
		map = Vector2.new(790, 505),
		spawn = Vector2.new(790, 600),
		look = Vector2.new(790, 500),
	},
	{
		id = "Vila",
		name = "Vila",
		icon = "🏘️",
		description = "Lojas e café. A Loja de Cores fica na casa azul.",
		map = Vector2.new(540, 560),
		spawn = Vector2.new(560, 640),
		look = Vector2.new(525, 540),
	},
	{
		id = "Porto",
		name = "Porto",
		icon = "⚓",
		description = "Píeres e barco. Pesque na ponta dos píeres.",
		map = Vector2.new(330, 670),
		spawn = Vector2.new(455, 628),
		look = Vector2.new(300, 650),
	},
	{
		id = "Praia",
		name = "Praia do Surfe",
		icon = "🏄",
		description = "Areia, guarda-sóis e a cabana de surfe.",
		map = Vector2.new(360, 400),
		spawn = Vector2.new(420, 445),
		look = Vector2.new(330, 360),
	},
	{
		id = "Farol",
		name = "Farol",
		icon = "🗼",
		description = "A ponta oeste da ilha.",
		map = Vector2.new(100, 505),
		spawn = Vector2.new(165, 550),
		look = Vector2.new(100, 505),
	},
	{
		id = "Mirante",
		name = "Mirante",
		icon = "🚩",
		description = "O ponto mais alto do oeste. Vista da ilha inteira.",
		map = Vector2.new(640, 150),
		spawn = Vector2.new(590, 205),
		look = Vector2.new(640, 140),
	},
	{
		id = "Cachoeira",
		name = "Cachoeira",
		icon = "💧",
		description = "Cachoeira, piscina natural e ponte de corda.",
		map = Vector2.new(820, 320),
		spawn = Vector2.new(790, 420),
		look = Vector2.new(840, 310),
	},
	{
		id = "Templo",
		name = "Templo",
		icon = "🏛️",
		description = "Ruínas antigas no alto do morro.",
		map = Vector2.new(1150, 150),
		spawn = Vector2.new(1140, 225),
		look = Vector2.new(1150, 140),
	},
	{
		id = "Acampamento",
		name = "Acampamento",
		icon = "⛺",
		description = "Barracas e fogueira perto do lago.",
		map = Vector2.new(1400, 360),
		spawn = Vector2.new(1380, 430),
		look = Vector2.new(1400, 370),
	},
	{
		id = "Campo",
		name = "Campo de Futebol",
		icon = "⚽",
		description = "Campo com arquibancada.",
		map = Vector2.new(1220, 515),
		spawn = Vector2.new(1085, 515),
		look = Vector2.new(1220, 515),
	},
	{
		id = "Bairro",
		name = "Bairro",
		icon = "🏡",
		description = "As casinhas da ilha.",
		map = Vector2.new(1000, 645),
		spawn = Vector2.new(980, 712),
		look = Vector2.new(1000, 640),
	},
	{
		id = "Parque",
		name = "Parque Aquático",
		icon = "🛝",
		description = "Lagoa com tobogãs e boias.",
		map = Vector2.new(1500, 630),
		spawn = Vector2.new(1330, 600),
		look = Vector2.new(1480, 680),
	},
	{
		id = "Pier",
		name = "Píer do Veleiro",
		icon = "⛵",
		description = "Píer comprido do sul. Também dá para pescar.",
		map = Vector2.new(1150, 835),
		spawn = Vector2.new(1090, 762),
		look = Vector2.new(1180, 880),
	},
}

Config.RoomsById = {}
for _, room in Config.Rooms do
	Config.RoomsById[room.id] = room
end

Config.StartRoom = "Praca"
Config.RoomChangeCooldown = 2 -- segundos entre teleportes
Config.RescueHeight = -30 -- abaixo disso o jogador volta para o lugar em que estava

---------------------------------------------------------------------------
-- Economia
---------------------------------------------------------------------------
Config.StartingCoins = 50

-- Cores do pinguim (vendidas na loja da Vila)
Config.DefaultColor = "Azul"
Config.Colors = {
	{ id = "Azul", name = "Azul", color = Color3.fromRGB(40, 90, 200), price = 0 },
	{ id = "Verde", name = "Verde", color = Color3.fromRGB(50, 160, 70), price = 20 },
	{ id = "Vermelho", name = "Vermelho", color = Color3.fromRGB(200, 40, 40), price = 20 },
	{ id = "Amarelo", name = "Amarelo", color = Color3.fromRGB(240, 200, 30), price = 30 },
	{ id = "Rosa", name = "Rosa", color = Color3.fromRGB(240, 120, 190), price = 30 },
	{ id = "Laranja", name = "Laranja", color = Color3.fromRGB(245, 130, 30), price = 40 },
	{ id = "Roxo", name = "Roxo", color = Color3.fromRGB(120, 60, 180), price = 40 },
	{ id = "Marrom", name = "Marrom", color = Color3.fromRGB(110, 70, 40), price = 50 },
	{ id = "Preto", name = "Preto", color = Color3.fromRGB(25, 25, 30), price = 60 },
}

Config.ColorsById = {}
for _, item in Config.Colors do
	Config.ColorsById[item.id] = item
end

---------------------------------------------------------------------------
-- Bola de neve
---------------------------------------------------------------------------
Config.Snowball = {
	cooldown = 0.6, -- segundos entre arremessos
	speed = 95, -- studs/s
	lifetime = 4, -- some depois disso se não acertar nada
	gravityScale = 0.35, -- fração da gravidade que a bola sente (arco suave)
}

---------------------------------------------------------------------------
-- Pesca
---------------------------------------------------------------------------
Config.Fishing = {
	biteMin = 2, -- segundos até o peixe morder (mínimo)
	biteMax = 6, -- (máximo)
	reactionWindow = 1.6, -- tempo para puxar depois da mordida
	maxDistance = 14, -- distância máxima do ponto de pesca
	rewards = {
		{ name = "Peixe pequeno", coins = 5, weight = 55 },
		{ name = "Peixe médio", coins = 10, weight = 30 },
		{ name = "Peixe grande", coins = 20, weight = 12 },
		{ name = "Bota velha", coins = 1, weight = 3 },
	},
}

return Config
