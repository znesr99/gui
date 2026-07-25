--========================================================
-- SaveManager System
-- Version: 2.0.0
-- Description: ระบบจัดการ Config ที่ใช้งานง่าย
-- Make My : Ai DeepSeek & Zens
--========================================================

local SaveManager = {}
SaveManager.__index = SaveManager

-- สร้าง instance ใหม่
function SaveManager.new()
    local self = setmetatable({}, SaveManager)
    
    -- ตั้งค่าเริ่มต้น
    self.Folder = "SaveManagerSettings"
    self.Options = {}
    self.Ignore = {}
    self.Parser = {}
    self.CurrentConfig = nil
    self.AutoLoadEnabled = false
    self.Library = nil
    self.HttpService = game:GetService("HttpService")
    
    -- ตั้งค่า Parser
    self:SetupParser()
    
    -- สร้างโฟลเดอร์
    self:BuildFolderTree()
    
    return self
end

--========================================================
-- Parser System
--========================================================

function SaveManager:SetupParser()
    self.Parser = {
        -- Toggle (เปิด/ปิด)
        Toggle = {
            Save = function(idx, object)
                return { type = "Toggle", idx = idx, value = object.Value }
            end,
            Load = function(idx, data)
                if self.Options[idx] then
                    self.Options[idx]:SetValue(data.value)
                end
            end,
        },
        
        -- Slider (เลื่อนปรับค่า)
        Slider = {
            Save = function(idx, object)
                return { type = "Slider", idx = idx, value = object.Value }
            end,
            Load = function(idx, data)
                if self.Options[idx] then
                    self.Options[idx]:SetValue(data.value)
                end
            end,
        },
        
        -- Dropdown (ตัวเลือก)
        Dropdown = {
        Save = function(idx, object)
    
            local Value = object.Value
    
            if object.Multi and type(Value) == "table" then
                local NewValue = {}
    
                for k,v in pairs(Value) do
                    if v == true then
                        table.insert(NewValue,k)
                    elseif type(k) == "number" then
                        table.insert(NewValue,v)
                    end
                end
    
                Value = NewValue
            end
    
            return {
                type = "Dropdown",
                idx = idx,
                value = Value,
                multi = object.Multi or false
            }
        end,
    
    
        Load = function(idx, data)
    
            if self.Options[idx] then
    
                if data.multi then
    
                    local Value = {}
    
                    for _,v in ipairs(data.value or {}) do
                        Value[v] = true
                    end
    
                    self.Options[idx]:SetValue(Value)
    
                else
    
                    self.Options[idx]:SetValue(data.value)

                    end
        
                end
        
            end,
        },
        
        -- Colorpicker (เลือกสี)
        Colorpicker = {
            Save = function(idx, object)
                return { 
                    type = "Colorpicker", 
                    idx = idx, 
                    value = object.Value:ToHex(), 
                    transparency = object.Transparency or 1
                }
            end,
            Load = function(idx, data)
                if self.Options[idx] then
                    self.Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
                end
            end,
        },
        
        -- Keybind (ปุ่มลัด)
        Keybind = {
            Save = function(idx, object)
                return { 
                    type = "Keybind", 
                    idx = idx, 
                    mode = object.Mode, 
                    key = object.Value 
                }
            end,
            Load = function(idx, data)
                if self.Options[idx] then
                    self.Options[idx]:SetValue(data.key, data.mode)
                end
            end,
        },
        
        -- Input (ช่องกรอกข้อความ)
        Input = {
            Save = function(idx, object)
                return { type = "Input", idx = idx, text = object.Value }
            end,
            Load = function(idx, data)
                if self.Options[idx] and type(data.text) == "string" then
                    self.Options[idx]:SetValue(data.text)
                end
            end,
        },
    }
end

--========================================================
-- Core Functions
--========================================================

-- ตั้งค่า Library (Fluent, etc.)
function SaveManager:SetLibrary(library)
    self.Library = library
    if library and library.Options then
        self.Options = library.Options
    end
end

-- ตั้งชื่อโฟลเดอร์
function SaveManager:SetFolder(folder)
    self.Folder = folder or "SaveManagerSettings"
    self:BuildFolderTree()
end

-- สร้างโครงสร้างโฟลเดอร์
function SaveManager:BuildFolderTree()
    local paths = {
        self.Folder,
        self.Folder .. "/settings"
    }
    for i = 1, #paths do
        local str = paths[i]
        if not isfolder(str) then
            makefolder(str)
        end
    end
