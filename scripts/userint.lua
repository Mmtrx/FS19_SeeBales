--=======================================================================================================
--  BALESEE USER INTERFACE FUNCTIONS
--
-- Purpose:		Allows bales and pallets to show up on the PDA map as hotspots.
-- Author:		Mmtrx		
-- Changelog:
--  v1.0		03.01.2019	original FS17 version by akuenzi (akuenzi@gmail.com)
--	v1.1.0		28.08.2019	updates for FS19, added user interface  
--  v1.1.1		17.09.2019  added pallette support.
--  v1.1.2		08.10.2019	save statistics / add legend in debug mode 
--  v2.0.0		10.02.2020  add Gui (settings and statistics)
--  v2.1.0.0	30.06.2021  MULTIPLAYER! / handle all bale types, (e.g. Maizeplus forage extension)
--=======================================================================================================
-------------------- Load functions ------------------------------------------------------------
function BaleSee:loadBaleTypes()
	-- load additional bale types from modDesc.xml
	local modDesc = loadXMLFile("modDesc", self.directory.."modDesc.xml")
	local i, ftName, colText, fround, fsquar, baleKey 
	local function rgbNormalize( colText )
		-- return FS19 normalized rgb values 
		local vals = StringUtil.splitString(" ",colText)
		for i = 1, #vals do
			vals[i] = (tonumber(vals[i])/255)^2.2
		end
		vals[4] = 1
		return unpack(vals)
	end;
	i = 0
	while true do
		baleKey = string.format("modDesc.baleTypes.bale(%d)", i)
		if not hasXMLProperty(modDesc, baleKey) then break; end;
		
		ftName = Utils.getNoNil(getXMLString(modDesc, baleKey .. "#name"), "")
		ft = g_fillTypeManager.nameToIndex[ftName]
		if ft == nil then
			if self.debug then print(string.format("-- bale type %s ignored.",ftName)) end
		elseif self.baleCols[ft] == nil then 	-- we have not seen this bale type yet
			colText = Utils.getNoNil(getXMLString(modDesc, baleKey .. "#color"), "255 0 255")
			fround = self.directory..Utils.getNoNil(getXMLString(modDesc, baleKey .. "#round"), "")
			fsquar = self.directory..Utils.getNoNil(getXMLString(modDesc, baleKey .. "#square"), "")
			if fileExists(fround) then
				if not fileExists(fsquar) then fsquar = fround end
				self.baleCols[ft] = {
					{rgbNormalize(colText)},
					fround, fsquar
				}
			else 
				print(string.format(
				"** Error %s: Icon file '%s' for bale type '%s' not found.",self.name,fname,ftName))	
			end	
		end	
		i = i +1
	end
	delete(modDesc)
end;
function BaleSee:loadGUI(canLoad, guiPath)
	if canLoad then
		-- load "BSGui.lua"
		if g_gui ~= nil and g_gui.guis.BSGui == nil then
			local luaPath = guiPath .. "BSGui.lua"
			if fileExists(luaPath) then
				source(luaPath)
			else
				canLoad = false
				print(string.format("**Error: [GuiLoader %s]  Required file '%s' could not be found!", 
					self.name, luaPath))
			end
		-- load "BSGui.xml"
			if canLoad then
				-- load my gui profiles 
				g_gui:loadProfiles(guiPath .. "guiProfiles.xml")
				local xmlPath = guiPath .. "BSGui.xml"
				if fileExists(xmlPath) then
					self.oGui = BSGui:new(nil, nil) 		-- my Gui object controller
					g_gui:loadGui(xmlPath, "BSGui", self.oGui)
				else
					canLoad = false
					print(string.format("**Error: [GuiLoader %s]  Required file '%s' could not be found!", 
						self.name, xmlPath))
				end
			end
		end
	end
	return canLoad
end;
-------------------- User interface functions ---------------------------------------------------
function BaleSee:registerActionEventsPlayer()
	-- gets called when player leaves vehicle
	local bs = g_baleSee
	local result, eventId = InputBinding.registerActionEvent(g_inputBinding,"bs_Bale",
			self,bs.actionbs_Bale,false,true,false,true)
	if result then
		bs.event = eventId
		g_inputBinding.events[eventId].displayIsVisible = true;
    end
