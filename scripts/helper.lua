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
--=======================================================================================================
-- ---------------Helper functions-----------------------------------------------------------
function BaleSee:updBales(objectId,isRound,inc)
	-- adjust count in .bales[]  
	local ft = objectId.fillType 		-- works, if it's a bale
	local ftIndex = BaleSee.ftIndex[ft]
	local sumIndex = 1
	if ftIndex == nil then
		print(("*ERROR* unknown bale fillType %d %s"):format(ft,BaleSee.ft[ft].name))
		return
	end
	if not isRound then ftIndex, sumIndex = ftIndex +5, 6; 
	end
	BaleSee.bales[ftIndex+1] = 	BaleSee.bales[ftIndex+1] +inc  -- update bale type
	BaleSee.bales[sumIndex] = 	BaleSee.bales[sumIndex] + inc	 -- update bales sum
end;
function BaleSee:updPallets(objectId,inc)
	-- adjust count in .pallets[] 
	local ft = objectId:getFillUnitFillType(1)
	if BaleSee.pallets[ft] == nil then
		BaleSee.pallets[ft] = 0
		if BaleSee.debug then
			print(("** new pallet fillType %d %s"):format(ft,BaleSee.ft[ft].name))
		end
	end
	BaleSee.pallets[ft] = BaleSee.pallets[ft] +inc  -- update pallet type
	if BaleSee.debug then print(("--updPallets(%s, %d): updated .pallets[%s]"):
		format(objectId.rootNode,inc,BaleSee.ft[ft].name))
	end
end;


function BaleSee:getSize(typ)
	-- return icon / dotmarker size in u.v coordinates
	local isiz = BaleSee.symSizes[BaleSee.dispSize]
	return unpack(isiz[typ])
end;
function BaleSee:getColor(objectId)
	-- return color depending on filltype of bale object 
	local ft = objectId.fillType 		-- works, if it's a bale
	if ft == nil then 					-- it's a pallet, vehicle object.
		ft = objectId:getFillUnitFillType(1)
	end
	return Utils.getNoNil(BaleSee.colors[ft], {1,1,1,1}) 		-- default
end;
function BaleSee:getIcon(objectId)
	-- Hotspot bale icons that will show on the map and in the Escape menu.
	local files =	BaleSee.icons
	-- return icon image depending on filltype of bale object 
	local image   = Utils.getFilename(files.squareStraw, BaleSee.modDir); -- default image: FillType.STRAW
	local fill 	  = objectId.fillType
	
	-- select correct image, based on filltype
	if objectId.baleDiameter then
		image = Utils.getFilename(files.roundStraw, BaleSee.modDir);
		if     fill == FillType.DRYGRASS_WINDROW then
			image = Utils.getFilename(files.roundHay, BaleSee.modDir);
		elseif fill == FillType.GRASS_WINDROW then
			image = Utils.getFilename(files.roundGrass, BaleSee.modDir);
		elseif fill == FillType.SILAGE then
			image = Utils.getFilename(files.roundSilage, BaleSee.modDir);
		end;			
	else
		if     fill == FillType.DRYGRASS_WINDROW then
			image = Utils.getFilename(files.squareHay, BaleSee.modDir);
		elseif fill == FillType.GRASS_WINDROW then
			image = Utils.getFilename(files.squareGrass, BaleSee.modDir);
		elseif fill == FillType.SILAGE then
			image = Utils.getFilename(files.squareSilage, BaleSee.modDir);
		elseif fill == FillType.COTTON then
			image = Utils.getFilename(files.squareCotton, BaleSee.modDir);
		end;
	end;	
	return image
end;
function BaleSee:getImage(self)
	-- find image source for the pallet icon display
	local image = 		Utils.getFilename(BaleSee.icons.otherPallet, BaleSee.modDir); --default image
	local fillType = 	self:getFillUnitFillType(1)
	if fillType == FillType.WOOL then
			image = Utils.getFilename(BaleSee.icons.woolPallet, BaleSee.modDir);
	elseif self.configFileName then
		local storeItem = g_currentMission.shopController.storeManager.xmlFilenameToItem[
			string.lower(self.configFileName)]
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
function BaleSee:delhot(hotspot)
	if hotspot ~= nil then
		g_currentMission.hud.ingameMap:removeMapHotspot(hotspot);
		for i = 1, table.getn(BaleSee.bHotspots) do
			if BaleSee.bHotspots[i][1] == hotspot then
		    	table.remove(BaleSee.bHotspots, i)
		    	break
			end
		end
	end;
