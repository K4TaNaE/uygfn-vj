if not game:IsLoaded() then
	game.Loaded:Wait()
end

--[[ sUNC ]]--
-- vegax, codex, delta x, xeno, velocity, volcano, yub-x, xenith, bunni, potassium  --- test on this provided sunc below
local cloneref =  cloneref -- potassium, seliware, volcano, delta, bunni, cryptic
local getupvalue = debug.getupvalue -- potassium, seliware, volcano, delta, bunni, cryptix

--[[ Services ]]--
local LocalPlayer = game:GetService("Players").LocalPlayer
local RunService = game:GetService("RunService")
local CoreGui = cloneref(game:GetService("CoreGui"))
local HttpService = game:GetService("HttpService")
local NetworkClient = game:GetService("NetworkClient")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local Stats = game:GetService("Stats")

--[[ Adopt stuff ]]--
local loader = require(ReplicatedStorage.Fsys).load
local UIManager = loader("UIManager")
local ClientData = loader("ClientData")
local InventoryDB = loader("InventoryDB")
local PetEntityManager = loader("PetEntityManager")
local InteriorsM = loader("InteriorsM")
local HouseClient = loader("HouseClient")
local PetActions = loader("PetActions")
local StateManagerClient = loader("StateManagerClient")
local LureBaitHelper = loader("LureBaitHelper")
local API = ReplicatedStorage.API

local StateDB = {
	active_ailments = {},
	baby_active_ailments = {}
}
local actual_pet = {
	unique = nil,
	remote = nil,
	model = nil,
	wrapper = nil,
	rarity = nil
}
local total_fullgrowned = {}
local farmed = {
	money = 0,
	pets_fullgrown = 0,
	ailments = 0,
	potions = 0,
	friendship_levels = 0,
	event_currency = 0,
	baby_ailments = 0,
	eggs_hatched = 0
}
_G.bait_placed = false

local furn = {}
_G.InternalConfig = {}

local markup = {
	["INFO"] = "80, 200, 255",
	["ERROR"] = "255, 70, 70",
	["SUCCESS"] = "80, 255, 120",
	["WARNING"] = "255, 200, 0"
}

local xp_thresholds = {
    common = {
        newborn = 0,
        junior = 200,
        pre_teen = 500,
        teen = 900,
        post_teen = 1500,
        fullgrown = 2500
    },
    uncommon = {
        newborn = 0,
        junior = 300,
        pre_teen = 800,
        teen = 1500,
        post_teen = 2700,
        fullgrown = 3600
    },
    rare = {
        newborn = 0,
        junior = 500,
        pre_teen = 1200,
        teen = 2100,
        post_teen = 3400,
        fullgrown = 5400
    },
    ultra_rare = {
        newborn = 0,
        junior = 700,
        pre_teen = 1700,
        teen = 3400,
        post_teen = 8000,
        fullgrown = 10700
    },
    legendary = {
        newborn = 0,
        junior = 1000,
        pre_teen = 2700,
        teen = 5600,
        post_teen = 10400,
        fullgrown = 18300
    }
}


--[[ Lua Stuff ]]
local Queue = {} 
Queue.new = function() 
	return {
		__head = 1,
		__tail = 0,
		_data = {} ,
		running = false,
		blocked = false,

		enqueue = function(self, task: table) -- task must be {taskname, callback}.
			if type(task) == "table" and type(task[1]) == "string" and type(task[2]) == "function" and self.blocked == false then
				self.__tail += 1
				table.insert(self._data, self.__tail, task)

				if not self.running then self:__run() end
			end
		end,

		dequeue = function(self,raw)
			if self.__head > self.__tail then
				return
			end

			local value = self._data[self.__head]
			if raw and self.blocked then 
				self:enqunblock()
				table.remove(self._data, self.__head)
				self:enqblock()
			else 
				table.remove(self._data, self.__head)
			end
			
			self.__tail -= 1
			return value
		end,

		enqblock = function(self) -- blocks adding new values to queue
			setmetatable(self._data, { __newindex = function(...) return end })
			self.blocked = true
		end,

		enqunblock = function(self) -- unblocks adding new values to queue
			setmetatable(self._data, nil)
			self.blocked = false
		end,

		destroy_linked = function(self, taskname) 
			if not self:empty() then
				for k,v in self._data do
					if v[1]:match(taskname) then
						table.remove(self._data, k)
						self.__tail -= 1
					end
				end
			end
		end,

		taskdestroy = function(self, pattern1, pattern2) 
			if not self:empty() then 
				for k,v in self._data do
					if v[1]:match(pattern1) and v[1]:match(pattern2) then
						table.remove(self._data, k)
						self.__tail -= 1
					end
				end
			end
		end,

		empty = function(self)
			return self.__head > self.__tail
		end,

		__asyncrun = function(taskt: table)
			local name = taskt[1]			
			local callback = taskt[2]			
			if name and type(name) == "string" and callback and type(callback) == "function" then 
				pcall(task.spawn, callback)
			end
		end,

		__run = function(self)
			self.running = true

			while not self:empty() do
				local dtask = self._data[self.__head]

				local name = dtask[1]
				local callback = dtask[2]
				print("running task: ", name)
				local ok, err = xpcall(callback, debug.traceback)
				self:dequeue(true)
				print("ended task", name)
				if not ok then
					print("Task failed:", err)
					local spl = name:split(": ")
					if spl[1]:match("ailment pet") then
						StateDB.active_ailments[spl[2]] = nil
					elseif spl[1]:match("ailment baby") then
						StateDB.active_ailments_baby[spl[2]] = nil
					end
				end

				task.wait(.5) 
			end
			self.running = false
		end
	}
end
local queue = Queue.new()

--[[ Helpers ]]-- -- not optimized
;(function() 
	local function enableRichTextInDescendants(parent)
		for _, v in ipairs(parent:GetDescendants()) do
			if v:IsA("TextLabel") then
				v.RichText = true
			end
		end
	end

	local function hookMainView(mainView)
		enableRichTextInDescendants(mainView)
		mainView.DescendantAdded:Connect(function(desc)
			if desc:IsA("TextLabel") then
				desc.RichText = true
			end
		end)
	end

	local function hookDevConsole(console)
		local mainView = console:FindFirstChild("MainView", true)
		if mainView then
			hookMainView(mainView)
		end
		console.DescendantAdded:Connect(function(desc)
			if desc.Name == "MainView" then
				hookMainView(desc)
			end
		end)
	end
	local console = CoreGui:FindFirstChild("DevConsoleMaster")
	if console then
		hookDevConsole(console)
	end
	CoreGui.ChildAdded:Connect(function(child)
		if child.Name == "DevConsoleMaster" then
			hookDevConsole(child)
		end
	end)
end)()

local function colorprint(color:table, text:string) -- works
	local Text = '<font color="rgb(' .. table.unpack(color) .. ')"'
	Text = Text .. '>' .. tostring(text) .. '</font>'
	print(Text)
end

local function temp_platform() -- optimized
	local part:Part = Instance.new("Part")
	part.Size = Vector3.new(50, 1, 50)
	part.Position = LocalPlayer.Character.HumanoidRootPart.Position - Vector3.new(0,5,0) 
	part.Name = "TempPart"
	part.Anchored = true
	part.Parent = game.Workspace
end

local function get_current_location() -- optimized
	return InteriorsM.get_current_location()["destination_id"]
end 

local function to_neighborhood() -- optimized
	local loc = get_current_location()
		if loc=="Neighborhood" 
		or loc=="Neighborhood!Default" 
		or loc=="Neighborhood!Desert" 
		or loc=="Neighborhood!Snow" 
		or loc=="Neighborhood!Fall" 
		or loc=="Neighborhood!Rain" 
		or loc=="Neighborhood!Christmas" then return end
	temp_platform()
	InteriorsM.enter("Neighborhood", "MainDoor")
	while not get_current_location() == "Neighborhood" do
		task.wait(.1)
	end
	game.Workspace:FindFirstChild("TempPart"):Destroy()
	task.wait(.5)
end

local function to_home() -- optimized
	if get_current_location() == "housing" then
		return
	end
	temp_platform()
	InteriorsM.enter("housing", "MainDoor", { house_owner=LocalPlayer })
	while not get_current_location() == "housing" do
		task.wait(.1)
	end
	game.Workspace:FindFirstChild("TempPart"):Destroy()
	task.wait(.5)
end

local function to_mainmap() -- optimized
	local loc = get_current_location()
		if loc == "MainMap"
		or loc == "MainMap!Default"
		or loc == "MainMap!Desert"
		or loc == "MainMap!Snow"
		or loc == "MainMap!Fall"
		or loc == "MainMap!Rain"
		or loc == "MainMap!Christmas" then return end 
	temp_platform()
	InteriorsM.enter("MainMap", "Neighborhood/MainDoor")
	if not get_current_location() == "MainMap" then
		task.wait(.1)
	end
	game.Workspace:FindFirstChild("TempPart"):Destroy()
	task.wait(.5)
end

local function goto(destId, door, ops:table) -- optimized
	if get_current_location() == destId then return end
	temp_platform()
	InteriorsM.enter(destId, door, ops or {})
	while not get_current_location() == destId do
		task.wait(.1)
	end
	game.Workspace:FindFirstChild("TempPart"):Destroy()
	task.wait(.5)
end

local function get_equiped_pet() -- not optimzed
	local model, age, friendship, xp
	local data = {}
	local wrapper = ClientData.get("pet_char_wrappers")[1]
	if not wrapper then return nil end
	local remote = wrapper["pet_id"] 
	local unique = wrapper["pet_unique"]
	local cdata = ClientData.get("inventory").pets[unique]
	if cdata then
		age = cdata.properties.age
		friendship = cdata.properties.friendship_level
		xp = cdata.properties.xp
	end
	for _,v in ipairs(game.Workspace.Pets:GetChildren() or {}) do
		local entity = PetEntityManager.get_pet_entity(v)
		if entity and entity.session_memory then 
			local session = entity.session_memory
			if session.meta.owned_by_local_player then
				model = v
			end				
		end
	end
	local rarity = InventoryDB.pets[remote].rarity
	local name = InventoryDB.pets[remote].name
	data.remote = remote; data.unique = unique; data.model = model or {}; data.wrapper = wrapper; 
	data.age = age; data.rarity = rarity; data.friendship = friendship; data.xp = xp; data.name = name;
 	return data
end

local function cur_unique() 
	local path = ClientData.get("pet_char_wrappers")[1]
	if path then
		return path.pet_unique
	end
end

local function equiped() 
	return ClientData.get("pet_char_wrappers")[1]
end

local function get_owned_pets() -- optimized
	local data = {}
	for _,v in ClientData.get("inventory").pets do
		if v.id == "practice_dog" then continue end
		local remote = v.id
		local unique = v.unique
		local age = v.properties.age
		local friendship = v.properties.friendship_level
		local xp = v.properties.xp
		local cost = InventoryDB.pets[remote].cost
		local name = InventoryDB.pets[remote].name
		local rarity = InventoryDB.pets[remote].rarity
		data[v.unique] = {
			remote=remote,unique=unique,age=age,friendship=friendship,xp=xp,
			cost=cost,name=name,rarity=rarity, table=v
		}
	end
	return data
end

local function get_owned_category(category) -- optimized
	local returned = {}; local remote, unique
	for _,v in ClientData.get("inventory")[category] do
		remote = v.id
		unique = v.unique
		returned[unique] = {
			remote=remote,unique=unique
		}
	end
	return returned
