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

G0 = getfenv(0) 					-- to get at all globals
source(Utils.getFilename("RoyalMod.lua", g_currentModDirectory.."scripts/")) 	-- RoyalMod support functions

BaleSee	= RoyalMod.new(true, true) 	-- (debug, mpSync)

function BaleSee:initialize()
	self.bales 		= {} 			-- bale counts per farm and type
	self.pallets 	= {} 			-- pallet counts per farm and type
	self.bHotspots 	= {{},{},{},{},{},{},{},{}}	-- bale hotspots for each farm
	self.pHotspots	= {}			-- all pallet hotspots, each entry is a tuple {hotspot, color, image}
	self.pal 		= {} 			-- specialization for pallet vehicletype
	self.legend 	= {} 			-- save hotspots for map legend
	self.initialized 	= false
	self.oGui			= nil 		-- object handle Gui controller
	self.bt 			= nil		-- Gui bale Table
	self.pt 			= nil		-- Gui pallet Table
	
	---------------- constants -----------------------------------------------------------------------
	self.version 	= "2.1.0.0" 	-- allow all future pallet fillTypes
	self.modsSettings= string.sub(g_modsDirectory,1,-2) .. "Settings/"
	self.visible 	=	{"invisible", "visible", "visible"}
	self.isIcon 	=	{[false] = 	"icons";	[true]  =	"spots"}
	self.isRound	=	{[false] = 	g_i18n:getText("BS_square"); [true] = g_i18n:getText("BS_round")}
	self.icons 		=	{
			squareStraw	= "HotspotIcons/square/StrawSquareBale.dds",
			squareHay	= "HotspotIcons/square/HaySquareBale.dds",
			squareGrass	= "HotspotIcons/square/GrassSquareBale.dds",
			squareSilage= "HotspotIcons/square/SilageSquareBale.dds",
			squareCotton= "HotspotIcons/square/CottonSquareBale.dds",
			roundStraw	= "HotspotIcons/round/StrawRoundBale.dds",
			roundHay	= "HotspotIcons/round/HayRoundBale.dds",
			roundGrass	= "HotspotIcons/round/GrassRoundBale.dds",
			roundSilage	= "HotspotIcons/round/SilageRoundBale.dds",
			woolPallet	= "HotspotIcons/WoolPallet.dds",
			otherPallet	= "HotspotIcons/Pallet.dds",
			potatoPallet= "HotspotIcons/potato.dds",
			beetPallet	= "HotspotIcons/sugarbeet.dds",
			carrPallet	= "HotspotIcons/carrot.dds",
			milkPallet	= "HotspotIcons/milkpallet.dds",
			eggsPallet	= "HotspotIcons/eggs.dds",
			-- Transparent image used as background to show hotspot icons 
			-- without the usual default (black) background:
			bgImage		= "HotspotIcons/BGOverlay.dds",	
						} 
	self.showOpts 	= {g_i18n:getText("ui_off"),g_i18n:getText("BS_icons"),g_i18n:getText("BS_symbols")}
	self.sizeOpts 	= {g_i18n:getText("configuration_valueSmall"), g_i18n:getText("setting_medium"), 
				   		   g_i18n:getText("configuration_valueBig")}
	self.ROUND 		= g_i18n:getText("fillType_roundBale")		   		   
	self.SQUARE 	= g_i18n:getText("fillType_squareBale")	
	self.baleIdToHash= {}	   			-- to find bale type from bale.id   
	self.numBalTypes = {0,0,0,0,0,0,0,0}-- # of diff bale types per farm/ length of self.bales[i]
	self.numBales 	= {0,0,0,0,0,0,0,0}	-- total bales for each farm
	self.numPals 	= {0,0,0,0,0,0,0,0}	-- total pallets for each farm
	self.MAXLINES 	= 16 				-- # of rows of bale/ pallets display list
	self.baleState	= 2 				-- 1:off, 2:icon, 3:dot
	self.palState 	= 2 				-- off
	self.dispSize 	= 3					-- 1:small, 2:medium, 3:large
	self.statFarm 	= nil 				-- farmId to display bale/pall stats
	self.symSizes 	= {
		{ icon = {getNormalizedScreenValues(6,6)}, 	dot = {getNormalizedScreenValues(5,5)}  },  --"small"
		{ icon = {getNormalizedScreenValues(8,8)}, 	dot = {getNormalizedScreenValues(7,7)}  },  --"medium"
		{ icon = {getNormalizedScreenValues(11,11)},dot = {getNormalizedScreenValues(10,10)}}  	--"large"
		}
	self.bgImage 	= Utils.getFilename(self.icons.bgImage, self.directory)
	self.uvB		= getNormalizedUVs({776, 776, 240, 240}) -- 8 + 3* 256 = 776
	self.uvP		= getNormalizedUVs({520, 520, 240, 240}) -- 8 + 2* 256 = 520
	
	-- ---------------Event definitions ----------------------
	source(self.directory.."scripts/events.lua")
	-- ---------------Helper functions------------------------
	source(self.directory.."scripts/helper.lua")
	-- ---------------Manage Hotspots for bales --------------
	source(self.directory.."scripts/hotspots.lua")
	------------------User interface / pallet functions ------
	source(self.directory.."scripts/userint.lua")

    G0["g_baleSee"] = self

	-- SaveSettings
	FSBaseMission.saveSavegame 	= Utils.appendedFunction(FSBaseMission.saveSavegame, self.saveSettings);	

	-- Append functions for bales.
	InGameMenuMapFrame.showContextBox = 
		Utils.appendedFunction(InGameMenuMapFrame.showContextBox, self.showContextBox)
	NetworkNode.addObject = Utils.appendedFunction(NetworkNode.addObject, self.addObject);
	Bale.readStream = 	Utils.overwrittenFunction(Bale.readStream, self.readStream);
	Bale.register = 	Utils.appendedFunction(Bale.register, self.newBale);
	Bale.delete = 		Utils.prependedFunction(Bale.delete, self.delete);
	
