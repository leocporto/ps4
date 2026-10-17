-- Mapa da ilha: lista as salas e teleporta ao clicar. Abre com M ou pelo botão.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Hud = require(script.Parent.Hud)

local player = Players.LocalPlayer

local MapController = {}

function MapController.start()
	local content, panel = Hud.panel("Mapa", "🗺 Mapa da " .. Config.GameName, UDim2.fromScale(0.6, 0.6))

	Hud.create("UIGridLayout", {
		CellSize = UDim2.new(0.5, -8, 0.5, -8),
		CellPadding = UDim2.fromOffset(16, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = content,
	})

	local buttons: { [string]: TextButton } = {}
	for i, room in Config.Rooms do
		local button = Hud.button({
			Name = room.id,
			LayoutOrder = i,
			Text = "",
			Parent = content,
		})
		Hud.label({
			Size = UDim2.new(1, -16, 0.45, 0),
			Position = UDim2.fromOffset(8, 6),
			Text = room.name,
			Parent = button,
		})
		Hud.label({
			Size = UDim2.new(1, -16, 0.4, 0),
			Position = UDim2.new(0, 8, 0.52, 0),
			Text = room.description,
			Font = Enum.Font.Gotham,
			TextTransparency = 0.15,
			TextWrapped = true,
			Parent = button,
		})
		button.Activated:Connect(function()
			if player:GetAttribute("Room") == room.id then
				Hud.toast("Você já está aqui!")
				return
			end
			Remotes.event("RequestRoom"):FireServer(room.id)
			panel.close()
		end)
		buttons[room.id] = button
	end

	local function highlightCurrent()
		local current = player:GetAttribute("Room")
		for id, button in buttons do
			button.BackgroundColor3 = if id == current then Hud.colors.good else Hud.colors.panelLight
		end
	end
	player:GetAttributeChangedSignal("Room"):Connect(highlightCurrent)
	highlightCurrent()

	-- Botão fixo (útil no celular, onde não há tecla M).
	local open = Hud.button({
		Name = "BotaoMapa",
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.fromOffset(120, 44),
		Text = "🗺 Mapa",
		BackgroundColor3 = Hud.colors.panel,
		Parent = Hud.gui(),
	})
	open.Activated:Connect(function()
		if not Hud.isBusy() or panel.isOpen() then
			panel.toggle()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.M then
			return
		end
		if panel.isOpen() or not Hud.isBusy() then
			panel.toggle()
		end
	end)
end

return MapController
