-- Ponto de entrada do cliente. O Hud vem primeiro porque os outros usam a tela dele.

local Controllers = script.Parent:WaitForChild("Controllers")

local Hud = require(Controllers:WaitForChild("Hud"))
Hud.start()

for _, name in { "MapController", "ShopController", "FishingController", "SnowballController" } do
	require(Controllers:WaitForChild(name)).start()
end
