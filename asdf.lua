if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait() 
print("Due to optimization color output is disabled.")
--[[ sUNC ]]--
-- vegax, codex, delta x, xeno, velocity, volcano, yub-x, xenith, bunni, potassium  --- test on this provided sunc below
local cloneref = cloneref or function(obj) return obj end -- potassium, seliware, volcano, delta, bunni, cryptic
local getupvalue = debug.getupvalue -- potassium, seliware, volcano, delta, bunni, cryptix

--[[ Services ]]--
local GuiService = game:GetService("GuiService")
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
	baby_active_ailments = {},
	total_fullgrowned = {}
}
local actual_pet = {
    unique = false,
    remote = false,
    model = false,
    wrapper = false,
    rarity = false,
    is_egg = false,
}
local farmed = {
	money = 0,
	pets_fullgrown = 0,
	ailments = 0,
	potions = 0,
	friendship_levels = 0,
	event_currency = 0,
	baby_ailments = 0,
	eggs_hatched = 0 ,
}
_G.bait_placed = false
local Cooldown = {
	AutoBuyEgg = 0,
	GiftsAutoOpen = 0,
	AutoGivePotion = 0,
	LureboxFarm = 0,
}

local furn = {}
_G.InternalConfig = {}
_G.flag_if_no_one_to_farm = false
_G.CONNECTIONS = {}
_G.CLEANUP_INSTANCES = {}

--[[ Lua Stuff ]]
local Scheduler = {}
Scheduler.tasks = {}

--[[
	**name**: name of task.\
	**interval**: function will run every "interval" secconds -> int.\
	**callback**: function that will be called.\
	**once**: if true will run only once.\
	**now**: if true will run now and every "interval" secconds.\
	**fallback**: function that will be called on error.
]]
function Scheduler:add(name, interval, callback, once, now, fallback)
    self.tasks[name] = {
        interval = interval,
        cb = callback,
        once = once == true,
        next = now == true and os.clock() or (os.clock() + interval),
		running = false, 
        paused = false,
        pause_until = nil,
		fallback = fallback or function() end
    } 
end

function Scheduler:remove(name)
    if self.tasks[name] then
        self.tasks[name] = nil
    end
end

function Scheduler:change_interval(name, interval)
    local t = self.tasks[name]
    if t then
        t.interval = interval
        t.next = os.clock() + interval
    end
end

function Scheduler:resume(name)
    local t = self.tasks[name]
    if not t then return end

    t.paused = false
    t.pause_until = nil
    t.next = os.clock() + t.interval
end

function Scheduler:exists(name) 
	return self.tasks[name] 
end

function Scheduler:waitForCondition(name, condition, onDone, timeout)
    local start = os.clock()
    Scheduler:add(name, 0.2, function()
        if condition() then
            Scheduler:remove(name)
            onDone(true)
            return
        end
        if timeout and os.clock() - start >= timeout then
            Scheduler:remove(name)
            onDone(false) 
        end
    end, false, true)
end

local Queue = {} 
Queue.new = function() 
	return {
		__head = 1,
		__tail = 0,
		_data = {} ,
		running = false,
		blocked = false,

		enqueue = function(self, ttask: table) -- task must be {taskname, callback, rollback}.
			if self.blocked then return end
			if type(ttask) == "table" and type(ttask[1]) == "string" and type(ttask[2]) == "function" then
				ttask.rollback = ttask.rollback or ""
				self.__tail += 1
				self._data[self.__tail] = ttask

				if not self.running then self:__run() end
			end
		end,

		dequeue = function(self,raw)
			if self.__head > self.__tail then return end
			local v = self._data[self.__head]
			self._data[self.__head] = nil
			self.__head += 1
			return v
		end,

		enqblock = function(self)
			self.blocked = true
		end,

		enqunblock = function(self) 
			self.blocked = false
		end,

		destroy_linked = function(self, taskname) 
			if not self:empty() then
				for k,v in ipairs(self._data) do
					if v[1]:match(taskname) then
						table.remove(self._data, k)
						self.__tail -= 1
					end
				end
			end
		end,

		taskdestroy = function(self, pattern1, pattern2) 
			if not self:empty() then 
				for k,v in ipairs(self._data) do
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

		asyncrun = function(self, taskt: table)
			task.spawn(function()
				local ok, err = pcall(taskt[2])
				if not ok then
					warn("Async error:", err)
				end
			end)
		end,

	__run = function(self)
		if self.running then return end
		self.running = true
		local function process_next()
				print("process_next started")
			if self:empty() then
				print("empty")
				self.running = false
				return
			end
			local task = self:dequeue()
			local name = task[1]
			local fn = task[2]
			local ailment = task[3]
			task.spawn(function()
				print("task spawn with name and ailment: ", name, ailment)
				local ok, err = pcall(function()
					fn(function(success)
						print("needed function started")
						if success == false then
							print("succes: false")
							if name == "ailment baby" then
								StateDB.baby_active_ailments[ailment] = nil
							elseif name == "ailment pet" then
								StateDB.active_ailments[ailment] = nil
							end
						end
						print("succces, calling process_next")
						process_next()
					end)
				end)
				if not ok then
					print("not ok")
					warn("Queue error:", name, err)
					if name == "ailment baby" then
						StateDB.baby_active_ailments[ailment] = nil
					elseif name == "ailment pet" then
						StateDB.actiev_ailments[ailment] = nil
					end
					process_next()
				end
			end)
		end
		print('process_next')
		process_next()
	end
    }
end

local queue = Queue.new()

--[[ Helpers ]]-- 
local function temp_platform()
    local old = workspace:FindFirstChild("TempPart")
    if old then old:Destroy() end

    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local part = Instance.new("Part")
    part.Size = Vector3.new(50, 1, 50)
    part.Position = root.Position - Vector3.new(0, 5, 0)
    part.Name = "TempPart"
    part.Anchored = true
    part.Parent = workspace
end

local function get_current_location()
	return InteriorsM.get_current_location()["destination_id"]
end 

local function goto(destId, door, ops, onArrived)
	if get_current_location() == destId then
		if onArrived then onArrived() end
		return
	end
	temp_platform()
	InteriorsM.enter(destId, door, ops or {})
	Scheduler:waitForCondition(
		"goto_await",
		function()
			return get_current_location() == destId
		end,
		function()
			local p = workspace:FindFirstChild("TempPart")
			if p then p:Destroy() end
			if onArrived then
				onArrived()
			end
		end,
		10
	)
end

local function to_neighborhood(onArrived)
	goto("Neighborhood", "MainDoor", nil, onArrived)
end

local function to_home(onArrived) 
	goto("housing", "MainDoor", { house_owner=LocalPlayer }, onArrived)
end

local function to_mainmap(onArrived) 
	goto("MainMap", "Neighborhood/MainDoor", nil, onArrived)
end

local function get_equiped_pet() 
    local wrapper = ClientData.get("pet_char_wrappers")[1]
    if not wrapper then return nil end
    local unique = wrapper.pet_unique
    local remote = wrapper.pet_id
    local inv_pets = ClientData.get("inventory").pets
    local cdata = inv_pets and inv_pets[unique]
    if not cdata then return nil end
    local age = cdata.properties.age
    local friendship = cdata.properties.friendship_level
    local xp = cdata.properties.xp
    local model
    for _, v in ipairs(workspace.Pets:GetChildren()) do
        local entity = PetEntityManager.get_pet_entity(v)
        if entity and entity.session_memory and entity.session_memory.meta.owned_by_local_player then
            model = v
            break
        end
    end
    local pet_info = InventoryDB.pets[remote]
    local rarity = pet_info and pet_info.rarity
    local name = pet_info and pet_info.name
    return {
        remote = remote,
        unique = unique,
        model = model,
        wrapper = wrapper,
        age = age,
        rarity = rarity,
        friendship = friendship,
        xp = xp,
        name = name
    }
