-- Ponto de entrada do servidor. A ordem importa: o mapa precisa existir
-- antes dos serviços procurarem portais, loja e pontos de pesca.
--
-- O build oficial (tools/bake-map.luau) já grava o mapa dentro do place, para
-- ele aparecer no Studio sem apertar Play. Se o mapa não estiver lá (por
-- exemplo, usando `rojo serve`), ele é montado agora.

local Services = script.Parent.Services

local MapBuilder = require(Services.MapBuilder)
local DataService = require(Services.DataService)
local PenguinAvatar = require(Services.PenguinAvatar)
local RoomService = require(Services.RoomService)
local SnowballService = require(Services.SnowballService)
local FishingService = require(Services.FishingService)
local ShopService = require(Services.ShopService)

if not workspace:FindFirstChild("Mapa") then
	MapBuilder.build()
end

DataService.start()
PenguinAvatar.start()
RoomService.start()
SnowballService.start()
FishingService.start()
ShopService.start()
