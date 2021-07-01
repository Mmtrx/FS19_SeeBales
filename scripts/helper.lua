--=======================================================================================================
--  BALESEE HELPER FUNCTIONS
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
function BaleSee:updBales(object,farmId,isRound,inc)
	-- adjust count in self.bales[]. Currently inc is always +1, because delete() does its own decrease
	local ft = object.fillType 		-- works, if it's a bale
	local cap = math.floor(object.fillLevel/1000)
	local hash = 100000* (isRound and 1 or 0) + 100* ft + cap
	if self.bales[farmId] [hash] == nil then
		if self.debug then
			print(("** new bale fillType %d %s for farm %d. Hash: %d"):format(ft,
				self.ft[ft].name,farmId,hash))
		end
		self.bales[farmId][hash] = {
		 text = string.format("%s (%s %dk)", self.ft[ft].title, self.isRound[isRound], cap),
		 number = 0}
		self.numBalTypes[farmId] = self.numBalTypes[farmId] + 1	 -- update # bale types
	end
	self.bales[farmId][hash].number = self.bales[farmId][hash].number +inc  -- update bale type
	self.numBales[farmId] = 		self.numBales[farmId] + inc	 			-- update bales sum
	self.baleIdToHash[object.id] = hash 
	return hash, self.bales[farmId][hash].text
end;
function BaleSee:updPallets(object, farm, inc)
	-- adjust count in .pallets[farm] 
	if farm == nil then 
		print(string.format("**Error SeeBales: Pallet %s has no farm",
			object.rootNode))
		return
	end	
	local ft = object:getFillUnitFillType(1)
	if self.pallets[farm][ft] == nil then
		self.pallets[farm][ft] = 0
		if self.debug then
			print(("-- new pallet fillType %d %s"):format(ft,self.ft[ft].name))
		end
	end
	self.pallets[farm][ft] = self.pallets[farm][ft] +inc  -- update pallet type
	if self.debug then print(("--updPallets(%s, %d, %d): updated .pallets[%s]"):
		format(object.rootNode,farm,inc,self.ft[ft].name))
	end
	self.numPals[farm] = self.numPals[farm] + inc	 	-- update pallets sum
end;
function BaleSee:getSize(typ)
	-- return icon / dotmarker size in u.v coordinates
	local isiz = self.symSizes[self.dispSize]
	return unpack(isiz[typ])
end;
function BaleSee:getColor(object)
	-- return color depending on filltype of bale/ pallet object 
	local ret = {1,1,1,1} 				-- default
	local ft = object.fillType 		-- works, if it's a bale

	if ft == nil then 					-- it's a pallet, vehicle object.
		ft = object:getFillUnitFillType(1)
		if self.pallCols[ft] ~= nil and self.pallCols[ft][1] ~= nil then
			ret = self.pallCols[ft][1]
		end
	elseif self.baleCols[ft] ~= nil and self.baleCols[ft][1] ~= nil then
			ret = self.baleCols[ft][1]
	end
	return ret 		
end;
function BaleSee:getIcon(object)
	-- return icon image depending on filltype of BALE object 
	local image   = Utils.getFilename(self.icons.squareStraw, self.directory); -- default image: FillType.STRAW
	local fill 	  = object.fillType
	
	-- select correct image, based on filltype
	if self.baleCols[fill] ~= nil then
		if object.baleDiameter and self.baleCols[fill][2] ~= nil then
			image = self.baleCols[fill][2] 
		elseif object.baleDiameter == nil and self.baleCols[fill][3] ~= nil then 
			image = self.baleCols[fill][3] 
		end			
	end
	return image
end;
function BaleSee:getImage(object, ft)
	-- find image source for the PALLET icon display
	local image = Utils.getFilename(self.icons.otherPallet, self.directory); --default image
	if ft ~= nil and self.pallCols[ft] ~= nil and self.pallCols[ft][2] ~= nil then
		return self.pallCols[ft][2]
	end
	if object.configFileName then
		local storeItem = g_currentMission.shopController.storeManager.xmlFilenameToItem[
			string.lower(object.configFileName)]
		if storeItem and storeItem.imageFilename then
			image = storeItem.imageFilename
	-- error in FS19 data: fillablePallet.xml, woolPallet.xml <image> says: data/store/store_pallet_saplings.png
	-- chgd to $data/objects/pallets/palletPoplar/store_pallet_saplingsPoplar.png
	-- (the png is the std plain wooden box pallet)
			if string.match(image, "data/store/") then
				image = "data/objects/pallets/palletPoplar/store_pallet_saplingsPoplar.png"
			end
		end;
	end;
	return image