end

local function get_equiped_pet_ailments() -- optimized
	local ailments = {}
	local pet = ClientData.get("pet_char_wrappers")[1]
	if pet then
		local path = ClientData.get("ailments_manager")["ailments"][pet.pet_unique]
		if not path then return nil end
		for k,_ in ClientData.get("ailments_manager")["ailments"][pet.pet_unique] do
			ailments[k] = true
		end
	end
	return ailments
end

local function has_ailment(ailment) 
    local ail = ClientData.get("ailments_manager")["ailments"][actual_pet.unique]
    return ail and ail[ailment] ~= nil
end

local function has_ailment_baby(ailment) 
	local ail = ClientData.get("ailments_manager")["baby_ailments"]
	return ail and ail[ailment] ~= nil
end	

local function get_baby_ailments() -- optimized
	local ailments = {}
	for k, _ in ClientData.get("ailments_manager")["baby_ailments"] do
		ailments[k] = true
	end 
	return ailments 
end


local function inv_get_category_remote(category, unique) -- optimized
	for k, v in ClientData.get("inventory")[category] do
		if k==unique then return v.id end
	end
end
 
local function inv_get_category_unique(category, remote) -- optimzied
	for k, v in ClientData.get("inventory")[category] do
		if v.id==remote then return k end
	end
end

local function inv_get_pets_with_rarity(rarity) -- optimized
	local list = {}	
	for _,v in get_owned_pets() do 
		if v.rarity == rarity then 
			list[v.unique] = {remote=v.remote, unique=v.unique}
		end
	end
	return list 
end

local function inv_get_pets_with_age(age) -- optimized
	local list = {}	
	for _,v in get_owned_pets() do 
		if v.age == age then 
			list[v.unique] = {remote=v.remote, unique=v.unique}
		end
	end
	return list 
end

local function check_pet_owned(remote) -- optimized
	for _, v in get_owned_category("pets") do
        if v.remote == remote then 
            return true
        end
	end
	return false
end

local function send_trade_request(user)  -- optimized
	API["TradeAPI/SendTradeRequest"]:FireServer(game.Players[user])
	local timer = 120
	while not UIManager.is_visible("TradeApp") and timer > 0 do
		task.wait(1)
		timer -=1 
	end
	if not UIManager.is_visible("TradeApp") then
		return "No response"
	end
	return true  
end 

local function count_of_product(category, remote) -- works
	local count = 0
	for _,v in ClientData.get("inventory")[category] do
		if v.id == remote then
			count+=1
		end
	end
	return count
end

local function check_remote_existance(category, remote) -- optimized
	if InventoryDB[category][remote] then
		return true
	end
	return false
end

local function count(t)
	local n = 0
	for _ in pairs(t) do
		n +=1 
	end
	return n
end

-- unit: b, kb, mb, gb
local function get_memory(unit: string) 
	local unit = unit:lower()
	if unit == "b" then
		return (Stats:GetTotalMemoryUsageMb() * 1024) * 1024
	elseif unit == "kb" then
		return Stats:GetTotalMemoryUsageMb() * 1024
	elseif unit == "mb" then
		return Stats:GetTotalMemoryUsageMb()
	elseif unit == "gb" then
		return Stats:GetTotalMemoryUsageMb() / 1024
	end
end

local function gotovec(x:number, y:number, z:number) -- optimized
	local pet = actual_pet
	if pet.unique then
		PetActions.pick_up(pet.wrapper)
		task.wait(.5)
		LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(x,y,z)
		task.wait(.2)
		API["AdoptAPI/EjectBaby"]:FireServer(pet.model)
	else
		LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(x,y,z)
	end
end

local function webhook(title, description) -- optimized
	local url = _G.InternalConfig.DiscordWebhookURL
	if url then
		local payload = {
		embeds = {
			{
				title = title,
				description = description,
				color = 000000,
				author = {
					name = "Arcanic",
					url = "https://discord.gg/E8BVmZWnHs",
					icon_url = "https://i.imageupload.app/936d8d1617445f2a3fbd.png"
				},
				footer = {
					text = `{os.date("%d.%m.%Y")} {os.date("%H:%M:%S")}`
				}
			}
		},
		username = "Arcanic Farmhook",
		attachments = {}
	}

	request({
		Url = url,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json"
		},
		Body = HttpService:JSONEncode(payload)
	})
	end
end

local function update_gui(label, val: number) -- optimized
    local overlay = CoreGui:FindFirstChild("StatsOverlay")
    if not overlay then return end

    local frame = overlay:FindFirstChild("StatsFrame")
    if not frame then return end

    local lbl = frame:FindFirstChild(label)
    if not lbl then return end

    local prefix = lbl.Text:match("^[^:]+")
    if prefix then
        lbl.Text = prefix .. ": " .. val
    end
end

local function enstat(friendship, money, ailment)  -- optimized
	task.wait(.5)
	if actual_pet.is_egg then
		if actual_pet.unique ~= cur_unique() then
			farmed.eggs_hatched += 1 
			actual_pet.unique = nil 
			queue:destroy_linked("ailment pet")
			table.clear(StateDB.active_ailments)
			farmed.money += ClientData.get("money") - money
			farmed.ailments += 1
			update_gui("eggs", farmed.eggs_hatched)
			update_gui("bucks", farmed.money)
			update_gui("pet_needs", farmed.ailments)
			return
		else
			farmed.money += ClientData.get("money") - money
			farmed.ailments += 1
			update_gui("bucks", farmed.money)
			update_gui("pet_needs", farmed.ailments)
			StateDB.active_ailments[ailment] = nil
			return
		end
	end

	if _G.InternalConfig.AutoFarmFilter.PotionFarm then
		if friendship < ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level then
			farmed.friendship_levels += 1
			farmed.potions += 1
			table.clear(StateDB.active_ailments)
			update_gui("friendship", farmed.friendship_levels)
			update_gui("potions", farmed.potions)
		else
			StateDB.active_ailments[ailment] = nil
		end
	else 
		if ClientData.get("pet_char_wrappers")[1].pet_progression.age == 6 then
			farmed.pets_fullgrown += 1
			table.insert(total_fullgrowned, actual_pet.unique)
			update_gui("fullgrown", farmed.pets_fullgrown)
			actual_pet.unique = nil
			table.clear(StateDB.active_ailments)
			queue:destroy_linked("ailment pet")
		else
			StateDB.active_ailments[ailment] = nil
		end
	end
	farmed.money += ClientData.get("money") - money
	farmed.ailments += 1
	update_gui("bucks", farmed.money)
	update_gui("pet_needs", farmed.ailments)
end

local function enstat_baby(money, ailment) -- optimized
	task.wait(.5)
	farmed.money += ClientData.get("money") - money 
	farmed.baby_ailments += 1
	StateDB.baby_active_ailments[ailment] = nil
	update_gui("bucks", farmed.money)
	update_gui("baby_needs", farmed.baby_ailments)
end

local function __pet_callback(friendship, ailment) 
	task.wait(.5)
	if not _G.InternalConfig.FarmPriority then
		farmed.ailments += 1
		update_gui("pet_needs", farmed.ailments) 
	else
		if _G.InternalConfig.FarmPriority == "eggs" then
			if _G.InternalConfig.AutoFarmFilter.PotionFarm then
				farmed.eggs_hatched += 1 
				farmed.ailments += 1
				update_gui("eggs", farmed.eggs_hatched)
				update_gui("pet_needs", farmed.ailments)
				local pet = get_equiped_pet()
				actual_pet.model = pet.model; actual_pet.rarity = pet.rarity; actual_pet.remote = pet.remote; actual_pet.unique = pet.unique; actual_pet.wrapper = pet.wrapper
				queue:destroy_linked("ailment pet")
				table.clear(StateDB.active_ailments)
				return
			end
			if actual_pet.unique ~= cur_unique() then
				farmed.eggs_hatched += 1 
				actual_pet.unique = nil 
				queue:destroy_linked("ailment pet")
				table.clear(StateDB.active_ailments)
				farmed.ailments += 1
				update_gui("eggs", farmed.eggs_hatched)
				update_gui("bucks", farmed.money)
				return
			else
				farmed.ailments += 1
				update_gui("bucks", farmed.money)
				StateDB.active_ailments[ailment] = nil
				return
			end
		end

		if _G.InternalConfig.AutoFarmFilter.PotionFarm then
			if friendship < ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level then
				farmed.friendship_levels += 1
				farmed.potions += 1
				table.clear(StateDB.active_ailments)
				update_gui("friendship", farmed.friendship_levels)
				update_gui("potions", farmed.potions)
			else
				StateDB.active_ailments[ailment] = nil
			end
		else 
			if actual_pet.rarity == 6 then
				farmed.pets_fullgrown += 1
				table.insert(total_fullgrowned, actual_pet.unique)
				update_gui("fullgrown", farmed.pets_fullgrown)
				actual_pet.unique = nil
				table.clear(StateDB.active_ailments)
				queue:destroy_linked("ailment pet")
			else
				StateDB.active_ailments[ailment] = nil
			end
		end
		farmed.ailments += 1
		update_gui("pet_needs", farmed.ailments)
	end
end

local function __baby_callbak(ailment, money) 
	task.wait(.5)
	if not _G.InternalConfig.BabyAutoFarm then
		farmed.baby_ailments += 1 
		update_gui("baby_needs", farmed.baby_ailments)
	else
		queue:taskdestroy("baby", ailment)
		farmed.baby_ailments += 1
		StateDB.baby_active_ailments[ailment] = nil
		update_gui("baby_needs", farmed.baby_ailments)
	end
end

