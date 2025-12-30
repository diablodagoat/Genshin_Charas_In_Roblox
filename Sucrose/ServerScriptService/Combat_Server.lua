local Rs = game:GetService("ReplicatedStorage")
local NormalRemote = Rs:WaitForChild("Remotes"):WaitForChild("Normal")
local VFXRemote = Rs:WaitForChild("Remotes"):WaitForChild("VFX_Replicator")

-- Configuration
local MAX_DISTANCE = 18 -- Slightly strict distance check
local DAMAGE = 10
local COOLDOWN = 0.35 -- Must match or be slightly lower than client
local ROTATION_SNAP_TIME = 0.2

-- Memory Store
local lastAttack = {}

-- Helper: Verify if the hit is physically possible
local function isHitValid(attackerRoot, victimRoot)
    if not victimRoot then return false end
    local dist = (attackerRoot.Position - victimRoot.Position).Magnitude
    return dist <= MAX_DISTANCE
end

local function applyPhysicalRotation(root, targetPart)
    local att = root:FindFirstChild("CombatAttachment") or Instance.new("Attachment")
    att.Name = "CombatAttachment"
    att.Parent = root

    local align = root:FindFirstChild("CombatAlign") or Instance.new("AlignOrientation")
    align.Name = "CombatAlign"
    align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    align.Attachment0 = att
    align.RigidityEnabled = true
    
    local direction = (targetPart.Position - root.Position) * Vector3.new(1, 0, 1)
    if direction.Magnitude > 0 then
        align.CFrame = CFrame.lookAt(Vector3.zero, direction.Unit)
        align.Parent = root
    end

    task.delay(ROTATION_SNAP_TIME, function()
        if align then align:Destroy() end
    end)
end

NormalRemote.OnServerEvent:Connect(function(player, comboCount)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    
    -- 1. Basic Safety
    if not root or not hum or hum.Health <= 0 then return end
    
    -- 2. State Check (Anti-Spam during hit-stun)
    if char:GetAttribute("Stunned") then return end

    -- 3. Server-Side Debounce (The "Sane" Check)
    local now = os.clock()
    if lastAttack[player] and (now - lastAttack[player] < COOLDOWN) then
        warn(player.Name .. " is firing too fast!") -- Possible exploiter
        return 
    end
    lastAttack[player] = now

    -- 4. Validation (Find target but verify distance)
    local target = nil
    local closestDist = MAX_DISTANCE
    
    for _, obj in ipairs(workspace:GetChildren()) do
        local t_hum = obj:FindFirstChild("Humanoid")
        local t_root = obj:FindFirstChild("HumanoidRootPart")
        if t_hum and t_root and obj ~= char and t_hum.Health > 0 then
            local dist = (root.Position - t_root.Position).Magnitude
            if dist < closestDist then
                target = obj
                closestDist = dist
            end
        end
    end

    -- 5. Execution
    local impactPos
    if target then
        local t_root = target.HumanoidRootPart
        
        -- Final Sanity Check
        if isHitValid(root, t_root) then
            target.Humanoid:TakeDamage(DAMAGE)
            applyPhysicalRotation(root, t_root)
            impactPos = t_root.Position
        end
    else
        -- Miss: VFX logic
        impactPos = (root.CFrame * CFrame.new(0, 0, -5)).Position
    end

    -- 6. Replication
    VFXRemote:FireAllClients(player, impactPos, comboCount)
end)

-- Memory Cleanup
game:GetService("Players").PlayerRemoving:Connect(function(player)
    lastAttack[player] = nil
end)