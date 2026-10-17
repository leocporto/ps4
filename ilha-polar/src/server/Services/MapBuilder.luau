-- Monta a ilha em 3D a partir do mapa oficial (assets/mapa-ilha.png).
--
-- Tudo é posicionado em pixels da imagem via IslandLayout.toWorld, então dá
-- para conferir cada coisa olhando o mapa. O formato da terra (praias, grama,
-- falésias, lagos) vem do IslandLayout; aqui ficam as construções e a decoração.
--
-- É feito só com peças simples. Cada lugar pode ser trocado depois por um
-- modelo feito no Studio, desde que as tags continuem nas peças certas:
--   "ShopCounter"  tem um ProximityPrompt com atributo Action = "Shop"
--   "FishingSpot"  tem um ProximityPrompt

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.IslandLayout)

local MapBuilder = {}

local S = Layout.SCALE
local UP = Vector3.new(0, 1, 0)

local COLORS = {
	sand = Color3.fromRGB(240, 220, 160),
	wetSand = Color3.fromRGB(215, 190, 130),
	grass = Color3.fromRGB(110, 190, 70),
	darkGrass = Color3.fromRGB(70, 150, 60),
	rock = Color3.fromRGB(120, 125, 135),
	darkRock = Color3.fromRGB(90, 95, 105),
	path = Color3.fromRGB(225, 195, 140),
	stone = Color3.fromRGB(200, 190, 185),
	stoneDark = Color3.fromRGB(160, 150, 150),
	templeStone = Color3.fromRGB(150, 155, 140),
	moss = Color3.fromRGB(80, 140, 70),
	wood = Color3.fromRGB(150, 100, 60),
	darkWood = Color3.fromRGB(100, 65, 40),
	thatch = Color3.fromRGB(205, 165, 95),
	water = Color3.fromRGB(40, 170, 215),
	lightWater = Color3.fromRGB(120, 210, 240),
	palm = Color3.fromRGB(60, 160, 60),
	palmDark = Color3.fromRGB(40, 125, 50),
	trunk = Color3.fromRGB(150, 110, 70),
	white = Color3.fromRGB(245, 245, 245),
	red = Color3.fromRGB(210, 50, 50),
	black = Color3.fromRGB(25, 25, 30),
}

---------------------------------------------------------------------------
-- Ajudantes básicos
---------------------------------------------------------------------------

-- Pseudo-aleatório com semente fixa: o mapa sai sempre igual.
local seed = 12345
local function rand(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end
local function randRange(a: number, b: number): number
	return a + (b - a) * rand()
end

local function part(props: { [string]: any }): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	for key, value in props do
		if key ~= "ClassName" and key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Ponto no mundo a partir do pixel do mapa, apoiado no chão (+ `up` studs).
local function at(x: number, y: number, up: number?): Vector3
	return Layout.toWorld(x, y, Layout.groundHeight(x, y) + (up or 0))
end

-- CFrame no chão em (x, y), com a frente (-Z) virada para o pixel (fx, fy).
local function facing(x: number, y: number, fx: number, fy: number, up: number?): CFrame
	local from = at(x, y, up)
	return CFrame.lookAt(from, Layout.toWorld(fx, fy, from.Y))
end

local function ellipsoid(p: BasePart): BasePart
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- CFrame no meio de a e b, com o eixo X apontando de a para b (para cilindros).
local function alongX(a: Vector3, b: Vector3): CFrame
	local dir = (b - a).Unit
	local mid = (a + b) / 2
	if math.abs(dir.Y) > 0.999 then
		return CFrame.new(mid) * CFrame.Angles(0, 0, math.rad(90))
	end
	return CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0)
end

-- Cilindro em pé (disco) entre duas alturas. Raio em pixels da imagem.
local function disc(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	r: number,
	bottom: number,
	top: number,
	color: Color3,
	material: Enum.Material
): BasePart
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(top - bottom, r * 2 * S, r * 2 * S),
		CFrame = CFrame.new(Layout.toWorld(x, y, (top + bottom) / 2)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
		Parent = parent,
	})
end

-- Bloco esticado entre dois pontos quase horizontais (caminhos, píeres).
local function beam(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	height: number,
	color: Color3,
	material: Enum.Material
): BasePart
	return part({
		Name = name,
		Size = Vector3.new(width, height, (b - a).Magnitude),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = color,
		Material = material,
		Parent = parent,
	})
end

