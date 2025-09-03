--Working DragonBlox--
local FarmingThread = nil
local AutoFarm = false
local SelectedMob = nil
local AutoAttackEnabled = false
local AutoAttackThread = nil
local BringAllMobsEnabled = false
local BringAllMobsThread = nil
local BringAllMobsDistance = 100 -- Default distance
local BroughtMobs = {} -- Keep track of brought mobs to avoid duplicate processing
local AutoRebirthEnabled = false
local AutoRebirthThread = nil
local AutoRebirthDelay = 500 -- default seconds

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Root = Character:WaitForChild("HumanoidRootPart")
local MobsFolder = Workspace:WaitForChild("World Mobs"):WaitForChild("Mobs")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SkillRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SkillRemote")


local GamePasses = {
	"2x Luck",
	"Instant Transformation",
	"Orb Bag",
	"Orb Notifier",
	"Red Scouter",
	"Relic Finder",
	"Use Own Avatar",
	"x2 Orb Mastery"
}

local function UnlockGamePasses()
	local gpFolder = game:GetService("Players").LocalPlayer:WaitForChild("Stats"):WaitForChild("GamePasses")

	for _, passName in ipairs(GamePasses) do
		local gp = gpFolder:FindFirstChild(passName)
		if gp and gp:IsA("BoolValue") then
			gp.Value = true
		end
	end
end

local function AutoAttack()
	local cameraCFrame = workspace.CurrentCamera.CFrame

	local attackCFrame = CFrame.new(
		cameraCFrame.Position + cameraCFrame.LookVector * 10,
		cameraCFrame.Position
	)

	local argsStart = {
		{
			Camera = cameraCFrame,
			SkillId = "1",
			Began = true,
			CFrame = attackCFrame,
			["Typ\208\181"] = 1, -- Required by game (Cyrillic for "Type")
			Aim = Vector3.new()
		}
	}

	local argsEnd = {
		{
			Camera = cameraCFrame,
			SkillId = "1",
			Began = false,
			CFrame = attackCFrame,
			["Typ\208\181"] = 1,
			Aim = Vector3.new()
		}
	}

	game:GetService("ReplicatedStorage")
		:WaitForChild("Remotes")
		:WaitForChild("SkillRemote")
		:FireServer(unpack(argsStart))

	task.wait()

	game:GetService("ReplicatedStorage")
		:WaitForChild("Remotes")
		:WaitForChild("SkillRemote")
		:FireServer(unpack(argsEnd))
end

local function AutoRebirth()
	local rebirthRemote = game:GetService("ReplicatedStorage")
		:WaitForChild("Packages")
		:WaitForChild("_Index")
		:WaitForChild("sleitnick_knit@1.4.7")
		:WaitForChild("knit")
		:WaitForChild("Services")
		:WaitForChild("PlayerLevelService")
		:WaitForChild("RF")
		:WaitForChild("RequestRebirth")

	local args = { true }
	pcall(function()
		rebirthRemote:InvokeServer(unpack(args))
	end)
end

-- Extracts unique mob names for dropdown use
local function GetUniqueMobNames()
	local seen = {}
	local unique = {}

	for _, mob in ipairs(MobsFolder:GetChildren()) do
		if mob:IsA("Model") and not seen[mob.Name] then
			table.insert(unique, mob.Name)
			seen[mob.Name] = true
		end
	end

	table.sort(unique)
	return unique
end

-- NEW: Bring mob to player instead of teleporting to mob
local function BringMobToPlayer(mob)
	local mobRoot = mob:FindFirstChild("HumanoidRootPart")
	if mobRoot and Root then
		local frontPosition = Root.Position + (Root.CFrame.LookVector * 5) + Vector3.new(0, 1, 0)
		mobRoot.CFrame = CFrame.new(frontPosition, Root.Position)
		
		-- Disable mob's ability to move (optional)
		local mobHumanoid = mob:FindFirstChildOfClass("Humanoid")
		if mobHumanoid then
			mobHumanoid.PlatformStand = true
			mobHumanoid.WalkSpeed = 0
			mobHumanoid.JumpPower = 0
		end
			task.spawn(function()
		while mob and mob.Parent and mobHumanoid.Health > 0 do
			local frontPosition = Root.Position + (Root.CFrame.LookVector * 6)
			mobRoot.CFrame = CFrame.new(frontPosition, Root.Position)
			task.wait()
		end

		-- Optional: Re-enable mob behavior after loop ends
		if mobHumanoid then
			mobHumanoid.PlatformStand = false
			mobHumanoid.WalkSpeed = 16
			mobHumanoid.JumpPower = 50
		end
    end)
		return true
	end
	return false
