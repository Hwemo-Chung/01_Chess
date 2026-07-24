-- ScreenGui HUD: combat status, metrics, shop, reroll/restart/transcend.
-- Icons via IconAssets keys + IconSurface (cloud → asphalt → pixel embed → text).
-- Never converts TextButton → ImageButton (PRD §4.2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetUi = require(script.Parent:WaitForChild("AssetUi"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local IconSurface = require(script.Parent:WaitForChild("IconSurface"))
local Shared = ReplicatedStorage:WaitForChild("Chess"):WaitForChild("Shared")
local AssetIds = require(Shared:WaitForChild("AssetIds"))
local Config = require(Shared:WaitForChild("Config"))

local HudController = {}
HudController.__index = HudController

local PANEL = Color3.fromRGB(18, 28, 48)
local TEXT = Color3.fromRGB(240, 246, 255)
local MUTED = Color3.fromRGB(160, 178, 205)
local ACCENT = Color3.fromRGB(90, 180, 255)
local DANGER = Color3.fromRGB(244, 114, 140)
local OK = Color3.fromRGB(110, 220, 150)
local GOLD = Color3.fromRGB(240, 200, 90)

local ICON_STAT = 18
local ICON_BUTTON = 26
local ICON_SHOP = 22
local ICON_ROSTER = 22
local BOSS_BANNER_SECONDS = 2

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
		Size = UDim2.fromOffset(400, 168),
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
		Position = UDim2.fromOffset(14, 30),
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
		Position = UDim2.fromOffset(14, 52),
		Size = UDim2.new(0.55, -16, 0, 20),
		Parent = top,
	})

	local atkLabel = create("TextLabel", {
		Name = "ATK",
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "ATK: —",
		TextColor3 = TEXT,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0.55, 0, 0, 52),
		Size = UDim2.new(0.45, -14, 0, 20),
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
		Position = UDim2.fromOffset(14, 74),
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
		Position = UDim2.fromOffset(14, 94),
		Size = UDim2.new(1, -28, 0, 18),
		Parent = top,
	})

	local livesStrip = create("Frame", {
		Name = "LivesStrip",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 116),
		Size = UDim2.new(1, -28, 0, ICON_ROSTER + 2),
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
		Position = UDim2.fromOffset(14, 140),
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
		Position = UDim2.fromScale(0.5, 0.40),
		Size = UDim2.fromOffset(220, 52),
		AutoButtonColor = true,
		Parent = gui,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = restartButton })

	local transcendButton = create("TextButton", {
		Name = "Transcend",
		BackgroundColor3 = Color3.fromRGB(90, 50, 140),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Transcend (+T)",
		TextColor3 = TEXT,
		TextSize = 16,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(220, 48),
		AutoButtonColor = true,
		Parent = gui,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = transcendButton })

	local shopFrame = create("Frame", {
		Name = "Shop",
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -220, 0, 72),
		Size = UDim2.fromOffset(204, 360),
		Visible = false,
		Parent = gui,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = shopFrame })
	create("TextLabel", {
		Name = "ShopTitle",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "Shop",
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
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = shopList,
	})

	local bossBanner = create("Frame", {
		Name = "BossBanner",
		BackgroundColor3 = Color3.fromRGB(40, 12, 18),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(360, 88),
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = bossBanner })
	local bossIcon = create("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(64, 64),
		Position = UDim2.fromOffset(12, 12),
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
		Active = false,
		ZIndex = 21,
		Parent = bossBanner,
	})
	local bossTitle = create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "KING BOSS",
		TextColor3 = Color3.fromRGB(255, 180, 80),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(88, 18),
		Size = UDim2.new(1, -100, 0, 28),
		ZIndex = 21,
		Parent = bossBanner,
	})
	local bossSubtitle = create("TextLabel", {
		Name = "Subtitle",
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "Final encounter — survive and clear.",
		TextColor3 = TEXT,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(88, 48),
		Size = UDim2.new(1, -100, 0, 22),
		ZIndex = 21,
		Parent = bossBanner,
	})

	local self = setmetatable({
		_gui = gui,
		_pieceLabel = pieceLabel,
		_hpLabel = hpLabel,
		_atkLabel = atkLabel,
		_metaLabel = metaLabel,
		_currencyLabel = currencyLabel,
		_livesStrip = livesStrip,
		_metricsLabel = metricsLabel,
		_logLabel = logLabel,
		_rerollButton = rerollButton,
		_restartButton = restartButton,
		_transcendButton = transcendButton,
		_shopFrame = shopFrame,
		_shopList = shopList,
		_bossBanner = bossBanner,
		_bossIcon = bossIcon,
		_bossTitle = bossTitle,
		_bossSubtitle = bossSubtitle,
		_bossBannerShown = false,
		_bossBannerToken = 0,
		_lastHp = nil :: number?,
		_lastGold = nil :: number?,
		_lastUpgradeTotal = nil :: number?,
		_lastRosterCount = nil :: number?,
		_onReroll = nil :: (() -> ())?,
		_onRestart = nil :: (() -> ())?,
		_onBuy = nil :: ((string) -> ())?,
		_onBuyUpgrade = nil :: ((string) -> ())?,
		_onTranscend = nil :: (() -> ())?,
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
	transcendButton.MouseButton1Click:Connect(function()
		if self._onTranscend ~= nil then
			self._onTranscend()
		end
	end)

	-- Static action-button icons (IconSurface: cloud / asphalt / pixel pack).
	AssetUi.decorateButton(rerollButton, "Reroll", ICON_BUTTON)
	AssetUi.decorateButton(restartButton, "Restart", ICON_BUTTON)
	AssetUi.decorateButton(transcendButton, "Transcend", ICON_BUTTON)

	Fx.wireButton(rerollButton)
	Fx.wireButton(restartButton)
	Fx.wireButton(transcendButton)

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

function HudController.onBuyUpgrade(self, callback: (string) -> ())
	self._onBuyUpgrade = callback
end

function HudController.onTranscend(self, callback: () -> ())
	self._onTranscend = callback
end

local function renderLivesStrip(parent: Frame, roster: { string })
	parent:ClearAllChildren()
	local x = 0
	for index, pieceName in ipairs(roster) do
		local key = AssetUi.pieceBlueKey(pieceName)
		local icon = AssetUi.setIcon(
			parent,
			"Life_" .. tostring(index),
			key,
			ICON_ROSTER,
			UDim2.fromOffset(x, 0)
		)
		if icon == nil then
			-- Color chip fallback (02_add style) when pixels/URI unavailable.
			create("TextLabel", {
				Name = "Life_" .. tostring(index),
				BackgroundColor3 = Color3.fromRGB(40, 55, 80),
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				Text = string.sub(tostring(pieceName), 1, 1),
				TextColor3 = TEXT,
				TextSize = 12,
				Size = UDim2.fromOffset(ICON_ROSTER, ICON_ROSTER),
				Position = UDim2.fromOffset(x, 0),
				Parent = parent,
			})
		end
		x += ICON_ROSTER + 4
	end
end

function HudController._applyStatIcons(self, snapshot)
	AssetUi.decorateLabel(self._hpLabel, "Hp", ICON_STAT)
	AssetUi.decorateLabel(self._atkLabel, "Atk", ICON_STAT)
	AssetUi.decorateLabel(self._currencyLabel, "Gold", ICON_STAT)
	AssetUi.decorateLabel(self._metaLabel, "Level", ICON_STAT)

	local active = snapshot.activePiece
	local blueKey = if type(active) == "string" then AssetUi.pieceBlueKey(active) else nil
	AssetUi.decorateLabel(self._pieceLabel, blueKey, ICON_STAT)

	local tier = snapshot.currentTier
	local redKey = if type(tier) == "string" then AssetUi.pieceRedKey(tier) else nil
	AssetUi.setIcon(
		self._metaLabel,
		"TierIcon",
		redKey,
		ICON_STAT,
		UDim2.new(1, -(ICON_STAT + 2), 0, 0)
	)
end

function HudController._renderShop(self, snapshot)
	for _, child in ipairs(self._shopList:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local meta = snapshot.phase == "GameOver" or snapshot.phase == "Victory" or snapshot.runOver
	self._shopFrame.Visible = meta == true
	local order = 0
	local canvas = 0

	local function pushHeight(h: number)
		canvas += h + 6
	end

	create("TextLabel", {
		Name = "LivesHeader",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "Lives",
		TextColor3 = MUTED,
		TextSize = 12,
		Size = UDim2.new(1, -4, 0, 18),
		LayoutOrder = order,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self._shopList,
	})
	order += 1
	pushHeight(18)

	local roster = snapshot.roster or {}
	if #roster > 0 then
		local rosterRow = create("Frame", {
			Name = "RosterIcons",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -4, 0, ICON_ROSTER + 4),
			LayoutOrder = order,
			Parent = self._shopList,
		})
		order += 1
		pushHeight(ICON_ROSTER + 4)
		renderLivesStrip(rosterRow, roster)
	end

	for _, entry in ipairs(snapshot.shop or {}) do
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
		AssetUi.decorateButton(button, AssetUi.pieceBlueKey(entry.piece), ICON_SHOP)
		if canBuy then
			Fx.wireButton(button, true)
			button.MouseButton1Click:Connect(function()
				if self._onBuy ~= nil then
					self._onBuy(entry.piece)
				end
			end)
		end
		order += 1
		pushHeight(32)
	end

	create("TextLabel", {
		Name = "UpgradesHeader",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "Upgrades",
		TextColor3 = MUTED,
		TextSize = 12,
		Size = UDim2.new(1, -4, 0, 18),
		LayoutOrder = order,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self._shopList,
	})
	order += 1
	pushHeight(18)

	for _, entry in ipairs(snapshot.upgradeShop or {}) do
		local canBuy = entry.canBuy == true
		local button = create("TextButton", {
			Name = "Upgrade_" .. entry.id,
			BackgroundColor3 = if canBuy
				then Color3.fromRGB(60, 50, 90)
				else Color3.fromRGB(45, 45, 55),
			BorderSizePixel = 0,
			Font = Enum.Font.Gotham,
			Text = string.format("%s L%d  %dg", entry.displayName, entry.level, entry.price),
			TextColor3 = if canBuy then TEXT else MUTED,
			TextSize = 13,
			Size = UDim2.new(1, -4, 0, 32),
			LayoutOrder = order,
			AutoButtonColor = canBuy,
			Parent = self._shopList,
		})
		create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = button })
		AssetUi.decorateButton(button, AssetUi.upgradeKey(entry.id), ICON_SHOP)
		if canBuy then
			Fx.wireButton(button, true)
			button.MouseButton1Click:Connect(function()
				if self._onBuyUpgrade ~= nil then
					self._onBuyUpgrade(entry.id)
				end
			end)
		end
		order += 1
		pushHeight(32)
	end

	self._shopList.CanvasSize = UDim2.fromOffset(0, canvas)