-- Cilindro entre dois pontos (troncos, postes, mastros, tobogãs).
local function rod(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new((b - a).Magnitude, thickness, thickness),
		CFrame = alongX(a, b),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

local function label(adornee: BasePart, text: string, offsetY: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0

	local text_ = Instance.new("TextLabel")
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundTransparency = 1
	text_.Text = text
	text_.TextScaled = true
	text_.Font = Enum.Font.FredokaOne
	text_.TextColor3 = Color3.new(1, 1, 1)
	text_.TextStrokeTransparency = 0.3
	text_.Parent = gui

	gui.Adornee = adornee
	gui.Parent = adornee
end

local function prompt(parent: BasePart, actionText: string, objectText: string, action: string)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = actionText
	p.ObjectText = objectText
	p.HoldDuration = 0
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p:SetAttribute("Action", action)
	p.Parent = parent
	return p
end

local function fishingSpot(parent: Instance, x: number, y: number)
	local spot = part({
		Name = "PontoDePesca",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.4, 2, 2),
		CFrame = CFrame.new(Layout.toWorld(x, y, Layout.SAND_TOP + 1.2)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = COLORS.darkWood,
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	spot:AddTag("FishingSpot")
	prompt(spot, "Pescar", "Ponto de pesca", "Fish")
end

---------------------------------------------------------------------------
-- Natureza
---------------------------------------------------------------------------

local function palm(parent: Instance, x: number, y: number)
	local h = randRange(16, 24)
	local m = model(parent, "Coqueiro")
	local cf = CFrame.new(at(x, y, -0.5)) * CFrame.Angles(0, randRange(0, math.pi * 2), 0)
	local segment = h / 4
	local lean = randRange(4, 9)
	for i = 1, 4 do
		cf = cf * CFrame.Angles(math.rad(lean), 0, 0)
		local thickness = 1.7 - i * 0.12
		part({
			Name = "Tronco",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(segment + 0.3, thickness, thickness),
			CFrame = cf * CFrame.new(0, segment / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = COLORS.trunk,
			Material = Enum.Material.Wood,
			Parent = m,
		})
		cf = cf * CFrame.new(0, segment, 0)
	end
	local top = CFrame.new(cf.Position)
	for k = 0, 6 do
		ellipsoid(part({
			Name = "Folha",
			Size = Vector3.new(2.6, 0.5, 11),
			CFrame = top
				* CFrame.Angles(0, k * math.pi * 2 / 7 + randRange(-0.2, 0.2), 0)
				* CFrame.Angles(math.rad(-22), 0, 0)
				* CFrame.new(0, 0, -5),
			Color = if k % 2 == 0 then COLORS.palm else COLORS.palmDark,
			Material = Enum.Material.LeafyGrass,
			CanCollide = false,
			Parent = m,
		}))
	end
	for k = 0, 2 do
		part({
			Name = "Coco",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.1,
			CFrame = top * CFrame.Angles(0, k * 2.1, 0) * CFrame.new(0.7, -0.8, 0),
			Color = COLORS.darkWood,
			Parent = m,
		})
	end
end

local function bushTree(parent: Instance, x: number, y: number, size: number?)
	local s = size or 1
	local m = model(parent, "Arvore")
	local base = at(x, y, -0.5)
	rod(m, "Tronco", base, base + UP * 9 * s, 2 * s, COLORS.trunk, Enum.Material.Wood)
	for _, offset in
		{ Vector3.new(0, 11, 0), Vector3.new(3, 9, 2), Vector3.new(-3, 9.5, -1.5), Vector3.new(0.5, 13, -1) }
	do
		part({
			Name = "Copa",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 8 * s,
			CFrame = CFrame.new(base + offset * s),
			Color = COLORS.darkGrass,
			Material = Enum.Material.LeafyGrass,
			Parent = m,
		})
	end
end

local function rock(parent: Instance, x: number, y: number, size: number, sink: number?)
	part({
		Name = "Pedra",
		Size = Vector3.new(size * randRange(0.8, 1.3), size * randRange(0.6, 1), size * randRange(0.8, 1.3)),
		CFrame = CFrame.new(Layout.toWorld(x, y, Layout.groundHeight(x, y) - (sink or size * 0.25)))
			* CFrame.Angles(randRange(-0.3, 0.3), randRange(0, math.pi), randRange(-0.3, 0.3)),
		Color = if rand() > 0.5 then COLORS.rock else COLORS.darkRock,
		Material = Enum.Material.Slate,
		Parent = parent,
	})
end

local FLOWER_COLORS = { Color3.fromRGB(240, 80, 120), Color3.fromRGB(250, 200, 60), Color3.fromRGB(230, 90, 200) }

local function flowers(parent: Instance, x: number, y: number)
	for i = 1, 5 do
		part({
			Name = "Flor",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.2,
			CFrame = CFrame.new(at(x + randRange(-8, 8), y + randRange(-6, 6), 0.5)),
			Color = FLOWER_COLORS[(i % #FLOWER_COLORS) + 1],
			CanCollide = false,
			Parent = parent,
		})
	end
end

---------------------------------------------------------------------------
-- Estruturas reutilizáveis
---------------------------------------------------------------------------

-- Prédio oco com porta na frente e telhado de duas águas.
-- `base` fica no chão no centro do prédio; a frente aponta para -Z (LookVector).
local function building(
	parent: Instance,
	name: string,
	base: CFrame,
	size: Vector3,
	wallColor: Color3,
	roofColor: Color3,
	sign: string?
): Model
	local m = model(parent, name)
	local t = 1
	local doorW, doorH = 6, 8
	local w, h, d = size.X, size.Y, size.Z

	local function wall(n: string, cf: CFrame, s: Vector3)
		part({
			Name = n,
			Size = s,
			CFrame = base * cf,
			Color = wallColor,
			Material = Enum.Material.WoodPlanks,
			Parent = m,
		})
	end
	wall("Fundo", CFrame.new(0, h / 2, d / 2), Vector3.new(w, h, t))
	wall("Esquerda", CFrame.new(-w / 2, h / 2, 0), Vector3.new(t, h, d))
	wall("Direita", CFrame.new(w / 2, h / 2, 0), Vector3.new(t, h, d))
	local side = (w - doorW) / 2
	wall("FrenteE", CFrame.new(-(doorW + side) / 2, h / 2, -d / 2), Vector3.new(side, h, t))
	wall("FrenteD", CFrame.new((doorW + side) / 2, h / 2, -d / 2), Vector3.new(side, h, t))
	wall("Verga", CFrame.new(0, doorH + (h - doorH) / 2, -d / 2), Vector3.new(doorW, h - doorH, t))

	part({
		Name = "Piso",
		Size = Vector3.new(w, 0.4, d),
		CFrame = base * CFrame.new(0, 0.2, 0),
		Color = COLORS.wood,
		Material = Enum.Material.WoodPlanks,
		Parent = m,
	})

	-- Telhado de duas águas: duas placas inclinadas que se encontram no meio.
	local pitch = math.rad(30)
	local slab = (d / 2) / math.cos(pitch) + 1.5
	local rise = (d / 4) * math.tan(pitch)
	for _, sideSign in { -1, 1 } do
		part({
			Name = "Telhado",
			Size = Vector3.new(w + 3, 0.8, slab),
			CFrame = base * CFrame.new(0, h + rise, sideSign * d / 4) * CFrame.Angles(sideSign * pitch, 0, 0),
			Color = roofColor,
			Material = Enum.Material.SmoothPlastic,
			Parent = m,
		})
		part({
			Name = "Oitao",
			Size = Vector3.new(t, rise * 1.6, d * 0.55),
			CFrame = base * CFrame.new(sideSign * w / 2, h + rise * 0.8, 0),
			Color = wallColor,
			Material = Enum.Material.WoodPlanks,
			Parent = m,
		})
	end

	for _, x in { -w / 2 + side / 2, w / 2 - side / 2 } do
		part({
			Name = "Janela",
			Size = Vector3.new(math.min(4, side - 1), 3, 0.3),
			CFrame = base * CFrame.new(x, doorH - 3, -d / 2 - 0.55),
			Color = Color3.fromRGB(150, 210, 240),
			Material = Enum.Material.Glass,
			Parent = m,
		})
	end

	if sign then
		local board = part({
			Name = "Placa",
			Size = Vector3.new(w * 0.6, 2.4, 0.5),
			CFrame = base * CFrame.new(0, doorH + 1.6, -d / 2 - 0.7),
			Color = COLORS.darkWood,
			Parent = m,
		})
		label(board, sign, 2.2)
	end
	return m
end

-- Telhado de palha em degraus (cabanas, quiosques, mirante).
local function thatchRoof(parent: Instance, center: CFrame, width: number, color: Color3?)
	for i = 0, 3 do
		local s = width * (1 - i * 0.24)
		part({
			Name = "Palha",
			Size = Vector3.new(s, 1.4, s),
			CFrame = center * CFrame.new(0, i * 1.3, 0),
			Color = color or COLORS.thatch,
			Material = Enum.Material.Fabric,
			Parent = parent,
		})
	end
end

-- Quiosque: deck, quatro postes e telhado de palha.
local function hut(
	parent: Instance,
	name: string,
	base: CFrame,
	width: number,
	height: number,
	roofColor: Color3?
): Model
	local m = model(parent, name)
	part({
		Name = "Deck",
		Size = Vector3.new(width, 1, width),
		CFrame = base * CFrame.new(0, 0.5, 0),
		Color = COLORS.wood,
		Material = Enum.Material.WoodPlanks,
		Parent = m,
	})
	for _, c in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
		local p = (base * CFrame.new(c * (width / 2 - 1))).Position
		rod(m, "Poste", p, p + UP * height, 1, COLORS.darkWood, Enum.Material.Wood)
	end
	thatchRoof(m, base * CFrame.new(0, height + 0.7, 0), width + 4, roofColor)
	return m
end

local function umbrella(parent: Instance, x: number, y: number, color: Color3)
	local base = at(x, y)
	rod(parent, "Haste", base, base + UP * 8, 0.4, COLORS.white)
	part({
		Name = "GuardaSol",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 10, 10),
		CFrame = CFrame.new(base + UP * 8) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Fabric,
		Parent = parent,
	})
	part({
		Name = "Topo",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.2,
		CFrame = CFrame.new(base + UP * 8.6),
		Color = COLORS.white,
		Parent = parent,
	})
end

local function beachChair(parent: Instance, base: CFrame, color: Color3)
	part({
		Name = "Assento",
		Size = Vector3.new(3, 0.5, 5),
		CFrame = base * CFrame.new(0, 1, 0),
		Color = color,
		Material = Enum.Material.Fabric,
		Parent = parent,
	})
	part({
		Name = "Encosto",
		Size = Vector3.new(3, 0.5, 3),
		CFrame = base * CFrame.new(0, 2, 2.8) * CFrame.Angles(math.rad(50), 0, 0),
		Color = color,
		Material = Enum.Material.Fabric,
		Parent = parent,
	})
end

local function bench(parent: Instance, base: CFrame)
	part({
		Name = "Assento",
		Size = Vector3.new(7, 0.6, 2.2),
		CFrame = base * CFrame.new(0, 1.8, 0),
		Color = COLORS.wood,
		Material = Enum.Material.WoodPlanks,
		Parent = parent,
	})
	for _, x in { -3, 3 } do
		part({
			Name = "Pe",
			Size = Vector3.new(0.6, 1.6, 2),
			CFrame = base * CFrame.new(x, 0.8, 0),
			Color = COLORS.darkWood,
			Parent = parent,
		})
	end
end

local function lamp(parent: Instance, x: number, y: number)
	local base = at(x, y)
	rod(parent, "Poste", base, base + UP * 10, 0.6, Color3.fromRGB(40, 80, 60), Enum.Material.Metal)
	local bulb = part({
		Name = "Lampada",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.6,
		CFrame = CFrame.new(base + UP * 10.5),
		Color = Color3.fromRGB(255, 240, 180),
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Range = 16
	light.Brightness = 0.8
	light.Color = Color3.fromRGB(255, 230, 170)
	light.Parent = bulb
end

-- Píer de madeira entre dois pixels, com estacas.
local function dock(parent: Instance, ax: number, ay: number, bx: number, by: number, width: number): BasePart
	local a = Layout.toWorld(ax, ay, Layout.SAND_TOP - 0.5)
	local b = Layout.toWorld(bx, by, Layout.SAND_TOP - 0.5)
	local deck = beam(parent, "Deck", a, b, width, 1, COLORS.wood, Enum.Material.WoodPlanks)
	local length = (b - a).Magnitude
	local dir = (b - a).Unit
	local right = deck.CFrame.RightVector
	for d = 4, length - 2, 10 do
		local p = a + dir * d
		for _, sideSign in { -1, 1 } do
			local q = p + right * sideSign * (width / 2 - 0.6)
			rod(parent, "Estaca", q - UP * 9, q + UP * 2.5, 1.2, COLORS.darkWood, Enum.Material.Wood)
		end
	end
	return deck
end

-- Ponte de tábuas com corrimão de corda (pontos já no mundo).
local function bridge(parent: Instance, name: string, a: Vector3, b: Vector3, width: number)
	local m = model(parent, name)
	local dir = (b - a).Unit
	local length = (b - a).Magnitude
	local planks = math.floor(length / 1.8)
	for i = 0, planks do
		local p = a + dir * (i * length / planks)
		part({
			Name = "Tabua",
			Size = Vector3.new(width, 0.5, 1.5),
			CFrame = CFrame.lookAt(p, p + dir),
			Color = if i % 2 == 0 then COLORS.wood else COLORS.darkWood,
			Material = Enum.Material.WoodPlanks,
			Parent = m,
		})
	end
	local right = CFrame.lookAt(a, b).RightVector
	for _, sideSign in { -1, 1 } do
		local off = right * sideSign * (width / 2)
		rod(m, "Corda", a + off + UP * 3, b + off + UP * 3, 0.35, COLORS.thatch)
		for _, p in { a, b } do
			rod(m, "Poste", p + off - UP, p + off + UP * 3.5, 0.8, COLORS.darkWood, Enum.Material.Wood)
		end
		-- Grade invisível para ninguém cair da ponte por acidente.
		local guard = beam(m, "Grade", a + off + UP * 2, b + off + UP * 2, 0.4, 4, COLORS.wood, Enum.Material.Wood)
		guard.Transparency = 1
	end
	return m
end

-- Escada que sobe até o topo de uma falésia, vinda da direção do pixel (fromX, fromY).
local function stairsTo(parent: Instance, cliff: { number }, fromX: number, fromY: number, fromHeight: number)
	local cx, cy, r, top = cliff[1], cliff[2], cliff[3], cliff[4]
	local dx, dy = fromX - cx, fromY - cy
	local dist = math.sqrt(dx * dx + dy * dy)
	local ux, uy = dx / dist, dy / dist

	local rise = top - fromHeight
	local run = rise * 1.5 -- studs
	local edge = Layout.toWorld(cx + ux * r, cy + uy * r, 0)
	local outward = Vector3.new(ux, 0, uy)
	local startPoint = edge + outward * run
	local endPoint = edge - outward * 2

	local m = model(parent, "Escada")
	local steps = math.ceil(rise / 0.9)
	local stepRun = (startPoint - endPoint).Magnitude / steps
	for i = 1, steps do
		local h = fromHeight + rise * i / steps
		local p = startPoint + (endPoint - startPoint) * ((i - 0.5) / steps)
		local height = h - fromHeight + 1
		local center = Vector3.new(p.X, h - height / 2, p.Z)
		part({
			Name = "Degrau",
			Size = Vector3.new(8, height, stepRun + 0.1),
			CFrame = CFrame.lookAt(center, center - outward),
			Color = if i % 2 == 0 then COLORS.wood else COLORS.darkWood,
			Material = Enum.Material.WoodPlanks,
			Parent = m,
		})
	end
	return m
end

---------------------------------------------------------------------------
-- Terreno (vem do IslandLayout)
---------------------------------------------------------------------------

local COAST_ROCKS = {
	{ 215, 340 },
	{ 165, 380 },
	{ 60, 600 },
	{ 130, 610 },
	{ 200, 600 },
	{ 70, 470 },
	{ 600, 720 },
	{ 640, 740 },
	{ 710, 760 },
	{ 830, 790 },
	{ 920, 800 },
	{ 1250, 780 },
	{ 1330, 770 },
	{ 1440, 500 },
	{ 1560, 500 },
	{ 1600, 420 },
	{ 1540, 760 },
	{ 1600, 720 },
	{ 70, 770 },
	{ 150, 790 },
	{ 540, 870 },
	{ 640, 880 },
	{ 290, 220 },
	{ 1595, 300 },
}

local function buildTerrain(map: Folder)
	local land = folder(map, "Terra")

	part({
		Name = "Mar",
		Size = Vector3.new(2048, 1, 2048),
		CFrame = CFrame.new(0, Layout.WATER_LEVEL - 0.5, 0),
		Color = COLORS.water,
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		CanCollide = false,
		Parent = map,
	})
	part({
		Name = "FundoDoMar",
		Size = Vector3.new(2048, 2, 2048),
		CFrame = CFrame.new(0, Layout.SEA_FLOOR - 1, 0),
		Color = COLORS.wetSand,
		Material = Enum.Material.Sand,
		Parent = map,
	})

	for i, d in Layout.LAND do
		local x, y, r, beach = d[1], d[2], d[3], d[4]
		disc(land, "Areia" .. i, x, y, r, Layout.SEA_FLOOR, Layout.SAND_TOP, COLORS.sand, Enum.Material.Sand)
		if not beach then
			disc(
				land,
				"Grama" .. i,
				x,
				y,
				r * Layout.GRASS_RATIO,
				Layout.SAND_TOP - 0.5,
				Layout.GRASS_TOP,
				COLORS.grass,
				Enum.Material.Grass
			)
		end
	end

	for name, c in Layout.CLIFFS do
		local x, y, r, top = c[1], c[2], c[3], c[4]
		disc(land, "Falesia" .. name, x, y, r, 0, top - 1, COLORS.rock, Enum.Material.Rock)
		disc(land, "Topo" .. name, x, y, r * 0.97, top - 1.2, top, COLORS.grass, Enum.Material.Grass)
		-- Pedras soltas em volta da base
		for _ = 1, math.floor(r / 12) do
			local a = rand() * math.pi * 2
			local ex, ey = x + math.cos(a) * (r + 4), y + math.sin(a) * (r + 4)
			if Layout.groundHeight(ex, ey) > Layout.WATER_LEVEL and Layout.groundHeight(ex, ey) < top then
				rock(land, ex, ey, randRange(4, 8), 1)
			end
		end
	end

	for name, pool in Layout.POOLS do
		local x, y, r = pool[1], pool[2], pool[3]
		disc(
			land,
			"Borda" .. name,
			x,
			y,
			r + 4,
			Layout.GRASS_TOP - 0.3,
			Layout.GRASS_TOP + 0.3,
			COLORS.stoneDark,
			Enum.Material.Slate
		)
		local water = disc(
			land,
			"Agua" .. name,
			x,
			y,
			r,
			Layout.GRASS_TOP - 0.2,
			Layout.GRASS_TOP + 0.6,
			COLORS.lightWater,
			Enum.Material.Glass
		)
		water.Transparency = 0.25
		water.CanCollide = false
	end

	for _, p in COAST_ROCKS do
		rock(land, p[1], p[2], randRange(5, 10), 2)
	end
end

local PATHS = {
	{ { 720, 545 }, { 640, 575 }, { 580, 610 } }, -- Praça -> Vila
	{ { 790, 425 }, { 805, 400 } }, -- Praça -> Cachoeira
	{ { 860, 575 }, { 930, 612 }, { 1000, 622 } }, -- Praça -> Bairro
	{ { 885, 505 }, { 1000, 500 }, { 1090, 508 } }, -- Praça -> Campo
	{ { 1100, 455 }, { 1250, 430 }, { 1350, 420 }, { 1390, 405 } }, -- Campo -> Acampamento
	{ { 1250, 430 }, { 1240, 390 } }, -- -> escada do Templo
	{ { 715, 475 }, { 620, 450 }, { 520, 430 }, { 455, 410 } }, -- Praça -> Praia
	{ { 440, 560 }, { 340, 565 }, { 260, 558 }, { 185, 545 } }, -- Vila -> Farol
	{ { 1000, 705 }, { 1080, 762 } }, -- Bairro -> Píer
	{ { 1150, 640 }, { 1250, 620 }, { 1310, 608 } }, -- Bairro -> Parque
	{ { 745, 590 }, { 700, 660 }, { 700, 690 } }, -- Praça -> ponte do sul
	{ { 865, 735 }, { 920, 705 }, { 935, 680 } }, -- ponte do sul -> Bairro
	{ { 455, 400 }, { 445, 378 } }, -- Praia -> escada do Mirante
}

local function buildPaths(map: Folder)
	local paths = folder(map, "Caminhos")
	local y = Layout.GRASS_TOP + 0.08
	for _, line in PATHS do
		for i = 1, #line - 1 do
			local a = Layout.toWorld(line[i][1], line[i][2], y)
			local b = Layout.toWorld(line[i + 1][1], line[i + 1][2], y)
			beam(paths, "Caminho", a, b, 7, 0.4, COLORS.path, Enum.Material.Sand)
			part({
				Name = "Curva",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.4, 7, 7),
				CFrame = CFrame.new(b) * CFrame.Angles(0, 0, math.rad(90)),
				Color = COLORS.path,
				Material = Enum.Material.Sand,
				Parent = paths,
			})
		end
	end
	-- Ponte de madeira sobre o canal do sul
	bridge(
		paths,
		"PonteDoSul",
		Layout.toWorld(722, 703, Layout.GRASS_TOP + 0.3),
		Layout.toWorld(848, 737, Layout.SAND_TOP + 0.3),
		8
	)
end

---------------------------------------------------------------------------
-- Lugares (um builder para cada id de Config.Rooms)
---------------------------------------------------------------------------

local places = {}

function places.Praca(f: Folder)
	local p = Layout.PLAZA
	local top = Layout.GRASS_TOP + 0.25
	disc(f, "Piso", p[1], p[2], p[3], Layout.GRASS_TOP - 0.3, top, COLORS.stone, Enum.Material.Cobblestone)
	disc(f, "Anel", p[1], p[2], p[3] * 0.55, top - 0.1, top + 0.05, COLORS.stoneDark, Enum.Material.Cobblestone)

	-- Fonte com a estátua do pinguim
	local c = CFrame.new(Layout.toWorld(p[1], p[2] - 10, top))
	local vertical = CFrame.Angles(0, 0, math.rad(90))
	part({
		Name = "Bacia",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.5, 28, 28),
		CFrame = c * CFrame.new(0, 1.25, 0) * vertical,
		Color = COLORS.stoneDark,
		Material = Enum.Material.Slate,
		Parent = f,
	})
	part({
		Name = "AguaFonte",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 25, 25),
		CFrame = c * CFrame.new(0, 2.4, 0) * vertical,
		Color = COLORS.lightWater,
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		CanCollide = false,
		Parent = f,
	})
	part({
		Name = "Pedestal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 6, 6),
		CFrame = c * CFrame.new(0, 4, 0) * vertical,
		Color = COLORS.stone,
		Material = Enum.Material.Marble,
		Parent = f,
	})

	local statue = model(f, "EstatuaPinguim")
	local s = c * CFrame.new(0, 7, 0) * CFrame.Angles(0, math.rad(180), 0) -- olha para o sul
	local marble = Enum.Material.Marble
	ellipsoid(part({
		Name = "Corpo",
		Size = Vector3.new(5, 7, 4.6),
		CFrame = s * CFrame.new(0, 3.5, 0),
		Color = COLORS.darkRock,
		Material = marble,
		Parent = statue,
	}))
	ellipsoid(part({
		Name = "Barriga",
		Size = Vector3.new(3.8, 5, 1.6),
		CFrame = s * CFrame.new(0, 3, -1.8),
		Color = COLORS.stone,
		Material = marble,
		Parent = statue,
	}))
	ellipsoid(part({
		Name = "Cabeca",
		Size = Vector3.one * 4,
		CFrame = s * CFrame.new(0, 8, 0),
		Color = COLORS.darkRock,
		Material = marble,
		Parent = statue,
	}))
	part({
		Name = "Bico",
		Size = Vector3.new(1.2, 0.6, 1.6),
		CFrame = s * CFrame.new(0, 7.6, -2.3),
		Color = COLORS.stone,
		Material = marble,
		Parent = statue,
	})
	for _, x in { -1, 1 } do
		ellipsoid(part({
			Name = "Asa",
			Size = Vector3.new(0.8, 4, 2),
			CFrame = s * CFrame.new(x * 2.7, 4, 0) * CFrame.Angles(0, 0, math.rad(-x * 20)),
			Color = COLORS.darkRock,
			Material = marble,
			Parent = statue,
		}))
	end

	-- Bandeiras, postes e bancos
	for i, pos in { { 745, 470 }, { 850, 470 } } do
		local base = at(pos[1], pos[2])
		rod(f, "Mastro", base, base + UP * 14, 0.6, COLORS.darkWood, Enum.Material.Wood)
		part({
			Name = "Bandeira",
			Size = Vector3.new(0.2, 7, 3.5),
			CFrame = CFrame.new(base + Vector3.new(0, 10, 1.9)),
			Color = if i == 1 then Color3.fromRGB(230, 70, 70) else Color3.fromRGB(60, 140, 230),
			Material = Enum.Material.Fabric,
			Parent = f,
		})
	end
	for k = 0, 5 do
		local a = k * math.pi / 3 + 0.3
		lamp(f, p[1] + math.cos(a) * (p[3] - 6), p[2] + math.sin(a) * (p[3] - 6))
	end
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		bench(f, facing(p[1] + math.cos(a) * 50, p[2] + math.sin(a) * 50, p[1], p[2]))
	end
	flowers(f, 720, 455)
	flowers(f, 870, 560)

	local spawnPart = Instance.new("SpawnLocation")
	spawnPart.Name = "Spawn"
	spawnPart.Anchored = true
	spawnPart.Neutral = true
	spawnPart.Duration = 0
	spawnPart.Size = Vector3.new(12, 1, 12)
	spawnPart.CFrame = CFrame.new(Layout.toWorld(790, 600, top + 0.5))
	spawnPart.Transparency = 1
	spawnPart.CanCollide = false
	spawnPart.Parent = f
end

function places.Vila(f: Folder)
	-- Prédios em diagonal, de frente para a pracinha da Vila.
	local sx, sy = 560, 640
	disc(
		f,
		"PracaVila",
		545,
		625,
		45,
		Layout.GRASS_TOP - 0.3,
		Layout.GRASS_TOP + 0.2,
		COLORS.stone,
		Enum.Material.Pavement
	)

	local cafeBase = facing(455, 525, sx, sy)
	building(
		f,
		"Café",
		cafeBase,
		Vector3.new(26, 14, 22),
		Color3.fromRGB(230, 170, 90),
		Color3.fromRGB(150, 80, 50),
		"Café"
	)
	for _, offset in { Vector3.new(-6, 0, -3), Vector3.new(6, 0, -3), Vector3.new(0, 0, 5) } do
		local cf = cafeBase * CFrame.new(offset)
		part({
			Name = "Mesa",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 5, 5),
			CFrame = cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = COLORS.wood,
			Parent = f,
		})
		part({
			Name = "PeMesa",
			Size = Vector3.new(0.8, 3, 0.8),
			CFrame = cf * CFrame.new(0, 1.5, 0),
			Color = COLORS.darkWood,
			Parent = f,
		})
	end

	local shopBase = facing(525, 540, sx, sy)
	local shop = building(
		f,
		"Loja de Cores",
		shopBase,
		Vector3.new(28, 15, 24),
		Color3.fromRGB(70, 130, 220),
		Color3.fromRGB(40, 70, 150),
		"Loja de Cores"
	)
	local counter = part({
		Name = "Balcao",
		Size = Vector3.new(12, 3.5, 3),
		CFrame = shopBase * CFrame.new(0, 1.75, 5),
		Color = COLORS.wood,
		Material = Enum.Material.WoodPlanks,
		Parent = shop,
	})
	counter:AddTag("ShopCounter")
	prompt(counter, "Abrir loja", "Loja de Cores", "Shop")
	part({
		Name = "Prateleira",
		Size = Vector3.new(22, 0.5, 2),
		CFrame = shopBase * CFrame.new(0, 5.1, 10.5),
		Color = COLORS.darkWood,
		Parent = shop,
	})
	for i, item in Config.Colors do
		part({
			Name = "Tinta_" .. item.id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, 1.4, 1.4),
			CFrame = shopBase * CFrame.new(-10 + (i - 1) * 2.5, 6, 10.5) * CFrame.Angles(0, 0, math.rad(90)),
			Color = item.color,
			Parent = shop,
		})
	end

	building(
		f,
		"Sorveteria",
		facing(595, 575, sx, sy + 40),
		Vector3.new(24, 16, 22),
		Color3.fromRGB(245, 235, 220),
		Color3.fromRGB(210, 50, 50),
		"Sorveteria"
	)
	building(
		f,
		"Loja de Surfe",
		facing(645, 612, sx - 20, sy + 40),
		Vector3.new(22, 13, 20),
		Color3.fromRGB(245, 180, 80),
		Color3.fromRGB(120, 80, 50),
		"Surfe"
	)

	umbrella(f, 450, 595, Color3.fromRGB(230, 60, 60))
	umbrella(f, 505, 600, Color3.fromRGB(250, 180, 40))
	umbrella(f, 585, 645, Color3.fromRGB(230, 60, 60))
	lamp(f, 520, 650)
	lamp(f, 610, 640)
	flowers(f, 640, 540)
end

function places.Porto(f: Folder)
	dock(f, 250, 628, 472, 628, 12)
	dock(f, 300, 634, 300, 742, 9)
	dock(f, 420, 634, 420, 702, 9)
	dock(f, 250, 628, 215, 548, 8) -- passarela até o Farol

	fishingSpot(f, 300, 738)
	fishingSpot(f, 420, 698)

	-- Barco branco e vermelho atracado
	local boat = model(f, "Barco")
	local b = CFrame.lookAt(Layout.toWorld(255, 690, 1.5), Layout.toWorld(330, 650, 1.5))
	part({ Name = "Casco", Size = Vector3.new(11, 4, 26), CFrame = b, Color = COLORS.white, Parent = boat })
	part({
		Name = "Faixa",
		Size = Vector3.new(11.2, 1.2, 26.2),
		CFrame = b * CFrame.new(0, -0.8, 0),
		Color = COLORS.red,
		Parent = boat,
	})
	ellipsoid(part({
		Name = "Proa",
		Size = Vector3.new(11, 4, 8),
		CFrame = b * CFrame.new(0, 0, -13),
		Color = COLORS.white,
		Parent = boat,
	}))
	part({
		Name = "Cabine",
		Size = Vector3.new(8, 5, 9),
		CFrame = b * CFrame.new(0, 4.5, 3),
		Color = COLORS.white,
		Parent = boat,
	})
	part({
		Name = "Vidro",
		Size = Vector3.new(8.2, 2, 9.2),
		CFrame = b * CFrame.new(0, 5, 3),
		Color = Color3.fromRGB(60, 90, 130),
		Material = Enum.Material.Glass,
		Parent = boat,
	})
	part({
		Name = "TetoCabine",
		Size = Vector3.new(9, 0.6, 10),
		CFrame = b * CFrame.new(0, 7.3, 3),
		Color = COLORS.red,
		Parent = boat,
	})

	for _, pos in { { 330, 615 }, { 450, 615 } } do
		part({
			Name = "Caixote",
			Size = Vector3.new(4, 4, 4),
			CFrame = CFrame.new(Layout.toWorld(pos[1], pos[2], Layout.SAND_TOP + 2)),
			Color = COLORS.wood,
			Material = Enum.Material.WoodPlanks,
			Parent = f,
		})
	end
	local sign = part({
		Name = "PlacaPesca",
		Size = Vector3.new(1, 8, 1),
		CFrame = CFrame.new(Layout.toWorld(470, 615, Layout.SAND_TOP + 4)),
		Color = COLORS.darkWood,
		Parent = f,
	})
	label(sign, "🎣 Pesca na ponta dos píeres", 6)
end

function places.Praia(f: Folder)
	local shackBase = facing(330, 355, 400, 430)
	hut(f, "CabanaDeSurfe", shackBase, 16, 9)
	local board = part({
		Name = "Placa",
		Size = Vector3.new(6, 2.5, 0.4),
		CFrame = shackBase * CFrame.new(0, 9, -8.5),
		Color = Color3.fromRGB(60, 120, 220),
		Parent = f,
	})
	label(board, "Surfe", 2)

	local boardColors =
		{ Color3.fromRGB(230, 60, 60), Color3.fromRGB(250, 200, 50), COLORS.white, Color3.fromRGB(60, 160, 230) }
	for i, color in boardColors do
		ellipsoid(part({
			Name = "Prancha",
			Size = Vector3.new(2, 9, 0.5),
			CFrame = CFrame.new(at(395 + i * 10, 368, 4.4)) * CFrame.Angles(math.rad(-10), 0, 0),
			Color = color,
			Parent = f,
		}))
	end
	building(
		f,
		"Quiosque",
		facing(468, 362, 440, 430),
		Vector3.new(12, 9, 10),
		Color3.fromRGB(250, 190, 90),
		Color3.fromRGB(150, 90, 50)
	)

	umbrella(f, 430, 410, Color3.fromRGB(60, 120, 230))
	umbrella(f, 452, 432, Color3.fromRGB(230, 70, 70))
	beachChair(f, facing(360, 420, 330, 470), Color3.fromRGB(60, 120, 230))
	beachChair(f, facing(415, 448, 400, 500), Color3.fromRGB(60, 160, 230))
	beachChair(f, facing(440, 455, 430, 510), Color3.fromRGB(240, 120, 60))
	for _, pos in { { 260, 395 }, { 295, 440 } } do
		part({
			Name = "Estrela",
			Size = Vector3.new(1.6, 0.3, 1.6),
			CFrame = CFrame.new(at(pos[1], pos[2], 0.1)),
			Color = Color3.fromRGB(240, 110, 60),
			Parent = f,
		})
	end
end

function places.Farol(f: Folder)
	local m = model(f, "Farol")
	local base = at(100, 500)
	local vertical = CFrame.Angles(0, 0, math.rad(90))
	for i = 0, 6 do
		part({
			Name = "Anel" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(5, 12 - i * 0.6, 12 - i * 0.6),
			CFrame = CFrame.new(base + UP * (2.5 + i * 5)) * vertical,
			Color = if i % 2 == 0 then COLORS.white else COLORS.red,
			Parent = m,
		})
	end
	local h = 35
	part({
		Name = "Varanda",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 13, 13),
		CFrame = CFrame.new(base + UP * (h + 0.5)) * vertical,
		Color = COLORS.darkRock,
		Parent = m,
	})
	local light = part({
		Name = "Luz",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(5, 6, 6),
		CFrame = CFrame.new(base + UP * (h + 3.5)) * vertical,
		Color = Color3.fromRGB(255, 230, 120),
		Material = Enum.Material.Neon,
		Parent = m,
	})
	local glow = Instance.new("PointLight")
	glow.Range = 40
	glow.Brightness = 2
	glow.Color = Color3.fromRGB(255, 230, 150)
	glow.Parent = light
	part({
		Name = "Teto",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 8, 8),
		CFrame = CFrame.new(base + UP * (h + 7)) * vertical,
		Color = COLORS.red,
		Parent = m,
	})
	part({
		Name = "Ponta",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3,
		CFrame = CFrame.new(base + UP * (h + 8.5)),
		Color = COLORS.red,
		Parent = m,
	})
	local door = CFrame.lookAt(base, Layout.toWorld(160, 545, base.Y))
	part({
		Name = "Porta",
		Size = Vector3.new(3.5, 6, 1),
		CFrame = door * CFrame.new(0, 3, -5.8),
		Color = COLORS.darkWood,
		Parent = m,
	})
	label(light, "Farol", 6)
end

function places.Mirante(f: Folder)
	local cliffs = Layout.CLIFFS
	stairsTo(f, cliffs.Mirante1, 440, 380, Layout.GRASS_TOP)
	stairsTo(f, cliffs.Mirante2, 494, 276, cliffs.Mirante1[4])

	-- Deck com cerca nos fundos e nas laterais, telhado de palha e bandeira vermelha.
	local base = facing(640, 145, 600, 260)
	local g = hut(f, "Mirante", base, 18, 10, Color3.fromRGB(160, 110, 60))
	part({
		Name = "Cerca",
		Size = Vector3.new(18, 2.5, 0.5),
		CFrame = base * CFrame.new(0, 2.25, 8.8),
		Color = COLORS.darkWood,
		Parent = g,
	})
	for _, sideSign in { -1, 1 } do
		part({
			Name = "Cerca",
			Size = Vector3.new(0.5, 2.5, 18),
			CFrame = base * CFrame.new(sideSign * 8.8, 2.25, 0),
			Color = COLORS.darkWood,
			Parent = g,
		})
	end
	local flagBase = (base * CFrame.new(5, 0, 5)).Position
	rod(g, "Mastro", flagBase, flagBase + UP * 22, 0.5, COLORS.white)
	local flag = part({
		Name = "Bandeira",
		Size = Vector3.new(0.2, 3.5, 6),
		CFrame = CFrame.new(flagBase + Vector3.new(0, 20, 3)),
		Color = COLORS.red,
		Material = Enum.Material.Fabric,
		Parent = g,
	})
	label(flag, "Mirante", 4)

	flowers(f, 560, 240)
	flowers(f, 700, 240)
end

function places.Cachoeira(f: Folder)
	local cliffs = Layout.CLIFFS
	-- Ponte de corda entre o Mirante e o morro da cachoeira.
	local a = Layout.toWorld(762, 257, cliffs.Mirante3[4] + 0.2)
	local b = Layout.toWorld(816, 250, cliffs.Cachoeira[4] + 0.2)
	local dir = (b - a).Unit
	bridge(f, "PonteDeCorda", a - dir * 3, b + dir * 3, 6)

	-- Lâmina de água descendo do morro até a piscina natural.
	local pool = Layout.POOLS.Cachoeira
	local cliff = cliffs.Cachoeira
	local cx, cy, r, top = cliff[1], cliff[2], cliff[3], cliff[4]
	local dx, dy = pool[1] - cx, pool[2] - cy
	local d = math.sqrt(dx * dx + dy * dy)
	local ex, ey = cx + dx / d * (r + 1), cy + dy / d * (r + 1)
	local fallTop = Layout.toWorld(ex, ey, top + 0.5)
	local fallBottom = Layout.toWorld(ex, ey, Layout.GRASS_TOP)
	local out = Vector3.new(dx / d, 0, dy / d)
	local middle = (fallTop + fallBottom) / 2 + out
	local sheet = part({
		Name = "Cachoeira",
		Size = Vector3.new(24, top - Layout.GRASS_TOP + 0.5, 3),
		CFrame = CFrame.lookAt(middle, middle + out),
		Color = Color3.fromRGB(170, 225, 250),
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		CanCollide = false,
		Parent = f,
	})
	local mist = Instance.new("ParticleEmitter")
	mist.Rate = 25
	mist.Lifetime = NumberRange.new(1, 2)
	mist.Speed = NumberRange.new(2, 4)
	mist.Size = NumberSequence.new(3, 6)
	mist.Transparency = NumberSequence.new(0.5, 1)
	mist.EmissionDirection = Enum.NormalId.Bottom
	mist.Parent = sheet

	local stream = beam(
		f,
		"Riacho",
		Layout.toWorld(cx, cy, top + 0.1),
		fallTop - out - UP * 0.4,
		10,
		0.4,
		COLORS.lightWater,
		Enum.Material.Glass
	)
	stream.CanCollide = false
	part({
		Name = "Espuma",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(14, 4, 14),
		CFrame = CFrame.new(fallBottom + out * 4),
		Color = COLORS.white,
		Transparency = 0.35,
		CanCollide = false,
		Parent = f,
	})
	flowers(f, 760, 390)
	flowers(f, 880, 380)
end

function places.Templo(f: Folder)
	local cliffs = Layout.CLIFFS
	stairsTo(f, cliffs.TemploDegrau, 1240, 386, Layout.GRASS_TOP)
	stairsTo(f, cliffs.Templo, 1192, 338, cliffs.TemploDegrau[4])

	local base = facing(1150, 135, 1150, 300)
	local m = model(f, "Templo")
	local tiers = { Vector3.new(40, 9, 30), Vector3.new(30, 8, 22), Vector3.new(20, 7, 14) }
	local y = 0
	local topTier: BasePart? = nil
	for i, size in tiers do
		topTier = part({
			Name = "Andar" .. i,
			Size = size,
			CFrame = base * CFrame.new(0, y + size.Y / 2, 0),
			Color = COLORS.templeStone,
			Material = Enum.Material.Slate,
			Parent = m,
		})
		part({
			Name = "Musgo",
			Size = Vector3.new(size.X * 0.4, 1, size.Z + 0.4),
			CFrame = base * CFrame.new(-size.X * 0.2, y + size.Y - 0.4, 0),
			Color = COLORS.moss,
			Material = Enum.Material.LeafyGrass,
			Parent = m,
		})
		y += size.Y
	end
	-- Entrada escura, degraus e tochas
	part({
		Name = "Entrada",
		Size = Vector3.new(8, 8, 1),
		CFrame = base * CFrame.new(0, 4, -15.1),
		Color = COLORS.black,
		Parent = m,
	})
	for i = 1, 4 do
		part({
			Name = "Degrau",
			Size = Vector3.new(14, i * 0.9, 2.2),
			CFrame = base * CFrame.new(0, i * 0.45, -15 - (5 - i) * 2.2),
			Color = COLORS.templeStone,
			Material = Enum.Material.Slate,
			Parent = m,
		})
	end
	for _, x in { -6, 6 } do
		local torchBase = (base * CFrame.new(x, 0, -17)).Position
		rod(m, "Tocha", torchBase, torchBase + UP * 6, 1, COLORS.darkWood, Enum.Material.Wood)
		local bowl = part({
			Name = "Braseiro",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.8,
			CFrame = CFrame.new(torchBase + UP * 6.5),
			Color = COLORS.darkRock,
			Parent = m,
		})
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 6
		fire.Parent = bowl
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 160, 60)
		light.Range = 14
		light.Parent = bowl
	end
	if topTier then
		label(topTier, "Templo", 8)
	end

	for _, p in { { 1060, 140 }, { 1240, 150 }, { 1080, 250 }, { 1210, 230 }, { 1050, 200 } } do
		bushTree(f, p[1], p[2], 0.9)
	end
