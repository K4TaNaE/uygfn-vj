if not game:IsLoaded() then
    game.Loaded:Wait()
end
print("Due to optimization, color-print is disabled.")
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
_G.__RUNNING = true
_G.InternalConfig = {}
_G.flag_if_no_one_to_farm = false
local _CONNECTIONS = {}
local _CLEANUP_INSTANCES = {}

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
local Scheduler = {
    tasks = {}
}

function Scheduler.add(name, interval, fn, opts)
    -- opts: {immediate = false, once = false}
    opts = opts or {}
    Scheduler.tasks[name] = {
        interval = interval,
        next = os.clock() + (opts.immediate and 0 or interval),
        fn = fn,
        once = opts.once or false
    }
end

function Scheduler.cancel(name)
    Scheduler.tasks[name] = nil
end

function Scheduler.tick(now)
    for name, task in pairs(Scheduler.tasks) do
        if now >= task.next then
            local ok, err = pcall(task.fn)
            if not ok then warn("Scheduler task error:", err) end
            if task.once then
                Scheduler.tasks[name] = nil
            else
                task.next = now + (task.interval or 0.1)
            end
        end
    end
end

local SelfWorker = {}
SelfWorker.new = function()
    local self = {
        _data = {},
        _head = 1,
        _tail = 0,
        running = false,
        blocked = false,
        worker_registered = false,
    }

    function self:enqueue(task)
        if self.blocked then return end
        if type(task) ~= "table" then return end
        if type(task[1]) ~= "string" or type(task[2]) ~= "function" then return end
        self._tail += 1
        self._data[self._tail] = task
        if not self.worker_registered then
            self.worker_registered = true
            Scheduler.add("queue_worker", 0.1, function()
                if self._head > self._tail then
                    Scheduler.tasks["queue_worker"] = nil
                    self.worker_registered = false
                    return
                end
                local dtask = self:dequeue()
                if dtask then
                    local name = dtask[1]
                    local callback = dtask[2]
                    local ok, err = xpcall(callback, debug.traceback)
                    dtask[1], dtask[2] = nil, nil
                    if not ok then
                        warn("Queue task failed:", err)
                        local spl = name:split(": ")
                        if spl[1] == "ailment pet" then
                            StateDB.active_ailments[spl[2]] = nil
                        elseif spl[1] == "ailment baby" then
                            StateDB.baby_active_ailments[spl[2]] = nil
                        end
                    end
                end
            end)
        end
    end

    function self:dequeue()
        if self._head > self._tail then return nil end
        local task = self._data[self._head]
        self._data[self._head] = nil
        self._head += 1
        return task
    end

    function self:empty()
        return self._head > self._tail
    end

    function self:clear()
        self._data = {}
        self._head = 1
        self._tail = 0
    end

    function self:destroy_linked(pattern)
        for i = self._head, self._tail do
            local v = self._data[i]
            if v and v[1] and v[1]:find(pattern) then
                self._data[i] = nil
            end
        end
    end

    function self:taskdestroy(p1, p2)
        for i = self._head, self._tail do
            local v = self._data[i]
            if v and v[1] and v[1]:find(p1) and v[1]:find(p2) then
                self._data[i] = nil
            end
        end
    end

	function self:asyncrun(taskt)
		if type(taskt) ~= "table" or type(taskt[2]) ~= "function" then return end
		local name = "async_" .. tostring(math.random())
		Scheduler.add(name, 0, function()
			local ok, err = xpcall(taskt[2], debug.traceback)
			if not ok then warn("Async task error:", err) end
			Scheduler.cancel(name)
		end, { once = true, immediate = true })
	end


    return self
end
local queue = SelfWorker.new()

local function wait_for(condition_fn, timeout, on_success, on_timeout)
    local start = os.clock()
    local name = "wait_for_" .. tostring(math.random())
    Scheduler.add(name, 0.25, function()
        local ok, res = pcall(condition_fn)
        if ok and res then
            Scheduler.cancel(name)
            if on_success then pcall(on_success) end
            return
        end
        if os.clock() - start >= (timeout or 10) then
            Scheduler.cancel(name)
            if on_timeout then pcall(on_timeout) end
            return
        end
    end)
end
local MAX_PARALLEL = 3
local active_parallel = 0
local function run_parallel(fn)
    if active_parallel >= MAX_PARALLEL then
        Scheduler.add("defer_parallel_"..tostring(math.random()), 0.5, function()
            run_parallel(fn)
        end, { once = true })
        return
    end
    active_parallel += 1
    task.spawn(function()
        local ok, err = pcall(fn)
        if not ok then warn("parallel task error:", err) end
        active_parallel -= 1
    end)
end

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

local function get_current_location() -- optimized
	return InteriorsM.get_current_location()["destination_id"]
end 

local function goto(destId, door, ops)
    if get_current_location() == destId then return end
    temp_platform()
    InteriorsM.enter(destId, door, ops or {})

    wait_for(
        function() return get_current_location() == destId end,
        10,
        function()
            local temp = workspace:FindFirstChild("TempPart")
            if temp then temp:Destroy() end
        end,
        function()
            local temp = workspace:FindFirstChild("TempPart")
            if temp then temp:Destroy() end
        end
    )
end

local function to_home()
    goto("housing", "MainDoor", { house_owner = LocalPlayer })
end

local function to_mainmap()
    goto("MainMap", "Neighborhood/MainDoor")
end

local function to_neighborhood()
    goto("Neighborhood", "MainDoor")
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
	local args = ...
    local ok, res = pcall(function() return API[api]:InvokeServer(args) end)
    return ok, res
end

local function safeFire(api, ...)
	local args = ...
    local ok = pcall(function() API[api]:FireServer(args) end)
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
    local wrapper = ClientData.get("pet_char_wrappers")[1]
    if not wrapper then return {} end
    local ailments = wrapper.pet_ailments
    if type(ailments) ~= "table" then
        return {}
    end
    local result = {}
    for name, active in pairs(ailments) do
        if active then
            result[name] = true
        end
    end
    return result
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
local function send_trade_request(user, callback)
    local player = game.Players:FindFirstChild(user)
    if not player then
        return callback("NoPlayer")
    end
    pcall(function()
        safeFire("TradeAPI/SendTradeRequest", player)
    end)
    local start = os.clock()
    local timeout = 120
    local name = "wait_tradeapp_" .. tostring(math.random())
    Scheduler.add(name, 0.5, function()
        if UIManager.is_visible("TradeApp") then
            Scheduler.cancel(name)
            return callback(true)
        end

        if os.clock() - start >= timeout then
            Scheduler.cancel(name)
            return callback("No response")
        end
    end, { immediate = true })
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

local function gotovec(x, y, z)
    run_parallel(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if actual_pet.unique and actual_pet.wrapper then
            pcall(function() PetActions.pick_up(actual_pet.wrapper) end)
            task.wait(0.4)
            root.CFrame = CFrame.new(x, y, z)
            task.wait(0.2)
            if actual_pet.model then
                pcall(function() safeFire("AdoptAPI/EjectBaby", actual_pet.model) end)
            end
        else
            root.CFrame = CFrame.new(x, y, z)
        end
    end)
end

local function webhook(title, description)
    local url = _G.InternalConfig.DiscordWebhookURL
    if not url then return end
    run_parallel(function()
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
    end)
end

