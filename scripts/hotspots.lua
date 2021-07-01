--=======================================================================================================
--  BALESEE HOTSPOT FUNCTIONS
--
-- Purpose:		Allows bales and pallets to show up on the PDA map as hotspots.
-- Author:		Mmtrx		
-- Changelog:
--  v1.0		03.01.2019	original FS17 version by akuenzi (akuenzi@gmail.com)
--	v1.1.0		28.08.2019	updates for FS19, added user interface  
--  v1.1.1		17.09.2019  added pallette support.
--  v1.1.2		08.10.2019	save statistics / add legend in debug mode 
--  v2.0.0		10.02.2020  add Gui (settings and statistics)
--  v2.0.0.1	19.06.2020  handle all pallet types, (e.g. straw harvest)
--  v2.1.0.0	30.06.2021  MULTIPLAYER! / handle all bale types, (e.g. Maizeplus forage extension)
--=======================================================================================================
-- ---------------Hotspots for bales.-----------------------------------------------------------
function BaleSee:delete()
	if g_server then 
		local bs = g_baleSee
		local hash = bs.baleIdToHash[self.id]
		local farm = self.ownerFarmId
		if hash == nil then
			dbprint(string.format("**Error SeeBales: trying to delete unknown bale id %s",self.id))
		elseif farm==nil or farm==0 then
			dbprint(string.format("**Error SeeBales: trying to delete bale id %s for unknown farm",self.id))
		else
			bs.bales[farm][hash].number = bs.bales[farm][hash].number -1
			bs.numBales[farm] = bs.numBales[farm] -1
			bs:delhot (self.mapHotspot, farm)
			-- broadcast to clients
			local bale = self
			g_server:broadcastEvent(SeeBalesEventNew:new(bale,farm,hash,"",false))
		end
	end
end;
function BaleSee:delhot(hotspot, farm)
	-- delete a bale hotspot
	if hotspot ~= nil then
		g_currentMission.hud.ingameMap:removeMapHotspot(hotspot);
		for i = 1, table.getn(self.bHotspots[farm]) do
			if self.bHotspots[farm][i][1] == hotspot then
		    	table.remove(self.bHotspots[farm], i)
		    	break
			end
		end
	end;
end;
function BaleSee:addObject(obj, id)
	-- called when client first sees a bale obj
	if g_server or not obj:isa(G0.Bale) then return end
	local bs = g_baleSee
	dbprint(string.format("- addObject(): %s / %s",obj.id, id))
	-- create hotspot, if this bale does not have one yet
	local hs, col, img 
	local found = false
	for f = 1,8 do
		if #bs.bHotspots[f] > 0 then
			for i,h in ipairs(bs.bHotspots[f]) do
				if h[4]==id and h[1] == nil then
					hs, col, img = bs:makeHotspot(obj, f)
					bs.bHotspots[f][i] = {hs, col, img, id}
					-- set farmId (original game does it not on clients)
					obj:setOwnerFarmId(f)
					found = true
					break
				end
			end
		end
		if found then break end
	end	
end
function BaleSee:newBale()
	--[[ 
	Bales are created through Baler:createBale(), Bale:loadFromXMLFile(), and BuyableBale:loadBaleAtPosition()
	all of these call Bale:register(), if running on server. So we append that. Baler:finishBale() calls createBale(), 
	and also broadcasts BalerCreateBaleEvent to clients
	For clients in MP we broadcast our NewEvent, so they can update their bales table
	]]
	if not g_server then
		print("**Error SeeBales: newBale() was called on client")
		return
	end
	local bs,bale = g_baleSee, self
	local farm = bale.ownerFarmId
	local h,c,i,isRoundbale = bs:makeHotspot(bale, farm)
	table.insert(bs.bHotspots[farm], {h,c,i, bale.id}) 

	-- update count for this bale type
	local hash,txt = bs:updBales(bale, farm, isRoundbale, 1)
	g_server:broadcastEvent(SeeBalesEventNew:new(bale,farm,hash,txt,true))
end;
function BaleSee:makeHotspot( bale, farmId )
	-- create map hotspot for bale object
	local bs = g_baleSee
	local isRoundbale = Utils.getNoNil(getUserAttribute(bale.nodeId, "isRoundbale"), false)
	if bs.debug then
		local x,y,z = getWorldTranslation(bale.nodeId)
		print(string.format("-- makeHotspot(): %s %s %s Bale %d/%s (%sl) of farm %s at %4.2f %4.2f.", 
			bs.visible[bs.baleState], bs.isRound[isRoundbale],
			bs.ft[bale.fillType].name, bale.id,
			tostring(bale.nodeId), tostring(bale.fillLevel), tostring(farmId), x, z))	
	end;
	local color = 	bs:getColor(bale)
	local uv 	= 	bs.uvB
	local image = 	bs:getIcon(bale)
	local sep = 	" "
	if g_gui.languageSuffix == "_de" then sep = "-" end
	local nam = string.format("%s%s%s %s",bs.ft[bale.fillType].title,sep, g_i18n:getText("unit_bale"), bale.id)
	
	-- Generate bale hotspot. Category = 6 to distinguish from others
	local hotspot = MapHotspot:new(nam, MapHotspot.CATEGORY_TOUR)
	hotspot.baleSee = true
	hotspot.bsImage = image
	-- following hotspot attributes need to be set, depending on baleState:
	-- baleState	bgImage, 	image, 	color, 	uv, 	scal
	-- ----------------------------------------------------------
	--	icon    2 	set 		set 	nil 	nil 	1.0
	-- 	dot		3 	nil 		nil 	set 	set 	0.8
	if bs.baleState == 2 then
		-- Hotspots will be small images/icons.
		hotspot:setImage(image, nil, nil)
		hotspot:setBackgroundImage(bs.bgImage, nil, nil)	
		hotspot:setSize(bs:getSize("icon"))	 
	else
		-- Hotspots will be small colored circles.
		hotspot:setIconScale(0.8)
		hotspot:setImage(nil, uv, color) 					-- colored circle 
		hotspot:setBackgroundImage(nil, uv, nil)			-- black circle
		hotspot:setSize(bs:getSize("dot"))					-- size for small cicrcles
	end;
	hotspot.enabled = bs.baleState > 1					
	hotspot.verticalAlignment = Overlay.ALIGN_VERTICAL_MIDDLE		
	hotspot:setLinkedNode(bale.nodeId)			-- also sets the x,z MapPos
	hotspot:setOwnerFarmId(farmId)

	bale.mapHotspot = hotspot 				-- property of the bale object
	g_currentMission.hud.ingameMap:addMapHotspot(hotspot) 
	return hotspot,color,image,isRoundbale
end;
function BaleSee.showContextBox(mapFrame, hotspot, description, imageFilename, uvs, farmId)
	-- if it's one of our hotspots, then set image filename for details box 
	-- So that also "dot markers" display an image in details box
	if hotspot.baleSee then
		mapFrame.contextImage:setImageFilename(hotspot.bsImage)
		mapFrame.contextImage:setImageUVs(GuiOverlay.STATE_NORMAL, unpack(Overlay.DEFAULT_UVS))

	-- add farm text in hotspot details box for MP
		if g_baleSee.isMultiplayer then
			local farm = g_farmManager:getFarmById(hotspot.ownerFarmId)
			mapFrame.contextFarm:setText(farm.name)
			mapFrame.contextFarm:setTextColor(unpack(farm:getColor()))
		end
	end
end;
