-- Arremesso de bola de neve na direção da câmera e efeito de "levou uma bolada".

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Hud = require(script.Parent.Hud)

local SnowballController = {}

local ACTION = "JogarBolaDeNeve"
local lastThrow = 0

local function onAction(_, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin or Hud.isBusy() then
		return Enum.ContextActionResult.Pass
	end
	local now = os.clock()
	if now - lastThrow < Config.Snowball.cooldown then
		return Enum.ContextActionResult.Sink
	end
	lastThrow = now

	local camera = workspace.CurrentCamera
	Remotes.event("ThrowSnowball"):FireServer(camera.CFrame.LookVector)
	return Enum.ContextActionResult.Sink
end

local function showHit(throwerName: string)
	local overlay = Hud.create("Frame", {
		Name = "Bolada",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.3, 0.5 + (math.random() - 0.5) * 0.3),
		Size = UDim2.fromScale(0.35, 0.35),
		BackgroundColor3 = Color3.fromRGB(250, 252, 255),
		BackgroundTransparency = 0.05,
		Parent = Hud.gui(),
	}, {
		Hud.create("UIAspectRatioConstraint", { AspectRatio = 1 }),
		Hud.corner(999),
	})
	TweenService:Create(overlay, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
		Position = overlay.Position + UDim2.fromScale(0, 0.08),
	}):Play()
	task.delay(1.7, function()
		overlay:Destroy()
	end)
	Hud.toast(("%s te acertou com uma bola de neve!"):format(throwerName))
end

function SnowballController.start()
	ContextActionService:BindAction(
		ACTION,
		onAction,
		true, -- cria botão de toque no celular
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:SetTitle(ACTION, "❄")
	ContextActionService:SetPosition(ACTION, UDim2.new(1, -170, 1, -150))

	Remotes.event("SnowballHit").OnClientEvent:Connect(showHit)
end

return SnowballController
