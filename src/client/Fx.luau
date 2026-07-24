-- Client-only juice: sounds, damage popups, camera shake, screen flash, UI punch.
-- Benchmark basis: docs/JUICE_BENCHMARK.md (Juice it or Lose it / Vlambeer screenshake).
-- Server truth untouched — everything here is cosmetic feedback on snapshots.

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Fx = {}

-- Built-in engine sounds (rbxasset): load offline, no upload/moderation needed.
-- ONLY files that actually ship in current Studio content/sounds/ (11 total) —
-- classic names like swordslash.wav no longer exist. Verified 2026-07-24.
local SOUNDS = {
	-- Owner call 2026-07-24: attack AND defense both use the big explosion sound
	-- (pitch tells them apart); voice-y death sounds (ouch/oof) are banned.
	hit = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.55, speed = 1.3 },
	crit = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.7, speed = 1.1 },
	hurt = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.6, speed = 0.8 },
	clear = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.7, speed = 1.1 },
	victory = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.7, speed = 0.9 },
	defeat = { id = "rbxasset://sounds/action_falling.ogg", volume = 0.7, speed = 0.8 },
	click = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.5, speed = 1.0 },
	upgrade = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.7, speed = 1.3 },
	buy = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.6, speed = 1.2 },
	move = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.5, speed = 1.0 },
}

function Fx.sound(name: string)
	local def = SOUNDS[name]
	if def == nil then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def.id
	sound.Volume = def.volume
	-- ±5% pitch jitter so repeated hits don't sound machine-gun identical.
	sound.PlaybackSpeed = def.speed * (0.95 + math.random() * 0.1)
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 3)
end

-- Floating combat text at a world position. big = crit styling.
function Fx.popup(worldPos: Vector3, text: string, color: Color3, big: boolean?)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = worldPos
	anchor.Parent = Workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 60)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = if big then 34 else 24
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Text = text
	label.Parent = gui

	local rise = TweenService:Create(
		gui,
		TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ StudsOffset = Vector3.new(0, if big then 5.2 else 4.4, 0) }
	)
	local fade = TweenService:Create(
		label,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	rise:Play()
	task.delay(0.35, function()
		fade:Play()
	end)
	Debris:AddItem(anchor, 0.9)
end

-- Decaying random camera shake. Concurrent calls just extend/boost the current one.
local shakeMagnitude = 0
local shakeRunning = false

function Fx.shake(magnitude: number)
	shakeMagnitude = math.max(shakeMagnitude, magnitude)
	if shakeRunning then
		return
	end
	shakeRunning = true
	task.spawn(function()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			shakeRunning = false
			return
		end
		local base = camera.CFrame
		while shakeMagnitude > 0.05 do
			local offset = Vector3.new(
				(math.random() - 0.5) * 2 * shakeMagnitude,
				(math.random() - 0.5) * 2 * shakeMagnitude,
				0
			)
			camera.CFrame = base * CFrame.new(offset)
			shakeMagnitude *= 0.75
			task.wait(0.03)
		end
		camera.CFrame = base
		shakeMagnitude = 0
		shakeRunning = false
	end)
end

-- Full-screen color flash (e.g. red on damage taken). Needs one-time init.
local flashFrame: Frame? = nil

function Fx.init(playerGui: Instance)
	if flashFrame ~= nil then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChessFx"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.new(1, 0, 0)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = 10
	frame.Parent = gui
	flashFrame = frame
end

function Fx.flash(color: Color3, peakTransparency: number)
	local frame = flashFrame
	if frame == nil then
		return
	end
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = peakTransparency
	TweenService:Create(
		frame,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	):Play()
end

-- Built-in engine particle textures (verified on disk 2026-07-25).
local BURST_TEXTURES = {
	sparkles = "rbxasset://textures/particles/sparkles_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}

-- One-shot particle burst (kill confirm, crit spark, click ping).
-- textureKey: sparkles | fire | smoke; nil = default emitter texture.
function Fx.burst(
	worldPos: Vector3,
	color: Color3,
	count: number,
	speed: number?,
	textureKey: string?
)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = worldPos
	anchor.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	if textureKey ~= nil and BURST_TEXTURES[textureKey] ~= nil then
		emitter.Texture = BURST_TEXTURES[textureKey]
	end
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.25, 0.5)
	emitter.Speed = NumberRange.new(speed or 14, (speed or 14) * 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(count)
	Debris:AddItem(anchor, 1)
end

-- Piece movement: eased slide with parabolic hop (picked-up-and-placed feel).
-- Knights get a high arc, sliders a low one. New call on same part cancels the old.
function Fx.arcMove(part: BasePart, target: Vector3, height: number, duration: number)
	local start = part.Position
	if (start - target).Magnitude < 0.01 then
		part.Position = target
		return
	end
	local token = (part:GetAttribute("FxMoveToken") :: number? or 0) + 1
	part:SetAttribute("FxMoveToken", token)
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			local dt = RunService.Heartbeat:Wait()
			if part.Parent == nil or part:GetAttribute("FxMoveToken") ~= token then
				return
			end
			elapsed += dt
			local alpha = math.clamp(elapsed / duration, 0, 1)
			local eased = 1 - (1 - alpha) ^ 2
			part.Position = start:Lerp(target, eased)
				+ Vector3.new(0, math.sin(math.pi * eased) * height, 0)
		end
		part.Position = target
	end)
end

-- Attack lunge: dash 45% toward the target, settle back home.
-- home = tile-true position; shares FxMoveToken so it cancels/loses to arcMove cleanly.
function Fx.lunge(part: BasePart, target: Vector3, home: Vector3)
	local token = (part:GetAttribute("FxMoveToken") :: number? or 0) + 1
	part:SetAttribute("FxMoveToken", token)
	task.spawn(function()
		local mid = home:Lerp(target, 0.45) + Vector3.new(0, 0.6, 0)
		local function seg(from: Vector3, to: Vector3, duration: number, easeOut: boolean)
			local elapsed = 0
			while elapsed < duration do
				local dt = RunService.Heartbeat:Wait()
				if part.Parent == nil or part:GetAttribute("FxMoveToken") ~= token then
					return false
				end
				elapsed += dt
				local alpha = math.clamp(elapsed / duration, 0, 1)
				local eased = if easeOut then 1 - (1 - alpha) ^ 2 else alpha * alpha
				part.Position = from:Lerp(to, eased)
			end
			return true
		end
		if not seg(home, mid, 0.09, false) then
			return
		end
		if not seg(mid, home, 0.16, true) then
			return
		end
		part.Position = home
	end)
end

-- Scale-in for freshly spawned pieces.
function Fx.spawnIn(part: BasePart)
	local size = part.Size
	part.Size = size * 0.05
	TweenService:Create(
		part,
		TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = size }
	):Play()
