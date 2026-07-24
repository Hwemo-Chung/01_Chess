-- Renders the 6x6 board, player piece, enemies, legal-move highlights + damage preview.
-- Crit preview icon from Config.ASSET_IDS.icons.crit (0 → text-only summary).

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Chess"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BoardLayout = require(Shared:WaitForChild("BoardLayout"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local IconSurface = require(script.Parent:WaitForChild("IconSurface"))

local BoardView = {}
BoardView.__index = BoardView

local LIGHT = Color3.fromRGB(232, 220, 196)
local DARK = Color3.fromRGB(92, 72, 54)
local HIGHLIGHT_MOVE = Color3.fromRGB(80, 200, 120)
local HIGHLIGHT_ATTACK = Color3.fromRGB(220, 80, 70)
local HIGHLIGHT_LETHAL = Color3.fromRGB(255, 40, 40)
local PLAYER_COLOR = Color3.fromRGB(90, 180, 255)
local ENEMY_COLOR = Color3.fromRGB(220, 90, 90)
local BOSS_COLOR = Color3.fromRGB(255, 200, 40)
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

local function attachBillboard(
	part: BasePart,
	text: string,
	textColor: Color3,
	studsY: number?,
	showCrit: boolean?
)
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

	if showCrit == true and IconSurface.has("Crit") then
		local critIcon = Instance.new("ImageLabel")
		critIcon.Name = "CritIcon"
		critIcon.BackgroundTransparency = 1
		critIcon.Size = UDim2.fromOffset(18, 18)
		critIcon.Position = UDim2.new(1, -18, 0, 0)
		critIcon.ScaleType = Enum.ScaleType.Fit
		critIcon.Active = false
		critIcon.Parent = gui
		if not IconSurface.apply(critIcon, "Crit") then
			critIcon:Destroy()
		end
	end
	return label
end

