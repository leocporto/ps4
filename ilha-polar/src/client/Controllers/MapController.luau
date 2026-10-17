-- Mapa ilustrado da ilha. Abre pelo botão redondo no canto esquerdo ou pela tecla M.
--
-- O desenho é feito só com Frames (sem imagens), então funciona sem enviar
-- nenhum asset para o Roblox. Cada lugar é um ícone clicável que teleporta;
-- lugares que ainda não existem aparecem com cadeado.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Hud = require(script.Parent.Hud)

local player = Players.LocalPlayer
local create = Hud.create

local MapController = {}

local PALETTE = {
	oceanTop = Color3.fromRGB(70, 175, 235),
	oceanBottom = Color3.fromRGB(25, 105, 190),
	shallow = Color3.fromRGB(140, 220, 245),
	snow = Color3.fromRGB(240, 246, 255),
	rock = Color3.fromRGB(140, 160, 195),
	rockDark = Color3.fromRGB(110, 128, 165),
	wood = Color3.fromRGB(130, 85, 50),
	ice = Color3.fromRGB(175, 225, 245),
	pill = Color3.fromRGB(25, 50, 90),
	locked = Color3.fromRGB(190, 195, 205),
}

-- Forma da ilha: vários "comprimidos" sobrepostos dão um contorno irregular.
-- { posição do centro, tamanho }, tudo em fração do quadro do mapa.
local ISLAND = {
	{ Vector2.new(0.47, 0.55), Vector2.new(0.56, 0.56) },
	{ Vector2.new(0.28, 0.52), Vector2.new(0.32, 0.46) },
	{ Vector2.new(0.68, 0.55), Vector2.new(0.36, 0.46) },
	{ Vector2.new(0.42, 0.32), Vector2.new(0.4, 0.3) },
	{ Vector2.new(0.55, 0.77), Vector2.new(0.4, 0.24) },
	{ Vector2.new(0.14, 0.56), Vector2.new(0.17, 0.18) },
	{ Vector2.new(0.82, 0.5), Vector2.new(0.16, 0.26) },
	{ Vector2.new(0.32, 0.76), Vector2.new(0.22, 0.22) },
}

-- Montanhas: { centro, altura (fração da altura do mapa) }
local MOUNTAINS = {
	{ Vector2.new(0.27, 0.28), 0.13 },
	{ Vector2.new(0.37, 0.22), 0.2 },
	{ Vector2.new(0.49, 0.19), 0.24 },
	{ Vector2.new(0.6, 0.25), 0.15 },
}

local TREES = {
	Vector2.new(0.2, 0.42),
	Vector2.new(0.24, 0.63),
	Vector2.new(0.22, 0.38),
	Vector2.new(0.38, 0.46),
	Vector2.new(0.4, 0.62),
	Vector2.new(0.62, 0.62),
	Vector2.new(0.66, 0.69),
	Vector2.new(0.63, 0.31),
	Vector2.new(0.8, 0.37),
	Vector2.new(0.86, 0.56),
	Vector2.new(0.68, 0.58),
	Vector2.new(0.43, 0.84),
	Vector2.new(0.68, 0.84),
	Vector2.new(0.45, 0.68),
}

local function scale(v: Vector2): UDim2
	return UDim2.fromScale(v.X, v.Y)
end

local function blob(parent: Instance, center: Vector2, size: Vector2, color: Color3, z: number)
	return create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = scale(center),
		Size = scale(size),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	}, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
end

local function emoji(parent: Instance, text: string, center: Vector2, size: Vector2, z: number)
	return Hud.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = scale(center),
		Size = scale(size),
		Text = text,
		ZIndex = z,
		Parent = parent,
	})
end