end

local function cur_unique()
    local w = ClientData.get("pet_char_wrappers")[1]
    return w and w.pet_unique
end

local function equiped() 
	return ClientData.get("pet_char_wrappers")[1]
end

local function get_owned_pets()
    local inv = ClientData.get("inventory")
    local pets = inv and inv.pets
    if not pets then return {} end
    local result = {}
    for unique, v in pairs(pets) do
        if v.id ~= "practice_dog" then
            local info = InventoryDB.pets[v.id]
            if info then
                result[unique] = {
                    remote = v.id,
                    unique = unique,
                    age = v.properties.age,
                    friendship = v.properties.friendship_level,
                    xp = v.properties.xp,
                    cost = info.cost,
                    name = info.name,
                    rarity = info.rarity,
                    table = v
                }
            end
        end
    end
    return result
end

local function safeInvoke(api, ...)
	local args = { ... }
    local ok, res = pcall(function() return API[api]:InvokeServer(table.unpack(args)) end)
    return ok, res
end

local function safeFire(api, ...)
	local args = { ... }
    local ok = pcall(function() API[api]:FireServer(table.unpack(args)) end)
    return ok
end

local function get_owned_category(category)
    local inv = ClientData.get("inventory")
    local cat = inv and inv[category]
    if not cat then return {} end
    local result = {}
    for unique, v in pairs(cat) do
        result[unique] = { remote = v.id, unique = unique }
    end
    return result
end

local function get_equiped_pet_ailments() -- optimized
	local ailments = {}
	local pet = ClientData.get("pet_char_wrappers")[1]
	if pet then
		local path = ClientData.get("ailments_manager")["ailments"][pet.pet_unique]
		if not path then return nil end
		for k,_ in pairs(path) do
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
	for k, _ in pairs(ClientData.get("ailments_manager")["baby_ailments"]) do
		ailments[k] = true
	end 
	return ailments 
end

local function inv_get_category_remote(category, unique)
    local inv = ClientData.get("inventory")
    local cat = inv and inv[category]
    if not cat then return nil end
    local v = cat[unique]
    return v and v.id or nil
end

local function inv_get_category_unique(category, remote)
    local inv = ClientData.get("inventory")
    local cat = inv and inv[category]
    if not cat then return nil end
    for unique, v in pairs(cat) do
        if v.id == remote then
            return unique
        end
    end
end

local function inv_get_pets_with_rarity(rarity)
    local pets = get_owned_pets()
    local list = {}
    for unique, v in pairs(pets) do
        if v.rarity == rarity then
            list[unique] = { remote = v.remote, unique = unique }
        end
    end
    return list
end

local function inv_get_pets_with_age(age)
    local pets = get_owned_pets()
    local list = {}
    for unique, v in pairs(pets) do
        if v.age == age then
            list[unique] = { remote = v.remote, unique = unique }
        end
    end
    return list
end

local function check_pet_owned(remote)
    local inv = ClientData.get("inventory")
    local pets = inv and inv.pets
    if not pets then return false end
    for _, v in pairs(pets) do
        if v.id == remote then
            return true
        end
    end
    return false
end

local function send_trade_request(user)
    safeFire("TradeAPI/SendTradeRequest", game.Players[user])
    local timer = 120
    local result = nil 
    Scheduler:add("trade_check_"..user, 1, function()
        timer -= 1
        if UIManager.is_visible("TradeApp") then
            result = true
            Scheduler:remove("trade_check_"..user)
            return
        end
        if timer <= 0 then
            result = false
            Scheduler:remove("trade_check_"..user)
            return
        end
    end, false, true)
    -- Scheduler:waitCondition(
    --     "wait_trade_"..user,
    --     function()
    --         return result ~= nil
    --     end,
    --     function()
    --     end,
    --     timer
    -- )
    if result == true then
        return true
    else
        return "No response"
    end
end

local function count_of_product(category, remote)
    local inv = ClientData.get("inventory")
    local cat = inv and inv[category]
    if not cat then return 0 end
    local count = 0
    for _, v in pairs(cat) do
        if v.id == remote then
            count += 1
        end
    end
    return count
end

local function check_remote_existance(category, remote) -- optimized
	return InventoryDB[category][remote] 
end

local function count(t)
	local n = 0
	for _ in pairs(t) do
		n +=1 
	end
	return n
end

-- unit: b, kb, mb, gb
local function get_memory(unit)
    unit = unit:lower()
    local mb = Stats:GetTotalMemoryUsageMb()
    if unit == "b" then
        return mb * 1024 * 1024
    elseif unit == "kb" then
        return mb * 1024
    elseif unit == "mb" then
        return mb
    elseif unit == "gb" then
        return mb / 1024
    end
    return mb
end

local function gotovec(x, y, z, onArrived)
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if Scheduler:exists("gotovec_move") then return end
	Scheduler:add("gotovec_move", 0.1, function()
		if actual_pet.unique and actual_pet.wrapper then
			PetActions.pick_up(actual_pet.wrapper)
		end
		root.CFrame = CFrame.new(x, y, z)
		if actual_pet.model then
			safeFire("AdoptAPI/EjectBaby", actual_pet.model)
		end
	end, true, true)

	Scheduler:waitForCondition(
		"gotovec_wait",
		function()
			return (root.Position - Vector3.new(x, y, z)).Magnitude < 4
		end,
		function(success)
			if success then
				if onArrived then
					onArrived()
				end
			else
				warn("gotovec timeout")
			end
		end,
		5
	)
end

local function webhook(title, description)
    local url = _G.InternalConfig.DiscordWebhookURL
    if not url then return end
	local payload = {
		embeds = {
			{
				title = title,
				description = description,
				color = 0,
				author = {
					name = "Arcanic",
					url = "https://discord.gg/E8BVmZWnHs",
					icon_url = "https://i.imageupload.app/936d8d1617445f2a3fbd.png"
				},
				footer = {
					text = os.date("%d.%m.%Y") .. " " .. os.date("%H:%M:%S")
				}
			}
		},
		username = "Arcanic Farmhook",
		attachments = {}
	}
	pcall(function()
		request({
			Url = url,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(payload)
		})
	end)
end

local function update_gui(label, val: number) -- optimized
    local overlay = CoreGui:FindFirstChild("StatsOverlay")
    if not overlay then return end
    local frame = overlay:FindFirstChild("StatsFrame")
    if not frame then return end
    local lbl = frame:FindFirstChild(label)
    if not lbl then return end
	local prefix = lbl.Text:match("^[^:]+") or lbl.Name
    if prefix then
        lbl.Text = prefix .. ": " .. val
    end
end

local function pet_update()
	local pet = get_equiped_pet()
	actual_pet.unique = pet.unique
	actual_pet.remote = pet.remote
	actual_pet.model = pet.model
	actual_pet.wrapper = pet.wrapper
	actual_pet.rarity = pet.rarity
	actual_pet.is_egg = (pet.name:lower()):match("egg") ~= nil
end

