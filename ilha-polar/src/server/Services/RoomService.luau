-- Troca de sala (pelo mapa ou pelos portais) e resgate de quem cai no mar.
-- A sala atual de cada jogador fica no atributo "Room" do Player.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RoomService = {}

local lastTeleport: { [Player]: number } = {}

function RoomService.teleport(player: Player, roomId: string, force: boolean?): boolean
	local room = Config.RoomsById[roomId]
	local character = player.Character
	if not room or not character or not character:FindFirstChild("HumanoidRootPart") then
		return false
	end

	local now = os.clock()
	if not force and now - (lastTeleport[player] or 0) < Config.RoomChangeCooldown then
		return false
	end
	lastTeleport[player] = now

	-- Espalha um pouco para ninguém nascer em cima de ninguém.
	local jitter = Vector3.new(math.random(-6, 6), 4, math.random(-6, 6))
	local position = room.center + room.spawn + jitter
	character:PivotTo(CFrame.lookAt(position, position + room.look))
	player:SetAttribute("Room", room.id)
	return true
end

local function portalTouched(portal: BasePart, hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	local destination = portal:GetAttribute("Destino")
	if player and type(destination) == "string" then
		RoomService.teleport(player, destination)
	end
end

local function watchPortal(portal: Instance)
	if portal:IsA("BasePart") then
		portal.Touched:Connect(function(hit)
			portalTouched(portal, hit)
		end)
	end
end

function RoomService.start()
	Remotes.event("RequestRoom").OnServerEvent:Connect(function(player, roomId)
		if type(roomId) == "string" then
			RoomService.teleport(player, roomId)
		end
	end)

	for _, portal in CollectionService:GetTagged("Portal") do
		watchPortal(portal)
	end
	CollectionService:GetInstanceAddedSignal("Portal"):Connect(watchPortal)

	local function onPlayer(player: Player)
		-- Todo personagem nasce no SpawnLocation da sala inicial.
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Room", Config.StartRoom)
		end)
		if player.Character then
			player:SetAttribute("Room", Config.StartRoom)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTeleport[player] = nil
	end)

	-- Caiu no mar? Volta para o ponto de chegada da sala em que estava.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and root.Position.Y < Config.OceanHeight - 2 then
					RoomService.teleport(player, player:GetAttribute("Room") or Config.StartRoom, true)
					Remotes.event("Notify"):FireClient(player, "Splash! A água está gelada demais 🥶")
				end
			end
		end
	end)
end

return RoomService
