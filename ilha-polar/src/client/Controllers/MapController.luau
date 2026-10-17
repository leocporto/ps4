-- Mapa da ilha. Abre pelo botão redondo no canto esquerdo ou pela tecla M.
--
-- Mostra a imagem oficial do mapa (Config.MapImage) com um ponto clicável em
-- cada lugar; clicar teleporta. Enquanto a imagem não foi enviada ao Roblox,
-- desenha a ilha a partir do IslandLayout, nas mesmas posições.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.IslandLayout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Hud = require(script.Parent.Hud)

local player = Players.LocalPlayer
local create = Hud.create

local MapController = {}

local PALETTE = {
	oceanTop = Color3.fromRGB(70, 175, 235),
	oceanBottom = Color3.fromRGB(25, 115, 200),
	shallow = Color3.fromRGB(130, 215, 240),
	sand = Color3.fromRGB(240, 220, 160),
	grass = Color3.fromRGB(110, 190, 70),
	rock = Color3.fromRGB(120, 125, 135),
	stone = Color3.fromRGB(205, 195, 190),
	water = Color3.fromRGB(120, 210, 240),
	wood = Color3.fromRGB(130, 85, 50),
	pill = Color3.fromRGB(25, 50, 90),
}

local IMAGE = Layout.IMAGE_SIZE

-- Pixel da imagem -> posição relativa dentro do quadro do mapa.
local function rel(x: number, y: number): UDim2
	return UDim2.fromScale(x / IMAGE.X, y / IMAGE.Y)
end

-- Círculo de raio `r` pixels da imagem (continua redondo porque o quadro tem
-- a mesma proporção da imagem).
local function circle(parent: Instance, x: number, y: number, r: number, color: Color3, z: number): Frame
	return create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = rel(x, y),
		Size = UDim2.fromScale(r * 2 / IMAGE.X, r * 2 / IMAGE.Y),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	}, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
end

-- Desenho simplificado da ilha (usado só sem a imagem oficial).
local function drawFallback(board: Frame)
	create("UIGradient", {
		Color = ColorSequence.new(PALETTE.oceanTop, PALETTE.oceanBottom),
		Rotation = 90,
		Parent = board,
	})
	for _, land in Layout.LAND do
		circle(board, land[1], land[2], land[3] + 10, PALETTE.shallow, 1).BackgroundTransparency = 0.4
	end
	for _, land in Layout.LAND do
		circle(board, land[1], land[2], land[3], PALETTE.sand, 2)
	end
	for _, land in Layout.LAND do
		if not land[4] then
			circle(board, land[1], land[2], land[3] * Layout.GRASS_RATIO, PALETTE.grass, 3)
		end
	end
	for _, cliff in Layout.CLIFFS do
		circle(board, cliff[1], cliff[2] + 6, cliff[3], PALETTE.rock, 4)
		local top = circle(board, cliff[1], cliff[2], cliff[3] * 0.95, PALETTE.grass, 4)
		top.BackgroundColor3 = PALETTE.grass:Lerp(Color3.new(1, 1, 1), math.min(cliff[4] / 80, 0.4))
	end
	for _, pool in Layout.POOLS do
		circle(board, pool[1], pool[2], pool[3], PALETTE.water, 5)
	end
	local plaza = Layout.PLAZA
	circle(board, plaza[1], plaza[2], plaza[3], PALETTE.stone, 5)
end

-- Ponto clicável de um lugar.
local function placePin(board: Frame, room, alwaysShowName: boolean): TextButton
	local button = create("TextButton", {
		Name = room.id,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = rel(room.map.X, room.map.Y),
		Size = UDim2.fromScale(0.042, 0.042),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.3,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 10,
		Parent = board,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		create("UIStroke", { Name = "Borda", Thickness = 3, Color = PALETTE.pill }),
	})
	local zoom = create("UIScale", { Parent = button })
	Hud.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		Text = room.icon,
		ZIndex = 11,
		Parent = button,
	})

	local tag = create("Frame", {
		Name = "Nome",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.fromScale(3.4, 0.6),
		BackgroundColor3 = PALETTE.pill,
		BackgroundTransparency = 0.05,
		Visible = alwaysShowName,
		ZIndex = 12,
		Parent = button,
	}, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	Hud.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.8),
		Text = room.name,
		ZIndex = 13,
		Parent = tag,
	})

	local grow = TweenInfo.new(0.12)
	button.MouseEnter:Connect(function()
		tag.Visible = true
		TweenService:Create(zoom, grow, { Scale = 1.2 }):Play()
	end)
	button.MouseLeave:Connect(function()
		tag.Visible = alwaysShowName
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
		Hud.panel("Mapa", "🗺️ Mapa da " .. Config.GameName, UDim2.fromScale(0.92, 0.9), Vector2.new(1280, 820))

	local board = create("Frame", {
		Name = "Ilha",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 1, -36),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Parent = content,
	}, {
		create("UIAspectRatioConstraint", { AspectRatio = IMAGE.X / IMAGE.Y }),
		create("UICorner", { CornerRadius = UDim.new(0, 14) }),
	})
	local boardZoom = create("UIScale", { Parent = board })

	if Config.MapImage ~= "" then
		create("ImageLabel", {
			Name = "Imagem",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Config.MapImage,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = 1,
			Parent = board,
		}, { create("UICorner", { CornerRadius = UDim.new(0, 14) }) })
	else
		drawFallback(board)
	end

	local info = Hud.label({
		Name = "Info",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 30),
		Font = Enum.Font.GothamMedium,
		Text = "",
		Parent = content,
	})
	local defaultInfo = "Clique em um lugar para ir até lá."
	info.Text = defaultInfo

	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local pins: { [string]: TextButton } = {}
	for _, room in Config.Rooms do
		local button = placePin(board, room, touchOnly)
		pins[room.id] = button
		button.MouseEnter:Connect(function()
			info.Text = ("%s %s: %s"):format(room.icon, room.name, room.description)
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

	-- Marcador "Você está aqui", flutuando em cima do lugar atual.
	local here = create("Frame", {
		Name = "VoceEstaAqui",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromScale(0.15, 0.05),
		BackgroundColor3 = Hud.colors.accent,
		ZIndex = 20,
		Visible = false,
		Parent = board,
	}, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	Hud.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.75),
		Text = "📍 Você está aqui",
		TextColor3 = PALETTE.pill,
		ZIndex = 21,
		Parent = here,
	})
	local bob: Tween? = nil

	local function updateHere()
		local room = Config.RoomsById[player:GetAttribute("Room")]
		if bob then
			bob:Cancel()
			bob = nil
		end
		for id, button in pins do
			local stroke = button:FindFirstChild("Borda") :: UIStroke?
			if stroke then
				stroke.Color = if room and id == room.id then Hud.colors.accent else PALETTE.pill
				stroke.Thickness = if room and id == room.id then 5 else 3
			end
		end
		if not room then
			here.Visible = false
			return
		end
		local top = rel(room.map.X, room.map.Y) - UDim2.fromScale(0, 0.06)
		here.Position = top
		here.Visible = true
		local tween = TweenService:Create(
			here,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = top - UDim2.fromScale(0, 0.012) }
		)
		tween:Play()
		bob = tween
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
		boardZoom.Scale = 0.94
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