-- proceed here
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
local function enstat(age, friendship, money, ailment)
    local start_unique = actual_pet.unique

    Scheduler.add("enstat_delay_" .. tostring(math.random()), 0.5, function()
        if actual_pet.is_egg then
            if start_unique ~= cur_unique() then
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
            local wrapper = ClientData.get("pet_char_wrappers")[1]
            if wrapper and wrapper.pet_progression.age == 6 and age < 6 then
                farmed.pets_fullgrown += 1
                update_gui("fullgrown", farmed.pets_fullgrown)
                table.insert(StateDB.total_fullgrowned, actual_pet.unique)

                if not _G.flag_if_no_one_to_farm then
                    actual_pet.unique = nil
                    queue:destroy_linked("ailment pet")
                    table.clear(StateDB.active_ailments)
                end
            end

            if _G.flag_if_no_one_to_farm then
                if friendship < ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level then
                    farmed.pets_fullgrown += 1
                    farmed.potions += 1
                    update_gui("friendship", farmed.friendship_levels)
                    update_gui("potions", farmed.potions)
                end
            end

            StateDB.active_ailments[ailment] = nil
        end

        farmed.money += ClientData.get("money") - money
        farmed.ailments += 1
        update_gui("bucks", farmed.money)
        update_gui("pet_needs", farmed.ailments)
    end, { once = true })
end

local function enstat_baby(money, ailment)
    Scheduler.add("enstat_baby_" .. tostring(math.random()), 0.5, function()
        farmed.money += ClientData.get("money") - money
        farmed.baby_ailments += 1
        StateDB.baby_active_ailments[ailment] = nil

        update_gui("bucks", farmed.money)
        update_gui("baby_needs", farmed.baby_ailments)
    end, { once = true })
end

local function __pet_callback(age, friendship, ailment)
    Scheduler.add("pet_callback_" .. tostring(math.random()), 0.5, function()
        if not _G.InternalConfig.FarmPriority then
            farmed.ailments += 1
            update_gui("pet_needs", farmed.ailments)
            return
        end
        if actual_pet.is_egg then
            if actual_pet.unique ~= cur_unique() then
                farmed.eggs_hatched += 1
                update_gui("eggs", farmed.eggs_hatched)
                farmed.ailments += 1
                update_gui("pet_needs", farmed.ailments)

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
            local wrapper = ClientData.get("pet_char_wrappers")[1]
            if wrapper and wrapper.pet_progression.age == 6 and age < 6 then
                farmed.pets_fullgrown += 1
                update_gui("fullgrown", farmed.pets_fullgrown)
                table.insert(StateDB.total_fullgrowned, actual_pet.unique)

                if not _G.flag_if_no_one_to_farm then
                    actual_pet.unique = nil
                    queue:destroy_linked("ailment pet")
                    table.clear(StateDB.active_ailments)
                end
            end

            if _G.flag_if_no_one_to_farm then
                if friendship < ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level then
                    farmed.pets_fullgrown += 1
                    farmed.potions += 1
                    update_gui("friendship", farmed.friendship_levels)
                    update_gui("potions", farmed.potions)
                end
            end

            StateDB.active_ailments[ailment] = nil
        end

        farmed.ailments += 1
        update_gui("pet_needs", farmed.ailments)
    end, { once = true })
end

