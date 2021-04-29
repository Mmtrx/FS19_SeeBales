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
--=======================================================================================================

BaleSee = {};
BaleSee.bHotspots 	= 	{}			-- to keep track of all generated b-ale and p-allet hotspots
BaleSee.pHotspots	= 	{}			-- each entry is a tuple {hotspot, color, image}
BaleSee.baleActivate   = true		-- 'True' means that the mod will show hot spots for bales.
BaleSee.palletActivate = false		-- 'True' means that the mod will show hot spots for pallets.
BaleSee.colorActivate  = true		-- 'True' means that the mod will create small colored circle hotspots.
									-- 'False' means that the mod will create hotspots that are small images of the objects.
BaleSee.colPalActivate = true		-- Separate switch for the pallets: in this version always == colorActivate
BaleSee.showHelp 	   = true 		-- show mods key help in F1-menu
BaleSee.events = {} 				--
BaleSee.legend = {} 				-- save hotspots for map legend
BaleSee.initialized 	= false
BaleSee.oGui			= nil 		-- object handle Gui controller
BaleSee.bt 				= nil		-- bale Table
BaleSee.pt 				= nil		-- pallet Table

---------------- constants -----------------------------------------------------------------------
BaleSee.version 	= "2.0.0.1" 	-- allow all future pallet fillTypes
BaleSee.debug 		= false
BaleSee.modDir 		= g_currentModDirectory
BaleSee.modName 	= g_currentModName;
BaleSee.modsSettings= string.sub(g_modsDirectory,1,-2) .. "Settings/"
BaleSee.visible 	=	{[false] = 	"invisible";[true]  =	"visible"}
BaleSee.isIcon 		=	{[false] = 	"icons";	[true]  =	"spots"}
BaleSee.isRound		=	{[false] = 	"square";	[true]  =	"round"}
BaleSee.icons 		=	{
		squareStraw	= "HotspotIcons/StrawSquareBale.dds",
		squareHay	= "HotspotIcons/HaySquareBale.dds",
		squareGrass	= "HotspotIcons/GrassSquareBale.dds",
		squareSilage= "HotspotIcons/SilageSquareBale.dds",
		squareCotton= "HotspotIcons/CottonSquareBale.dds",
		roundStraw	= "HotspotIcons/StrawRoundBale.dds",
		roundHay	= "HotspotIcons/HayRoundBale.dds",
		roundGrass	= "HotspotIcons/GrassRoundBale.dds",
		roundSilage	= "HotspotIcons/SilageRoundBale.dds",
		woolPallet	= "HotspotIcons/WoolPallet.dds",
		otherPallet	= "HotspotIcons/Pallet.dds",
		-- Transparent image used as background to show hotspot icons 
		-- without the usual default (black) background:
		bgImage		= "HotspotIcons/BGOverlay.dds",	
					}
BaleSee.showOpts 	= {g_i18n:getText("ui_off"),g_i18n:getText("BS_icons"),g_i18n:getText("BS_symbols")}
BaleSee.sizeOpts 	= {g_i18n:getText("configuration_valueSmall"), g_i18n:getText("setting_medium"), 
			   		   g_i18n:getText("configuration_valueBig")}
BaleSee.ROUND 		= g_i18n:getText("fillType_roundBale")		   		   
BaleSee.SQUARE 		= g_i18n:getText("fillType_squareBale")		   		   
BaleSee.baleType 	= {
			string.upper(BaleSee.ROUND),
			g_i18n:getText("fillType_straw"),
			g_i18n:getText("fillType_grass"),		--fillType_roundBaleGrass
			g_i18n:getText("fillType_dryGrass"),	--fillType_roundBaleDryGrass
			g_i18n:getText("fillType_silage"),		--fillType_roundBaleSilage

			string.upper(BaleSee.SQUARE),
			g_i18n:getText("fillType_straw"),
			g_i18n:getText("fillType_grass"),
			g_i18n:getText("fillType_dryGrass"),
			g_i18n:getText("fillType_silage"),
			g_i18n:getText("fillType_cotton")
			}
BaleSee.bales 		= {0,0,0,0,0,0,0,0,0,0,0}	-- holds #of bales of each type
BaleSee.BAL_TYPES 	= #BaleSee.baleType
BaleSee.PAL_TYPES 	= 17
BaleSee.baleDisplay = {
						{ false,false},			-- baleState 1: "off"
						{ true, false},			-- baleState 2: "icon"
						{ true, true}			-- baleState 3: "symbol"
					}
BaleSee.baleState	= 1 				-- off
BaleSee.palState 	= 1 				-- off
BaleSee.dispSize 	= 1					-- "small"
BaleSee.symSizes 	= {
	{ icon = {getNormalizedScreenValues(6,6)}, 	dot = {getNormalizedScreenValues(5,5)}  },  --"small"
	{ icon = {getNormalizedScreenValues(8,8)}, 	dot = {getNormalizedScreenValues(7,7)}  },  --"medium"
	{ icon = {getNormalizedScreenValues(11,11)},dot = {getNormalizedScreenValues(10,10)}}  	--"large"
	}
