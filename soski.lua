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
	total_fullgrowned = {},
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
	eggs_hatched = 0,
}
local Cooldown = {
    init_autofarm = 0,
	init_baby_autofarm = 0,
	init_auto_buy = 0,
	init_auto_recycle = 0,
	init_auto_trade = 0,
	init_lurebox_farm = 0,
	init_gift_autoopen = 0,
	init_auto_give_potion = 0,
	watchdog = 0,
}
local PetPotionsNeedRarity = {
	common = 1,
	uncommon = 2,
	rare = 3,
	ultra_rare = 4,
	legendary = 7,
}
local TASKS_BY_RARITY = {
    common = 25,
    uncommon = 36,
    rare = 54,
    ultra_rare = 107,
    legendary = 183
}
local furn = {}
local accumulator = 0

_G.InternalConfig = {}
_G.flag_if_no_one_to_farm = false
_G.CONNECTIONS = {}
_G.CLEANUP_INSTANCES = {}
_G.HeadCashed = nil

--[[ Lua Stuff ]]
local Queue = {} 
Queue.new = function() 

	return {
		__head = 1,
		__tail = 0,
		_data = {} ,
		running = false,
		blocked = false,


		enqueue = function(self, ttask: table) -- task must be {taskname, callback}.

			if self.blocked then return end

			if type(ttask) == "table" and type(ttask[1]) == "string" and type(ttask[2]) == "function" then
				self.__tail += 1
				self._data[self.__tail] = ttask

				if not self.running then self:__run() end
			end

		end,


		dequeue = function(self)

			if self.__head > self.__tail then return end

			self:enqunblock()

			local v = self._data[self.__head]

			self._data[self.__head] = nil
			self.__head += 1

			self:enqblock()

			return v

		end,


		enqblock = function(self)

			self.blocked = true

		end,


		enqunblock = function(self) 

			self.blocked = false

		end,


		destroy_linked = function(self, taskname)

			if self.__head <= self.__tail then
				for i = self.__tail, self.__head, -1 do
					local v = self._data[i]

					if v and v[1]:match(taskname) then
						self._data[i] = nil

						if i == self.__tail then
							while self.__tail >= self.__head and self._data[self.__tail] == nil do
								self.__tail -= 1
							end
						end
					end
				end
			end

		end,


		taskdestroy = function(self, pattern1, pattern2)

			if self.__head <= self.__tail then
				for i = self.__tail, self.__head, -1 do
					local v = self._data[i]

					if v and v[1]:match(pattern1) and v[1]:match(pattern2) then
						self._data[i] = nil

						if i == self.__tail then
							while self.__tail >= self.__head and self._data[self.__tail] == nil do
								self.__tail -= 1
							end
						end
					end
				end
			end

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

			self.running = true

			while self.__head <= self.__tail do
				local dtask = self._data[self.__head]
				print("dtask:", dtask)

				if not dtask then
					self.__head += 1
					continue
				end

				local name = dtask[1] 
				local callback = dtask[2]
				local ev = Instance.new("BindableEvent")
				local fired = false


				local function sfire()
					
					if not fired then
						fired = true
						ev:Fire()
					end

				end


				task.spawn(function()
					print("task started", name)
					local ok, err = xpcall(function()
						callback(sfire)
					end, debug.traceback)

					if not ok then
						warn("Task failed:", err)

						local spl = name:split(": ")
						local tag = spl[1]
						local ail = spl[2]

						if tag and ail then 
							if tag:match("ailment pet") then
								StateDB.active_ailments[ail] = nil 
							elseif tag:match("ailment baby") then
								StateDB.baby_active_ailments[ail] = nil
							end
						end

						sfire()
					end
				end)
				
				ev.Event:Wait()
				ev:Destroy() 
				
				self:dequeue()

				print("task ended. Event called", name)
				
			end

			self.running = false

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

local
 function goto(destId, door, ops:table) 

	if get_current_location() == destId then return end

	temp_platform()

	InteriorsM.enter(destId, door, ops or {})

	while get_current_location() ~= destId do
		task.wait(.1)
	end

	game.Workspace:FindFirstChild("TempPart"):Destroy()

	task.wait(.5)
end


local function to_neighborhood()

	goto("Neighborhood", "MainDoor")

end


local function to_home() 

	goto("housing", "MainDoor", { house_owner=LocalPlayer })
	
end


local function to_mainmap() 

	goto("MainMap", "Neighborhood/MainDoor")

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

    local pet_info = InventoryDB.pets[remote]
    local rarity = pet_info and pet_info.rarity
    local name = pet_info and pet_info.name

    return {
        remote = remote,
        unique = unique,
        wrapper = wrapper,
        age = age,
        rarity = rarity,
        friendship = friendship,
        xp = xp,
        name = name,
    }

end


local function get_equiped_model() 

    local model

    for _, v in ipairs(workspace.Pets:GetChildren()) do
        local entity = PetEntityManager.get_pet_entity(v)

        if entity and entity.session_memory and entity.session_memory.meta.owned_by_local_player then
            model = v
            break
        end
    end

	return model

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


local function get_equiped_pet_ailments() 

	local ailments = {}

	if actual_pet.unique then
		local path = ClientData.get("ailments_manager")["ailments"][actual_pet.unique]

		if not path then return {} end

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

    if pets[inv_get_category_unique("pets", remote)] then
        return true
    end
	
    return false

end


local function send_trade_request(user)  

	safeFire("TradeAPI/SendTradeRequest", game.Players[user])

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


local function check_remote_existance(category, remote)

	return InventoryDB[category][remote] 

end


local function count(t)

	local n = 0

	for _ in pairs(t) do
		n +=1 
	end

	return n

end


local function shallow_keys_copy(t)

	local r = {}

	for k,_ in pairs(t) do
        r[k] = true
    end

	return r

end


local function get_potions() 

	local big = {}
	local tiny = {}

	for k,v in pairs(get_owned_category("food")) do
		if (v.remote:lower()):match("potion") then
			if (v.remote:lower()):match("tiny age up potion") then
				tiny[k] = true
			elseif (v.remote:lower()):match("age up potion") then
				big[k] = true
			end
		end 
	end
	
	if count(big) == 0 then big = nil end
	if count(tiny) == 0 then tiny = nil end

	return { big, tiny }

end


local function calculate_optimal_potions_by_rarity(age, rarity, potions)

    local total_tasks = TASKS_BY_RARITY[rarity:lower()]

    local remaining = total_tasks - age

    if remaining <= 0 then
        return { {}, {} }
    end

	local _age = potions[1] and shallow_keys_copy(potions[1]) or {}  
	local _tiny = potions[2] and shallow_keys_copy(potions[2]) or {}

    local big_up = count(_age)
    local tiny_up = count(_tiny)

    local use_age = math.floor(remaining / 30)
    local leftover = remaining % 30
    local use_tiny = 0

    if leftover > 0 then
        if leftover <= 3 and tiny_up > 0 then
            use_tiny = 1
        else
            use_age += 1
        end
    end

    local original_age = use_age
    use_age = math.min(use_age, big_up)

    if use_age < original_age and tiny_up > 0 then
        local missing_age = original_age - use_age
        local tiny_needed = math.ceil((missing_age * 30) / 3)
        use_tiny = math.min(tiny_needed, tiny_up)
    end

    use_tiny = math.min(use_tiny, tiny_up)

    if use_age > 0 and big_up > use_age then
        for k,_ in pairs(_age) do 
            _age[k] = nil
            if count(_age) == use_age then
                break
            end
        end
    end

    if use_tiny > 0 and tiny_up > use_tiny then
        for k,_ in pairs(_tiny) do 
            _tiny[k] = nil
            if count(_tiny) == use_tiny then
                break
            end
        end
    end

    return { _age, _tiny }

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


local function gotovec(x, y, z)

	local char = LocalPlayer.Character

	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	if actual_pet.unique and actual_pet.wrapper then
		PetActions.pick_up(actual_pet.wrapper)

		task.wait(0.4)

		root.CFrame = CFrame.new(x, y, z)

		task.wait(0.2)

		if actual_pet.model then
			safeFire("AdoptAPI/EjectBaby", actual_pet.model)
		end
	else
		root.CFrame = CFrame.new(x, y, z)
	end

end


local function Avatar()

    local success, response = pcall(function()
        return request({
            Url = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds="
                .. LocalPlayer.UserId
                .. "&size=420x420&format=Png&isCircular=false",
            Method = "GET",
        })
    end)

    if not success or not response or not response.Body then
        warn("[-] Failed to fetch avatar.")
        return
    end

    local decoded
    
    pcall(function()
        decoded = HttpService:JSONDecode(response.Body)
    end)

    _G.HeadCashed = decoded.data[1].imageUrl

end


local function webhook(title, description)
	
    local url = _G.InternalConfig.DiscordWebhookURL
    if not url then return end

	if not _G.HeadCashed then
		Avatar()
	end

	local payload = {
		content = nil,
		embeds = {
			{
				title = "`              "..title.."              `",				
				description = description,
				color = 0,
				author = {
					name = LocalPlayer.Name,
					url = "https://discord.gg/E8BVmZWnHs",
					icon_url = _G.HeadCashed or "https://i.imageupload.app/936d8d1617445f2a3fbd.png"
				},
				footer = {
					text = os.date("%d.%m.%Y") .. " " .. os.date("%H:%M:%S")
				}
			}
		},
		username = "Arcanic",
		avatar_url = "https://i.imageupload.app/936d8d1617445f2a3fbd.png",
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


local function update_gui(label, val: number) 

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

	if pet then
		actual_pet.unique = pet.unique 
		actual_pet.remote = pet.remote
		actual_pet.model = get_equiped_model() 
		actual_pet.wrapper = pet.wrapper
		actual_pet.rarity = pet.rarity
		actual_pet.is_egg = (pet.name:lower()):match("egg") ~= nil
	end

end


local function __baby_callbak(ailment) 

	if _G.InternalConfig.BabyAutoFarm then
		queue:taskdestroy("baby", ailment)
		StateDB.baby_active_ailments[ailment] = nil
	end

	farmed.baby_ailments += 1 
	update_gui("baby_needs", farmed.baby_ailments)

end


local function enstat(age, friendship, money, ailment, baby_has_ailment)  

	local deadline = os.clock() + 5

	while money == ClientData.get("money") and os.clock() < deadline do
		task.wait(.1)
	end

	if baby_has_ailment and ClientData.get("team") == "Babies" and not has_ailment_baby(ailment) then
		__baby_callbak(ailment)
	end

	if actual_pet.is_egg then
		if actual_pet.unique ~= cur_unique() then
			farmed.eggs_hatched += 1 
			farmed.ailments += 1
			update_gui("eggs", farmed.eggs_hatched)
			update_gui("pet_needs", farmed.ailments)
			
			if money then 
				farmed.money += ClientData.get("money") - money
				update_gui("bucks", farmed.money)
			end

			if not _G.flag_if_no_one_to_farm then 
				actual_pet.unique = nil 
				queue:destroy_linked("ailment pet")
				table.clear(StateDB.active_ailments)
			else
				StateDB.active_ailments[ailment] = nil
				pet_update()
			end
		else
			farmed.ailments +=1
			update_gui("pet_needs", farmed.ailments)

			if money then 
				farmed.money += ClientData.get("money") - money
				update_gui("bucks", farmed.money)
			end

			StateDB.active_ailments[ailment] = nil
		end

		return
	end

	if _G.InternalConfig.AutoFarmFilter.PotionFarm then
		if age < 6 and ClientData.get("pet_char_wrappers")[1].pet_progression.age == 6 then
			farmed.pets_fullgrown += 1
			update_gui("fullgrown", farmed.pets_fullgrown)
			StateDB.total_fullgrowned[actual_pet.unique] = true
		end

		if friendship < ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level then
			farmed.friendship_levels += 1
			farmed.potions += 1
			update_gui("friendship", farmed.friendship_levels)
			update_gui("potions", farmed.potions)
		end

		StateDB.active_ailments[ailment] = nil
	else 
		StateDB.active_ailments[ailment] = nil 

		if age < 6 and ClientData.get("pet_char_wrappers")[1].pet_progression.age == 6 then
			farmed.pets_fullgrown += 1
			update_gui("fullgrown", farmed.pets_fullgrown)
			StateDB.total_fullgrowned[actual_pet.unique] = true

			if not _G.flag_if_no_one_to_farm then
				actual_pet.unique = nil
				queue:destroy_linked("ailment pet")
				table.clear(StateDB.active_ailments)
			end

		end
	
		if friendship < ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level then
			farmed.friendship_levels += 1
			farmed.potions += 1
			update_gui("friendship", farmed.friendship_levels)
			update_gui("potions", farmed.potions)
		end
	end

	farmed.ailments += 1

	if money then 
		farmed.money += ClientData.get("money") - money
		update_gui("bucks", farmed.money)
	end

	update_gui("pet_needs", farmed.ailments)

end


local function __pet_callback(age, friendship, ailment) 

	if not _G.InternalConfig.FarmPriority then
		farmed.ailments += 1
		update_gui("pet_needs", farmed.ailments) 
	else
		enstat(age, friendship, nil, ailment)
	end

end


local function enstat_baby(money, ailment, pet_has_ailment, petData) 

	local deadline = os.clock() + 5

	while money == ClientData.get("money") and os.clock() < deadline do
		task.wait(.1)
	end

	farmed.money += ClientData.get("money") - money 
	farmed.baby_ailments += 1
	StateDB.baby_active_ailments[ailment] = nil

	if pet_has_ailment and equiped() and not has_ailment(ailment) then
		__pet_callback(petData[1], petData[2], ailment)
	end

	update_gui("bucks", farmed.money)
	update_gui("baby_needs", farmed.baby_ailments)
	
end


local pet_ailments = { 
	["camping"] = function(ev)

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
		local age = pet.pet_progression.age
		local baby_has_ailment = has_ailment_baby("camping")

		to_mainmap()
		gotovec(-23, 37, -1063)
        
		local deadline = os.clock() + 60
        
		repeat 
            task.wait(1)
        until not has_ailment("camping") or os.clock() > deadline
        
		if os.clock() > deadline then 
			error("Out of limits") 
		end        

		enstat(age, friendship, money, "camping", baby_has_ailment)

		ev()

	end,

	["hungry"] = function(ev) -- healing_apple в прошлый раз не работало
		
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
		local age = pet.pet_progression.age

		if count_of_product("food", "apple") == 0 then
			if money == 0 then 
				error("[!] No money to buy food.") 
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
		local money = ClientData.get("money")
		
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
			error("Out of limits") 
		end        

		enstat(age, friendship, money, "hungry")  

		ev()

	end,

	["thirsty"] = function(ev) 

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
		local age = pet.pet_progression.age

		if count_of_product("food", "water") == 0 then
			if money == 0 then 
				error("[!] No money to buy food.") 
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
		local money = ClientData.get("money")

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
			error("Out of limits") 
		end            	

		enstat(age, friendship, money, "thirsty")  

		ev()

	end,

	["sick"] = function(ev) 
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
		local age = pet.pet_progression.age
		local baby_has_ailment = has_ailment_baby("sick")

		goto("Hospital", "MainDoor")

		safeInvoke("HousingAPI/ActivateInteriorFurniture",
			"f-14",
			"UseBlock",
			"Yes",
			LocalPlayer.Character
		)
		
		enstat(age, friendship, money, "sick", baby_has_ailment)

		ev()

	end,

	["bored"] = function(ev) 

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
		local age = pet.pet_progression.age
		local baby_has_ailment = has_ailment_baby("bored")

		to_mainmap()
		gotovec(-365, 30, -1749)

        local deadline = os.clock() + 60

        repeat 
            task.wait(1)
        until not has_ailment("bored") or os.clock() > deadline

        if os.clock() > deadline then 
			error("Out of limits") 
		end        

		enstat(age, friendship, money, "bored", baby_has_ailment)  

		ev()

	end,

	["salon"] = function(ev) 

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
		local age = pet.pet_progression.age
		local baby_has_ailment = has_ailment_baby("salon")

		goto("Salon", "MainDoor")

        local deadline = os.clock() + 60

        repeat 
            task.wait(1)
        until not has_ailment("salon") or os.clock() > deadline

        if os.clock() > deadline then 
			error("Out of limits") 
		end        
		
		enstat(age, friendship, money, "salon", baby_has_ailment)
		
		ev()

	end,

	["play"] = function(ev) 

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
		local age = pet.pet_progression.age

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
			error("Out of limits") 
		end        

		enstat(age, friendship, money, "play") 

		ev()

	end,

	["toilet"] = function(ev) 

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
		local age = pet.pet_progression.age

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
			error("Out of limits") 
		end        

		enstat(age, friendship, money, "toilet")

		ev()

	end,

	["beach_party"] = function(ev) 

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
		local age = pet.pet_progression.age
		local baby_has_ailment = has_ailment_baby("beach_party")

		to_mainmap()
		gotovec(-596, 27, -1473)

        local deadline = os.clock() + 60

        repeat 
            task.wait(1)
        until not has_ailment("beach_party") or os.clock() > deadline

        if os.clock() > deadline then 
			error("Out of limits") 
		end        

		enstat(age, friendship, money, "beach_party", baby_has_ailment)  
		
		ev()

	end,

	["ride"] = function(ev)

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
		local age = pet.pet_progression.age
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
			error("Out of limits") 
		end        

		enstat(age, friendship, money, "ride") 

		ev()

	end,

	["dirty"] = function(ev) 

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
		local age = pet.pet_progression.age

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
			error("Out of limits") 
		end        

		enstat(age, friendship, money, "dirty")  

		ev()

	end,

	["walk"] = function(ev) 
		
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
		local age = pet.pet_progression.age
		local deadline = os.clock() + 60

		gotovec(1000,25,1000)

		safeFire("AdoptAPI/HoldBaby", actual_pet.model)

		repeat
			LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position + LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector * 50)
			LocalPlayer.Character.Humanoid.MoveToFinished:Wait()
			LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector * 50)
			LocalPlayer.Character.Humanoid.MoveToFinished:Wait()				
		until not has_ailment("walk") or os.clock() > deadline

		safeFire("AdoptAPI/EjectBaby", actual_pet.model)

		if os.clock() > deadline then 
			error("Out of limits") 
		end      

		enstat(age, friendship, money, "walk") 

		ev()

	end,

	["school"] = function(ev) 

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
		local age = pet.pet_progression.age
		local baby_has_ailment = has_ailment_baby("school")
		
		goto("School", "MainDoor")

        local deadline = os.clock() + 60

        repeat 
            task.wait(1)
        until not has_ailment("school") or os.clock() > deadline

        if os.clock() > deadline then 
			error("Out of limits") 
		end        

		enstat(age, friendship, money, "school", baby_has_ailment)
		
		ev()

	end,

	["sleepy"] = function(ev)

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
		local age = pet.pet_progression.age

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
			error("Out of limits") 
		end        

		enstat(age, friendship, money, "sleepy")  

		ev()

	end,

	["mystery"] = function() 

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

	["pizza_party"] = function(ev) 

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
		local age = pet.pet_progression.age
		local baby_has_ailment = has_ailment_baby("pizza_party")

		goto("PizzaShop", "MainDoor")

        local deadline = os.clock() + 60

        repeat 
            task.wait(1)
        until not has_ailment("pizza_party") or os.clock() > deadline

        if os.clock() > deadline then 
			error("Out of limits") 
		end       

		enstat(age, friendship, money, "pizza_party", baby_has_ailment)  
		
		ev()

	end,
	
	-- ["pet_me"] = function() end,
	-- ["party_zone"] = function() end, -- available on admin abuse
}

