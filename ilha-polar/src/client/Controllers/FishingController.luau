-- Interface do minigame de pesca. Quem decide o resultado é o servidor;
-- aqui só mostramos o estado e mandamos o "puxar".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Hud = require(script.Parent.Hud)

local FishingController = {}

local fishing = false
local reelSent = false

function FishingController.start()
	-- É um botão para o celular: tocar nele puxa a linha. No computador o mouse
	-- fica preso no centro, então lá o clique em qualquer lugar também vale.
	local box = Hud.button({
		Name = "Pesca",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.68),
		Size = UDim2.fromOffset(420, 70),
		BackgroundTransparency = 0.15,
		BackgroundColor3 = Hud.colors.panel,
		Text = "",
		Visible = false,
		Parent = Hud.gui(),
	})
	local stroke = Hud.create("UIStroke", { Thickness = 3, Color = Hud.colors.accent, Parent = box })

	local pulse: Tween? = nil

	local function reel()
		if fishing and not reelSent then
			reelSent = true
			Remotes.event("FishingReel"):FireServer()
		end
	end

	Remotes.event("FishingState").OnClientEvent:Connect(function(state: string, text: string?)
		if pulse then
			pulse:Cancel()
			pulse = nil
		end
		box.Size = UDim2.fromOffset(420, 70)

		if state == "waiting" then
			fishing, reelSent = true, false
			Hud.setBusy("fishing", true)
			box.Visible = true
			box.Text = "🎣 Linha na água... espere morder!"
			box.BackgroundColor3 = Hud.colors.panel
			stroke.Color = Hud.colors.accent
		elseif state == "bite" then
			box.Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
				then "🐟 MORDEU! Toque aqui para puxar!"
				else "🐟 MORDEU! Clique para puxar!"
			box.BackgroundColor3 = Hud.colors.good
			stroke.Color = Color3.new(1, 1, 1)
			pulse = TweenService:Create(
				box,
				TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Size = UDim2.fromOffset(460, 80) }
			)
			pulse:Play()
		elseif state == "done" then
			fishing = false
			Hud.setBusy("fishing", false)
			box.Visible = false
			if text then
				Hud.toast(text)
			end
		end
	end)

	-- Puxa com clique, espaço, botão A do controle ou tocando no próprio aviso.
	box.Activated:Connect(reel)
	UserInputService.InputBegan:Connect(function(input)
		if not fishing then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			reel()
		end
	end)
end

return FishingController
