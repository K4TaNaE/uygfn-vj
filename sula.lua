if not game:IsLoaded() then
	game.Loaded:Wait()
end

--[[ Lua Stuff ]]
local Queue = {} -- it is reccomended to call every function with pcall or xpcall
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

		__run = function(self) -- start doing tasks.
			self.running = true
			
			local err = function(err)
				print("Error to task\n" .. debug.info(self.__run, "n"), "adding task to end of queue")
				pcall(self:enqueue(self:dequeue(true)))
			end
			
			repeat
				if self.blocked then repeat task.wait(2) until not self.blocked end
				local task = self._data[1]
				print("Current task: " .. task[1])
				
				if task[3] then
					local status, _ = xpcall(task.spawn, err, task[2])
					if status then
						print(`Task {self:dequeue(true)[1]} successfully completed.`)
						task.wait(.5)
					end
				else
					local status, _ = pcall(task.spawn, task[2])
					if status then
						print(`Task {self:dequeue(true)[1]} successfully completed.`)
						task.wait(.5)
					end 
				end
				task.wait(1)
				
			until self.__head > self.__tail
			
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

local farming_pet = nil
local active_ailments = {}
local baby_active_ailments = {}
local total_fullgrowned = {}
local queue = Queue.new()
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
		local pet = PetEntityManager.get_pet_entity(v)	
		if pet.session_memory.meta.owned_by_local_player then
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
		if not get_equiped_pet().unique == farming_pet then
			farmed.eggs_hatched += 1 
			farming_pet = nil 
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
			table.insert(total_fullgrowned, farming_pet)
			update_gui("fullgrown", farmed.pets_fullgrown)
			farming_pet = nil
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
		if not pet or not farming_pet then
			queue:destroy_linked("ailment pet")
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
		if not pet or not farming_pet then
			queue:destroy_linked("ailment pet")
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
		if not pet or not farming_pet then
			queue:destroy_linked("ailment pet")
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
		if not pet or not farming_pet then
			queue:destroy_linked("ailment pet")
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
		if not pet or not farming_pet then
			queue:destroy_linked("ailment pet")
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
		if not Parent or not farming_pet then
			queue:destroy_linked("ailment pet")
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
		if not pet or not farming_pet then
			queue:destroy_linked("ailment pet")
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
		if not pet or not farming_pet then
			queue:destroy_linked("ailment pet")
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
		if not pet or not farming_pet then
			queue:destroy_linked("ailment pet")
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
		if not pet or not farming_pet then
			queue:destroy_linked("ailment pet")
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
		if not pet or not farming_pet then
			queue:destroy_linked("ailment pet")
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
		if not pet or not farming_pet then
			queue:destroy_linked("ailment pet")
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
		if not pet or not farming_pet then
			queue:destroy_linked("ailment pet")
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
		if not pet or not farming_pet then
			queue:destroy_linked("ailment pet")
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
		if not pet or not farming_pet then
			queue:destroy_linked("ailment pet")
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
		if not pet or not farming_pet then
			queue:destroy_linked("ailment pet")
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