baby_ailments = {

	["camping"] = function(ev) 
		
		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("camping") then
			error() 
		end

		local money = ClientData.get("money")

		to_mainmap()
		gotovec(-23, 37, -1063)
    
		local deadline = os.clock() + 60
		local pet_has_ailment = has_ailment("camping")
		local age, friendship
	
		if pet_has_ailment then
			age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
			friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
		end
    
		repeat 
            task.wait(1)
        until not has_ailment_baby("camping") or os.clock() > deadline
    
		if os.clock() > deadline then 
			error("Out of limits") 
		end		

		enstat_baby(money, "camping", pet_has_ailment, { age, friendship, })
	
		ev()

	end,

	["hungry"] = function(ev) 

		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("hungry") then
			error() 
		end

		local money = ClientData.get("money")

		if count_of_product("food", "apple") < 3 then
			if money == 0 then  
				error("[-] No money to buy food.") 
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

		local money = ClientData.get("money")
		local deadline = os.clock() + 5

		repeat 
			safeFire("ToolAPI/ServerUseTool",
				inv_get_category_unique("food", "apple"),
				"END"
			)
			task.wait(.5)
        until not has_ailment_baby("hungry") or os.clock() > deadline

        if os.clock() > deadline then 
			error("Out of limits") 
		end	

		enstat_baby(money, "hungry")  

		ev()

	end,

	["thirsty"] = function(ev) 

		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("thirsty") then
			error() 
		end

		local money = ClientData.get("money")

		if count_of_product("food", "water") == 0 then
			if money == 0 then 
				error("[-] No money to buy food.") 
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

		local money = ClientData.get("money")
        local deadline = os.clock() + 5

		repeat			
			safeFire("ToolAPI/ServerUseTool",
				inv_get_category_unique("food", "water"),
				"END"
			)
			task.wait(.5)
		until not has_ailment_baby("thirsty") or os.clock() > deadline  

        if os.clock() > deadline then 
			error("Out of limits") 
		end		

		enstat_baby(money, "thirsty")  

		ev()

	end,

	["sick"] = function(ev) 

		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("sick") then
			error() 
		end

		local money = ClientData.get("money")
		local pet_has_ailment = has_ailment("sick")
		local age, friendship

		if pet_has_ailment then
			age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
			friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
		end

		goto("Hospital", "MainDoor")
		
		safeInvoke("HousingAPI/ActivateInteriorFurniture",
			"f-14",
			"UseBlock",
			"Yes",
			LocalPlayer.Character
		)

		enstat_baby(money, "sick", pet_has_ailment, { age, friendship, }) 
		
		ev()

	end,

	["bored"] = function(ev) 
		
		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("bored") then
			error() 
		end
		
		local money = ClientData.get("money")
		local pet_has_ailment = has_ailment("bored")
		local age, friendship

		if pet_has_ailment then
			age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
			friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
		end

		to_mainmap()
		gotovec(-365, 30, -1749)
        
		local deadline = os.clock() + 60
        
		repeat 
            task.wait(1)
        until not has_ailment_baby("bored") or os.clock() > deadline

        if os.clock() > deadline then 
			error("Out of limits") 
		end		

		enstat_baby(money, "bored", pet_has_ailment, { age, friendship, })  
		
		ev()

	end,

	["salon"] = function(ev) 

		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("salon") then
			error() 
		end

		local money = ClientData.get("money")
		local pet_has_ailment = has_ailment("salon")
		local age, friendship

		if pet_has_ailment then
			age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
			friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
		end

		goto("Salon", "MainDoor")

        local deadline = os.clock() + 60

        repeat 
            task.wait(1)
        until not has_ailment_baby("salon") or os.clock() > deadline

        if os.clock() > deadline then 
			error("Out of limits") 
		end		

		enstat_baby(money, "salon", pet_has_ailment, { age, friendship, }) 
		
		ev()

	end,

	["beach_party"] = function(ev) 

		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("beach_party") then
			error() 
		end

		local money = ClientData.get("money")
		local pet_has_ailment = has_ailment("beach_party")
		local age, friendship

		if pet_has_ailment then
			age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
			friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
		end
		
		to_mainmap()
		gotovec(-596, 27, -1473)

        local deadline = os.clock() + 60

        repeat 
            task.wait(1)
        until not has_ailment_baby("beach_party") or os.clock() > deadline

        if os.clock() > deadline then 
			error("Out of limits") 
		end		

		enstat_baby(money, "beach_party", pet_has_ailment, { age, friendship, })  
		
		ev()

	end,

	["dirty"] = function(ev) 

		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("dirty") then
			error() 
		end

		local money = ClientData.get("money")

		to_home()

		task.spawn(function() 
			safeInvoke('HousingAPI/ActivateFurniture',
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
		
		task.wait(.1)

		StateManagerClient.exit_seat_states()

        if os.clock() > deadline then 
			error("Out of limits") 
		end		
		
		enstat_baby(money, "dirty")  

		ev()

	end,

	["school"] = function(ev) 
		
		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("school") then
			error() 
		end

		local money = ClientData.get("money")
		local pet_has_ailment = has_ailment("school")
		local age, friendship

		if pet_has_ailment then
			age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
			friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
		end

		goto("School", "MainDoor")

        local deadline = os.clock() + 60

        repeat 
            task.wait(1)
        until not has_ailment_baby("school") or os.clock() > deadline

        if os.clock() > deadline then 
			error("Out of limits") 
		end		

		enstat_baby(money, "school", pet_has_ailment, { age, friendship, })  
		
		ev()

	end,

	["sleepy"] = function(ev) 

		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("sleepy") then
			error() 
		end

		local money = ClientData.get("money")

		to_home()

		task.spawn(function() 
			safeInvoke('HousingAPI/ActivateFurniture',
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

		task.wait(.1)

		StateManagerClient.exit_seat_states()

        if os.clock() > deadline then 
			error("Out of limits") 
		end		

		enstat_baby(money, "sleepy")  

		ev()

	end,

	["pizza_party"] = function(ev) 

		if ClientData.get("team") ~= "Babies" or not has_ailment_baby("pizza_party") then
			error() 
		end

		local money = ClientData.get("money")
		local pet_has_ailment = has_ailment("pizza_party")
		local age, friendship

		if pet_has_ailment then
			age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
			friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
		end

		goto("PizzaShop", "MainDoor")

        local deadline = os.clock() + 60

        repeat 
            task.wait(1)
        until not has_ailment_baby("pizza_party") or os.clock() > deadline

        if os.clock() > deadline then 
			error("Out of limits") 
		end		

		enstat_baby(money, "pizza_party", pet_has_ailment, { age, friendship, })  
		
		ev()

	end,
}

local function init_autofarm() 

	if count(get_owned_pets()) == 0 then
		Cooldown.init_autofarm = 49
        return
	end
    
    local flag = false
	local kitty_exist = check_pet_owned("2d_kitty")
	local kitty_unique = inv_get_category_unique("pets", "d2kitty")

	if kitty_exist and kitty_unique ~= actual_pet.unique or kitty_unique ~= cur_unique() then
		safeInvoke("ToolAPI/Equip",
			kitty_unique,
			{
				use_sound_delay = true,
				equip_as_last = false
			}
		)

		flag = true
		_G.flag_if_no_one_to_farm = false

		task.wait(.3)

		pet_update()
	end

	if actual_pet.unique ~= cur_unique() or not equiped() then
		warn("actual_pet.unique = nil because: actual_pet.unique ~= cur_unique()",actual_pet.unique ~= cur_unique(), "equiped:", equiped())
		actual_pet.unique = nil
	end

    if not actual_pet.unique or _G.flag_if_no_one_to_farm then
		warn("pet selection, cuz actual_pet.unique:", actual_pet.unique, "_G.flag_no..:", _G.flag_if_no_one_to_farm)
		local owned_pets = get_owned_pets()

		if not kitty_exist then
			if _G.InternalConfig.PotionFarm then
				if _G.InternalConfig.FarmPriority == "pets" then
					for k,v in pairs(owned_pets) do
						if v.age == 6 and not _G.InternalConfig.AutoFarmFilter.PetsToExclude[v.remote] then
							safeInvoke("ToolAPI/Equip",
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
							_G.flag_if_no_one_to_farm = false
							pet_update()
							break				
						end
					end
				else 
					for k,v in pairs(owned_pets) do
						if (v.name:lower()):find("egg") then
							safeInvoke("ToolAPI/Equip",
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
							_G.flag_if_no_one_to_farm = false
							pet_update()
							break
						end
					end
					if not flag then
						for k, _ in pairs(owned_pets) do
							safeInvoke("ToolAPI/Equip",
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
							_G.flag_if_no_one_to_farm = false
							pet_update()
							break
						end
					end
				end
			else
				if _G.InternalConfig.FarmPriority == "pets" then	
					warn("section i need (pets)")		
					warn("Check [1]")
					for k,v in pairs(owned_pets) do
						if v.age < 6 and not _G.InternalConfig.AutoFarmFilter.PetsToExclude[v.remote] and not (v.name:lower()):match("egg") then
							safeInvoke("ToolAPI/Equip",
								k,
								{
									use_sound_delay = true,
									equip_as_last = false
								}
							)
							if not equiped() then
								warn("Check [1] : not equiped")
								continue
							end
							flag = true
							_G.flag_if_no_one_to_farm = false
							pet_update()
							warn("Check [1] : success. flag and unique:", flag, actual_pet.unique)
							break
						end
					end
				else 
					for k,v in pairs(owned_pets) do
						if not _G.InternalConfig.AutoFarmFilter.PetsToExclude[v.remote] and (v.name:lower()):match("egg") then
							safeInvoke("ToolAPI/Equip",
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
							_G.flag_if_no_one_to_farm = false
							pet_update()
							break
						end
					end
				end
				if not flag then
					warn("Check [2] : no flag. flag:", flag)
					if _G.InternalConfig.AutoFarmFilter.OppositeFarmEnabled then
						if not _G.flag_if_no_one_to_farm then  
						    warn("No pets to farm depending on config. Trying to detect legendary pet to farm or any..")
							for k, v in pairs(owned_pets) do
								if v.rarity == "legendary" then
									safeInvoke("ToolAPI/Equip",
										k,
										{
											use_sound_delay = true,
											equip_as_last = false
										}
									)

									if not equiped() then
										warn("Check [2] leg : not equiped")
										continue
									end

									flag = true
									_G.flag_if_no_one_to_farm = true
									_G.random_farm = true
									pet_update()
									warn("Check [2] leg : successed. flag and unique:", flag, actual_pet.unique)
									break
								end
							end
						end
					end
				end
				if not flag then
					warn("Check [3] : still no flag. flag:", flag)
					if _G.InternalConfig.AutoFarmFilter.OppositeFarmEnabled then
					    if not _G.flag_if_no_one_to_farm then  
						    for k, _ in pairs(owned_pets) do
							    safeInvoke("ToolAPI/Equip",
								    k,
								    {
							        	use_sound_delay = true,
								    	equip_as_last = false
								    }
						    	)
							    if not equiped() then
									warn("Check [3] : not equiped")
					     			continue
						    	end
						    	flag = true
					    		_G.flag_if_no_one_to_farm = true
						    	_G.random_farm = true
							    pet_update()
								warn("Check [3] : successed. flag and unique:", flag, actual_pet.unique)
						    	break
					    	end
				    	end
					end
				end
			end 
		end
        
        if not _G.flag_if_no_one_to_farm and _G.random_farm then
            table.clear(StateDB.active_ailments)
            queue:destroy_linked("ailment pet")
            _G.random_farm = false
        end
        
        if not flag or not equiped() then 
			print("Check after pet selection: flag and equiped:", flag, equiped())
            Cooldown.init_autofarm = 14
            return 
        end

    end 

	task.wait(1)

	local eqailments = get_equiped_pet_ailments()

    for k,_ in pairs(eqailments) do 
        if StateDB.active_ailments[k] then continue end
        if pet_ailments[k] then
            StateDB.active_ailments[k] = true
            if k == "mystery" then 
                queue:asyncrun({`ailment pet: {k}`, pet_ailments[k]}) 
                continue 
            end
			print("pet enq:", k)
            queue:enqueue({`ailment pet: {k}`, pet_ailments[k]})
        end
    end

    Cooldown.init_autofarm = 14

end
	

local function init_baby_autofarm() 

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

	task.wait(1)

	local active_ailments = get_baby_ailments()

	for k,_ in pairs(active_ailments) do
		if StateDB.baby_active_ailments[k] then continue end
		if baby_ailments[k] then
			StateDB.baby_active_ailments[k] = true
			print("baby enq:", k)
			queue:enqueue({`ailment baby {k}`, baby_ailments[k]})
		end
	end

	Cooldown.init_baby_autofarm = 14

end


local function init_auto_buy()
	
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

		Cooldown.init_auto_buy = 3600		
	else
		Cooldown.init_auto_buy = math.huge()
	end

end


local function init_auto_recycle() -- dodelat

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


local function init_auto_trade() 

	local user = _G.InternalConfig.AutoTradeFilter.PlayerTradeWith 
	local need_repeat = false
	local pets_to_send = {}
	local exclude = {}
    
	if game.Players:FindFirstChild(user) then
        Cooldown.init_auto_trade = 5000

        local r = send_trade_request(user)
		
        if r == "No response" then
            print("[Trade] No response.")
            Cooldown.init_auto_trade = _G.InternalConfig.AutoTradeFilter.TradeDelay
            return 
        end
        
		local owned_pets = get_owned_pets()
		local dtype = _G.InternalConfig.AutoTradeFilter.SendAllType 
		local rlist, alist

		if dtype == "number" then
			alist = inv_get_pets_with_age(dtype)
		else
			rlist = inv_get_pets_with_rarity(dtype)			
		end

		for k,v in owned_pets do
			if _G.InternalConfig.AutoTradeFilter.ExcludeFriendly then
				if v.friendship > 0 then
					exclude[k] = true
				end
			end

			if _G.InternalConfig.AutoTradeFilter.ExcludeEggs then
				if (v.name:lower()):match("egg") then
					exclude[k] = true
				end
			end

			if _G.InternalConfig.AutoTradeFilter.SendAllFarmed then
				if not exclude[k] and StateDB.total_fullgrowned[k] then
					pets_to_send[k] = true
				end
			end

			if _G.InternalConfig.AutoTradeFilter.SendAllType then
				if not exclude[k] and not pets_to_send[k] then
					local dtype = _G.InternalConfig.AutoTradeFilter.SendAllType 
					if type(dtype) == "number" and alist[k] then
						pets_to_send[k] = true						
					elseif type(dtype) == "string" and rlist[k] then
						pets_to_send[k] = true
					end
				end
			end
		end

        if count(pets_to_send) == 0 then
            Cooldown.init_auto_trade = 3600
            print("[TradeLog] Internal pet list is empty. Timeout: [3600]s.")
            return
        elseif count(pets_to_send) > 18 then
            for k in pairs(pets_to_send) do
				pets_to_send[k] = nil
				if count(pets_to_send) <= 18 then
					need_repeat = true
					break
				end
			end
        end

        task.wait(1)

        -- if UIManager.is_visible("TradeApp") then -- dodelat
        --     pcall(function()
        --         for k,_ in pairs(pets_to_send) do 
        --             safeFire("TradeAPI/AddItemToOffer", k)
        --             task.wait(.2)
        --         end
        --         repeat 
        --             while UIManager.apps.TradeApp:_get_local_trade_state().current_stage == "negotiation" do
        --                 safeFire("TradeAPI/AcceptNegotiation")
        --                 task.wait(5)
        --             end
        --             safeFire("TradeAPI/ConfirmTrade")
        --             task.wait(5)
        --         until not UIManager.is_visible("TradeApp")
        --     end)
        -- end

    else
		Cooldown.init_auto_trade = 60
		return
	end

    for k,_ in pairs(get_owned_pets()) do
        if pets_to_send[k] then 
            Cooldown.init_auto_trade = _G.InternalConfig.AutoTradeFilter.TradeDelay
			print(`[-] Trade unsuccessed. Timeout: [{_G.InternalConfig.AutoTradeFilter.TradeDelay}]s.`)
			webhook(
				"Trade-Log",
				"```diff\n- Trade with " 
					.. user 
					.. " unsuccessed. Timeout: [" 
					.. _G.InternalConfig.AutoTradeFilter.TradeDelay 
					.. "]s.\n```"
			)
            return
        end
    end

	print("[+] Trade successed.")

	if _G.InternalConfig.AutoTradeFilter.WebhookEnabled then
    	webhook("Trade-Log", "```diff\n+ Trade with " .. user .. " succeeded.\n```")		
		Cooldown.init_auto_trade = 3600
	end

	if need_repeat then
		print(`[+] Pets to send was > 18 so trade will be repeated after [{_G.InternalConfig.AutoTradeFilter.TradeDelay}]s.`)
		Cooldown.init_auto_trade = _G.InternalConfig.AutoTradeFilter.TradeDelay	
	end

end


local function init_lurebox_farm() 

	queue:enqueue({"lurebox_check", function(ev) 

		to_home()
		
		if not debug.getupvalue(LureBaitHelper.run_tutorial, 11)() then
			safeInvoke("HousingAPI/ActivateFurniture",
				LocalPlayer,
				furn.lurebox.unique,
				"UseBlock",
				{
					bait_unique = inv_get_category_unique("food", "ice_dimension_2025_ice_soup_bait") 
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

		local bait_placed = debug.getupvalue(LureBaitHelper.run_tutorial, 11)()                                       

		if not bait_placed then
			print("[Lure] Reward collected.")
		else
			print("[Lure] Next check in [3600]s.")
		end

		Cooldown.init_lurebox_farm = 3600

		ev()

	end})

end


local function init_gift_autoopen() 

	if count(get_owned_category("gifts")) < 1 then
		Cooldown.init_gift_autoopen = 3600
		return
	end
	
	for k,v in pairs(get_owned_category("gifts")) do
		if (v.remote:lower()):match("box") or (v.remote:lower()):match("chest") then
			safeInvoke("LootBoxAPI/ExchangeItemForReward", v.remote, k)
		else
			safeInvoke("ShopAPI/OpenGift", k)
		end
		task.wait(.5) 
	end

	Cooldown.init_gift_autoopen = 3600 
	
end


local function init_auto_give_potion()
	
	local pet_to_grow = {}
	local owned_pets = get_owned_pets()
	local _repeat = false

	if _G.InternalConfig.AutoGivePotion ~= "any" then
		for k,v in ipairs(_G.InternalConfig.AutoGivePotion) do
			local pet = inv_get_category_unique("pets", k)
			if owned_pets[pet] and owned_pets[pet].age < 6 and not (owned_pets[pet].name:lower()):match("egg") then
				table.insert(pet_to_grow, {pet, v.age, v.rarity})
			end
		end
	else
		for k,v in pairs(owned_pets) do
			if v.age < 6 and not (v.name:lower()):match("egg") then
				table.insert(pet_to_grow, {k, v.age, v.rarity})
			end
		end
	end

	if #pet_to_grow == 0 then 
		Cooldown.init_auto_give_potion = 900
		return
	elseif #pet_to_grow > 1 then
		_repeat = true
		for k,_ in ipairs(pet_to_grow) do
			pet_to_grow[k] = nil
			if #pet_to_grow == 1 then
				break
			end
		end
	end

	local potions = get_potions()
	
	if not potions[1] and not potions[2] then 
		Cooldown.init_auto_give_potion = 900
		return
	end	
	
	local potions_to_give = calculate_optimal_potions_by_rarity(pet_to_grow[1][2], pet_to_grow[1][3], potions)
		
	queue:enqueue({"auto_give_potion", function()
			
		local equiped_pet = ClientData.get("pet_char_wrappers")[1]

		if equiped_pet then
			safeInvoke("ToolAPI/Unequip",
				equiped_pet.pet_unique,
				{
					use_sound_delay = true,
					equip_as_last = false
				}
			)
		end

		task.wait(1)

		safeInvoke("ToolAPI/Equip",
			pet_to_grow[1][1],
			{
				use_sound_delay = true,
				equip_as_last = false
			}
		)
				
		if count(potions_to_give[1]) > 0 then
			local main = nil
			local others = {}

			for k,_ in pairs(potions_to_give[1]) do
				if main then 
					table.insert(others, k)
				else 
					main = k 
				end
			end

			safeInvoke("PetObjectAPI/CreatePetObject",
				"__Enum_PetObjectCreatorType_2",
				{
					additional_consume_uniques = {
						table.unpack(others)
					},
					pet_unique = pet_to_grow[1][1],
					unique_id = main
				}
			)
		end
				
		task.wait(2)
		
		if count(potions_to_give[2]) > 0 then
			local main = nil
			local others = {}

			for k,_ in pairs(potions_to_give[2]) do
				if main then 
					table.insert(others, k)
				else 
					main = k 
				end
			end

			safeInvoke("PetObjectAPI/CreatePetObject",
				"__Enum_PetObjectCreatorType_2",
				{
					additional_consume_uniques = {
						table.unpack(others)
					},
					pet_unique = pet_to_grow[1][1],
					unique_id = main
				}
			)
		end
		
		task.wait(1)

		safeInvoke("ToolAPI/Equip",
			equiped_pet.pet_unique or actual_pet.unique or "",
			{
				use_sound_delay = true,
				equip_as_last = false
			}
		)

		if _repeat then 
			Cooldown.init_auto_give_potion = 1
		else
			Cooldown.init_auto_give_potion = 900
		end

	end})

end


local function init_send_webhook() 

    webhook(
        "Farm-Log",
        `>>> 💸 __Money Earned__ - [ {farmed.money} ]\
        📈 __Pets Full-grown__ - [ {farmed.pets_fullgrown} ]\
        🐶 __Pet Needs Completed__ - [ {farmed.ailments} ]\
        🧪 __Potions Farmed__ - [ {farmed.potions} ]\
        🧸 __Friendship Levels Farmed__ - [ {farmed.friendship_levels} ]\
        👶 __Baby Needs Completed__ - [ {farmed.baby_ailments} ]\
        🥚 __Eggs Hatched__ - [ {farmed.eggs_hatched} ]`
    )

	Cooldown.webhook_send_delay = _G.InternalConfig.WebhookSendDelay

end


local function inGameOptimization() 
	if _G.InternalConfig.Mode == "bot" then
		RunService:Set3dRenderingEnabled(false)
	else
		-- playable optmization
	end
end


local function __init()

    Cooldown.webhook_send_delay = _G.InternalConfig.WebhookSendDelay or 3600


    _G.CONNECTIONS.HeartbeatInternalCountdown = RunService.Heartbeat:Connect(function(dt)

		accumulator += dt

        if accumulator >= 1 then
            accumulator -= 1
            local cd = Cooldown

            cd.init_autofarm = cd.init_autofarm and math.max(0, cd.init_autofarm - 1)
            cd.init_baby_autofarm = cd.init_baby_autofarm and math.max(0, cd.init_baby_autofarm - 1)
            cd.init_auto_buy = cd.init_auto_buy and math.max(0, cd.init_auto_buy - 1)
            cd.init_auto_recycle = cd.init_auto_recycle and math.max(0, cd.init_auto_recycle - 1)
            cd.init_auto_trade = cd.init_auto_trade and math.max(0, cd.init_auto_trade - 1)
            cd.init_lurebox_farm = cd.init_lurebox_farm and math.max(0, cd.init_lurebox_farm - 1)
            cd.init_gift_autoopen = cd.init_gift_autoopen and math.max(0, cd.init_gift_autoopen - 1)
            cd.init_auto_give_potion = cd.init_auto_give_potion and math.max(0, cd.init_auto_give_potion - 1)
            cd.webhook_send_delay = cd.webhook_send_delay and math.max(0, cd.webhook_send_delay - 1)
			cd.watchdog = cd.watchdog and math.max(0, cd.watchdog - 1)

            if _G.InternalConfig.FarmPriority and cd.init_autofarm == 0 then
                cd.init_autofarm = nil
                task.defer(init_autofarm)
            end

            if _G.InternalConfig.BabyAutoFarm and cd.init_baby_autofarm == 0 then
                cd.init_baby_autofarm = nil
                task.defer(init_baby_autofarm)
            end

            if _G.InternalConfig.AutoFarmFilter.AutoBuyEgg and cd.init_auto_buy == 0 then
                cd.init_auto_buy = nil
                task.defer(init_auto_buy)
            end

            if _G.InternalConfig.GiftsAutoOpen and cd.init_gift_autoopen == 0 then
                cd.init_gift_autoopen = nil
                task.defer(init_gift_autoopen)
            end

            if _G.InternalConfig.LureboxFarm and cd.init_lurebox_farm == 0 then
                cd.init_lurebox_farm = nil
                task.defer(init_lurebox_farm)
            end

            if _G.InternalConfig.AutoGivePotion and cd.init_auto_give_potion == 0 then
                cd.init_auto_give_potion = nil
                task.defer(init_auto_give_potion)
            end

            if _G.InternalConfig.AutoRecyclePet and cd.init_auto_recycle == 0 then
                cd.init_auto_recycle = nil
                task.defer(init_auto_recycle)
            end

            if _G.InternalConfig.PetAutoTrade and cd.init_auto_trade == 0 then
                cd.init_auto_trade = nil
                task.defer(init_auto_trade)
            end

            if _G.InternalConfig.DiscordWebhookURL and cd.webhook_send_delay == 0 then
                cd.webhook_send_delay = nil
                task.defer(init_send_webhook)
            end

			if cd.watchdog == 0 then
				task.defer(function()
					print("LuaVM Memory Usage: ", gcinfo() / 1024, "Mb")
					Cooldown.watchdog = 60
				end)
				cd.watchdog = -1
			end
        end
    end)


end 


local function autotutorial() end


local function license() 

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

	print("[?] Starting..")

	for k, v in pairs(getupvalue(require(ReplicatedStorage.ClientModules.Core:WaitForChild("RouterClient"):WaitForChild("RouterClient")).init, 7)) do
		v.Name = k
	end

	print("[+] API dehashed.")
	task.spawn(Avatar)

end)()


-- internal config init
;(function() 

	if type(Config.FarmPriority) == "string" then
		_G.InternalConfig.AutoFarmFilter = {}

		if (Config.FarmPriority):lower() == "eggs" or (Config.FarmPriority):lower() == "pets" then
			_G.InternalConfig.FarmPriority = Config.FarmPriority

			if type(Config.AutoFarmFilter.PetsToExclude) == "table" then 
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

			if type(Config.AutoFarmFilter.PotionFarm) == "boolean" then 
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

			if type(Config.AutoFarmFilter.EggAutoBuy) == "string" then
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

	if type(Config.BabyAutoFarm) == "boolean" then 
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

	if type(Config.AutoRecyclePet) == "boolean" then 
		if Config.AutoRecyclePet then
			_G.InternalConfig.AutoRecyclePet = true

			if not _G.InternalConfig.FarmPriority then
				_G.InternalConfig.FarmPriority = "pets"		

				if type(Config.AutoFarmFilter.PetsToExclude) == "table" then 
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

				if type(Config.AutoFarmFilter.PotionFarm) == "boolean" then
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

				if type(Config.AutoFarmFilter.EggAutoBuy) == "string" then 
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
			if type(Config.PetExchangeRarity) == "string" then 
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

			if type(Config.PetExchangeAge) == "string" then 
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

	if type(Config.DiscordWebhookURL) == "string" then 
		if not (Config.DiscordWebhookURL):match("^%s*$") then 
			local res, _ = pcall(function() 
				request({
					Url = Config.DiscordWebhookURL,
					Method = "GET"
				})
			end)

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

			if type(Config.AutoTradeFilter.PlayerTradeWith) == "string" then 
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
	_G.Looping.NetworkHook = NetworkClient.ChildRemoved:Connect(function() 
		

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


	end)
end


_G.CONNECTIONS.AntiAFK = LocalPlayer.Idled:Connect(function() 

	task.spawn(function() 

		VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)

		task.wait(1)

		VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)

	end)

end)


-- launch screen
;(function()

	if LocalPlayer.Character then return end

	repeat 
		task.wait(1)
	until not LocalPlayer.PlayerGui.AssetLoadUI.Enabled
	
	safeInvoke("TeamAPI/ChooseTeam", "Parents", { source_for_logging="intro_sequence" })

	task.wait(1)

	UIManager.set_app_visibility("MainMenuApp", false)
	UIManager.set_app_visibility("NewsApp", false)
	UIManager.set_app_visibility("DialogApp", false)

	task.wait(3)

	safeInvoke("DailyLoginAPI/ClaimDailyReward")

	UIManager.set_app_visibility("DailyLoginApp", false)

	safeFire("PayAPI/DisablePopups")
	
	repeat 
		task.wait(.3) 
	until LocalPlayer.Character and 
	LocalPlayer.Character.HumanoidRootPart and 
	LocalPlayer.Character.Humanoid and 
	LocalPlayer.PlayerGui

	task.wait(1)

end)()


-- stats gui
task.spawn(function() 

	local gui = Instance.new("ScreenGui") 
    local frame = Instance.new("Frame")

	if LocalPlayer.PlayerGui then 
		if CoreGui:FindFirstChild("StatsOverlay") then
			return
		end
	end

	gui.Name = "StatsOverlay" 
	gui.ResetOnSpawn = false 
	gui.Parent = CoreGui

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
;(function() 

	if not _G.InternalConfig.FarmPriority and 
	not _G.InternalConfig.BabyAutoFarm and
	not _G.InternalConfig.LureboxFarm then 
		return
	end	

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

end)()


task.spawn(function() 

	if game.Workspace:FindFirstChild("FarmPart") then return end

	local part:Part = Instance.new("Part")

	part.Size = Vector3.new(150, 1, 150)
	part.Position = Vector3.new(1000, 20, 1000) 
	part.Name = "FarmPart"
	part.Anchored = true
	part.Parent = game.Workspace

end)


license()
__init()
task.wait(5)
inGameOptimization()