end

function places.Acampamento(f: Folder)
	-- Barracas em "A": duas lonas inclinadas.
	for _, t in { { 1355, 330, Color3.fromRGB(240, 130, 40) }, { 1450, 350, Color3.fromRGB(245, 205, 60) } } do
		local base = facing(t[1], t[2], 1395, 400)
		local m = model(f, "Barraca")
		for _, sideSign in { -1, 1 } do
			part({
				Name = "Lona",
				Size = Vector3.new(0.4, 10, 12),
				CFrame = base * CFrame.new(sideSign * 2.6, 3.8, 0) * CFrame.Angles(0, 0, math.rad(sideSign * 35)),
				Color = t[3],
				Material = Enum.Material.Fabric,
				Parent = m,
			})
		end
	end

	-- Fogueira
	local fireBase = at(1395, 395)
	for k = 0, 2 do
		local a = k * math.pi / 3
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		rod(
			f,
			"Lenha",
			fireBase - dir * 2 + UP * 0.5,
			fireBase + dir * 2 + UP * 0.5,
			0.9,
			COLORS.darkWood,
			Enum.Material.Wood
		)
	end
	local core = part({
		Name = "Fogueira",
		Size = Vector3.one,
		CFrame = CFrame.new(fireBase + UP),
		Transparency = 1,
		CanCollide = false,
		Parent = f,
	})
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 9
	fire.Parent = core
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 60)
	light.Range = 20
	light.Brightness = 2
	light.Parent = core
	for k = 0, 7 do
		local a = k * math.pi / 4
		part({
			Name = "PedraFogueira",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.4,
			CFrame = CFrame.new(fireBase + Vector3.new(math.cos(a) * 3.2, 0.4, math.sin(a) * 3.2)),
			Color = COLORS.darkRock,
			Parent = f,
		})
	end
	for _, pos in { { 1370, 410 }, { 1425, 410 }, { 1395, 425 } } do
		local seat = at(pos[1], pos[2], 0.8)
		local toFire = (fireBase - seat) * Vector3.new(1, 0, 1)
		local side = Vector3.new(-toFire.Z, 0, toFire.X).Unit
		rod(f, "Tronco", seat - side * 3, seat + side * 3, 1.6, COLORS.trunk, Enum.Material.Wood)
	end
	building(
		f,
		"Cabana",
		facing(1315, 372, 1395, 400),
		Vector3.new(14, 10, 12),
		Color3.fromRGB(150, 100, 60),
		Color3.fromRGB(90, 60, 40)
	)
	bushTree(f, 1250, 400, 1.3)
	bushTree(f, 1500, 330, 1.1)

	-- Ponte sobre o lago
	local pond = Layout.POOLS.Lago
	bridge(
		f,
		"PonteDoLago",
		Layout.toWorld(pond[1] - pond[3] - 10, pond[2] + 15, Layout.GRASS_TOP + 0.3),
		Layout.toWorld(pond[1] + pond[3] + 10, pond[2] - 10, Layout.GRASS_TOP + 0.3),
		6
	)