end

local function BringAllMobsInRange(maxDistance)
    maxDistance = maxDistance or BringAllMobsDistance
    local playerPos = Root.Position
    local mobsBrought = 0
    
    -- Function to process mobs from a folder
    local function processMobFolder(folder, folderName)
        if not folder then return end
        
        for _, mob in ipairs(folder:GetChildren()) do
            if mob:IsA("Model") then
                local mobRoot = mob:FindFirstChild("HumanoidRootPart")
                local mobHumanoid = mob:FindFirstChildOfClass("Humanoid")
                
                if mobRoot and mobHumanoid and mobHumanoid.Health > 0 then
                    local distance = (mobRoot.Position - playerPos).Magnitude
                    
                    -- Only bring mobs within range that we haven't already brought
                    if distance <= maxDistance and not BroughtMobs[mob] then
                        if BringMobToPlayer(mob) then
                            BroughtMobs[mob] = true
                            mobsBrought = mobsBrought + 1
                        end
                    end
                end
            end
        end
    end
    
    -- Process regular mobs
    local mobsFolder = Workspace:FindFirstChild("World Mobs")
    if mobsFolder then
        local regularMobs = mobsFolder:FindFirstChild("Mobs")
        processMobFolder(regularMobs, "Regular Mobs")
        
        -- Process boss mobs
        local bossMobs = mobsFolder:FindFirstChild("Boss Mobs")
        processMobFolder(bossMobs, "Boss Mobs")
    end
    
    return mobsBrought
end

-- Auto bring all mobs loop
local function StartBringAllMobs()
    if BringAllMobsThread and coroutine.status(BringAllMobsThread) == "running" then
        return -- Already running
    end
    
    BringAllMobsThread = coroutine.create(function()
        
        while BringAllMobsEnabled and coroutine.running() == BringAllMobsThread do
            local mobsBrought = BringAllMobsInRange(BringAllMobsDistance)
            
            if mobsBrought > 0 then
                
            end
            
            task.wait(1) -- Check for new mobs every 2 seconds
        end
    end)
    
    coroutine.resume(BringAllMobsThread)
end

-- Stop bringing all mobs
local function StopBringAllMobs()
    BringAllMobsEnabled = false
    
    if BringAllMobsThread then
        coroutine.close(BringAllMobsThread)
        BringAllMobsThread = nil
    end
    
    -- Clear the tracking table
    BroughtMobs = {}
end

local function TeleportBehindMob(mob)
	local hrp = mob:FindFirstChild("HumanoidRootPart")
	if hrp and Root then
		local behind = hrp.Position - (hrp.CFrame.LookVector * 3) + Vector3.new(0, 2, 0)
		Root.CFrame = CFrame.new(behind, hrp.Position)
		return true
	end
	return false
end

local function LockOnMob(mob)
	task.spawn(function()
		while AutoFarm and mob and mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChildOfClass("Humanoid") and mob:FindFirstChildOfClass("Humanoid").Health > 0 do
			local mobHRP = mob:FindFirstChild("HumanoidRootPart")
			if mobHRP and Root then
				local currentPos = Root.Position
				Root.CFrame = CFrame.new(currentPos, mobHRP.Position)
			end
			task.wait()
		end
	end)
end

local function StopFarming()
	if FarmingThread then
		coroutine.close(FarmingThread)
		FarmingThread = nil
	end
end

local function StartFarming()
	if FarmingThread and coroutine.status(FarmingThread) == "running" then
		return -- already running
	end

	FarmingThread = coroutine.create(function()
		while AutoFarm and coroutine.running() == FarmingThread do
			if not SelectedMob then
				task.wait(1)
				continue
			end

			local mobs = MobsFolder:GetChildren()
			local target = nil

			for _, mob in ipairs(mobs) do
				if mob:IsA("Model") and mob.Name == SelectedMob then
					local humanoid = mob:FindFirstChildOfClass("Humanoid")
					local hrp = mob:FindFirstChild("HumanoidRootPart")

					if humanoid and humanoid.Health > 0 and hrp then
						target = mob
						break
					end
				end
			end

			if target then
				
				-- Choose between bringing mob or teleporting to it
				if _G.MobFarmAPI.UseBringMob then
					if BringMobToPlayer(target) then
					else
						TeleportBehindMob(target)
					end
				else
					TeleportBehindMob(target)
				end
				
				LockOnMob(target)

				-- Just wait while mob is alive (no attacking)
				while AutoFarm and target and target.Parent do
					local humanoid = target:FindFirstChildOfClass("Humanoid")
					if not humanoid or humanoid.Health <= 0 or not target.Parent then
						break
					end
					task.wait(1) -- Check every second
				end
			else
				task.wait(0.3)
			end
		end
	end)
	coroutine.resume(FarmingThread)
