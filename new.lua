if not game:IsLoaded() then
	game.Loaded:Wait()
end

--[[ Lua Stuff ]]
local Queue = {} 
Queue.new = function() 
	return {
		__head = 1,
		__tail = 0,
		_data = {} ,
		running = false,
		blocked = false,

		enqueue = function(self, task: table) -- task must be {taskname, callback, repeat: boolean}.
			if type(task) == "table" and type(task[1]) == "string" and type(task[2]) == "function" and self.blocked == false then
				self.__tail += 1
				table.insert(self._data, self.__tail, task)

				if not self.running then self:__run() end
			end
		end,

		dequeue = function(self,raw)
			if self.__head > self.__tail then
				error() 
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

		-- gettask = function(self, nameindex: number) -- name or index
		-- 	for k,v in pairs(self._data) do
		-- 		if (self._data[nameindex] and type(nameindex) == "number") or (self._data[k][1] == nameindex) then
		-- 			return { 
		-- 				position = if type(nameindex) == "number" then 
		-- 					nameindex
		-- 				else
		-- 					v[1],
		-- 				name = if type(nameindex) == "number" then 
		-- 						self._data[nameindex][1] 
		-- 					elseif self._data[k][1] == nameindex then
		-- 						self._data[k][1]
		-- 					else nil,
								
		-- 				callback = if type(nameindex) == "number" then 
		-- 						self._data[nameindex][2] 
		-- 					elseif self._data[k][2] == nameindex then
		-- 						self._data[k][2] 
		-- 					else nil
		-- 				}
		-- 		else
		-- 			return nil
		-- 		end
		-- 	end
		-- end,

		-- enqueue_important = function() end, -- добавляет задачу в начало очереди потомучто ее надо выполнить срочно

		-- export = function(self, fetch:boolean) -- перенос фукнций в другую очередь
		-- 	local tasks = {}
		-- 	if self:empty() then return nil end
		-- 	for i = self.__tail, 0, -1 do 
		-- 		local task = self:gettask(i)
		-- 		table.insert(tasks, i, table.pack(task.name, task.callback))
		-- 		if fetch then 
		-- 			self:dequeue()
		-- 		end
		-- 	end
		-- 	return tasks 
		-- end,

		-- import = function(self, tasktable, replace:boolean) 
		-- 	if replace then self:clear() end 
		-- 	for _, v in tasktable do
		-- 		self:enqueue(v)
		-- 	end
		-- end,
			
		-- pause = function(self) 			
		-- 	self:enqblock()
		-- 	return self:export(true)
		-- end,


		-- set_task_position = function(self, taskplace, endtaskplace): boolean
		-- 	if self._data[taskplace] and self._data[endtaskplace] then
		-- 		if taskplace == 1 or endtaskplace == 1 then
		-- 			error()
		-- 		end
		-- 		local first = table.clone(self._data[taskplace])
		-- 		local last = table.clone(self._data[endtaskplace]) 
		-- 		self._data[taskplace] = last
		-- 		self._data[endtaskplace] = first
		-- 	end
		-- end,

		destroy_linked = function(self, taskname) 
			if not self:empty() then
				for k,v in self._data do
					if v[1] == taskname then
						table.remove(self._data, k)
						self.__tail -= 1
					end
				end
			end
		end,

		-- size = function(self)
		-- 	return self.__tail
		-- end,

		-- clear = function(self)
		-- 	 table.clear(self._data)
		-- 	 self.__tail = 0
		-- end,

		empty = function(self)
			return self.__head > self.__tail
		end,

		__run = function(self)
			self.running = true

			local function onTaskError(errMsg)
				pcall(function()
					local failed = self:dequeue(true)
					self:enqueue(failed)
				end)
			end

			while self.__head <= self.__tail do
				if self.blocked then
					repeat task.wait(0.1) until not self.blocked
				end

				local taskData = self._data[self.__head]
				if not taskData then
					break
				end

				local name = taskData[1]
				local callback = taskData[2]

				print("Current task:", name)

				task.spawn(function()
					local ok, errMsg = xpcall(callback, debug.traceback)

					if ok then
						local finished = self:dequeue(true)
					else
						onTaskError(errMsg)
					end
				end)

				task.wait(0.5)
			end

			self.running = false
		end
	}
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

--[[ Adopt stuff ]]--
local loader = require(ReplicatedStorage.Fsys).load
local UIManager = loader("UIManager")
local ClientData = loader("ClientData")
local InventoryDB = loader("InventoryDB")
local PetEntityManager = loader("PetEntityManager")
local InteriorsM = loader("InteriorsM")
local API = ReplicatedStorage.API
-- local Router = loader("")