end

function places.Campo(f: Folder)
	local green = Color3.fromRGB(70, 175, 70)
	local c = CFrame.new(Layout.toWorld(1220, 515, Layout.GRASS_TOP + 0.1))
	local length, width = 140, 66
	part({
		Name = "Gramado",
		Size = Vector3.new(length, 0.3, width),
		CFrame = c,
		Color = green,
		Material = Enum.Material.Grass,
		Parent = f,
	})
	local function line(cf: CFrame, size: Vector3)
		part({ Name = "Linha", Size = size, CFrame = c * cf, Color = COLORS.white, CanCollide = false, Parent = f })
	end
	line(CFrame.new(0, 0.18, -width / 2 + 1), Vector3.new(length - 2, 0.1, 0.6))
	line(CFrame.new(0, 0.18, width / 2 - 1), Vector3.new(length - 2, 0.1, 0.6))
	line(CFrame.new(-length / 2 + 1, 0.18, 0), Vector3.new(0.6, 0.1, width - 2))
	line(CFrame.new(length / 2 - 1, 0.18, 0), Vector3.new(0.6, 0.1, width - 2))
	line(CFrame.new(0, 0.18, 0), Vector3.new(0.6, 0.1, width - 2))
	local vertical = CFrame.Angles(0, 0, math.rad(90))
	part({
		Name = "Circulo",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, 18, 18),
		CFrame = c * CFrame.new(0, 0.17, 0) * vertical,
		Color = COLORS.white,
		CanCollide = false,
		Parent = f,
	})
	part({
		Name = "CirculoMeio",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 16.8, 16.8),
		CFrame = c * CFrame.new(0, 0.18, 0) * vertical,
		Color = green,
		CanCollide = false,
		Parent = f,
	})

	for _, sideSign in { -1, 1 } do
		local g = c * CFrame.new(sideSign * (length / 2 - 1.5), 0, 0)
		for _, z in { -6, 6 } do
			rod(f, "Trave", (g * CFrame.new(0, 0, z)).Position, (g * CFrame.new(0, 7, z)).Position, 0.6, COLORS.white)
		end
		rod(f, "Travessao", (g * CFrame.new(0, 7, -6)).Position, (g * CFrame.new(0, 7, 6)).Position, 0.6, COLORS.white)
		part({
			Name = "Rede",
			Size = Vector3.new(3, 7, 12),
			CFrame = g * CFrame.new(sideSign * 1.5, 3.5, 0),
			Color = COLORS.white,
			Transparency = 0.7,
			CanCollide = false,
			Parent = f,
		})
	end
	-- Arquibancada no lado norte
	for i = 1, 3 do
		part({
			Name = "Arquibancada",
			Size = Vector3.new(90, i * 1.6, 3),
			CFrame = c * CFrame.new(0, i * 0.8, -width / 2 - 2 - (4 - i) * 3),
			Color = if i % 2 == 0 then COLORS.wood else COLORS.darkWood,
			Material = Enum.Material.WoodPlanks,
			Parent = f,
		})
	end
	local banners = {
		Color3.fromRGB(230, 60, 60),
		Color3.fromRGB(60, 120, 230),
		Color3.fromRGB(250, 200, 50),
		Color3.fromRGB(60, 180, 90),
	}
	for i = 0, 7 do
		part({
			Name = "Faixa",
			Size = Vector3.new(6, 3, 0.3),
			CFrame = c * CFrame.new(-42 + i * 12, 1.5, width / 2 + 2),
			Color = banners[(i % #banners) + 1],
			Material = Enum.Material.Fabric,
			Parent = f,
		})
	end
	umbrella(f, 1265, 600, Color3.fromRGB(60, 120, 230))
	umbrella(f, 1300, 595, Color3.fromRGB(240, 240, 240))
end

function places.Bairro(f: Folder)
	local houses = {
		{ 850, 650, Color3.fromRGB(240, 150, 80), Color3.fromRGB(200, 70, 50) },
		{ 960, 630, Color3.fromRGB(245, 235, 210), Color3.fromRGB(210, 60, 50) },
		{ 1050, 668, Color3.fromRGB(240, 200, 110), Color3.fromRGB(50, 100, 190) },
		{ 965, 560, Color3.fromRGB(170, 120, 80), Color3.fromRGB(120, 80, 50) },
	}
	for i, h in houses do
		building(f, "Casa" .. i, facing(h[1], h[2], 980, 710), Vector3.new(20, 11, 18), h[3], h[4])
	end
	hut(f, "Gazebo", facing(1120, 620, 1000, 700), 12, 8, Color3.fromRGB(60, 160, 160))
	for _, pos in { { 900, 700 }, { 1010, 600 }, { 1100, 700 } } do
		flowers(f, pos[1], pos[2])
	end
	lamp(f, 930, 690)
	lamp(f, 1040, 715)
end

function places.Parque(f: Folder)
	dock(f, 1345, 625, 1450, 625, 12)
	dock(f, 1420, 735, 1530, 735, 12)
	dock(f, 1450, 625, 1505, 640, 10)

	-- Torre dos tobogãs em palafitas no meio da lagoa
	local towerTop = 16
	local base = CFrame.new(Layout.toWorld(1515, 615, 0))
	local tower = model(f, "TorreTobogas")
	for _, c in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
		local p = base.Position + c * 6
		rod(tower, "Palafita", p - UP * 8, p + UP * (towerTop + 8), 1.2, COLORS.darkWood, Enum.Material.Wood)
	end
	part({
		Name = "Plataforma",
		Size = Vector3.new(14, 1, 14),
		CFrame = base * CFrame.new(0, towerTop, 0),
		Color = COLORS.wood,
		Material = Enum.Material.WoodPlanks,
		Parent = tower,
	})
	thatchRoof(tower, base * CFrame.new(0, towerTop + 9, 0), 18)
	for i = 0, 7 do
		part({
			Name = "Degrau",
			Size = Vector3.new(0.6, 0.4, 5),
			CFrame = base * CFrame.new(-7.6, Layout.SAND_TOP + i * 1.8, 0),
			Color = COLORS.darkWood,
			Parent = tower,
		})
	end
	-- Tobogãs (decorativos por enquanto)
	local p0 = base.Position + UP * towerTop
	local slides = {
		{
			Color3.fromRGB(250, 205, 50),
			{
				p0 + Vector3.new(6, 0, 4),
				Layout.toWorld(1550, 680, 9),
				Layout.toWorld(1520, 730, 3),
				Layout.toWorld(1500, 760, 0.5),
			},
		},
		{
			Color3.fromRGB(50, 120, 230),
			{
				p0 + Vector3.new(-5, 0, 5),
				Layout.toWorld(1470, 650, 10),
				Layout.toWorld(1440, 690, 3),
				Layout.toWorld(1420, 700, 0.5),
			},
		},
	}
	for _, slide in slides do
		local points = slide[2]
		for i = 1, #points - 1 do
			rod(tower, "Toboga", points[i], points[i + 1], 4, slide[1])
		end
	end
	-- Boias
	for _, b in
		{
			{ 1365, 672, Color3.fromRGB(250, 220, 60) },
			{ 1420, 706, Color3.fromRGB(245, 120, 170) },
			{ 1470, 760, Color3.fromRGB(80, 200, 120) },
		}
	do
		local p = Layout.toWorld(b[1], b[2], Layout.WATER_LEVEL + 0.2)
		local vertical = CFrame.Angles(0, 0, math.rad(90))
		part({
			Name = "Boia",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 6, 6),
			CFrame = CFrame.new(p) * vertical,
			Color = b[3],
			Parent = f,
		})
		part({
			Name = "FuroBoia",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.1, 2.6, 2.6),
			CFrame = CFrame.new(p) * vertical,
			Color = COLORS.water,
			Parent = f,
		})
	end
	umbrella(f, 1300, 580, Color3.fromRGB(230, 70, 70))
	beachChair(f, facing(1330, 585, 1400, 680), Color3.fromRGB(250, 200, 60))