-- Desenha a ilha (tudo que não é clicável).
local function drawIsland(board: Frame)
	-- Água rasa em volta e a ilha por cima.
	for _, piece in ISLAND do
		blob(board, piece[1], piece[2] * Vector2.new(1.12, 1.16), PALETTE.shallow, 1).BackgroundTransparency = 0.3
	end
	for _, piece in ISLAND do
		blob(board, piece[1], piece[2], PALETTE.snow, 2)
	end

	-- Montanhas: quadrados girados 45° viram picos; a ponta de cima ganha neve
	-- e a base fica escondida atrás de uma faixa de neve desenhada por cima.
	for _, mountain in MOUNTAINS do
		local peak = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = scale(mountain[1]),
			Size = UDim2.fromScale(mountain[2], mountain[2]),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Rotation = 45,
			BackgroundColor3 = PALETTE.rock,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = board,
		}, {
			create("UIGradient", {
				Color = ColorSequence.new(PALETTE.rock, PALETTE.rockDark),
				Rotation = 45,
			}),
		})
		-- O canto superior esquerdo do quadrado vira o topo depois de girar.
		create("Frame", {
			Size = UDim2.fromScale(0.42, 0.42),
			BackgroundColor3 = PALETTE.snow,
			BorderSizePixel = 0,
			Parent = peak,
		})
	end
	blob(board, Vector2.new(0.43, 0.35), Vector2.new(0.46, 0.13), PALETTE.snow, 4)

	-- Lago congelado e píer da doca.
	blob(board, Vector2.new(0.8, 0.7), Vector2.new(0.11, 0.09), PALETTE.ice, 4)
	create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.22, 0.82),
		Size = UDim2.fromScale(0.02, 0.12),
		BackgroundColor3 = PALETTE.wood,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = board,
	})
	create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.22, 0.93),
		Size = UDim2.fromScale(0.05, 0.02),
		BackgroundColor3 = PALETTE.wood,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = board,
	})
	emoji(board, "⛵", Vector2.new(0.13, 0.86), Vector2.new(0.05, 0.08), 4)

	for _, position in TREES do
		emoji(board, "🌲", position, Vector2.new(0.035, 0.06), 5)
	end

	-- Detalhes do mar.
	for _, position in
		{ Vector2.new(0.08, 0.2), Vector2.new(0.9, 0.85), Vector2.new(0.12, 0.85), Vector2.new(0.92, 0.2) }
	do
		local wave = emoji(board, "〰", position, Vector2.new(0.06, 0.05), 1)
		wave.TextColor3 = PALETTE.shallow
		wave.TextTransparency = 0.3
	end
	emoji(board, "🧭", Vector2.new(0.93, 0.1), Vector2.new(0.06, 0.1), 6)
end

