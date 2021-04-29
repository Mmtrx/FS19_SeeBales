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
--=======================================================================================================

BSGui = {}
local BSGui_mt = Class(BSGui, YesNoDialog)

BSGui.CONTROLS = {          -- to address the different Gui elements by their id 
	SHOW_BALES          = "setShowBales",
	SHOW_PALS           = "setShowPals",
	SET_SIZE            = "setSize",
	HELPBOX 	        = "helpBox",
	HELPBOX_TEXT        = "helpBoxText",
	BALETABLE           = "baleTable",
	PALTABLE            = "palTable",
	STATS_CONTAINER     = "statsContainer",     
	BALETABLE_HEADER_BOX= "baletableHeaderBox",
	PALTABLE_HEADER_BOX = "paltableHeaderBox"
}
function BSGui:new(target, custom_mt)
	local self = YesNoDialog:new(target, custom_mt or BSGui_mt)
	self:registerControls(BSGui.CONTROLS)
	return self
end
function BSGui:onClickShowBales( ix )
	-- multiTextOption clicked
	local bA, cA = BaleSee.baleActivate, BaleSee.colorActivate
	BaleSee.baleState = ix
	BaleSee.baleActivate, BaleSee.colorActivate = unpack(BaleSee.baleDisplay[ix])
	if BaleSee.baleActivate   ~= bA then 
		BaleSee:toggleVis(BaleSee.bHotspots, BaleSee.baleActivate) 
	end
	if BaleSee.baleActivate and BaleSee.colorActivate ~= cA then
		BaleSee:toggleCol(BaleSee.bHotspots, BaleSee.colorActivate, false)
	end
end
function BSGui:onClickShowPals( ix )
	local bA, cA = BaleSee.palletActivate, BaleSee.colPalActivate
	BaleSee.palState = ix
	BaleSee.palletActivate, BaleSee.colPalActivate = unpack(BaleSee.baleDisplay[ix])
	if BaleSee.palletActivate   ~= bA then 
		BaleSee:toggleVis(BaleSee.pHotspots, BaleSee.palletActivate) 
	end
	if BaleSee.palletActivate and BaleSee.colPalActivate ~= cA then
		BaleSee:toggleCol(BaleSee.pHotspots, BaleSee.colPalActivate, true)
	end
end
function BSGui:onClickSize( ix )
	BaleSee.dispSize = ix
	BaleSee:toggleSize()
end
function BSGui:onToolTipBoxTextChanged(toolTipBox)
	local showText = (toolTipBox.text ~= nil and toolTipBox.text ~= "")
	self.helpBox:setVisible(showText)
end

function BSGui:updateStats(tb)
	-- is called by BSGui elements baleTable, palTable
	if tb.id == "baleTable" then
		-- move bale counts to tb.data:
		for i=1,BaleSee.BAL_TYPES do
			BaleSee.bt.data[i] = BaleSee:buildRow(BaleSee.baleType[i],BaleSee.bales[i])
		end
	elseif tb.id == "palTable" then
		BaleSee.pt.data = {}
		for k,v in pairs(BaleSee.pallets) do
			if v > 0 then
				table.insert(BaleSee.pt.data, BaleSee:buildRow(BaleSee.ft[k].title,v))
			end
		end
		local notshown = #BaleSee.pt.data - BaleSee.PAL_TYPES
		if notshown > 0 then
        	self.helpBoxText:setText(string.format(g_i18n:getText("BS_warnPal"), notshown))
        	self.helpBox:setVisible(true)
		end			
	end
	tb:updateView(true)
end
function BSGui:onClickBack(forceBack, usedMenuButton)
	self:close()
end