-- Slim HP bar under an enemy billboard label. Returns the fill frame.
local function addHpBar(gui: BillboardGui): Frame
	local back = Instance.new("Frame")
	back.Name = "HpBack"
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.new(0.5, 0, 1, -2)
	back.Size = UDim2.new(0.6, 0, 0, 5)
	back.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	back.BackgroundTransparency = 0.25
	back.BorderSizePixel = 0
	back.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "HpFill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(235, 90, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	return fill
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
		_enemyEntries = {} :: { any },
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
		-- Breathing pulse so playable squares read at a glance.
		TweenService:Create(
			marker,
			TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.65 }
		):Play()
		if preview ~= nil and preview.kind == "attack" then
			local canCrit = type(preview.critChance) == "number" and preview.critChance > 0
			attachBillboard(marker, preview.summary, Color3.fromRGB(255, 245, 220), 1.4, canCrit)
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
		part.Position = Vector3.new(px, py, pz)
		attachBillboard(part, "?", Color3.new(1, 1, 1))
		self._playerPart = part
	end
	local playerPart = self._playerPart :: BasePart
	local targetPos = Vector3.new(px, py, pz)
	-- Piece-flavored motion: Knight vaults, everything else glides with a low hop.
	local hopHeight = if snapshot.activePiece == "Knight" then 4 else 1
	Fx.arcMove(playerPart, targetPos, hopHeight, 0.22)
	playerPart.Color = if snapshot.invulnerable then INVULN_COLOR else PLAYER_COLOR
	local playerLabel = playerPart:FindFirstChild("Label")
	if playerLabel ~= nil then
		local textLabel = playerLabel:FindFirstChildOfClass("TextLabel")
		if textLabel ~= nil then
			textLabel.Text = PIECE_LABEL[snapshot.activePiece] or "?"
		end
	end

	-- Reuse nearest same-type enemy part so moves animate instead of teleporting.
	local remaining = self._enemyEntries
	self._enemyEntries = {}
	for _, enemy in ipairs(snapshot.enemies or {}) do
		local ex, ey, ez = BoardLayout.gridToPieceWorld(enemy.x, enemy.z)
		local enemyPos = Vector3.new(ex, ey, ez)
		local isBoss = enemy.isBoss == true
		local pieceType = enemy.pieceType or ""

		local bestIdx, bestDist = nil, math.huge
		for idx, entry in pairs(remaining) do
			if entry.pieceType == pieceType and entry.isBoss == isBoss then
				local dx = entry.x - enemy.x
				local dz = entry.z - enemy.z
				local dist = dx * dx + dz * dz
				if dist < bestDist then
					bestIdx, bestDist = idx, dist
				end
			end
		end

		local entry
		if bestIdx ~= nil then
			entry = remaining[bestIdx]
			remaining[bestIdx] = nil
			local hop = if pieceType == "Knight" then 3.5 elseif isBoss then 0.4 else 0.8
			Fx.arcMove(entry.part, enemyPos, hop, 0.2)
		else
			local part = makePart({
				Name = "Enemy_" .. pieceType,
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				Material = if isBoss then Enum.Material.Neon else Enum.Material.SmoothPlastic,
				Color = if isBoss then BOSS_COLOR else ENEMY_COLOR,
				Size = if isBoss then Vector3.new(3.4, 3.4, 3.4) else Vector3.new(2.8, 2.8, 2.8),
				Position = enemyPos,
				Parent = self._pieces,
			})
			local textLabel = attachBillboard(part, "", Color3.fromRGB(255, 220, 220))
			local gui = part:FindFirstChild("Label")
			local hpFill = if gui ~= nil and gui:IsA("BillboardGui") then addHpBar(gui) else nil
			Fx.spawnIn(part)
			entry = { part = part, label = textLabel, hpFill = hpFill }
		end

		local label = PIECE_LABEL[pieceType] or "E"
		entry.label.Text = string.format(
			"%s%s\n%d",
			if isBoss then "★" else "",
			label,
			math.max(0, math.floor(enemy.health))
		)
		entry.x, entry.z = enemy.x, enemy.z
		entry.pieceType, entry.isBoss = pieceType, isBoss
		-- Client-side max-HP guess (snapshot has no maxHealth): highest seen wins.
		entry.maxHp = math.max(entry.maxHp or 0, enemy.health)
		if entry.hpFill ~= nil and entry.maxHp > 0 then
			entry.hpFill.Size = UDim2.fromScale(math.clamp(enemy.health / entry.maxHp, 0, 1), 1)
		end
		table.insert(self._enemyEntries, entry)
	end
	for _, entry in pairs(remaining) do
		Fx.dieOut(entry.part)
	end

	if snapshot.runOver then
		self:clearHighlights()
	else
		self:setHighlights(snapshot.legalMoves, snapshot.enemies, snapshot.previews)
	end
end

function BoardView.getPlayerPart(self): BasePart?
	return self._playerPart
end

-- Enemy nearest to (x,z) lunges at targetWorld — attack motion for counters/enemy phase.
function BoardView.lungeEnemyToward(self, x: number, z: number, targetWorld: Vector3)
	local bestEntry, bestDist = nil, 9
	for _, entry in ipairs(self._enemyEntries) do
		local dx = entry.x - x
		local dz = entry.z - z
		local dist = dx * dx + dz * dz
		if dist < bestDist then
			bestEntry, bestDist = entry, dist
		end
	end
	if bestEntry == nil then
		return
	end
	local hx, hy, hz = BoardLayout.gridToPieceWorld(bestEntry.x, bestEntry.z)
	Fx.lunge(bestEntry.part, targetWorld, Vector3.new(hx, hy, hz))
end

-- White hit-flash on the enemy nearest to the attacked square (within ~3 tiles).
function BoardView.flashEnemyNear(self, x: number, z: number)
	local bestEntry, bestDist = nil, 9
	for _, entry in ipairs(self._enemyEntries) do
		local dx = entry.x - x
		local dz = entry.z - z
		local dist = dx * dx + dz * dz
		if dist < bestDist then
			bestEntry, bestDist = entry, dist
		end
	end
	if bestEntry == nil then
		return
	end
	Fx.hitFlash(bestEntry.part)
end

function BoardView.destroy(self)
	if self._folder ~= nil then
		self._folder:Destroy()
	end
end

return BoardView