end

function HudController._maybeShowBossBanner(self, snapshot)
	local bossLevel = AssetIds.bossLevel(Config)
	local level = snapshot.level or 0
	if level < bossLevel then
		self._bossBannerShown = false
		return
	end

	local hasBoss = false
	for _, enemy in ipairs(snapshot.enemies or {}) do
		if enemy.isBoss == true then
			hasBoss = true
			break
		end
	end
	if not hasBoss or self._bossBannerShown then
		return
	end

	self._bossBannerShown = true
	self._bossBannerToken += 1
	local token = self._bossBannerToken

	local ok = IconSurface.apply(self._bossIcon, AssetUi.bossKey())
	if ok then
		self._bossIcon.Visible = true
		self._bossTitle.Position = UDim2.fromOffset(88, 18)
		self._bossSubtitle.Position = UDim2.fromOffset(88, 48)
	else
		self._bossIcon.Visible = false
		self._bossTitle.Position = UDim2.fromOffset(20, 18)
		self._bossSubtitle.Position = UDim2.fromOffset(20, 48)
	end

	self._bossBanner.Visible = true
	task.delay(BOSS_BANNER_SECONDS, function()
		if self._bossBannerToken == token and self._bossBanner ~= nil then
			self._bossBanner.Visible = false
		end
	end)