--[[ make Gui texts global:
    local gTexts = G0.g_i18n.texts
    for k, v in pairs (g_i18n.texts) do
        local prefix, _ = k:find("BS_", 1, true)
        if prefix ~= nil then gTexts[k] = v; end
    end
]]
	--load settings from modsSettings folder
	local key = "BaleSee"
	local f = self.modsSettings .. 'BaleSee.xml'
	if fileExists(f) then
		local xmlFile = loadXMLFile("BaleSee", f, key);
		self.baleState =Utils.getNoNil(getXMLInt(xmlFile, key.."#baleState"), 2);			
		self.palState = Utils.getNoNil(getXMLInt(xmlFile, key.."#palState"), 2);			
		self.dispSize = Utils.getNoNil(getXMLInt(xmlFile, key.."#size"), 3);			
		self.debug =	Utils.getNoNil(getXMLBool(xmlFile, key.."#debug"), false);			
		delete(xmlFile);
	end;
	if self.debug then
		print("read settings from: ".. f)
		print(string.format("** baleState: %d. palletState: %d. size: %d",
			self.baleState, self.palState, self.dispSize))
	end
	-- load "BSGui.lua", "BSGui.xml"
	if not self:loadGUI(true, self.directory.."gui/") then
		print(string.format(
		"** Error: - '%s.Gui' failed to load! Supporting files are missing.", self.name))
		return
	end
	self.bt 			= self.oGui.baleTable
	self.pt 			= self.oGui.palTable
	self.initialized 	= true
	print(string.format("  Loaded %s V%s", self.name, self.version))
end;
function BaleSee:onStartMission()
	--[[ if client in MP game, request initial bale table from server
	if g_server == nil then 
		g_client:getServerConnection():sendEvent(SeeBalesJoinEvent:emptyNew())
	end	
	]]
