AddCSLuaFile()
TOOL.Category = "Construction"
TOOL.Name = "KB RemoveProps"
TOOL.Author = "Kobralost"

KBRemoveProps = KBRemoveProps or {}

--[[ If you use mysql you have to enable this variable, configure mysql informations on the file lua/autorun/server/kb_removeprops_database.lua and restart your server ]]
KBRemoveProps.Mysql = false

--[[ Ranks access to the tool ]]
KBRemoveProps.RanksAccess = {
	["superadmin"] = true,
	["admin"] = true,
}

--[[ Language of the addon ]]
KBRemoveProps.SelectedLanguage = "en"

--[[ All constants of the addon ]]
KBRemoveProps.Constants = {
	["green"] = Color(46, 204, 113),
	["white"] = Color(240, 240, 240),
	["white5"] = Color(248, 247, 252, 5),
	["black"] = Color(0, 0, 0, 255),
	["grey"] = Color(150, 150, 150),
	["grey30"] = Color(150, 150, 150, 30),
	["red"] = Color(238, 82, 83),
	["toolgun"] = Material("kb_tools/removeprops_background.png", "$ignorez"),
	["background"] = Material("kb_tools/toolBackground.png", "smooth"),
}

-- [[ Language system ]] --
KBRemoveProps.Language = {
	["en"] = {
		["toolName"] = "KB Removeprops",
		["toolDesc"] = "Remove props created on your default map",
		["singlePlayer"] = "You are on singleplayer KBRemoveProps is disable and cannot work please lunch a peer to peer server",
		["toolLeft"] = "Left-click to remove the entity that you are looking at",
		["succesfulyRemoved"] = "Succesfuly removed the entity with the map creation id #%s",
		["succesfulyRemovedRemove"] = "Sucessfuly removed from the database the entity with the map creation id #%s (Cleanup or restart to respawn it)",
		["removePropsId"] = "KB RemoveProps - ID #%s",
		["noEntitiesRemoved"] = "No entities removed",
		["noEntitiesRemovedDesc"] = "You have not removed any entities yet",
	},
	["fr"] = {
		["toolName"] = "KB Removeprops",
		["toolDesc"] = "Remove props created on your default map",
		["singlePlayer"] = "You are on singleplayer KBRemoveProps is disable and cannot work please lunch a peer to peer server",
		["toolLeft"] = "Left-click to remove the entity that you are looking at",
		["succesfulyRemoved"] = "Succesfuly removed the entity with the map creation id #%s",
		["succesfulyRemovedRemove"] = "Sucessfuly removed from the database the entity with the map creation id #%s (Cleanup or restart to respawn it)",
		["removePropsId"] = "KB RemoveProps - ID #%s",
		["noEntitiesRemoved"] = "No entities removed",
		["noEntitiesRemovedDesc"] = "You have not removed any entities yet",
	},
}

if game.SinglePlayer() then
	for i=1, 5 do
		print(getSentence("peerToPeerNeededLog"))
	end
end

local function getSentence(key)
	local lang = KBRemoveProps.SelectedLanguage

	KBRemoveProps.Language = KBRemoveProps.Language or {}
	KBRemoveProps.Language[lang] = KBRemoveProps.Language[lang] or {}

	local langToReturn = KBRemoveProps.Language[lang][key] or (KBRemoveProps.Language["en"][key] and KBRemoveProps.Language["en"][key] or "Bad sentence")

	return langToReturn
end

local function callbackAllPlayersWithToolGun(callback)
	for k, v in pairs(player.GetAll()) do
		if not IsValid(v) then continue end

		local wep = v:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() != "gmod_tool" then continue end

		local toolName = v:GetInfo("gmod_toolmode")
		if toolName != "kb_removeprops" then continue end

		callback(v)
	end
end