local pet_ailments = { 
	["camping"] = function()
		local pet = ClientData.get("pet_char_wrappers")[1]
		if not pet or not actual_pet.unique or pet.pet_unique ~= actual_pet.unique or not has_ailment("camping") then
			queue:destroy_linked("ailment pet")
			actual_pet.unique = nil
			table.clear(StateDB.active_ailments)
			return 
		end		
		local cdata = ClientData.get("inventory").pets[actual_pet.unique]
		local friendship = cdata.properties.friendship_level
		local money = ClientData.get("money")
		local baby_has_ailment = has_ailment_baby("camping")
		to_mainmap()
		gotovec(-23, 37, -1063)
        local deadline = os.clock() + 60
        repeat 
            task.wait(1)
        until not has_ailment("camping") or os.clock() > deadline
        if os.clock() > deadline then 
			StateDB.active_ailments.camping = nil
			error("Out of limits") 
		end        
		enstat(friendship, money, "camping")
		task.wait(.8)
		if baby_has_ailment and ClientData.get("team") == "Babies" and not has_ailment_baby("camping") then
			__baby_callbak(money, "camping")
		end
	end,
	["hungry"] = function() -- healing_apple в прошлый раз не работало
		local pet = ClientData.get("pet_char_wrappers")[1]
		if not pet or not actual_pet.unique or pet.pet_unique ~= actual_pet.unique or not has_ailment("hungry") then
			queue:destroy_linked("ailment pet")
			actual_pet.unique = nil
			table.clear(StateDB.active_ailments)
			return 
		end
		local cdata = ClientData.get("inventory").pets[actual_pet.unique]
		local friendship = cdata.properties.friendship_level
		local money = ClientData.get("money")
		if count_of_product("food", "apple") == 0 then
			if money == 0 then 
				colorprint({markup.ERROR}, "[-] No money to buy food") 
				StateDB.active_ailments.hungry = nil 
				return
			end
			if money > 20 then
				API["ShopAPI/BuyItem"]:InvokeServer(
					"food",
					"apple",
					{
						buy_count = 20
					}
				)
			else 
				API["ShopAPI/BuyItem"]:InvokeServer(
					"food",
					"apple",
					{
						buy_count = money / 2
					}
				)
			end
		end
		local deadline = os.clock() + 10
		API["PetObjectAPI/CreatePetObject"]:InvokeServer(
			"__Enum_PetObjectCreatorType_2",
			{
				additional_consume_uniques={},
				pet_unique = pet.pet_unique,
				unique_id = inv_get_category_unique("food", "apple")
			}
		)
		repeat 
			task.wait(1)
        until not has_ailment("hungry") or os.clock() > deadline
        if os.clock() > deadline then 
			StateDB.active_ailments.hungry = nil
			error("Out of limits") 
		end        
		enstat(friendship, money, "hungry")  
	end,
	["thirsty"] = function() 
		local pet = ClientData.get("pet_char_wrappers")[1]
		if not pet or not actual_pet.unique or pet.pet_unique ~= actual_pet.unique or not has_ailment("thirsty") then
			queue:destroy_linked("ailment pet")
			actual_pet.unique = nil
			table.clear(StateDB.active_ailments)
			return 
		end
		local cdata = ClientData.get("inventory").pets[actual_pet.unique]
		local friendship = cdata.properties.friendship_level
		local money = ClientData.get("money")
		if count_of_product("food", "water") == 0 then
			if money == 0 then 
				colorprint({markup.ERROR}, "[-] No money to buy food") 
				StateDB.active_ailments.thirsty = nil 
				return
			end
			if money > 20 then
				API["ShopAPI/BuyItem"]:InvokeServer(
					"food",
					"water",
					{
						buy_count = 20
					}
				)
			else 
				API["ShopAPI/BuyItem"]:InvokeServer(
					"food",
					"water",
					{
						buy_count = money / 2
					}
				)
			end
		end
		local deadline = os.clock() + 10
		API["PetObjectAPI/CreatePetObject"]:InvokeServer(
			"__Enum_PetObjectCreatorType_2",
			{
				additional_consume_uniques={},
				pet_unique = pet.pet_unique,
				unique_id = inv_get_category_unique("food", "water")
			}
		)
		repeat 
            task.wait(1)
        until not has_ailment("thirsty") or os.clock() > deadline
        if os.clock() > deadline then 
			StateDB.active_ailments.thirsty = nil
			error("Out of limits") 
		end            	
		enstat(friendship, money, "thirsty")  
	end,
	["sick"] = function() 
		local pet = ClientData.get("pet_char_wrappers")[1]
		if not pet or not actual_pet.unique or pet.pet_unique ~= actual_pet.unique or not has_ailment("sick") then
			queue:destroy_linked("ailment pet")
			actual_pet.unique = nil
			table.clear(StateDB.active_ailments)
			return 
		end
		local cdata = ClientData.get("inventory").pets[actual_pet.unique]
		local friendship = cdata.properties.friendship_level
		local money = ClientData.get("money")
		local baby_has_ailment = has_ailment_baby("sick")
		goto("Hospital", "MainDoor")
		repeat 
			API["HousingAPI/ActivateInteriorFurniture"]:InvokeServer(
				"f-14",
				"UseBlock",
				"Yes",
				LocalPlayer.Character
			)
			task.wait(1)
		until not has_ailment("sick")
		enstat(friendship, money, "sick") 
		task.wait(.8)
		if baby_has_ailment and ClientData.get("team") == "Babies" and not has_ailment("sick") then
			__baby_callbak(money, "sick")
		end
	end,
	["bored"] = function() 
		local pet = ClientData.get("pet_char_wrappers")[1]
		if not pet or not actual_pet.unique or pet.pet_unique ~= actual_pet.unique or not has_ailment("bored") then
			queue:destroy_linked("ailment pet")
			actual_pet.unique = nil
			table.clear(StateDB.active_ailments)
			return 
		end
		local cdata = ClientData.get("inventory").pets[actual_pet.unique]
		local friendship = cdata.properties.friendship_level
		local money = ClientData.get("money")
		local baby_has_ailment = has_ailment_baby("bored")
		to_mainmap()
		gotovec(-365, 30, -1749)
        local deadline = os.clock() + 60
        repeat 
            task.wait(1)
        until not has_ailment("bored") or os.clock() > deadline
        if os.clock() > deadline then 
			StateDB.active_ailments.bored = nil
			error("Out of limits") 
		end        
		enstat(friendship, money, "bored")  
		task.wait(.8)
		if baby_has_ailment and ClientData.get("team") == "Babies" and not has_ailment_baby("bored") then
			__baby_callbak(money, "bored")
		end
	end,
	["salon"] = function() 
		local pet = ClientData.get("pet_char_wrappers")[1]
		if not pet or not actual_pet.unique or pet.pet_unique ~= actual_pet.unique or not has_ailment("salon") then
			queue:destroy_linked("ailment pet")
			actual_pet.unique = nil
			table.clear(StateDB.active_ailments)
			return 
		end
		local cdata = ClientData.get("inventory").pets[actual_pet.unique]
		local friendship = cdata.properties.friendship_level
		local money = ClientData.get("money")
		local baby_has_ailment = has_ailment_baby("salon")
		goto("Salon", "MainDoor")
        local deadline = os.clock() + 60
        repeat 
            task.wait(1)
        until not has_ailment("salon") or os.clock() > deadline
        if os.clock() > deadline then 
			StateDB.active_ailments.salon = nil
			error("Out of limits") 
		end        
		enstat(friendship, money, "salon")  
		task.wait(.8)
		if baby_has_ailment and ClientData.get("team") == "Babies" and not has_ailment_baby("salon") then
			__baby_callbak(money, "salon")	
		end
	end,
	["play"] = function() -- improve. add something without task.wait
		local pet = ClientData.get("pet_char_wrappers")[1]
		if not pet or not actual_pet.unique or pet.pet_unique ~= actual_pet.unique or not has_ailment("play") then
			queue:destroy_linked("ailment pet")
			actual_pet.unique = nil
			table.clear(StateDB.active_ailments)
			return 
		end
		local cdata = ClientData.get("inventory").pets[actual_pet.unique]
		local friendship = cdata.properties.friendship_level
		local money = ClientData.get("money")
		gotovec(1000,25,1000)
		task.wait(.3)
		API["ToolAPI/Equip"]:InvokeServer(inv_get_category_unique("toys", "squeaky_bone_default"), {})
		local deadline = os.clock() + 25
		repeat 
			API["PetObjectAPI/CreatePetObject"]:InvokeServer(
				"__Enum_PetObjectCreatorType_1",
				{
					reaction_name = "ThrowToyReaction",
					unique_id = inv_get_category_unique("toys", "squeaky_bone_default")
				}
			)
			task.wait(5) 
		until not has_ailment("play") or os.clock() > deadline
		task.wait(.3)
		API["ToolAPI/Unequip"]:InvokeServer(inv_get_category_unique("toys", "squeaky_bone_default"), {})
        if os.clock() > deadline then 
			StateDB.active_ailments.play = nil
			error("Out of limits") 
		end        
		enstat(friendship, money, "play") 
	end,
	["toilet"] = function() 
		local pet = ClientData.get("pet_char_wrappers")[1]
		if not pet or not actual_pet.unique or pet.pet_unique ~= actual_pet.unique or not has_ailment("toilet") then
			queue:destroy_linked("ailment pet")
			actual_pet.unique = nil
			table.clear(StateDB.active_ailments)
			return 
		end
		local cdata = ClientData.get("inventory").pets[actual_pet.unique]
		local friendship = cdata.properties.friendship_level
		local money = ClientData.get("money")
		to_home()
		API['HousingAPI/ActivateFurniture']:InvokeServer(
			LocalPlayer,
			furn.toilet.unique,
			furn.toilet.usepart,
			{
				cframe = furn.toilet.cframe
			},
			actual_pet.model
		)
        local deadline = os.clock() + 15
        repeat 
            task.wait(1)
        until not has_ailment("toilet") or os.clock() > deadline
        if os.clock() > deadline then 
			StateDB.active_ailments.toilet = nil
			error("Out of limits") 
		end        
		enstat(friendship, money, "toilet")  
	end,
	["beach_party"] = function() 
		local pet = ClientData.get("pet_char_wrappers")[1]
		if not pet or not actual_pet.unique or pet.pet_unique ~= actual_pet.unique or not has_ailment("beach_party") then
			queue:destroy_linked("ailment pet")
			actual_pet.unique = nil
			table.clear(StateDB.active_ailments)
			return 
		end
		local cdata = ClientData.get("inventory").pets[actual_pet.unique]
		local friendship = cdata.properties.friendship_level
		local money = ClientData.get("money")
		local baby_has_ailment = has_ailment_baby("beach_party")
		to_mainmap()
		gotovec(-596, 27, -1473)
        local deadline = os.clock() + 60
        repeat 
            task.wait(1)
        until not has_ailment("beach_party") or os.clock() > deadline
        if os.clock() > deadline then 
			StateDB.active_ailments.beach_party = nil
			error("Out of limits") 
		end        
		enstat(friendship, money, "beach_party")  
		task.wait(.8)
		if baby_has_ailment and ClientData.get("team") == "Babies" and not has_ailment_baby("beach_party") then
			__baby_callbak(money, "beach_party")
		end
	end,
	["ride"] = function()
		local pet = ClientData.get("pet_char_wrappers")[1]
		if not pet or not actual_pet.unique or pet.pet_unique ~= actual_pet.unique or not has_ailment("ride") then
			queue:destroy_linked("ailment pet")
			actual_pet.unique = nil
			table.clear(StateDB.active_ailments)
			return 
		end
		local cdata = ClientData.get("inventory").pets[actual_pet.unique]
		local friendship = cdata.properties.friendship_level
		local money = ClientData.get("money")
		local deadline = os.clock() + 60
		gotovec(1000,25,1000)
		API["ToolAPI/Equip"]:InvokeServer(inv_get_category_unique("strollers", "stroller-default"), {})
		repeat 
			LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position + LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector * 50)
			LocalPlayer.Character.Humanoid.MoveToFinished:Wait()
			LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector * 50)
			LocalPlayer.Character.Humanoid.MoveToFinished:Wait()			
		until not has_ailment("ride") or os.clock() > deadline
		API["ToolAPI/Unequip"]:InvokeServer(inv_get_category_unique("strollers", "stroller-default"), {})
		if os.clock() > deadline then 
			StateDB.active_ailments.ride = nil
			error("Out of limits") 
		end        
		enstat(friendship, money, "ride") 
	end,
	["dirty"] = function() 
		local pet = ClientData.get("pet_char_wrappers")[1]
		if not pet or not actual_pet.unique or pet.pet_unique ~= actual_pet.unique or not has_ailment("dirty") then
			queue:destroy_linked("ailment pet")
			actual_pet.unique = nil
			table.clear(StateDB.active_ailments)
			return 
		end
		local cdata = ClientData.get("inventory").pets[actual_pet.unique]
		local friendship = cdata.properties.friendship_level
		local money = ClientData.get("money")
		to_home()
		API['HousingAPI/ActivateFurniture']:InvokeServer(
			LocalPlayer,
			furn.bath.unique,
			furn.bath.usepart,
			{
				cframe = furn.bath.cframe
			},
			actual_pet.model
		)
        local deadline = os.clock() + 20
        repeat 
            task.wait(1)
        until not has_ailment("dirty") or os.clock() > deadline
        if os.clock() > deadline then 
			StateDB.active_ailments.dirty = nil
			error("Out of limits") 
		end        
		enstat(friendship, money, "dirty")  
	end,
	["walk"] = function() 
		local pet = ClientData.get("pet_char_wrappers")[1]
		if not pet or not actual_pet.unique or pet.pet_unique ~= actual_pet.unique or not has_ailment("walk") then
			queue:destroy_linked("ailment pet")
			actual_pet.unique = nil
			table.clear(StateDB.active_ailments)
			return 
		end
		local cdata = ClientData.get("inventory").pets[actual_pet.unique]
		local friendship = cdata.properties.friendship_level
		local money = ClientData.get("money")
		local deadline = os.clock() + 60
		gotovec(1000,25,1000)
		API["AdoptAPI/HoldBaby"]:FireServer(actual_pet.model)
		repeat
			LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position + LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector * 50)
			LocalPlayer.Character.Humanoid.MoveToFinished:Wait()
			LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector * 50)
			LocalPlayer.Character.Humanoid.MoveToFinished:Wait()				
		until not has_ailment("walk") or os.clock() > deadline
		API["AdoptAPI/EjectBaby"]:FireServer(pet.model)
		if os.clock() > deadline then 
			StateDB.active_ailments.walk = nil
			error("Out of limits") 
		end      
		enstat(friendship, money, "walk") 
	end,
	["school"] = function() 
		local pet = ClientData.get("pet_char_wrappers")[1]
		if not pet or not actual_pet.unique or pet.pet_unique ~= actual_pet.unique or not has_ailment("school") then
			queue:destroy_linked("ailment pet")
			actual_pet.unique = nil
			table.clear(StateDB.active_ailments)
			return 
		end
		local cdata = ClientData.get("inventory").pets[actual_pet.unique]
		local friendship = cdata.properties.friendship_level
		local money = ClientData.get("money")
		local baby_has_ailment = has_ailment_baby("school")
		goto("School", "MainDoor")
        local deadline = os.clock() + 60
        repeat 
            task.wait(1)
        until not has_ailment("school") or os.clock() > deadline
        if os.clock() > deadline then 
			StateDB.active_ailments.school = nil
			error("Out of limits") 
		end        
		enstat(friendship, money, "school")  
		task.wait(.8)
		if baby_has_ailment and ClientData.get("team") == "Babies" and not has_ailment_baby("school") then
			__baby_callbak(money, "school")
		end
	end,
	["sleepy"] = function()
		local pet = ClientData.get("pet_char_wrappers")[1]
		if not pet or not actual_pet.unique or pet.pet_unique ~= actual_pet.unique or not has_ailment("sleepy") then
			queue:destroy_linked("ailment pet")
			actual_pet.unique = nil
			table.clear(StateDB.active_ailments)
			return 
		end
		local cdata = ClientData.get("inventory").pets[actual_pet.unique]
		local friendship = cdata.properties.friendship_level
		local money = ClientData.get("money")
		to_home()
		API['HousingAPI/ActivateFurniture']:InvokeServer(
			LocalPlayer,
			furn.bed.unique,
			furn.bed.usepart,
			{
				cframe = furn.bed.cframe
			},
			actual_pet.model
		)
        local deadline = os.clock() + 20
        repeat 
            task.wait(1)
        until not has_ailment("sleepy") or os.clock() > deadline
        if os.clock() > deadline then 
			StateDB.active_ailments.sleepy = nil
			error("Out of limits") 
		end        
		enstat(friendship, money, "sleepy")  
	end,
	["mystery"] = function() 
		print("Mystery started")
		local pet = ClientData.get("pet_char_wrappers")[1]
		if not pet or not actual_pet.unique or pet.pet_unique ~= actual_pet.unique or not has_ailment("mystery") then
			queue:destroy_linked("ailment pet")
			actual_pet.unique = nil
			table.clear(StateDB.active_ailments)
			return 
		end
		for k,_ in loader("new:AilmentsDB") do
			API["AilmentsAPI/ChooseMysteryAilment"]:FireServer(
				actual_pet.unique,
				"mystery",
				1,
				k
			)
			-- task.wait(1.2) 
		end
		StateDB.active_ailments.mystery = nil
	end,
	["pizza_party"] = function() 
		local pet = ClientData.get("pet_char_wrappers")[1]
		if not pet or not actual_pet.unique or pet.pet_unique ~= actual_pet.unique or not has_ailment("pizza_party") then
			queue:destroy_linked("ailment pet")
			actual_pet.unique = nil
			table.clear(StateDB.active_ailments)
			return 
		end
		local cdata = ClientData.get("inventory").pets[actual_pet.unique]
		local friendship = cdata.properties.friendship_level
		local money = ClientData.get("money")
		local baby_has_ailment = has_ailment_baby("pizza_party")
		goto("PizzaShop", "MainDoor")
        local deadline = os.clock() + 60
        repeat 
            task.wait(1)
        until not has_ailment("pizza_party") or os.clock() > deadline
        if os.clock() > deadline then 
			StateDB.active_ailments.pizza_party = nil
			error("Out of limits") 
		end        
		enstat(friendship, money, "pizza_party")  
		task.wait(.8)
		if baby_has_ailment and ClientData.get("team") == "Babies" and not has_ailment_baby("pizza_party") then
			__baby_callbak(money, "pizza_party")
		end
	end,
	
	["pet_me"] = function() end,
	["party_zone"] = function() end -- available on admin abuse
}

