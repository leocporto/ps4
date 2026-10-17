-- Teleporte para os lugares da ilha (pelo mapa) e "em que lugar estou".
--
-- A ilha é uma só: o lugar atual de cada jogador (atributo "Room" do Player)
-- é o lugar do Config.Rooms mais perto dele, recalculado o tempo todo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.IslandLayout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RoomService = {}

local lastTeleport: { [Player]: number } = {}

-- Acha o chão embaixo de um ponto (ignorando personagens).
local function groundAt(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local characters = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	params.FilterDescendantsInstances = characters

	local origin = Vector3.new(position.X, 300, position.Z)
	local result = workspace:Raycast(origin, Vector3.new(0, -400, 0), params)
	return if result then result.Position else Vector3.new(position.X, 10, position.Z)
end

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
	local spot = Layout.toWorld(room.spawn.X, room.spawn.Y) + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
	local position = groundAt(spot) + Vector3.new(0, 4, 0)
	local look = Layout.toWorld(room.look.X, room.look.Y, position.Y)
	character:PivotTo(CFrame.lookAt(position, look))
	player:SetAttribute("Room", room.id)
	return true
end

local function nearestRoom(position: Vector3): string
	local pixel = Layout.toImage(position)
	local best, bestDistance = Config.StartRoom, math.huge
	for _, room in Config.Rooms do
		local distance = (room.map - pixel).Magnitude
		if distance < bestDistance then
			best, bestDistance = room.id, distance
		end
	end
	return best
end

function RoomService.start()
	Remotes.event("RequestRoom").OnServerEvent:Connect(function(player, roomId)
		if type(roomId) == "string" then
			RoomService.teleport(player, roomId)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastTeleport[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					if root.Position.Y < Config.RescueHeight then
						-- Caiu para fora do mapa: volta para o lugar em que estava.
						RoomService.teleport(player, player:GetAttribute("Room") or Config.StartRoom, true)
					else
						local room = nearestRoom(root.Position)
						if player:GetAttribute("Room") ~= room then
							player:SetAttribute("Room", room)
						end
					end
				end
			end
		end
	end)
end

return RoomService