end;
function BaleSee:makeLegend()
	-- show all bale/pallet hotspot markers:
	local w,h = getNormalizedScreenValues(16,16)
	local x,z = -1000, -1000
	local uvP = getNormalizedUVs({520, 520, 240, 240})
	local uvB = getNormalizedUVs({776, 776, 240, 240})
	local function isbale( ft )		-- true if ft is bale fillType
		local ftbale = {FillType.STRAW, FillType.GRASS_WINDROW, FillType.DRYGRASS_WINDROW,
			FillType.SILAGE	}
		for _,f in ipairs(ftbale) do
			if f == ft then return true end
		end
		return false
	end;

	for i=1,52 do
		if BaleSee.colors[i] ~= nil then 
			local color = BaleSee.colors[i]
			local hotspot = MapHotspot:new(string.format("%d %s",i,BaleSee.ft[i].title), 
				MapHotspot.CATEGORY_TOUR)
			hotspot:setIconScale(0.8)
			hotspot:setSize(w,h)	-- size for small cicrcles
			hotspot.verticalAlignment = Overlay.ALIGN_VERTICAL_MIDDLE
			hotspot:setImage(nil, uvP, color)
			hotspot:setBackgroundImage(nil, uvP, nil)
			if isbale(i) then
				hotspot:setSize(0.9*w,0.9*h)
				hotspot:setImage(nil, uvB, color)
				hotspot:setBackgroundImage(nil, uvB, nil)
			end			
			hotspot:setWorldPosition(x, z)			-- also sets the x,z MapPos
	--		hotspot:setTextOptions(textSize, textBold, textOffsetY, textColor, 
	--			verticalAlignment, textAlignment)
			hotspot:setTextOptions(0.5*h, nil, nil, nil, nil, nil)
			hotspot:setText(hotspot.name,false,true)
			hotspot.enabled = false
			g_currentMission.hud.ingameMap:addMapHotspot(hotspot) 
			table.insert(BaleSee.legend, {hotspot,color}) 
			z = z +70	
		end				
	end;
end;
function BaleSee:toggleVis(spots, on)
	-- show / hide some map hotspots
	for i = 1, #spots do
		spots[i][1].enabled = on
		spots[i][1].hasDetails = on
	end
end;
function BaleSee:toggleCol(spots, on, forPallets)
	-- toggle colorActivate / colPalActivate
	if BaleSee.debug then
		print(("--BaleSee: toggle color to %s"):format(on,forPallets))
	end
	local uvs = BaleSee.uvB
	if forPallets then uvs = BaleSee.uvP; end
	if on then
	-- for each hotspot: reset it to uvP marker
		for _, h in pairs(spots) do
			-- h is {hotspot, color, image}
			hs = h[1]
			--remove image, bgImage, set uv and color
			hs:setImage 		 (nil, uvs, h[2])
			hs:setBackgroundImage(nil, uvs, nil)	
			hs:setIconScale		 (0.7)
			hs:setSize			 (BaleSee:getSize("dot"))	
		end
	else    -- reset hotspots to Icons:
		for _, h in pairs(spots) do
			hs = h[1]
			--remove uv, col. Set image, bgImage 
			hs:setImage 		 (h[3], nil, nil)
			hs:setBackgroundImage(BaleSee.bgImage, nil, nil)	
			hs:setIconScale 	 (1)
			hs:setSize			 (BaleSee:getSize("icon"))	
		end
	end
end;
function BaleSee:toggleSize()
	-- set size for existing map hotspots
	local spots = {BaleSee.bHotspots, BaleSee.pHotspots}
	for i=1,2 do
		local typ = "icon"
		if (i == 1 and BaleSee.colorActivate) or (i == 2 and BaleSee.colPalActivate) then
			typ = "dot"
		end
		for _, h in pairs(spots[i]) do
			hs = h[1]							-- h is {hotspot, color, image}
			hs:setSize(BaleSee:getSize(typ))	-- set new size
		end
	end
end;