local function enstat(age, friendship, money, ailment)  -- optimized
	task.wait(.5)
	if actual_pet.is_egg then
		task.wait(.5)
		if actual_pet.unique ~= cur_unique() then
			farmed.eggs_hatched += 1 
			farmed.money += ClientData.get("money") - money
			update_gui("eggs", farmed.eggs_hatched)
			update_gui("bucks", farmed.money)
			update_gui("pet_needs", farmed.ailments)
			farmed.ailments += 1
			if not _G.flag_if_no_one_to_farm then 
				actual_pet.unique = nil 
				queue:destroy_linked("ailment pet")
				table.clear(StateDB.active_ailments)
			else
				StateDB.active_ailments[ailment] = nil
				pet_update()
			end
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
		if age < 6 and ClientData.get("pet_char_wrappers")[1].pet_progression.age == 6 then
			farmed.pets_fullgrown += 1
			update_gui("fullgrown", farmed.pets_fullgrown)
			table.insert(StateDB.total_fullgrowned, actual_pet.unique)
		end
		if friendship < ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level then
			farmed.friendship_levels += 1
			farmed.potions += 1
			update_gui("friendship", farmed.friendship_levels)
			update_gui("potions", farmed.potions)
		end
		StateDB.active_ailments[ailment] = nil
	else 
		if ClientData.get("pet_char_wrappers")[1].pet_progression.age == 6 then
			if age < 6 and ClientData.get("pet_char_wrappers")[1].pet_progression.age == 6 then
				farmed.pets_fullgrown += 1
				update_gui("fullgrown", farmed.pets_fullgrown)
				table.insert(StateDB.total_fullgrowned, actual_pet.unique)
				if not _G.flag_if_no_one_to_farm then
					actual_pet.unique = nil
					queue:destroy_linked("ailment pet")
					table.clear(StateDB.active_ailments)
				end
			end
		end
		pcall(function() StateDB.active_ailments[ailment] = nil end)
		if _G.flag_if_no_one_to_farm then
			if friendship < ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level then
				farmed.pets_fullgrown += 1
				farmed.potions += 1
				update_gui("friendship", farmed.friendship_levels)
				update_gui("potions", farmed.potions)
				StateDB.active_ailments[ailment] = nil
			end
		end
	end
	farmed.money += ClientData.get("money") - money
	farmed.ailments += 1
	update_gui("bucks", farmed.money)
	update_gui("pet_needs", farmed.ailments)
end

local function __pet_callback(age, friendship, ailment) 
	task.wait(.5)
	if not _G.InternalConfig.FarmPriority then
		farmed.ailments += 1
		update_gui("pet_needs", farmed.ailments) 
	else
		if actual_pet.is_egg then
			if actual_pet.unique ~= cur_unique() then
				farmed.eggs_hatched += 1 
				update_gui("eggs", farmed.eggs_hatched)
				update_gui("pet_needs", farmed.ailments)
				farmed.ailments += 1
				if not _G.flag_if_no_one_to_farm then 
					actual_pet.unique = nil 
					queue:destroy_linked("ailment pet")
					table.clear(StateDB.active_ailments)
				else
					StateDB.active_ailments[ailment] = nil
				end
				return
			else
				farmed.ailments += 1
				update_gui("pet_needs", farmed.ailments)
				StateDB.active_ailments[ailment] = nil
				return
			end
		end

		if _G.InternalConfig.AutoFarmFilter.PotionFarm then
			if age < 6 and ClientData.get("pet_char_wrappers")[1].pet_progression.age == 6 then
				farmed.pets_fullgrown += 1
				update_gui("fullgrown", farmed.pets_fullgrown)
				table.insert(StateDB.total_fullgrowned, actual_pet.unique)
			end
			if friendship < ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level then
				farmed.friendship_levels += 1
				farmed.potions += 1
				update_gui("friendship", farmed.friendship_levels)
				update_gui("potions", farmed.potions)
			end
			StateDB.active_ailments[ailment] = nil
		else 
			if ClientData.get("pet_char_wrappers")[1].pet_progression.age == 6 then
				if age < 6 and ClientData.get("pet_char_wrappers")[1].pet_progression.age == 6 then
					farmed.pets_fullgrown += 1
					update_gui("fullgrown", farmed.pets_fullgrown)
					table.insert(StateDB.total_fullgrowned, actual_pet.unique)
					StateDB.active_ailments[ailment]=  nil
					if not _G.flag_if_no_one_to_farm then
						actual_pet.unique = nil
						queue:destroy_linked("ailment pet")
						table.clear(StateDB.active_ailments)
					end
				end
			end
			if _G.flag_if_no_one_to_farm then
				if friendship < ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level then
					farmed.pets_fullgrown += 1
					farmed.potions += 1
					update_gui("friendship", farmed.friendship_levels)
					update_gui("potions", farmed.potions)
					StateDB.active_ailments[ailment] = nil
				end
			end
		end
		farmed.ailments += 1
		update_gui("pet_needs", farmed.ailments)
	end
end

local function enstat_baby(money, ailment, pet_has_ailment, petData) -- optimized
	local pet_has_ailment = pet_has_ailment or false
	Scheduler:waitForCondition("enstat_baby_"..tostring(math.random(1,999)), function()
		return money ~= ClientData.get("money")
	end,
	function(success)
		farmed.money += ClientData.get("money") - money 
		farmed.baby_ailments += 1
		StateDB.baby_active_ailments[ailment] = nil
		if pet_has_ailment and equiped() and not has_ailment(ailment) then
			__pet_callback(petData[1], petData[2], ailment)
		end
		update_gui("bucks", farmed.money)
		update_gui("baby_needs", farmed.baby_ailments)
	end,
	3
	)
end

