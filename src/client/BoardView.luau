-- Renders the 6x6 board, player piece, enemies, legal-move highlights + damage preview labels.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Chess"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BoardLayout = require(Shared:WaitForChild("BoardLayout"))

local BoardView = {}
BoardView.__index = BoardView

local LIGHT = Color3.fromRGB(232, 220, 196)
local DARK = Color3.fromRGB(92, 72, 54)
local HIGHLIGHT_MOVE = Color3.fromRGB(80, 200, 120)
local HIGHLIGHT_ATTACK = Color3.fromRGB(220, 80, 70)
local HIGHLIGHT_LETHAL = Color3.fromRGB(255, 40, 40)
local PLAYER_COLOR = Color3.fromRGB(90, 180, 255)
local ENEMY_COLOR = Color3.fromRGB(220, 90, 90)
local INVULN_COLOR = Color3.fromRGB(255, 230, 100)

local PIECE_LABEL = {
	Pawn = "P",
	Knight = "N",
	Bishop = "B",
	Rook = "R",
	Queen = "Q",
	King = "K",
}

local function makePart(props)
	local part = Instance.new("Part")
	for key, value in pairs(props) do
		(part :: any)[key] = value
	end
	return part
end

local function attachBillboard(part: BasePart, text: string, textColor: Color3, studsY: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(110, 48)
	gui.StudsOffset = Vector3.new(0, studsY or 2.2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = textColor
	label.TextStrokeTransparency = 0.35
	label.TextWrapped = true
	label.Text = text
	label.Parent = gui
	return label
end

function BoardView.new()
	local folder = Workspace:FindFirstChild("ChessBoard")
	if folder ~= nil then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "ChessBoard"
	folder.Parent = Workspace

	local tilesFolder = Instance.new("Folder")
	tilesFolder.Name = "Tiles"
	tilesFolder.Parent = folder

	local highlightsFolder = Instance.new("Folder")
	highlightsFolder.Name = "Highlights"
	highlightsFolder.Parent = folder

	local piecesFolder = Instance.new("Folder")
	piecesFolder.Name = "Pieces"
	piecesFolder.Parent = folder

	local tiles: { [string]: BasePart } = {}
	local size = BoardLayout.TILE_SIZE
	for x = 1, Config.BOARD_SIZE do
		for z = 1, Config.BOARD_SIZE do
			local worldX, worldY, worldZ = BoardLayout.gridToWorld(x, z)
			local isLight = (x + z) % 2 == 0
			local tile = makePart({
				Name = string.format("Tile_%d_%d", x, z),
				Anchored = true,
				CanCollide = false,
				CanQuery = true,
				Material = Enum.Material.SmoothPlastic,
				Color = if isLight then LIGHT else DARK,
				Size = Vector3.new(size - 0.15, 0.6, size - 0.15),
				Position = Vector3.new(worldX, worldY, worldZ),
				Parent = tilesFolder,
			})
			tile:SetAttribute("GridX", x)
			tile:SetAttribute("GridZ", z)
			tiles[x .. "," .. z] = tile
		end
	end

	return setmetatable({
		_folder = folder,
		_tiles = tiles,
		_highlights = highlightsFolder,
		_pieces = piecesFolder,
		_playerPart = nil :: BasePart?,
		_enemyParts = {} :: { BasePart },
		_onTileClick = nil :: ((number, number) -> ())?,
	}, BoardView)
end

function BoardView.onTileClick(self, callback: (number, number) -> ())
	self._onTileClick = callback
end

function BoardView.handleClickPosition(self, worldPosition: Vector3)
	local x, z = BoardLayout.worldToGrid(worldPosition.X, worldPosition.Z)
	if x == nil or z == nil then
		return
	end
	if self._onTileClick ~= nil then
		self._onTileClick(x, z)
	end
end

function BoardView.clearHighlights(self)
	self._highlights:ClearAllChildren()
end

function BoardView.setHighlights(self, legalMoves, enemies, previews)
	self:clearHighlights()
	local enemySet: { [string]: boolean } = {}
	for _, enemy in ipairs(enemies or {}) do
		enemySet[enemy.x .. "," .. enemy.z] = true
	end
	previews = previews or {}
	for _, move in ipairs(legalMoves or {}) do
		local key = move.x .. "," .. move.z
		local worldX, worldY, worldZ = BoardLayout.gridToWorld(move.x, move.z)
		local isAttack = enemySet[key] == true
		local preview = previews[key]
		local color = HIGHLIGHT_MOVE
		if isAttack then
			color = if preview and preview.playerDiesIfHit
				then HIGHLIGHT_LETHAL
				else HIGHLIGHT_ATTACK
		end
		local marker = makePart({
			Name = string.format("Highlight_%d_%d", move.x, move.z),
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			Material = Enum.Material.Neon,
			Color = color,
			Transparency = 0.35,
			Size = Vector3.new(BoardLayout.TILE_SIZE - 1.2, 0.2, BoardLayout.TILE_SIZE - 1.2),
			Position = Vector3.new(worldX, worldY + 0.45, worldZ),
			Parent = self._highlights,
		})
		marker:SetAttribute("GridX", move.x)
		marker:SetAttribute("GridZ", move.z)
		if preview ~= nil and preview.kind == "attack" then
			attachBillboard(marker, preview.summary, Color3.fromRGB(255, 245, 220), 1.4)
		end
	end
end

function BoardView.render(self, snapshot)
	if snapshot == nil then
		return
	end

	if snapshot.activePosition == nil or snapshot.activePiece == nil then
		self:clearHighlights()
		return
	end

	local pos = snapshot.activePosition
	local px, py, pz = BoardLayout.gridToPieceWorld(pos.x, pos.z)
	if self._playerPart == nil or self._playerPart.Parent == nil then
		local part = makePart({
			Name = "PlayerPiece",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			Material = Enum.Material.SmoothPlastic,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.5, 3.5, 3.5),
			Parent = self._pieces,
		})
		part.Orientation = Vector3.new(0, 0, 90)
		attachBillboard(part, "?", Color3.new(1, 1, 1))
		self._playerPart = part
	end
	local playerPart = self._playerPart :: BasePart
	playerPart.Position = Vector3.new(px, py, pz)
	playerPart.Color = if snapshot.invulnerable then INVULN_COLOR else PLAYER_COLOR
	local playerLabel = playerPart:FindFirstChild("Label")
	if playerLabel ~= nil then
		local textLabel = playerLabel:FindFirstChildOfClass("TextLabel")
		if textLabel ~= nil then
			textLabel.Text = PIECE_LABEL[snapshot.activePiece] or "?"
		end
	end

	for _, part in ipairs(self._enemyParts) do
		part:Destroy()
	end
	self._enemyParts = {}
	for index, enemy in ipairs(snapshot.enemies or {}) do
		local ex, ey, ez = BoardLayout.gridToPieceWorld(enemy.x, enemy.z)
		local part = makePart({
			Name = "Enemy_" .. tostring(index),
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			Material = Enum.Material.SmoothPlastic,
			Color = ENEMY_COLOR,
			Size = Vector3.new(2.8, 2.8, 2.8),
			Position = Vector3.new(ex, ey, ez),
			Parent = self._pieces,
		})
		local hpText = string.format("%d", math.max(0, math.floor(enemy.health)))
		attachBillboard(part, hpText, Color3.fromRGB(255, 220, 220))
		table.insert(self._enemyParts, part)
	end

	if snapshot.runOver then
		self:clearHighlights()
	else
		self:setHighlights(snapshot.legalMoves, snapshot.enemies, snapshot.previews)
	end
end

function BoardView.destroy(self)
	if self._folder ~= nil then
		self._folder:Destroy()
	end
end

return BoardView
