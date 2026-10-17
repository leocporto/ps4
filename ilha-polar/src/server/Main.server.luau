-- Ponto de entrada do servidor. A ordem importa: o mapa precisa existir
-- antes dos serviços procurarem portais, loja e pontos de pesca.

local Services = script.Parent.Services

local MapBuilder = require(Services.MapBuilder)
local DataService = require(Services.DataService)
local PenguinAvatar = require(Services.PenguinAvatar)
local RoomService = require(Services.RoomService)
local SnowballService = require(Services.SnowballService)
local FishingService = require(Services.FishingService)
local ShopService = require(Services.ShopService)

MapBuilder.build()

DataService.start()
PenguinAvatar.start()
RoomService.start()
SnowballService.start()
FishingService.start()
ShopService.start()