end

-- Expose utility functions for GUI
_G.MobFarmAPI = {
	GetMobList = GetUniqueMobNames,
	SetTargetMob = function(name)
		local mobName
		if type(name) == "table" then
			for _, value in pairs(name) do
				if type(value) == "string" then
					mobName = value
					break
				end
			end
			if not mobName then
				return
			end
		else
			mobName = tostring(name)
		end
		
		SelectedMob = mobName
		if AutoFarm then
			StopFarming()
			StartFarming()
		end
	end,
	Toggle = function(state)
		AutoFarm = state
		if state then
			StartFarming()
		else
			StopFarming()
		end
	end,
	UseBringMob = false,
	ToggleBringMode = function(state)
		_G.MobFarmAPI.UseBringMob = state
	end
}

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
	Name = "Dragon Blox",
	Icon = 0,
	LoadingTitle = "Rayfield Interface Suite",
	LoadingSubtitle = "Sponsored by Chat GPT",
	ShowText = "Rayfield",
	Theme = "Default",
	UIKeybind = "K",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = nil,
		FileName = "Dragon Blox"
	},
})

local Tab = Window:CreateTab("Auto Farm", 4483362458)
local Section = Tab:CreateSection("Auto Farm")

-- Create buttons for each mob for reliable selection
local mobOptions = _G.MobFarmAPI.GetMobList()

-- Also create a dropdown with proper Set() implementation
local dropdown = Tab:CreateDropdown({
	Name = "Mob List",
	Options = mobOptions,
	CurrentOption = "Select a mob",
	Callback = function(option)
		print("🔧 Dropdown callback received:", option, "Type:", type(option))
		if option and option ~= "Select a mob" then
			_G.MobFarmAPI.SetTargetMob(option)
			-- Handle the mob name for notification
			local displayName = type(option) == "table" and (option[1] or "Unknown") or tostring(option)
			Rayfield:Notify({
				Title = "Target Selected",
				Content = "Now targeting: " .. displayName,
				Duration = 2,
				Image = 4483362458,
			})
		end
	end,
})

--[[ 
for i, mobName in ipairs(mobOptions) do
	Tab:CreateButton({
		Name = "Select: " .. mobName,
		Callback = function()
			-- Use dropdown:Set() method instead of direct API call
			dropdown:Set(mobName)
			print("🎯 Set dropdown to:", mobName)
		end,
	})
end
]]--

local Button = Tab:CreateButton({
	Name = "Refresh Moblist",
	Callback = function()
		mobOptions = _G.MobFarmAPI.GetMobList()
		dropdown:Refresh(mobOptions)

		Rayfield:Notify({
			Title = "Status",
			Content = "Refreshed Moblist",
			Duration = 3,
			Image = 4483362458,
		})
	end,
})

local Toggle = Tab:CreateToggle({
	Name = "Farm Mob",
	CurrentValue = false,
	Flag = "AutoFarmMob",
	Callback = function(Value)
		_G.MobFarmAPI.Toggle(Value)

		Rayfield:Notify({
			Title = "Status",
			Content = "Auto Farm is " .. (Value and "ON" or "OFF"),
			Duration = 1.5,
			Image = 4483362458,
		})
	end,
})

local Toggle = Tab:CreateToggle({
	Name = "Bring Mobs to Me",
	CurrentValue = false,
	Flag = "BringMobMode",
	Callback = function(Value)
		_G.MobFarmAPI.ToggleBringMode(Value)

		Rayfield:Notify({
			Title = "Mode Changed",
			Content = Value and "Bringing mobs to player" or "Teleporting to mobs",
			Duration = 2,
			Image = 4483362458,
		})
	end,
})

