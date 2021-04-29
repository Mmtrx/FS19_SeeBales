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
--=======================================================================================================
-------------------- User interface functions ---------------------------------------------------
function BaleSee:registerActionEventsPlayer()
	-- gets called when player leaves vehicle
	local result, eventId 
	for e, f in pairs(BaleSee.ACTIONS) do
		result, eventId = InputBinding.registerActionEvent(g_inputBinding,e,self,f,false,true,false,true)
		if result then
			table.insert(BaleSee.events, eventId);
			g_inputBinding.events[eventId].displayIsVisible = true;
    	end
    end
end;
function BaleSee:removeActionEventsPlayer()
	-- gets called when player enters vehicle
	BaleSee.events = {};
end;
function BaleSee:saveSettings()
	local key = "BaleSee"
	local f = BaleSee.modsSettings .. 'BaleSee.xml'
	local xmlFile = createXMLFile("BaleSee", f, key);
	setXMLInt(xmlFile, key .. "#baleState", BaleSee.baleState);
	setXMLInt(xmlFile, key .. "#palState", 	BaleSee.palState);		
	setXMLInt(xmlFile, key .. "#size",		BaleSee.dispSize);
	saveXMLFile(xmlFile);
	delete(xmlFile);
	if BaleSee.debug then
		print("** BaleSee:saved settings to " ..f);
	end;
end;
function BaleSee:actionbs_Bale(actionName, keyStatus, arg3, arg4, arg5)
	-- show Gui
	local dialog = g_gui:showDialog("BSGui")
	if dialog == nil then
		print("*Error* could not show Gui!")
		return
	end
	-- set texts for multiTextOption Gui elements:
    BaleSee.oGui.setShowBales:setTexts(BaleSee.showOpts)
    BaleSee.oGui.setShowBales:setState(BaleSee.baleState, true)

    BaleSee.oGui.setShowPals:setTexts(BaleSee.showOpts)
    BaleSee.oGui.setShowPals:setState(BaleSee.palState, true)

    BaleSee.oGui.setSize:setTexts(BaleSee.sizeOpts)
    BaleSee.oGui.setSize:setState(BaleSee.dispSize, true)

	BaleSee.oGui:updateStats(BaleSee.bt)
	BaleSee.oGui:updateStats(BaleSee.pt)
end;