end

-- Shrink-and-fade death for removed pieces; caller forgets the part after this.
function Fx.dieOut(part: BasePart)
	part:SetAttribute("FxMoveToken", -1)
	local gui = part:FindFirstChildWhichIsA("BillboardGui")
	if gui ~= nil then
		gui:Destroy()
	end
	TweenService:Create(
		part,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = part.Size * 0.05, Transparency = 1 }
	):Play()
	Debris:AddItem(part, 0.25)
end

-- White Highlight flash — reads as "hit" regardless of the part's base color.
function Fx.hitFlash(part: BasePart)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.15
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = part
	highlight.Parent = part
	TweenService:Create(
		highlight,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FillTransparency = 1, OutlineTransparency = 1 }
	):Play()
	Debris:AddItem(highlight, 0.25)
end

-- Quick scale punch on a 3D part (attack impact on the piece).
function Fx.punchPart(part: BasePart, factor: number)
	local original = part.Size
	part.Size = original * factor
	TweenService:Create(
		part,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = original }
	):Play()
end

-- Text pulse for HUD stat changes (HP drop, gold gain).
-- Base color/size cached in attributes so overlapping pulses don't drift.
function Fx.pulseText(label: TextLabel, color: Color3)
	local baseColor = label:GetAttribute("FxBaseColor") :: Color3?
	if baseColor == nil then
		baseColor = label.TextColor3
		label:SetAttribute("FxBaseColor", baseColor)
	end
	local baseSize = label:GetAttribute("FxBaseSize") :: number?
	if baseSize == nil then
		baseSize = label.TextSize
		label:SetAttribute("FxBaseSize", baseSize)
	end
	label.TextColor3 = color
	label.TextSize = (baseSize :: number) + 4
	TweenService:Create(
		label,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TextColor3 = baseColor, TextSize = baseSize }
	):Play()
end

-- Hover/press feedback so buttons feel alive. Call once per button.
-- pressOnly: no hover growth — use inside list layouts (resize would reflow rows).
function Fx.wireButton(button: GuiButton, pressOnly: boolean?)
	if button:GetAttribute("FxWired") == true then
		return
	end
	button:SetAttribute("FxWired", true)
	local baseSize = button.Size
	if pressOnly ~= true then
		button.MouseEnter:Connect(function()
			TweenService:Create(
				button,
				TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = baseSize + UDim2.fromOffset(4, 2) }
			):Play()
		end)
		button.MouseLeave:Connect(function()
			TweenService:Create(
				button,
				TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = baseSize }
			):Play()
		end)
	end
	button.MouseButton1Down:Connect(function()
		Fx.sound("click")
		TweenService:Create(
			button,
			TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = baseSize - UDim2.fromOffset(4, 2) }
		):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(
			button,
			TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = baseSize }
		):Play()
	end)
end

return Fx
