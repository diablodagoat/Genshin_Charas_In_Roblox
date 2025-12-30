local Rs = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local VFXRemote = Rs:WaitForChild("Remotes"):WaitForChild("VFX_Replicator")
local Vfxes = Rs:WaitForChild("Vfxes")

-- VFX Bases
local BURST_1 = Vfxes:WaitForChild("Normal(First)"):WaitForChild("burst1")
local BURST_2 = Vfxes:WaitForChild("Normal(First)"):WaitForChild("Burst2")

local function playEffect(template, cf)
	local clone = template:Clone()
	clone.CFrame = cf -- Now setting the full CFrame (Pos + Rot)
	clone.Anchored = true
	clone.CanCollide = false
	clone.Transparency = 1
	clone.Parent = workspace

	-- Fire particles
	for _, p in ipairs(clone:GetDescendants()) do
		if p:IsA("ParticleEmitter") then
			p:Emit(p:GetAttribute("EmitCount") or 15)
		end
	end

	Debris:AddItem(clone, 2)
end

VFXRemote.OnClientEvent:Connect(function(attacker, impactPos)
	local a_char = attacker.Character
	local a_root = a_char and a_char:FindFirstChild("HumanoidRootPart")

	-- Define the 90 degree tilt
	local tilt = CFrame.Angles(math.rad(90), 0, 0)

	if a_root then
		-- 1. Burst at Player (Rotated 90 degrees on X)
		-- We take player's position/rotation, move it forward, then tilt it
		local playerEffectCF = (a_root.CFrame * CFrame.new(0, 0, -2)) * tilt
		playEffect(BURST_1, playerEffectCF)
	end

	-- 2. Burst at Impact (Rotated 90 degrees on X)
	if impactPos then
		-- Create CFrame at impact position, facing player, then tilt it 90 degrees
		local impactCF = CFrame.lookAt(impactPos, a_root and a_root.Position or impactPos + Vector3.new(0,0,1))
		impactCF = impactCF * tilt

		playEffect(BURST_2, impactCF)
	end
end)