_G.farming_pet = nil
local active_ailments = {}
local baby_active_ailments = {}
local total_fullgrowned = {}
getgenv().queue = Queue.new()
local farmed = {
	money = 0,
	pets_fullgrown = 0,
	ailments = 0,
	potions = 0,
	friendship_levels = 0,
	event_currency = 0,
	baby_ailments = 0,
	eggs_hatched = 0,
	lurebox = {}
}

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
		task.wait()
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
		task.wait()
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
		task.wait()
	end
	game.Workspace:FindFirstChild("TempPart"):Destroy()
	task.wait(.5)
end

local function goto(destId, door, ops:table) -- optimized
	if get_current_location() == destId then return end
	temp_platform()
	InteriorsM.enter(destId, door, ops or {})
	while not get_current_location() == destId do
		task.wait()
	end
	game.Workspace:FindFirstChild("TempPart"):Destroy()
	task.wait(.5)
end

local function get_equiped_pet() -- not optimzed
	local remote, unique, model, age, rarity, friendship, xp
	local data = {}
	local wrapper = ClientData.get("pet_char_wrappers")[1]
	if not wrapper then return nil end
	remote = wrapper["pet_id"] 
	unique = wrapper["pet_unique"]
	local cdata = ClientData.get("inventory").pets[unique]
	if cdata then
		age = cdata.properties.age
		rarity = cdata.properties.rarity
		friendship = cdata.properties.friendship_level
		xp = cdata.properties.xp
	end
	for _,v in ipairs(game.Workspace.Pets:GetChildren()) do
		if PetEntityManager.get_pet_entity(v).session_memory.meta.owned_by_local_player then
			model = v
		end
	end
	data.remote = remote; data.unique = unique; data.model = model; data.wrapper = wrapper; 
	data.age = age; data.rarity = rarity; data.friendship = friendship; data.xp = xp
 	return data
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
			cost=cost,name=name,rarity=rarity
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
	local pet = get_equiped_pet()
	if pet then
		for k,_ in ClientData.get("ailments_manager")["ailments"][pet.unique] do
			table.insert(ailments, k)
		end
	else
		return nil
	end
	return ailments
end

local function get_baby_ailments() -- optimized
	local ailments = {}
	for k, _ in ClientData.get("ailments_manager")["baby_ailments"] do
		table.insert(ailments, k)
	end 
    if #ailments == 0 then return nil end
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

local function gotovec(x:number, y:number, z:number) -- optimized
	if get_equiped_pet() then
		API["AdoptAPI/HoldBaby"]:FireServer(get_equiped_pet().model)
		task.wait(.1)
		game.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(x,y,z)
		task.wait(.1)
		API["AdoptAPI/EjectBaby"]:FireServer(get_equiped_pet().model)
	else
		game.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(x,y,z)
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

local function enstat(xp, friendship, money, ailment)  -- optimized
	if _G.InternalConfig.FarmPriority == "eggs" then
		if not get_equiped_pet().unique == _G.farming_pet then
			farmed.eggs_hatched += 1 
			_G.farming_pet = nil 
			queue:destroy_linked("ailment pet")
			table.clear(active_ailments)
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
			active_ailments[ailment] = nil
			return
		end
	end

	if _G.InternalConfig.AutoFarmFilter.PotionFarm then
		if friendship < get_equiped_pet().friendship then
			farmed.friendship_levels += 1
			farmed.potions += 1
			table.clear(active_ailments)
			update_gui("friendship", farmed.friendship_levels)
			update_gui("potions", farmed.potions)
		else
			active_ailments[ailment] = nil
		end
	else 
		if xp >= xp_thresholds[get_equiped_pet().rarity][6] then
			farmed.pets_fullgrown += 1
			table.insert(total_fullgrowned, _G.farming_pet)
			update_gui("fullgrown", farmed.pets_fullgrown)
			_G.farming_pet = nil
			table.clear(active_ailments)
			queue:destroy_linked("ailment pet")
		else
			active_ailments[ailment] = nil
		end
	end
	farmed.money += ClientData.get("money") - money
	farmed.ailments += 1
	update_gui("bucks", farmed.money)
	update_gui("pet_needs", farmed.ailments)
end

local function enstat_baby(money, ailment) -- optimized
	farmed.money += ClientData.get("money") - money 
	farmed.baby_ailments += 1
	baby_active_ailments[ailment] = nil
	update_gui("bucks", farmed.money)
	update_gui("baby_needs", farmed.ailments)
end

