local InputH = {}
local Combat = require(script.Parent:WaitForChild("Combat_Handler"))

function InputH.Input(input, processed, player)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Combat.Normal(player)
	end
end

return InputH