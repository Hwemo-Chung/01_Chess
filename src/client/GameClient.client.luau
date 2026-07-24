-- Client composition: board + HUD + camera, server StateSync only for truth.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

print("[CHESS] GameClient starting…")

local BoardView = require(script.Parent:WaitForChild("BoardView"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))
local HudController = require(script.Parent:WaitForChild("HudController"))
local Fx = require(script.Parent:WaitForChild("Fx"))

local Shared = ReplicatedStorage:WaitForChild("Chess"):WaitForChild("Shared")
local BoardLayout = require(Shared:WaitForChild("BoardLayout"))

local player = Players.LocalPlayer
local board = BoardView.new()
local camera = CameraController.new(player)
local hud = HudController.new(player)
Fx.init(player:WaitForChild("PlayerGui"))

local latestSnapshot = nil
local cleaned = false

local pendingAttackPos: Vector3? = nil -- world pos of last clicked tile (popup anchor)
local pendingAttackGrid: { x: number, z: number }? = nil
local lastFxRound = -1

local function tileWorld(x: number, z: number): Vector3
	local wx, wy, wz = BoardLayout.gridToPieceWorld(x, z)
	return Vector3.new(wx, wy, wz)
end

local function playCombatFx(snapshot)
	local last = snapshot.lastResult
	if type(last) ~= "table" then
		return
	end
	local round = tonumber(snapshot.roundsPlayed) or 0
	if round == lastFxRound then
		return
	end
	lastFxRound = round

	local playerPos = if snapshot.activePosition ~= nil
		then tileWorld(snapshot.activePosition.x, snapshot.activePosition.z)
		else nil
	local hitPos = pendingAttackPos or playerPos
	local hitGrid = pendingAttackGrid
	pendingAttackPos = nil
	pendingAttackGrid = nil

	local dealt = tonumber(last.playerDamageDealt) or 0
	local taken = tonumber(last.playerDamageTaken) or 0

	-- Owner call: defense (damage taken) resolves FIRST, attack follows —
	-- never simultaneous, or the two explosion sounds smear together.
	local function takenFx()
		-- Attacker motion: counter comes from the attacked square, enemy-phase
		-- hits from whoever is nearest the player.
		local fromGrid = if dealt > 0 and hitGrid ~= nil then hitGrid else snapshot.activePosition
		if fromGrid ~= nil and playerPos ~= nil then
			board:lungeEnemyToward(fromGrid.x, fromGrid.z, playerPos)
		end
		if playerPos ~= nil then
			Fx.popup(playerPos, string.format("-%d", taken), Color3.fromRGB(255, 80, 70), false)
		end
		local part = board:getPlayerPart()
		if part ~= nil then
			Fx.punchPart(part, 1.25)
		end
		Fx.sound("hurt")
		Fx.flash(Color3.fromRGB(255, 30, 30), 0.75)
		Fx.shake(math.min(0.4 + taken * 0.15, 1.6))
	end

	local function dealtFx()
		if dealt > 0 and hitPos ~= nil then
			-- Attacker motion: player piece lunges into the target square.
			-- On a kill the capture arcMove IS the motion — skip the lunge.
			if not last.enemyDied and playerPos ~= nil then
				local playerPart = board:getPlayerPart()
				if playerPart ~= nil then
					Fx.lunge(playerPart, hitPos, playerPos)
				end
			end
			local crit = last.crit == true
			Fx.popup(
				hitPos,
				string.format("-%d%s", dealt, if crit then " CRIT!" else ""),
				if crit then Color3.fromRGB(255, 170, 40) else Color3.fromRGB(255, 240, 200),
				crit
			)
			Fx.sound(if crit then "crit" else "hit")
			if crit then
				Fx.shake(0.8)
				Fx.burst(hitPos, Color3.fromRGB(255, 170, 40), 12, 20, "sparkles")
			end
			if not last.enemyDied and hitGrid ~= nil then
				-- Survivor takes the hit — flash it white so damage reads on the piece.
				board:flashEnemyNear(hitGrid.x, hitGrid.z)
			end
		end
		if last.enemyDied then
			-- Kill = shake + burst only; no voice-y death sound (owner call).
			Fx.shake(0.5)
			if hitPos ~= nil then
				Fx.burst(hitPos, Color3.fromRGB(255, 120, 60), 22, nil, "fire")
				Fx.burst(hitPos, Color3.fromRGB(120, 120, 130), 8, 6, "smoke")
			end
		end
	end

	if taken > 0 and (dealt > 0 or last.enemyDied) then
		takenFx()
		task.delay(1, dealtFx) -- owner call: attack lands 1s after defense
	elseif taken > 0 then
		takenFx()
	else
		if dealt == 0 and not last.enemyDied then
			-- Plain move — landing thunk synced to the arc touchdown (~0.22s).
			task.delay(0.18, function()
				Fx.sound("move")
			end)
		end
		dealtFx()
	end
	if last.levelCleared then
		Fx.sound("clear")
	end
	if last.victory then
		Fx.sound("victory")
	elseif last.runOver then
		Fx.sound("defeat")
		Fx.flash(Color3.fromRGB(120, 0, 0), 0.6)
	end