end
function BaleSee:makeLegend()
	-- show all bale/pallet hotspot markers:
	local w,h = getNormalizedScreenValues(16,16)
	local x,z = -1000, -1000
	local uvP = getNormalizedUVs({520, 520, 240, 240})
	local uvB = getNormalizedUVs({776, 776, 240, 240})
	local files = self.icons
	local image
	local function isbale( ft )		-- true if ft is bale fillType
		return self.baleCols[ft] ~= nil
	end;

	local ct = 1
	for i=1,#self.ft do
		if self.baleCols[i] ~= nil or self.pallCols[i] ~= nil then 
			-- ------------ dot: --------------------------------------
			local hotspot = MapHotspot:new(string.format("%d %s",i,self.ft[i].title), 
				MapHotspot.CATEGORY_TOUR)
			hotspot:setIconScale(0.8)
			hotspot.verticalAlignment = Overlay.ALIGN_VERTICAL_MIDDLE

			if isbale(i) then
				hotspot:setSize(0.9*w,0.9*h)
				hotspot:setImage(nil, uvB, self.baleCols[i][1])
				hotspot:setBackgroundImage(nil, uvB, nil)
			else 	
				hotspot:setSize(w,h)							-- size for small cicrcles
				hotspot:setImage(nil, uvP, self.pallCols[i][1]) -- pallet marker
				hotspot:setBackgroundImage(nil, uvP, nil) 		-- pallet background 
			end			
			local align 
			if ct > 14 then align = RenderText.ALIGN_LEFT end
			-- hotspot:setTextOptions(textSize, textBold, textOffsetY, textColor, 
			-- 	verticalAlignment, textAlignment)
			hotspot:setTextOptions(0.5*h, nil, nil, nil, nil, align)
			hotspot:setText(hotspot.name,false,true)
			hotspot:setWorldPosition(x, z)			-- also sets the x,z MapPos
			hotspot.enabled = false
			g_currentMission.hud.ingameMap:addMapHotspot(hotspot) 
			table.insert(self.legend, {hotspot,"color"}) 
			-- ------------ icon: -------------------------------------
			hotspot = MapHotspot:new("", MapHotspot.CATEGORY_TOUR)
			hotspot:setIconScale(1.6)
			hotspot:setBackgroundImage(self.bgImage, nil, nil)	
			hotspot:setSize(1.2*w, 1.2*h)	 
			hotspot.verticalAlignment = Overlay.ALIGN_VERTICAL_MIDDLE
			if isbale(i) then 
				image = self.baleCols[i][2]
			else
				image = self.pallCols[i][2]
			end
			hotspot:setImage(image, nil, nil)
			hotspot:setWorldPosition(x+40, z)	
			hotspot.enabled = false
			g_currentMission.hud.ingameMap:addMapHotspot(hotspot) 
			table.insert(self.legend, {hotspot,"color"}) 	-- need only the hotspot for toggleLegend

			z = z +70	
			ct = ct +1
			if math.fmod(ct,14) == 1 then 
				-- start new column
				x = x + 200
				z = -1000
			end
		end				
	end;
end;
function BaleSee:toggleLegend(on)
	-- show/ hide legend display on ingameMap
	if on == nil then on = "on" end
	local vis = on == "on" 
	self:toggleVis(self.legend, vis) 
end;
function BaleSee:toggleVis(spots, on)
	-- show / hide some map hotspots
	for i = 1, #spots do
		spots[i][1].enabled = on
		spots[i][1].hasDetails = on
	end
end;
function BaleSee:toggleCol(spots, on, forPallets)
	-- toggle dot / icon marker
	if self.debug then
		print(("--BaleSee: set dots %s. forPallets %s"):format(on,forPallets))
	end
	local uvs = self.uvB
	if forPallets then uvs = self.uvP; end
	if on then
	-- for each hotspot: reset it to uvP marker
		for _, h in pairs(spots) do
			-- h is {hotspot, color, image, baleId}
			hs = h[1]
			-- on a client, hotspots are not created before player first sees them
			if hs then  
				--remove image, bgImage, set uv and color
				hs:setImage 		 (nil, uvs, h[2])
				hs:setBackgroundImage(nil, uvs, nil)	
				hs:setIconScale		 (0.7)
				hs:setSize			 (self:getSize("dot"))	
			end
		end
	else    -- reset hotspots to Icons:
		for _, h in pairs(spots) do
			hs = h[1]
			if hs then  
				--remove uv, col. Set image, bgImage 
				hs:setImage 		 (h[3], nil, nil)
				hs:setBackgroundImage(self.bgImage, nil, nil)	
				hs:setIconScale 	 (1)
				hs:setSize			 (self:getSize("icon"))	
			end
		end
	end
end;
function BaleSee:toggleSize()
	-- set size for existing map hotspots
	local u,v = self:getSize("icon")
	if self.baleState == 3 then u,v = self:getSize("dot") end
	for farm = 1,8 do
		for _, h in pairs(self.bHotspots[farm]) do
			hs = h[1]						-- h is {hotspot, color, image, baleId}
			if hs then hs:setSize(u,v) end	-- set new size
		end
	end
	-- for pallets:
	u,v = self:getSize("icon")
	if self.palState == 3 then u,v = self:getSize("dot") end
	for _, h in pairs(self.pHotspots) do
		hs = h[1]						-- h is {hotspot, color, image}
		if hs then hs:setSize(u,v) end	-- set new size
	end
end;
function BaleSee:cltObjects( balesOnly )
	-- console cmd: find out bale objects that client sees
	if balesOnly == nil then balesOnly = false end
	if g_server then 
		print("  i  id  node farm type *SERVER objects")
		for i, o in pairs(g_server.objects) do
			if not balesOnly or o:isa(G0.Bale) then
				print(string.format("%3d %3d %5s %4s %s",i, o.id, tostring(o.nodeId),
					 tostring(o.ownerFarmId),tostring(o.typeName)))
			end
		end
		return 
	end
	print("  i  id  node farm type *CLIENT")
	for i, o in pairs(g_client.objects) do
		if not balesOnly or o:isa(G0.Bale) then
			print(string.format("%3d %3d %5s %4s %s",i, o.id, tostring(o.nodeId),
				 tostring(o.ownerFarmId),tostring(o.typeName)))
		end
	end
end