local function __baby_callbak(money, ailment) 
	Scheduler:waitForCondition("__baby_callback_"..tostring(math.random(1,999)), function()
		return money ~= ClientData.get("money") 
	end,
	function(success)
		if _G.InternalConfig.BabyAutoFarm then
			queue:taskdestroy("baby", ailment)
			StateDB.baby_active_ailments[ailment] = nil
		end
		farmed.baby_ailments += 1
		update_gui("baby_needs", farmed.baby_ailments)
	end,
	3
	)
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
		local age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
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
		enstat(age, friendship, money, "camping")
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
		local age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
		if count_of_product("food", "apple") == 0 then
			if money == 0 then 
				print("[!] No money to buy food.") 
				StateDB.active_ailments.hungry = nil 
				return
			end
			if money > 20 then
				safeInvoke("ShopAPI/BuyItem",
					"food",
					"apple",
					{
						buy_count = 20
					}
				)
			else 
				safeInvoke("ShopAPI/BuyItem",
					"food",
					"apple",
					{
						buy_count = money / 2
					}
				)
			end
		end
		local deadline = os.clock() + 10
		safeInvoke("PetObjectAPI/CreatePetObject",
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
		enstat(age, friendship, money, "hungry")  
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
		local age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
		if count_of_product("food", "water") == 0 then
			if money == 0 then 
				print("[!] No money to buy food.") 
				StateDB.active_ailments.thirsty = nil 
				return
			end
			if money > 20 then
				safeInvoke("ShopAPI/BuyItem",
					"food",
					"water",
					{
						buy_count = 20
					}
				)
			else 
				safeInvoke("ShopAPI/BuyItem",
					"food",
					"water",
					{
						buy_count = money / 2
					}
				)
			end
		end
		local deadline = os.clock() + 10
		safeInvoke("PetObjectAPI/CreatePetObject",
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
		enstat(age, friendship, money, "thirsty")  
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
		local age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
		local baby_has_ailment = has_ailment_baby("sick")
		goto("Hospital", "MainDoor")
		repeat 
			safeInvoke("HousingAPI/ActivateInteriorFurniture",
				"f-14",
				"UseBlock",
				"Yes",
				LocalPlayer.Character
			)
			task.wait(1)
		until not has_ailment("sick")
		enstat(age, friendship, money, "sick") 
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
		local age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
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
		enstat(age, friendship, money, "bored")  
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
		local age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
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
		enstat(age, friendship, money, "salon")  
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
		local age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
		gotovec(1000,25,1000)
		task.wait(.3)
		safeInvoke("ToolAPI/Equip", inv_get_category_unique("toys", "squeaky_bone_default"), {})
		local deadline = os.clock() + 25
		repeat 
			safeInvoke("PetObjectAPI/CreatePetObject",
				"__Enum_PetObjectCreatorType_1",
				{
					reaction_name = "ThrowToyReaction",
					unique_id = inv_get_category_unique("toys", "squeaky_bone_default")
				}
			)
			task.wait(5) 
		until not has_ailment("play") or os.clock() > deadline
		task.wait(.3)
		safeInvoke("ToolAPI/Unequip", inv_get_category_unique("toys", "squeaky_bone_default"), {})
        if os.clock() > deadline then 
			StateDB.active_ailments.play = nil
			error("Out of limits") 
		end        
		enstat(age, friendship, money, "play") 
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
		local age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
		to_home()
		safeInvoke('HousingAPI/ActivateFurniture',
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
		enstat(age, friendship, money, "toilet")  
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
		local age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
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
		enstat(age, friendship, money, "beach_party")  
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
		local age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
		local deadline = os.clock() + 60
		gotovec(1000,25,1000)
		safeInvoke("ToolAPI/Equip", inv_get_category_unique("strollers", "stroller-default"), {})
		repeat 
			LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position + LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector * 50)
			LocalPlayer.Character.Humanoid.MoveToFinished:Wait()
			LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector * 50)
			LocalPlayer.Character.Humanoid.MoveToFinished:Wait()			
		until not has_ailment("ride") or os.clock() > deadline
		safeInvoke("ToolAPI/Unequip", inv_get_category_unique("strollers", "stroller-default"), {})
		if os.clock() > deadline then 
			StateDB.active_ailments.ride = nil
			error("Out of limits") 
		end        
		enstat(age, friendship, money, "ride") 
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
		local age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
		to_home()
		safeInvoke('HousingAPI/ActivateFurniture',
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
		enstat(age, friendship, money, "dirty")  
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
		local age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
		local deadline = os.clock() + 60
		gotovec(1000,25,1000)
		safeFire("AdoptAPI/HoldBaby", actual_pet.model)
		repeat
			LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position + LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector * 50)
			LocalPlayer.Character.Humanoid.MoveToFinished:Wait()
			LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector * 50)
			LocalPlayer.Character.Humanoid.MoveToFinished:Wait()				
		until not has_ailment("walk") or os.clock() > deadline
		safeFire("AdoptAPI/EjectBaby", pet.model)
		if os.clock() > deadline then 
			StateDB.active_ailments.walk = nil
			error("Out of limits") 
		end      
		enstat(age, friendship, money, "walk") 
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
		local age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
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
		enstat(age, friendship, money, "school")  
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
		local age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
		to_home()
		safeInvoke('HousingAPI/ActivateFurniture',
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
		enstat(age, friendship, money, "sleepy")  
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
			safeFire("AilmentsAPI/ChooseMysteryAilment",
				actual_pet.unique,
				"mystery",
				1,
				k
			)
			task.wait(1.5) 
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
		local age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
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
		enstat(age, friendship, money, "pizza_party")  
		task.wait(.8)
		if baby_has_ailment and ClientData.get("team") == "Babies" and not has_ailment_baby("pizza_party") then
			__baby_callbak(money, "pizza_party")
		end
	end,
	
	["pet_me"] = function() end,
	["party_zone"] = function() end -- available on admin abuse
}

