-- Configuração central do jogo. Tudo que é "número de design" fica aqui,
-- para dar para balancear sem caçar valores no código.

local Config = {}

Config.GameName = "Ilha Polar"

---------------------------------------------------------------------------
-- Salas
---------------------------------------------------------------------------
-- Cada sala é uma ilha separada no mesmo servidor. Trocar de sala = teleporte.
-- `spawn` é relativo ao centro da sala; `look` é para onde o jogador olha ao chegar.

Config.RoomSize = 160 -- lado da plataforma de cada sala (studs)

Config.Rooms = {
	{
		id = "Vila",
		name = "Vila",
		description = "O centro da ilha: café e loja de cores.",
		center = Vector3.new(0, 0, 0),
		spawn = Vector3.new(0, 0, 30),
		look = Vector3.new(0, 0, -1),
	},
	{
		id = "Praca",
		name = "Praça",
		description = "Palco, fonte congelada e fortes para guerra de neve.",
		center = Vector3.new(400, 0, 0),
		spawn = Vector3.new(0, 0, 30),
		look = Vector3.new(0, 0, -1),
	},
	{
		id = "Doca",
		name = "Doca",
		description = "Pesque no fim do píer e ganhe moedas.",
		center = Vector3.new(0, 0, 400),
		spawn = Vector3.new(0, 0, -30),
		look = Vector3.new(0, 0, 1),
	},
	{
		id = "Montanha",
		name = "Montanha",
		description = "Pista de trenó (em breve).",
		center = Vector3.new(400, 0, 400),
		spawn = Vector3.new(0, 0, -30),
		look = Vector3.new(0, 0, 1),
	},
}

Config.RoomsById = {}
for _, room in Config.Rooms do
	Config.RoomsById[room.id] = room
end

Config.StartRoom = "Vila"
Config.RoomChangeCooldown = 2 -- segundos entre teleportes
Config.OceanHeight = -6 -- abaixo disso (com margem) o jogador "caiu na água" e volta à sala

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
