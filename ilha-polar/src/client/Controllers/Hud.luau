-- Interface base: moedas, nome da sala, dicas, avisos (toasts) e janelas.
--
-- Em primeira pessoa o mouse fica preso no centro da tela. Toda janela tem um
-- botão com `Modal = true`, que solta o mouse enquanto ela está aberta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local Hud = {}

Hud.colors = {
	panel = Color3.fromRGB(20, 45, 80),
	panelLight = Color3.fromRGB(40, 80, 130),
	accent = Color3.fromRGB(255, 200, 40),
	text = Color3.fromRGB(255, 255, 255),
	good = Color3.fromRGB(70, 190, 100),
	bad = Color3.fromRGB(220, 70, 70),
}

local gui: ScreenGui
local toastList: Frame
local openPanels: { [string]: boolean } = {}
local busyReasons: { [string]: boolean } = {}

function Hud.create(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	instance.Parent = parent
	return instance
end
local create = Hud.create

function Hud.corner(radius: number?): UICorner
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Hud.label(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or Hud.colors.text
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	return create("TextLabel", props)
end

function Hud.button(props: { [string]: any }): TextButton
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or Hud.colors.text
	props.BackgroundColor3 = props.BackgroundColor3 or Hud.colors.panelLight
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	props.AutoButtonColor = true
	return create("TextButton", props, { Hud.corner(10) })
end

-- "Ocupado" = algo que deve bloquear a bola de neve (janela aberta, pescando...).
function Hud.setBusy(reason: string, value: boolean)
	busyReasons[reason] = value or nil
end

function Hud.isBusy(): boolean
	return next(busyReasons) ~= nil
end

function Hud.toast(text: string, color: Color3?)
	local item = Hud.label({
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 0.15,
		BackgroundColor3 = color or Hud.colors.panel,
		Text = text,
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		Parent = toastList,
	})
	Hud.corner(10).Parent = item
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = item,
	})

	task.delay(3.5, function()
		local fade = TweenInfo.new(0.4)
		TweenService:Create(item, fade, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		task.wait(0.4)
		item:Destroy()
	end)
end

-- Janela centralizada com título e botão de fechar.
-- Retorna o frame de conteúdo e funções para abrir/fechar.
function Hud.panel(name: string, title: string, size: UDim2)
	local frame = create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = Hud.colors.panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	}, { Hud.corner(16) })
	create("UISizeConstraint", { MaxSize = Vector2.new(720, 560), Parent = frame })

	Hud.label({
		Size = UDim2.new(1, -80, 0, 44),
		Position = UDim2.fromOffset(16, 8),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Hud.colors.accent,
		Parent = frame,
	})

	local close = Hud.button({
		Name = "Fechar",
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, -54, 0, 8),
		Text = "X",
		BackgroundColor3 = Hud.colors.bad,
		Modal = true, -- solta o mouse da primeira pessoa enquanto a janela está aberta
		Parent = frame,
	})

	local content = create("Frame", {
		Name = "Conteudo",
		Size = UDim2.new(1, -32, 1, -76),
		Position = UDim2.fromOffset(16, 60),
		BackgroundTransparency = 1,
		Parent = frame,
	})

	local controls = {}
	function controls.open()
		for other in openPanels do
			if other ~= name then
				local otherFrame = gui:FindFirstChild(other)
				if otherFrame then
					otherFrame.Visible = false
				end
				openPanels[other] = nil
			end
		end
		frame.Visible = true
		openPanels[name] = true
		Hud.setBusy("panel", true)
	end
	function controls.close()
		frame.Visible = false
		openPanels[name] = nil
		Hud.setBusy("panel", next(openPanels) ~= nil)
	end
	function controls.toggle()
		if frame.Visible then
			controls.close()
		else
			controls.open()
		end
	end
	function controls.isOpen()
		return frame.Visible
	end

	close.Activated:Connect(controls.close)
	return content, controls
end

function Hud.gui(): ScreenGui
	return gui
end

function Hud.start()
	gui = create("ScreenGui", {
		Name = "IlhaPolarHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Moedas (canto superior direito)
	local coins = Hud.label({
		Name = "Moedas",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(170, 44),
		BackgroundTransparency = 0.2,
		BackgroundColor3 = Hud.colors.panel,
		TextColor3 = Hud.colors.accent,
		Text = "🪙 ...",
		Parent = gui,
	})
	Hud.corner(12).Parent = coins

	local function updateCoins()
		local value = player:GetAttribute("Coins")
		coins.Text = if value then ("🪙 %d"):format(value) else "🪙 ..."
	end
	player:GetAttributeChangedSignal("Coins"):Connect(updateCoins)
	updateCoins()

	-- Sala atual (topo, centro)
	local room = Hud.label({
		Name = "Sala",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(260, 40),
		BackgroundTransparency = 0.35,
		BackgroundColor3 = Hud.colors.panel,
		Text = "",
		Parent = gui,
	})
	Hud.corner(12).Parent = room

	local function updateRoom()
		local info = Config.RoomsById[player:GetAttribute("Room")]
		room.Text = if info then "📍 " .. info.name else Config.GameName
	end
	player:GetAttributeChangedSignal("Room"):Connect(updateRoom)
	updateRoom()

	-- Mira (primeira pessoa)
	create("Frame", {
		Name = "Mira",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.2,
		Parent = gui,
	}, { Hud.corner(3) })

	-- Dicas (rodapé). No celular os botões de toque já mostram as ações.
	if UserInputService.KeyboardEnabled then
		Hud.label({
			Name = "Dicas",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Size = UDim2.fromOffset(560, 26),
			Text = "Clique: bola de neve   •   M: mapa   •   E: interagir   •   /: chat",
			TextTransparency = 0.15,
			TextStrokeTransparency = 0.5,
			Parent = gui,
		})
	end

	toastList = create("Frame", {
		Name = "Avisos",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(460, 300),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	Remotes.event("Notify").OnClientEvent:Connect(function(text)
		Hud.toast(text)
	end)

	Hud.toast(("Bem-vindo à %s! Explore, pesque e jogue bolas de neve."):format(Config.GameName))
end

return Hud
