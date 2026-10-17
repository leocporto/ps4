-- Bolas de neve: o cliente só manda a direção da mira; quem cria a bola,
-- controla o cooldown e decide o que foi atingido é o servidor.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SnowballService = {}

local SNOW = Color3.fromRGB(250, 252, 255)
local lastThrow: { [Player]: number } = {}

local function splat(position: Vector3)
	local puff = Instance.new("Part")
	puff.Name = "Respingo"
	puff.Shape = Enum.PartType.Ball
	puff.Size = Vector3.one * 1.2
	puff.Position = position
	puff.Anchored = true
	puff.CanCollide = false
	puff.CanTouch = false
	puff.CanQuery = false
	puff.Material = Enum.Material.Snow
	puff.Color = SNOW
	puff.Parent = workspace

	TweenService:Create(puff, TweenInfo.new(0.35), { Size = Vector3.one * 3.5, Transparency = 1 }):Play()
	Debris:AddItem(puff, 0.4)
end

local function throw(player: Player, direction: any)
	if typeof(direction) ~= "Vector3" then
		return
	end
	local magnitude = direction.Magnitude
	if magnitude < 0.5 or magnitude ~= magnitude then -- descarta zero e NaN
		return
	end
	direction = direction.Unit

	local now = os.clock()
	if now - (lastThrow[player] or 0) < Config.Snowball.cooldown then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not head then
		return
	end
	lastThrow[player] = now

	local ball = Instance.new("Part")
	ball.Name = "BolaDeNeve"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 0.9
	ball.Material = Enum.Material.Snow
	ball.Color = SNOW
	ball.CanCollide = false
	ball.CFrame = CFrame.new(head.Position + direction * 3)
	ball.Parent = workspace
	ball:SetNetworkOwner(nil)

	-- Anula parte da gravidade para a bola fazer um arco suave.
	local attachment = Instance.new("Attachment")
	attachment.Parent = ball
	local antiGravity = Instance.new("VectorForce")
	antiGravity.Attachment0 = attachment
	antiGravity.RelativeTo = Enum.ActuatorRelativeTo.World
	antiGravity.ApplyAtCenterOfMass = true
	antiGravity.Force = Vector3.new(0, ball:GetMass() * workspace.Gravity * (1 - Config.Snowball.gravityScale), 0)
	antiGravity.Parent = ball

	ball.AssemblyLinearVelocity = direction * Config.Snowball.speed

	local done = false
	ball.Touched:Connect(function(hit)
		if done or hit:IsDescendantOf(character) or hit.Name == "BolaDeNeve" then
			return
		end

		local hitModel = hit:FindFirstAncestorOfClass("Model")
		local victim = hitModel and Players:GetPlayerFromCharacter(hitModel)
		if not victim and not hit.CanCollide then
			return -- atravessa portais e outras peças sem colisão
		end

		done = true
		splat(ball.Position)
		ball:Destroy()
		if victim and victim ~= player then
			Remotes.event("SnowballHit"):FireClient(victim, player.DisplayName)
		end
	end)

	Debris:AddItem(ball, Config.Snowball.lifetime)
end

function SnowballService.start()
	Remotes.event("ThrowSnowball").OnServerEvent:Connect(throw)
	Players.PlayerRemoving:Connect(function(player)
		lastThrow[player] = nil
	end)
end

return SnowballService