baby_ailments = {
	["camping"] = function() 
		local money = ClientData.get("money")
		local timer = 30
		to_mainmap()
		gotovec(-23, 37, -1063)
		while baby_active_ailments.camping and timer > 0 do
			task.wait(1)
			timer -= 1
		end
		if timer == 0 then error("Out of limits") end
		enstat_baby(money, "camping")
	end,
	["hungry"] = function() 
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

		while baby_active_ailments.hungry do
			API["ToolAPI/ServerUseTool"]:InvokeServer(
				inv_get_category_unique("food", "healing_apple"),
				"END"
			)
			task.wait(.1)
		end
		enstat_baby(money, "hungry")  
	end,
	["thirsty"] = function() 
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
		
		while baby_active_ailments.thirsty do
			API["ServerUseTool"]:InvokeServer(
				inv_get_category_unique("food", "water"),
				"END"
			)
			task.wait(.1)
		end
		enstat_baby(money, "thirsty")  
	end,
	["sick"] = function() 
		local money = ClientData.get("money")
		goto("Hospital", "MainDoor")
		API["HousingAPI/ActivateInteriorFurniture"]:InvokeServer(
			"f-14",
			"UseBlock",
			"Yes",
			LocalPlayer.Character
		)
		enstat_baby(money, "sick") 

	end,
	["bored"] = function() 
		local money = ClientData.get("money")
		local timer = 60
		to_mainmap()
		gotovec(-365, 30, -1749)
		while get_baby_ailments().bored and timer > 0 do
			task.wait(1)
			timer -= 1
		end
		if timer == 0 then error("Out of limits") end
		enstat_baby(money, "bored")  
	end,
	["salon"] = function() 
		local money = ClientData.get("money")
		local timer = 60
		goto("Salon", "MainDoor")
		while baby_active_ailments.salon and timer > 0 do
			task.wait(1)
			timer -= 1
		end
		if timer == 0 then error("Out of limits") end
		enstat_baby(money, "salon")  

	end,
	["beach_party"] = function() 
		local money = ClientData.get("money")
		local timer = 60
		to_mainmap()
		gotovec(-596, 27, -1473)
		while baby_active_ailments.beach_party and timer > 0 do
			task.wait(1)
			timer -= 1
		end
		if timer == 0 then error("Out of limits") end
		enstat_baby(money, "beach_party")  

	end,
	["dirty"] = function() 
		local money = ClientData.get("money")
		local timer = 15
		to_home()
		API['HousingAPI/ActivateFurniture']:InvokeServer(
			game.LocalPlayer,
			furn.bath.unique,
			furn.bath.usepart,
			{
				cframe = furn.bath.cframe
			},
			LocalPlayer.Character
		)
		while baby_active_ailments.dirty and timer > 0 do
			task.wait(1)
			timer -= 1
		end
		if timer == 0 then error("Out of limits") end
		enstat_baby(money, "dirty")  
	end,
	["school"] = function() 
		local money = ClientData.get("money")
		local timer = 60
		goto("School", "MainDoor")
		while get_baby_ailments().school and timer > 0 do
			task.wait(1)
			timer -= 1
		end
		if timer == 0 then error("Out of limits") end
		enstat_baby(money, "school")  
	end,
	["sleepy"] = function() 
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
			LocalPlayer.Character
		)
		while baby_active_ailments.sleepy and timer > 0 do
			task.wait(1)
			timer -= 1
		end
		if timer == 0 then error("Out of limits") end
		enstat_baby(money, "sleepy")  
	end,
	["pizza_party"] = function() 
		local money = ClientData.get("money")
		local timer = 60
		goto("PizzaShop", "MainDoor")
		while baby_active_ailments.pizza_party and timer > 0 do
			task.wait(1)
			timer -= 1
		end
		if timer == 0 then error("Out of limits") end
		enstat_baby(money, "pizza_party")  
	end,
}