BaleSee.bgImage 	= Utils.getFilename(BaleSee.icons.bgImage, BaleSee.modDir)
BaleSee.uvB			= getNormalizedUVs({776, 776, 240, 240}) -- 8 + 3* 256 = 776
BaleSee.uvP			= getNormalizedUVs({520, 520, 240, 240}) -- 8 + 2* 256 = 520
G0					= getfenv(0) 	-- to get at all globals

-- ---------------Helper functions------------------------
source(BaleSee.modDir.."scripts/helper.lua")
-- ---------------Manage Hotspots for bales and pallets---
source(BaleSee.modDir.."scripts/hotspots.lua")
------------------User interface functions ---------------
source(BaleSee.modDir.."scripts/userint.lua")

----------------------- initilization on load Map ----------------------------------------------
function BaleSee:loadMap(name)
	print("--- loading BaleSee V".. BaleSee.version )
	-- SaveSettings
	FSBaseMission.saveSavegame 	= Utils.appendedFunction(FSBaseMission.saveSavegame, BaleSee.saveSettings);		
		
	-- Append functions for bales.
	Bale.delete = 	Utils.appendedFunction(Bale.delete, BaleSee.delete);
	Bale.setNodeId= Utils.appendedFunction(Bale.setNodeId, BaleSee.setNodeId);
	
    -- needed for action event for player
    Player.registerActionEvents = Utils.appendedFunction(Player.registerActionEvents, BaleSee.registerActionEventsPlayer);
	Player.removeActionEvents = Utils.appendedFunction(Player.removeActionEvents, BaleSee.removeActionEventsPlayer);		
		
	-- register the functions to be triggered for pallets (is a vehicle type :)
	local pType =  g_vehicleTypeManager:getVehicleTypeByName("pallet")
	SpecializationUtil.registerEventListener(pType, "onLoadFinished",  	BaleSee);
	SpecializationUtil.registerEventListener(pType, "onDelete", 		BaleSee);	
	SpecializationUtil.registerEventListener(pType, "onChangedFillType",BaleSee);	
	
	-- initialize constants
	BaleSee.colors		=	{  -- set this here, because FillType.x is not yet filled, outside of loadMap()
	[FillType.STRAW] =		{0.6, 	0.3, 	0, 		1},	-- Orange
	[FillType.DRYGRASS_WINDROW] ={0.4, 	1, 		0.4, 	1},	-- Light Green
	[FillType.GRASS_WINDROW]={0.1, 	0.2, 	0, 		1},		-- Dark Green
	[FillType.SILAGE] =		{0.95, 	0.35, 	0.35,	1},		-- pink
	[FillType.COTTON] =		{0.5, 	0.5, 	0.7,	1},		-- grey
	-- pallet big bags:
	[FillType.UNKNOWN] =	{1, 	0, 		1, 		1},		-- Magenta
	[FillType.PIGFOOD] =	{0.27, 	0.085,	0.085, 	1},		-- dark pink
	[FillType.SEEDS] =		{0.1, 	0.04, 	0.04, 	1},		-- dark brown
	[FillType.FERTILIZER] = {0.55, 	0.25, 	0.25,	1},		-- medium pink
	[FillType.LIME] =		{1, 	0.6, 	0.6, 	1},		-- light pink
	[FillType.WHEAT] =		{0.55, 	0.5, 	0.26,	1},		-- light bronze
	[FillType.OAT] =		{0.34, 	0.29, 	0.15,	1},		-- medium bronze			
	-- pallet tanks:
	[FillType.LIQUIDFERTILIZER] = {0.79, 	0.6, 	0.3, 1},-- light Orange
	[FillType.HERBICIDE] =	{0.8, 	0.0, 	0.8,	1},		-- medium magenta	
	-- other pallets:
	[FillType.TREESAPLINGS]={0, 	0.39, 	0.09,	1},		-- Green
	[FillType.SUGARCANE] =	{0.014, 0.9, 	0.22,	1},		-- light Green
	[FillType.WOOL] =		{0.69, 	0.66, 	0.7, 	1},		-- light grey
	[FillType.EGG] =		{0.63, 	0.38, 	0.27,	1},		-- light brown
	[FillType.MILK] =		{0.59, 	0.62, 	0.62,	1},		-- light grey
	[FillType.POTATO] =		{0.15, 	0.05, 	0.05,	1},		-- light brown
	[FillType.SUGARBEET] =	{0.5, 	0.3, 	0.19,	1},		-- middle brown
	[FillType.POPLAR] =		{0.05, 	0.1, 	0.0,	1},		-- dark green
		}
	BaleSee.pallets = {
		[FillType.UNKNOWN] 		= 0	
		}
	BaleSee.ftIndex = {
		[FillType.STRAW]			= 1,
		[FillType.GRASS_WINDROW]	= 2,
		[FillType.DRYGRASS_WINDROW]	= 3,
		[FillType.SILAGE]			= 4,
		[FillType.COTTON]			= 5
	}
	BaleSee.ft 				= g_fillTypeManager.fillTypes
	BaleSee.ACTIONS 		= { bs_Bale = BaleSee.actionbs_Bale}
	-- make english plural:
	if g_gui.languageSuffix == "_en" then 
		for i=1,6,5 do
			BaleSee.baleType[i] = BaleSee.baleType[i].."S"
		end
	end	

	--load settings from modsSettings folder
	local key = "BaleSee"
	local f = BaleSee.modsSettings .. 'BaleSee.xml'
	if fileExists(f) then
		local xmlFile = loadXMLFile("BaleSee", f, key);
		BaleSee.baleState =		Utils.getNoNil(getXMLInt(xmlFile, key.."#baleState"), 1);			
		BaleSee.palState = 		Utils.getNoNil(getXMLInt(xmlFile, key.."#palState"), 1);			
		BaleSee.dispSize = 		Utils.getNoNil(getXMLInt(xmlFile, key.."#size"), 1);			
		BaleSee.debug = 	   	Utils.getNoNil(getXMLBool(xmlFile, key.."#debug"), false);			
		delete(xmlFile);
		-- set switches from BaleSee state values:
	    BaleSee.baleActivate, BaleSee.colorActivate = unpack(BaleSee.baleDisplay[BaleSee.baleState])
		BaleSee.palletActivate, BaleSee.colPalActivate = unpack(BaleSee.baleDisplay[BaleSee.palState])
	end;
	if BaleSee.debug then
		BaleSee:makeLegend()
		print("read settings from: ".. f)
		print(string.format("** Bales: %s %s. Pallets: %s %s. size: %d",
			BaleSee.visible[BaleSee.baleActivate],   BaleSee.isIcon[BaleSee.colorActivate],
			BaleSee.visible[BaleSee.palletActivate], BaleSee.isIcon[BaleSee.colPalActivate],
			BaleSee.dispSize))
	end
	-- make Gui texts global:
    local gTexts = G0.g_i18n.texts
    for k, v in pairs (g_i18n.texts) do
        local prefix, _ = k:find("BS_", 1, true)
        if prefix ~= nil then gTexts[k] = v; end
    end
    if G0.BaleSee == nil then G0.BaleSee = BaleSee; end

	-- load "BSGui.lua", "BSGui.xml"
	if not BaleSee:loadGUI(true, BaleSee.modDir.."gui/") then
		print(string.format(
		"** Info: - '%s.Gui' failed to load! Supporting files are missing.", BaleSee.modName))
	end
	BaleSee:init()
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
					BaleSee.modName, luaPath))
			end
		-- load "BSGui.xml"
			if canLoad then
				-- load my gui profiles 
				g_gui:loadProfiles(guiPath .. "guiProfiles.xml")
				local xmlPath = guiPath .. "BSGui.xml"
				if fileExists(xmlPath) then
					BaleSee.oGui = BSGui:new(nil, nil) 		-- my Gui object controller
					g_gui:loadGui(xmlPath, "BSGui", BaleSee.oGui)
				else
					canLoad = false
					print(string.format("**Error: [GuiLoader %s]  Required file '%s' could not be found!", 
						BaleSee.modName, xmlPath))
				end
			end
		end
	end
	return canLoad