end

-- เส้นทางไฟล์ Config
function SaveManager:GetConfigPath(name)
    return self.Folder .. "/settings/" .. name .. ".json"
end

-- ตรวจสอบชื่อ Config
function SaveManager:IsValidName(name)
    if not name or name:gsub(" ", "") == "" then
        return false, "ชื่อ config ไม่ถูกต้อง (ห้ามเว้นว่าง)"
    end
    if name:match("[^%w_%-%s]") then
        return false, "ชื่อ config ต้องเป็นตัวอักษร, ตัวเลข, _ หรือ - เท่านั้น"
    end
    return true
end

-- ตั้งค่ารายการที่จะไม่บันทึก
function SaveManager:SetIgnoreIndexes(list)
    for _, key in next, list do
        self.Ignore[key] = true
    end
end

-- ไม่บันทึกการตั้งค่า Theme
function SaveManager:IgnoreThemeSettings()
    self:SetIgnoreIndexes({ 
        "InterfaceTheme", "AcrylicToggle", "TransparentToggle", "MenuKeybind"
    })
end

--========================================================
-- Save/Load Functions
--========================================================

-- บันทึก Config
function SaveManager:Save(name, silent)
    local valid, err = self:IsValidName(name)
    if not valid then
        if not silent then self:Notify("❌ Error", "บันทึกไม่สำเร็จ", err) end
        return false, err
    end
    
    local fullPath = self:GetConfigPath(name)
    local data = { 
        objects = {}, 
        info = {
            created = os.time(),
            version = "2.0.0",
            name = name,
            game = game.PlaceId,
        }
    }
    
    local count = 0
    for idx, option in next, self.Options do
        if not self.Parser[option.Type] then continue end
        if self.Ignore[idx] then continue end
        table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
        count = count + 1
    end
    
    local success, encoded = pcall(self.HttpService.JSONEncode, self.HttpService, data)
    if not success then
        if not silent then self:Notify("❌ Error", "บันทึกไม่สำเร็จ", "ไม่สามารถเข้ารหัสข้อมูลได้") end
        return false, "Failed to encode data"
    end
    
    writefile(fullPath, encoded)
    self.CurrentConfig = name
    
    if not silent then
        self:Notify("✅ Success", string.format("บันทึก Config: %s", name), 
                   string.format("บันทึกการตั้งค่า %d รายการ", count))
    end
    
    return true, "Config saved successfully"
end

-- โหลด Config
function SaveManager:Load(name, silent)
    if not name then
        if not silent then self:Notify("❌ Error", "โหลดไม่สำเร็จ", "ไม่ได้เลือก Config") end
        return false, "No config selected"
    end
    
    local file = self:GetConfigPath(name)
    if not isfile(file) then 
        if not silent then self:Notify("❌ Error", "โหลดไม่สำเร็จ", "ไม่พบไฟล์ Config") end
        return false, "Config file not found" 
    end
    
    local success, decoded = pcall(self.HttpService.JSONDecode, self.HttpService, readfile(file))
    if not success then 
        if not silent then self:Notify("❌ Error", "โหลดไม่สำเร็จ", "ไฟล์เสียหาย") end
        return false, "Failed to decode config" 
    end
    
    local count = 0
    for _, option in next, decoded.objects do
        if self.Parser[option.type] then
            task.spawn(function() 
                self.Parser[option.type].Load(option.idx, option) 
            end)
            count = count + 1
        end
    end
    
    self.CurrentConfig = name
    
    if not silent then
        self:Notify("✅ Success", string.format("โหลด Config: %s", name), 
                   string.format("โหลดการตั้งค่า %d รายการ", count))
    end
    
    return true, "Config loaded successfully"
end

-- ลบ Config
function SaveManager:Delete(name, silent)
    local file = self:GetConfigPath(name)
    if isfile(file) then
        delfile(file)
        if self.CurrentConfig == name then
            self.CurrentConfig = nil
        end
        if not silent then
            self:Notify("🗑️ Deleted", string.format("ลบ Config: %s", name), "")
        end
        return true, "Config deleted"
    end
    if not silent then
        self:Notify("❌ Error", "ลบไม่สำเร็จ", "ไม่พบไฟล์ Config")
    end
    return false, "Config not found"
end