local function init_autofarm(cat) -- optimized
	local pet = get_equiped_pet()
	if pet then
		API["ToolAPI/Unequip"]:InvokeServer(
			pet.unique,
			{
				use_sound_delay = true,
				equip_as_last = false
			}
		)
	end
	if table.getn(get_owned_pets()) == 0 then
		repeat 
			task.wait(50)
		until table.getn(get_owned_pets()) > 0
	end

	while true do
		local owned_pets = get_owned_pets()
		if _G.InternalConfig.PotionFarm then
			local flag = false
			for k,v in owned_pets do
				if v.age == 6 and not _G.InternalConfig.AutoFarmFilter.PetsToExclude[v.remote] then
					API["ToolAPI/Equip"]:InvokeServer(
						inv_get_category_unique("pets", k),
						{
							use_sound_deulay = true,
							equip_as_last = false
						}
					)
					flag = true		
					break				
				end
			end
			if not flag then
				for k,v in owned_pets do
					if not (v.name:lower()):find("egg") then
						API["ToolAPI/Equip"]:InvokeServer(
							inv_get_category_unique("pets", k),
							{
								use_sound_deulay = true,
								equip_as_last = false
							}
						)
						flag = true
						break
					end
				end
				if not flag then
					for k, _ in owned_pets do
						API["ToolAPI/Equip"]:InvokeServer(
							inv_get_category_unique("pets", k),
							{
								use_sound_deulay = true,
								equip_as_last = false
							}
						)
						break
					end
				end
			end
		else
			if cat == "pets" then			
				for k,v in owned_pets do
					if v.age ~= 6 and not _G.InternalConfig.AutoFarmFilter.PetsToExclude[v.remote] then
						API["ToolAPI/Equip"]:InvokeServer(
							inv_get_category_unique("pets", k),
							{
								use_sound_deulay = true,
								equip_as_last = false
							}
						)
						break
					end
				end
			else 
				for k,v in owned_pets do
					if v.age > 1 and not _G.InternalConfig.AutoFarmFilter.PetsToExclude[v.remote] and (v.name:lower()):find("egg") then
						API["ToolAPI/Equip"]:InvokeServer(
							inv_get_category_unique("pets", k),
							{
								use_sound_delay = true,
								equip_as_last = false
							}
						)
						break
					end
				end
			end
		end 
		while true do
			local curpet = get_equiped_pet()
			if curpet then
				farming_pet = pet.unique
				while farming_pet do 
					local eqpetailms = get_equiped_pet_ailments()
					if eqpetailms then
						for k,v in pet_ailments do 
							if eqpetailms[k] then
								if active_ailments[k] then continue end
								queue:enqueue({"ailment pet", v})
								active_ailments[k] = true
							end
						end
						task.wait(20)
					else
						task.wait(30)
					end
				end
			else
				task.wait(60)
				break
			end
		end
	end
end
	
local function init_baby_autofarm() -- optimized
	API["TeamAPI/ChooseTeam"]:InvokeServer(
		"babies",
		{
			dont_respawn = true,
			source_for_logging = "avatar_editor"
		}
	)
	task.wait(1)
	while true do
		local active_ailments = get_baby_ailments()
		if active_ailments then
			for k,v in baby_ailments do
				if active_ailments[k] then
					if baby_active_ailments[k] then continue end
					baby_active_ailments[k] = true
					queue:enqueue({"ailment baby", v})
				end
			end
			task.wait(30)
		else
			task.wait(30)
		end
	end
end

local function init_auto_buy() -- optimized
	local cost = InventoryDB.pets[_G.InternalConfig.AutoFarmFilter.EggAutoBuy].cost
	if cost then
		while true do
			API["ShopAPI/BuyItem"]:InvokeServer(
				"pets",
				_G.InternalConfig.AutoFarmFilter.EggAutoBuy,
				{
					buy_count = ClientData.get("money") / cost
				}
			)
			task.wait(300)
		end
	else 
		return
	end
end

-- local function init_crystall_auto()
-- 	local pet_exchange_age, pet_exchange_rar
--  	pet_exchange_age = _G.InternalConfig.PetExchangeAge 
-- 	pet_exchange_rar = _G.InternalConfig.PetExchangeRarity


-- end

local function init_auto_trade() -- optimized
	local user = _G.InternalConfig.AutoTradeFilter.PlayerTradeWith 
	local exist = false
	local trade_successed = true
	if game.Players[user] then
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
			player.CharacterRemoving:Wait()
			exist = false
		end
	end)

	while true do 
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
				for k,_ in pets_to_send do 
					API["TradeAPI/AddItemToOffer"]:FireServer(k)
					task.wait(.2)
				end
				repeat 
					API["TradeAPI/AcceptNegotation"]:FireServer()
					task.wait(5)
					API["TradeAPI/ConfirmTrade"]:FireServer()
				until not UIManager.is_visible("TradeApp")
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
			colorprint({markup.ERROR}, "[-] Trade was canceled")
			task.wait(25)
			continue
		else
			if _G.InternalConfig.AutoTradeFilter.WebhookEnabled then
				webhook("TradeLog", `Trade with {user} successed.`)
			end
		end
		task.wait(3600)
	end
end