end

function places.Pier(f: Folder)
	dock(f, 1085, 772, 1195, 897, 10)
	fishingSpot(f, 1190, 890)

	-- Veleiro
	local boat = model(f, "Veleiro")
	local b = CFrame.lookAt(Layout.toWorld(1262, 862, 1), Layout.toWorld(1300, 840, 1))
	part({
		Name = "Casco",
		Size = Vector3.new(7, 3, 16),
		CFrame = b,
		Color = COLORS.wood,
		Material = Enum.Material.Wood,
		Parent = boat,
	})
	ellipsoid(part({
		Name = "Proa",
		Size = Vector3.new(7, 3, 6),
		CFrame = b * CFrame.new(0, 0, -8),
		Color = COLORS.wood,
		Parent = boat,
	}))
	rod(
		boat,
		"Mastro",
		(b * CFrame.new(0, 1, 0)).Position,
		(b * CFrame.new(0, 20, 0)).Position,
		0.6,
		COLORS.darkWood,
		Enum.Material.Wood
	)
	for i = 0, 3 do
		part({
			Name = "Vela",
			Size = Vector3.new(0.2, 3.5, 9 - i * 1.8),
			CFrame = b * CFrame.new(0, 3.5 + i * 3.6, 4.5 - i * 0.9),
			Color = if i % 2 == 0 then COLORS.white else COLORS.red,
			Material = Enum.Material.Fabric,
			Parent = boat,
		})
	end
	for _, pos in { { 1040, 790 }, { 1150, 760 } } do
		part({
			Name = "Estrela",
			Size = Vector3.new(1.6, 0.3, 1.6),
			CFrame = CFrame.new(at(pos[1], pos[2], 0.1)),
			Color = Color3.fromRGB(240, 110, 60),
			Parent = f,
		})
	end