end

local function activeAttack(snapshot): number?
	local piece = snapshot.activePiece
	if type(piece) ~= "string" then
		return nil
	end
	local base = Config.PIECES and Config.PIECES[piece]
	if type(base) ~= "table" or type(base.attack) ~= "number" then
		return nil
	end
	local attack = base.attack
	local profile = snapshot.profile
	if type(profile) == "table" and type(profile.upgrades) == "table" then
		local might = profile.upgrades.Might
		local def = Config.UPGRADES and Config.UPGRADES.Might
		if type(might) == "number" and might > 0 and type(def) == "table" then
			local per = def.perLevel or 0.06
			attack = attack * (1 + per * might)
		end
	end
	return math.floor(attack + 0.5)
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
	local atk = activeAttack(snapshot)
	self._atkLabel.Text = if atk ~= nil then string.format("ATK: %d", atk) else "ATK: —"

	local hp = tonumber(snapshot.activeHealth) or 0
	if self._lastHp ~= nil and hp ~= self._lastHp then
		Fx.pulseText(
			self._hpLabel,
			if hp < self._lastHp then Color3.fromRGB(255, 80, 70) else Color3.fromRGB(120, 230, 130)
		)
	end
	self._lastHp = hp

	self._metaLabel.Text = string.format(
		"Lv %s  ·  Tier %s  ·  Lives %d  ·  E %d",
		tostring(snapshot.level or 0),
		tostring(snapshot.currentTier or "—"),
		#(snapshot.roster or {}),
		#(snapshot.enemies or {})
	)

	local currency = 0
	local tLevel = snapshot.transcendenceLevel or 1
	if snapshot.profile and type(snapshot.profile.currency) == "number" then
		currency = snapshot.profile.currency
		tLevel = snapshot.profile.transcendenceLevel or tLevel
	end
	self._currencyLabel.Text = string.format(
		"Gold: %d  ·  T%d (soft)  ·  Roster %d",
		currency,
		tLevel,
		snapshot.profile and #(snapshot.profile.roster or {}) or 0
	)
	if self._lastGold ~= nil and currency ~= self._lastGold then
		Fx.pulseText(self._currencyLabel, GOLD)
	end
	self._lastGold = currency

	-- Purchase feedback: upgrade level or roster size going up = confirmed buy.
	local upgradeTotal = 0
	local rosterCount = 0
	if type(snapshot.profile) == "table" then
		if type(snapshot.profile.upgrades) == "table" then
			for _, level in pairs(snapshot.profile.upgrades) do
				if type(level) == "number" then
					upgradeTotal += level
				end
			end
		end
		rosterCount = #(snapshot.profile.roster or {})
	end
	if self._lastUpgradeTotal ~= nil and upgradeTotal > self._lastUpgradeTotal then
		Fx.sound("upgrade")
		Fx.pulseText(self._atkLabel, OK)
	end
	if self._lastRosterCount ~= nil and rosterCount > self._lastRosterCount then
		Fx.sound("buy")
	end
	self._lastUpgradeTotal = upgradeTotal
	self._lastRosterCount = rosterCount

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

	-- Top-bar lives (always during play; text chip fallback when no ids).
	renderLivesStrip(self._livesStrip, snapshot.roster or {})

	local rerolls = snapshot.rerollsRemaining or 0
	self._rerollButton.Text = string.format("Reroll (%d)", rerolls)
	self._rerollButton.Visible = not snapshot.runOver
	self._rerollButton.Active = rerolls > 0
	self._rerollButton.BackgroundColor3 = if rerolls > 0
		then Color3.fromRGB(40, 70, 110)
		else Color3.fromRGB(40, 40, 50)

	local finished = snapshot.runOver == true
		or snapshot.phase == "Victory"
		or snapshot.phase == "GameOver"
	self._restartButton.Visible = finished
	self._restartButton.Text = if snapshot.victory or snapshot.phase == "Victory"
		then "Continue (same T)"
		else "Restart Run"
	self._transcendButton.Visible = snapshot.victory == true or snapshot.phase == "Victory"

	self:_renderShop(snapshot)
	self:_applyStatIcons(snapshot)
	self:_maybeShowBossBanner(snapshot)

	if snapshot.victory or snapshot.phase == "Victory" then
		self._logLabel.Text = "VICTORY — King boss down. Shop, continue, or Transcend."
		self._logLabel.TextColor3 = OK
	elseif snapshot.runOver or snapshot.phase == "GameOver" then
		self._logLabel.Text = "Run over. Buy lives/upgrades, then Restart."
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
