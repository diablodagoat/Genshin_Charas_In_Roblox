local Combat = {}

--[ SERVICES ]--
local Rs = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

--[ ASSETS ]--
local AnimFolder = Rs:WaitForChild("Animations")
local Remotes = Rs:WaitForChild("Remotes")
local NormalRemote = Remotes:WaitForChild("Normal")

--[ CONFIGURATION ]--
local SETTINGS = {
	DEFAULT_WALKSPEED = 16,
	COMBO_RESET_TIME = 1.5,
	COOLDOWN_TIME = 0.4,
	ANIM_SPEED = 2,
	HIT_RANGE = 15, -- How far away the auto-rotate/look-at works
}

--[ MEMORY CACHE ]--
local playerCombos = {}
local loadedTracks = {} -- Stores tracks so we don't call LoadAnimation() repeatedly

--[ PREPARATION ]--
local AnimList = AnimFolder:GetChildren()
table.sort(AnimList, function(a, b)
	local numA = tonumber(a.Name:match("_(%d+)$")) or 0
	local numB = tonumber(b.Name:match("_(%d+)$")) or 0
	return numA < numB
end)

--[ PRIVATE FUNCTIONS ]--

-- Smoothly rotates player to target
local function localLookAt(root, target)
	if not target then return end

	local lookPos = Vector3.new(target.Position.X, root.Position.Y, target.Position.Z)
	local targetCFrame = CFrame.lookAt(root.Position, lookPos)

	TweenService:Create(root, TweenInfo.new(0.1), {CFrame = targetCFrame}):Play()
end

-- Caches animations for a specific animator to prevent "LoadAnimation" lag
local function getPlayerTracks(animator)
	if loadedTracks[animator] then return loadedTracks[animator] end

	local tracks = {}
	for i, animObj in ipairs(AnimList) do
		local track = animator:LoadAnimation(animObj)
		track.Priority = Enum.AnimationPriority.Action
		tracks[i] = track
	end

	loadedTracks[animator] = tracks

	-- Cleanup cache when animator is destroyed
	animator.AncestryChanged:Connect(function(_, parent)
		if not parent then loadedTracks[animator] = nil end
	end)

	return tracks
end

--[ PUBLIC API ]--

function Combat.Normal(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	-- 1. Safety Checks
	if not (animator and humanoid and root) or humanoid.Health <= 0 then return end

	-- 2. Combo Data Management
	if not playerCombos[player] then
		playerCombos[player] = {count = 1, lastHit = 0, isAttacking = false}
	end
	local data = playerCombos[player]

	-- 3. Cooldown & Debounce
	local currentTime = os.clock()
	if data.isAttacking or (currentTime - data.lastHit < SETTINGS.COOLDOWN_TIME) then return end

	-- Reset combo if too much time passed
	if currentTime - data.lastHit > SETTINGS.COMBO_RESET_TIME then 
		data.count = 1 
	end

	-- 4. Get Cached Animation
	local tracks = getPlayerTracks(animator)
	local animTrack = tracks[data.count]
	if not animTrack then return end

	-- 5. Execute Attack Visuals
	data.isAttacking = true
	data.lastHit = currentTime

	-- Stop movement
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	root.AssemblyLinearVelocity = Vector3.zero -- Stops sliding

	-- Play Animation (Instant response)
	animTrack:Play(0.1) -- 0.1 fade for smoothness
	animTrack:AdjustSpeed(SETTINGS.ANIM_SPEED)

	-- 6. Target Selection (Rotation)
	local closestDist = SETTINGS.HIT_RANGE
	local closestRoot = nil
	for _, obj in ipairs(workspace:GetChildren()) do
		local t_root = obj:FindFirstChild("HumanoidRootPart")
		local t_hum = obj:FindFirstChildOfClass("Humanoid")
		if t_root and t_hum and obj ~= character and t_hum.Health > 0 then
			local d = (root.Position - t_root.Position).Magnitude
			if d < closestDist then
				closestDist = d
				closestRoot = t_root
			end
		end
	end
	localLookAt(root, closestRoot)

	-- 7. Hit Detection Event (Server Request)
	local hitConnection
	hitConnection = animTrack:GetMarkerReachedSignal("Hit"):Connect(function()
		NormalRemote:FireServer(data.count) -- Tell server which hit in the combo this is
		hitConnection:Disconnect()
	end)

	-- 8. Movement Cleanup
	local stopConnection
	stopConnection = animTrack.Stopped:Connect(function()
		humanoid.WalkSpeed = SETTINGS.DEFAULT_WALKSPEED
		humanoid.AutoRotate = true
		data.isAttacking = false

		-- Increment combo
		data.count = (data.count % #AnimList) + 1

		stopConnection:Disconnect()
		if hitConnection then hitConnection:Disconnect() end
	end)
end

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(p)
	playerCombos[p] = nil
end)

return Combat