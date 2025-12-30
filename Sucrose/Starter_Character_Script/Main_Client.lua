local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game.Players.LocalPlayer

local Modules = ReplicatedStorage:WaitForChild("Modules")
local InputHandler = require(Modules:WaitForChild("Input_Handler"))

UIS.InputBegan:Connect(function(i, e)
	InputHandler.Input(i, e, player)
end)