-- сделать детект предметов которые ты можешшь положить в бокс
local function init_lurebox() -- optimized
	while true do
		API["HousingAPI/ActivateFurniture"]:InvokeServer(
			LocalPlayer,
			furn.lurebox.usepart,
			"UseBlock",
			{
				bait_unique = "2_91644c5593d247da9297c3d05a83cb53"
			},
			LocalPlayer.Character
		)
		task.wait(2)
		local timesleep = nil
		for _,v in ipairs(LocalPlayer.PlayerGui.InteractionsApp.BasicSelects:GetChildren()) do
            if v.Name == "Template" then
                local msg = v:FindFirstChild("Message")
                if not msg then continue end

                local holder = msg:FindFirstChild("FragmentHolder")
                if not holder then continue end

                local lure = holder:FindFirstChild("LuresTimerFragment")
                if not lure then continue end

                local cont = lure:FindFirstChild("Container")
                if not cont then continue end

                local contents = cont:FindFirstChild("Contents")
                if not contents then continue end

                local timer = contents:FindFirstChild("Timer")
                if timer then
                    timesleep = tonumber(timer.Text)
                    break
                end
            end
		end
		timesleep = tonumber(timesleep)
		task.wait((timesleep or 3600) + 5)
		API["HousingAPI/ActivateFurniture"]:InvokeServer(
			LocalPlayer,
			furn.lurebox.unique,
			"UseBlock",
			false,
			LocalPlayer.Character
		)
	end
end

local function init_gift_autoopen() -- optimized
	while true do
		if #get_owned_category("gifts") > 0 then
			repeat task.wait(300) until #get_owned_category("gifts") > 0
		end
		for k,_ in get_owned_category("gifts") do
			game.ReplicatedStorage.API["ShopAPI/OpenGift"]:InvokeServer(k)
			task.wait(0.2)
		end	
	end
end

local function __init() 
	if _G.InternalConfig.FarmPriority == "pets" then
		task.spawn(init_autofarm, "pets")
	elseif _G.InternalConfig.FarmPriority == "eggs" then
		task.spawn(init_autofarm, "eggs")
	end

	task.wait(1)

	if _G.InternalConfig.AutoFarmFilter.EggAutoBuy then
		task.spawn(init_auto_buy)
	end

	task.wait(1)

	if _G.InternalConfig.BabyAutoFarm then
		task.spawn(init_baby_autofarm)
	end

	task.wait(1)

	-- if _G.InternalConfig.CrystallEggFarm then
	-- 	task.spawn(init_crystall_auto)
	-- end

	if _G.InternalConfig.PetAutoTrade then
		task.spawn(init_auto_trade)
	end

	if _G.InternalConfig.DiscordWebhookURL then
		task.spawn(function()
			while true do
				task.wait(_G.InternalConfig.WebhookSendDelay)
				webhook(
					"AutoFarm Log",
					`**💸Money Earned :** {farmed.money}\n\
					**📈Pets Full-grown :** {farmed.pets_fullgrown}\n\
					**🐶Pet Needs Completed :** {farmed.ailments}\n\
					**🧪Potions Farmed :** {farmed.potions}\n\
					**🧸Friendship Levels Farmed :** {farmed.friendship_levels}\n\
					**👶Baby Needs Completed :** {farmed.baby_ailments}\n\
					**🥚Eggs Hatched :** {farmed.eggs_hatched}\
					**📦Found in LureBox :** {farmed.lurebox}`
				)
			end
		end)
	end

	task.wait(1)

	if _G.InternalConfig.LureboxFarm then
		task.spawn(init_lurebox)
	end

	if _G.InternalConfig.GiftsAutoOpen then
		task.spawn(init_gift_autoopen)
	end

end

local function autotutorial() end