baby_ailments = {
	["camping"] = function() 
		if not ClientData.get("team") == "Babies" or not has_ailment_baby("camping") then
			return 
		end
		local money = ClientData.get("money")
		to_mainmap()
		gotovec(-23, 37, -1063)
        local deadline = os.clock() + 60
		local pet_has_ailment = has_ailment("camping")
        repeat 
            task.wait(1)
        until not has_ailment_baby("camping") or os.clock() > deadline
        if os.clock() > deadline then 
			StateDB.active_ailments_baby.camping = nil
			error("Out of limits") 
		end		
		enstat_baby(money, "camping")
		task.wait(.8)
		if pet_has_ailment and equiped() and not has_ailment("camping") then
			__pet_callback(ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level, "camping")
		end
	end,
	["hungry"] = function() 
		if not ClientData.get("team") == "Babies" or not has_ailment_baby("hungry") then
			return 
		end
		local money = ClientData.get("money")
		if count_of_product("food", "apple") < 3 then
			if money == 0 then 
				StateDB.active_ailments_baby.hungry = nil 
				colorprint({markup.ERROR}, "[-] No money to buy food.") 
				return 
			end
			if money > 20 then
				API["ShopAPI/BuyItem"]:InvokeServer(
					"food",
					"apple",
					{
						buy_count = 30
					}
				)
			else
				API["ShopAPI/BuyItem"]:InvokeServer(
					"food",
					"apple",
					{
						buy_count = money / 2
					}
				)
			end
		end
		local deadline = os.clock() + 5
		repeat 
			API["ToolAPI/ServerUseTool"]:FireServer(
				inv_get_category_unique("food", "apple"),
				"END"
			)
			task.wait(.5)
        until not has_ailment_baby("hungry") or os.clock() > deadline
        if os.clock() > deadline then 
			StateDB.active_ailments_baby.hungry = nil
			error("Out of limits") 
		end		
		enstat_baby(money, "hungry")  
	end,
	["thirsty"] = function() 
		if not ClientData.get("team") == "Babies" or not has_ailment_baby("thirsty") then
			return 
		end
		local money = ClientData.get("money")
		if count_of_product("food", "water") == 0 then
			if money == 0 then colorprint({markup.ERROR}, "[-] No money to buy food.") return end
			if money > 20 then
				API["ShopAPI/BuyItem"]:InvokeServer(
					"food",
					"water",
					{
						buy_count = 20
					}
				)
			else 
				API["ShopAPI/BuyItem"]:InvokeServer(
					"food",
					"water",
					{
						buy_count = money / 2
					}
				)
			end
		end
        local deadline = os.clock() + 5
		repeat			
			API["ToolAPI/ServerUseTool"]:FireServer(
				inv_get_category_unique("food", "water"),
				"END"
			)
			task.wait(.5)
		until not has_ailment_baby("thirsty") or os.clock() > deadline  
        if os.clock() > deadline then 
			StateDB.active_ailments_baby.thirsty = nil
			error("Out of limits") 
		end		
		enstat_baby(money, "thirsty")  
	end,
	["sick"] = function() 
		if not ClientData.get("team") == "Babies" or not has_ailment_baby("sick") then
			return 
		end
		local money = ClientData.get("money")
		local pet_has_ailment = has_ailment("sick")
		repeat 
			goto("Hospital", "MainDoor")
			API["HousingAPI/ActivateInteriorFurniture"]:InvokeServer(
				"f-14",
				"UseBlock",
				"Yes",
				LocalPlayer.Character
			)
			task.wait(1)
		until not has_ailment_baby("sick") 
		enstat_baby(money, "sick") 
		task.wait(.8)
		if pet_has_ailment and equiped() and not has_ailment("sick") then
			__pet_callback(ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level, "sick")
		end
	end,
	["bored"] = function() 
		if not ClientData.get("team") == "Babies" or not has_ailment_baby("bored") then
			return 
		end
		local money = ClientData.get("money")
		local pet_has_ailment = has_ailment("bored")
		to_mainmap()
		gotovec(-365, 30, -1749)
        local deadline = os.clock() + 60
        repeat 
            task.wait(1)
        until not has_ailment_baby("bored") or os.clock() > deadline
        if os.clock() > deadline then 
			StateDB.active_ailments_baby.broed = nil
			error("Out of limits") 
		end		
		enstat_baby(money, "bored")  
		task.wait(.8)
		if pet_has_ailment and equiped() and not has_ailment("bored") then
			__pet_callback(ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level, "bored")
		end
	end,
	["salon"] = function() 
		if not ClientData.get("team") == "Babies" or not has_ailment_baby("salon") then
			return 
		end
		local money = ClientData.get("money")
		local pet_has_ailment = has_ailment("salon")
		goto("Salon", "MainDoor")
        local deadline = os.clock() + 60
        repeat 
            task.wait(1)
        until not has_ailment_baby("salon") or os.clock() > deadline
        if os.clock() > deadline then 
			StateDB.active_ailments_baby.salon = nil
			error("Out of limits") 
		end		
		enstat_baby(money, "salon")  
		task.wait(.8)
		if pet_has_ailment and equiped() and not has_ailment("salon") then
			__pet_callback(ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level, "salon")
		end
	end,
	["beach_party"] = function() 
		if not ClientData.get("team") == "Babies" or not has_ailment_baby("beach_party") then
			return 
		end
		local money = ClientData.get("money")
		local pet_has_ailment = has_ailment("beach_party")
		to_mainmap()
		gotovec(-596, 27, -1473)
        local deadline = os.clock() + 60
        repeat 
            task.wait(1)
        until not has_ailment_baby("beach_party") or os.clock() > deadline
        if os.clock() > deadline then 
			StateDB.active_ailments_baby.beach_party = nil
			error("Out of limits") 
		end		
		enstat_baby(money, "beach_party")  
		task.wait(.8)
		if pet_has_ailment and equiped() and not has_ailment("beach_party") then
			__pet_callback(ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level, money, "beach_party")
		end
	end,
	["dirty"] = function() 
		if not ClientData.get("team") == "Babies" or not has_ailment_baby("dirty") then
			return 
		end
		local money = ClientData.get("money")
		to_home()
		task.spawn(function() 
			API['HousingAPI/ActivateFurniture']:InvokeServer(
				LocalPlayer,
				furn.bath.unique,
				furn.bath.usepart,
				{
					cframe = furn.bath.cframe
				},
				LocalPlayer.Character
			)
		end)
        local deadline = os.clock() + 20
        repeat 
            task.wait(1)
        until not has_ailment_baby("dirty") or os.clock() > deadline
		task.wait(.3)
		StateManagerClient.exit_seat_states()
        if os.clock() > deadline then 
			StateDB.active_ailments_baby.dirty = nil
			error("Out of limits") 
		end		
		enstat_baby(money, "dirty")  
	end,
	["school"] = function() 
		if not ClientData.get("team") == "Babies" or not has_ailment_baby("school") then
			return 
		end
		local money = ClientData.get("money")
		local pet_has_ailment = has_ailment("school")
		goto("School", "MainDoor")
        local deadline = os.clock() + 60
        repeat 
            task.wait(1)
        until not has_ailment_baby("school") or os.clock() > deadline
        if os.clock() > deadline then 
			StateDB.active_ailments_baby.school = nil
			error("Out of limits") 
		end		
		enstat_baby(money, "school")  
		task.wait(.8)
		if pet_has_ailment and equiped() and not has_ailment("school") then
			__pet_callback(ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level, "school")
		end
	end,
	["sleepy"] = function() 
		if not ClientData.get("team") == "Babies" or not has_ailment_baby("sleepy") then
			return 
		end
		local money = ClientData.get("money")
		to_home()
		task.spawn(function() 
			API['HousingAPI/ActivateFurniture']:InvokeServer(
				LocalPlayer,
				furn.bed.unique,
				furn.bed.usepart,
				{
					cframe = furn.bed.cframe
				},
				LocalPlayer.Character
			)
		end)
        local deadline = os.clock() + 20
        repeat 
            task.wait(1)
        until not has_ailment_baby("sleepy") or os.clock() > deadline
		task.wait(.3)
		StateManagerClient.exit_seat_states()
        if os.clock() > deadline then 
			StateDB.active_ailments_baby.sleepy = nil
			error("Out of limits") 
		end		
		enstat_baby(money, "sleepy")  
	end,
	["pizza_party"] = function() 
		if not ClientData.get("team") == "Babies" or not has_ailment_baby("pizza_party") then
			return 
		end
		local money = ClientData.get("money")
		local pet_has_ailment = has_ailment("pizza_party")
		goto("PizzaShop", "MainDoor")
        local deadline = os.clock() + 60
        repeat 
            task.wait(1)
        until not has_ailment_baby("pizza_party") or os.clock() > deadline
        if os.clock() > deadline then 
			StateDB.active_ailments_baby.pizza_party = nil
			error("Out of limits") 
		end		
		enstat_baby(money, "pizza_party")  
		task.wait(.8)
		if pet_has_ailment and equiped() and not has_ailment("pizza_party") then
			__pet_callback(ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level, "pizza_party")
		end
	end,
}