local function __baby_callbak(ailment, money)
    Scheduler.add("baby_callback_" .. tostring(math.random()), 0.5, function()
        if not _G.InternalConfig.BabyAutoFarm then
            farmed.baby_ailments += 1
            update_gui("baby_needs", farmed.baby_ailments)
            return
        end

        queue:taskdestroy("baby", ailment)
        farmed.baby_ailments += 1
        StateDB.baby_active_ailments[ailment] = nil
        update_gui("baby_needs", farmed.baby_ailments)
    end, { once = true })
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
        local age = pet.pet_progression.age
        local baby_has = has_ailment_baby("camping")

        to_mainmap()
        gotovec(-23, 37, -1063)

        local start = os.clock()
        local key = "camping_wait_" .. tostring(math.random())

        Scheduler.add(key, 1, function()
            if not has_ailment("camping") then
                Scheduler.cancel(key)
                enstat(age, friendship, money, "camping")

                local key2 = "camping_baby_" .. tostring(math.random())
                Scheduler.add(key2, 0.8, function()
                    Scheduler.cancel(key2)
                    if baby_has and ClientData.get("team") == "Babies" and not has_ailment_baby("camping") then
                        __baby_callbak(money, "camping")
                    end
                end, { once = true })

                return
            end

            if os.clock() - start >= 60 then
                Scheduler.cancel(key)
                StateDB.active_ailments.camping = nil
                return
            end
        end)
    end,

    ["hungry"] = function()
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
                StateDB.active_ailments.hungry = nil
                return
            end
            if money > 20 then
                safeInvoke("ShopAPI/BuyItem", "food", "apple", { buy_count = 20 })
            else
                safeInvoke("ShopAPI/BuyItem", "food", "apple", { buy_count = money / 2 })
            end
        end

        safeInvoke("PetObjectAPI/CreatePetObject",
            "__Enum_PetObjectCreatorType_2",
            {
                additional_consume_uniques = {},
                pet_unique = pet.pet_unique,
                unique_id = inv_get_category_unique("food", "apple")
            }
        )

        local start = os.clock()
        local key = "hungry_wait_" .. tostring(math.random())

        Scheduler.add(key, 1, function()
            if not has_ailment("hungry") then
                Scheduler.cancel(key)
                enstat(age, friendship, money, "hungry")
                return
            end

            if os.clock() - start >= 10 then
                Scheduler.cancel(key)
                StateDB.active_ailments.hungry = nil
                return
            end
        end)
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
        local age = pet.pet_progression.age

        if count_of_product("food", "water") == 0 then
            if money == 0 then
                StateDB.active_ailments.thirsty = nil
                return
            end
            if money > 20 then
                safeInvoke("ShopAPI/BuyItem", "food", "water", { buy_count = 20 })
            else
                safeInvoke("ShopAPI/BuyItem", "food", "water", { buy_count = money / 2 })
            end
        end

        safeInvoke(PetObjectAPI/CreatePetObject,
            "__Enum_PetObjectCreatorType_2",
            {
                additional_consume_uniques = {},
                pet_unique = pet.pet_unique,
                unique_id = inv_get_category_unique("food", "water")
            }
        )

        local start = os.clock()
        local key = "thirsty_wait_" .. tostring(math.random())

        Scheduler.add(key, 1, function()
            if not has_ailment("thirsty") then
                Scheduler.cancel(key)
                enstat(age, friendship, money, "thirsty")
                return
            end

            if os.clock() - start >= 10 then
                Scheduler.cancel(key)
                StateDB.active_ailments.thirsty = nil
                return
            end
        end)
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
        local age = pet.pet_progression.age
        local baby_has = has_ailment_baby("sick")

        goto("Hospital", "MainDoor")

        local key = "sick_wait_" .. tostring(math.random())

        Scheduler.add(key, 1, function()
            safeInvoke("HousingAPI/ActivateInteriorFurniture",
                "f-14",
                "UseBlock",
                "Yes",
                LocalPlayer.Character
            )

            if not has_ailment("sick") then
                Scheduler.cancel(key)
                enstat(age, friendship, money, "sick")

                local key2 = "sick_baby_" .. tostring(math.random())
                Scheduler.add(key2, 0.8, function()
                    Scheduler.cancel(key2)
                    if baby_has and ClientData.get("team") == "Babies" and not has_ailment("sick") then
                        __baby_callbak(money, "sick")
                    end
                end, { once = true })

                return
            end
        end)
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
        local age = pet.pet_progression.age
        local baby_has = has_ailment_baby("bored")

        to_mainmap()
        gotovec(-365, 30, -1749)

        local start = os.clock()
        local key = "bored_wait_" .. tostring(math.random())

        Scheduler.add(key, 1, function()
            if not has_ailment("bored") then
                Scheduler.cancel(key)
                enstat(age, friendship, money, "bored")

                local key2 = "bored_baby_" .. tostring(math.random())
                Scheduler.add(key2, 0.8, function()
                    Scheduler.cancel(key2)
                    if baby_has and ClientData.get("team") == "Babies" and not has_ailment_baby("bored") then
                        __baby_callbak(money, "bored")
                    end
                end, { once = true })

                return
            end

            if os.clock() - start >= 60 then
                Scheduler.cancel(key)
                StateDB.active_ailments.bored = nil
                return
            end
        end)
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
		local age = pet.pet_progression.age
		local baby_has = has_ailment_baby("salon")

		goto("Salon", "MainDoor")

		local start = os.clock()
		local key = "salon_wait_" .. tostring(math.random())

		Scheduler.add(key, 1, function()
			if not has_ailment("salon") then
				Scheduler.cancel(key)
				enstat(age, friendship, money, "salon")

				local key2 = "salon_baby_" .. tostring(math.random())
				Scheduler.add(key2, 0.8, function()
					Scheduler.cancel(key2)
					if baby_has and ClientData.get("team") == "Babies" and not has_ailment_baby("salon") then
						__baby_callbak(money, "salon")
					end
				end, { once = true })

				return
			end

			if os.clock() - start >= 60 then
				Scheduler.cancel(key)
				StateDB.active_ailments.salon = nil
				return
			end
		end)
	end,

	["play"] = function()
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
		safeInvoke("ToolAPI/Equip", inv_get_category_unique("toys", "squeaky_bone_default"), {})

		safeInvoke("PetObjectAPI/CreatePetObject",
			"__Enum_PetObjectCreatorType_1",
			{
				reaction_name = "ThrowToyReaction",
				unique_id = inv_get_category_unique("toys", "squeaky_bone_default")
			}
		)

		local start = os.clock()
		local key = "play_wait_" .. tostring(math.random())

		Scheduler.add(key, 1, function()
			if not has_ailment("play") then
				Scheduler.cancel(key)
				safeInvoke("ToolAPI/Unequip", inv_get_category_unique("toys", "squeaky_bone_default"), {})
				enstat(age, friendship, money, "play")
				return
			end

			if os.clock() - start >= 25 then
				Scheduler.cancel(key)
				safeInvoke("ToolAPI/Unequip", inv_get_category_unique("toys", "squeaky_bone_default"), {})
				StateDB.active_ailments.play = nil
				return
			end
		end)
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
		local age = pet.pet_progression.age

		to_home()
		safeInvoke('HousingAPI/ActivateFurniture',
			LocalPlayer,
			furn.toilet.unique,
			furn.toilet.usepart,
			{ cframe = furn.toilet.cframe },
			actual_pet.model
		)

		local start = os.clock()
		local key = "toilet_wait_" .. tostring(math.random())

		Scheduler.add(key, 1, function()
			if not has_ailment("toilet") then
				Scheduler.cancel(key)
				enstat(age, friendship, money, "toilet")
				return
			end

			if os.clock() - start >= 15 then
				Scheduler.cancel(key)
				StateDB.active_ailments.toilet = nil
				return
			end
		end)
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
		local age = pet.pet_progression.age
		local baby_has = has_ailment_baby("beach_party")

		to_mainmap()
		gotovec(-596, 27, -1473)

		local start = os.clock()
		local key = "beach_wait_" .. tostring(math.random())

		Scheduler.add(key, 1, function()
			if not has_ailment("beach_party") then
				Scheduler.cancel(key)
				enstat(age, friendship, money, "beach_party")

				local key2 = "beach_baby_" .. tostring(math.random())
				Scheduler.add(key2, 0.8, function()
					Scheduler.cancel(key2)
					if baby_has and ClientData.get("team") == "Babies" and not has_ailment_baby("beach_party") then
						__baby_callbak(money, "beach_party")
					end
				end, { once = true })

				return
			end

			if os.clock() - start >= 60 then
				Scheduler.cancel(key)
				StateDB.active_ailments.beach_party = nil
				return
			end
		end)
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
		local age = pet.pet_progression.age

		gotovec(1000,25,1000)
		safeInvoke("ToolAPI/Equip", inv_get_category_unique("strollers", "stroller-default"), {})

		LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position + Vector3.new(0,0,50))

		local start = os.clock()
		local key = "ride_wait_" .. tostring(math.random())

		Scheduler.add(key, 1, function()
			if not has_ailment("ride") then
				Scheduler.cancel(key)
				safeInvoke("ToolAPI/Unequip", inv_get_category_unique("strollers", "stroller-default"), {})
				enstat(age, friendship, money, "ride")
				return
			end

			if os.clock() - start >= 60 then
				Scheduler.cancel(key)
				safeInvoke("ToolAPI/Unequip", inv_get_category_unique("strollers", "stroller-default"), {})
				StateDB.active_ailments.ride = nil
				return
			end
		end)
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
		local age = pet.pet_progression.age

		to_home()
		safeInvoke('HousingAPI/ActivateFurniture',
			LocalPlayer,
			furn.bath.unique,
			furn.bath.usepart,
			{ cframe = furn.bath.cframe },
			actual_pet.model
		)

		local start = os.clock()
		local key = "dirty_wait_" .. tostring(math.random())

		Scheduler.add(key, 1, function()
			if not has_ailment("dirty") then
				Scheduler.cancel(key)
				enstat(age, friendship, money, "dirty")
				return
			end

			if os.clock() - start >= 20 then
				Scheduler.cancel(key)
				StateDB.active_ailments.dirty = nil
				return
			end
		end)
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
		local age = pet.pet_progression.age

		gotovec(1000,25,1000)
		safeFire("AdoptAPI/HoldBaby", actual_pet.model)

		LocalPlayer.Character.Humanoid:MoveTo(LocalPlayer.Character.HumanoidRootPart.Position + Vector3.new(0,0,50))

		local start = os.clock()
		local key = "walk_wait_" .. tostring(math.random())

		Scheduler.add(key, 1, function()
			if not has_ailment("walk") then
				Scheduler.cancel(key)
				safeFire("AdoptAPI/EjectBaby", pet.model)
				enstat(age, friendship, money, "walk")
				return
			end

			if os.clock() - start >= 60 then
				Scheduler.cancel(key)
				safeFire("AdoptAPI/EjectBaby", pet.model)
				StateDB.active_ailments.walk = nil
				return
			end
		end)
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
		local age = pet.pet_progression.age
		local baby_has = has_ailment_baby("school")

		goto("School", "MainDoor")

		local start = os.clock()
		local key = "school_wait_" .. tostring(math.random())

		Scheduler.add(key, 1, function()
			if not has_ailment("school") then
				Scheduler.cancel(key)
				enstat(age, friendship, money, "school")

				local key2 = "school_baby_" .. tostring(math.random())
				Scheduler.add(key2, 0.8, function()
					Scheduler.cancel(key2)
					if baby_has and ClientData.get("team") == "Babies" and not has_ailment_baby("school") then
						__baby_callbak(money, "school")
					end
				end, { once = true })

				return
			end

			if os.clock() - start >= 60 then
				Scheduler.cancel(key)
				StateDB.active_ailments.school = nil
				return
			end
		end)
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
		local age = pet.pet_progression.age

		to_home()
		safeInvoke('HousingAPI/ActivateFurniture',
			LocalPlayer,
			furn.bed.unique,
			furn.bed.usepart,
			{ cframe = furn.bed.cframe },
			actual_pet.model
		)

		local start = os.clock()
		local key = "sleepy_wait_" .. tostring(math.random())

		Scheduler.add(key, 1, function()
			if not has_ailment("sleepy") then
				Scheduler.cancel(key)
				enstat(age, friendship, money, "sleepy")
				return
			end

			if os.clock() - start >= 20 then
				Scheduler.cancel(key)
				StateDB.active_ailments.sleepy = nil
				return
			end
		end)
	end,

	["mystery"] = function()
		local pet = ClientData.get("pet_char_wrappers")[1]
		if not pet or not actual_pet.unique or pet.pet_unique ~= actual_pet.unique or not has_ailment("mystery") then
			queue:destroy_linked("ailment pet")
			actual_pet.unique = nil
			table.clear(StateDB.active_ailments)
			return
		end

		local list = loader("new:AilmentsDB")
		local keys = {}

		for k,_ in pairs(list) do
			table.insert(keys, k)
		end

		local idx = 1
		local key = "mystery_loop_" .. tostring(math.random())

		Scheduler.add(key, 1.5, function()
			if not has_ailment("mystery") then
				Scheduler.cancel(key)
				StateDB.active_ailments.mystery = nil
				return
			end

			if idx > #keys then
				Scheduler.cancel(key)
				StateDB.active_ailments.mystery = nil
				return
			end

			safeFire("AilmentsAPI/ChooseMysteryAilment",
				actual_pet.unique,
				"mystery",
				1,
				keys[idx]
			)

			idx += 1
		end)
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
		local age = pet.pet_progression.age
		local baby_has = has_ailment_baby("pizza_party")

		goto("PizzaShop", "MainDoor")

		local start = os.clock()
		local key = "pizza_wait_" .. tostring(math.random())

		Scheduler.add(key, 1, function()
			if not has_ailment("pizza_party") then
				Scheduler.cancel(key)
				enstat(age, friendship, money, "pizza_party")

				local key2 = "pizza_baby_" .. tostring(math.random())
				Scheduler.add(key2, 0.8, function()
					Scheduler.cancel(key2)
					if baby_has and ClientData.get("team") == "Babies" and not has_ailment_baby("pizza_party") then
						__baby_callbak(money, "pizza_party")
					end
				end, { once = true })

				return
			end

			if os.clock() - start >= 60 then
				Scheduler.cancel(key)
				StateDB.active_ailments.pizza_party = nil
				return
			end
		end)
	end
}

