-- Formato da ilha, descrito nas coordenadas (em pixels) da imagem do mapa
-- (assets/mapa-ilha.png, 1619 x 971). Assim o mundo 3D e os pontos clicáveis
-- do mapa da tela usam exatamente os mesmos números.
--
-- Para mexer: abra a imagem num editor, veja o pixel do lugar e ajuste aqui.

local IslandLayout = {}

IslandLayout.IMAGE_SIZE = Vector2.new(1619, 971)
IslandLayout.SCALE = 0.6 -- studs por pixel da imagem
IslandLayout.ORIGIN = Vector2.new(800, 500) -- pixel que vira o ponto (0, 0, 0) do mundo

-- Alturas (studs)
IslandLayout.SEA_FLOOR = -14
IslandLayout.WATER_LEVEL = 0.5
IslandLayout.SAND_TOP = 2.5
IslandLayout.GRASS_TOP = 3
IslandLayout.GRASS_RATIO = 0.87 -- a grama cobre 87% do raio da areia

-- Terra: { x, y, raio, praia? }. Praia = só areia; sem a flag, ganha grama por cima.
IslandLayout.LAND = {
	-- Praia do Surfe
	{ 300, 410, 70, true },
	{ 380, 430, 80, true },
	{ 470, 440, 70, true },
	{ 250, 380, 40, true },
	-- Pé das falésias do Mirante
	{ 430, 330, 70 },
	{ 560, 330, 90 },
	{ 680, 320, 80 },
	-- Vila
	{ 560, 570, 120 },
	{ 460, 560, 80 },
	{ 660, 610, 70 },
	{ 340, 550, 55 },
	{ 295, 560, 45, true },
	{ 680, 530, 60 },
	{ 400, 520, 60 },
	-- Península do Farol
	{ 110, 530, 75 },
	{ 190, 560, 50, true },
	{ 250, 560, 40, true },
	-- Praça e centro
	{ 800, 520, 140 },
	{ 700, 450, 70 },
	{ 800, 400, 90 },
	{ 950, 380, 100 },
	-- Templo, lago e acampamento
	{ 1100, 330, 110 },
	{ 1250, 330, 100 },
	{ 1400, 380, 110 },
	{ 1500, 440, 70 },
	-- Campo de futebol
	{ 1220, 510, 140 },
	{ 1100, 500, 80 },
	{ 1360, 500, 70 },
	-- Bairro
	{ 930, 650, 100 },
	{ 1050, 660, 100 },
	{ 1150, 640, 80 },
	{ 860, 600, 70 },
	{ 1160, 430, 70 },
	{ 1330, 420, 70 },
	-- Praia do sul
	{ 1000, 760, 70, true },
	{ 1100, 760, 70, true },
	{ 1200, 720, 70, true },
	{ 880, 740, 50, true },
	-- Oeste da ponte
	{ 680, 690, 60 },
	{ 620, 660, 50 },
	-- Areia do parque aquático (a lagoa no meio fica sem terra)
	{ 1300, 610, 70, true },
	{ 1400, 570, 60, true },
	{ 1530, 560, 60, true },
	{ 1580, 640, 40, true },
	{ 1580, 700, 45, true },
	{ 1560, 790, 50, true },
	{ 1300, 745, 55, true },
	-- Ilhotas
	{ 110, 740, 55 },
	{ 590, 850, 75 },
	{ 330, 225, 22 },
	{ 110, 270, 26, true },
	{ 1590, 290, 18 },
}

-- Falésias e morros: { x, y, raio, altura do topo }
IslandLayout.CLIFFS = {
	Mirante1 = { 480, 280, 75, 16 },
	Mirante2 = { 600, 210, 95, 28 },
	Mirante3 = { 705, 250, 65, 28 },
	Cachoeira = { 885, 245, 75, 28 },
	Templo = { 1130, 185, 115, 40 },
	TemploDegrau = { 1185, 300, 58, 20 },
	RochasLeste = { 1520, 470, 45, 10 },
	IlhotaSul = { 590, 860, 40, 10 },
	IlhotaOeste = { 110, 750, 30, 8 },
}

-- Água em cima da terra (lagos rasos): { x, y, raio }
IslandLayout.POOLS = {
	Cachoeira = { 820, 350, 50 },
	Lago = { 1090, 380, 55 },
}

IslandLayout.PLAZA = { 790, 515, 95 } -- piso de pedra redondo da Praça

-- Pixel da imagem -> posição no mundo.
function IslandLayout.toWorld(x: number, y: number, height: number?): Vector3
	return Vector3.new(
		(x - IslandLayout.ORIGIN.X) * IslandLayout.SCALE,
		height or 0,
		(y - IslandLayout.ORIGIN.Y) * IslandLayout.SCALE
	)
end

-- Posição no mundo -> pixel da imagem.
function IslandLayout.toImage(position: Vector3): Vector2
	return Vector2.new(
		position.X / IslandLayout.SCALE + IslandLayout.ORIGIN.X,
		position.Z / IslandLayout.SCALE + IslandLayout.ORIGIN.Y
	)
end

local function inside(x: number, y: number, cx: number, cy: number, r: number): boolean
	local dx, dy = x - cx, y - cy
	return dx * dx + dy * dy <= r * r
end

-- Altura do chão num pixel da imagem (usada para apoiar a decoração no chão).
function IslandLayout.groundHeight(x: number, y: number): number
	local best = nil
	for _, cliff in IslandLayout.CLIFFS do
		if inside(x, y, cliff[1], cliff[2], cliff[3]) and (best == nil or cliff[4] > best) then
			best = cliff[4]
		end
	end
	if best then
		return best
	end
	local plaza = IslandLayout.PLAZA
	if inside(x, y, plaza[1], plaza[2], plaza[3]) then
		return IslandLayout.GRASS_TOP + 0.25
	end
	local height = nil
	for _, land in IslandLayout.LAND do
		if not land[4] and inside(x, y, land[1], land[2], land[3] * IslandLayout.GRASS_RATIO) then
			return IslandLayout.GRASS_TOP
		elseif inside(x, y, land[1], land[2], land[3]) then
			height = IslandLayout.SAND_TOP
		end
	end
	return height or IslandLayout.WATER_LEVEL
end

return IslandLayout
