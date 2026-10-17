-- Loja de cores do pinguim. O cliente pede; o servidor confere preço e saldo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local ShopService = {}

type Result = { ok: boolean, msg: string }

local function buy(player: Player, colorId: any): Result
	local item = type(colorId) == "string" and Config.ColorsById[colorId]
	if not item then
		return { ok = false, msg = "Item inválido." }
	end
	local data = DataService.get(player)
	if not data then
		return { ok = false, msg = "Ainda carregando seu progresso..." }
	end
	if data.ownedColors[item.id] then
		return { ok = false, msg = "Você já tem essa cor." }
	end
	if data.coins < item.price then
		return { ok = false, msg = ("Faltam %d moedas."):format(item.price - data.coins) }
	end

	DataService.update(player, function(d)
		d.coins -= item.price
		d.ownedColors[item.id] = true
		d.color = item.id -- já veste a cor nova
	end)
	return { ok = true, msg = ("Você comprou a cor %s!"):format(item.name) }
end

local function equip(player: Player, colorId: any): Result
	local item = type(colorId) == "string" and Config.ColorsById[colorId]
	local data = DataService.get(player)
	if not item or not data then
		return { ok = false, msg = "Item inválido." }
	end
	if not data.ownedColors[item.id] then
		return { ok = false, msg = "Você ainda não tem essa cor." }
	end
	DataService.update(player, function(d)
		d.color = item.id
	end)
	return { ok = true, msg = ("Agora você é um pinguim %s."):format(item.name:lower()) }
end

function ShopService.start()
	Remotes.func("BuyColor").OnServerInvoke = buy
	Remotes.func("EquipColor").OnServerInvoke = equip
end

return ShopService