local pet_ailments = { 
	["camping"] = function()
		local pet = get_equiped_pet() 
		if not pet or not _G.farming_pet then
			queue:destroy_linked("ailment pet")
			_G.farming_pet = nil
			table.clear(active_ailments)
			return 
		end
		local xp = pet.xp
		local friendship = pet.friendship
		local money = ClientData.get("money")
		local timer = 30
		to_mainmap()
		gotovec(-23, 37, -1063)
		while active_ailments.camping and timer > 0 do
			task.wait(1)
			timer -= 1
		end
		if timer == 0 then error("Out of limits") end
		enstat(xp, friendship, money, "camping")
	end,
	["hungry"] = function() 
		local pet = get_equiped_pet() 
		if not pet or not _G.farming_pet then
			queue:destroy_linked("ailment pet")
			_G.farming_pet = nil
			table.clear(active_ailments)
			return 
		end
		local xp = pet.xp
		local friendship = pet.friendship
		local money = ClientData.get("money")
		if count_of_product("food", "healing_apple") == 0 then
			local money = ClientData.get("money") 
			if money == 0 then colorprint({markup.ERROR}, "[-] No money to buy food") return end
			if money > 20 then
				API["ShopAPI/BuyItem"]:InvokeServer(
					"food",
					"healing_apple",
					{
						buy_count = 20
					}
				)
			else 
				API["ShopAPI/BuyItem"]:InvokeServer(
					"food",
					"healing_apple",
					{
						buy_count = money
					}
				)
			end
		end
		API["PetObjectAPI/CreatePetObject"]:InvokeServer(
			"__Enum_PetObjectCreatorType_2",
			{
				additional_consume_uniques={},
				pet_unique = pet.unique,
				unique_id = inv_get_category_unique("food", "healing_apple")
			}
		)
		while active_ailments.hungry do
			task.wait(1)
		end
		enstat(xp, friendship, money, "hungry")  
	end,
	["thirsty"] = function() 
		local pet = get_equiped_pet() 
		if not pet or not _G.farming_pet then
			queue:destroy_linked("ailment pet")
			_G.farming_pet = nil
			table.clear(active_ailments)
			return 
		end
		local xp = pet.xp
		local friendship = pet.friendship
		local money = ClientData.get("money")
		if count_of_product("food", "water") == 0 then
			local money = ClientData.get("money") 
			if money == 0 then colorprint({markup.ERROR}, "[-] No money to buy food") return end
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
						buy_count = money
					}
				)
			end
		end
		API["PetObjectAPI/CreatePetObject"]:InvokeServer(
			"__Enum_PetObjectCreatorType_2",
			{
				additional_consume_uniques={},
				pet_unique = pet.unique,
				unique_id = inv_get_category_unique("food", "water")
			}
		)
		while active_ailments.thirsty do
			task.wait(1)
		end
		enstat(xp, friendship, money, "thirsty")  
	end,
	["sick"] = function() 
		local pet = get_equiped_pet() 
		if not pet or not _G.farming_pet then
			queue:destroy_linked("ailment pet")
			_G.farming_pet = nil
			table.clear(active_ailments)
			return 
		end
		local xp = pet.xp
		local friendship = pet.friendship
		local money = ClientData.get("money")
		goto("Hospital", "MainDoor")
		API["HousingAPI/ActivateInteriorFurniture"]:InvokeServer(
			"f-14",
			"UseBlock",
			"Yes",
			LocalPlayer.Character
		)
		enstat(xp, friendship, money, "sick") 
	end,
	["bored"] = function() 
		local pet = get_equiped_pet() 
		if not pet or not _G.farming_pet then
			queue:destroy_linked("ailment pet")
			_G.farming_pet = nil
			table.clear(active_ailments)
			return 
		end
		local xp = pet.xp
		local friendship = pet.friendship
		local money = ClientData.get("money")
		local timer = 60
		to_mainmap()
		gotovec(-365, 30, -1749)
		while active_ailments.bored and timer > 0 do
			task.wait(1)
			timer -= 1
		end
		if timer == 0 then error("Out of limits") end
		enstat(xp, friendship, money, "bored")  
	end,
	["salon"] = function() 
		local pet = get_equiped_pet() 
		if not pet or not _G.farming_pet then
			queue:destroy_linked("ailment pet")
			_G.farming_pet = nil
			table.clear(active_ailments)
			return 
		end
		local xp = pet.xp
		local friendship = pet.friendship
		local money = ClientData.get("money")
		local timer = 60
		goto("Salon", "MainDoor")
		while active_ailments.salon and timer > 0 do
			task.wait(1)
			timer -= 1
		end
		if timer == 0 then error("Out of limits") end
		enstat(xp, friendship, money, "salon")  
	end,
	["play"] = function() -- improve. add something without task.wait
		local pet = get_equiped_pet() 
		if not pet or not _G.farming_pet then
			queue:destroy_linked("ailment pet")
			_G.farming_pet = nil
			table.clear(active_ailments)
			return 
		end
		local xp = pet.xp
		local friendship = pet.friendship
		local money = ClientData.get("money")
		API["ToolAPI/Equip"]:InvokeServer("2_48207a6d86754985a58ee57c758331de", {})
		while get_equiped_pet_ailments().play do
			API["PetObjectAPI/CreatePetObject"]:InvokeServer(
				"__Enum_PetObjectCreatorType_1",
				{
					reaction_name = "ThrowToyReaction",
					unique_id = "2_48207a6d86754985a58ee57c758331de"
				}
			)
			task.wait(5) 
		end
		enstat(xp, friendship, money, "play") 
	end,
	["toilet"] = function() 
		local pet = get_equiped_pet() 
		if not pet or not _G.farming_pet then
			queue:destroy_linked("ailment pet")
			_G.farming_pet = nil
			table.clear(active_ailments)
			return 
		end
		local xp = pet.xp
		local friendship = pet.friendship
		local money = ClientData.get("money")
		local timer = 15
		to_home()
		API['HousingAPI/ActivateFurniture']:InvokeServer(
			LocalPlayer,
			furn.toilet.unique,
			furn.toilet.usepart,
			{
				cframe = furn.toilet.cframe
			},
			pet.model
		)
		while active_ailments.toilet and timer > 0 do
			task.wait(1)
			timer -= 1
		end
		if timer == 0 then error("Out of limits") end
		enstat(xp, friendship, money, "toilet")  
	end,
	["beach_party"] = function() 
		local pet = get_equiped_pet() 
		if not pet or not _G.farming_pet then
			queue:destroy_linked("ailment pet")
			_G.farming_pet = nil
			table.clear(active_ailments)
			return 
		end
		local xp = pet.xp
		local friendship = pet.friendship
		local money = ClientData.get("money")
		local timer = 60
		to_mainmap()
		gotovec(-596, 27, -1473)
		while active_ailments.beach_party and timer > 0 do
			task.wait(1)
			timer -= 1
		end
		if timer == 0 then error("Out of limits") end
		enstat(xp, friendship, money, "beach_party")  
	end,
	["ride"] = function()
		local pet = get_equiped_pet() 
		if not pet or not _G.farming_pet then
			queue:destroy_linked("ailment pet")
			_G.farming_pet = nil
			table.clear(active_ailments)
			return 
		end
		local xp = pet.xp
		local friendship = pet.friendship
		local money = ClientData.get("money")
		gotovec(1000,25,1000)
		API["ToolAPI/Equip"]:InvokeServer(inv_get_category_unique("strollers", "stroller-default"), {})
		while active_ailments.ride do
			LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position + LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector * 50)
			LocalPlayer.Character.Humanoid.MoveToFinished:Wait()
			LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector * 50)
			LocalPlayer.Character.Humanoid.MoveToFinished:Wait()
		end
		API["ToolAPI/Unequip"]:InvokeServer(inv_get_category_unique("strollers", "stroller-default"), {})
		enstat(xp, friendship, money, "ride") 
	end,
	["dirty"] = function() 
		local pet = get_equiped_pet() 
		if not pet or not _G.farming_pet then
			queue:destroy_linked("ailment pet")
			_G.farming_pet = nil
			table.clear(active_ailments)
			return 
		end
		local xp = pet.xp
		local friendship = pet.friendship
		local money = ClientData.get("money")
		local timer = 15
		to_home()
		API['HousingAPI/ActivateFurniture']:InvokeServer(
			LocalPlayer,
			furn.bath.unique,
			furn.bath.usepart,
			{
				cframe = furn.bath.cframe
			},
			pet.model
		)
		while active_ailments.dirty and timer > 0 do
			task.wait(1)
			timer -= 1
		end
		if timer == 0 then error("Out of limits") end
		enstat(xp, friendship, money, "dirty")  
	end,
	["walk"] = function() 
		local pet = get_equiped_pet() 
		if not pet or not _G.farming_pet then
			queue:destroy_linked("ailment pet")
			_G.farming_pet = nil
			table.clear(active_ailments)
			return 
		end
		local xp = pet.xp
		local friendship = pet.friendship
		local money = ClientData.get("money")
		gotovec(1000,25,1000)
		while active_ailments.walk do 
			LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position + LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector * 50)
			LocalPlayer.Character.Humanoid.MoveToFinished:Wait()
			LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector * 50)
			LocalPlayer.Character.Humanoid.MoveToFinished:Wait()
		end
		enstat(xp, friendship, money, "walk") 
	end,
	["school"] = function() 
		local pet = get_equiped_pet() 
		if not pet or not _G.farming_pet then
			queue:destroy_linked("ailment pet")
			_G.farming_pet = nil
			table.clear(active_ailments)
			return 
		end
		local xp = pet.xp
		local friendship = pet.friendship
		local money = ClientData.get("money")
		local timer = 60
		goto("School", "MainDoor")
		while active_ailments.school and timer > 0 do
			task.wait(1)
			timer -= 1
		end
		if timer == 0 then error("Out of limits") end
		enstat(xp, friendship, money, "school")  
	end,
	["sleepy"] = function()
		local pet = get_equiped_pet() 
		if not pet or not _G.farming_pet then
			queue:destroy_linked("ailment pet")
			_G.farming_pet = nil
			table.clear(active_ailments)
			return 
		end
		local xp = pet.xp
		local friendship = pet.friendship
		local money = ClientData.get("money")
		local timer = 20
		to_home()
		API['HousingAPI/ActivateFurniture']:InvokeServer(
			LocalPlayer,
			furn.bed.unique,
			furn.bed.usepart,
			{
				cframe = furn.bed.cframe
			},
			pet.model
		)
		while active_ailments.sleepy and timer > 0 do
			task.wait(1)
			timer -= 1
		end
		if timer == 0 then error("Out of limits") end
		enstat(xp, friendship, money, "sleepy")  
	end,
	["mystery"] = function() 
		local pet = get_equiped_pet()
		if not pet or not _G.farming_pet then
			queue:destroy_linked("ailment pet")
			_G.farming_pet = nil
			table.clear(active_ailments)
			return 
		end
		for k,_ in loader("new:AilmentsDB") do
		API["AilmentsAPI/ChooseMysteryAilment"]:FireServer(
			pet.unique,
			"mystery",
			1,
			k
		)
		end				
	end,
	["pizza_party"] = function() 
		local pet = get_equiped_pet() 
		if not pet or not _G.farming_pet then
			queue:destroy_linked("ailment pet")
			_G.farming_pet = nil
			table.clear(active_ailments)
			return 
		end
		local xp = pet.xp
		local friendship = pet.friendship
		local money = ClientData.get("money")
		local timer = 60
		goto("PizzaShop", "MainDoor")
		while active_ailments.pizza_party and timer > 0 do
			task.wait(1)
			timer -= 1
		end
		if timer == 0 then error("Out of limits") end
		enstat(xp, friendship, money, "pizza_party")  
	end,
	
	["pet_me"] = function() end,
	["party_zone"] = function() end -- available on admin abuse
}
;(function() -- api deash
	colorprint({markup.INFO}, "[?] Starting..")
	for k, v in pairs(getupvalue(require(ReplicatedStorage.ClientModules.Core:WaitForChild("RouterClient"):WaitForChild("RouterClient")).init, 7)) do
		v.Name = k
	end
	colorprint({markup.SUCCESS}, "[+] API dehashed.")
end)()


