-- Salva e carrega o progresso de cada jogador (DataStore).
--
-- Os outros serviços nunca mexem no DataStore: eles chamam `DataService.update`,
-- que altera a tabela em memória, marca para salvar e espelha os campos
-- visíveis em atributos do Player (Coins, Color, OwnedColors), que o cliente lê.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local STORE_NAME = "IlhaPolar_v1"
local AUTOSAVE_INTERVAL = 60
local LOAD_ATTEMPTS = 3

local DataService = {}

type Profile = {
	data: { [string]: any },
	canSave: boolean, -- false se o carregamento falhou: não sobrescreve o save bom com dados padrão
	dirty: boolean,
}

local profiles: { [Player]: Profile } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore indisponível:", result)
	end
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function defaultData()
	return {
		coins = Config.StartingCoins,
		color = Config.DefaultColor,
		ownedColors = { [Config.DefaultColor] = true },
		fishCaught = 0,
	}
end

-- Garante que um save antigo tenha todos os campos novos.
local function reconcile(data: { [string]: any })
	for key, value in defaultData() do
		if data[key] == nil then
			data[key] = value
		end
	end
	if not Config.ColorsById[data.color] then
		data.color = Config.DefaultColor
	end
	data.ownedColors[Config.DefaultColor] = true
	return data
end

local function syncAttributes(player: Player, data: { [string]: any })
	local owned = {}
	for colorId in data.ownedColors do
		table.insert(owned, colorId)
	end
	table.sort(owned)

	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("Color", data.color)
	player:SetAttribute("OwnedColors", table.concat(owned, ","))
	player:SetAttribute("FishCaught", data.fishCaught)
end

local function save(player: Player, profile: Profile)
	if not store or not profile.canSave or not profile.dirty then
		return
	end
	profile.dirty = false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function()
			return profile.data
		end)
	end)
	if not ok then
		profile.dirty = true
		warn("[DataService] Falha ao salvar", player.Name, err)
	end
end

local function load(player: Player)
	local loaded = nil
	local loadedOk = store == nil -- sem DataStore (ex.: Studio sem API) não há o que proteger

	if store then
		for attempt = 1, LOAD_ATTEMPTS do
			local ok, result = pcall(function()
				return (store :: DataStore):GetAsync(keyFor(player))
			end)
			if ok then
				loaded = result
				loadedOk = true
				break
			end
			warn(
				("[DataService] Tentativa %d de carregar %s falhou: %s"):format(attempt, player.Name, tostring(result))
			)
			task.wait(attempt * 2)
		end
	end

	if not player.Parent then
		return -- saiu enquanto carregava
	end

	local data = reconcile(if type(loaded) == "table" then loaded else defaultData())
	profiles[player] = { data = data, canSave = loadedOk and store ~= nil, dirty = false }
	syncAttributes(player, data)
	player:SetAttribute("DataLoaded", true)

	if not loadedOk then
		Remotes.event("Notify")
			:FireClient(player, "Não foi possível carregar seu progresso. Nada será salvo nesta sessão.")
	end
end

-- Retorna os dados do jogador (somente leitura!) ou nil se ainda não carregou.
function DataService.get(player: Player): { [string]: any }?
	local profile = profiles[player]
	return profile and profile.data
end

-- Única forma de alterar os dados: `mutator` recebe a tabela e a modifica.
function DataService.update(player: Player, mutator: ({ [string]: any }) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	mutator(profile.data)
	profile.dirty = true
	syncAttributes(player, profile.data)
	return true
end

function DataService.addCoins(player: Player, amount: number): boolean
	return DataService.update(player, function(data)
		data.coins += amount
	end)
end

function DataService.start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			save(player, profile)
			profiles[player] = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, profile in profiles do
				task.spawn(save, player, profile)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for player, profile in profiles do
			pending += 1
			task.spawn(function()
				save(player, profile)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