end;
function BaleSee:removeActionEventsPlayer()
	-- gets called when player enters vehicle
	g_baleSee.event = nil
end;
function BaleSee:actionbs_Bale(actionName, keyStatus, arg3, arg4, arg5)
	-- show Gui
	local dialog = g_gui:showDialog("BSGui")
	if dialog == nil then
		print("*Error* could not show Gui!")
		return
	end
	local bs = g_baleSee
	-- set texts for multiTextOption Gui elements:
    bs.oGui.setShowBales:setTexts(bs.showOpts)
    bs.oGui.setShowBales:setState(bs.baleState)

    bs.oGui.setShowPals:setTexts(bs.showOpts)
    bs.oGui.setShowPals:setState(bs.palState) 		--, true)

    bs.oGui.setSize:setTexts(bs.sizeOpts)
    bs.oGui.setSize:setState(bs.dispSize) 			--, true)

    bs.oGui.setFarm:setVisible(bs.isMultiplayer)
    if bs.isMultiplayer then
    	local texts = {}
    	for i = 1,8 do
    		if g_farmManager.farmIdToFarm[i] then
    			texts[i] = g_farmManager.farmIdToFarm[i].name
    		else
    			texts[i] = string.format("%d n/a",i)
    		end	
    	end	
    	bs.oGui.setFarm:setTexts(texts)
    	bs.statFarm = g_currentMission:getFarmId()
    	bs.oGui.setFarm:setState(bs.statFarm)
    end	

	bs.oGui:updateStats(bs.bt)
	bs.oGui:updateStats(bs.pt)
end;
function BaleSee:buildRow(name, value, profile)
	-- return a table in correct format for <tableElement>.data 
	local vis = value > 0
	local row = {
			columnCells = {	btype = {text= name, isVisible = vis},
							count = {text= tostring(value), isVisible = vis}
							}, 
			id = name
	}
	if profile ~= nil then
		row.columnCells.btype.overrideProfileName = profile
	end
	return row
end;
function BaleSee:saveSettings()
	local bs = g_baleSee
	local key = "BaleSee"
	local f = bs.modsSettings .. 'BaleSee.xml'
	local xmlFile = createXMLFile("BaleSee", f, key);
	setXMLInt(xmlFile, key .. "#baleState", bs.baleState);
	setXMLInt(xmlFile, key .. "#palState", 	bs.palState);		
	setXMLInt(xmlFile, key .. "#size",		bs.dispSize);
	if bs.debug then
		setXMLBool(xmlFile, key .. "#debug",	bs.debug);
	end
	saveXMLFile(xmlFile);
	delete(xmlFile);
	if bs.debug then
		print("** BaleSee:saved settings to " ..f);
	end;
end;

-- ----------------Manage Hotspots for pallets.--------------------------------------------------
function BaleSee.pal:onDelete()		-- is called on delete for a pallet type object
	local bs = g_baleSee
	local farm = self.ownerFarmId
	if bs.debug then
		local typ = 	 self.typeName
		local fillType = self:getFillUnitFillType(1)
		print(string.format("-- onDelete %s %s %d farm %s",
			bs.ft[fillType].name, typ, self.rootNode, tostring(farm)))
	end
	if farm == nil then return end 	-- from pallet load in store

	-- decrease count for this farm /pallet type:
	bs:updPallets(self, farm, -1)
	-- remove hotspot from ingameMap and our own List
	local hot = self.mapHotspot
	if hot ~= nil then
		g_currentMission.hud.ingameMap:removeMapHotspot(hot);
		for i = 1, table.getn(bs.pHotspots) do
			if bs.pHotspots[i][1] == hot then
		    	table.remove(bs.pHotspots, i)
		    	break
			end
		end
	end;