end

local function remotesFolder()
	local chess = ReplicatedStorage:WaitForChild("Chess", 30)
	if chess == nil then
		warn("[CHESS] ReplicatedStorage.Chess missing")
		return nil
	end
	return chess:WaitForChild("Remotes", 30)
end

local function remote(name: string): RemoteEvent?
	local folder = remotesFolder()
	if folder == nil then
		return nil
	end
	local value = folder:FindFirstChild(name)
	if value ~= nil and value:IsA("RemoteEvent") then
		return value
	end
	local waited = folder:WaitForChild(name, 15)
	if waited ~= nil and waited:IsA("RemoteEvent") then
		return waited
	end
	return nil
end

local function applySnapshot(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	latestSnapshot = snapshot
	board:render(snapshot)
	hud:render(snapshot)
	camera:apply()
	playCombatFx(snapshot)
	print(
		string.format(
			"[CHESS] snapshot phase=%s piece=%s enemies=%s",
			tostring(snapshot.phase),
			tostring(snapshot.activePiece),
			tostring(snapshot.enemies and #snapshot.enemies)
		)
	)
end

local function isLegalMove(x: number, z: number): boolean
	if latestSnapshot == nil or type(latestSnapshot.legalMoves) ~= "table" then
		return false
	end
	for _, move in ipairs(latestSnapshot.legalMoves) do
		if move.x == x and move.z == z then
			return true
		end
	end
	return false
end

board:onTileClick(function(x, z)
	if latestSnapshot == nil or latestSnapshot.runOver then
		return
	end
	if not isLegalMove(x, z) then
		return
	end
	pendingAttackPos = tileWorld(x, z)
	pendingAttackGrid = { x = x, z = z }
	-- Instant click ping — response before the server round-trip.
	Fx.burst(tileWorld(x, z), Color3.fromRGB(240, 246, 255), 6, 6, "sparkles")
	local submit = remote("SubmitMove")
	if submit ~= nil then
		submit:FireServer(x, z)
	end
end)

hud:onReroll(function()
	if latestSnapshot == nil or latestSnapshot.runOver then
		return
	end
	if (latestSnapshot.rerollsRemaining or 0) <= 0 then
		return
	end
	local request = remote("RequestReroll")
	if request ~= nil then
		request:FireServer()
	end
end)

hud:onRestart(function()
	if latestSnapshot == nil or not latestSnapshot.runOver then
		return
	end
	local request = remote("RequestRestart")
	if request ~= nil then
		request:FireServer()
	end
end)

hud:onBuy(function(pieceType)
	local request = remote("RequestBuy")
	if request ~= nil then
		request:FireServer(pieceType)
	end
end)

hud:onBuyUpgrade(function(upgradeId)
	local request = remote("RequestBuyUpgrade")
	if request ~= nil then
		request:FireServer(upgradeId)
	end
end)

hud:onTranscend(function()
	if
		latestSnapshot == nil or not (latestSnapshot.victory or latestSnapshot.phase == "Victory")
	then
		return
	end
	local request = remote("RequestTranscend")
	if request ~= nil then
		request:FireServer()
	end
end)

-- Wire StateSync BEFORE requesting a snapshot (critical race fix).
local stateSync = remote("StateSync")
if stateSync ~= nil then
	stateSync.OnClientEvent:Connect(applySnapshot)
	print("[CHESS] StateSync connected")
else
	warn("[CHESS] StateSync remote missing — board will stay empty")
end

local function askServerForState()
	local req = remote("RequestStateSync")
	if req ~= nil then
		req:FireServer()
	end
end

askServerForState()
task.spawn(function()
	for _ = 1, 10 do
		if latestSnapshot ~= nil and latestSnapshot.activePiece ~= nil then
			return
		end
		task.wait(0.4)
		askServerForState()
		camera:apply()
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if
		input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch
	then
		return
	end
	local cameraObj = Workspace.CurrentCamera
	if cameraObj == nil then
		return
	end
	local position = input.Position
	local ray = cameraObj:ViewportPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	if player.Character ~= nil then
		table.insert(exclude, player.Character)
	end
	params.FilterDescendantsInstances = exclude
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if result == nil then
		return
	end
	board:handleClickPosition(result.Position)
end)

local function hideCharacter(character: Model)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = 1
			descendant.CanCollide = false
		end
	end
	-- Accessories stream in after spawn — hide those too, or the avatar pops in on the board.
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = 1
			descendant.CanCollide = false
		end
	end)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end
	-- Character spawn resets camera — reclaim top-down view.
	task.defer(function()
		camera:apply()
	end)
end

if player.Character ~= nil then
	hideCharacter(player.Character)
end
player.CharacterAdded:Connect(hideCharacter)

local function cleanup()
	if cleaned then
		return
	end
	cleaned = true
	board:destroy()
	camera:destroy()
	hud:destroy()
end

script.Destroying:Connect(cleanup)
print("[CHESS] GameClient ready")