local function init_autofarm() -- optimized
	if count(get_owned_pets()) == 0 then
		repeat 
			task.wait(50)
		until count(get_owned_pets()) > 0
	end

	while task.wait(1) do
		local pet = ClientData.get("pet_char_wrappers")[1]
		if pet then
			API["ToolAPI/Unequip"]:InvokeServer(
				pet.pet_unique,
				{
					use_sound_delay = true,
					equip_as_last = false
				}
			)
		end
		local owned_pets = get_owned_pets()
		local flag = false
		if _G.InternalConfig.PotionFarm then
			if _G.InternalConfig.FarmPriority == "pets" then
				for k,v in owned_pets do
					if v.age == 6 and not _G.InternalConfig.AutoFarmFilter.PetsToExclude[v.remote] then
						API["ToolAPI/Equip"]:InvokeServer(
							k,
							{
								use_sound_delay = true,
								equip_as_last = false
							}
						)
						if not equiped() then
							continue
						end
						flag = true		
						break				
					end
				end
			else 
				for k,v in owned_pets do
					if (v.name:lower()):find("egg") then
						API["ToolAPI/Equip"]:InvokeServer(
							k,
							{
								use_sound_delay = true,
								equip_as_last = false
							}
						)
						if not equiped() then
							continue
						end
						flag = true
						break
					end
				end
				if not flag then
					for k, _ in owned_pets do
						API["ToolAPI/Equip"]:InvokeServer(
							k,
							{
								use_sound_delay = true,
								equip_as_last = false
							}
						)
						if not equiped() then
							continue
						end
						flag = true
						break
					end
				end
			end
		else
			if _G.InternalConfig.FarmPriority == "pets" then			
				for k,v in owned_pets do
					if v.age < 6 and not _G.InternalConfig.AutoFarmFilter.PetsToExclude[v.remote] and not (v.name:lower()):match("egg") then
						API["ToolAPI/Equip"]:InvokeServer(
							k,
							{
								use_sound_delay = true,
								equip_as_last = false
							}
						)
						if not equiped() then
							continue
						end
						flag = true
						break
					end
				end
			else 
				for k,v in owned_pets do
					if not _G.InternalConfig.AutoFarmFilter.PetsToExclude[v.remote] and (v.name:lower()):match("egg") then
						API["ToolAPI/Equip"]:InvokeServer(
							k,
							{
								use_sound_delay = true,
								equip_as_last = false
							}
						)
						if not equiped() then
							continue
						end
						flag = true
						break
					end
				end
			end
			if not flag then
				for k, _ in owned_pets do
					API["ToolAPI/Equip"]:InvokeServer(
						k,
						{
							use_sound_delay = true,
							equip_as_last = false
						}
					)
					if not equiped() then
						continue
					end
					flag = true
					break
				end
			end
		end 
		if not flag or not equiped() then task.wait(28) continue end
		task.wait(2)
		local curpet = get_equiped_pet()
		actual_pet.unique = curpet.unique
		actual_pet.remote = curpet.remote
		actual_pet.model = curpet.model
		actual_pet.wrapper = curpet.wrapper
		actual_pet.rarity = curpet.rarity
		actual_pet.is_egg = (curpet.name:lower()):match("egg")

		while task.wait(1) do
			if actual_pet.unique ~= cur_unique() then
				actual_pet.unique = nil
				break
			end
			if not actual_pet.unique then
				break
			end			
			local eqpetailms = get_equiped_pet_ailments()
			if not eqpetailms then
				task.wait(10)
				continue
			end
			for k,_ in eqpetailms do 
				if StateDB.active_ailments[k] then continue end
				if pet_ailments[k] then
					StateDB.active_ailments[k] = true
					if k == "mystery" then 
						queue:__asyncrun({`ailment pet: {k}`, pet_ailments[k]}) 
						continue 
					end
					queue:enqueue({`ailment pet: {k}`, pet_ailments[k]})
				end
			end
			task.wait(20)
		end
	end
end
	
local function init_baby_autofarm() -- optimized
	while task.wait(1) do
		if ClientData.get("team") ~= "Babies" then
			API["TeamAPI/ChooseTeam"]:InvokeServer(
				"Babies",
				{
					dont_respawn = true,
					source_for_logging = "avatar_editor"
				}
			)
			task.wait(1)
		end	
		if not _G.InternalConfig.FarmPriority then
			local pet = ClientData.get("pet_char_wrappers")[1]
			if pet then
				API["ToolAPI/Unequip"]:InvokeServer(
					pet.pet_unique,
					{
						use_sound_delay = true,
						equip_as_last = false
					}
				)
			end
		end
		local active_ailments = get_baby_ailments()
		for k,_ in active_ailments do
			if StateDB.baby_active_ailments[k] then continue end
			if baby_ailments[k] then
				StateDB.baby_active_ailments[k] = true
				queue:enqueue({`ailment baby {k}`, baby_ailments[k]})
			end
		end
		task.wait(15)
	end
end

local function init_auto_buy() -- optimized
	local cost = InventoryDB.pets[_G.InternalConfig.AutoFarmFilter.EggAutoBuy].cost
	if cost then
		while task.wait(1) do
			local farmd = farmed.money
			API["ShopAPI/BuyItem"]:InvokeServer(
				"pets",
				_G.InternalConfig.AutoFarmFilter.EggAutoBuy,
				{
					buy_count = ClientData.get("money") / cost
				}
			)
			farmed.money = farmd
			task.wait(300)
		end
	else 
		return
	end
end

local function init_auto_recycle()
	local pet_to_exchange = {}
	local owned_pets = get_owned_pets()
	
	if not _G.InternalConfig.PetExchangeRarity then
		for k,v in owned_pets do
			if v.age == _G.InternalConfig.PetExchangeAge then
				pet_to_exchange[k] = true
			end
		end
	else
		for k,v in owned_pets do
			if v.age == _G.InternalConfig.PetExchangeAge then
				if v.rarity == _G.InternalConfig.PetExchangeRarity then
					pet_to_exchange[k] = true
				end
			end
		end
	end

	API["HousingAPI/ActivateInteriorFurniture"]:InvokeServer(
		"f-9",
		"UseBlock",
		{
			action = "use",
			uniques = pet_to_exchange
		},
		LocalPlayer.Character
	)
end

local function init_auto_trade() -- optimized
	local user = _G.InternalConfig.AutoTradeFilter.PlayerTradeWith 
	local exist = false
	local trade_successed = true
	if game.Players:FindFirstChild(user) then
		exist = true
	end

	game.Players.PlayerAdded:Connect(function(player)
		if player == user then 
			player.CharacterAdded:Wait()
			exist = true 
		end
	end)
	
	game.Players.PlayerRemoving:Connect(function(player) 
		if player == user then
			exist = false
		end
	end)

	while task.wait(1) do 
		while not exist do
			task.wait(4)
		end
		
		local pets_to_send = {}
		local r = send_trade_request(user)
		if r == "No response" then
			colorprint({markup.ERROR}, "[-] No response")
			task.wait(_G.InternalConfig.AutoTradeFilter.TradeDelay)
			continue
		else
			local owned_pets = get_owned_pets()
			while UIManager.is_visible("TradeApp") do
				local exclude = {}
				if _G.InternalConfig.AutoTradeFilter.ExcludeFriendly then
					for k,v in owned_pets do
						if v.friendship > 0 then
							exclude[k] = true
						end
					end
				end
				if _G.InternalConfig.AutoTradeFilter.ExcludeEggs then
					for k,v in owned_pets do
						if (v.name:lower()):find("egg") then 
							exclude[k] = true
						end
					end
				end
				if _G.InternalConfig.AutoTradeFilter.SendAllFarmed then
					for _,v in total_fullgrowned do
						if owned_pets[v] and not exclude[v] then
							pets_to_send[v] = true
						end
 					end
				end
				if _G.InternalConfig.AutoTradeFilter.SendAllType then
					if type(_G.InternalConfig.AutoTradeFilter.SendAllType) == "number" then
						for k,_ in inv_get_pets_with_age(_G.InternalConfig.AutoTradeFilter.SendAllType) do
							if not pets_to_send[k] and not exclude[k] then
								pets_to_send[k] = true
							end
						end
					else
 						for k,v in inv_get_pets_with_rarity(_G.InternalConfig.AutoTradeFilter.SendAllType) do
							if not pets_to_send[k] and not exclude[k] then
								pets_to_send[k] = true
							end
						end
					end
				end
				pcall(function()
				for k,_ in pets_to_send do 
					API["TradeAPI/AddItemToOffer"]:FireServer(k)
					task.wait(.2)
				end
				repeat 
					while UIManager.apps.TradeApp:_get_local_trade_state().current_stage == "negotiation" do
						API["TradeAPI/AcceptNegotiation"]:FireServer()
						task.wait(5)
					end
					API["TradeAPI/ConfirmTrade"]:FireServer()
					task.wait(5)
				until not UIManager.is_visible("TradeApp")
			end)
			end
		end
		for k,_ in get_owned_pets() do
			if pets_to_send[k] then 
				trade_successed = false
				break
			end
		end
		if not trade_successed then
			trade_successed = true
			colorprint({markup.ERROR}, "[-] Trade was canceled.")
			task.wait(25)
			continue
		else
			colorprint({markup.SUCCESS}, "[+] Trade successed.")
			if _G.InternalConfig.AutoTradeFilter.WebhookEnabled then
				webhook("TradeLog", `Trade with {user} successed.`)
			end
		end
		task.wait(3600)
	end