end;
----------------------- initilization on load Map ----------------------------------------------
function BaleSee:onPostLoadMap()
	self = g_baleSee
	if self.debug then print("-- BaleSee:loadMap() --") end
	self.ft 			= g_fillTypeManager.fillTypes
	self.isMultiplayer 	= g_currentMission.missionDynamicInfo.isMultiplayer 
	self.baleCols		=	{  -- set this here, because FillType.x is not yet filled, outside of loadMap()
		-- the standard game bale types:
		[FillType.STRAW] =		{{0.6, 	0.3, 	0, 		1},	-- Orange
								 self.directory..self.icons.roundStraw, self.directory..self.icons.squareStraw},
		[FillType.DRYGRASS_WINDROW] ={{0.4, 	1, 		0.4, 	1},	-- Light Green
								 self.directory..self.icons.roundHay, self.directory..self.icons.squareHay},
		[FillType.GRASS_WINDROW]={{0.1, 	0.2, 	0, 		1},		-- Dark Green
								 self.directory..self.icons.roundGrass, self.directory..self.icons.squareGrass},
		[FillType.SILAGE] =		{{0.95, 	0.35, 	0.35,	1},		-- pink
								 self.directory..self.icons.roundSilage, self.directory..self.icons.squareSilage},
		[FillType.COTTON] =		{{0.5, 	0.5, 	0.7,	1},		-- grey
								 self.directory..self.icons.squareCotton, self.directory..self.icons.squareCotton},
		}
	self.pallCols = {	
		-- pallet big bags:
		[FillType.UNKNOWN] =	{{1, 	0, 		1, 		1},			-- Magenta
								 "data/store/store_empty.png"},
		[FillType.PIGFOOD] =	{{0.27, 	0.085,	0.085, 	1},		-- dark pink
								 "data/objects/bigBagContainer/store_bigBagContainerPigFood.png"},
		[FillType.FERTILIZER] = {{0.55, 	0.25, 	0.25,	1},		-- medium pink
								 "data/objects/bigBagContainer/store_bigBagContainerFertilizer.png"},
		[FillType.LIME] =		{{1, 	0.6, 	0.6, 	1},			-- light pink
								 "data/objects/bigBagContainer/store_bigBagContainerLime.png"},
		[FillType.WHEAT] =		{{0.55, 	0.5, 	0.26,	1},		-- light bronze
								 "data/objects/bigBagContainer/store_bigBagContainerChickenFood.png"},
		[FillType.OAT] =		{{0.34, 	0.29, 	0.15,	1},		-- medium bronze	
								 "data/objects/bigBagContainer/store_bigBagContainerHorseFood.png"},		
		[FillType.SEEDS] =		{{0.1, 	0.04, 	0.04, 	1},			-- dark brown
								 nil},-- because SEEDS can also be a pallet. So we rely on the store item image
		-- pallet tanks:
		[FillType.LIQUIDFERTILIZER] = {{0.79, 	0.6, 	0.3, 1},-- light Orange
								 "data/objects/pallets/liquidTank/store_fertilizerTank.png"},
		[FillType.HERBICIDE] =	{{0.8, 	0.0, 	0.8,	1},		-- medium magenta	
								 "data/objects/pallets/liquidTank/store_herbicideTank.png"},
		-- other pallets:
		[FillType.TREESAPLINGS]={{0, 	0.39, 	0.09,	1},		-- Green
								 "data/objects/pallets/treeSaplingPallet/store_pallet_saplings.png"},
		[FillType.SUGARCANE] =	{{0.014, 0.9, 	0.22,	1},		-- light Green
								 "data/objects/pallets/palletSugarCane/store_palletSugarCane.png"},
		[FillType.WOOL] =		{{0.69, 	0.66, 	0.7, 	1},		-- light grey
								 self.directory..self.icons.woolPallet},
		[FillType.EGG] =		{{0.63, 	0.38, 	0.27,	1},		-- light brown
								 self.directory..self.icons.eggsPallet},
		[FillType.MILK] =		{{0.59, 	0.62, 	0.62,	1},		-- light grey
								 self.directory..self.icons.milkPallet},
		[FillType.POTATO] =		{{0.15, 	0.05, 	0.05,	1},		-- light brown
								 self.directory..self.icons.potatoPallet},
		[FillType.SUGARBEET] =	{{0.5, 	0.3, 	0.19,	1},		-- middle brown
								 self.directory..self.icons.beetPallet},
		[FillType.POPLAR] =		{{0.05, 	0.1, 	0.0,	1},		-- dark green
								 "data/objects/pallets/palletPoplar/store_pallet_saplingsPoplar.png"},
		}
	-- Carrot pallets:
	local ft = g_fillTypeManager.nameToIndex["CARROT"]
	if ft ~= nil then
		self.pallCols[ft] = 	{{1, 	0.4, 	0.1,	1},		-- orange
								 self.directory..self.icons.carrPallet}
	end	
	-- additional bale types (i.e. for maize+ extension)
	self:loadBaleTypes()

	-- keep bale tables for each farm individually (MP)
	for i = 1,8 do
		self.bales[i] = {[FillType.UNKNOWN] = {
							text = "unknown (n/a)" ,
							number = 0	
							}}
		self.pallets[i] = {[FillType.UNKNOWN] = 0}
	end

	-- initialize dataView for BALE table:
	local drow 
	for k,v in pairs(self.bales[1]) do
		drow = self:buildRow(v.text, v.number)
		table.insert(self.bt.dataView, drow)
	end
	-- initialize dataView for PALLET table:
	for k,v in pairs(self.pallets[1]) do
		drow = self:buildRow(self.ft[k].title, v)
		table.insert(self.pt.dataView, drow)
	end
	-- sorted ascending on btype:
	for _,t in ipairs({"bt","pt"}) do
		self[t].customSortbeforeData = true
		self[t].sortingColumn = "btype"
		self[t].sortingOrder = TableHeaderElement.SORTING_ASC
		self[t]:initialize();
	end 
    -- to insert Shift-B key for player F1-menu
    Player.registerActionEvents = Utils.appendedFunction(Player.registerActionEvents, self.registerActionEventsPlayer);
	Player.removeActionEvents = Utils.appendedFunction(Player.removeActionEvents, self.removeActionEventsPlayer);		
		
	-- register the functions to be triggered for pallets (is a vehicle type :)
	local pType =  g_vehicleTypeManager:getVehicleTypeByName("pallet")
	SpecializationUtil.registerEventListener(pType, "onLoadFinished",  	self.pal)
	SpecializationUtil.registerEventListener(pType, "onDelete", 		self.pal)	
	SpecializationUtil.registerEventListener(pType, "onChangedFillType",self.pal)	
	if self.debug then
		self:makeLegend() 	-- needs self.colors
        addConsoleCommand("bsLegend", "Switch legend display on ingameMap [on / off].", "toggleLegend", self)
        addConsoleCommand("bsObjects", "Look for owned bales on client [balesOnly].", "cltObjects", self)
	end