-- Um ícone de lugar no mapa. Retorna o botão.
local function placePin(
	board: Frame,
	name: string,
	icon: string,
	position: Vector2,
	color: Color3,
	locked: boolean
): TextButton
	local button = create("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = scale(position),
		Size = UDim2.fromScale(0.13, 0.19),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 8,
		Parent = board,
	})
	local zoom = create("UIScale", { Parent = button })

	local circle = create("Frame", {
		Name = "Icone",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.7, 0.7),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = if locked then PALETTE.locked else Color3.new(1, 1, 1),
		Parent = button,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		create("UIStroke", {
			Thickness = 3,
			Color = if locked then PALETTE.rockDark else color,
		}),
	})
	Hud.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		Text = icon,
		TextTransparency = if locked then 0.45 else 0,
		Parent = circle,
	})
	if locked then
		Hud.label({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1.05, 1.05),
			Size = UDim2.fromScale(0.42, 0.42),
			Text = "🔒",
			Parent = circle,
		})
	end

	local tag = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1.2, 0.27),
		BackgroundColor3 = if locked then PALETTE.rockDark else PALETTE.pill,
		BackgroundTransparency = 0.1,
		Parent = button,
	}, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	Hud.label({
		Size = UDim2.fromScale(0.9, 0.8),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Text = name,
		Parent = tag,
	})

	local grow = TweenInfo.new(0.12)
	button.MouseEnter:Connect(function()
		TweenService:Create(zoom, grow, { Scale = 1.15 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(zoom, grow, { Scale = 1 }):Play()
	end)

	return button
end

-- Botão redondo do mapa, no canto esquerdo da tela.
local function createMapButton(onClick: () -> ())
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local button = create("TextButton", {
		Name = "BotaoMapa",
		-- No celular o canto de baixo é do analógico; o botão sobe para o meio da lateral.
		AnchorPoint = if touchOnly then Vector2.new(0, 0.5) else Vector2.new(0, 1),
		Position = if touchOnly then UDim2.new(0, 16, 0.45, 0) else UDim2.new(0, 20, 1, -48),
		Size = UDim2.fromOffset(88, 88),
		BackgroundColor3 = Color3.fromRGB(255, 236, 190),
		AutoButtonColor = false,
		Text = "",
		Parent = Hud.gui(),
	}, {
		create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		create("UIStroke", { Thickness = 4, Color = PALETTE.wood }),
	})
	local zoom = create("UIScale", { Parent = button })
	Hud.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromScale(0.68, 0.68),
		Text = "🗺️",
		Parent = button,
	})
	local caption = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(if touchOnly then 64 else 96, 24),
		BackgroundColor3 = PALETTE.pill,
		Parent = button,
	}, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	Hud.label({
		Size = UDim2.fromScale(0.9, 0.85),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Text = if touchOnly then "Mapa" else "Mapa (M)",
		Parent = caption,
	})

	local grow = TweenInfo.new(0.12)
	button.MouseEnter:Connect(function()
		TweenService:Create(zoom, grow, { Scale = 1.08 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(zoom, grow, { Scale = 1 }):Play()
	end)
	button.Activated:Connect(onClick)
end

function MapController.start()
	local content, panel =
		Hud.panel("Mapa", "🗺️ Mapa da " .. Config.GameName, UDim2.fromScale(0.86, 0.86), Vector2.new(1100, 760))

	local board = create("Frame", {
		Name = "Ilha",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 1, -40),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Parent = content,
	}, {
		create("UIAspectRatioConstraint", { AspectRatio = 1.6 }),
		create("UICorner", { CornerRadius = UDim.new(0, 14) }),
		create("UIGradient", {
			Color = ColorSequence.new(PALETTE.oceanTop, PALETTE.oceanBottom),
			Rotation = 90,
		}),
	})
	local boardZoom = create("UIScale", { Parent = board })

	local info = Hud.label({
		Name = "Info",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 32),
		Font = Enum.Font.GothamMedium,
		Text = "",
		Parent = content,
	})
	local defaultInfo = "Clique em um lugar para ir até lá."
	info.Text = defaultInfo

	drawIsland(board)

	-- Lugares de verdade
	local pins: { [string]: TextButton } = {}
	for _, room in Config.Rooms do
		local button = placePin(board, room.name, room.map.icon, room.map.position, room.map.color, false)
		pins[room.id] = button
		button.MouseEnter:Connect(function()
			info.Text = ("%s %s: %s"):format(room.map.icon, room.name, room.description)
		end)
		button.MouseLeave:Connect(function()
			info.Text = defaultInfo
		end)
		button.Activated:Connect(function()
			if player:GetAttribute("Room") == room.id then
				Hud.toast("Você já está aqui!")
				return
			end
			Remotes.event("RequestRoom"):FireServer(room.id)
			panel.close()
		end)
	end

	-- Lugares futuros
	for _, place in Config.MapComingSoon do
		local button = placePin(board, place.name, place.icon, place.position, PALETTE.locked, true)
		button.MouseEnter:Connect(function()
			info.Text = ("%s %s: em breve!"):format(place.icon, place.name)
		end)
		button.MouseLeave:Connect(function()
			info.Text = defaultInfo
		end)
		button.Activated:Connect(function()
			Hud.toast(("%s ainda está em construção. Em breve!"):format(place.name))
		end)
	end

	-- Marcador "Você está aqui", que flutua em cima do lugar atual.
	local here = create("Frame", {
		Name = "VoceEstaAqui",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromScale(0.16, 0.055),
		BackgroundColor3 = Hud.colors.accent,
		ZIndex = 10,
		Visible = false,
		Parent = board,
	}, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	Hud.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.75),
		Text = "📍 Você está aqui",
		TextColor3 = PALETTE.pill,
		Parent = here,
	})
	local bob: Tween? = nil

	local function updateHere()
		local room = Config.RoomsById[player:GetAttribute("Room")]
		if bob then
			bob:Cancel()
			bob = nil
		end
		if not room then
			here.Visible = false
			return
		end
		local top = UDim2.fromScale(room.map.position.X, room.map.position.Y - 0.1)
		here.Position = top
		here.Visible = true
		local tween = TweenService:Create(
			here,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = top - UDim2.fromScale(0, 0.015) }
		)
		tween:Play()
		bob = tween

		for id, button in pins do
			local circle = button:FindFirstChild("Icone")
			local stroke = circle and circle:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Thickness = if id == room.id then 5 else 3
			end
		end
	end
	player:GetAttributeChangedSignal("Room"):Connect(updateHere)
	updateHere()

	local function open()
		if panel.isOpen() then
			panel.close()
			return
		end
		if Hud.isBusy() then
			return -- pescando ou com outra janela aberta
		end
		panel.open()
		boardZoom.Scale = 0.92
		TweenService:Create(boardZoom, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end

	createMapButton(open)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			open()
		end
	end)
end

return MapController