end

---------------------------------------------------------------------------
-- Coqueiros e árvores espalhados como no mapa
---------------------------------------------------------------------------

local PALMS = {
	-- oeste e praia
	{ 270, 300 },
	{ 250, 335 },
	{ 370, 320 },
	{ 215, 405 },
	{ 60, 470 },
	{ 175, 460 },
	{ 75, 545 },
	{ 400, 500 },
	{ 340, 510 },
	{ 600, 520 },
	{ 655, 520 },
	{ 690, 590 },
	{ 710, 635 },
	-- Mirante
	{ 420, 180 },
	{ 455, 195 },
	{ 520, 180 },
	{ 560, 150 },
	{ 700, 160 },
	{ 730, 205 },
	{ 740, 240 },
	{ 650, 280 },
	{ 560, 300 },
	{ 690, 300 },
	-- centro e norte
	{ 880, 190 },
	{ 940, 200 },
	{ 1000, 230 },
	{ 900, 330 },
	{ 700, 390 },
	{ 860, 420 },
	-- leste
	{ 1260, 120 },
	{ 1310, 150 },
	{ 1380, 220 },
	{ 1500, 380 },
	{ 1540, 400 },
	{ 1330, 470 },
	{ 1380, 560 },
	{ 1560, 580 },
	{ 1570, 650 },
	-- sul
	{ 1060, 560 },
	{ 1080, 600 },
	{ 1180, 680 },
	{ 1240, 700 },
	{ 1280, 700 },
	{ 900, 760 },
	{ 1040, 690 },
	{ 880, 610 },
	{ 760, 640 },
	{ 650, 700 },
	-- ilhotas
	{ 100, 705 },
	{ 575, 820 },
	{ 620, 810 },
	{ 320, 215 },
	{ 110, 255 },
	{ 1590, 285 },
}

