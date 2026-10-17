-- Janela da Loja de Cores. Abre pelo ProximityPrompt do balcão (Action = "Shop").

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Hud = require(script.Parent.Hud)

local player = Players.LocalPlayer

local ShopController = {}

local function owned(): { [string]: boolean }
	local set = {}
	for id in string.gmatch(player:GetAttribute("OwnedColors") or "", "[^,]+") do
		set[id] = true
	end
	return set
end

function ShopController.start()
	local content, panel = Hud.panel("Loja", "🎨 Loja de Cores", UDim2.fromScale(0.62, 0.62))

	Hud.create("UIGridLayout", {
		CellSize = UDim2.new(1 / 3, -11, 1 / 3, -11),
		CellPadding = UDim2.fromOffset(16, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = content,
	})

	local busy = false
	local refreshers = {}

	for i, item in Config.Colors do
		local card = Hud.button({
			Name = item.id,
			LayoutOrder = i,
			Text = "",
			Parent = content,
		})
		Hud.create("Frame", {
			Name = "Amostra",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromScale(0.6, 0.6),
			BackgroundColor3 = item.color,
			Parent = card,
		}, {
			Hud.create("UIAspectRatioConstraint", { AspectRatio = 1 }),
			Hud.corner(999),
			Hud.create("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }),
		})
		Hud.label({
			Size = UDim2.new(0.6, 0, 0.45, 0),
			Position = UDim2.fromScale(0.38, 0.08),
			Text = item.name,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		local status = Hud.label({
			Size = UDim2.new(0.6, 0, 0.35, 0),
			Position = UDim2.fromScale(0.38, 0.55),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})

		table.insert(refreshers, function(ownedSet: { [string]: boolean })
			if player:GetAttribute("Color") == item.id then
				status.Text = "✔ Usando"
				status.TextColor3 = Hud.colors.good
			elseif ownedSet[item.id] then
				status.Text = "Vestir"
				status.TextColor3 = Hud.colors.text
			else
				status.Text = ("🪙 %d"):format(item.price)
				status.TextColor3 = Hud.colors.accent
			end
		end)

		card.Activated:Connect(function()
			if busy or player:GetAttribute("Color") == item.id then
				return
			end
			busy = true
			local remote = if owned()[item.id] then "EquipColor" else "BuyColor"
			local ok, result = pcall(function()
				return Remotes.func(remote):InvokeServer(item.id)
			end)
			busy = false
			if ok and type(result) == "table" then
				Hud.toast(result.msg, if result.ok then Hud.colors.good else Hud.colors.bad)
			else
				Hud.toast("Erro ao falar com o servidor. Tente de novo.", Hud.colors.bad)
			end
		end)
	end

	local function refresh()
		local ownedSet = owned()
		for _, fn in refreshers do
			fn(ownedSet)
		end
	end
	player:GetAttributeChangedSignal("OwnedColors"):Connect(refresh)
	player:GetAttributeChangedSignal("Color"):Connect(refresh)
	refresh()

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("Action") == "Shop" then
			panel.open()
		end
	end)
end

return ShopController