end

-- -- сделать детект предметов которые ты можешшь положить в бокс
local function init_lurebox() -- optimized
	
	local function to_home_and_check_bait_placed()
		to_home()
		if not debug.getupvalue(LureBaitHelper.run_tutorial, 11)() then
			API["HousingAPI/ActivateFurniture"]:InvokeServer(
				LocalPlayer,
				furn.lurebox.unique,
				"UseBlock",
				{
					bait_unique = inv_get_category_unique("food", "ice_dimension_2025_ice_soup_bait") -- возможно не этот remote
				},
				LocalPlayer.Character
			)
			colorprint({markup.INFO}, "[Lure] Tried to place bait.")
		end

		API["HousingAPI/ActivateFurniture"]:InvokeServer(
			LocalPlayer,
			furn.lurebox.unique,
			"UseBlock",
			false,
			LocalPlayer.Character
		)
		task.wait(.5)
		_G.bait_placed = debug.getupvalue(LureBaitHelper.run_tutorial, 11)() 
		_G.can_proceed = true 
	end

	while task.wait(1) do
		queue:enqueue{"bait_check", to_home_and_check_bait_placed}
		repeat 
			task.wait(1)		
		until _G.can_proceed
		_G.can_proceed = false
		if not _G.bait_placed then
			colorprint({markup.SUCCESS}, "[Lure] Reward collected")
		else
			colorprint({markup.INFO}, "[Lure] Next check in 1h.")
			task.wait(3600)
		end
	end
end

local function init_gift_autoopen() -- чета тут не так
	while count(get_owned_category("gifts")) < 1 do
		task.wait(300) 
	end
	for k,_ in get_owned_category("gifts") do
		if k.remote:lower():match("box") or k.remote:lower():match("chest") then
			API["LootBoxAPI/ExchangeItemForReward"]:InvokeServer(k.remote,k)
		else
			API["ShopAPI/OpenGift"]:InvokeServer(k)
		end
		task.wait(.5) 
	end	
end

-- local function init_auto_give_potion()
	
-- 	local function get_potions() 
-- 	local potions = {}
-- 		for k,v in get_owned_category("food") do
-- 			if (v.id:lower()):match("potion") then
-- 				table.insert(potions, k)
-- 			end 
-- 		end
-- 		if #potions > 0 then return potions else return nil end
-- 	end

-- 	while task.wait(1) do
-- 		local pets_to_grow = {}
-- 		local owned_pets = get_owned_pets()
-- 		if _G.InternalConfig.AutoGivePotion ~= "any" then
-- 			for k,_ in _G.InternalConfig.AutoGivePotion do
-- 				local pet = inv_get_category_unique("pets", k)
-- 				if owned_pets[pet] and owned_pets[pet].age < 6 and not (owned_pets[pet].name:lower()):match("egg") then
-- 					pets_to_grow[pet] = true
-- 				end
-- 			end
-- 		else
-- 			for k,v in owned_pets do
-- 				if v.age < 6 and not (v.name:lower()):match("egg") then
-- 					pets_to_grow[k] = true
-- 				end
-- 			end
-- 		end
-- 		local equiped_pet
-- 		for k,_ in pets_to_grow do
-- 			local potions = get_potions()
-- 			if not potions then task.wait(300) break end	
			
-- 			equiped_pet = ClientData.get("pet_char_wrappers")[1]
-- 			if equiped_pet then
-- 				API["ToolAPI/Unequip"]:InvokeServer(
-- 					equiped_pet.pet_unique,
-- 					{
-- 						use_sound_delay = true,
-- 						equip_as_last = false
-- 					}
-- 				)
-- 				task.wait(1)
-- 				API["ToolAPI/Equip"]:InvokeServer(
-- 					k,
-- 					{
-- 						use_sound_delay = true,
-- 						equip_as_last = false
-- 					}
-- 				)
-- 			end
-- 			task.wait(1)
-- 			for a,_ in ipairs(potions) do
-- 				local others = {}
-- 				for i, _ in ipairs(potions) do
-- 					for j, p in ipairs(potions) do
-- 						if j ~= i then table.insert(others, p) end
-- 					end
-- 				end
-- 				API["PetObjectAPI/CreatePetObject"]:InvokeServer(
-- 					"__Enum_PetObjectCreatorType_2",
-- 					{
-- 						additional_consume_uniques = {
-- 							table.unpack(others)
-- 						},
-- 						pet_unique = k,
-- 						unique_id = a
-- 					}
-- 				)
-- 				task.wait(1)
-- 			end
-- 		end
-- 		task.wait(1)
-- 		API["ToolAPI/Equip"]:InvokeServer(
-- 			equiped_pet.pet_unique or actual_pet.unique or "",
-- 			{
-- 				use_sound_delay = true,
-- 				equip_as_last = false
-- 			}
-- 		)
-- 		task.wait(299)
-- 	end
-- end

local function init_mode() 
	if _G.InternalConfig.Mode == "bot" then
		RunService:Set3dRenderingEnabled(false)
	else
		-- playable optmization
	end
end

local function __init() 

	-- task.defer(function() 
	-- 	-- memory monitor
	-- 	repeat
	-- 		task.wait(60)
	-- 	until false
	-- end)


	if _G.InternalConfig.FarmPriority then
		task.defer(init_autofarm)
	end
	
	if _G.InternalConfig.AutoFarmFilter.EggAutoBuy then
		task.defer(init_auto_buy)
	end

	if _G.InternalConfig.BabyAutoFarm then
		task.defer(init_baby_autofarm)
	end

	if _G.InternalConfig.AutoRecyclePet then
		task.defer(init_auto_recycle)
	end

	-- if _G.InternalConfig.AutoGivePotion then
	-- 	task.defer(init_auto_give_potion)
	-- end

	if _G.InternalConfig.PetAutoTrade then
		task.defer(init_auto_trade)
	end

	if _G.InternalConfig.DiscordWebhookURL then
		task.defer(function()
			while task.wait(1) do
				task.wait(_G.InternalConfig.WebhookSendDelay)
				webhook(
					"AutoFarm Log",
					`**💸Money Earned :** {farmed.money}\n\
	   				**📈Pets Full-grown :** {farmed.pets_fullgrown}\n\
	   				**🐶Pet Needs Completed :** {farmed.ailments}\n\
	   				**🧪Potions Farmed :** {farmed.potions}\n\
	   				**🧸Friendship Levels Farmed :** {farmed.friendship_levels}\n\
	   				**👶Baby Needs Completed :** {farmed.baby_ailments}\n\
	   				**🥚Eggs Hatched :** {farmed.eggs_hatched}`
				)
			end
		end)
	end

	if _G.InternalConfig.LureboxFarm then
		task.defer(init_lurebox)
	end

	if _G.InternalConfig.GiftsAutoOpen then
		task.defer(init_gift_autoopen)
	end

	task.wait(5)

	if _G.InternalConfig.Mode then
		task.defer(init_mode)
	end

end

local function autotutorial() end

local function license() -- optimized 
	if loader("TradeLicenseHelper").player_has_trade_license(LocalPlayer) then
		colorprint({markup.SUCCESS}, "[+] License found.")
	else
		colorprint({markup.INFO}, "[?] License not found, trying to get..")
		API["SettingsAPI/SetBooleanFlag"]:FireServer("has_talked_to_trade_quest_npc", true)
		API["TradeAPI/BeginQuiz"]:FireServer()
		task.wait(.2)
		for _,v in ClientData.get("trade_license_quiz_manager").quiz do
			API["TradeAPI/AnswerQuizQuestion"]:FireServer(v.answer)
		end
		colorprint({markup.SUCCESS}, "[+] Successed.")
	end
end


--[[ Init ]]--
;(function() -- api deash
	colorprint({markup.INFO}, "[?] Starting..")
	for k, v in pairs(getupvalue(require(ReplicatedStorage.ClientModules.Core:WaitForChild("RouterClient"):WaitForChild("RouterClient")).init, 7)) do
		v.Name = k
	end
	colorprint({markup.SUCCESS}, "[+] API dehashed.")
end)()

NetworkClient.ChildRemoved:Connect(function()
	local send_responce = function()
		return HttpService:RequestAsync({
			Url = "https://pornhub.com",
			Method = "GET"
		})
	end
	repeat
		print("No internet. Waiting..")
		task.wait(5)
		local success, _ = pcall(send_responce)
	until success 
	TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)

