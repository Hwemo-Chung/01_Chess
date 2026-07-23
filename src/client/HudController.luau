-- ScreenGui HUD: piece/HP/level/roster + reroll + restart + last combat log.
local HudController = {}
HudController.__index = HudController

local PANEL = Color3.fromRGB(18, 28, 48)
local TEXT = Color3.fromRGB(240, 246, 255)
local MUTED = Color3.fromRGB(160, 178, 205)
local ACCENT = Color3.fromRGB(90, 180, 255)
local DANGER = Color3.fromRGB(244, 114, 140)
local OK = Color3.fromRGB(110, 220, 150)

local function create(className: string, props)
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	return instance
end

function HudController.new(player: Player)
	local gui = create("ScreenGui", {
		Name = "ChessHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local top = create("Frame", {
		Name = "TopBar",
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(360, 132),
		Parent = gui,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = top })
	create("UIStroke", { Color = Color3.fromRGB(60, 85, 120), Thickness = 1, Parent = top })

	local title = create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "01_Chess",
		TextColor3 = ACCENT,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 20),
		Parent = top,
	})

	local pieceLabel = create("TextLabel", {
		Name = "Piece",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = "Piece: —",
		TextColor3 = TEXT,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 34),
		Size = UDim2.new(1, -28, 0, 22),
		Parent = top,
	})

	local hpLabel = create("TextLabel", {
		Name = "HP",
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "HP: —",
		TextColor3 = TEXT,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 58),
		Size = UDim2.new(1, -28, 0, 20),
		Parent = top,
	})

	local metaLabel = create("TextLabel", {
		Name = "Meta",
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "Lv —  ·  Lives —",
		TextColor3 = MUTED,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 82),
		Size = UDim2.new(1, -28, 0, 18),
		Parent = top,
	})

	local statusLabel = create("TextLabel", {
		Name = "Status",
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "Waiting for server…",
		TextColor3 = MUTED,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 104),
		Size = UDim2.new(1, -28, 0, 18),
		Parent = top,
	})

	local logPanel = create("Frame", {
		Name = "Log",
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(520, 40),
		Parent = gui,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = logPanel })
	local logLabel = create("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "Click a highlighted square to move. Red = attack.",
		TextColor3 = TEXT,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = logPanel,
	})

	local rerollButton = create("TextButton", {
		Name = "Reroll",
		BackgroundColor3 = Color3.fromRGB(40, 70, 110),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		Text = "Reroll (1)",
		TextColor3 = TEXT,
		TextSize = 16,
		Position = UDim2.new(1, -160, 0, 16),
		Size = UDim2.fromOffset(144, 44),
		AutoButtonColor = true,
		Parent = gui,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = rerollButton })

	local restartButton = create("TextButton", {
		Name = "Restart",
		BackgroundColor3 = Color3.fromRGB(120, 40, 60),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Restart Run",
		TextColor3 = TEXT,
		TextSize = 18,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(220, 56),
		AutoButtonColor = true,
		Parent = gui,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = restartButton })

	local self = setmetatable({
		_gui = gui,
		_title = title,
		_pieceLabel = pieceLabel,
		_hpLabel = hpLabel,
		_metaLabel = metaLabel,
		_statusLabel = statusLabel,
		_logLabel = logLabel,
		_rerollButton = rerollButton,
		_restartButton = restartButton,
		_onReroll = nil :: (() -> ())?,
		_onRestart = nil :: (() -> ())?,
	}, HudController)

	rerollButton.MouseButton1Click:Connect(function()
		if self._onReroll ~= nil then
			self._onReroll()
		end
	end)
	restartButton.MouseButton1Click:Connect(function()
		if self._onRestart ~= nil then
			self._onRestart()
		end
	end)

	return self
end

function HudController.onReroll(self, callback: () -> ())
	self._onReroll = callback
end

function HudController.onRestart(self, callback: () -> ())
	self._onRestart = callback
end

function HudController.render(self, snapshot)
	if snapshot == nil then
		return
	end

	local piece = snapshot.activePiece or "—"
	local inv = if snapshot.invulnerable then "  [INVULN]" else ""
	self._pieceLabel.Text = string.format("Piece: %s%s", piece, inv)
	self._hpLabel.Text = string.format(
		"HP: %s / %s",
		tostring(snapshot.activeHealth),
		tostring(snapshot.activeMaxHealth)
	)
	self._metaLabel.Text = string.format(
		"Lv %s  ·  Lives left %d  ·  Enemies %d",
		tostring(snapshot.level),
		#(snapshot.roster or {}),
		#(snapshot.enemies or {})
	)

	local rerolls = snapshot.rerollsRemaining or 0
	self._rerollButton.Text = string.format("Reroll (%d)", rerolls)
	self._rerollButton.Visible = not snapshot.runOver
	self._rerollButton.Active = rerolls > 0
	self._rerollButton.BackgroundColor3 = if rerolls > 0
		then Color3.fromRGB(40, 70, 110)
		else Color3.fromRGB(40, 40, 50)

	self._restartButton.Visible = snapshot.runOver == true

	if snapshot.runOver then
		self._statusLabel.Text = "Run over — roster exhausted"
		self._statusLabel.TextColor3 = DANGER
		self._logLabel.Text = "All pieces lost. Restart to try again."
	else
		self._statusLabel.Text = "Your turn — click a green/red square"
		self._statusLabel.TextColor3 = OK
	end

	local last = snapshot.lastResult
	if type(last) == "table" then
		local bits = {}
		if last.playerDamageDealt and last.playerDamageDealt > 0 then
			table.insert(
				bits,
				string.format(
					"Dealt %s%s",
					tostring(last.playerDamageDealt),
					if last.crit then " CRIT" else ""
				)
			)
		end
		if last.playerDamageTaken and last.playerDamageTaken > 0 then
			table.insert(bits, string.format("Took %s", tostring(last.playerDamageTaken)))
		end
		if last.enemyDied then
			table.insert(bits, "Enemy down")
		end
		if last.pierced then
			table.insert(bits, "Pierce!")
		end
		if last.levelCleared then
			table.insert(bits, "Level clear")
		end
		if last.runOver then
			table.insert(bits, "RUN OVER")
		end
		if #bits > 0 then
			self._logLabel.Text = table.concat(bits, "  ·  ")
		end
	end
end

function HudController.destroy(self)
	if self._gui ~= nil then
		self._gui:Destroy()
	end
end

return HudController