Tab:CreateToggle({
	Name = "Auto Attack",
	CurrentValue = false,
	Flag = "AutoAttack",
	Callback = function(Value)
		AutoAttackEnabled = Value

		if Value then
			-- Start loop only if not already running
			if AutoAttackThread and coroutine.status(AutoAttackThread) == "running" then return end

			AutoAttackThread = coroutine.create(function()
				while AutoAttackEnabled do
					AutoAttack()
					task.wait() -- adjust delay as needed
				end
			end)

			coroutine.resume(AutoAttackThread)
		else
			-- Set flag to false and allow current thread to exit naturally
			AutoAttackThread = nil
		end
	end
})

local Tab = Window:CreateTab("MAGS", 4483362458) -- Title, Image

Tab:CreateSlider({
    Name = "Bring Distance (studs)",
    Range = {10, 1000},
    Increment = 10,
    CurrentValue = 100,
    Flag = "BringAllDistance",
    Callback = function(Value)
        BringAllMobsDistance = Value
    end,
})

Tab:CreateToggle({
    Name = "Bring All Mobs in Range",
    CurrentValue = false,
    Flag = "BringAllMobs",
    Callback = function(Value)
        BringAllMobsEnabled = Value
        
        if Value then
            StartBringAllMobs()
        else
            StopBringAllMobs()
        end
        
        Rayfield:Notify({
            Title = "Bring All Mobs",
            Content = "Bringing all mobs is " .. (Value and "ON" or "OFF"),
            Duration = 2,
            Image = 4483362458,
        })
    end,
})

Tab:CreateButton({
    Name = "Bring All Mobs (Once)",
    Callback = function()
        local mobsBrought = BringAllMobsInRange(BringAllMobsDistance)
        
        Rayfield:Notify({
            Title = "Mobs Brought",
            Content = "Brought " .. mobsBrought .. " mobs within " .. BringAllMobsDistance .. " studs",
            Duration = 3,
            Image = 4483362458,
        })
    end,
})

-- Button to clear brought mobs tracking (useful for reset)
Tab:CreateButton({
    Name = "Reset Mob Tracking",
    Callback = function()
        BroughtMobs = {}
        
        Rayfield:Notify({
            Title = "Reset Complete",
            Content = "Cleared mob tracking - will re-bring all mobs in range",
            Duration = 2,
            Image = 4483362458,
        })
    end,
})

local Tab = Window:CreateTab("Misc", 4483362458) -- Title, Image


local Button = Tab:CreateButton({
	Name = "Unlock GamePasses",
	Callback = function()
		UnlockGamePasses()
		local unlockedList = table.concat(GamePasses, ", ")

		Rayfield:Notify({
			Title = "Status",
			Content = "Unlocked GamePasses: " .. unlockedList,
			Duration = 4,
			Image = 4483362458,
		})
	end,
})

local SliderRef
local InputRef

SliderRef = Tab:CreateSlider({
	Name = "Auto Rebirth Delay",
	Range = {1, 1000},
	Increment = 1,
	Suffix = "sec",
	CurrentValue = AutoRebirthDelay,
	Flag = "RebirthDelaySlider",
	Callback = function(Value)
		AutoRebirthDelay = Value
		if InputRef then
			InputRef:Set(tostring(Value)) -- Update input box
		end
	end,
})

InputRef = Tab:CreateInput({
	Name = "Set Delay (Manual)",
	CurrentValue = tostring(AutoRebirthDelay),
	PlaceholderText = "Enter delay in seconds",
	RemoveTextAfterFocusLost = true,
	Flag = "RebirthDelayInput",
	Callback = function(Text)
		local num = tonumber(Text)
		if num and num >= 1 and num <= 1000 then
			AutoRebirthDelay = num
			if SliderRef then
				SliderRef:Set(num) -- Update slider
			end
		else
			warn("⚠️ Invalid delay entered. Must be a number 1–1000.")
		end
	end,
})

-- Auto Rebirth Toggle
Tab:CreateToggle({
	Name = "Auto Rebirth",
	CurrentValue = false,
	Flag = "AutoRebirthToggle",
	Callback = function(Value)
		AutoRebirthEnabled = Value

		if Value then
			if AutoRebirthThread and coroutine.status(AutoRebirthThread) == "running" then return end

			AutoRebirthThread = coroutine.create(function()
				while AutoRebirthEnabled do
					AutoRebirth()
					task.wait(AutoRebirthDelay)
				end
			end)

			coroutine.resume(AutoRebirthThread)
		else
			AutoRebirthThread = nil
		end
	end
})
