--=======================================================================================================
-- BALESEE SCRIPT
--
-- Purpose:		Allows bales and pallets to show up on the PDA map as hotspots.
-- Author:		Mmtrx		
-- Changelog:
--  v1.0		03.01.2019	original FS17 version by akuenzi (akuenzi@gmail.com)
--	v1.1.0		28.08.2019	updates for FS19, added user interface  
--  v1.1.1		17.09.2019  added pallette support.
--  v1.1.2		08.10.2019	save statistics / add legend in debug mode 
--  v2.0.0.0	19.02.2020  add Gui (settings and statistics)
--  v2.0.0.1	19.06.2020  handle all pallet types, (e.g. straw harvest)
--  v2.1.0.0	30.06.2021  MULTIPLAYER! / handle all bale types, (e.g. Maizeplus forage extension)
--=======================================================================================================

----------------- New (or delete) Bale event 
SeeBalesEventNew = {}
SeeBalesEventNew_mt = Class(SeeBalesEventNew, Event)

InitEventClass(SeeBalesEventNew, "SeeBalesEventNew")

function SeeBalesEventNew:emptyNew()
    local self = Event:new(SeeBalesEventNew_mt)
	self.className = "SeeBalesEventNew"
    return self
end
function SeeBalesEventNew:new(object, farmId, hash, text, incr)
    local self = SeeBalesEventNew:emptyNew()
    self.object = object
	self.farmId = farmId
	self.hash = hash
	self.text = text
	if incr == nil then incr = true end
	self.incr = incr 	-- true/nil: increase count. false: decrease
    return self
end
function SeeBalesEventNew:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObjectId(streamId) 	
	self.farmId = streamReadInt8(streamId)
	self.hash = streamReadInt32(streamId)
	self.text = streamReadString(streamId)
	self.incr = streamReadBool(streamId)
	self:run(connection)
end
function SeeBalesEventNew:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteInt8(streamId, self.farmId)
	streamWriteInt32(streamId, self.hash)
	streamWriteString(streamId, self.text)
	streamWriteBool(streamId, self.incr)
end
function SeeBalesEventNew:run(connection)
    if g_client and connection:getIsServer() then
    	-- event was broadcast from server, we need to update clients table
    	print(("-- Event:run() called on client."))
    	DebugUtil.printTableRecursively(self,".",1,2)
    	local bs = g_baleSee
    	local bals = bs.bales[self.farmId]
    	local farm = self.farmId
    	local objId = self.object
    	local obj = g_client:getObject(objId) 
		--local myfa = g_currentMission:getFarmId()

    	if bals[self.hash] == nil then 				-- seen an new bale type
    		bals[self.hash] = {text = self.text, number = 0}
    		bs.numBalTypes[farm] = bs.numBalTypes[farm] +1
    	end
    	local inc = -1
    	if self.incr then 
    		-- count the bale, make hotspot
    		inc = 1 
    		local h, c, i
    		if obj then 
				h, c, i = bs:makeHotspot(obj, farm)
			end
			table.insert(bs.bHotspots[farm], {h,c,i, objId}) 
    	else -- delete hotspot
			bs:delhot(obj.mapHotspot, farm)
    	end
    	bals[self.hash].number = bals[self.hash].number + inc 
    	bs.numBales[farm] = bs.numBales[farm] + inc
    end
end
----------------------- SeeBales Events ----------------------------------------------
SeeBalesJoinEvent = {}
SeeBalesJoinEvent_mt = Class(SeeBalesJoinEvent, Event)
InitEventClass(SeeBalesJoinEvent, "SeeBalesJoinEvent")
function SeeBalesJoinEvent:emptyNew()
    local self = Event:new(SeeBalesJoinEvent_mt)
	self.className = "SeeBalesJoinEvent"
    return self
end
function SeeBalesJoinEvent:readStream(stream, conn)
	-- body
	if not conn:getIsServer() then 
		-- write current bales table to client
		conn:sendEvent(SeeBalesDataEvent:emptyNew())
	end	
end

SeeBalesDataEvent = {}
SeeBalesDataEvent_mt = Class(SeeBalesDataEvent, Event)
InitEventClass(SeeBalesDataEvent, "SeeBalesDataEvent")

function SeeBalesDataEvent:emptyNew()
    local self = Event:new(SeeBalesDataEvent_mt)
	self.className = "SeeBalesDataEvent"
    return self
end
function SeeBalesDataEvent:readStream(stream, conn)
	-- read initial bales table from server
	if conn:getIsServer() then 
		BaleSee:receiveData(stream)
	end	
end
function SeeBalesDataEvent:writeStream(stream, conn)
	-- send initial bales table to a client
	if not conn:getIsServer() then 
		BaleSee:sendData(stream)
	end	
end