end;
function BaleSee:init()
	if BaleSee.initialized then return; end
	if BaleSee.oGui == nil then 
		print("*Error* BaleSee Gui was not loaded")
		return
	end	
	BaleSee.bt 			= BaleSee.oGui.baleTable
	BaleSee.pt 			= BaleSee.oGui.palTable
	local drow, prof 

	-- initialize dataView for bale table:
	for i=1,BaleSee.BAL_TYPES do
		--columnCells.btype.text = baleType
		if i == 1 or i == 6 then prof = "baleSeeCategory"
		else prof = ""
		end
		drow = BaleSee:buildRow(BaleSee.baleType[i], BaleSee.bales[i], prof)
		table.insert(BaleSee.bt.dataView, drow)
	end
	BaleSee.bt:initialize(); 
	-- make overrideProfileName attributes possible for bt cells:
	BaleSee.bt:setProfileOverrideFilterFunction(function( cell )
		return true
	end)

	-- initialize dataView for pallet table:
	for k,v in pairs(BaleSee.pallets) do
		drow = BaleSee:buildRow(BaleSee.ft[k].title,v)
		table.insert(BaleSee.pt.dataView, drow)
	end
	BaleSee.pt:initialize(); 
	-- sorted descending on count:
	BaleSee.pt.customSortbeforeData = true
	BaleSee.pt.sortingColumn = "count"
	BaleSee.pt.sortingOrder = TableHeaderElement.SORTING_DESC

	BaleSee.initialized 	= true
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
	if name == BaleSee.baleType[1] or name == BaleSee.baleType[6] then
		row.columnCells.btype.overrideProfileName = "baleSeeCategory"
	end
	return row
end;
---------- "Mod main" ---------------------
addModEventListener(BaleSee);