baby_ailments = {
	["camping"] = function(done) 
		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("camping") then
			done(false)
			return 
		end
		to_mainmap(function() 
			gotovec(-23, 37, -1063, function() 
				local money = ClientData.get("money")
				local pet_has_ailment = has_ailment("camping")
				local age, friendship
				if pet_has_ailment then
					age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
					friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
				end
				Scheduler:waitForCondition(
					"ailment_baby_camping",
					function()
						return not has_ailment_baby("camping")
					end,
					function(success)
						if not success then
							done(false)
							return
						end
						enstat_baby(money, "camping", pet_has_ailment, { age, friendship })
						done(true)
					end,
					60
				)
			end
			)
		end
		)
	end,
	["hungry"] = function(done) 
		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("hungry") then
			done(false)
			return 
		end
		local money = ClientData.get("money")
		if count_of_product("food", "apple") < 3 then
			if money == 0 then 
				print("[-] No money to buy food.") 
				done(false)
				return 
			end
			if money > 20 then
				safeInvoke("ShopAPI/BuyItem",
					"food",
					"apple",
					{
						buy_count = 30
					}
				)
			else
				safeInvoke("ShopAPI/BuyItem",
					"food",
					"apple",
					{
						buy_count = money / 2
					}
				)
			end
		end
		Scheduler:add("ailemnt_baby_hungry_eat", 1, function() 
			if not Scheduler:exists("ailment_baby_hungry_check") then
				Scheduler:waitForCondition("ailment_baby_hungry_check", function() 
						return not has_ailment_baby("hungry")
					end,
					function(success) 
						if not success then
							Scheduler:remove("ailemnt_baby_hungry_eat")
							Scheduler:remove("ailment_baby_hungry_check")
							done(false)
							return
						end
						enstat_baby(money, "hungry")  
						done(true)
						Scheduler:remove("ailemnt_baby_hungry_eat")
						Scheduler:remove("ailment_baby_hungry_check")
					end,
					10
				)
				safeFire("ToolAPI/ServerUseTool",
					inv_get_category_unique("food", "apple"),
					"END"
				)
			end
		end, false, true)
	end,
	["thirsty"] = function(done) 
		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("thirsty") then
			done(false)
			return 
		end
		local money = ClientData.get("money")
		if count_of_product("food", "water") == 0 then
			if money == 0 then 
				print("[!] No money to buy food.") 
				done(false)
				return 
			end			
			if money > 20 then
				safeInvoke("ShopAPI/BuyItem",
					"food",
					"water",
					{
						buy_count = 20
					}
				)
			else 
				safeInvoke("ShopAPI/BuyItem",
					"food",
					"water",
					{
						buy_count = money / 2
					}
				)
			end
		end
		Scheduler:add("ailemnt_baby_thirsty_eat", 1, function() 
			if not Scheduler:exists("ailment_baby_thirsty_check") then
				Scheduler:waitForCondition("ailment_baby_thirsty_check", function() 
						return not has_ailment_baby("thirsty")
					end,
					function(success) 
						if not success then
							Scheduler:remove("ailemnt_baby_thirsty_eat")
							Scheduler:remove("ailment_baby_thirsty_check")
							done(false)
							return
						end
						enstat_baby(money, "thirsty")  
						done(true)
						Scheduler:remove("ailemnt_baby_thirsty_eat")
						Scheduler:remove("ailment_baby_thirsty_check")
					end,
					10
				)
				safeFire("ToolAPI/ServerUseTool",
					inv_get_category_unique("food", "water"),
					"END"
				)
			end
		end, false, true)
	end,
	["sick"] = function(done) 
		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("sick") then
			done(false)
			return 
		end
		goto('Hospital', "MainDoor", function() 
			local money = ClientData.get("money")
			local pet_has_ailment = has_ailment("sick")
			local age, friendship
			if pet_has_ailment then
				age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
				friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
			end
			safeInvoke("HousingAPI/ActivateInteriorFurniture",
				"f-14",
				"UseBlock",
				"Yes",
				LocalPlayer.Character
			)
			Scheduler:waitForCondition("ailment_baby_sick", function()
				return not has_ailment_baby("sick")
			end,
			function(success)
				if not success then
					done(false)
					return
				end
				enstat_baby(money, "sick", pet_has_ailment, { age, friendship }) 
				done(true)
			end,
			5)	
		end)
	end,
	["bored"] = function(done) 
		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("bored") then
			done(false)
			return 
		end
		to_mainmap(function()
			gotovec(-365, 30, -1749, function()
				local money = ClientData.get("money")
				local pet_has_ailment = has_ailment("bored")
				local age, friendship
				if pet_has_ailment then
					age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
					friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
				end
				Scheduler:waitForCondition(
					"ailment_baby_bored",
					function()
						return not has_ailment_baby("bored")
					end,
					function(success)
						if not success then
							done(false)
							return
						end
						enstat_baby(money, "bored", pet_has_ailment, { age, friendship })
						done(true)
					end,
					60
				)
			end)
		end)
	end,
	["salon"] = function(done) 
		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("salon") then
			done(false)
			return 
		end
		goto("Salon", "MainDoor", function()
			local money = ClientData.get("money")
			local pet_has_ailment = has_ailment("salon")
			local age, friendship
			if pet_has_ailment then
				age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
				friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
			end
			Scheduler:waitForCondition(
				"ailment_baby_salon",
				function()
					return not has_ailment_baby("salon")
				end,
				function(success)
					if not success then
						done(false)
						return
					end
					enstat_baby(money, "salon", pet_has_ailment, { age, friendship })
					done(true)
				end,
				60
			)	
		end)
	end,
	["beach_party"] = function(done) 
		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("beach_party") then
			done(false)
			return 
		end
		to_mainmap(function()
			gotovec(-596, 27, -1473, function()
				local money = ClientData.get("money")
				local pet_has_ailment = has_ailment("beach_party")
				local age, friendship
				if pet_has_ailment then
					age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
					friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
				end
				Scheduler:waitForCondition(
					"ailment_baby_beach_party",
					function()
						return not has_ailment_baby("beach_party")
					end,
					function(success)
						if not success then
							done(false)
							return
						end
						enstat_baby(money, "beach_party", pet_has_ailment, { age, friendship })
						done(true)
					end,
					60
				)
			end)
		end)
	end,
	["dirty"] = function(done) 
		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("dirty") then
			done(false)
			return 
		end
		to_home(function()
			local money = ClientData.get("money")
			Scheduler:add("ailment_baby_dirty", 2, function()
				if not Scheduler:exists("ailment_baby_dirty_check") then
					Scheduler:waitForCondition("ailment_baby_dirty_check", function()
						return not has_ailment_baby("dirty")
					end, 
					function(success)
						if not success then
							Scheduler:remove("ailment_baby_dirty")
							Scheduler:remove("ailment_baby_dirty_check")
							StateManagerClient.exit_seat_states()
							done(false)
							return
						end
						enstat_baby(money, "dirty")
						StateManagerClient.exit_seat_states()
						Scheduler:remove("ailment_baby_dirty")
						Scheduler:remove("ailment_baby_dirty_check")
						done(true)
					end,
					20
				)
				end
				safeInvoke('HousingAPI/ActivateFurniture',
					LocalPlayer,
					furn.bath.unique,
					furn.bath.usepart,
					{
						cframe = furn.bath.cframe
					},
					LocalPlayer.Character
				)
			end, false, true)
		end)
	end,
	["school"] = function(done) 
		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("school") then
			done(false)
			return 
		end
		goto("School", "MainDoor", function()
			local money = ClientData.get("money")
			local pet_has_ailment = has_ailment("school")
			local age, friendship
			if pet_has_ailment then
				age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
				friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
			end
			Scheduler:waitForCondition(
				"ailment_baby_school",
				function()
					return not has_ailment_baby("school")
				end,
				function(success)
					if not success then
						done(false)
						return
					end
					enstat_baby(money, "school", pet_has_ailment, { age, friendship })
					done(true)
				end,
				60
			)	
		end)
	end,
	["sleepy"] = function(done) 
		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("sleepy") then
			done(false)
			return 
		end
		to_home(function()
			local money = ClientData.get("money")
			Scheduler:add("ailment_baby_sleepy", 2, function()
				if not Scheduler:exists("ailment_baby_sleepy_check") then
					Scheduler:waitForCondition("ailment_baby_sleepy_check", function()
						return not has_ailment_baby("sleepy")
					end, 
					function(success)
						if not success then
							Scheduler:remove("ailment_baby_sleepy")
							Scheduler:remove("ailment_baby_sleepy_check")
							StateManagerClient.exit_seat_states()
							done(false)
							return
						end
						enstat_baby(money, "sleepy")
						StateManagerClient.exit_seat_states()
						Scheduler:remove("ailment_baby_sleepy")
						Scheduler:remove("ailment_baby_sleepy_check")
						done(true)
					end,
					20
				)
				end
				safeInvoke('HousingAPI/ActivateFurniture',
					LocalPlayer,
					furn.bed.unique,
					furn.bed.usepart,
					{
						cframe = furn.bed.cframe
					},
					LocalPlayer.Character
				)
			end, false, true)
		end)
	end,
	["pizza_party"] = function(done) 
		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("pizza_party") then
			done(false)
			return 
		end
		goto("PizzaShop", "MainDoor", function()
			local money = ClientData.get("money")
			local pet_has_ailment = has_ailment("pizza_party")
			local age, friendship
			if pet_has_ailment then
				age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
				friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
			end
			Scheduler:waitForCondition(
				"ailment_baby_pizza_party",
				function()
					return not has_ailment_baby("pizza_party")
				end,
				function(success)
					if not success then
						done(false)
						return
					end
					enstat_baby(money, "pizza_party", pet_has_ailment, { age, friendship })
					done(true)
				end,
				60
			)	
		end)
	end,
}