end;
function BaleSee:onWriteStream(streamId)
	-- write to a client when it joins
    local farms = {}
    -- how many farms to send?
    for i = 1,8 do
		if self.numBalTypes[i] > 0 then 
			farms[i] = self.numBalTypes[i]
		end	
    end	
    local nf = table.getn(farms)
	print((" - BaleSee:writeStream() info for %d farms to client stream %s"):format(nf,streamId))
    streamWriteInt8(streamId, nf) 					-- # of farm entries
	for i,n in pairs(farms) do
		streamWriteInt8(streamId, i) 				-- farmId
		streamWriteInt32(streamId, self.numBales[i])-- # bales == # of following hotspots
		for _,v in ipairs(self.bHotspots[i]) do
			NetworkUtil.writeNodeObjectId(streamId, v[4])
		end

		streamWriteInt8(streamId, n) 				-- # of following bale types
		for h,v in pairs(self.bales[i]) do
			if h > FillType.UNKNOWN then 			-- skip 1st entry ("UNKNOWN")
				streamWriteInt32(streamId, h) 		-- hash
				streamWriteInt32(streamId, v.number)  
				streamWriteString(streamId, v.text)
			end
		end
	end
end;
function BaleSee:onReadStream(streamId)
	-- runs when a client joins the game
	print((" - BaleSee:receiveData(%s) called"):format(streamId))
    local farms = streamReadInt8(streamId)
    print(tostring(farms).." farms:")
    local i,n,nh, hash  
    for _ = 1,farms do
		i = streamReadInt8(streamId) 				-- farmId
		nh = streamReadInt32(streamId) 				-- #bales == #hotspots
		self.numBales[i] = nh
		print(string.format("  read %d hotspots for farm %d:",nh,i))
		for _ = 1,nh do
			baleId = NetworkUtil.readNodeObjectId(streamId) 	
			table.insert(self.bHotspots[i], {nil, nil, nil, baleId}) -- bale id on server
			print(string.format("   %s", baleId))
		end

		n = streamReadInt8(streamId) 				-- # of bale entries
		self.numBalTypes[i] = n 
		print(string.format("  read %d baletypes for farm %d",n,i))
		for _ = 1,n do
			hash = streamReadInt32(streamId)
			print(string.format("   hash: %s",hash))
			self.bales[i][hash] = {number = streamReadInt32(streamId),
									text = streamReadString(streamId)}
			print(string.format("   %s %s",self.bales[i][hash].number, self.bales[i][hash].text))
		end
    end	
end;