local BUSHES = {
	{ 1000, 160 },
	{ 1260, 260 },
	{ 1330, 290 },
	{ 1400, 250 },
	{ 960, 280 },
	{ 1290, 380 },
	{ 1460, 420 },
	{ 820, 240 },
	{ 600, 400 },
	{ 520, 360 },
	-- mata em cima das falésias, como no desenho
	{ 470, 250 },
	{ 520, 300 },
	{ 560, 190 },
	{ 620, 250 },
	{ 680, 220 },
	{ 720, 280 },
	{ 860, 200 },
	{ 910, 260 },
	{ 930, 220 },
	{ 1090, 120 },
	{ 1200, 110 },
	{ 1180, 250 },
	{ 1100, 270 },
	{ 1030, 180 },
}

---------------------------------------------------------------------------

function MapBuilder.build()
	seed = 12345
	local map = Instance.new("Folder")
	map.Name = "Mapa"

	buildTerrain(map)
	buildPaths(map)

	local placesFolder = folder(map, "Lugares")
	for _, room in Config.Rooms do
		local builder = places[room.id]
		if builder then
			builder(folder(placesFolder, room.id))
		end
	end

	local nature = folder(map, "Natureza")
	for _, p in PALMS do
		palm(nature, p[1], p[2])
	end
	for _, p in BUSHES do
		bushTree(nature, p[1], p[2], randRange(0.8, 1.2))
	end

	map.Parent = workspace
	return map
end

-- Água "de verdade" (Terrain), para dar para nadar. Só existe com o jogo
-- rodando, por isso fica fora do mapa gravado no arquivo.
function MapBuilder.addWater()
	local map = workspace:FindFirstChild("Mapa")
	local sea = map and map:FindFirstChild("Mar") :: BasePart?
	if not sea then
		return
	end
	local height = Layout.WATER_LEVEL - Layout.SEA_FLOOR
	workspace.Terrain:FillBlock(
		CFrame.new(sea.Position.X, Layout.SEA_FLOOR + height / 2, sea.Position.Z),
		Vector3.new(sea.Size.X, height, sea.Size.Z),
		Enum.Material.Water
	)
	sea.Transparency = 1
end

return MapBuilder
