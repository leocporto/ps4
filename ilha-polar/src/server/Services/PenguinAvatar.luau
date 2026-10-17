-- Transforma o personagem padrão do Roblox em um pinguim.
--
-- O boneco original continua existindo (animações, colisão e física são dele),
-- mas fica invisível. Por cima dele soldamos peças simples que formam o pinguim.
-- Em primeira pessoa, o Roblox esconde automaticamente tudo dentro do próprio
-- personagem para o dono, então só os outros jogadores veem o pinguim.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PenguinAvatar = {}

local WHITE = Color3.fromRGB(245, 245, 245)
local BLACK = Color3.fromRGB(20, 20, 20)
local ORANGE = Color3.fromRGB(250, 150, 30)
local BODY = "body" -- marcador: estas peças usam a cor do jogador

-- Medidas com y = 0 no chão e -Z sendo a frente do pinguim.
local PIECES = {
	{ name = "Corpo", size = Vector3.new(3, 3.8, 2.8), pos = Vector3.new(0, 2.3, 0), color = BODY },
	{ name = "Cabeca", size = Vector3.new(2.4, 2.4, 2.4), pos = Vector3.new(0, 4.5, 0), color = BODY },
	{ name = "Barriga", size = Vector3.new(2.3, 2.9, 1.2), pos = Vector3.new(0, 2.0, -0.95), color = WHITE },
	{ name = "Rosto", size = Vector3.new(1.8, 1.5, 0.8), pos = Vector3.new(0, 4.45, -0.85), color = WHITE },
	{ name = "OlhoE", size = Vector3.new(0.35, 0.45, 0.35), pos = Vector3.new(-0.4, 4.7, -1.22), color = BLACK },
	{ name = "OlhoD", size = Vector3.new(0.35, 0.45, 0.35), pos = Vector3.new(0.4, 4.7, -1.22), color = BLACK },
	{ name = "Bico", size = Vector3.new(0.8, 0.35, 0.9), pos = Vector3.new(0, 4.2, -1.3), color = ORANGE },
	{ name = "PeE", size = Vector3.new(0.9, 0.3, 1.3), pos = Vector3.new(-0.6, 0.15, -0.4), color = ORANGE },
	{ name = "PeD", size = Vector3.new(0.9, 0.3, 1.3), pos = Vector3.new(0.6, 0.15, -0.4), color = ORANGE },
	{ name = "AsaE", size = Vector3.new(0.4, 2.4, 1.4), pos = Vector3.new(-1.55, 2.5, 0), color = BODY, roll = 15 },
	{ name = "AsaD", size = Vector3.new(0.4, 2.4, 1.4), pos = Vector3.new(1.55, 2.5, 0), color = BODY, roll = -15 },
}

local function colorFor(player: Player): Color3
	local item = Config.ColorsById[player:GetAttribute("Color") or Config.DefaultColor]
	return (item or Config.ColorsById[Config.DefaultColor]).color
end

local function paint(character: Model, color: Color3)
	local penguin = character:FindFirstChild("Pinguim")
	if not penguin then
		return
	end
	for _, p in penguin:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("UsaCorDoJogador") then
			p.Color = color
		end
	end
end

local function hideOriginal(character: Model)
	for _, d in character:GetDescendants() do
		local isClothing = d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic")
		local isFace = d:IsA("Decal") and d.Parent ~= nil and d.Parent.Name == "Head"
		if isClothing or isFace then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Transparency = 1
		end
	end
end

local function build(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not root or not humanoid or not character.Parent then
		return
	end

	hideOriginal(character)

	-- Altura do chão em relação ao centro do HumanoidRootPart.
	-- No R6 o HipHeight é 0 e as pernas (2 studs) ficam abaixo do tronco.
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else humanoid.HipHeight
	local floorY = -(legs + root.Size.Y / 2)
	local color = colorFor(player)

	local model = Instance.new("Model")
	model.Name = "Pinguim"

	for _, piece in PIECES do
		local p = Instance.new("Part")
		p.Name = piece.name
		p.Size = piece.size
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = true
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth

		if piece.color == BODY then
			p.Color = color
			p:SetAttribute("UsaCorDoJogador", true)
		else
			p.Color = piece.color
		end

		if piece.name ~= "Bico" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere -- vira elipsoide do tamanho da peça
			mesh.Parent = p
		end

		p.CFrame = root.CFrame
			* CFrame.new(piece.pos + Vector3.new(0, floorY, 0))
			* CFrame.Angles(0, 0, math.rad(piece.roll or 0))

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p

		p.Parent = model
	end

	model.Parent = character

	-- Peças que o Roblox criar depois (ex.: ao trocar de aparência) também somem.
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and not d:IsDescendantOf(model) then
			d.Transparency = 1
		elseif d:IsA("Accessory") then
			task.defer(d.Destroy, d)
		end
	end)
end

function PenguinAvatar.start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			build(player, character)
		end)
		if player.Character then
			task.spawn(build, player, player.Character)
		end
		player:GetAttributeChangedSignal("Color"):Connect(function()
			if player.Character then
				paint(player.Character, colorFor(player))
			end
		end)
	end

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return PenguinAvatar