if CLIENT then
	TOOL.Information = {
		{name = "left"},
	}

	local function reloadToolInfo()
		local singlePlayer = game.SinglePlayer()
		local singlePlayerText = getSentence("singlePlayer")

		language.Add("tool.kb_removeprops.name", getSentence("toolName"))
		language.Add("tool.kb_removeprops.desc", (singlePlayer and singlePlayerText or getSentence("toolDesc")))
		
		language.Add("tool.kb_removeprops.left", (singlePlayer and singlePlayerText or getSentence("toolLeft")))
	end
	reloadToolInfo()

	local function loadFonts()
		surface.CreateFont("KBRemoveProps:Font:01", {
			font = "Georama",
			extended = false,
			size = KBRemoveProps.ScrH*0.02,
			italic = false,
			weight = 0, 
			blursize = 0,
			scanlines = 0,
			antialias = true,
		})

		surface.CreateFont("KBRemoveProps:Font:02", {
			font = "Georama",
			extended = false,
			size = KBRemoveProps.ScrH*0.026,
			italic = false,
			weight = 0, 
			blursize = 0,
			scanlines = 0,
			antialias = true,
		})
	end

	local function createClientSideModel(mapCreationId, model, pos, ang, material, modelScale, color, skinEnt, removeTime)
		if not isstring(model) or not isvector(pos) or not isangle(ang) or not isstring(material) or not isnumber(modelScale) or not isnumber(removeTime) or not IsColor(color) then return end
		if timer.Exists("KBRemoveProps:RemoveClientSideModel:"..mapCreationId) then return end

		local model = ClientsideModel(model)
		model:SetPos(pos)
		model:SetAngles(ang)
		model:SetMaterial(material)
		model:SetModelScale(modelScale)
		model:SetColor(color)
		model:SetSkin(skinEnt)

		KBRemoveProps.PropsToShow[mapCreationId] = pos
	
		timer.Create("KBRemoveProps:RemoveClientSideModel:"..mapCreationId, removeTime, 1, function()
			if IsValid(model) then
				model:Remove()
				KBRemoveProps.PropsToShow[mapCreationId] = nil
			end
		end)

		return model
	end

	local function reloadRemovedEnt()
		if not istable(KBRemoveProps.PropsRemoved) then return end
		if not IsValid(KBRemovePropsScroll) then return end

		KBRemovePropsScroll:Clear()

		local getKeys = table.GetKeys(KBRemoveProps.PropsRemoved)

		table.sort(getKeys, function(a, b)
			return KBRemoveProps.PropsRemoved[a].mapCreationId > KBRemoveProps.PropsRemoved[b].mapCreationId
		end)

		for k, v in ipairs(getKeys) do
			local v = KBRemoveProps.PropsRemoved[v]
			if not istable(v) then continue end

			local removedEntity = vgui.Create("DPanel", KBRemovePropsScroll)
			removedEntity:Dock(TOP)
			removedEntity:SetSize(0, KBRemoveProps.ScrH*0.05)
			removedEntity:DockMargin(KBRemoveProps.ScrH*0.005, KBRemoveProps.ScrH*0.005, KBRemoveProps.ScrH*0.005, KBRemoveProps.ScrH*0.005)
			removedEntity.deleteConfirmation = false
			removedEntity.Paint = function(self, w, h)
				draw.RoundedBox(0, 0, 0, w, h, KBRemoveProps.Constants["white5"])
			end

			local modelEntity = vgui.Create("DLabel", removedEntity)
			modelEntity:SetPos(KBRemoveProps.ScrW*0.005, KBRemoveProps.ScrH*0.007)
			modelEntity:SetSize(KBRemoveProps.ScrW*0.12, KBRemoveProps.ScrH*0.02)
			modelEntity:SetText(v.model)
			modelEntity:SetFont("KBRemoveProps:Font:01")
			modelEntity:SetTextColor(KBRemoveProps.Constants["white"])

			local modelInfo = vgui.Create("DLabel", removedEntity)
			modelInfo:SetPos(KBRemoveProps.ScrW*0.005, KBRemoveProps.ScrH*0.025)
			modelInfo:SetSize(KBRemoveProps.ScrW*0.15, KBRemoveProps.ScrH*0.02)
			modelInfo:SetText(getSentence("removePropsId"):format(v.mapCreationId))
			modelInfo:SetFont("KBRemoveProps:Font:01")
			modelInfo:SetTextColor(KBRemoveProps.Constants["white"])

			local lerpColorName = 0
			local previewEntity = vgui.Create("DImageButton", removedEntity)
			previewEntity:SetPos(KBRemoveProps.ScrW*0.12, KBRemoveProps.ScrH*0.01)
			previewEntity:SetSize(KBRemoveProps.ScrH*0.03, KBRemoveProps.ScrH*0.03)
			previewEntity:SetImage("kb_tools/placeCube.png")
			previewEntity:SetColor(KBRemoveProps.Constants["white"])
			previewEntity.Paint = function(self, w, h)
				lerpColorName = Lerp(FrameTime()*5, lerpColorName, (self:IsHovered() and 255 or 100))
				self:SetColor(ColorAlpha(KBRemoveProps.Constants["white"], lerpColorName))
			end
			previewEntity.DoClick = function()
				createClientSideModel(v.mapCreationId, v.model, v.pos, v.ang, v.material, v.scale, v.color, v.skin, 10)

				net.Start("KBRemoveProps:MainNet")
					net.WriteUInt(1, 4)
					net.WriteVector(v.pos)
				net.SendToServer()
			end

			local lerpColorTrash = 0
			local trashEntity = vgui.Create("DImageButton", removedEntity)
			trashEntity:SetPos(KBRemoveProps.ScrW*0.14, KBRemoveProps.ScrH*0.01)
			trashEntity:SetSize(KBRemoveProps.ScrH*0.03, KBRemoveProps.ScrH*0.03)
			trashEntity:SetImage("kb_tools/trash.png")
			trashEntity.buttonColor = KBRemoveProps.Constants["white"]
			
			trashEntity:SetColor(trashEntity.buttonColor)
			trashEntity.Paint = function(self, w, h)
				lerpColorTrash = Lerp(FrameTime()*5, lerpColorTrash, (self:IsHovered() and 255 or 100))
				self:SetColor(ColorAlpha(trashEntity.buttonColor, lerpColorTrash))
			end
			trashEntity.DoClick = function()
				if not removedEntity.deleteConfirmation then
					trashEntity.buttonColor = KBRemoveProps.Constants["red"]
					removedEntity.deleteConfirmation = true

					timer.Simple(1, function()
						if not IsValid(removedEntity) then return end

						if IsValid(trash) then
							trashEntity.buttonColor = KBRemoveProps.Constants["white"]
						end

						removedEntity.deleteConfirmation = false
					end)

					return
				else
					net.Start("KBRemoveProps:MainNet")
						net.WriteUInt(2, 4)
						net.WriteUInt(v.mapCreationId, 32)
					net.SendToServer()
				end
			end
		end
	end

	local function paintCPanel(CPanel)
		CPanel.Paint = function(self, w, h)
			draw.RoundedBox(4, 0, 0, w, h, KBRemoveProps.Constants["black"])
			
			surface.SetDrawColor(KBRemoveProps.Constants["white"])
			surface.SetMaterial(KBRemoveProps.Constants["background"])
			surface.DrawTexturedRect(0, 0, w*2, h)

			local noEntitiesRemoved = false
			if IsValid(KBRemovePropsScroll) then
				local getChildrenScroll = KBRemovePropsScroll:GetChildren()

				if istable(getChildrenScroll) then
					local getChildren = getChildrenScroll[1]:GetChildren()

					if istable(getChildren) then
						if table.Count(getChildren) <= 0 then
							noEntitiesRemoved = true
						end
					end
				else
					noEntitiesRemoved = true
				end
			end

			if noEntitiesRemoved then
				draw.DrawText(getSentence("noEntitiesRemoved"), "KBRemoveProps:Font:02", w/2, h*0.45, KBRemoveProps.Constants["white"], TEXT_ALIGN_CENTER)
				draw.DrawText(getSentence("noEntitiesRemovedDesc"), "KBRemoveProps:Font:01", w/2, h*0.5, KBRemoveProps.Constants["white"], TEXT_ALIGN_CENTER)
			end
		end
		
		local mainPanel = vgui.Create("DPanel")
		mainPanel:SetSize(KBRemoveProps.ScrW*0.3, KBRemoveProps.ScrH*0.43)
		mainPanel:SetPos(0, 0)
		mainPanel.Paint = function(self, w, h) end

		KBRemovePropsScroll = vgui.Create("DScrollPanel", mainPanel)
		KBRemovePropsScroll:SetSize(mainPanel:GetWide(), KBRemoveProps.ScrH*0.4)
		KBRemovePropsScroll:SetPos(0, 0)
		KBRemovePropsScroll.Paint = function(self, w, h) 
			self:SetSize(mainPanel:GetWide(), KBRemoveProps.ScrH*0.4)

			draw.RoundedBox(0, 0, 0, w, h, KBRemoveProps.Constants["white5"])
		end

		local scrollBar = KBRemovePropsScroll:GetVBar()
		scrollBar:SetWide(KBRemoveProps.ScrW*0.003)
		scrollBar.Paint = function(self, w, h)
			draw.RoundedBox(0, 0, 0, w, h, KBRemoveProps.Constants["grey30"])
		end
		scrollBar.btnUp.Paint = function(self, w, h)
			draw.RoundedBox(0, 0, 0, w, h, KBRemoveProps.Constants["grey30"])
		end
		scrollBar.btnDown.Paint = function(self, w, h)
			draw.RoundedBox(0, 0, 0, w, h, KBRemoveProps.Constants["grey30"])
		end
		scrollBar.btnGrip.Paint = function(self, w, h)
			draw.RoundedBox(0, 0, 0, w, h, KBRemoveProps.Constants["grey30"])
		end

		reloadRemovedEnt()

		CPanel:AddPanel(mainPanel)
	end

	function TOOL.BuildCPanel(CPanel)
		if CLIENT then
			CPanel:AddControl("Header", {
				Text = "#tool.kb_removeprops.name",
				Description = ""
			})

			paintCPanel(CPanel)
		end
	end
	
	function TOOL:DrawToolScreen(w, h)
		surface.SetDrawColor(KBRemoveProps.Constants["white"])
		surface.SetMaterial(KBRemoveProps.Constants["toolgun"])
		surface.DrawTexturedRect(0, 0, w, h)
	end

	function TOOL:Holster()
		KBRemoveProps.PropsRemoved = {}

		return true
	end

	cvars.AddChangeCallback("gmod_language", function(convar_name, value_old, value_new)
		reloadToolInfo()
	end)

	hook.Add("HUDPaint", "KBRemoveProps:PosScreen", function()
		if not KBRemoveProps.RanksAccess[LocalPlayer():GetUserGroup()] then return end

		KBRemoveProps.PropsToShow = KBRemoveProps.PropsToShow or {}

		for k, v in pairs(KBRemoveProps.PropsToShow) do
			local pos = v:ToScreen()

			draw.DrawText(getSentence("removePropsId"):format(k), "KBRemoveProps:Font:02", pos.x, pos.y - 30, KBRemoveProps.Constants["white"], TEXT_ALIGN_CENTER)
			draw.DrawText("⚫", "KBRemoveProps:Font:02", pos.x, pos.y - 10, KBRemoveProps.Constants["green"], TEXT_ALIGN_CENTER)
		end
	end)

	hook.Add("HUDPaint", "KBRemoveProps:HUDPaint:Initialize", function()
		KBRemoveProps.ScrW, KBRemoveProps.ScrH = ScrW(), ScrH()
	
		loadFonts()
		hook.Remove("HUDPaint", "KBRemoveProps:HUDPaint:Initialize")
	end)

	hook.Add("OnScreenSizeChanged", "KBRemoveProps:OnScreenSizeChanged", function()
		KBRemoveProps.ScrW, KBRemoveProps.ScrH = ScrW(), ScrH()

		loadFonts()
	end)

	net.Receive("KBRemoveProps:SendNotification", function()
		local text = net.ReadString()
		local notifyType = net.ReadUInt(4)
		local time = net.ReadUInt(10)

		notification.AddLegacy(text, notifyType, time)
	end)

	net.Receive("KBRemoveProps:MainNet", function()
		local uInt = net.ReadUInt(4)

		if uInt == 1 then
			local count = net.ReadUInt(32)
			KBRemoveProps.PropsRemoved = {}

			for i=1, count do
				local model = net.ReadString()
				local pos = net.ReadVector()
				local ang = net.ReadAngle()
				local mapCreationId = net.ReadUInt(16)
				local color = net.ReadColor()
				local material = net.ReadString()
				local scale = net.ReadUInt(8)
				local entSkin = net.ReadUInt(6)

				KBRemoveProps.PropsRemoved[mapCreationId] = {
					["model"] = model,
					["pos"] = pos,
					["ang"] = ang,
					["mapCreationId"] = mapCreationId,
					["color"] = color,
					["material"] = material,
					["scale"] = scale,
					["skin"] = entSkin,
				}
			end

			reloadRemovedEnt()
		elseif uInt == 2 then
			local model = net.ReadString()
			local pos = net.ReadVector()
			local ang = net.ReadAngle()
			local mapCreationId = net.ReadUInt(16)
			local color = net.ReadColor()
			local material = net.ReadString()
			local scale = net.ReadUInt(8)
			local entSkin = net.ReadUInt(6)

			KBRemoveProps.PropsRemoved[mapCreationId] = {
				["model"] = model,
				["pos"] = pos,
				["ang"] = ang,
				["mapCreationId"] = mapCreationId,
				["color"] = color,
				["material"] = material,
				["scale"] = scale,
				["skin"] = entSkin,
			}

			reloadRemovedEnt()
		elseif uInt == 3 then
			local mapCreationId = net.ReadUInt(32)

			if timer.Exists("KBRemoveProps:RemoveClientSideModel:"..mapCreationId) then 
				timer.Remove("KBRemoveProps:RemoveClientSideModel:"..mapCreationId)
			end

			local clientProp = KBRemoveProps.PropsToShow[mapCreationId]

			if IsValid(clientProp) then
				clientProp:Remove()
			end

			KBRemoveProps.PropsRemoved[mapCreationId] = nil
			reloadRemovedEnt()
		end
	end)
