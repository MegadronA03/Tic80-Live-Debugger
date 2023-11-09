local Game = {
	State = {
		--DumpConfig = { -- skip over memory that already updated by mem functions hooks
		--	{0,32768},
		--	{65408,}
		--},
		Mem = {},
		MemC = {},
		Func = {
			vbank = 0,
		}
	}
}

local Debug = {
	ToggleKey = 44, -- ` (aka GRAVE)
	ToolMenu = {
		ActiveID = 0,
		ActiveRef = {},
		Items = {
			{
				name = "Variable browser",
				env = _G,
				TIC = function()
					
				end
			},
			{
				name = "Console",
				logstr = "",
				inputstr = "",
				TIC = function()
				
				end
			},
			{
				name = "Debug Settings",
				TIC = function()
				
				end
			}
		}
	},
	Orig = {
		TIC = TIC,
		OVR = OVR,
		time = time,
		vbank = vbank
	}
}

Debug.ToolMenu.Items[0] ={
	name = "Runtime Debugger",
	--step_key = 64, -- shift key TODO: create bind menu
	record = false, -- to step a frame release shift with desired keys
	TIC = function()
		local step_key = 65
		print("release ALT to step 1 frame",1,8,5)
		if key(step_key) then
			record=true
		elseif record then
			record=false
			Debug.Toggle()
			--instaed of actually unpausing, just execute everything here
			--TODO: BDR missing
			Game.TIC()
			Debug.Orig.vbank(1)
			if Game.OVR then Game.OVR() end
			Debug.Orig.vbank(Game.State.Func.vbank)
			Debug.Toggle()
		end
	end
}

local AE = Game

--TODO: implement frame fixed delta
Debug.Time = {
	DTS = 0.0, -- delta time stamp
	--timestamps to hide debugger from time()
	ECT = 0.0, -- env change timestamp
	EET = 0.0, -- env elapsed time
	Lcall = 0.0, --locally to the debug env
	Scale = 1.0,
	FDB = 0, -- frame delay budget
	FE = 0, -- frame executions
	FScale = 1.0
} 
Game.Time = {
	EET = 0.0, -- env elapsed time
	Lcall = 0.0, --locally to the game env
	Scale = 1.0,
	FDB = 0,
	FE = 0, -- frame executions
	FScale = 1.0
}

Game.State.Save = function()
	--naive method
	--for i=0,85540 do
	--	Game.State.Mem[i] = Debug.Orig.peek(i)
	--end
	--pmem, memcpy method
	local pm = {}
	for i=0,255 do
		pm[i]=pmem(i)
	end
	local gs = Game.State
	--dump all RAM
	local cm = {}
	for k=0,95 do
		memcpy(81924,k<<10,1024) -- corrupt the hell
		for i=0,255 do
			local d
			local mi = (k<<8)+i
			if (mi > 20480) and (mi < 20736) then
				d = pm[mi-20481]
			else
				d = pmem(i)
			end
			--[[
			if cm[1] then
				if d == (d>>8) then
					if cm[#cm][1] == d then
						cm[#cm][1] = cm[#cm][1] + 1
					else
						cm[#cm+1] = {d,1}
					end
				else
					cm[#cm+1] = {d,0}
				end
			else
				cm[#cm+1] = {d,0}
			end]]
			gs.Mem[mi]=d
		end
	end
	--restore pmem
	for i=0,255 do
		pmem(i,pm[i])
		--gs.Mem[20481+i]=pm[i]
	end
end

Game.State.RestoreScreen = function()
	for i,e in pairs(Game.State.Func) do
		Debug.Orig[i](e)
	end
	for k=0,15 do
		for b=0,255 do
			pmem(b,Game.State.Mem[(k<<8)+b])
		end
		memcpy(k<<10,81924,1024)
	end
	
	for i=0,255 do
		pmem(i,Game.State.Mem[20481+i])
	end
	--[[
	local rb = 0
	for i,e in pairs(Game.State.MemC) do
		if e[2] == 0 then
			for i=0,31,8 do
				poke(rb,e[1]>>i)
				rb = rb + 1
			end
		else
			local sl = e[2]<<2
			memset(rb,e[1],sl)
			rb = rb + sl
		end
	end]]
end

Game.State.Restore = function()
	for i,e in pairs(Game.State.Func) do
		Debug.Orig[i](e)
	end
	for i,e in ipairs(Game.State.Mem) do
		local ip = i & 255
		pmem(ip,e)
		if ip == 255 then
			memcpy((i-255)<<2,81924,1024)
		end
	end
	for i=0,255 do
		pmem(i,Game.State.Mem[20481+i])
	end
	--[[
	local rb = 0
	for i,e in pairs(Game.State.MemC) do
		if e[2] == 0 then
			for i=0,31,8 do
				poke(rb,e[1]>>i)
				rb = rb + 1
			end
		else
			local sl = e[2]<<2
			memset(rb,e[1],sl)
			rb = rb + sl
		end
	end]]
end

Debug.TIC = function()
	for c=0,3 do
		sfx(-1, nil, nil, c)
	end
	music(-1)
	Debug.ToolMenu.ActiveRef.TIC()
end

Debug.BDR = function(scanline)
	
end

Debug.OVR = function(scanline)
	
	--Debug.ToolMenu.ActiveRef.OVR()
	vbank(0)
	memset(0,0xCC,840)
	print(Debug.ToolMenu.ActiveRef.name,1,1)
end

Debug.BOOT = function()
	--what
end

Debug.MENU = function(item)
	--show notification for menu emulation
end

Debug.IsActive = function()
	return (Debug.Orig.TIC == Debug.TIC)
end

-- TODO: variable freezing
--Debug.After = {
--	TIC = function()
--		
--	end,
--	OVR = function()
--	
--	end
--}

local function Frame(f)
	local te = AE.Time
	for i=1,te.FE do
		f()
	end
end

Debug.GameOverlay = function()
	if not Debug.IsActive() then
		--local of = Debug.Orig
		--Debug.Orig.vbank(0)
		print("GTLC "..tostring(Game.Time.Lcall))
		--Game.State.Restore()
	end
end

--here are debug hooks
Debug.Hook = {
	TIC = function()
		if keyp(Debug.ToggleKey) then
			Debug.Toggle()
		end
		local te = AE.Time
		te.FDB = te.FDB - te.FScale
		te.FE = 0
		if not Debug.IsActive() then
			Game.State.RestoreScreen()
		end
		for i=math.floor(te.FDB),0 do
			Debug.Orig.TIC()
			if not Debug.IsActive() then
				Game.State.Save()
			end
			--Debug.Orig[exec]()
			--Debug.After[exec]()
			--te.FDB = te.FDB + 1
			te.FE = te.FE + 1
		end
		te.FDB = te.FDB + te.FE
	end,
	OVR = function()
		--Frame(Debug.Orig.OVR) --more accurate but have issues
		if Debug.Orig.OVR then Debug.Orig.OVR() end --doesnt have blinking
		Debug.GameOverlay()
	end,
	time = function() 
		local dbt = Debug.Time
		--TODO: remove ifs
		local te = AE.Time
		local ts = Debug.Orig.time() - te.EET
		local d = ts - dbt.DTS -- delta
		dbt.DTS = ts
		te.Lcall = te.Lcall + (d * te.Scale)
		return te.Lcall
	end,
	vbank = function(v)
		if not Debug.IsActive() then
			Game.State.Func.vbank = v
		end
		Debug.Orig.vbank(v)
	end
}

Debug.Toggle = function()
	local of = Debug.Orig
	local ts = of.time()
	if Debug.IsActive() then 
		Game.State.Restore()
		AE = Game
	else
		Game.State.Save()
		AE = Debug
	end
	Debug.Orig.TIC = AE.TIC
	SCN = AE.BDR
	BDR = AE.BDR
	OVR = AE.OVR
	BOOT = AE.BOOT
	MENU = AE.MENU
	local te = AE.Time
	te.EET = te.EET - Debug.Time.ECT + ts
	Debug.Time.ECT = ts
end

Debug.InitHooks = function()
	--TIC defined after lib load
	--Debug.Orig.TIC = TIC
	--Debug.Orig.OVR = OVR
	--load hooks
	for i,e in pairs(Debug.Hook) do
		Debug.Orig[i] = _ENV[i]
		_ENV[i] = e
	end
	--TIC = Debug.Hook.TIC
end

Debug.Init = function()
	--init timer
	Debug.Time.DTS = Debug.Orig.time()
	--apply hooks
	Debug.InitHooks()
	--init tool menu
	Debug.ToolMenu.ActiveRef = Debug.ToolMenu.Items[Debug.ToolMenu.ActiveID]
	--save active routines
	Game.TIC = Debug.Orig.TIC
	Game.BDR = SCN or BDR
	Game.OVR = OVR
	Game.BOOT = BOOT
	Game.MENU = MENU
	Game.State.Save()
end

return {Init=Debug.Init,Debug=Debug,Game=Game,_VERSION="0.0.1"}