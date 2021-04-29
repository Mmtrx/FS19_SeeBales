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
--=======================================================================================================
-- ---------------Hotspots for bales.-----------------------------------------------------------
function BaleSee:delete()
	local isRound = self.baleDiameter ~= nil
	BaleSee:updBales(self, isRound, -1)
	BaleSee:delhot (self.mapHotspot)
end;
function BaleSee:setNodeId(nodeId)
	--[[Add map hot spot for each bale so they can be found.  We put this here in the code, as it's
		a location that will end up getting called by load(), loadFromAttributesAndNodes(), and readStream().]]
	local isRoundbale = Utils.getNoNil(getUserAttribute(nodeId, "isRoundbale"), false)
	local color = 	BaleSee:getColor(self)
	local uv 	= 	BaleSee.uvB
	local image = 	BaleSee:getIcon(self)

	-- following hotspot attributes need to be set, depending on colorActivate:
	-- colorActivate	bgImage, 	image, 	color, 	uv, 	scal
	-- ----------------------------------------------------------
	-- 			true 	nil 		nil 	set 	set 	0.8
	--		   false 	set 		set 	nil 	nil 	1.0
	local nam = 	BaleSee.ft[self.fillType].title
	if g_gui.languageSuffix == "_de" then nam = nam.."-"
	else nam = nam.." "
	end
	nam = nam .. g_i18n:getText("unit_bale")
	-- Generate bale hotspot. Category = 6 to distinguish from others
	local hotspot = 	MapHotspot:new(nam, MapHotspot.CATEGORY_TOUR)

	if BaleSee.colorActivate then
		-- Hotspots will be small colored circles.
		hotspot:setIconScale(0.8)
		hotspot:setImage(nil, uv, color) 					-- colored circle 
		hotspot:setBackgroundImage(nil, uv, nil)			-- black circle
		hotspot:setSize(BaleSee:getSize("dot"))				-- size for small cicrcles
	else
		-- Hotspots will be small images/icons.
		hotspot:setImage(image, nil, nil)
		hotspot:setBackgroundImage(BaleSee.bgImage, nil, nil)	
		hotspot:setSize(BaleSee:getSize("icon"))	 
	end;
	hotspot.enabled = BaleSee.baleActivate						
	hotspot.verticalAlignment = Overlay.ALIGN_VERTICAL_MIDDLE		
	hotspot:setLinkedNode(nodeId)			-- also sets the x,z MapPos

	self.mapHotspot = hotspot 				-- property of the bale object
	g_currentMission.hud.ingameMap:addMapHotspot(hotspot) 
	table.insert(BaleSee.bHotspots, {hotspot,color,image,self.id}) 

	-- update count for this bale type
	BaleSee:updBales(self, isRoundbale, 1)

	if BaleSee.debug then
		local x,y,z = getWorldTranslation(nodeId)
		print(string.format("** %s %s %s Bale %d/%d (%d) at %4.2f %4.2f.", 
			BaleSee.visible[BaleSee.baleActivate], BaleSee.isRound[isRoundbale],
			BaleSee.ft[self.fillType].name, self.id,
			nodeId, self.fillLevel, x, z))	
	end;
end;

-- ----------------Manage Hotspots for pallets.--------------------------------------------------
function BaleSee:onDelete()		-- is called on delete for a pallet type object
	if BaleSee.debug then
		local typ = 	 self.typeName
		local fillType = self:getFillUnitFillType(1)
		print(string.format("** Delete %s %s %d",
			BaleSee.ft[fillType].name, typ, self.rootNode))
	end
	-- decrease count for this pallet type:
	BaleSee:updPallets(self, -1)
	-- remove hotspot from ingameMap and our own List
	local hot = self.mapHotspot
	if hot ~= nil then
		g_currentMission.hud.ingameMap:removeMapHotspot(hot);
		for i = 1, table.getn(BaleSee.pHotspots) do
			if BaleSee.pHotspots[i][1] == hot then
		    	table.remove(BaleSee.pHotspots, i)
		    	break
			end
		end
	end;