local function init_autofarm() -- optimized
	if count(get_owned_pets()) == 0 then
		Scheduler:add("init_autofarm", 15, init_autofarm, true, false)
		return
	end

	local owned_pets = get_owned_pets()
	local flag = false
	
	local pet = ClientData.get("pet_char_wrappers")[1]
	if pet and not _G.flag_if_no_one_to_farm then
		safeInvoke("ToolAPI/Unequip",
			pet.pet_unique,
			{
				use_sound_delay = true,
				equip_as_last = false
			}
		)
	end
	
	local d2kitty = inv_get_category_unique("pets", "2d_kitty")
	if owned_pets[d2kitty] then
		safeInvoke("ToolAPI/Equip",
			d2kitty,
			{
				use_sound_delay = true,
				equip_as_last = false
			}
		)
		if equiped() then 
			flag = true
			_G.flag_if_no_one_to_farm = false
		end
	end

	local function try_equip(check)
        for k,v in pairs(owned_pets) do
            if check(k,v) then
                safeInvoke("ToolAPI/Equip", k, {use_sound_delay = true, equip_as_last = false})
                if equiped() then
                    flag = true
                    _G.flag_if_no_one_to_farm = false
                    return true
                end
            end
        end
        return false
    end

    if _G.InternalConfig.PotionFarm then
        if _G.InternalConfig.FarmPriority == "pets" then
            try_equip(function(k,v) return v.age == 6 and not _G.InternalConfig.AutoFarmFilter.PetsToExclude[v.remote] end)
        else
            local found = try_equip(function(k,v) return (v.name:lower()):find("egg") end)
            if not found then
                try_equip(function(k,v) return true end) 
            end
        end
    else
        if _G.InternalConfig.FarmPriority == "pets" then
            try_equip(function(k,v) return v.age < 6 and not _G.InternalConfig.AutoFarmFilter.PetsToExclude[v.remote] and not (v.name:lower()):match("egg") end)
        else
            try_equip(function(k,v) return not _G.InternalConfig.AutoFarmFilter.PetsToExclude[v.remote] and (v.name:lower()):match("egg") end)
        end
        if not flag and _G.InternalConfig.OppositeFarmEnabled and not _G.flag_if_no_one_to_farm then
            print("No pets to farm depending on config. Trying to detect legendary pet to farm or any..")
            local legendary = try_equip(function(k,v) return v.rarity == "legendary" end)
            if not legendary then
                try_equip(function(k,v) return true end)
                _G.random_farm = true
                _G.flag_if_no_one_to_farm = true
            end
        end
    end

	if not _G.flag_if_no_one_to_farm and _G.random_farm then
		table.clear(StateDB.active_ailments)
		queue:destroy_linked("ailment pet")
		_G.random_farm = false
	end

	if not flag or not equiped() then 
		print("flag: ", flag, "equiped: ", equiped())
		Scheduler:add("init_autofarm", 15, init_autofarm, true, false)
		return
	end
	Scheduler:sleep("init_autofarm", 2)
	pet_update()

	if not Scheduler:exists("init_autofarm_main") then 
		Scheduler:add("init_autofarm_main", 15, function()
		
			if actual_pet.unique ~= cur_unique() or not actual_pet.unique then
				actual_pet.unique = nil
				Scheduler:add("init_autofarm", 15, init_autofarm, true, false)
				return
			end

			local eqpetailms = get_equiped_pet_ailments()
			if not eqpetailms then
				return
			end

			for k,_ in pairs(eqpetailms) do 
				if StateDB.active_ailments[k] then continue end
				if pet_ailments[k] then
					StateDB.active_ailments[k] = true
					if k == "mystery" then 
						queue:asyncrun({"ailment pet", pet_ailments[k]}) 
						continue 
					end
					queue:enqueue({"ailment pet", pet_ailments[k], k})
				end
			end
			if _G.flag_if_no_one_to_farm then
				Scheduler:add("init_autofarm", 15, init_autofarm, true, false)
				return
			end
		end, false, true)
	end
end
	
local function init_baby_autofarm() -- optimized
	if ClientData.get("team") ~= "Babies" then
		safeInvoke("TeamAPI/ChooseTeam",
			"Babies",
			{
				dont_respawn = true,
				source_for_logging = "avatar_editor"
			}
		)
	end	
	if not _G.InternalConfig.FarmPriority then
		local pet = ClientData.get("pet_char_wrappers")[1]
		if pet then
			safeInvoke("ToolAPI/Unequip",
				pet.pet_unique,
				{
					use_sound_delay = true,
					equip_as_last = false
				}
			)
		end
	end
	local active_ailments = get_baby_ailments()
	for k,_ in pairs(active_ailments) do
		if StateDB.baby_active_ailments[k] then continue end
		if baby_ailments[k] then
			StateDB.baby_active_ailments[k] = true
			print("enqueued: ", k)
			queue:enqueue({"ailment baby", baby_ailments[k], k})
		end
	end
	wanr("Currently active")
	for k,v in StateDB.baby_active_ailments do
		print(k,v)
	end
end

local function async_auto_buy() -- optimized
	local cost = InventoryDB.pets[_G.InternalConfig.AutoFarmFilter.EggAutoBuy].cost
	if cost then
		local farmd = farmed.money
		safeInvoke("ShopAPI/BuyItem",
			"pets",
			_G.InternalConfig.AutoFarmFilter.EggAutoBuy,
			{
				buy_count = ClientData.get("money") / cost
			}
		)
		farmed.money = farmd
		Cooldown.AutoBuyEgg = 3600		
	else 
		Cooldown.AutoBuyEgg = math.huge()
	end
end

