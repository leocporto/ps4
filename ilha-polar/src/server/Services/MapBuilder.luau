-- Monta o mapa por código: uma ilha de gelo para cada sala, com prédios,
-- decoração e os pontos interativos (portais, loja, pesca).
--
-- É um mapa "de protótipo" feito com peças simples. Depois dá para trocar
-- cada sala por um modelo feito no Studio sem mexer nos serviços, porque eles
-- só procuram as tags do CollectionService:
--   "Portal"       atributo Destino = id da sala
--   "ShopCounter"  tem um ProximityPrompt com atributo Action = "Shop"
--   "FishingSpot"  tem um ProximityPrompt

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local PLATFORM_THICKNESS = 20

local COLORS = {
	snow = Color3.fromRGB(240, 246, 255),
	ice = Color3.fromRGB(170, 215, 240),
	wood = Color3.fromRGB(125, 85, 55),
	darkWood = Color3.fromRGB(90, 60, 40),
	roofRed = Color3.fromRGB(180, 60, 60),
	roofBlue = Color3.fromRGB(60, 100, 170),
	wall = Color3.fromRGB(235, 220, 190),
	pine = Color3.fromRGB(40, 110, 70),
	water = Color3.fromRGB(40, 120, 170),
	portal = Color3.fromRGB(120, 200, 255),
	stone = Color3.fromRGB(150, 155, 165),
}

---------------------------------------------------------------------------
-- Ajudantes
---------------------------------------------------------------------------

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