local function baby_loop_adaptive(ailment, timeout, intervals, action_fn, on_success)
    local start = os.clock()
    local last = os.clock()
    local idx = 1
    local key = "baby_loop_" .. ailment .. "_" .. tostring(math.random())
    Scheduler.add(key, 0.3, function()
        if not has_ailment_baby(ailment) then
            Scheduler.cancel(key)
            on_success()
            return
        end
        if os.clock() - start >= timeout then
            Scheduler.cancel(key)
            StateDB.baby_active_ailments[ailment] = nil
            return
        end
        local curInterval = intervals[idx] or intervals[#intervals]
        if os.clock() - last >= curInterval then
            last = os.clock()
            idx = idx % #intervals + 1
            pcall(action_fn)
        end
    end)
end

local baby_ailments = {
    ["camping"] = function()
        if ClientData.get("team") ~= "Babies" or not has_ailment_baby("camping") then return end
        local money = ClientData.get("money")
        to_mainmap()
        gotovec(-23, 37, -1063)
        local pet_has = has_ailment("camping")
        local age, friendship
        if pet_has then
            age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
            friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
        end
        local start = os.clock()
        local key = "baby_camping_wait_" .. tostring(math.random())
        Scheduler.add(key, 1, function()
            if not has_ailment_baby("camping") then
                Scheduler.cancel(key)
                enstat_baby(money, "camping")
                local key2 = "baby_camping_cb_" .. tostring(math.random())
                Scheduler.add(key2, 0.8, function()
                    Scheduler.cancel(key2)
                    if pet_has and equiped() and not has_ailment("camping") then
                        __baby_callbak("camping", money)
                    end
                end, { once = true })
                return
            end
            if os.clock() - start >= 60 then
                Scheduler.cancel(key)
                StateDB.baby_active_ailments.camping = nil
                return
            end
        end)
    end,

    ["hungry"] = function()
        if ClientData.get("team") ~= "Babies" or not has_ailment_baby("hungry") then return end
        local money = ClientData.get("money")
        if count_of_product("food", "apple") < 3 then
            if money == 0 then
                StateDB.baby_active_ailments.hungry = nil
                return
            end
            local buy = money > 20 and 30 or math.floor(money / 2)
            safeInvoke("ShopAPI/BuyItem", "food", "apple", { buy_count = buy })
        end
        baby_loop_adaptive(
            "hungry",
            5,
            {0.3, 0.5, 0.7},
            function()
                safeFire("ToolAPI/ServerUseTool", inv_get_category_unique("food", "apple"), "END")
            end,
            function()
                enstat_baby(money, "hungry")
                __baby_callbak("hungry", money)
            end
        )
    end,

    ["thirsty"] = function()
        if ClientData.get("team") ~= "Babies" or not has_ailment_baby("thirsty") then return end
        local money = ClientData.get("money")
        if count_of_product("food", "water") == 0 then
            if money == 0 then
                StateDB.baby_active_ailments.thirsty = nil
                return
            end
            local buy = money > 20 and 20 or math.floor(money / 2)
            safeInvoke("ShopAPI/BuyItem", "food", "water", { buy_count = buy })
        end
        baby_loop_adaptive(
            "thirsty",
            5,
            {0.3, 0.5, 0.7},
            function()
                safeFire("ToolAPI/ServerUseTool", inv_get_category_unique("food", "water"), "END")
            end,
            function()
                enstat_baby(money, "thirsty")
                __baby_callbak("thirsty", money)
            end
        )
    end,

    ["sick"] = function()
        if ClientData.get("team") ~= "Babies" or not has_ailment_baby("sick") then return end
        local money = ClientData.get("money")
        local pet_has = has_ailment("sick")
        local age, friendship
        if pet_has then
            age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
            friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
        end
        baby_loop_adaptive(
            "sick",
            20,
            {1},
            function()
                goto("Hospital", "MainDoor")
                safeInvoke("HousingAPI/ActivateInteriorFurniture", "f-14", "UseBlock", "Yes", LocalPlayer.Character)
            end,
            function()
                enstat_baby(money, "sick")
                __baby_callbak("sick", money)
            end
        )
    end,

    ["bored"] = function()
        if ClientData.get("team") ~= "Babies" or not has_ailment_baby("bored") then return end
        local money = ClientData.get("money")
        local pet_has = has_ailment("bored")
        local age, friendship
        if pet_has then
            age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
            friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
        end
        to_mainmap()
        gotovec(-365, 30, -1749)
        local start = os.clock()
        local key = "baby_bored_wait_" .. tostring(math.random())
        Scheduler.add(key, 1, function()
            if not has_ailment_baby("bored") then
                Scheduler.cancel(key)
                enstat_baby(money, "bored")
                local key2 = "baby_bored_cb_" .. tostring(math.random())
                Scheduler.add(key2, 0.8, function()
                    Scheduler.cancel(key2)
                    if pet_has and equiped() and not has_ailment("bored") then
                        __baby_callbak("bored", money)
                    end
                end, { once = true })
                return
            end
            if os.clock() - start >= 60 then
                Scheduler.cancel(key)
                StateDB.baby_active_ailments.bored = nil
                return
            end
        end)
    end,

    ["salon"] = function()
        if ClientData.get("team") ~= "Babies" or not has_ailment_baby("salon") then return end
        local money = ClientData.get("money")
        local pet_has = has_ailment("salon")
        local age, friendship
        if pet_has then
            age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
            friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
        end
        goto("Salon", "MainDoor")
        local start = os.clock()
        local key = "baby_salon_wait_" .. tostring(math.random())
        Scheduler.add(key, 1, function()
            if not has_ailment_baby("salon") then
                Scheduler.cancel(key)
                enstat_baby(money, "salon")
                local key2 = "baby_salon_cb_" .. tostring(math.random())
                Scheduler.add(key2, 0.8, function()
                    Scheduler.cancel(key2)
                    if pet_has and equiped() and not has_ailment("salon") then
                        __baby_callbak("salon", money)
                    end
                end, { once = true })
                return
            end
            if os.clock() - start >= 60 then
                Scheduler.cancel(key)
                StateDB.baby_active_ailments.salon = nil
                return
            end
        end)
    end,

    ["beach_party"] = function()
        if ClientData.get("team") ~= "Babies" or not has_ailment_baby("beach_party") then return end
        local money = ClientData.get("money")
        local pet_has = has_ailment("beach_party")
        local age, friendship
        if pet_has then
            age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
            friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
        end
        to_mainmap()
        gotovec(-596, 27, -1473)
        local start = os.clock()
        local key = "baby_beach_wait_" .. tostring(math.random())
        Scheduler.add(key, 1, function()
            if not has_ailment_baby("beach_party") then
                Scheduler.cancel(key)
                enstat_baby(money, "beach_party")
                local key2 = "baby_beach_cb_" .. tostring(math.random())
                Scheduler.add(key2, 0.8, function()
                    Scheduler.cancel(key2)
                    if pet_has and equiped() and not has_ailment("beach_party") then
                        __baby_callbak("beach_party", money)
                    end
                end, { once = true })
                return
            end
            if os.clock() - start >= 60 then
                Scheduler.cancel(key)
                StateDB.baby_active_ailments.beach_party = nil
                return
            end
        end)
    end,

    ["dirty"] = function()
        if ClientData.get("team") ~= "Babies" or not has_ailment_baby("dirty") then return end
        local money = ClientData.get("money")
        to_home()
        task.spawn(function()
            safeInvoke('HousingAPI/ActivateFurniture', LocalPlayer, furn.bath.unique, furn.bath.usepart, { cframe = furn.bath.cframe }, LocalPlayer.Character)
        end)
        local start = os.clock()
        local key = "baby_dirty_wait_" .. tostring(math.random())
        Scheduler.add(key, 1, function()
            if not has_ailment_baby("dirty") then
                Scheduler.cancel(key)
                StateManagerClient.exit_seat_states()
                enstat_baby(money, "dirty")
                return
            end
            if os.clock() - start >= 20 then
                Scheduler.cancel(key)
                StateDB.baby_active_ailments.dirty = nil
                return
            end
        end)
    end,

    ["school"] = function()
        if ClientData.get("team") ~= "Babies" or not has_ailment_baby("school") then return end
        local money = ClientData.get("money")
        local pet_has = has_ailment("school")
        local age, friendship
        if pet_has then
            age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
            friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
        end
        goto("School", "MainDoor")
        local start = os.clock()
        local key = "baby_school_wait_" .. tostring(math.random())
        Scheduler.add(key, 1, function()
            if not has_ailment_baby("school") then
                Scheduler.cancel(key)
                enstat_baby(money, "school")
                local key2 = "baby_school_cb_" .. tostring(math.random())
                Scheduler.add(key2, 0.8, function()
                    Scheduler.cancel(key2)
                    if pet_has and equiped() and not has_ailment("school") then
                        __baby_callbak("school", money)
                    end
                end, { once = true })
                return
            end
            if os.clock() - start >= 60 then
                Scheduler.cancel(key)
                StateDB.baby_active_ailments.school = nil
                return
            end
        end)
    end,

    ["sleepy"] = function()
        if ClientData.get("team") ~= "Babies" or not has_ailment_baby("sleepy") then return end
        local money = ClientData.get("money")
        to_home()
        task.spawn(function()
            safeInvoke('HousingAPI/ActivateFurniture', LocalPlayer, furn.bed.unique, furn.bed.usepart, { cframe = furn.bed.cframe }, LocalPlayer.Character)
        end)
        local start = os.clock()
        local key = "baby_sleepy_wait_" .. tostring(math.random())
        Scheduler.add(key, 1, function()
            if not has_ailment_baby("sleepy") then
                Scheduler.cancel(key)
                StateManagerClient.exit_seat_states()
                enstat_baby(money, "sleepy")
                return
            end
            if os.clock() - start >= 20 then
                Scheduler.cancel(key)
                StateDB.baby_active_ailments.sleepy = nil
                return
            end
        end)
    end,

    ["pizza_party"] = function()
        if ClientData.get("team") ~= "Babies" or not has_ailment_baby("pizza_party") then return end
        local money = ClientData.get("money")
        local pet_has = has_ailment("pizza_party")
        local age, friendship
        if pet_has then
            age = ClientData.get("pet_char_wrappers")[1].pet_progression.age
            friendship = ClientData.get("inventory").pets[actual_pet.unique].properties.friendship_level
        end
        goto("PizzaShop", "MainDoor")
        local start = os.clock()
        local key = "baby_pizza_wait_" .. tostring(math.random())
        Scheduler.add(key, 1, function()
            if not has_ailment_baby("pizza_party") then
                Scheduler.cancel(key)
                enstat_baby(money, "pizza_party")
                local key2 = "baby_pizza_cb_" .. tostring(math.random())
                Scheduler.add(key2, 0.8, function()
                    Scheduler.cancel(key2)
                    if pet_has and equiped() and not has_ailment("pizza_party") then
                        __baby_callbak("pizza_party", money)
                    end
                end, { once = true })
                return
            end
            if os.clock() - start >= 60 then
                Scheduler.cancel(key)
                StateDB.baby_active_ailments.pizza_party = nil
                return
            end
        end)
    end,
}

local function step_autofarm()
    if count(get_owned_pets()) == 0 then
        return
    end

    local owned_pets = get_owned_pets()
    local flag = false

    local pet = ClientData.get("pet_char_wrappers")[1]
    if pet and not _G.flag_if_no_one_to_farm then
		safeInvoke("ToolAPI/Unequip", pet.pet_unique, { use_sound_delay = true, equip_as_last = false })
    end

    local d2kitty = inv_get_category_unique("pets", "2d_kitty")
    if d2kitty and owned_pets[d2kitty] then
        safeInvoke("ToolAPI/Equip", d2kitty, { use_sound_delay = true, equip_as_last = false })
        flag = true
        _G.flag_if_no_one_to_farm = false
    end

    if not flag then
        if _G.InternalConfig.PotionFarm then
            if _G.InternalConfig.FarmPriority == "pets" then
                for k,v in pairs(owned_pets) do
                    if v.age == 6 and not _G.InternalConfig.AutoFarmFilter.PetsToExclude[v.remote] then
                        safeInvoke("ToolAPI/Equip", k, { use_sound_delay = true, equip_as_last = false }) 
                        if equiped() then flag = true; _G.flag_if_no_one_to_farm = false; break end
                    end
                end
            else
                for k,v in pairs(owned_pets) do
                    if (v.name:lower()):find("egg") then
                        safeInvoke("ToolAPI/Equip", k, { use_sound_delay = true, equip_as_last = false }) 
                        if equiped() then flag = true; _G.flag_if_no_one_to_farm = false; break end
                    end
                end
                if not flag then
                    for k,_ in pairs(owned_pets) do
                        safeInvoke("ToolAPI/Equip", k, { use_sound_delay = true, equip_as_last = false }) 
                        if equiped() then flag = true; _G.flag_if_no_one_to_farm = false; break end
                    end
                end
            end
        else
            if _G.InternalConfig.FarmPriority == "pets" then
                for k,v in pairs(owned_pets) do
                    if v.age < 6 and not _G.InternalConfig.AutoFarmFilter.PetsToExclude[v.remote] and not (v.name:lower()):match("egg") then
                        safeInvoke("ToolAPI/Equip", k, { use_sound_delay = true, equip_as_last = false })
                        if equiped() then flag = true; _G.flag_if_no_one_to_farm = false; break end
                    end
                end
            else
                for k,v in pairs(owned_pets) do
                    if not _G.InternalConfig.AutoFarmFilter.PetsToExclude[v.remote] and (v.name:lower()):match("egg") then
                        safeInvoke("ToolAPI/Equip", k, { use_sound_delay = true, equip_as_last = false }) 
                        if equiped() then flag = true; _G.flag_if_no_one_to_farm = false; break end
                    end
                end
            end

            if not flag and _G.InternalConfig.OppositeFarmEnabled and not _G.flag_if_no_one_to_farm then
                for k,v in pairs(owned_pets) do
                    if v.rarity == "legendary" then
                        safeInvoke("ToolAPI/Equip", k, { use_sound_delay = true, equip_as_last = false }) 
                        if equiped() then flag = true; _G.flag_if_no_one_to_farm = true; _G.random_farm = true; break end
                    end
                end
            end

            if not flag and not _G.flag_if_no_one_to_farm then
                for k,_ in pairs(owned_pets) do
                    safeInvoke("ToolAPI/Equip", k, { use_sound_delay = true, equip_as_last = false }) 
                    if equiped() then flag = true; _G.flag_if_no_one_to_farm = true; _G.random_farm = true; break end
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
        return
    end

    pet_update()

    local eqpetailms = get_equiped_pet_ailments()
    if next(eqpetailms) == nil then return end

    for k,_ in pairs(eqpetailms) do
        if StateDB.active_ailments[k] then
            -- уже в обработке
        else
            if pet_ailments[k] then
                StateDB.active_ailments[k] = true
                if k == "mystery" then
                    queue:asyncrun({("ailment pet: " .. k), pet_ailments[k]})
                else
                    queue:enqueue({("ailment pet: " .. k), pet_ailments[k]})
                end
            end
        end
    end
end

local function step_baby_autofarm()
    if ClientData.get("team") ~= "Babies" then
		safeInvoke("TeamAPI/ChooseTeam", "Babies", { dont_respawn = true, source_for_logging = "avatar_editor" })
        return
    end

    if not _G.InternalConfig.FarmPriority then
        local pet = ClientData.get("pet_char_wrappers")[1]
        if pet then
			safeInvoke("ToolAPI/Unequip", pet.pet_unique, { use_sound_delay = true, equip_as_last = false })
        end
    end

    local active_ailments = get_baby_ailments()
    for k,_ in pairs(active_ailments) do
        if not StateDB.baby_active_ailments[k] and baby_ailments[k] then
            StateDB.baby_active_ailments[k] = true
            queue:enqueue({("ailment baby " .. k), baby_ailments[k]})
        end
    end
end

local function async_auto_buy()
    local key = _G.InternalConfig.AutoFarmFilter and _G.InternalConfig.AutoFarmFilter.EggAutoBuy
    if not key or not InventoryDB.pets[key] then
        Cooldown.AutoBuyEgg = math.huge()
        return
    end
    local cost = InventoryDB.pets[key].cost
    if not cost or cost <= 0 then
        Cooldown.AutoBuyEgg = math.huge()
        return
    end

    local farmd = farmed.money
        safeInvoke("ShopAPI/BuyItem", "pets", key, { buy_count = math.floor(ClientData.get("money") / cost) })
    farmed.money = farmd
end

local function init_auto_recycle()
    local pet_to_exchange = {}
    local owned_pets = get_owned_pets()
    if not owned_pets then return end

    if not _G.InternalConfig.PetExchangeRarity then
        for k,v in pairs(owned_pets) do
            if v.age == _G.InternalConfig.PetExchangeAge then pet_to_exchange[k] = true end
        end
    else
        for k,v in pairs(owned_pets) do
            if v.age == _G.InternalConfig.PetExchangeAge and v.rarity == _G.InternalConfig.PetExchangeRarity then
                pet_to_exchange[k] = true
            end
        end
    end

	safeInvoke("HousingAPI/ActivateInteriorFurniture",
		"f-9",
		"UseBlock",
		{ action = "use", uniques = pet_to_exchange },
		LocalPlayer.Character
	)
end

local _TRADE_CONN = {}
local function init_auto_trade_setup()
    local user = _G.InternalConfig.AutoTradeFilter.PlayerTradeWith
    if not user or user == "" then return end

    local exist = game.Players:FindFirstChild(user) ~= nil

    table.insert(_TRADE_CONN, game.Players.PlayerAdded:Connect(function(player)
        if player.Name == user then
            player.CharacterAdded:Wait()
            exist = true
        end
    end))
    table.insert(_TRADE_CONN, game.Players.PlayerRemoving:Connect(function(player)
        if player.Name == user then exist = false end
    end))

    Scheduler.add("auto_trade_loop", 1, function()
        if not exist then return end

        local pets_to_send = {}
        local r = send_trade_request(user)
        if r == "No response" then
            print("[!] No response.")
            Scheduler.cancel("auto_trade_loop")
            Scheduler.add("auto_trade_loop", _G.InternalConfig.AutoTradeFilter.TradeDelay or 40, function() init_auto_trade_setup(user) end)
        end

        run_parallel(function()
            local owned_pets = get_owned_pets()
            local exclude = {}
            if _G.InternalConfig.AutoTradeFilter.ExcludeFriendly then
                for k,v in pairs(owned_pets) do if v.friendship > 0 then exclude[k] = true end end
            end
            if _G.InternalConfig.AutoTradeFilter.ExcludeEggs then
                for k,v in pairs(owned_pets) do if (v.name:lower()):match("egg") then exclude[k] = true end end
            end
            if _G.InternalConfig.AutoTradeFilter.SendAllFarmed then
                for _,v in ipairs(StateDB.total_fullgrowned) do if owned_pets[v] and not exclude[v] then pets_to_send[v] = true end end
            end
            if _G.InternalConfig.AutoTradeFilter.SendAllType then
                if type(_G.InternalConfig.AutoTradeFilter.SendAllType) == "number" then
                    for k,_ in pairs(inv_get_pets_with_age(_G.InternalConfig.AutoTradeFilter.SendAllType)) do if not pets_to_send[k] and not exclude[k] then pets_to_send[k] = true end end
                else
                    for k,_ in pairs(inv_get_pets_with_rarity(_G.InternalConfig.AutoTradeFilter.SendAllType)) do if not pets_to_send[k] and not exclude[k] then pets_to_send[k] = true end end
                end
            end

            if count(pets_to_send) == 0 then
                print("[TradeLog] Internal pet list is empty. Timeout: [3600]s.")
                return
            end

            pcall(function()
                for k,_ in pairs(pets_to_send) do
                    safeFire("TradeAPI/AddItemToOffer", k)
                    task.wait(0.2)
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

            print("[+] Trade successed.")
            if _G.InternalConfig.AutoTradeFilter.WebhookEnabled then
                webhook("TradeLog", ("Trade with %s successed."):format(user))
            end
        end)
    end)
end

local function async_lurebox_farm()
    queue:enqueue({ "bait_check", function()
        to_home()
        if not pcall(function() return debug.getupvalue(LureBaitHelper.run_tutorial, 11)() end) then end
            safeInvoke("HousingAPI/ActivateFurniture", LocalPlayer, furn.lurebox.unique, "UseBlock", { bait_unique = inv_get_category_unique("food", "ice_dimension_2025_ice_soup_bait") }, LocalPlayer.Character)
            safeInvoke("HousingAPI/ActivateFurniture", LocalPlayer, furn.lurebox.unique, "UseBlock", false, LocalPlayer.Character)
        task.wait(0.5)
        _G.bait_placed = pcall(function() return debug.getupvalue(LureBaitHelper.run_tutorial, 11)() end)
        _G.can_proceed = true
    end})
end

local function async_gift_autoopen()
    local gifts = get_owned_category("gifts")
    if not gifts or count(gifts) < 1 then
        Cooldown.GiftsAutoOpen = 3600
        return
    end
    run_parallel(function()
        for k,v in pairs(gifts) do
            pcall(function()
                local id = v.id or (v.remote and v.remote) or k
                if tostring(id):lower():match("box") or tostring(id):lower():match("chest") then
                    safeInvoke("LootBoxAPI/ExchangeItemForReward", id, v)
                else
                    safeInvoke("ShopAPI/OpenGift",v)
                end
            end)
            task.wait(0.5)
        end
    end)
    Cooldown.GiftsAutoOpen = 3600
end
local function async_auto_give_potion()
    local function get_potions()
        local potions = {}
        for k,v in pairs(get_owned_category("food")) do
            if (v.id:lower()):match("potion") then table.insert(potions, k) end
        end
        return #potions > 0 and potions or nil
    end

    local potions = get_potions()
    if not potions then
        Cooldown.AutoGivePotion = 900
        return
    end

    local pets_to_grow = {}
    local owned_pets = get_owned_pets()
    if _G.InternalConfig.AutoGivePotion ~= "any" then
        for _,name in ipairs(_G.InternalConfig.AutoGivePotion) do
            local pet = inv_get_category_unique("pets", name)
            if owned_pets[pet] and owned_pets[pet].age < 6 and not (owned_pets[pet].name:lower()):match("egg") then
                pets_to_grow[pet] = true
            end
        end
    else
        for k,v in pairs(owned_pets) do
            if v.age < 6 and not (v.name:lower()):match("egg") then pets_to_grow[k] = true end
        end
    end

    run_parallel(function()
        local first_equiped_pet = ClientData.get("pet_char_wrappers")[1]
        for pet_unique,_ in pairs(pets_to_grow) do
            local potions_local = { table.unpack(potions) }
            if #potions_local > 0 then
                local equiped_pet = ClientData.get("pet_char_wrappers")[1]
                if equiped_pet then
                    safeInvoke("ToolAPI/Unequip", equiped_pet.pet_unique, { use_sound_delay = true, equip_as_last = false }) 
                    wait_for(function() return not equiped() end, 3)
                    safeInvoke("ToolAPI/Equip", pet_unique, { use_sound_delay = true, equip_as_last = false }) 
                    wait_for(function() return equiped() end, 5)
                end

                for i,unique_id in ipairs(potions_local) do
                    local others = {}
                    for j,p in ipairs(potions_local) do if j ~= i then table.insert(others, p) end end
                        safeInvoke("PetObjectAPI/CreatePetObject", "__Enum_PetObjectCreatorType_2", { additional_consume_uniques = others, pet_unique = pet_unique, unique_id = unique_id })
                    task.wait(1)
                end
            end
        end

		safeInvoke("ToolAPI/Equip", first_equiped_pet and first_equiped_pet.pet_unique or actual_pet.unique or "", { use_sound_delay = true, equip_as_last = false })
    end)

    Cooldown.AutoGivePotion = 900
end


local function init_mode() 
	if _G.InternalConfig.Mode == "bot" then
		RunService:Set3dRenderingEnabled(false)
	else
		-- playable optmization
	end
end

local function trackInstance(inst)
    table.insert(_CLEANUP_INSTANCES, inst)
    return inst
end
local function trackConnection(conn)
    if conn then
        table.insert(_CONNECTIONS, conn)
    end
    return conn
end

local function cleanupAll()
    _G.__RUNNING = false

    for name, _ in pairs(Scheduler.tasks) do
        pcall(function() Scheduler.cancel(name) end)
    end

    for _, conn in ipairs(_CONNECTIONS) do
        if conn and conn.Disconnect then
            pcall(function() conn:Disconnect() end)
        end
    end
    _CONNECTIONS = {}

    for _, inst in ipairs(_CLEANUP_INSTANCES) do
        if inst and inst.Destroy then
            pcall(function() inst:Destroy() end)
        end
    end
    _CLEANUP_INSTANCES = {}

    if queue and queue.clear then
        pcall(function() queue:clear() end)
    end
    table.clear(StateDB.active_ailments)
    table.clear(StateDB.baby_active_ailments)
    StateDB.total_fullgrowned = {}

    collectgarbage("collect")
    print("[+] cleanupAll finished")
end

local function register_background_tasks()
    Scheduler.add("internal_countdown", 1, function()
        Cooldown.AutoBuyEgg = math.max(0, Cooldown.AutoBuyEgg - 1)
        Cooldown.GiftsAutoOpen = math.max(0, Cooldown.GiftsAutoOpen - 1)
        Cooldown.AutoGivePotion = math.max(0, Cooldown.AutoGivePotion - 1)
        Cooldown.LureboxFarm = math.max(0, Cooldown.LureboxFarm - 1)
    end)

    Scheduler.add("optimized_waiting", 1, function()
        if _G.InternalConfig.EggAutoBuy and (Cooldown.AutoBuyEgg <= 0) then
            pcall(async_auto_buy)
            Cooldown.AutoBuyEgg = Cooldown.AutoBuyEgg or 3600
        end

        if _G.InternalConfig.LureboxFarm and (Cooldown.LureboxFarm <= 0) then
            pcall(async_lurebox_farm)
            Cooldown.LureboxFarm = Cooldown.LureboxFarm or 3600
        end

        if _G.InternalConfig.GiftsAutoOpen and (Cooldown.GiftsAutoOpen <= 0) then
            pcall(async_gift_autoopen)
            Cooldown.GiftsAutoOpen = Cooldown.GiftsAutoOpen or 3600
        end

        if _G.InternalConfig.AutoGivePotion and (Cooldown.AutoGivePotion <= 0) then
            pcall(async_auto_give_potion)
            Cooldown.AutoGivePotion = Cooldown.AutoGivePotion or 900
        end
    end)

    if _G.InternalConfig.FarmPriority then
        Scheduler.add("autofarm_loop", 1, function()
            pcall(step_autofarm)
        end)
    end

    if _G.InternalConfig.BabyAutoFarm then
        Scheduler.add("baby_autofarm_loop", 1, function()
            pcall(step_baby_autofarm)
        end)
    end

    if _G.InternalConfig.AutoRecyclePet then
        Scheduler.add("auto_recycle_periodic", 60, function()
            pcall(init_auto_recycle)
        end)
    end

    if _G.InternalConfig.PetAutoTrade then
        pcall(init_auto_trade_setup)
    end

    if _G.InternalConfig.DiscordWebhookURL then
        Scheduler.add("webhook_logger", _G.InternalConfig.WebhookSendDelay or 3600, function()
            pcall(function()
                webhook("AutoFarm Log",
                    ("**💸Money Earned :** %s\n**📈Pets Full-grown :** %s\n**🐶Pet Needs Completed :** %s\n**🧪Potions Farmed :** %s\n**🧸Friendship Levels Farmed :** %s\n**👶Baby Needs Completed :** %s\n**🥚Eggs Hatched :** %s")
                    :format(farmed.money, farmed.pets_fullgrown, farmed.ailments, farmed.potions, farmed.friendship_levels, farmed.baby_ailments, farmed.eggs_hatched)
                )
            end)
        end)
    end

	init_mode()
end

local function create_stats_gui()
    local existing = CoreGui:FindFirstChild("StatsOverlay")
    if existing then
        trackInstance(existing)
        return existing
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "StatsOverlay"
    gui.ResetOnSpawn = false
    gui.Parent = CoreGui
    trackInstance(gui)

    local frame = Instance.new("Frame")
    frame.Name = "StatsFrame"
    frame.Size = UDim2.new(0, 250, 0, 150)
    frame.Position = UDim2.new(0, 5, 0, 5)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.3
    frame.Parent = gui
    trackInstance(frame)

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
        trackInstance(label)
        return label
    end

    createLabel("bucks", "💸Bucks earned", 0)
    createLabel("fullgrown", "📈Pets full-grown", 1)
    createLabel("pet_needs", "🐶Pet needs completed", 2)
    createLabel("potions", "🧪Potions farmed", 3)
    createLabel("friendship", "🧸Friendship levels farmed", 4)
    createLabel("baby_needs", "👶Baby needs completed", 5)
    createLabel("eggs", "🥚Eggs hatched", 6)

    return gui
end

local function __init()
    print("[?] Starting init sequence...")
    _G.__RUNNING = true

	task.spawn(function()
		while _G.__RUNNING do
			Scheduler.tick(os.clock())
			task.wait(0.1)
		end
	end)

    create_stats_gui()
    register_background_tasks()
    table.insert(_CONNECTIONS, NetworkClient.ChildRemoved:Connect(function()
        local function send_responce()
            return HttpService:RequestAsync({ Url = "https://example.com", Method = "GET" })
        end
        repeat
            print("No internet. Waiting..")
            task.wait(5)
            local success, _ = pcall(send_responce)
        until success
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
    end))

    table.insert(_CONNECTIONS, LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end))

    if _G.InternalConfig.PetAutoTrade and _G.InternalConfig.AutoTradeFilter and _G.InternalConfig.AutoTradeFilter.PlayerTradeWith then
        local user = _G.InternalConfig.AutoTradeFilter.PlayerTradeWith
        table.insert(_CONNECTIONS, game.Players.PlayerAdded:Connect(function(player)
            if player.Name == user then
                pcall(function() player.CharacterAdded:Wait() end)
            end
        end))
        table.insert(_CONNECTIONS, game.Players.PlayerRemoving:Connect(function(player)
        end))
    end

    pcall(function() Scheduler.add("optimized_waiting_immediate", 0, function() pcall(function() 
        if _G.InternalConfig.GiftsAutoOpen and Cooldown.GiftsAutoOpen <= 0 then async_gift_autoopen() end
        if _G.InternalConfig.EggAutoBuy and Cooldown.AutoBuyEgg <= 0 then async_auto_buy() end
        if _G.InternalConfig.LureboxFarm and Cooldown.LureboxFarm <= 0 then async_lurebox_farm() end
        if _G.InternalConfig.AutoGivePotion and Cooldown.AutoGivePotion <= 0 then async_auto_give_potion() end
    end) end, { once = true, immediate = true }) end)

    print("[+] Init registered in Scheduler")
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
	print("[?] Starting..")
	for k, v in pairs(getupvalue(require(ReplicatedStorage.ClientModules.Core:WaitForChild("RouterClient"):WaitForChild("RouterClient")).init, 7)) do
		v.Name = k
	end
	print("[+] API dehashed.")
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
Scheduler.add("launch_screen_once", 0, function()
    if LocalPlayer.Character then
        Scheduler.cancel("launch_screen_once")
        return
    end

    wait_for(function()
        local ok, enabled = pcall(function() return LocalPlayer.PlayerGui and LocalPlayer.PlayerGui.AssetLoadUI and LocalPlayer.PlayerGui.AssetLoadUI.Enabled end)
        return ok and (enabled == false)
    end, 60, function()
		safeInvoke("TeamAPI/ChooseTeam", "Parents", { source_for_logging = "intro_sequence" })
        Scheduler.add("launch_hide_ui", 1, function()
            pcall(function()
                UIManager.set_app_visibility("MainMenuApp", false)
                UIManager.set_app_visibility("NewsApp", false)
                UIManager.set_app_visibility("DialogApp", false)
            end)
            Scheduler.cancel("launch_hide_ui")
        end, { once = true, immediate = true })

        safeInvoke("DailyLoginAPI/ClaimDailyReward")
        pcall(function() UIManager.set_app_visibility("DailyLoginApp", false) end)
        safeFire("PayAPI/DisablePopups")

        wait_for(function()
            local ok, res = pcall(function()
                return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer:FindFirstChild("PlayerGui")
            end)
            return ok and res
        end, 60, function()
            Scheduler.cancel("launch_screen_once")
        end, function()
            Scheduler.cancel("launch_screen_once")
        end)
    end, function()
        Scheduler.cancel("launch_screen_once")
    end)
end, { once = true, immediate = true })

Scheduler.add("furniture_init_once", 0, function()
    if not (_G.InternalConfig.FarmPriority or _G.InternalConfig.BabyAutoFarm or _G.InternalConfig.LureboxFarm) then
        Scheduler.cancel("furniture_init_once")
        return
    end

    pcall(to_home)

    local furniture = {}
    local filter = {
        bed = true, crib = true, shower = true, toilet = true, tub = true,
        litter = true, potty = true, lures2023normallure = true
    }

    pcall(function()
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
    end)

    pcall(function()
        local house_furn = ClientData.get("house_interior") and ClientData.get("house_interior")['furniture'] or {}
        for k,v in pairs(house_furn) do
            local id = (v.id or ""):lower():gsub("_", "")
            local part = furniture[id]
            if part then
                if id:find("bed") or id:find("crib") then
                    furn.bed = { id = v.id, unique = k, usepart = part.Name, cframe = part.CFrame }
                elseif id:find("shower") or id:find("bathtub") or id:find("tub") then
                    furn.bath = { id = v.id, unique = k, usepart = part.Name, cframe = part.CFrame }
                elseif id:find("litter") or id:find("potty") or id:find("toilet") then
                    furn.toilet = { id = v.id, unique = k, usepart = part.Name, cframe = part.CFrame }
                elseif id:find("lures2023normallure") then
                    furn.lurebox = { id = v.id, unique = k, usepart = part.Name, cframe = part.CFrame }
                end
            end
            if furn.bed and furn.bath and furn.toilet and furn.lurebox then break end
        end
    end)

    local function buy_and_find(kind, modelName, fallbackUsePart)
        local ok, result = pcall(function()
            return safeInvoke("HousingAPI/BuyFurnitures", { { kind = kind, properties = { cframe = CFrame.new() } } })
        end)
        if not ok or not result then return nil end
        local foundCFrame
        pcall(function()
            for _, folder in ipairs(game.Workspace.HouseInteriors.furniture:GetChildren()) do
                if folder:IsA("Folder") then
                    local model = folder:FindFirstChild(modelName)
                    if model and model:IsA("Model") then
                        local ub = model:FindFirstChild("UseBlocks")
                        if ub then
                            local part = ub:FindFirstChildWhichIsA("Part")
                            if part then foundCFrame = part.CFrame; break end
                        end
                    end
                end
            end
        end)
        return result, foundCFrame
    end

    if not furn.bed then
        local res, cf = buy_and_find("basicbed", "BasicBed", "Seat1")
        if res and cf then
            furn.bed = { id = "basicbed", unique = res["results"][1].unique, usepart = "Seat1", cframe = cf }
        end
    end
    if not furn.bath then
        local res, cf = buy_and_find("cheap_pet_bathtub", "CheapPetBathtub", "UseBlock")
        if res and cf then
            furn.bath = { id = "cheap_pet_bathtub", unique = res["results"][1].unique, usepart = "UseBlock", cframe = cf }
        end
    end
    if not furn.toilet then
        local res, cf = buy_and_find("ailments_refresh_2024_litter_box", "Toilet", "Seat1")
        if res and cf then
            furn.toilet = { id = "ailments_refresh_2024_litter_box", unique = res["results"][1].unique, usepart = "Seat1", cframe = cf }
        end
    end
    if not furn.lurebox then
        local res, cf = buy_and_find("lures_2033_normal_lure", "Lures2023NormalLure", "UseBlock")
        if res and cf then
            furn.lurebox = { id = "lures_2033_normal_lure", unique = res["results"][1].unique, usepart = "UseBlock", cframe = cf }
        end
    end

    pcall(function()
        if not HouseClient.is_door_locked() then HouseClient.lock_door() end
    end)

    print("[+] Furniture init done. Door locked.")
    Scheduler.cancel("furniture_init_once")
end, { once = true, immediate = true })

local function create_farm_part()
    local existing = workspace:FindFirstChild("FarmPart")
    if existing then
        trackInstance(existing)
        return
    end
    local ok, part = pcall(function()
        local p = Instance.new("Part")
        p.Size = Vector3.new(150, 1, 150)
        p.Position = Vector3.new(1000, 20, 1000)
        p.Name = "FarmPart"
        p.Anchored = true
        p.Parent = workspace
        return p
    end)
    if ok and part then trackInstance(part) end
end
create_farm_part()

pcall(license)
pcall(function() __init() end)
