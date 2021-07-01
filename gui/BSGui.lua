--=======================================================================================================
--  BALESEE HOTSPOT GUI
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

BSGui = {}
local BSGui_mt = Class(BSGui, YesNoDialog)

BSGui.CONTROLS = {          -- to address the different Gui elements by their id 
	SHOW_BALES          = "setShowBales",
	SHOW_PALS           = "setShowPals",
	SET_SIZE            = "setSize",
	SET_FARM            = "setFarm",
	HELPBOX 	        = "helpBox",
	HELPBOX_TEXT        = "helpBoxText",
	BALETABLE           = "baleTable",
	PALTABLE            = "palTable",
	STATS_CONTAINER     = "statsContainer",     
	BALETABLE_HEADER_BOX= "baletableHeaderBox",
	PALTABLE_HEADER_BOX = "paltableHeaderBox",
	SUMBAL 				= "sumBal",
	SUMPAL 				= "sumPal",
	BCOUNT 				= "bcount",
	PCOUNT 				= "pcount",
}
function BSGui:new(target, custom_mt)
	local self = YesNoDialog:new(target, custom_mt or BSGui_mt)
	self:registerControls(BSGui.CONTROLS)
	return self
end
function BSGui:onClickShowBales( ix )
	-- multiTextOption clicked
	local bs = g_baleSee
	local oldState = bs.baleState
	bs.baleState = ix
	if oldState == 1 or bs.baleState == 1 then 		-- switch display on / off
		for i = 1,8 do
			bs:toggleVis(bs.bHotspots[i], oldState == 1)   -- switch on, if display was off
		end
	end
	if bs.baleState ~= 1 then 						-- dots true, if new baleState 3
		for i = 1,8 do
			bs:toggleCol(bs.bHotspots[i], bs.baleState == 3, false)
		end
	end
end
function BSGui:onClickShowPals( ix )
	local bs = g_baleSee
	local oldState = bs.palState
	bs.palState = ix
	if oldState == 1 or bs.palState == 1 then 
		bs:toggleVis(bs.pHotspots, oldState == 1) 
	end
	if bs.palState ~= 1 then
		bs:toggleCol(bs.pHotspots, bs.palState == 3, true)
	end
end
function BSGui:onClickSize( ix )
	g_baleSee.dispSize = ix
	g_baleSee:toggleSize()
end
function BSGui:onClickFarm( ix )
	g_baleSee.statFarm = ix
	self:updateStats(self.baleTable)
	self:updateStats(self.palTable)
end
function BSGui:onToolTipBoxTextChanged(toolTipBox)
	local showText = (toolTipBox.text ~= nil and toolTipBox.text ~= "")
	self.helpBox:setVisible(showText)
end

function BSGui:updateStats(tb)
	-- is called by BSGui elements baleTable, palTable
	-- refresh tb.data
	local bs, farm = g_baleSee, g_baleSee.statFarm
	if farm == nil then
		farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId).farmId
	end
	tb.data = {}
	if tb.id == "baleTable" then
		-- totals row:
		self.bcount:setText(tostring(bs.numBales[farm])) 
		self.sumBal:setVisible(bs.numBales[farm] > 0)
		-- move bale counts to tb.data:
		for _,v in pairs(bs.bales[farm]) do
			if v.number > 0 then
				table.insert(tb.data, bs:buildRow(v.text, v.number))
			end
		end
	elseif tb.id == "palTable" then
		-- totals row:
		self.pcount:setText(tostring(bs.numPals[farm])) 
		self.sumPal:setVisible(bs.numPals[farm] > 0)
		for k,v in pairs(bs.pallets[farm]) do
			if v > 0 then
				table.insert(tb.data, bs:buildRow(bs.ft[k].title,v))
			end
		end
	end
	local notshown = #tb.data - bs.MAXLINES
	if notshown > 0 then
		local typ = "BS_warnBal"
		if tb.id == "palTable" then typ = "BS_warnPal" end
        self.helpBoxText:setText(string.format(g_i18n:getText(typ), notshown))
       	self.helpBox:setVisible(true)
	end			
	tb.dataView = {"dummy"} 	-- updateView() checks for #dataView > 0
	tb:updateView(false)
end
function BSGui:onClickBack(forceBack, usedMenuButton)
	self:close()
end
--[[-- make overrideProfileName attributes possible for bt cells:
	BaleSee.bt:setProfileOverrideFilterFunction(function( cell )
		return true
	end)
	]]