LocalPlayer.Idled:Connect(function() -- anti afk
  VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
  task.wait(1)
  VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

-- internal config init
;(function() -- optimized
	-- FarmPriority
	if type(Config.FarmPriority) == "string" then
		_G.InternalConfig.AutoFarmFilter = {}
		if (Config.FarmPriority):lower() == "eggs" or (Config.FarmPriority):lower() == "pets" then
			_G.InternalConfig.FarmPriority = Config.FarmPriority
			if type(Config.AutoFarmFilter.PetsToExclude) == "table" then -- AutoFarmFilter / PetsToExclude
				if not #Config.AutoFarmFilter.PetsToExclude == 0 then
					if Config.AutoFarmFilter.PetsToExclude[1]:match("^%s*$") then
						local list = {}
						for _,v in Config.AutoFarmFilter.PetsToExclude do
							if check_remote_existance("pets", v) then
								list[v] = true
							else
								colorprint({markup.ERROR}, `[AutoFarmFilter.PetsToExclude] Wrong [{v}] remote name.`)
							end
						end
						if count(list) > 0 then
							_G.InternalConfig.AutoFarmFilter.PetsToExclude = list
						else
							colorprint({markup.WARNING}, "[AutoFarmFilter.PetsToExclude] No valid remote names. Option is disabled.")
							_G.InternalConfig.AutoFarmFilter.PetsToExclude = {}
						end
					else
						_G.InternalConfig.AutoFarmFilter.PetsToExclude = {}
					end
				else
					_G.InternalConfig.AutoFarmFilter.PetsToExclude = {}
				end
			else
				error("[AutoFarmFilter.PetsToExclude] Wrong datatype. Exiting.")
			end			

			if type(Config.AutoFarmFilter.PotionFarm) == "boolean" then -- AutoFarmFilter / PotionFarm
				if Config.AutoFarmFilter.PotionFarm then	
					if _G.InternalConfig.FarmPriority == "eggs" then 
						_G.InternalConfig.AutoFarmFilter.PotionFarm = false
					else
						_G.InternalConfig.AutoFarmFilter.PotionFarm = true
					end
				else
					_G.InternalConfig.AutoFarmFilter.PotionFarm = false
				end
			else 
				error("[AutoFarmFilter.PotionFarm] Wrong datatype. Exiting.")
			end

			if type(Config.AutoFarmFilter.EggAutoBuy) == "string" then -- AutoFarmFilter / EggAutoBuy
				if not (Config.AutoFarmFilter.EggAutoBuy):match("^%s*$") then 
					if check_remote_existance("pets", Config.AutoFarmFilter.EggAutoBuy) then
						_G.InternalConfig.AutoFarmFilter.EggAutoBuy = Config.AutoFarmFilter.EggAutoBuy
					else
						_G.InternalConfig.AutoFarmFilter.EggAutoBuy = false
						colorprint({markup.ERROR}, `[AutoFarmFilter.EggAutoBuy] Wrong [{Config.AutoFarmFilter.EggAutoBuy}] remote name. Option is disabled.`)
					end
				else
					_G.InternalConfig.AutoFarmFilter.EggAutoBuy = false
				end
			else
				error("[AutoFarmFilter.EggAutoBuy] Wrong datatype. Exiting.")
			end
			
		elseif (Config.FarmPriority):match("^%s*$") then 
			_G.InternalConfig.FarmPriority = false
			_G.InternalConfig.AutoFarmFilter.EggAutoBuy = false 
			_G.InternalConfig.AutoFarmFilter.PotionFarm = false 
			_G.InternalConfig.AutoFarmFilter.PetsToExclude = {} 
			
		else 
			error("[FarmPriority] Wrong value. Exiting.")
		end
	else  
		error("[FarmPriority] Wrong datatype. Exiting.")
	end

	if type(Config.BabyAutoFarm) == "boolean" then -- babyAutoFarm
		_G.InternalConfig.BabyAutoFarm = Config.BabyAutoFarm
	else
		error("[BabyAutoFarm] Wrong datatype. Exiting.")
	end

	if type(Config.LureboxFarm) == "boolean" then
		_G.InternalConfig.LureboxFarm = Config.LureboxFarm
	else
		error("[LureboxFarm] Wrong datatype. Exiting.")
	end

	if type(Config.GiftsAutoOpen) == "boolean" then
		_G.InternalConfig.GiftsAutoOpen = Config.GiftsAutoOpen
	else
		error("[GiftsAutoOpen] Wrong datatype. Exiting.")
	end

	if type(Config.AutoGivePotion) == "string" then
		if not (Config.AutoGivePotion):match("^%s*$") then 
			_G.InternalConfig.AutoGivePotion = {}
			if Config.AutoGivePotion == "any" or Config.AutoGivePotion:match(";") then
				if Config.AutoGivePotion == "any" then
					_G.InternalConfig.AutoGivePotion = "any"
				else
					for v in Config.AutoGivePotion:gmatch("([^;]+)") do
						if InventoryDB.pets[v] then
							_G.InternalConfig.AutoGivePotion[v] = true 
						else
							colorprint({markup.ERROR}, `[AutoGivePotion] Wrong [{v}] remote name.`)
						end
					end
					if count(_G.InternalConfig.AutoGivePotion) == 0 then
						colorprint({markup.WARNING}, "[AutoGivePotion] No valid remote names. Option is disabled.")
						_G.InternalConfig.AutoGivePotion = false
					end
				end
			else
				error("[AutoGivePotion] Wrong value. Exiting.")
			end
		else
			_G.InternalConfig.AutoGivePotion = false
		end
	else
		error("[AutoGivePotion] Wrong datatype. Exiting.")
	end

	if type(Config.AutoRecyclePet) == "boolean" then -- CrystalEggFarm
		if Config.AutoRecyclePet then
			_G.InternalConfig.AutoRecyclePet = true
			if not _G.InternalConfig.FarmPriority then
				_G.InternalConfig.FarmPriority = "pets"				
				if type(Config.AutoFarmFilter.PetsToExclude) == "table" then -- AutoFarmFilter / PetsToExclude
					local list = {}
					for _,v in Config.AutoFarmFilter.PetsToExclude do
						if check_remote_existance("pets", v) then
							list[v] = true
						end
					end
					if count(list) > 0 then
						_G.InternalConfig.AutoFarmFilter.PetsToExclude = list
					else
						_G.InternalConfig.AutoFarmFilter.PetsToExclude = {}
					end
				else
					_G.InternalConfig.AutoFarmFilter.PetsToExclude = {}
				end			

				if type(Config.AutoFarmFilter.PotionFarm) == "boolean" then -- AutoFarmFilter / PotionFarm
					if Config.AutoFarmFilter.PotionFarm then	
						if _G.InternalConfig.FarmPriority == "eggs" then 
							_G.InternalConfig.AutoFarmFilter.PotionFarm = false
						else
							_G.InternalConfig.AutoFarmFilter.PotionFarm = true
						end
					else
						_G.InternalConfig.AutoFarmFilter.PotionFarm = false
					end
				else 
					_G.InternalConfig.AutoFarmFilter.PotionFarm = true
				end

				if type(Config.AutoFarmFilter.EggAutoBuy) == "string" then -- AutoFarmFilter / EggAutoBuy
					if not (Config.AutoFarmFilter.EggAutoBuy):match("^%s*$") then 
						if check_remote_existance("pets", Config.AutoFarmFilter.EggAutoBuy) then
							_G.InternalConfig.AutoFarmFilter.EggAutoBuy = Config.AutoFarmFilter.EggAutoBuy
						else
							_G.InternalConfig.AutoFarmFilter.EggAutoBuy = false
						end
					else
						_G.InternalConfig.AutoFarmFilter.EggAutoBuy = false
					end
				else
					_G.InternalConfig.AutoFarmFilter.EggAutoBuy = false
				end
			end

			local possible = {"common", "uncommon", "rare", "ultra_rare", "legendary"}
			if type(Config.PetExchangeRarity) == "string" then -- PetExchangeRarity
				if not (Config.PetExchangeRarity):match("^%s*$") then 
					if table.find(possible, Config.PetExchangeRarity) then
						_G.InternalConfig.PetExchangeRarity = Config.PetExchangeRarity
					else
						_G.InternalConfig.PetExchangeRarity = false
					end
				else
					_G.InternalConfig.PetExchangeRarity = false
				end
			else
				error("[PetExchangeRarity] Wrong datatype. Exiting")
			end

			local possible = {
				["newborn"] = 1,
				["junior"] = 2,
				["preteen"] = 3,
				["teen"] = 4,
				["postteen"] = 5,
				["fullgrown"] = 6
			}
			if type(Config.PetExchangeAge) == "string" then -- PetExchangeAge
				if not (Config.PetExchangeAge):match("^%s*$") then 
					_G.InternalConfig.PetExchangeAge = 6
					for k,v in possible do
						if k == Config.PetExchangeAge then
							_G.InternalConfig.PetExchangeAge = v
						end
					end					
				else
					_G.InternalConfig.PetExchangeAge = 6
				end
			else
				error("[PetExchangeAge] Wrong datatype. Exiting.")
			end
		else 
			_G.InternalConfig.AutoRecyclePet = false
			_G.InternalConfig.PetExchangeAge = false
		end
	else
		error("[AutoRecyclePet] Wrong datatype. Exiting.")
	end

	if type(Config.DiscordWebhookURL) == "string" then -- DiscordWebhookURL
		if not (Config.DiscordWebhookURL):match("^%s*$") then 
			local res, _ = pcall(function() 
				request({
				Url = Config.DiscordWebhookURL,
				Method = "GET"
			})end)
			if res then
				_G.InternalConfig.DiscordWebhookURL = Config.DiscordWebhookURL
			else
				_G.InternalConfig.DiscordWebhookURL = false
			end
		else 
			_G.InternalConfig.DiscordWebhookURL = false
		end
	else
		error("[DiscordWebhookURL] Wrong datatype. Exiting.")
	end


	if type(Config.PetAutoTrade) == "boolean" then
		_G.InternalConfig.AutoTradeFilter = {}
		if Config.PetAutoTrade then 
			_G.InternalConfig.PetAutoTrade = true	
			if type(Config.AutoTradeFilter.PlayerTradeWith) == "string" then -- PlayerTradeWith
				if not Config.AutoTradeFilter.PlayerTradeWith:match("^%s*$") then 
					_G.InternalConfig.AutoTradeFilter.PlayerTradeWith = Config.AutoTradeFilter.PlayerTradeWith
					local possible = {
						["common"] = "common", 
						["uncommon"] = "uncommon",
						["rare"] = "rare",
						["ultra_rare"] = "ultra_rare",
						["legendary"] = "legendary",
						["newborn"] = 1,
						["junior"] = 2,
						["preteen"] = 3,
						["teen"] = 4,
						["postteen"] = 5,
						["fullgrown"] = 6,
					}
					if type(Config.AutoTradeFilter.SendAllType) == "string" then
						_G.InternalConfig.AutoTradeFilter.SendAllType = false
						for k,v in possible do
							if k == Config.AutoTradeFilter.SendAllType then
								_G.InternalConfig.AutoTradeFilter.SendAllType = v
							end
						end
					else
						error("[AutoTradeFilter.SendAllType] Wrong datatype. Exiting.")
					end
					if type(Config.AutoTradeFilter.SendAllFarmed) == "boolean" then
						_G.InternalConfig.AutoTradeFilter.SendAllFarmed = Config.AutoTradeFilter.SendAllFarmed
					else
						error("[AutoTradeFilter.SendAllFarmed] Wrong datatype. Exiting.")
					end
					if type(Config.AutoTradeFilter.ExcludeFriendly) == "boolean" then
						_G.InternalConfig.AutoTradeFilter.ExcludeFriendly = Config.AutoTradeFilter.ExcludeFriendly
					else
						error("[AutoTradeFilter.ExcludeFriendy] Wrong datatype. Exiting.")
					end
					if type(Config.AutoTradeFilter.ExcludeEggs) == "boolean" then
						_G.InternalConfig.AutoTradeFilter.ExcludeEggs = Config.AutoTradeFilter.ExcludeEggs
					else
						error("[AutoTradeFilter.ExcludeEggs] Wrong datatype. Exiting.")
					end
					if type(Config.AutoTradeFilter.WebhookEnabled) == "boolean" then
						if Config.AutoTradeFilter.WebhookEnabled then
							if _G.InternalConfig.DiscordWebhookURL then
								_G.InternalConfig.AutoTradeFilter.WebhookEnabled = true
							else
								_G.InternalConfig.AutoTradeFilter.WebhookEnabled = false
							end
						else
							_G.InternalConfig.AutoTradeFilter.WebhookEnabled = false
						end
					else
						error("[WebhookEnabled] Wrong datatype. Exiting.")
					end
					if type(Config.AutoTradeFilter.TradeDelay) == "number" then
						if Config.AutoTradeFilter.TradeDelay >= 1 then
							_G.InternalConfig.AutoTradeFilter.TradeDelay = Config.AutoTradeFilter.TradeDelay
						else
							_G.InternalConfig.AutoTradeFilter.TradeDelay = 40 
							colorprint({markup.WARNING}, "[AutoTradeFilter.TradeDelay] Value of TradeDelay can't be lower than 1. Reseting to 40.")
						end
					else 
						error("[AutoTradeFilter.TradeDelay] Wrong datatype. Exiting.")
					end
				else 
					colorprint({markup.WARNING}, "[!] AutoTradeFilter.PlayerTradeWith is not specified. PetAutoTrade won't work.")
					_G.InternalConfig.PetAutoTrade = false
					_G.InternalConfig.AutoTradeFilter.PlayerTradeWith = false
					_G.InternalConfig.AutoTradeFilter.SendAllType = false
					_G.InternalConfig.AutoTradeFilter.SendAllFarmed = false
					_G.InternalConfig.AutoTradeFilter.ExcludeFriendly = false
					_G.InternalConfig.AutoTradeFilter.WebhookEnabled = false
					_G.InternalConfig.AutoTradeFilter.TradeDelay = false
				end
			else
				error("[AutoTradeFilter.PlayerTradeWith] Wrong datatype. Exiting.")
			end
		else
			_G.InternalConfig.PetAutoTrade = false
			_G.InternalConfig.AutoTradeFilter.PlayerTradeWith = false
			_G.InternalConfig.AutoTradeFilter.SendAllType = false
			_G.InternalConfig.AutoTradeFilter.SendAllFarmed = false
			_G.InternalConfig.AutoTradeFilter.ExcludeFriendly = false
			_G.InternalConfig.AutoTradeFilter.WebhookEnabled = false
			_G.InternalConfig.AutoTradeFilter.TradeDelay = false
		end
	else
		error("[PetAutoTrade] Wrong datatype. Exiting.")
	end

	if type(Config.WebhookSendDelay) == "number" then
		if Config.WebhookSendDelay >= 1 then
			_G.InternalConfig.WebhookSendDelay = Config.WebhookSendDelay
		else
			_G.InternalConfig.WebhookSendDelay = 3600
			colorprint({markup.WARNING}, "[!] Value of WebhookSendDelay can't be lower than 1. Reseting to 3600.")
		end
	else
		error("[WebhookSendDelay] Wrong datatype. Exiting.")
	end

	if type(Config.Mode) == "string" then
		if Config.Mode == "bot" or Config.mode == "playable" then
			_G.InternalConfig.Mode = Config.Mode
		end
	else
		error("[Mode] Wrong datatype. Exiting.")
	end
end)()

-- launch screen
;(function() -- optmized
	if LocalPlayer.Character then return end
	repeat 
		task.wait(1)
	until not LocalPlayer.PlayerGui.AssetLoadUI.Enabled
	API["TeamAPI/ChooseTeam"]:InvokeServer("Parents", {source_for_logging="intro_sequence"})
	task.wait(1)
	UIManager.set_app_visibility("MainMenuApp", false)
	UIManager.set_app_visibility("NewsApp", false)
	UIManager.set_app_visibility("DialogApp", false)
	task.wait(3)
	API["DailyLoginAPI/ClaimDailyReward"]:InvokeServer()
	UIManager.set_app_visibility("DailyLoginApp", false)
	API["PayAPI/DisablePopups"]:FireServer()
	repeat task.wait(.3) until LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart and LocalPlayer.Character.Humanoid and LocalPlayer.PlayerGui
	task.wait(1)
end)()

-- stats gui
task.spawn(function() -- optimized
	local gui = Instance.new("ScreenGui") 
	gui.Name = "StatsOverlay" 
	gui.ResetOnSpawn = false 
	gui.Parent = CoreGui

    local frame = Instance.new("Frame")
    frame.Name = "StatsFrame"
    frame.Size = UDim2.new(0, 250, 0, 150)
    frame.Position = UDim2.new(0, 5, 0, 5)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.3
    frame.Parent = gui

    local function createLabel(name, text, order)
        local label = Instance.new("TextLabel")
        label.Name = name
        label.Size = UDim2.new(1, 0, 0, 20)
        label.Position = UDim2.new(0, 0, 0, order * 22)
        label.BackgroundTransparency = 1
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Font = Enum.Font.SourceSans
        label.TextSize = 18
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = text .. ": 0"
        label.Parent = frame
        return label
    end

    createLabel("bucks", "💸Bucks earned", 0)
    createLabel("fullgrown", "📈Pets full-grown", 1)
    createLabel("pet_needs", "🐶Pet needs completed", 2)
    createLabel("potions", "🧪Potions farmed", 3)
    createLabel("friendship", "🧸Friendship levels farmed", 4)
    createLabel("baby_needs", "👶Baby needs completed", 5)
    createLabel("eggs", "🥚Eggs hatched", 6)
end) 


-- furniture init
;(function() -- optimized
	if not _G.InternalConfig.FarmPriority and not _G.InternalConfig.BabyAutoFarm and not _G.InternalConfig.LureboxFarm then return end	
	to_home()
	local furniture = {}
	local filter = {
		bed = true,
		crib = true,
		shower = true,
		toilet = true,
		tub = true,
		litter = true,
		potty = true,
		lures2023normallure = true
	}
	for _, v in ipairs(game.Workspace.HouseInteriors.furniture:GetDescendants()) do
		if v:IsA("Model") then
			local name = v.Name:lower()
			for key in pairs(filter) do
				if name:find(key) then
					local part = v:FindFirstChild("UseBlocks")
					if part then
						part = part:FindFirstChildWhichIsA("Part")
						if part then
							furniture[name] = part
						end
					end
				end
			end
		end
	end
	for k,v in ClientData.get("house_interior")['furniture'] do
		local id = v.id:lower():gsub("_", "")
		local part = furniture[id]
		if part then
			if id:find("bed") or id:find("crib") then 
				furn.bed = {
					id=v.id,
					unique=k,
					usepart=part.Name,
					cframe=part.CFrame
				}
			elseif id:find("shower") or id:find("bathtub") or id:find("tub") then
				furn.bath = {
					id=v.id,
					unique=k,
					usepart=part.Name,
					cframe=part.CFrame
				}
			elseif id:find("litter") or id:find("potty") or id:find("toilet") then
				furn.toilet = {
					id=v.id,
					unique=k,
					usepart=part.Name,
					cframe=part.CFrame
				}
			elseif id:find("lures2023normallure") then
				furn.lurebox = {
					id=v.id,
					unique=k,
					usepart=part.name,
					cframe=part.CFrame
				}
			end
		end
		if furn.bed and furn.bath and furn.toilet and furn.lurebox then break end
	end
	local cframe
	if not furn.bed then
		local result = API["HousingAPI/BuyFurnitures"]:InvokeServer(
			{
				{
					kind = "basicbed",
					properties = {
						cframe = CFrame.new(11.89990234375, 0, -27.10009765625, 1, -3.8213709303294e-15, 8.7422776573476e-08, 3.8213709303294e-15, 1, 0, -8.7422776573476e-08, 0, 1)
					}
				}
			}
		)
		for _,v in ipairs(game.Workspace.HouseInteriors.furniture:GetChildren()) do
			if v:IsA("Folder") then
				local model = v:FindFirstChild("BasicBed")
				if model and model:IsA("Model") then
					local ub = model:FindFirstChild("UseBlocks")
					if ub then
						local part = ub:FindFirstChildWhichIsA("Part")
						if part then 
							cframe = part.CFrame
							break 
						end
					end

				end
			end
 		end
		furn.bed = {
			id="basicbed",
			unique=result["results"][1].unique,
			usepart="Seat1",
			cframe=cframe
		}
	end
	if not furn.bath then
		local result = API["HousingAPI/BuyFurnitures"]:InvokeServer(
			{
				{
					kind = "cheap_pet_bathtub",
					properties = {
						cframe = CFrame.new(31.300048828125, 0, -3.5, 1, -3.8213709303294e-15, 8.7422776573476e-08, 3.8213709303294e-15, 1, 0, -8.7422776573476e-08, 0, 1)
					}
				}
			}
		)
		for _,v in ipairs(game.Workspace.HouseInteriors.furniture:GetChildren()) do
			if v:IsA("Folder") then
				local model = v:FindFirstChild("CheapPetBathtub")
				if model and model:IsA("Model") then
					local ub = model:FindFirstChild("UseBlocks")
					if ub then
						local part = ub:FindFirstChildWhichIsA("Part")
						if part then 
							cframe = part.CFrame
							break 
						end
					end
				end
			end
 		end
		furn.bath = {
			id="cheap_pet_bathtub",
			unique=result["results"][1].unique,
			usepart="UseBlock",
			cframe=cframe
		}
	end
	if not furn.toilet then
		local result = API["HousingAPI/BuyFurnitures"]:InvokeServer(
			{
				{
					kind = "ailments_refresh_2024_litter_box",
					properties = {
						cframe = CFrame.new(3.199951171875, 0, -24.2998046875, 1, -3.8213709303294e-15, 8.7422776573476e-08, 3.8213709303294e-15, 1, 0, -8.7422776573476e-08, 0, 1)
					}
				}
			}
		)
		for _,v in ipairs(game.Workspace.HouseInteriors.furniture:GetChildren()) do
			if v:IsA("Folder") then
				local model = v:FindFirstChild("Toilet")
				if model and model:IsA("Model") then
					local ub = model:FindFirstChild("UseBlocks")
					if ub then
						local part = ub:FindFirstChildWhichIsA("Part")
						if part then 
							cframe = part.CFrame
							break 
						end
					end
				end
			end
 		end
		furn.toilet = {
			id="ailments_refresh_2024_litter_box",
			unique=result["results"][1].unique,
			usepart="Seat1",
			cframe=cframe
		}
	end
	if not furn.lurebox then
		local result = API["HousingAPI/BuyFurnitures"]:InvokeServer(
			{
				{
					kind = "lures_2033_normal_lure",
					properties = {
						cframe = CFrame.new(18.5, 0, -26.400390625, 1, -3.8213709303294e-15, 8.7422776573476e-08, 3.8213709303294e-15, 1, 0, -8.7422776573476e-08, 0, 1)
					}
				}
			}
		)
		for _,v in ipairs(game.Workspace.HouseInteriors.furniture:GetChildren()) do
			if v:IsA("Folder") then
				local model = v:FindFirstChild("Lures2023NormalLure")
				if model and model:IsA("Model") then
					local ub = model:FindFirstChild("UseBlocks")
					if ub then
						local part = ub:FindFirstChildWhichIsA("Part")
						if part then 
							cframe = part.CFrame
							break 
						end
					end
				end
			end
			furn.lurebox = {
				id="lures_2033_normal_lure",
				unique=result["results"][1].unique,
				usepart="UseBlock",
				cframe=cframe
			}
		end
	end
	if not HouseClient.is_door_locked() then
		HouseClient.lock_door()
	end
	colorprint({markup.SUCCESS}, "[+] Furniture init done. Door locked.")
end)()

task.spawn(function() -- optimized
	local part:Part = Instance.new("Part")
	part.Size = Vector3.new(150, 1, 150)
	part.Position = Vector3.new(1000, 20, 1000) 
	part.Name = "FarmPart"
	part.Anchored = true
	part.Parent = game.Workspace
end)

license()
task.spawn(__init)