local function license() -- optimized 
	if loader("TradeLicenseHelper").player_has_trade_license(LocalPlayer) then
		colorprint({markup.SUCCESS}, "[+] License found")
	else
		colorprint({markup.INFO}, "[?] License not found, trying to get..")
		API["SettingsAPI/SetBooleanFlag"]:FireServer("has_talked_to_trade_quest_npc", true)
		API["TradeAPI/BeginQuiz"]:FireServer()
		task.wait(.2)
		for _,v in ClientData.get("trade_license_quiz_manager").quiz do
			API["TradeAPI/AnswerQuizQuestion"]:FireServer(v.answer)
		end
		colorprint({markup.SUCCESS}, "[+] Successed")
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
				local list = {}
				for _,v in Config.AutoFarmFilter.PetsToExclude do
					if check_remote_existance("pets", v) then
						list[v] = true
					else
						colorprint({markup.ERROR}, `[-] Wrong "{v}" remote name `)
					end
				end
				if #list > 0 then
					_G.InternalConfig.AutoFarmFilter.PetsToExclude = list
				else
					_G.InternalConfig.AutoFarmFilter.PetsToExclude = {}
				end
			else
				error("Wrong datatype of PetsToExclude!")
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
				error("Wrong datatype of PotionFarm!")
			end

			if type(Config.AutoFarmFilter.EggAutoBuy) == "string" then -- AutoFarmFilter / EggAutoBuy
				if not (Config.FarmPriority):match("^%s*$") ~= nil then 
					if check_remote_existance("pets", Config.AutoFarmFilter.EggAutoBuy) then
						_G.InternalConfig.AutoFarmFilter.EggAutoBuy = Config.AutoFarmFilter.EggAutoBuy
					else
						_G.InternalConfig.AutoFarmFilter.EggAutoBuy = false
						colorprint({markup.ERROR}, `[-] Wrong "{Config.AutoFarmFilter.EggAutoBuy}" remote name `)
					end
				else
					_G.InternalConfig.AutoFarmFilter.EggAutoBuy = false
				end
			else
				error("Wrong datatype of EggAutoBuy!")
			end
			
		elseif (Config.FarmPriority):match("^%s*$") ~= nil then 
			_G.InternalConfig.FarmPriority = false
			_G.InternalConfig.AutoFarmFilter.EggAutoBuy = false 
			_G.InternalConfig.AutoFarmFilter.PotionFarm = false 
			_G.InternalConfig.AutoFarmFilter.PetsToExclude = {} 
			
		else 
			error("Wrong FarmPriority value!")
		end
	else  
		error("Wrong datatype of FarmPriority!")
	end

	if type(Config.BabyAutoFarm) == "boolean" then -- babyAutoFarm
		_G.InternalConfig.BabyAutoFarm = Config.BabyAutoFarm
	else
		error("Wrong datatype of BabyAutoFarm!")
	end

	if type(Config.LureboxFarm) == "boolean" then
		_G.InternalConfig.LureboxFarm = Config.LureboxFarm
	else
		error("Wrong datatype of LureboxFarm")
	end

	if type(Config.GiftsAutoOpen) == "boolean" then
		_G.InternalConfig.GiftsAutoOpen = Config.GiftsAutoOpen
	else
		error("Wrong datatype of GiftsAutoOpen")
	end

	if type(Config.CrystalEggFarm) == "boolean" then -- CrystalEggFarm
		if Config.CrystalEggFarm then
			_G.InternalConfig.CrystallEggFarm = true
			if not _G.InternalConfig.FarmPriority then
				_G.InternalConfig.FarmPriority = "pets"				
				if type(Config.AutoFarmFilter.PetsToExclude) == "table" then -- AutoFarmFilter / PetsToExclude
					local list = {}
					for _,v in Config.AutoFarmFilter.PetsToExclude do
						if check_remote_existance("pets", v) then
							list[v] = true
						end
					end
					if #list > 0 then
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
					if not (Config.AutoFarmFilter.EggAutoBuy):match("^%s*$") ~= nil then 
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
				if not (Config.PetExchangeRarity):match("^%s*$") ~= nil then 
					if table.find(possible, Config.PetExchangeRarity) then
						_G.InternalConfig.PetExchangeRarity = Config.PetExchangeRarity
					else
						_G.InternalConfig.PetExchangeRarity = false
					end
				else
					_G.InternalConfig.PetExchangeRarity = false
				end
			else
				error("Wrong datatype of PetExchangeRarity!")
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
				if not (Config.PetExchangeAge):match("^%s*$") ~= nil then 
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
				error("Wrong datatype of PetExchangeAge")
			end
		else 
			_G.InternalConfig.CrystallEggFarm = false
			_G.InternalConfig.PetExchangeAge = false
		end
	else
		error("Wrong datatype of CrystalEggFarm")
	end

	if type(Config.DiscordWebhookURL) == "string" then -- DiscordWebhookURL
		if not (Config.DiscordWebhookURL):match("^%s*$") ~= nil then 
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
		error("Wrong datatype of DiscordWebhookURL")
	end


	if type(Config.PetAutoTrade) == "boolean" then
		_G.InternalConfig.AutoTradeFilter = {}
		if Config.PetAutoTrade then 
			_G.InternalConfig.PetAutoTrade = true	
			if type(Config.AutoTradeFilter.PlayerTradeWith) == "string" then -- PlayerTradeWith
				if not (Config.PlayerTradeWith):match("^%s*$") ~= nil then 
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
						error("Wrong datatype of SendAllType")
					end
					if type(Config.AutoTradeFilter.SendAllFarmed) == "boolean" then
						_G.InternalConfig.AutoTradeFilter.SendAllFarmed = Config.AutoTradeFilter.SendAllFarmed
					else
						error("Wrong datatype of SendAllFarmed")
					end
					if type(Config.AutoTradeFilter.ExcludeFriendly) == "boolean" then
						_G.InternalConfig.AutoTradeFilter.ExcludeFriendly = Config.AutoTradeFilter.ExcludeFriendly
					else
						error("Wrong datatype of ExcludeFriendy")
					end
					if type(Config.AutoTradeFilter.WebhookEnabled) == "boolean" then
						if Config.AutoTradeFilter.WebhookEnabled then
							if _G.DiscordWebhookURL then
								_G.InternalConfig.AutoTradeFilter.WebhookEnabled = true
							else
								_G.InternalConfig.AutoTradeFilter.WebhookEnabled = false
							end
						else
							_G.InternalConfig.AutoTradeFilter.WebhookEnabled = false
						end
					else
						error("Wrong datatype of WebhookEnabled")
					end
					if type(Config.AutoTradeFilter.TradeDelay) == "number" then
						if Config.AutoTradeFilter.TradeDelay >= 1 then
							_G.InternalConfig.AutoTradeFilter.TradeDelay = Config.AutoTradeFilter.TradeDelay
						else
							_G.InternalConfig.AutoTradeFilter.TradeDelay = 40 
							colorprint({markup.WARNING}, "[!] Value of TradeDelay can't be lower than 1. Reseting to 40.")
						end
					else 
						error("Wrong datatype TradeDelay")
					end
				else 
					colorprint({markup.WARNING}, "[!] PlayerTradeWith not specified. PetAutoTrade won't work.")
					_G.InternalConfig.PetAutoTrade = false
					_G.InternalConfig.AutoTradeFilter.PlayerTradeWith = false
					_G.InternalConfig.AutoTradeFilter.SendAllType = false
					_G.InternalConfig.AutoTradeFilter.SendAllFarmed = false
					_G.InternalConfig.AutoTradeFilter.ExcludeFriendly = false
					_G.InternalConfig.AutoTradeFilter.WebhookEnabled = false
					_G.InternalConfig.AutoTradeFilter.TradeDelay = false
				end
			else
				error("Wrong datatype of PlayerTradeWith")
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
		error("Wrong datatype of PetAutoTrade")
	end

	if type(Config.WebhookSendDelay) == "number" then
		if Config.WebhookSendDelay >= 1 then
			_G.InternalConfig.WebhookSendDelay = Config.WebhookSendDelay
		else
			_G.InternalConfig.WebhookSendDelay = 3600
			colorprint({markup.WARNING}, "[!] Value of WebhookSendDelay can't be lower than 1. Reseting to 3600.")
		end
	else
		error("Wrong datatype of WebhookSendDelay")
	end
	task.wait(1)
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
    frame.Size = UDim2.new(0, 250, 0, 220)
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
(function() -- optimized
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
end)

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

