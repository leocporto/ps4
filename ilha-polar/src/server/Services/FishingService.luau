-- Minigame de pesca na Doca.
--
-- Fluxo: o jogador ativa um ponto de pesca -> espera alguns segundos -> o peixe
-- morde -> ele tem `reactionWindow` segundos para puxar. Todo o tempo é
-- contado no servidor, então o cliente não consegue trapacear o momento certo.
--
-- Estados enviados ao cliente pelo evento FishingState:
--   "waiting"   linha na água
--   "bite"      o peixe mordeu, puxe agora
--   "done"      fim (acompanha o texto do resultado)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local FishingService = {}

type Session = {
	stage: "waiting" | "bite",
	biteTime: number,
	spot: BasePart,
	walkSpeed: number,
}

local sessions: { [Player]: Session } = {}
local random = Random.new()

local function rollReward()
	local total = 0
	for _, reward in Config.Fishing.rewards do
		total += reward.weight
	end
	local roll = random:NextNumber(0, total)
	for _, reward in Config.Fishing.rewards do
		roll -= reward.weight
		if roll <= 0 then
			return reward
		end
	end
	return Config.Fishing.rewards[1]
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function finish(player: Player, session: Session, text: string)
	if sessions[player] ~= session then
		return
	end
	sessions[player] = nil

	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.WalkSpeed = session.walkSpeed
	end
	Remotes.event("FishingState"):FireClient(player, "done", text)
end

local function isNear(player: Player, spot: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - spot.Position).Magnitude <= Config.Fishing.maxDistance
end

local function start(player: Player, spot: BasePart)
	if sessions[player] or not DataService.get(player) or not isNear(player, spot) then
		return
	end
	local humanoid = humanoidOf(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local session: Session = { stage = "waiting", biteTime = 0, spot = spot, walkSpeed = humanoid.WalkSpeed }
	sessions[player] = session
	humanoid.WalkSpeed = 0 -- fica parado enquanto pesca
	Remotes.event("FishingState"):FireClient(player, "waiting")

	local biteDelay = random:NextNumber(Config.Fishing.biteMin, Config.Fishing.biteMax)
	task.delay(biteDelay, function()
		if sessions[player] ~= session then
			return
		end
		session.stage = "bite"
		session.biteTime = os.clock()
		Remotes.event("FishingState"):FireClient(player, "bite")

		-- Margem extra para o atraso da rede antes de declarar que o peixe fugiu.
		task.delay(Config.Fishing.reactionWindow + 0.6, function()
			finish(player, session, "O peixe escapou! Tente de novo.")
		end)
	end)
end

local function reel(player: Player)
	local session = sessions[player]
	if not session then
		return
	end

	if session.stage == "waiting" then
		finish(player, session, "Cedo demais! O peixe se assustou.")
		return
	end

	local reaction = os.clock() - session.biteTime
	if reaction > Config.Fishing.reactionWindow + 0.5 or not isNear(player, session.spot) then
		finish(player, session, "O peixe escapou! Tente de novo.")
		return
	end

	local reward = rollReward()
	DataService.update(player, function(data)
		data.coins += reward.coins
		data.fishCaught += 1
	end)
	finish(player, session, ("Você pescou: %s! +%d moedas"):format(reward.name, reward.coins))
end

local function watchSpot(spot: Instance)
	if not spot:IsA("BasePart") then
		return
	end
	local prompt = spot:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(player)
			start(player, spot)
		end)
	end
end

function FishingService.start()
	for _, spot in CollectionService:GetTagged("FishingSpot") do
		watchSpot(spot)
	end
	CollectionService:GetInstanceAddedSignal("FishingSpot"):Connect(watchSpot)

	Remotes.event("FishingReel").OnServerEvent:Connect(reel)

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return FishingService