local function label(adornee: BasePart, text: string, offsetY: number, size: number?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 140
	gui.AlwaysOnTop = false
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

	if size then
		gui.Size = UDim2.fromOffset(260 * size, 60 * size)
	end
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

-- Pinheiro de bolinhas empilhadas.
local function tree(parent: Instance, base: CFrame, scale: number?)
	local s = scale or 1
	part({
		Name = "Tronco",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4 * s, 1.5 * s, 1.5 * s),
		CFrame = base * CFrame.new(0, 2 * s, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = COLORS.darkWood,
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	for i, d in { 9, 7, 5 } do
		part({
			Name = "Folhas",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * d * s,
			CFrame = base * CFrame.new(0, (2 + i * 3.2) * s, 0),
			Color = COLORS.pine,
			Material = Enum.Material.Grass,
			Parent = parent,
		})
	end
	part({
		Name = "Neve",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3 * s,
		CFrame = base * CFrame.new(0, 13.6 * s, 0),
		Color = COLORS.snow,
		Material = Enum.Material.Snow,
		Parent = parent,
	})
end

-- Prédio oco com porta na frente. `base` fica no chão, no centro do prédio,
-- e a frente aponta para -Z do CFrame (o LookVector).
local function building(parent: Instance, name: string, base: CFrame, size: Vector3, roofColor: Color3)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local t = 1 -- espessura da parede
	local doorW, doorH = 7, 9
	local w, h, d = size.X, size.Y, size.Z

	local function wall(n: string, cf: CFrame, s: Vector3)
		part({
			Name = n,
			Size = s,
			CFrame = base * cf,
			Color = COLORS.wall,
			Material = Enum.Material.WoodPlanks,
			Parent = model,
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
		Parent = model,
	})
	part({
		Name = "Telhado",
		Size = Vector3.new(w + 4, 1.5, d + 4),
		CFrame = base * CFrame.new(0, h + 0.75, 0),
		Color = roofColor,
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	part({
		Name = "NeveTelhado",
		Size = Vector3.new(w + 4.4, 0.8, d + 4.4),
		CFrame = base * CFrame.new(0, h + 1.9, 0),
		Color = COLORS.snow,
		Material = Enum.Material.Snow,
		Parent = model,
	})

	local sign = part({
		Name = "Placa",
		Size = Vector3.new(w * 0.6, 2.5, 0.5),
		CFrame = base * CFrame.new(0, doorH + 1.6, -d / 2 - 0.6),
		Color = COLORS.darkWood,
		Parent = model,
	})
	label(sign, name, 2.5)

	return model
end

local function bench(parent: Instance, base: CFrame)
	part({
		Name = "Assento",
		Size = Vector3.new(8, 0.6, 2.4),
		CFrame = base * CFrame.new(0, 1.8, 0),
		Color = COLORS.wood,
		Material = Enum.Material.WoodPlanks,
		Parent = parent,
	})
	for _, x in { -3.4, 3.4 } do
		part({
			Name = "Pe",
			Size = Vector3.new(0.6, 1.6, 2),
			CFrame = base * CFrame.new(x, 0.8, 0),
			Color = COLORS.darkWood,
			Parent = parent,
		})
	end
end

local function table_(parent: Instance, base: CFrame)
	part({
		Name = "Mesa",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 6, 6),
		CFrame = base * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = COLORS.wood,
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	part({
		Name = "PeMesa",
		Size = Vector3.new(0.8, 3, 0.8),
		CFrame = base * CFrame.new(0, 1.5, 0),
		Color = COLORS.darkWood,
		Parent = parent,
	})
end

---------------------------------------------------------------------------
-- Estrutura comum de toda sala: plataforma, muretas de neve e portais
---------------------------------------------------------------------------

-- `gaps` lista lados sem mureta ("+Z", "-Z", "+X", "-X").
local function platform(folder: Instance, center: Vector3, gaps: { [string]: boolean }?)
	local size = Config.RoomSize
	part({
		Name = "Chao",
		Size = Vector3.new(size, PLATFORM_THICKNESS, size),
		CFrame = CFrame.new(center + Vector3.new(0, -PLATFORM_THICKNESS / 2, 0)),
		Color = COLORS.snow,
		Material = Enum.Material.Snow,
		Parent = folder,
	})

	local sides = {
		["+Z"] = { CFrame.new(0, 1.5, size / 2), Vector3.new(size, 3, 3) },
		["-Z"] = { CFrame.new(0, 1.5, -size / 2), Vector3.new(size, 3, 3) },
		["+X"] = { CFrame.new(size / 2, 1.5, 0), Vector3.new(3, 3, size) },
		["-X"] = { CFrame.new(-size / 2, 1.5, 0), Vector3.new(3, 3, size) },
	}
	for side, def in sides do
		if not (gaps and gaps[side]) then
			part({
				Name = "Mureta" .. side,
				Size = def[2],
				CFrame = CFrame.new(center) * def[1],
				Color = COLORS.ice,
				Material = Enum.Material.Ice,
				Parent = folder,
			})
		end
	end
end

-- Uma fileira de portais (um para cada outra sala) na linha z = `z` da sala.
local function portals(folder: Instance, room, z: number)
	local others = {}
	for _, other in Config.Rooms do
		if other.id ~= room.id then
			table.insert(others, other)
		end
	end

	local spacing = 28
	local startX = -spacing * (#others - 1) / 2
	for i, other in others do
		local pos = room.center + Vector3.new(startX + (i - 1) * spacing, 0, z)
		local pad = part({
			Name = "Portal_" .. other.id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 10, 10),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = COLORS.portal,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Transparency = 0.2,
			Parent = folder,
		})
		pad:SetAttribute("Destino", other.id)
		CollectionService:AddTag(pad, "Portal")
		label(pad, "➜ " .. other.name, 5)

		local light = Instance.new("PointLight")
		light.Color = COLORS.portal
		light.Range = 14
		light.Brightness = 1.5
		light.Parent = pad
	end
end

---------------------------------------------------------------------------
-- Salas
---------------------------------------------------------------------------

local builders = {}

function builders.Vila(folder: Folder, room)
	local c = CFrame.new(room.center)
	platform(folder, room.center)
	portals(folder, room, -68)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnVila"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(room.center + room.spawn + Vector3.new(0, 0.5, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = folder

	-- Café: frente virada para o centro (+Z da sala), por isso gira 180°.
	local cafe = building(
		folder,
		"Café",
		c * CFrame.new(-42, 0, -25) * CFrame.Angles(0, math.rad(180), 0),
		Vector3.new(30, 14, 24),
		COLORS.roofRed
	)
	for _, offset in { Vector3.new(-6, 0, -4), Vector3.new(6, 0, -4), Vector3.new(0, 0, 5) } do
		table_(cafe, c * CFrame.new(Vector3.new(-42, 0, -25) + offset))
	end

	-- Loja de cores
	local shop = building(
		folder,
		"Loja de Cores",
		c * CFrame.new(42, 0, -25) * CFrame.Angles(0, math.rad(180), 0),
		Vector3.new(30, 14, 24),
		COLORS.roofBlue
	)
	local counter = part({
		Name = "Balcao",
		Size = Vector3.new(14, 3.5, 3),
		CFrame = c * CFrame.new(42, 1.75, -30),
		Color = COLORS.wood,
		Material = Enum.Material.WoodPlanks,
		Parent = shop,
	})
	CollectionService:AddTag(counter, "ShopCounter")
	prompt(counter, "Abrir loja", "Loja de Cores", "Shop")
	for i, item in Config.Colors do
		-- Latas de tinta na prateleira, só de enfeite.
		part({
			Name = "Tinta_" .. item.id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, 1.4, 1.4),
			CFrame = c * CFrame.new(42 - 10 + (i - 1) * 2.5, 6, -36.5) * CFrame.Angles(0, 0, math.rad(90)),
			Color = item.color,
			Parent = shop,
		})
	end
	part({
		Name = "Prateleira",
		Size = Vector3.new(26, 0.5, 2),
		CFrame = c * CFrame.new(42, 5.1, -36.5),
		Color = COLORS.darkWood,
		Parent = shop,
	})

	-- Placa central
	local post = part({
		Name = "Poste",
		Size = Vector3.new(1, 10, 1),
		CFrame = c * CFrame.new(0, 5, 5),
		Color = COLORS.darkWood,
		Parent = folder,
	})
	label(post, "Bem-vindo à " .. Config.GameName .. "!", 7, 1.3)

	for _, pos in { Vector3.new(-65, 0, 60), Vector3.new(65, 0, 60), Vector3.new(-70, 0, 10), Vector3.new(70, 0, 10) } do
		tree(folder, c * CFrame.new(pos))
	end
end

function builders.Praca(folder: Folder, room)
	local c = CFrame.new(room.center)
	platform(folder, room.center)
	portals(folder, room, 68)

	-- Palco
	local stage = part({
		Name = "Palco",
		Size = Vector3.new(50, 3, 20),
		CFrame = c * CFrame.new(0, 1.5, -55),
		Color = COLORS.wood,
		Material = Enum.Material.WoodPlanks,
		Parent = folder,
	})
	label(stage, "Palco", 10)
	part({
		Name = "FundoPalco",
		Size = Vector3.new(50, 18, 1),
		CFrame = c * CFrame.new(0, 12, -65),
		Color = COLORS.roofRed,
		Material = Enum.Material.Fabric,
		Parent = folder,
	})

	-- Fonte congelada
	part({
		Name = "Fonte",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 18, 18),
		CFrame = c * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = COLORS.stone,
		Material = Enum.Material.Slate,
		Parent = folder,
	})
	part({
		Name = "GeloFonte",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 15, 15),
		CFrame = c * CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = COLORS.ice,
		Material = Enum.Material.Ice,
		Parent = folder,
	})
	part({
		Name = "Escultura",
		Size = Vector3.new(3, 8, 3),
		CFrame = c * CFrame.new(0, 6, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color = COLORS.ice,
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		Parent = folder,
	})

	-- Fortes de neve para guerra de bolas de neve
	for _, x in { -45, 45 } do
		for i = -1, 1 do
			part({
				Name = "Forte",
				Size = Vector3.new(10, 4.5, 2.5),
				CFrame = c * CFrame.new(x, 2.25, i * 14) * CFrame.Angles(0, math.rad(90), 0),
				Color = COLORS.snow,
				Material = Enum.Material.Snow,
				Parent = folder,
			})
		end
	end

	for _, z in { 25, 40 } do
		bench(folder, c * CFrame.new(-18, 0, z))
		bench(folder, c * CFrame.new(18, 0, z))
	end
	for _, pos in { Vector3.new(-68, 0, -68), Vector3.new(68, 0, -68) } do
		tree(folder, c * CFrame.new(pos), 1.2)
	end
end

function builders.Doca(folder: Folder, room)
	local c = CFrame.new(room.center)
	local size = Config.RoomSize

	-- Só metade da sala é terra firme; a outra metade é mar, com o píer.
	part({
		Name = "Chao",
		Size = Vector3.new(size, PLATFORM_THICKNESS, size / 2),
		CFrame = c * CFrame.new(0, -PLATFORM_THICKNESS / 2, -size / 4),
		Color = COLORS.snow,
		Material = Enum.Material.Snow,
		Parent = folder,
	})
	for _, def in
		{
			{ CFrame.new(0, 1.5, -size / 2), Vector3.new(size, 3, 3) },
			{ CFrame.new(size / 2, 1.5, -size / 4), Vector3.new(3, 3, size / 2) },
			{ CFrame.new(-size / 2, 1.5, -size / 4), Vector3.new(3, 3, size / 2) },
		}
	do
		part({
			Name = "Mureta",
			Size = def[2],
			CFrame = c * def[1],
			Color = COLORS.ice,
			Material = Enum.Material.Ice,
			Parent = folder,
		})
	end
	portals(folder, room, -68)

	-- Píer de madeira
	local pierLength = 60
	part({
		Name = "Pier",
		Size = Vector3.new(14, 1, pierLength),
		CFrame = c * CFrame.new(0, -0.5, pierLength / 2),
		Color = COLORS.wood,
		Material = Enum.Material.WoodPlanks,
		Parent = folder,
	})
	for z = 6, pierLength, 12 do
		for _, x in { -6.5, 6.5 } do
			part({
				Name = "Estaca",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(12, 1.4, 1.4),
				CFrame = c * CFrame.new(x, -5, z) * CFrame.Angles(0, 0, math.rad(90)),
				Color = COLORS.darkWood,
				Material = Enum.Material.Wood,
				Parent = folder,
			})
		end
	end
	for _, x in { -7.3, 7.3 } do
		part({
			Name = "Corrimao",
			Size = Vector3.new(0.6, 3, pierLength - 8),
			CFrame = c * CFrame.new(x, 1.5, pierLength / 2 - 4),
			Color = COLORS.darkWood,
			Parent = folder,
		})
	end

	-- Pontos de pesca na ponta do píer
	for i, x in { -4.5, 0, 4.5 } do
		local spot = part({
			Name = "PontoDePesca" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.4, 2, 2),
			CFrame = c * CFrame.new(x, 1.2, pierLength - 1.5) * CFrame.Angles(0, 0, math.rad(90)),
			Color = COLORS.darkWood,
			Material = Enum.Material.Wood,
			Parent = folder,
		})
		CollectionService:AddTag(spot, "FishingSpot")
		prompt(spot, "Pescar", "Ponto de pesca", "Fish")
	end

	local sign = part({
		Name = "PlacaPesca",
		Size = Vector3.new(1, 8, 1),
		CFrame = c * CFrame.new(9, 4, 4),
		Color = COLORS.darkWood,
		Parent = folder,
	})
	label(sign, "🎣 Pesca no fim do píer", 6)

	-- Caixotes
	for i, pos in { Vector3.new(-30, 0, -10), Vector3.new(-27, 0, -14), Vector3.new(-28.5, 4, -12) } do
		part({
			Name = "Caixote" .. i,
			Size = Vector3.new(4, 4, 4),
			CFrame = c * CFrame.new(pos + Vector3.new(0, 2, 0)),
			Color = COLORS.wood,
			Material = Enum.Material.WoodPlanks,
			Parent = folder,
		})
	end
end

function builders.Montanha(folder: Folder, room)
	local c = CFrame.new(room.center)
	platform(folder, room.center)
	portals(folder, room, -68)

	-- Rampa que sobe em direção a +Z (lado alto da WedgePart), com um patamar no topo.
	part({
		ClassName = "WedgePart",
		Name = "Rampa",
		Size = Vector3.new(50, 30, 60),
		CFrame = c * CFrame.new(0, 15, 35),
		Color = COLORS.snow,
		Material = Enum.Material.Snow,
		Parent = folder,
	})
	local top = part({
		Name = "Topo",
		Size = Vector3.new(50, 30, 14),
		CFrame = c * CFrame.new(0, 15, 72),
		Color = COLORS.snow,
		Material = Enum.Material.Snow,
		Parent = folder,
	})
	label(top, "🛷 Corrida de trenó — em breve!", 20, 1.3)

	for _, pos in
		{
			Vector3.new(-50, 0, 30),
			Vector3.new(50, 0, 30),
			Vector3.new(-60, 0, -20),
			Vector3.new(60, 0, -20),
			Vector3.new(-45, 0, 65),
		}
	do
		tree(folder, c * CFrame.new(pos), 1.3)
	end
end

---------------------------------------------------------------------------

function MapBuilder.build()
	local map = Instance.new("Folder")
	map.Name = "Mapa"

	-- Mar que fica embaixo de todas as ilhas.
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, room in Config.Rooms do
		minX = math.min(minX, room.center.X)
		maxX = math.max(maxX, room.center.X)
		minZ = math.min(minZ, room.center.Z)
		maxZ = math.max(maxZ, room.center.Z)
	end
	local margin = Config.RoomSize * 2
	part({
		Name = "Mar",
		Size = Vector3.new(math.min(maxX - minX + margin * 2, 2048), 1, math.min(maxZ - minZ + margin * 2, 2048)),
		CFrame = CFrame.new((minX + maxX) / 2, Config.OceanHeight, (minZ + maxZ) / 2),
		Color = COLORS.water,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		CanCollide = false,
		Parent = map,
	})

	for _, room in Config.Rooms do
		local folder = Instance.new("Folder")
		folder.Name = room.id
		folder.Parent = map
		local builder = builders[room.id]
		if builder then
			builder(folder, room)
		else
			platform(folder, room.center)
			portals(folder, room, -68)
		end
	end

	map.Parent = workspace
	return map
end

return MapBuilder