-- รายชื่อ Config ทั้งหมด
function SaveManager:RefreshConfigList()
    if not isfolder(self.Folder .. "/settings") then
        self:BuildFolderTree()
        return {}
    end
    
    local list = listfiles(self.Folder .. "/settings")
    local out = {}
    
    for i = 1, #list do
        local file = list[i]
        if file:sub(-5) == ".json" then
            local pos = file:find(".json", 1, true)
            local start = pos
            local char = file:sub(pos, pos)
            while char ~= "/" and char ~= "\\" and char ~= "" do
                pos = pos - 1
                char = file:sub(pos, pos)
            end
            if char == "/" or char == "\\" then
                local name = file:sub(pos + 1, start - 1)
                if name ~= "options" then
                    table.insert(out, name)
                end
            end
        end
    end
    
    return out
end

--========================================================
-- Auto Load Functions
--========================================================

-- โหลด Auto Config
function SaveManager:LoadAutoloadConfig()
    local autoLoadFile = self.Folder .. "/settings/autoload.txt"
    if isfile(autoLoadFile) then
        local name = readfile(autoLoadFile)
        if name and name ~= "" then
            local success = self:Load(name, true)
            if success then
                self.AutoLoadEnabled = true
                self:Notify("🔄 Auto Load", string.format("โหลด Config: %s", name), "โหลดอัตโนมัติสำเร็จ")
            end
        end
    end
end

-- ตั้งค่า Auto Load
function SaveManager:SetAutoload(name, silent)
    if not name then
        if isfile(self.Folder .. "/settings/autoload.txt") then
            delfile(self.Folder .. "/settings/autoload.txt")
        end
        self.AutoLoadEnabled = false
        if not silent then
            self:Notify("🔓 Auto Load", "ปิดใช้งาน Auto Load", "")
        end
        return true
    end
    
    local file = self:GetConfigPath(name)
    if not isfile(file) then
        if not silent then
            self:Notify("❌ Error", "ไม่พบ Config", "กรุณาเลือก Config ที่มีอยู่")
        end
        return false
    end
    
    writefile(self.Folder .. "/settings/autoload.txt", name)
    self.AutoLoadEnabled = true
    if not silent then
        self:Notify("🔒 Auto Load", string.format("เปิดใช้งาน: %s", name), "จะโหลดอัตโนมัติเมื่อเปิดสคริปต์")
    end
    return true
end

-- ดูว่า Auto Load เปิดอยู่ไหม
function SaveManager:GetAutoloadConfig()
    local autoLoadFile = self.Folder .. "/settings/autoload.txt"
    if isfile(autoLoadFile) then
        return readfile(autoLoadFile)
    end
    return nil
end

--========================================================
-- UI Functions
--========================================================

-- แสดง Notification
function SaveManager:Notify(title, content, subContent, duration)
    duration = duration or 5
    if self.Library and self.Library.Notify then
        self.Library:Notify({
            Title = title,
            Content = content,
            SubContent = subContent or "",
            Duration = duration
        })
    else
        -- ถ้าไม่มี Library ให้พิมพ์ใน Console
        print(string.format("[%s] %s: %s", title, content, subContent or ""))
    end
end

