export type Utilities = {
	Get : (self : Utilities, initialInstance : Instance, path : string, findMode : boolean) -> Instance?,
	Tween : (self : Utilities, instance : Instance, tweenInfo : TweenInfo, properties : {[string] : any}, callbackData : {ExecutionType : "Before" | "After", Callback : () -> ()}) -> (),
	Create : (self : Utilities, className : string) -> ({[string] : any}) -> Instance
}

local TweenService = cloneref(game:GetService("TweenService"))

local utilities : Utilities = {} :: Utilities

function utilities:Tween(instance : Instance, tweenInfo : TweenInfo, properties : {[string] : any}, callbackData : {ExecutionType : "Before" | "After", Callback : () -> ()})
	local tweenInstance = TweenService:Create(instance, tweenInfo, properties)
	if callbackData and callbackData.ExecutionType == "Before" then
		callbackData.Callback()
	end
	if tweenInstance.PlaybackState == Enum.PlaybackState.Begin then
		tweenInstance:Play()
	end
	tweenInstance.Completed:Connect(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed then
			if callbackData and callbackData.ExecutionType == "After" then
				callbackData.Callback()
			end
		end
	end)
end

function utilities:Get(initialInstance : Instance, path : string, findMode : boolean) : Instance?
	local splittedPath = string.split(path, ".")
	local currentInstance = initialInstance
	if table.maxn(splittedPath) <= 0 then
		return nil
	end
	for _, value in splittedPath do
		if not currentInstance then
			break
		end
		if currentInstance == game then
			currentInstance = currentInstance:GetService(value)
		elseif findMode then
			currentInstance = currentInstance:WaitForChild(value)
		else
			currentInstance = currentInstance:FindFirstChild(value)
		end
	end
	return currentInstance
end

function utilities:Create(className : string) : ({[string] : any}) -> Instance
	local instance = Instance.new(className)
	local clonedInstance = cloneref(instance)
	local instanceMetatable = getrawmetatable(clonedInstance)
	local originalIndex = rawget(instanceMetatable, "__index")
	local originalNamecall = rawget(instanceMetatable, "__namecall")
	local originalNewIndex = rawget(instanceMetatable, "__newindex")
	setreadonly(instanceMetatable, false)
	rawset(instanceMetatable, "__index", newcclosure(function(self, index)
		if (self == instance or self == clonedInstance) and not checkcaller() then
			return error("The current thread cannot access '" .. tostring(self) .. "' (lacking capability RobloxScript)")
		end
		return originalIndex(self, index)
	end))
	rawset(instanceMetatable, "__namecall", newcclosure(function(self, ...)
		if (self == instance or self == clonedInstance) and not checkcaller() then
			return error("The current thread cannot access '" .. tostring(self) .. "' (lacking capability RobloxScript)")
		end
		return originalNamecall(self, ...)
	end))
	rawset(instanceMetatable, "__newindex", newcclosure(function(self, index, value)
		if (self == instance or self == clonedInstance) and not checkcaller() then
			return error("The current thread cannot access '" .. tostring(self) .. "' (lacking capability RobloxScript)")
		end
		return originalNewIndex(self, index, value)
	end))
	setreadonly(instanceMetatable, true)
	return function(properties)
		for index, value in properties do
			if typeof(index) == "number" then
				value.Parent = instance
			elseif typeof(instance[index]) == "RBXScriptSignal" then
				instance[index]:Connect(value)
			else
				instance[index] = value
			end
		end
		return instance
	end
end

return utilities