local function init_auto_recycle()
	local pet_to_exchange = {}
	local owned_pets = get_owned_pets()
	
	if not _G.InternalConfig.PetExchangeRarity then
		for k,v in pairs(owned_pets) do
			if v.age == _G.InternalConfig.PetExchangeAge then
				pet_to_exchange[k] = true
			end
		end
	else
		for k,v in pairs(owned_pets) do
			if v.age == _G.InternalConfig.PetExchangeAge then
				if v.rarity == _G.InternalConfig.PetExchangeRarity then
					pet_to_exchange[k] = true
				end
			end
		end
	end

	safeInvoke("HousingAPI/ActivateInteriorFurniture",
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

	_G.CONNECTIONS.TradePA = game.Players.PlayerAdded:Connect(function(player)
		if player == user then 
			player.CharacterAdded:Wait()
			exist = true 
		end
	end)
	
	_G.CONNECTIONS.TradePR = game.Players.PlayerRemoving:Connect(function(player) 
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
			print("[!] No response.")
			task.wait(_G.InternalConfig.AutoTradeFilter.TradeDelay)
			continue
		else
			local owned_pets = get_owned_pets()
			while UIManager.is_visible("TradeApp") do
				local exclude = {}
				if _G.InternalConfig.AutoTradeFilter.ExcludeFriendly then
					for k,v in pairs(owned_pets) do
						if v.friendship > 0 then
							exclude[k] = true
						end
					end
				end
				if _G.InternalConfig.AutoTradeFilter.ExcludeEggs then
					for k,v in pairs(owned_pets) do
						if (v.name:lower()):match("egg") then 
							exclude[k] = true
						end
					end
				end
				if _G.InternalConfig.AutoTradeFilter.SendAllFarmed then
					for _,v in ipairs(StateDB.total_fullgrowned) do
						if owned_pets[v] and not exclude[v] then
							pets_to_send[v] = true
						end
 					end
				end
				if _G.InternalConfig.AutoTradeFilter.SendAllType then
					if type(_G.InternalConfig.AutoTradeFilter.SendAllType) == "number" then
						for k,_ in pairs(inv_get_pets_with_age(_G.InternalConfig.AutoTradeFilter.SendAllType)) do
							if not pets_to_send[k] and not exclude[k] then
								pets_to_send[k] = true
							end
						end
					else
 						for k,_ in pairs(inv_get_pets_with_rarity(_G.InternalConfig.AutoTradeFilter.SendAllType)) do
							if not pets_to_send[k] and not exclude[k] then
								pets_to_send[k] = true
							end
						end
					end
				end
				if count(pets_to_send) == 0 then
					print("[TradeLog] Internal pet list is empty. Timeout: [3600]s.")
					task.wait(3600)
					continue
				end
				pcall(function()
				for k,_ in pairs(pets_to_send) do 
					safeFire("TradeAPI/AddItemToOffer", k)
					task.wait(.2)
				end
				repeat 
					while UIManager.apps.TradeApp:_get_local_trade_state().current_stage == "negotiation" do
						safeFire("TradeAPI/AcceptNegotiation")
						task.wait(5)
					end
					safeFire("TradeAPI/ConfirmTrade")
					task.wait(5)
				until not UIManager.is_visible("TradeApp")
			end)
			end
		end
		for k,_ in pairs(get_owned_pets()) do
			if pets_to_send[k] then 
				trade_successed = false
				break
			end
		end
		if not trade_successed then
			trade_successed = true
			print("[-] Trade was canceled.")
			task.wait(25)
			continue
		else
			print("[+] Trade successed.")
			if _G.InternalConfig.AutoTradeFilter.WebhookEnabled then
				webhook("TradeLog", `Trade with {user} successed.`)
			end
		end
		task.wait(3600)
	end
end

local function async_lurebox_farm() 

	local function to_home_and_check_bait_placed()
		to_home()
		if not debug.getupvalue(LureBaitHelper.run_tutorial, 11)() then
			safeInvoke("HousingAPI/ActivateFurniture",
				LocalPlayer,
				furn.lurebox.unique,
				"UseBlock",
				{
					bait_unique = inv_get_category_unique("food", "ice_dimension_2025_ice_soup_bait") -- возможно не этот remote
				},
				LocalPlayer.Character
			)
			print("[Lure] Tried to place bait.")
		end

		safeInvoke("HousingAPI/ActivateFurniture",
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

	queue:enqueue{"bait_check", to_home_and_check_bait_placed}
	repeat 
		task.wait(1)		
	until _G.can_proceed
	_G.can_proceed = false
	if not _G.bait_placed then
		print("[Lure] Reward collected.")
	else
		print("[Lure] Next check in [3600]s.")
		Cooldown.LureboxFarm = 3600
	end
end

local function async_gift_autoopen() -- чета тут не так
	if count(get_owned_category("gifts")) < 1 then
		Cooldown.GiftsAutoOpen = 3600
		return
	end
	for k,v in pairs(get_owned_category("gifts")) do
		if k.remote:lower():match("box") or v.remote:lower():match("chest") then
			safeInvoke("LootBoxAPI/ExchangeItemForReward", k.remote,k)
		else
			safeInvoke("ShopAPI/OpenGift", k)
		end
		task.wait(.5) 
	end
	Cooldown.GiftsAutoOpen = 3600 
end

local function async_auto_give_potion()
	
	local function get_potions() 
	local potions = {}
		for k,v in pairs(get_owned_category("food")) do
			if (v.id:lower()):match("potion") then
				table.insert(potions, k)
			end 
		end
		if #potions > 0 then return potions else return nil end
	end

	local pets_to_grow = {}
	local owned_pets = get_owned_pets()
	if _G.InternalConfig.AutoGivePotion ~= "any" then
		for k,_ in ipairs(_G.InternalConfig.AutoGivePotion) do
			local pet = inv_get_category_unique("pets", k)
			if owned_pets[pet] and owned_pets[pet].age < 6 and not (owned_pets[pet].name:lower()):match("egg") then
				pets_to_grow[pet] = true
			end
		end
	else
		for k,v in pairs(owned_pets) do
			if v.age < 6 and not (v.name:lower()):match("egg") then
				pets_to_grow[k] = true
			end
		end
	end
	local equiped_pet
	local potions = get_potions()
	if not potions then 
		Cooldown.AutoGivePotion = 900
		return
	end	
	local first_equiped_pet = ClientData.get("pet_char_wrappers")[1]
	for k,_ in pairs(pets_to_grow) do
		local count_of_potions = #potions
		
		if count_of_potions > 0 then
			equiped_pet = ClientData.get("pet_char_wrappers")[1]
			if equiped_pet then
				safeInvoke("ToolAPI/Unequip",
					equiped_pet.pet_unique,
					{
						use_sound_delay = true,
						equip_as_last = false
					}
				)
				task.wait(1)
				safeInvoke("ToolAPI/Equip",
					k,
					{
						use_sound_delay = true,
						equip_as_last = false
					}
				)
			end
			
			task.wait(1)
			for a,_ in ipairs(potions) do
				local others = {}
				for i, _ in ipairs(potions) do
					for j, p in ipairs(potions) do
						if j ~= i then table.insert(others, p) end
					end
				end
				safeInvoke("PetObjectAPI/CreatePetObject",
					"__Enum_PetObjectCreatorType_2",
					{
						additional_consume_uniques = {
							table.unpack(others)
						},
						pet_unique = k,
						unique_id = a
					}
				)
				task.wait(1)
			end
		end
	end
	task.wait(1)
	safeInvoke("ToolAPI/Equip",
		first_equiped_pet.pet_unique or actual_pet.unique or "",
		{
			use_sound_delay = true,
			equip_as_last = false
		}
	)
	Cooldown.AutoGivePotion = 900
end

local function init_mode() 
	if _G.InternalConfig.Mode == "bot" then
		RunService:Set3dRenderingEnabled(false)
	else
		-- playable optmization
	end
end

local function internal_countdown() 
	while task.wait(1) do
		Cooldown.AutoBuyEgg -= 1
		Cooldown.GiftsAutoOpen -= 1
		Cooldown.AutoGivePotion -= 1
		Cooldown.LureboxFarm -= 1
	end
end

local function optimized_waiting_coroutine() 
	while task.wait(10) do
		if _G.InternalConfig.GiftsAutoOpen then
			if Cooldown.GiftsAutoOpen <= 0 then
				async_gift_autoopen()
			end
		end	
		if _G.InternalConfig.EggAutoBuy then
			if Cooldown.AutoBuyEgg <= 0 then
				async_auto_buy()
			end
		end
		if _G.InternalConfig.LureboxFarm then
			if Cooldown.LureboxFarm <= 0 then 
				async_lurebox_farm()
			end
		end
		if _G.InternalConfig.AutoGivePotion then
			if Cooldown.AutoGivePotion <= 0 then
				async_auto_give_potion()
			end
		end
	end
end

local function __init() 
	if _G.InternalConfig.FarmPriority then
		Scheduler:add("init_autofarm", 15, init_autofarm, true, true)
	end

	if _G.InternalConfig.BabyAutoFarm then
		Scheduler:add("init_baby_autofarm", 15, init_baby_autofarm, false, true)
	end
	-- task.wait(.1)
	-- if _G.InternalConfig.AutoRecyclePet then
	-- 	task.defer(init_auto_recycle)
	-- end
	-- task.wait(.1)
	-- if _G.InternalConfig.PetAutoTrade then
	-- 	task.defer(init_auto_trade)
	-- end
	-- task.wait(.1)
	-- if _G.InternalConfig.DiscordWebhookURL then
	-- 	task.defer(function()
	-- 		while task.wait(1) do
	-- 			task.wait(_G.InternalConfig.WebhookSendDelay)
	-- 			webhook(
	-- 				"AutoFarm Log",
	-- 				`**💸Money Earned :** {farmed.money}\n\
	--    				**📈Pets Full-grown :** {farmed.pets_fullgrown}\n\
	--    				**🐶Pet Needs Completed :** {farmed.ailments}\n\
	--    				**🧪Potions Farmed :** {farmed.potions}\n\
	--    				**🧸Friendship Levels Farmed :** {farmed.friendship_levels}\n\
	--    				**👶Baby Needs Completed :** {farmed.baby_ailments}\n\
	--    				**🥚Eggs Hatched :** {farmed.eggs_hatched}`
	-- 			)
	-- 		end
	-- 	end)
	-- end
	-- task.wait(.1)
	-- task.defer(optimized_waiting_coroutine)
	-- task.wait(4)
	-- if _G.InternalConfig.Mode then
	-- 	task.defer(init_mode)
	-- end

end

local function autotutorial() end

local function license() -- optimized 
	if loader("TradeLicenseHelper").player_has_trade_license(LocalPlayer) then
		print("[+] License found.")
	else
		print("[?] License not found, trying to get..")
		safeFire("SettingsAPI/SetBooleanFlag", "has_talked_to_trade_quest_npc", true)
		safeFire("TradeAPI/BeginQuiz")
		task.wait(.2)
		for _,v in pairs(ClientData.get("trade_license_quiz_manager").quiz) do
			safeFire("TradeAPI/AnswerQuizQuestion", v.answer)
		end
		print("[+] Successed.")
	end
end

--[[ Init ]]--
;(function() -- api deash
	for k, v in pairs(getupvalue(require(ReplicatedStorage.ClientModules.Core:WaitForChild("RouterClient"):WaitForChild("RouterClient")).init, 7)) do
		v.Name = k
	end
	print("[+] API dehashed.")
end)()

_G.CONNECTIONS.Scheduler = RunService.Heartbeat:Connect(function()
    local now = os.clock()
    for name, t in pairs(Scheduler.tasks) do
        if t.paused then
            if t.pause_until and now >= t.pause_until then
                t.paused = false
                t.pause_until = nil
            else
                continue
            end
        end
        if t.running then
            continue
        end
        if now >= t.next then
            t.running = true
            task.spawn(function()
				local ok, err = pcall(function()
					print("called:", name)
					if type(t.cb) == "function" then
						t.cb()
					else
						error("Invalid cb type: " .. typeof(t.cb))
					end
				end)
                if Scheduler.tasks[name] then
                    if t.once then
                        Scheduler.tasks[name] = nil
                    else
                        t.next = os.clock() + t.interval
                        t.running = false
                    end
                end
            end)
        end
    end
end)

local function __CONN_CLEANUP(player)
	if player == LocalPlayer then
		for _, v in pairs(_G.CONNECTIONS) do
			v:Disconnect()
		end
	end
end

_G.CONNECTIONS.BindToClose = game.Players.PlayerRemoving:Connect(__CONN_CLEANUP)

_G.Looping = {}
if not _G.Looping["NetworkHook"] then 
	_G.Looping.NetworkHook = NetworkClient.ChildRemoved:Connect(function() -- network hook
		local send_responce = function()
			return HttpService:RequestAsync({
				Url = "https://pornhub.com",
				Method = "GET"
			})
		end
		Scheduler:add("InternetCheck", 5, function() 
			local success = pcall(send_responce)
			if success then
				Scheduler:remove("InternetCheck")
				TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
			else
				print("[!] No internet, waiting...")
			end
		end, false, true)
	end)
end 

Scheduler:add("gc", 300, function() -- watchdog
	print('watchdog working')
	collectgarbage("step", 260)
end, false, false) 

_G.CONNECTIONS.AntiAFK = LocalPlayer.Idled:Connect(function() -- anti afk
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
						for _,v in ipairs(Config.AutoFarmFilter.PetsToExclude) do
							if check_remote_existance("pets", v) then
								list[v] = true
							else
								print(`[AutoFarmFilter.PetsToExclude] Wrong [{v}] remote name.`)
							end
						end
						if count(list) > 0 then
							_G.InternalConfig.AutoFarmFilter.PetsToExclude = list
						else
							print("[AutoFarmFilter.PetsToExclude] No valid remote names. Option is disabled.")
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
						print(`[AutoFarmFilter.EggAutoBuy] Wrong [{Config.AutoFarmFilter.EggAutoBuy}] remote name. Option is disabled.`)
					end
				else
					_G.InternalConfig.AutoFarmFilter.EggAutoBuy = false
				end
			else
				error("[AutoFarmFilter.EggAutoBuy] Wrong datatype. Exiting.")
			end
			
			if type(Config.AutoFarmFilter.OppositeFarmEnabled) == "boolean" then
				if _G.InternalConfig.FarmPriority then
					_G.InternalConfig.OppositeFarmEnabled = Config.AutoFarmFilter.OppositeFarmEnabled
				else	
					_G.InternalConfig.OppositeFarmEnabled = false
				end
			else
				error("[AutoFarmFilter.OppositeFarmEnabled] Wrong datatype. Exiting.")
			end

		elseif (Config.FarmPriority):match("^%s*$") then 
			_G.InternalConfig.FarmPriority = false
			_G.InternalConfig.AutoFarmFilter.EggAutoBuy = false 
			_G.InternalConfig.AutoFarmFilter.PotionFarm = false 
			_G.InternalConfig.AutoFarmFilter.PetsToExclude = {} 
			_G.InternalConfig.AutoFarmFilter.OppositeFarmEnabled = false
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
							print(`[AutoGivePotion] Wrong [{v}] remote name.`)
						end
					end
					if count(_G.InternalConfig.AutoGivePotion) == 0 then
						print("[AutoGivePotion] No valid remote names. Option is disabled.")
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
					for _,v in ipairs(Config.AutoFarmFilter.PetsToExclude) do
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
			
				if type(Config.AutoFarmFilter.OppositeFarmEnabled) == "boolean" then
					_G.InternalConfig.OppositeFarmEnabled = Config.AutoFarmFilter.OppositeFarmEnabled
				else
					_G.InternalConfig.OppositeFarmEnabled = false
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
					for k,v in pairs(possible) do
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
						for k,v in pairs(possible) do
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
							print("[AutoTradeFilter.TradeDelay] Value of TradeDelay can't be lower than 1. Reseting to 40.")
						end
					else 
						error("[AutoTradeFilter.TradeDelay] Wrong datatype. Exiting.")
					end
				else 
					print("[!] AutoTradeFilter.PlayerTradeWith is not specified. PetAutoTrade won't work.")
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
			print("[!] Value of WebhookSendDelay can't be lower than 1. Reseting to 3600.")
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
	safeInvoke("TeamAPI/ChooseTeam", "Parents", {source_for_logging="intro_sequence"})
	task.wait(1)
	UIManager.set_app_visibility("MainMenuApp", false)
	UIManager.set_app_visibility("NewsApp", false)
	UIManager.set_app_visibility("DialogApp", false)
	task.wait(3)
	safeInvoke("DailyLoginAPI/ClaimDailyReward")
	UIManager.set_app_visibility("DailyLoginApp", false)
	safeFire("PayAPI/DisablePopups")
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
	if not _G.InternalConfig.FarmPriority and not _G.InternalConfig.BabyAutoFarm and not _G.InternalConfig.LureboxFarm then license() __init() return end	
	to_home(function()
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
		for k,v in pairs(ClientData.get("house_interior")['furniture']) do
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
			local result = safeInvoke("HousingAPI/BuyFurnitures",
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
			local result = safeInvoke("HousingAPI/BuyFurnitures",
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
			local result = safeInvoke("HousingAPI/BuyFurnitures",
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
			local result = safeInvoke("HousingAPI/BuyFurnitures",
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
		print("[+] Furniture init done. Door locked.")
		license()
		__init()
	end)
end)()

task.spawn(function() -- optimized
	if game.Workspace:FindFirstChild("FarmPart") then return end
	local part:Part = Instance.new("Part")
	part.Size = Vector3.new(150, 1, 150)
	part.Position = Vector3.new(1000, 20, 1000) 
	part.Name = "FarmPart"
	part.Anchored = true
	part.Parent = game.Workspace
end)