else
	util.AddNetworkString("KBRemoveProps:SendNotification")
	util.AddNetworkString("KBRemoveProps:MainNet")

	-- [[ Mysql database connection system ]] --
	local mysqlDB
	KBRemoveProps.MysqlConnected = false

	if KBRemoveProps.Mysql then
		local succ, err = pcall(function() require("mysqloo") end)
		if not succ then return print("[KBRemoveProps] Error with MYSQLOO") end
		
		if not mysqloo then
			return print("[KBRemoveProps] Cannot require mysqloo module :\n"..requireError)
		end

		mysqlDB = mysqloo.connect(KBRemoveProps.MysqlInformations["host"], KBRemoveProps.MysqlInformations["username"], KBRemoveProps.MysqlInformations["password"], KBRemoveProps.MysqlInformations["database"], {["port"] = KBRemoveProps.MysqlInformations["port"]})

		function mysqlDB:onConnected()  
			print("[KBRemoveProps] Succesfuly connected to the mysql database !")
			KBRemoveProps.MysqlConnected = true
		end
		
		function mysqlDB:onConnectionFailed(connectionError)
			print("[KBRemoveProps] Cannot etablish database connection :\n"..connectionError)
		end
		mysqlDB:connect()
	end

	--[[ SQL Query function ]] --
	function KBRemoveProps.Query(query, callback)
		if not isstring(query) then return end

		local result = {}
		local isInsertQuery = string.StartWith(query, "INSERT")
		if KBRemoveProps.Mysql then
			query = mysqlDB:query(query)

			if callback == "wait" then
				query:start()
				query:wait()

				local err = query:error()
				if err == "" then
					return isInsertQuery and { lastInsertId = query:lastInsert() } or query:getData()
				else
					print("[KBRemoveProps] "..err)
				end
			else
				function query:onError(err, sql)
					print("[KBRemoveProps] "..err)
				end

				function query:onSuccess(tbl, data)
					if isfunction(callback) then
						callback(isInsertQuery and { lastInsertId = query:lastInsert() } or tbl)
					end
				end
				query:start()
			end
		else
			result = sql.Query(query)
			result = isInsertQuery and { lastInsertId = sql.Query("SELECT last_insert_rowid()")[1]["last_insert_rowid()"] } or result

			if callback == "wait" then
				return result
				
			elseif isfunction(callback) then
				callback(result)

				return
			end
		end

		return (result or {})
	end

	-- [[ Escape the string ]] --  
	function KBRemoveProps.Escape(str)
		return KBRemoveProps.MysqlConnected and ("'%s'"):format(mysqlDB:escape(tostring(str))) or SQLStr(str)    
	end

	-- [[ Function to add a compatibility with autoincrement ]]
	function KBRemoveProps.AutoIncrement()
		return (KBRemoveProps.Mysql and "AUTO_INCREMENT" or "AUTOINCREMENT")
	end

	function KBRemoveProps.InitDatabaseTable()
		KBRemoveProps.Query(([[CREATE TABLE IF NOT EXISTS kb_removeprops (
			id INTEGER PRIMARY KEY %s, 
			class TEXT, 
			model TEXT, 
			pos TEXT,
			ang TEXT,
			map TEXT,
			mapCreationId INT,
			color TEXT,
			material TEXT,
			scale INT,
			skin INT,
			option LONGTEXT)]]
		):format(KBRemoveProps.AutoIncrement()))
	end

	local KBRemovePropsMap = game.GetMap():lower()
	local PLAYER = FindMetaTable("Player")

	function PLAYER:KBRemovePropsNotify(text, notifyType, time)
		net.Start("KBRemoveProps:SendNotification")
			net.WriteString(text)
			net.WriteUInt(notifyType, 4)
			net.WriteUInt(time, 10)
		net.Send(self)
	end

	-- [[ Save removed prop on the database ]]
	function KBRemoveProps.SaveEntRemoved(ent, ply)
		if not IsValid(ent) then return end

		local class = ent:GetClass()
		local model = ent:GetModel()
		local pos = ent:GetPos()
		local ang = ent:GetAngles()
		local mapCreationId = ent:MapCreationID()
		local color = ent:GetColor()
		local material = ent:GetMaterial()
		local scale = ent:GetModelScale()
		local entSkin = ent:GetSkin()

		if mapCreationId == -1 then
			return
		end

		local options = {}

		KBRemoveProps.Query(([[INSERT INTO kb_removeprops (class, model, pos, ang, map, mapCreationId, color, material, scale, skin, option) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)]]):format(
			KBRemoveProps.Escape(class),
			KBRemoveProps.Escape(model),
			KBRemoveProps.Escape(tostring(pos)),
			KBRemoveProps.Escape(tostring(ang)),
			KBRemoveProps.Escape(KBRemovePropsMap),
			KBRemoveProps.Escape(mapCreationId),
			KBRemoveProps.Escape(util.TableToJSON(color)),
			KBRemoveProps.Escape(material),
			KBRemoveProps.Escape(scale),
			KBRemoveProps.Escape(entSkin),
			KBRemoveProps.Escape(util.TableToJSON(options))
		), function(data)
			local lastInsertId = tonumber(data.lastInsertId)
			if not isnumber(lastInsertId) then return end

			ent:EmitSound("buttons/button24.wav")

			ent:Remove()

			if IsValid(ply) then
				ply:KBRemovePropsNotify(getSentence("succesfulyRemoved"):format(mapCreationId), 0, 5)
			end

			callbackAllPlayersWithToolGun(function(ply)
				if IsValid(ply) then
					KBRemoveProps.SendEntRemoved(ply, mapCreationId)
				end
			end)
		end)
	end

	function KBRemoveProps.RemoveAllEntRemoved()
		KBRemoveProps.Query(([[SELECT * FROM kb_removeprops WHERE map = %s]]):format(KBRemoveProps.Escape(KBRemovePropsMap)), function(data)
			if not istable(data) then return end

			for k, v in ipairs(data) do
				local ent = ents.GetMapCreatedEntity(v.mapCreationId)
				if not IsValid(ent) then continue end

				ent:Remove()
			end
		end)
	end

	function KBRemoveProps.SendAllEntRemoved(ply)
		KBRemoveProps.Query(([[SELECT * FROM kb_removeprops WHERE map = %s]]):format(KBRemoveProps.Escape(KBRemovePropsMap)), function(data)
			if not istable(data) then return end

			net.Start("KBRemoveProps:MainNet")
				net.WriteUInt(1, 4)
				net.WriteUInt(table.Count(data), 32)
				for k, v in ipairs(data) do
					local model = (v.model or "")

					local pos = util.StringToType(v.pos, "Vector")
					if not isvector(pos) then
						pos = Vector(0, 0, 0)
					end

					local ang = util.StringToType(v.ang, "Angle")
					if not isangle(ang) then
						ang = Angle(0, 0, 0)
					end

					local mapCreationId = (v.mapCreationId or 0)

					local color = util.JSONToTable(v.color)
					if istable(color) then
						color = Color(color.r, color.g, color.b, color.a)
					else
						color = color_white
					end

					local material = (v.material or "")
					local scale = (tonumber(v.scale) or 1)
					local entSkin = (tonumber(v.skin) or 0)

					net.WriteString(model)
					net.WriteVector(pos)
					net.WriteAngle(ang)
					net.WriteUInt(mapCreationId, 16)
					net.WriteColor(color)
					net.WriteString(material)
					net.WriteUInt(scale, 8)
					net.WriteUInt(entSkin, 6)
				end
			net.Send(ply)
		end)	
	end

	function KBRemoveProps.SendEntRemoved(ply, mapCreationId)
		KBRemoveProps.Query(([[SELECT * FROM kb_removeprops WHERE map = %s AND mapCreationId = %s]]):format(KBRemoveProps.Escape(KBRemovePropsMap), KBRemoveProps.Escape(mapCreationId)), function(data)
			if not istable(data) then return end

			net.Start("KBRemoveProps:MainNet")
				net.WriteUInt(2, 4)
				for k, v in ipairs(data) do
					local model = (v.model or "")
					
					local pos = util.StringToType(v.pos, "Vector")
					if not isvector(pos) then
						pos = Vector(0, 0, 0)
					end

					local ang = util.StringToType(v.ang, "Angle")
					if not isangle(ang) then
						ang = Angle(0, 0, 0)
					end

					local mapCreationId = (v.mapCreationId or 0)

					local color = util.JSONToTable(v.color)
					if istable(color) then
						color = Color(color.r, color.g, color.b, color.a)
					else
						color = color_white
					end

					local material = (v.material or "")
					local scale = (tonumber(v.scale) or 1)
					local entSkin = (tonumber(v.skin) or 0)

					net.WriteString(model)
					net.WriteVector(pos)
					net.WriteAngle(ang)
					net.WriteUInt(mapCreationId, 16)
					net.WriteColor(color)
					net.WriteString(material)
					net.WriteUInt(scale, 8)
					net.WriteUInt(entSkin, 6)
				end
			net.Send(ply)
		end)	
	end

	function KBRemoveProps.SendEntRemovedRemove(ply, mapCreationId)
		net.Start("KBRemoveProps:MainNet")
			net.WriteUInt(3, 4)
			net.WriteUInt(mapCreationId, 32)
		net.Send(ply)
	end

	function KBRemoveProps.RemoveEntRemoved(mapCreationId, remover)
		KBRemoveProps.Query(([[DELETE FROM kb_removeprops WHERE map = %s AND mapCreationId = %s]]):format(KBRemoveProps.Escape(KBRemovePropsMap), KBRemoveProps.Escape(mapCreationId)), function()
			if IsValid(remover) then
				remover:KBRemovePropsNotify(getSentence("succesfulyRemovedRemove"):format(mapCreationId), 0, 5)
			end

			callbackAllPlayersWithToolGun(function(ply)
				if IsValid(ply) then
					KBRemoveProps.SendEntRemovedRemove(ply, mapCreationId)
				end
			end)
		end)
	end

	function TOOL:LeftClick()
		local owner = self:GetOwner()
		if not KBRemoveProps.RanksAccess[owner:GetUserGroup()] then return end

		self.KBRemoveProps = self.KBRemoveProps or {}

		local curTime = CurTime()

		self.KBRemoveProps["antiSpam"] = self.KBRemoveProps["antiSpam"] or 0
		if self.KBRemoveProps["antiSpam"] > curTime then return end
		self.KBRemoveProps["antiSpam"] = curTime + 0.5

		local trace = owner:GetEyeTrace()
		local ent = trace.Entity

		if not IsValid(ent) or ent:IsPlayer() or ent:IsVehicle() or ent:IsWorld() then return end

		KBRemoveProps.SaveEntRemoved(ent, owner)
	end

	function TOOL:Deploy()
		local owner = self:GetOwner()
		if not KBRemoveProps.RanksAccess[owner:GetUserGroup()] then return end

		KBRemoveProps.SendAllEntRemoved(owner)
	end

	net.Receive("KBRemoveProps:MainNet", function(len, ply)
		if not IsValid(ply) then return end

		ply.KBRemoveProps = ply.KBRemoveProps or {}

		local curTime = CurTime()

		ply.KBRemoveProps["antiSpam"] = ply.KBRemoveProps["antiSpam"] or 0
		if ply.KBRemoveProps["antiSpam"] > curTime then return end
		ply.KBRemoveProps["antiSpam"] = curTime + 0.5

		local uInt = net.ReadUInt(4)

		if uInt == 1 then
			if not KBRemoveProps.RanksAccess[ply:GetUserGroup()] then return end
			local posToGo = net.ReadVector()

			if ply:GetPos():DistToSqr(posToGo) > 2000000 then 
				ply:SetPos(posToGo)
			end

		elseif uInt == 2 then
			if not KBRemoveProps.RanksAccess[ply:GetUserGroup()] then return end
			local mapCreationId = net.ReadUInt(32)
			
			KBRemoveProps.RemoveEntRemoved(mapCreationId, ply)
		end
	end)
	
	hook.Add("PostCleanupMap", "KBRemoveProps:PostCleanupMap:ReloadAllSavedEnts", function()
		KBRemoveProps.RemoveAllEntRemoved()
	end)

	hook.Add("InitPostEntity", "KBRemoveProps:InitPostEntity:InitDatabase", function()
		KBRemoveProps.InitDatabaseTable()

		timer.Simple(2, function()
			KBRemoveProps.RemoveAllEntRemoved()
		end)
	end)
end