-- launch screen
;(function() -- optmized
	API["TeamAPI/ChooseTeam"]:InvokeServer("Parents", {source_for_logging="intro_sequence"})
	task.wait(1)
	UIManager.set_app_visibility("MainMenuApp", false)
	UIManager.set_app_visibility("NewsApp", false)
	UIManager.set_app_visibility("DialogApp", false)
	task.wait(3)
	API["DailyLoginAPI/ClaimDailyReward"]:InvokeServer()
	UIManager.set_app_visibility("DailyLoginApp", false)
	API["PayAPI/DisablePopups"]:FireServer()
	repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart
	task.wait(.5)
end)()

-- stats gui
task.spawn(function() -- optimized
	local gui = Instance.new("ScreenGui") 
	gui.Name = "StatsOverlay" 
	gui.ResetOnSpawn = false 
	gui.Parent = CoreGui

    local frame = Instance.new("Frame")
    frame.Name = "StatsFrame"
    frame.Size = UDim2.new(0, 250, 0, 200)
    frame.Position = UDim2.new(0, 5, 0, 5)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.3
    frame.Parent = gui

    local function createLabel(name, text, order, postfix)
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
    createLabel("lurebox", "📦Found in lurebox", 7)
end) 


-- furniture init
;(function() -- optimized
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

	colorprint({markup.SUCCESS}, "[+] Furniture init done")
end)()
