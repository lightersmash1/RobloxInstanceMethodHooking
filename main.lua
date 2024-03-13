-- by lightersmash 3/13/2024 2 AM

local FakeInstHooks = {
	index = {
		["Instance.Name"] = function(Object) return "LOL" end
	},
	newindex = {
		
	}
}

local function LoopAllTBLs(Tbl, Callback)
	local NewTbl = table.clone(Tbl)
	for I, V in pairs (Tbl) do
		if type(V) == "table" then
			LoopAllTBLs(V, Callback)
		else
			NewTbl[I] = Callback(V)
		end
	end
	return NewTbl
end

local function MakeFakeInstance(Object)
	local IsFakeInstance, _ = pcall(function()
		local abc = Object["_instance"]
	end)
	
	if IsFakeInstance then
		return Object
	end
	
	local Class = Object.ClassName
	local FakeInstance = newproxy(true)
	local mt = getmetatable(FakeInstance)
	
	mt.__index = function(self, key)
		if key == "_instance" then
			return Object
		end
		for I, V in pairs (FakeInstHooks.index) do
			local Class = string.split(I, ".")[1]
			local PropName = string.split(I, ".")[2]
			if Object:IsA(Class) and key == PropName then
				return V(Object)
			end
		end
		local Result
		local IsValidProperty, _ = pcall(function()
			Result = Object[key]
		end)
		local Type = typeof(Result)
		if Type == "function" then
			return function(...)
				local Arguments = {...}
				Arguments[1] = Object
				for I, V in pairs (Arguments) do
					if typeof(V) == "Instance" then
						-- Convert it back
						pcall(function()
							Arguments[I] = V["_instance"]
						end)
					elseif typeof(V) == "table" then
						Arguments[I] = LoopAllTBLs(V, function(Value)
							if typeof(Value) == "Instance" then
								local Inst = Value
								pcall(function()
									Inst = V["_instance"]
								end)
								return Inst
							end
							return Value
						end)
					end
				end
				local Res = Result(unpack(Arguments))
				local ResType = typeof(Res)
				if ResType == "Instance" then
					return MakeFakeInstance(Res)
				elseif ResType == "table" then
					return LoopAllTBLs(Res, function(V)
						if typeof(V) == "Instance" then
							return MakeFakeInstance(V)
						end
						return V
					end)
				end
				return Res
			end
		elseif Type == "Instance" then --  or Type == "nil"
			return MakeFakeInstance(Result)
		elseif Type == "table" then
			return LoopAllTBLs(Result, function(V)
				if typeof(V) == "Instance" then
					return MakeFakeInstance(V)
				end
				return V
			end)
		end
		return Result
	end
	
	mt.__newindex = function(self, key, value)
		local NewValue = value
		local ValType = typeof(value)
		if ValType == "Instance" then
			pcall(function()
				NewValue = NewValue["_instance"]
			end)
		end

		for I, V in pairs (FakeInstHooks.newindex) do
			local Class = string.split(I, ".")[1]
			local PropName = string.split(I, ".")[2]
			if Object:IsA(Class) and key == PropName then
				return V(Object, value)
			end
		end

		Object[key] = NewValue
	end
	
	mt.__metatable = "The metatable is locked"
	
	return FakeInstance
end

function InitializeHooksInCurrentEnvironment()
	-- why is roblox removing setfenv (there's no alternative to it)
	
	local CurrentEnvironment = getfenv(2)
	
	local NewEnvironment = setmetatable({}, {
		__index = function(self, key)
			local Result = rawget(self, key) or CurrentEnvironment[key]
			if typeof(Result) == "Instance" then
				return MakeFakeInstance(Result)
			end
			return Result
		end,
		__newindex = function(self, key, value)
			rawset(self, key, value)
		end,
	})
	
	setfenv(2, NewEnvironment)
	
end

function test()
	InitializeHooksInCurrentEnvironment()
	
	for I, V in pairs (game:GetDescendants()) do
		print(V)
		print(V.Name)
	end
end

test()
