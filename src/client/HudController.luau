-- ScreenGui HUD: combat status, metrics, shop buttons, reroll/restart.
local HudController = {}
HudController.__index = HudController

local PANEL = Color3.fromRGB(18, 28, 48)
local TEXT = Color3.fromRGB(240, 246, 255)
local MUTED = Color3.fromRGB(160, 178, 205)
local ACCENT = Color3.fromRGB(90, 180, 255)
local DANGER = Color3.fromRGB(244, 114, 140)
local GOLD = Color3.fromRGB(240, 200, 90)

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
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(380, 150),
		Parent = gui,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = top })

	create("TextLabel", {
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
		Position = UDim2.fromOffset(14, 32),
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
		Position = UDim2.fromOffset(14, 56),
		Size = UDim2.new(1, -28, 0, 20),
		Parent = top,
	})

	local metaLabel = create("TextLabel", {
		Name = "Meta",
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "Lv —",
		TextColor3 = MUTED,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 78),
		Size = UDim2.new(1, -28, 0, 18),
		Parent = top,
	})

	local currencyLabel = create("TextLabel", {
		Name = "Currency",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = "Gold: 0",
		TextColor3 = GOLD,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 98),
		Size = UDim2.new(1, -28, 0, 18),
		Parent = top,
	})

	local metricsLabel = create("TextLabel", {
		Name = "Metrics",
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "Metrics: —",
		TextColor3 = MUTED,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 120),
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
		Size = UDim2.fromOffset(560, 40),
		Parent = gui,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = logPanel })
	local logLabel = create("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "Hover red tiles: damage preview. Click to move/attack.",
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
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(220, 56),
		AutoButtonColor = true,
		Parent = gui,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = restartButton })

	local shopFrame = create("Frame", {
		Name = "Shop",
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -220, 0, 72),
		Size = UDim2.fromOffset(204, 280),
		Visible = false,
		Parent = gui,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = shopFrame })
	create("TextLabel", {
		Name = "ShopTitle",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "Shop (lives)",
		TextColor3 = GOLD,
		TextSize = 15,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = shopFrame,
	})
	local shopList = create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 34),
		Size = UDim2.new(1, -16, 1, -42),
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollBarThickness = 4,
		Parent = shopFrame,
	})
	local shopLayout = create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = shopList,
	})

	local self = setmetatable({
		_gui = gui,
		_pieceLabel = pieceLabel,
		_hpLabel = hpLabel,
		_metaLabel = metaLabel,
		_currencyLabel = currencyLabel,
		_metricsLabel = metricsLabel,
		_logLabel = logLabel,
		_rerollButton = rerollButton,
		_restartButton = restartButton,
		_shopFrame = shopFrame,
		_shopList = shopList,
		_shopLayout = shopLayout,
		_onReroll = nil :: (() -> ())?,
		_onRestart = nil :: (() -> ())?,
		_onBuy = nil :: ((string) -> ())?,
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

function HudController.onBuy(self, callback: (string) -> ())
	self._onBuy = callback
end

function HudController._renderShop(self, snapshot)
	for _, child in ipairs(self._shopList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local shop = snapshot.shop or {}
	self._shopFrame.Visible = snapshot.runOver == true or snapshot.phase == "GameOver"
	local order = 0
	for _, entry in ipairs(shop) do
		order += 1
		local canBuy = entry.canBuy == true
		local button = create("TextButton", {
			Name = "Buy_" .. entry.piece,
			BackgroundColor3 = if canBuy
				then Color3.fromRGB(50, 80, 50)
				else Color3.fromRGB(45, 45, 55),
			BorderSizePixel = 0,
			Font = Enum.Font.Gotham,
			Text = string.format("%s  %d g", entry.piece, entry.price),
			TextColor3 = if canBuy then TEXT else MUTED,
			TextSize = 14,
			Size = UDim2.new(1, -4, 0, 32),
			LayoutOrder = order,
			AutoButtonColor = canBuy,
			Parent = self._shopList,
		})
		create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = button })
		if canBuy then
			button.MouseButton1Click:Connect(function()
				if self._onBuy ~= nil then
					self._onBuy(entry.piece)
				end
			end)
		end
	end
	self._shopList.CanvasSize = UDim2.fromOffset(0, order * 38)
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
		tostring(snapshot.activeHealth or 0),
		tostring(snapshot.activeMaxHealth or 0)
	)
	self._metaLabel.Text = string.format(
		"Lv %s  ·  Lives left %d  ·  Enemies %d",
		tostring(snapshot.level or 0),
		#(snapshot.roster or {}),
		#(snapshot.enemies or {})
	)

	local currency = 0
	if snapshot.profile and type(snapshot.profile.currency) == "number" then
		currency = snapshot.profile.currency
	end
	self._currencyLabel.Text = string.format(
		"Gold: %d  ·  Roster lives: %d",
		currency,
		snapshot.profile and #(snapshot.profile.roster or {}) or 0
	)

	local m = snapshot.metrics
	if type(m) == "table" then
		self._metricsLabel.Text = string.format(
			"Session rounds %d · restart-after-loss %d/%d (%.0f%%)",
			m.roundsThisSession or 0,
			m.restartsAfterLoss or 0,
			m.runsEnded or 0,
			(m.restartAfterLossRate or 0) * 100
		)
	else
		self._metricsLabel.Text = "Metrics: waiting…"
	end

	local rerolls = snapshot.rerollsRemaining or 0
	self._rerollButton.Text = string.format("Reroll (%d)", rerolls)
	self._rerollButton.Visible = not snapshot.runOver
	self._rerollButton.Active = rerolls > 0
	self._rerollButton.BackgroundColor3 = if rerolls > 0
		then Color3.fromRGB(40, 70, 110)
		else Color3.fromRGB(40, 40, 50)

	self._restartButton.Visible = snapshot.runOver == true
	self:_renderShop(snapshot)

	if snapshot.runOver then
		self._logLabel.Text = "Run over. Buy lives in the shop, then Restart."
		self._logLabel.TextColor3 = DANGER
	else
		self._logLabel.TextColor3 = TEXT
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
