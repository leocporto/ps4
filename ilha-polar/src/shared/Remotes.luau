-- Lista única de RemoteEvents/RemoteFunctions.
-- O servidor cria tudo na primeira vez que este módulo é carregado;
-- o cliente só espera os objetos aparecerem.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"RequestRoom", -- cliente -> servidor: (roomId)
	"ThrowSnowball", -- cliente -> servidor: (direção)
	"SnowballHit", -- servidor -> cliente: (nome de quem acertou)
	"FishingState", -- servidor -> cliente: (estado, texto?)
	"FishingReel", -- cliente -> servidor: ()
	"Notify", -- servidor -> cliente: (texto)
}

local FUNCTIONS = {
	"BuyColor", -- (colorId) -> { ok, msg }
	"EquipColor", -- (colorId) -> { ok, msg }
}

local FOLDER_NAME = "Remotes"

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		for _, name in EVENTS do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		for _, name in FUNCTIONS do
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local Remotes = {}

function Remotes.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