end;
function BaleSee:onLoadFinished(Savegame)
	--[[Add map hot spot for each pallet so they can be found.]]
	local nodeId = 		self.rootNode
	local fillType = 	self:getFillUnitFillType(1)
	local image = 		BaleSee:getImage(self)
	local color = 		BaleSee:getColor(self)
	local nam = 		BaleSee.ft[fillType].title
	-- Generate pallet hotspot. Category = 6 to distinguish from other
	local hotspot = 	MapHotspot:new(nam, MapHotspot.CATEGORY_TOUR)
	
	if BaleSee.colPalActivate then
		-- Hotspots will be small colored dots.
		hotspot:setIconScale(0.7)
		hotspot:setImage 		  (nil, BaleSee.uvP, color)
		hotspot:setBackgroundImage(nil, BaleSee.uvP, nil)	
		hotspot:setSize(BaleSee:getSize("dot"))
	else
		-- Hotspots will be small images/icons.
		hotspot:setImage(image, nil, nil)
		hotspot:setBackgroundImage(BaleSee.bgImage, nil, nil)	
		hotspot:setSize(BaleSee:getSize("icon"))
	end;
	hotspot:setLinkedNode(nodeId)			-- also sets the x,z MapPos
	hotspot.verticalAlignment = Overlay.ALIGN_VERTICAL_MIDDLE		
	hotspot.enabled = BaleSee.palletActivate						
	g_currentMission.hud.ingameMap:addMapHotspot(hotspot) 
	
	self.mapHotspot = hotspot 				-- property of the pallet object
	table.insert(BaleSee.pHotspots, {hotspot,color,image}) 
	-- increase count for this pallet type:
	BaleSee:updPallets(self, 1)

	if BaleSee.debug then
		local x,y,z = getWorldTranslation(nodeId)
		print(string.format("** %s %s Pallet %d at %4.2f %4.2f", 
			BaleSee.visible[BaleSee.palletActivate], BaleSee.ft[fillType].name, nodeId, x, z))
	end;			
end;
function BaleSee:onChangedFillType(fillUnitIndex, fillTypeIndex, oldFillTypeIndex)
	-- to set fillType of newly filled fillablePallet (egg / wool / potato / sugarbeet)
	-- also, when selling/ feeding pallets, they change back to UNKNOWN when emptied, shortly 
	-- before they get deleted
	if BaleSee.debug then
		print(string.format("** filltype change(%d,%d,%d) for %s pallet %d to %s", 
		fillUnitIndex, fillTypeIndex, oldFillTypeIndex,
		BaleSee.ft[oldFillTypeIndex].name,
	 	self.rootNode, BaleSee.ft[fillTypeIndex].name))
	end
	local hotspot = self.mapHotspot
	if hotspot == nil then return; end 			-- only for our managed pallets

	local color, image = BaleSee:getColor(self), BaleSee:getImage(self)
	if BaleSee.colPalActivate then
		hotspot:setImage(nil, BaleSee.uvP, color) 	-- change color.
	else			
		hotspot:setImage(image, nil, nil) 			-- change small image/icon.
	end;
	-- change also in our table of hotspots:
	for i,h in ipairs(BaleSee.pHotspots) do
		if h[1] == hotspot then
			-- BaleSee.pHotspots[i] = {h[1],color,image}
			h[2],h[3] = color,image 				-- should be enough
			hotspot:setText(BaleSee.ft[fillTypeIndex].title, true, false)  --(name,hidden,alwaysshow)
			break
		end
	end
	-- adjust pallet counts, old filltype -1, new fillType +1:
	BaleSee.pallets[oldFillTypeIndex] = BaleSee.pallets[oldFillTypeIndex] -1
	if BaleSee.pallets[fillTypeIndex] == nil then
		BaleSee.pallets[fillTypeIndex] = 1 			-- we have a new filltype
	else
		BaleSee.pallets[fillTypeIndex] = BaleSee.pallets[fillTypeIndex] +1
	end
end
