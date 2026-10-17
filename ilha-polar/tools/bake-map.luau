--[[
	Grava o mapa dentro do place, para ele aparecer no Studio sem apertar Play.

	Uso (rode na pasta ilha-polar):
		rojo build -o build/base.rbxlx
		lune run tools/bake-map build/base.rbxlx IlhaPolar.rbxlx

	Ele abre o place gerado pelo Rojo, roda o MapBuilder de verdade (o mesmo
	código que roda no servidor) e salva o resultado com o mapa já montado.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local input, output = process.args[1], process.args[2]
assert(input and output, "uso: lune run tools/bake-map <entrada.rbxlx> <saida.rbxlx>")

local game = roblox.deserializePlace(fs.readFile(input))
local workspace = game:GetService("Workspace")

-- Os tipos do Roblox (Vector3, CFrame, Instance, Enum...) vêm da biblioteca do Lune.
local robloxGlobals = {}
for name, value in roblox do
	if string.match(name, "^%u") then
		robloxGlobals[name] = value
	end
end

-- `require` no estilo do Roblox: recebe um ModuleScript do place e roda o Source dele.
local cache = {}
local function requireModule(module)
	if cache[module] == nil then
		local environment = table.clone(robloxGlobals)
		environment.game = game
		environment.workspace = workspace
		environment.script = module
		environment.require = requireModule
		local chunk = luau.load(module.Source, {
			debugName = module:GetFullName(),
			environment = environment,
		})
		cache[module] = chunk()
	end
	return cache[module]
end

local services = game:GetService("ServerScriptService"):FindFirstChild("Server"):FindFirstChild("Services")
local MapBuilder = requireModule(services:FindFirstChild("MapBuilder"))

local old = workspace:FindFirstChild("Mapa")
if old then
	old:Destroy()
end
local map = MapBuilder.build()

local parts, tags = 0, {}
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
	for _, tag in d:GetTags() do
		tags[tag] = (tags[tag] or 0) + 1
	end
end

fs.writeFile(output, roblox.serializePlace(game, true))
print(`Mapa gravado: {parts} peças. Tags: ShopCounter={tags.ShopCounter or 0}, FishingSpot={tags.FishingSpot or 0}`)
print(`Arquivo salvo em {output}`)