end;
function BaleSee.pal:onLoadFinished()
	-- called for a pallet on its finished-loading event 
	-- (registered as spec event listener)
	local bs = 			g_baleSee
	local nodeId = 		self.rootNode
	local fillType = 	self:getFillUnitFillType(1)
	local farmId = 		self.ownerFarmId
	local image = 		bs:getImage(self,fillType)
	local color = 		bs:getColor(self)
	local nam = 		bs.ft[fillType].title

	if bs.debug then
		local x,y,z = getWorldTranslation(nodeId)
		print(string.format("-- %s %s Pallet %d farm %s at %4.2f %4.2f", 
			bs.visible[bs.palState], bs.ft[fillType].name, nodeId, tostring(farmId), x, z))
	end;		
	if farmId == nil then return end -- pallet load in store

	-- Generate pallet hotspot. Category = 6 to distinguish from other
	local hotspot = MapHotspot:new(nam, MapHotspot.CATEGORY_TOUR)
	hotspot.baleSee = true
	hotspot.bsImage = image
	
	if bs.palState == 2 then
		-- Hotspots will be small images/icons.
		hotspot:setImage(image, nil, nil)
		hotspot:setBackgroundImage(bs.bgImage, nil, nil)	
		hotspot:setSize(bs:getSize("icon"))
	else
		-- Hotspots will be small colored dots.
		hotspot:setIconScale(0.7)
		hotspot:setImage 		  (nil, bs.uvP, color)
		hotspot:setBackgroundImage(nil, bs.uvP, nil)	
		hotspot:setSize(bs:getSize("dot"))
	end;
	hotspot:setLinkedNode(nodeId)			-- also sets the x,z MapPos
	hotspot:setOwnerFarmId(farmId)
	hotspot.verticalAlignment = Overlay.ALIGN_VERTICAL_MIDDLE		
	hotspot.enabled = bs.palState > 1					
	g_currentMission.hud.ingameMap:addMapHotspot(hotspot) 
	
	self.mapHotspot = hotspot 				-- property of the pallet object
	table.insert(bs.pHotspots, {hotspot,color,image}) 
	-- increase count for this pallet type:
	bs:updPallets(self, farmId, 1)
end;
function BaleSee.pal:onChangedFillType(fillUnitIndex, fillTypeIndex, oldFillTypeIndex)
	-- to set fillType of newly filled fillablePallet (egg / wool / potato / sugarbeet)
	-- also, when selling/ feeding pallets, they change back to UNKNOWN when emptied, shortly 
	-- before they get deleted
	local bs = g_baleSee
	if bs.debug then
		print(string.format("-- filltype change(%d,%d,%d) for %s pallet %d to %s. Hotspot: %s", 
		fillUnitIndex, fillTypeIndex, oldFillTypeIndex,
		bs.ft[oldFillTypeIndex].name,
	 	self.rootNode, bs.ft[fillTypeIndex].name, self.mapHotspot))
	end
	local hotspot = self.mapHotspot
	if hotspot == nil then return; end 	-- only for our managed pallets

	local farm = hotspot.ownerFarmId
	local color = bs:getColor(self) 
	local image = bs:getImage(self,fillTypeIndex)

	hotspot.bsImage = image 					-- change image for details display
	if bs.palState == 2 then
		hotspot:setImage(image, nil, nil) 		-- change small image/icon.
	else			
		hotspot:setImage(nil, bs.uvP, color) 	-- change color.
	end;
	-- change also in our table of hotspots:
	for i,h in ipairs(bs.pHotspots) do
		if h[1] == hotspot then
			-- bs.pHotspots[i] = {h[1],color,image}
			h[2],h[3] = color,image 				-- should be enough
			hotspot:setText(bs.ft[fillTypeIndex].title, true, false)  --(name,hidden,alwaysshow)
			break
		end
	end
	-- adjust pallet counts, old filltype -1, new fillType +1:
	bs.pallets[farm][oldFillTypeIndex] = bs.pallets[farm][oldFillTypeIndex] -1
	if bs.pallets[farm][fillTypeIndex] == nil then
		bs.pallets[farm][fillTypeIndex] = 1 			-- we have a new filltype
	else
		bs.pallets[farm][fillTypeIndex] = bs.pallets[farm][fillTypeIndex] +1
	end
end