-- สร้าง UI Section สำหรับจัดการ Config (ใช้กับ Fluent)
function SaveManager:BuildConfigSection(tab)
    assert(self.Library, "ต้องตั้งค่า Library ก่อน (SaveManager:SetLibrary())")
    
    -- Dropdown รายชื่อ Config
    local configList = self:RefreshConfigList()
    local configDropdown = tab:AddDropdown("SaveManager_ConfigList", { 
        Title = "📂 Select Config",
        Description = "เลือกไฟล์ Config ที่ต้องการ",
        Values = configList,
        AllowNull = true,
        Multi = false,
    })
    
    -- ช่องใส่ชื่อ Config
    local nameInput = tab:AddInput("SaveManager_ConfigName", { 
        Title = "✏️ Config Name",
        Description = "ตั้งชื่อ Config ใหม่",
        Default = "",
        Placeholder = "เช่น: แม็พโจรสลัด, บอทเลเวล 100",
        Finished = true
    })
    
    -- ปุ่มบันทึก
    tab:AddButton({
        Title = "💾 Save Config",
        Description = "บันทึกการตั้งค่าปัจจุบัน",
        Callback = function()
            local name = self.Options.SaveManager_ConfigName.Value
            if name == "" then
                self:Notify("⚠️ Warning", "กรุณาใส่ชื่อ Config", "ชื่อห้ามเว้นว่าง")
                return
            end
            self:Save(name)
            local newList = self:RefreshConfigList()
            configDropdown:SetValues(newList)
            configDropdown:SetValue(name)
        end
    })
    
    -- ปุ่มโหลด
    tab:AddButton({
        Title = "📂 Load Config",
        Description = "โหลดการตั้งค่าจากไฟล์",
        Callback = function()
            local name = self.Options.SaveManager_ConfigList.Value
            if not name then
                self:Notify("⚠️ Warning", "กรุณาเลือก Config", "เลือกจากรายการด้านบน")
                return
            end
            self:Load(name)
            nameInput:SetValue(name)
        end
    })
    
    -- ปุ่มบันทึกทับ
    tab:AddButton({
        Title = "🔄 Overwrite Config",
        Description = "บันทึกทับ Config ที่เลือก",
        Callback = function()
            local name = self.Options.SaveManager_ConfigList.Value
            if not name then
                self:Notify("⚠️ Warning", "กรุณาเลือก Config", "เลือกจากรายการด้านบน")
                return
            end
            self:Save(name)
        end
    })
    
    -- ปุ่มลบ
    tab:AddButton({
        Title = "🗑️ Delete Config",
        Description = "ลบไฟล์ Config ที่เลือก",
        Callback = function()
            local name = self.Options.SaveManager_ConfigList.Value
            if not name then
                self:Notify("⚠️ Warning", "กรุณาเลือก Config", "เลือกจากรายการด้านบน")
                return
            end
            self:Delete(name)
            local newList = self:RefreshConfigList()
            configDropdown:SetValues(newList)
            configDropdown:SetValue(nil)
        end
    })
    
    -- ปุ่มรีเฟรช
    tab:AddButton({
        Title = "🔄 Refresh List",
        Description = "อัปเดตรายการ Config",
        Callback = function()
            local newList = self:RefreshConfigList()
            configDropdown:SetValues(newList)
            configDropdown:SetValue(nil)
            self:Notify("🔄 Refreshed", "อัปเดตรายการ Config", string.format("พบ %d ไฟล์", #newList))
        end
    })
    
    -- Section Auto Load
    local autoSection = tab:AddSection("⚙️ Auto Load")
    
    -- Toggle Auto Load
    local currentAutoLoad = self:GetAutoloadConfig()
    autoSection:AddToggle("SaveManager_AutoLoad", {
        Title = "🔁 Enable Auto Load",
        Description = "เปิดออโต้โหลด",
        Default = currentAutoLoad ~= nil,
        Callback = function(value)
            if value then
                local name = self.Options.SaveManager_ConfigList.Value
                if not name then
                    self:Notify("⚠️ Warning", "กรุณาเลือก Config", "เลือก Config ที่ต้องการ Auto Load")
                    return
                end
                self:SetAutoload(name)
            else
                self:SetAutoload(nil)
            end
        end
    })
    
    -- ปุ่มแสดงข้อมูล Config ปัจจุบัน
    autoSection:AddButton({
        Title = "ℹ️ Config Info",
        Description = "แสดงข้อมูลของ Config ที่กำลังใช้งาน",
        Callback = function()
            if self.CurrentConfig then
                local file = self:GetConfigPath(self.CurrentConfig)
                if isfile(file) then
                    local success, data = pcall(function()
                        return self.HttpService:JSONDecode(readfile(file))
                    end)
                    if success and data and data.info then
                        local info = data.info
                        local timeStr = os.date("%d/%m/%Y %H:%M:%S", info.created)
                        self:Notify("ℹ️ Config Info", 
                                   string.format("ชื่อ: %s", self.CurrentConfig),
                                   string.format("สร้างเมื่อ: %s\nเวอร์ชัน: %s", timeStr, info.version or "1.0"), 5)
                    end
                end
            else
                self:Notify("ℹ️ Info", "ไม่ได้ใช้งาน Config", "ยังไม่ได้โหลด Config ใดๆ")
            end
        end
    })
    
    -- ไม่บันทึกการตั้งค่า UI ของตัวจัดการ Config
    self:SetIgnoreIndexes({ 
        "SaveManager_ConfigList", 
        "SaveManager_ConfigName",
        "SaveManager_AutoLoad"
    })
end

--========================================================
-- Export
--========================================================

return SaveManager

