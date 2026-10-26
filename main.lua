--[[
    ========================================================================
    King Legacy - Dedicated Auto Fishing & Friend Coordinator
    [Scoot UI Edition - Modern, Organized & Full Robust 24/7]
    UI Library: https://raw.githubusercontent.com/x2Swiftz/UI-Library/refs/heads/main/Libraries/Scoot%20UI%20-%20Example.lua
    ========================================================================
]]

-- กู้คืนอัตโนมัติเมื่อขึ้นหน้าต่าง error ของ Roblox (529 Http error / 279 Connection Failed / 277 ฯลฯ)
-- ต้องอยู่บนสุด ก่อนรอเกมโหลด: ต่อเซิร์ฟใหม่ไม่ติด = เกมไม่มีวันโหลดเสร็จ โค้ดด้านล่างจะค้างรออยู่ตลอด
-- ลองไปเซิร์ฟที่กำลังตีบอส / กำลังวาร์ปไป (KL_REJOIN_JOBID) ก่อน 2 ครั้ง แล้วค่อยสุ่มเซิร์ฟใหม่ ทุก 10 วิ สูงสุด 5 นาที
do
    local env = getgenv and getgenv() or _G
    if not env.KL_AUTO_REJOIN then
        env.KL_AUTO_REJOIN = true
        local TeleportService = game:GetService("TeleportService")
        local GuiService = game:GetService("GuiService")
        local SEA3_PLACE_ID = 15759515082
        local rejoining = false
        -- ข้อความที่ไม่ใช่หน้าต่าง error ค้าง -> ไม่ต้องกู้
        --   disconnectclientinitiated / 285: Roblox ตั้งเองทุกครั้งที่ย้ายเซิร์ฟปกติ
        --     (จาก log 8 ชม. ถึง 03:45 วันที่ 25: เด้ง 1,646 ครั้ง แล้วสั่งวาร์ปซ้ำทับการย้ายเซิร์ฟที่กำลังทำ -> IsTeleporting 1,467 ครั้ง)
        --   teleport failed: วาร์ปไม่สำเร็จแต่ยังอยู่เซิร์ฟเดิม (main.lua ลองใหม่เองใน TeleportInitFailed / ลองเซิร์ฟในคิวต่อ)
        --   same account: ไอดีเดียวกันเข้าจากที่อื่น เข้าใหม่จะเตะกันไปมา
        local IGNORED_ERRORS = { "disconnectclientinitiated", "error code: 285", "teleport failed", "same account" }

        -- กล่อง ErrorPrompt ของ Roblox ที่โชว์อยู่บนจอ (หรือ nil)
        local function getErrorPrompt()
            local ok, prompt = pcall(function()
                local promptGui = game:GetService("CoreGui"):FindFirstChild("RobloxPromptGui")
                local overlay = promptGui and promptGui:FindFirstChild("promptOverlay")
                local found = overlay and overlay:FindFirstChild("ErrorPrompt")
                if found and found.Visible ~= false then return found end
                return nil
            end)
            return ok and prompt or nil
        end

        local function rejoin(message)
            local text = tostring(message or "")
            if rejoining or text == "" then return end
            local lowerText = string.lower(text)
            for _, ignored in ipairs(IGNORED_ERRORS) do
                if string.find(lowerText, ignored, 1, true) then return end
            end
            rejoining = true
            env.KL_REJOINING = true -- ตัวกันย้ายเซิร์ฟของ main.lua ต้องปล่อยการเข้าเกมใหม่นี้ผ่าน
            task.spawn(function()
                warn("[KL-Fisher] 🔄 ขึ้นหน้าต่าง error: " .. text .. " -> เข้าเกมใหม่อัตโนมัติ")
                local placeId = (game.PlaceId ~= 0) and game.PlaceId or SEA3_PLACE_ID
                for attempt = 1, 30 do
                    task.wait(attempt == 1 and 3 or 10)
                    -- error หายไปเองแล้ว (ไม่มีข้อความ error และไม่มีกล่อง ErrorPrompt บนจอ) -> เลิกกู้ ไม่สั่งวาร์ปทับ
                    local okMsg, currentError = pcall(function() return GuiService:GetErrorMessage() end)
                    if okMsg and currentError == "" and not getErrorPrompt() then
                        warn("[KL-Fisher] ✅ หน้าต่าง error หายไปเองแล้ว -> ยกเลิกการเข้าเกมใหม่")
                        rejoining = false
                        env.KL_REJOINING = false
                        return
                    end
                    local player = game:GetService("Players").LocalPlayer
                    local targetJobId = env.KL_REJOIN_JOBID
                    pcall(function()
                        if attempt <= 2 and type(targetJobId) == "string" and targetJobId ~= "" then
                            TeleportService:TeleportToPlaceInstance(placeId, targetJobId, player)
                        else
                            TeleportService:Teleport(placeId, player)
                        end
                    end)
                end
            end)
        end

        pcall(function() GuiService.ErrorMessageChanged:Connect(rejoin) end)
        -- บางครั้งหน้าต่างขึ้นโดยไม่มี ErrorMessageChanged -> เช็คกล่อง ErrorPrompt ของ Roblox เองทุก 2 วิด้วย
        -- (วนตลอด ไม่หยุดหลังกู้ครั้งแรก: error หายเองแล้วยกเลิกการกู้ได้ ต้องจับครั้งถัดไปได้อีก)
        task.spawn(function()
            while true do
                task.wait(2)
                pcall(function()
                    if rejoining then return end
                    local prompt = getErrorPrompt()
                    if not prompt then return end
                    -- ใช้ข้อความบนกล่องก่อน: GetErrorMessage อาจยังค้าง "DisconnectClientInitiated" จากการย้ายเซิร์ฟครั้งก่อน
                    local message = ""
                    for _, label in ipairs(prompt:GetDescendants()) do
                        if label:IsA("TextLabel") and #label.Text > #message then
                            message = label.Text
                        end
                    end
                    if message == "" then
                        message = GuiService:GetErrorMessage()
                    end
                    rejoin(message ~= "" and message or "ErrorPrompt")
                end)
            end
        end)
    end
end

-- รันจาก autoexec ได้: รอเกมโหลดเสร็จก่อน และรันเฉพาะใน King Legacy (มี ReplicatedStorage.Chest.Remotes)
if not game:IsLoaded() then
    game.Loaded:Wait()
end
do
    local chest = game:GetService("ReplicatedStorage"):WaitForChild("Chest", 20)
    if not chest or not chest:WaitForChild("Remotes", 10) then
        return
    end
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- ตรวจสอบ LocalPlayer ให้พร้อมใช้งาน 100%
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    repeat
        task.wait(0.1)
        LocalPlayer = Players.LocalPlayer
    until LocalPlayer
end

-- กันรันซ้อน 2 ตัว (autoexec + กด Execute เอง) ไม่งั้นบอทสองตัวแย่งกันคุมตัวละคร
-- อยากรันเวอร์ชันใหม่: rejoin เกม (รอ Maru Hub โหลด) แล้วกด Execute main.lua ใหม่
-- (เช็คทั้ง getgenv และ attribute บนตัวผู้เล่น เพราะจาก log เคยรันซ้อน 2 ตัว: บาง executor แยก getgenv ต่อสคริปต์)
local scriptEnv = getgenv and getgenv() or _G
if scriptEnv.KL_FISHER_RUNNING or LocalPlayer:GetAttribute("KLFisherRunning") then
    warn("[KL-Fisher] ⏭️ main.lua รันอยู่แล้วในเซิร์ฟนี้ ข้ามการรันซ้ำ")
    return
end
scriptEnv.KL_FISHER_RUNNING = true
scriptEnv.KL_REJOIN_JOBID = nil -- เซิร์ฟใหม่: ยังไม่มีไฟต์ / ยังไม่ได้วาร์ปไปไหน
pcall(function() LocalPlayer:SetAttribute("KLFisherRunning", true) end)

-- กดเข้าเกมจากหน้าแรกให้เอง (ที่เกมส่งตอนกด Play / ดักด้วย Cobalt)
-- แยก thread + pcall: InvokeServer อาจค้างรอเซิร์ฟ ไม่ให้บล็อกส่วนอื่นของสคริปต์
task.spawn(function()
    local ok, err = pcall(function()
        ReplicatedStorage.Chest.Remotes.Functions:WaitForChild("EtcFunction", 20):InvokeServer("EnterTheGame", {})
    end)
    if not ok then
        warn("[KL-Fisher] EnterTheGame ไม่สำเร็จ: " .. tostring(err))
    end
end)

-- ย้ายเซิร์ฟ (Maru Hop / วาร์ปตามเพื่อน) แล้วให้ main.lua รันต่อเองในเซิร์ฟใหม่
-- (ไม่ใช่ autoexec: เข้าเกมครั้งแรกยังต้องกด Execute เอง / จาก log 15:16-15:23 ย้ายเซิร์ฟแล้วสคริปต์หยุด 7 นาที)
-- โค้ดที่ฝากไว้อ่าน main.lua จาก workspace ของ Volt ใหม่ทุกครั้ง และ main.lua ยังรอ Maru โหลด 40 วิเหมือนเดิม
-- ไม่มี main.lua ใน workspace (คนที่รันผ่าน loadstring จาก GitHub) -> โหลดจาก SCRIPT_URL แทน
-- พร้อมพก getgenv().KL_CONFIG ไปด้วย (getgenv ล้างทุกครั้งที่ย้ายเซิร์ฟ)
local AUTO_RERUN_ON_TELEPORT = true
do
    local SCRIPT_URL = "https://raw.githubusercontent.com/LilSky1/king-legacy/main/main.lua"
    local queueTeleport = queue_on_teleport or queueonteleport
        or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if AUTO_RERUN_ON_TELEPORT and queueTeleport then
        local configLine = ""
        if type(scriptEnv.KL_CONFIG) == "table" then
            local encoded = nil
            pcall(function() encoded = HttpService:JSONEncode(scriptEnv.KL_CONFIG) end)
            if encoded and not string.find(encoded, "]==]", 1, true) then
                configLine = "(getgenv and getgenv() or _G).KL_CONFIG = game:GetService(\"HttpService\"):JSONDecode([==["
                    .. encoded .. "]==])\n"
            end
        end
        pcall(queueTeleport, configLine .. [[
            if isfile and readfile and isfile("main.lua") then
                local chunk = loadstring(readfile("main.lua"), "=main.lua")
                if chunk then chunk() end
            elseif ]] .. string.format("%q", SCRIPT_URL) .. [[ ~= "" then
                loadstring(game:HttpGet(]] .. string.format("%q", SCRIPT_URL) .. [[))()
            end
        ]])
    elseif AUTO_RERUN_ON_TELEPORT then
        warn("[KL-Fisher] ⚠️ executor ไม่มี queue_on_teleport -> ย้ายเซิร์ฟแล้วต้องกด Execute main.lua ใหม่เอง")
    end
end

-- Maru Hub (Luraph) เช็คตอนโหลดว่ามีสคริปต์อื่น hook เกมไหม ถ้าเจอจะไม่ยอมทำงาน (UI ไม่ขึ้น)
-- -> ตอนเพิ่งเข้าเกม (autoexec) ให้รอ Maru โหลดผ่านไปก่อน ค่อยเริ่ม fish.lua
-- (hook ทุกตัวของ fish.lua ติดตั้งตอนใช้งานจริงเท่านั้น ไม่ได้ติดตั้งตอนเริ่ม)
local MARU_STARTUP_GRACE = 5 -- วินาทีนับจากเข้าเกม (hook ของเราติดตั้งตอนใช้งานจริงอยู่แล้ว รอสั้น ๆ พอ)
if time() < MARU_STARTUP_GRACE then
    print(string.format("[KL-Fisher] ⏳ เพิ่งเข้าเกม -> รอ Maru Hub โหลดก่อน %d วินาที แล้วค่อยเริ่ม", math.ceil(MARU_STARTUP_GRACE - time())))
    repeat task.wait(1) until time() >= MARU_STARTUP_GRACE
end

----------------------------------------------------------------------
-- 1. CONFIGURATION (ควบคุมผ่าน Scoot UI แบบ Real-time)
----------------------------------------------------------------------
local CONFIG = {
    -- Firebase สำหรับประสานงาน
    FIREBASE_URL = "https://skyring-kingl-default-rtdb.asia-southeast1.firebasedatabase.app/signal.json",
    -- รหัสลับกลุ่ม: ตั้งให้ตรงกันทุกเครื่อง สัญญาณที่รหัสไม่ตรงจะถูกเมิน (เว้นว่าง = ไม่ตรวจ)
    SIGNAL_KEY = "",

    -- แจ้ง Discord เมื่อเจอบอส (ชื่อบอส + JobId + คำสั่งวาร์ป) ส่งครั้งเดียวต่อบอสต่อเซิร์ฟ
    DISCORD_NOTIFY_BOSS = true,
    -- แจ้งเมื่อเจอน้ำวน (SerpentWhirlpool) ส่งไปอีกช่อง ครั้งเดียวต่อเซิร์ฟ
    DISCORD_NOTIFY_WHIRLPOOL = true,
    -- log การเรียกเพื่อน: ใครเจอ / ใครยอมไปรวม / ใครวาร์ปไปหาใคร / วาร์ปไม่สำเร็จ / มาถึงแล้ว / บอสจบ
    DISCORD_COORD_LOG = true,
    DISCORD_COORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1563478696218853442/J06ToTVXQ0u7Bq_yDJxl1Dz6d6XWJqphcGmCC3VFgWLcf9Rm33LHW_XAAyYOgrjzBqlK",
    DISCORD_WHIRLPOOL_WEBHOOK_URL = "https://discord.com/api/webhooks/1563472257148264609/tkf4b-xdXtn6-3Foz5Q2tnWXq7uJoTS5TLAcvRzNHEc-TB90rDDxAxxQpJWaL3ElqG7J",
    DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1563468768393560104/ErLyvPLNI1d09z7sEbK3N5WnMiDz1C2bJ_FEKB0tUMziJXBi2P4px7h2A2Qu8SuecvN2",

    -- แจ้งเตือนเมื่อไอดีนี้ได้ของดรอปในรายการ (Serpent: Fin 7% / Heart 2% / Acromask 0.5% / Acrodagger 0.35% ใน Sea 3)
    -- จับจากข้อความใหม่บนจอ (popup / แจ้งเตือนของเกม) และแชทระบบ/แชทที่มีชื่อไอดีนี้ (ตัวรองไม่ตี เลยไม่เปิด)
    DROP_ALERT = true,
    DROP_ALERT_WEBHOOK_URL = "https://discord.com/api/webhooks/1563913033183531170/VuNSMRTJbdXO5khMUAyGg2j4y1CLkgS0QZF0ksYSBGViTeEesZsl9QQWEsRC7K2fNgdp",
    DROP_ALERT_ITEMS = { "Acromask", "Acrodagger", "Serpent Heart", "Serpent Fin" },

    -- ใช้คู่กับ Maru Hub:
    --   fish.lua: ตกปลา + มินิเกม (Maru ไม่มี) / บอสเกิด -> เรียกเพื่อน + หยิบดาบขึ้นมาถือ (พร้อมตี)
    --   Maru Hub: ตีบอส / Hop / Anti-AFK
    RESTORE_ROD_AFTER_BOSS = true, -- บอสหายแล้วหยิบเบ็ดกลับจากกระเป๋าเกม แล้วตกปลาต่อ

    -- โหมดตกปลา
    AUTO_FISHING = true,
    AUTO_SOLVE_MINIGAME = true,
    -- bypass มินิเกม: ตั้งค่า progress ของเกมให้เต็มเลย (ชนะทันที) แทนการบังคับแถบเอง
    -- ต้องใช้ getgc + debug.setupvalue ถ้า executor ไม่มีจะกลับไปใช้วิธีบังคับแถบแบบเดิม
    MINIGAME_INSTANT_WIN = true,
    MINIGAME_WIN_DELAY = 1, -- รอกี่วินาทีก่อนชนะ (เร็วเกินไปอาจดูผิดปกติ ตั้ง 0 = ชนะทันที)
    AUTO_CLOSE_POPUP = true,
    AUTO_CAST_ROD = true,
    CAST_CHARGE_MIN = 95,  -- แรงเหวี่ยงเบ็ด (Charge) สุ่มในช่วงนี้ทุกครั้ง (เกมรับ 0-100)
    CAST_CHARGE_MAX = 100,
    CAST_COOLDOWN = 1.5,
    MINIGAME_TIMEOUT = 12,
    BITE_TIMEOUT = 30, -- รอปลากินเบ็ดนานสุดกี่วินาทีก่อนเหวี่ยงใหม่

    -- น้ำวน & ทะเล
    AUTO_WHIRLPOOL = true,
    ANTI_DROWN_PLATFORM = true,
    PLATFORM_HEIGHT = 12,
    
    -- การต่อสู้ & บอส
    -- ปิดไว้เพราะใช้คู่กับ Maru Hub (AutoSerpent/AutoThirdSeaDragon ตีบอสเอง)
    -- ตอนปิด: เจอบอสแล้ว fish.lua จะถือดาบหลักรอ (พร้อมตี) แล้วเรียกเพื่อน ส่วนการตีให้ Maru ทำ
    AUTO_ATTACK_BOSS = false,
    PREFERRED_SWORD = "Authentic Mace",
    CYCLE_WEAPONS = true,
    WEAPON_CYCLE_DELAY = 1.5,
    AUTO_SPAM_SKILLS = true,
    AUTO_BUSO_HAKI = true,
    AIM_LOCK = true,
    NOCLIP_COMBAT = true,
    ATTACK_DISTANCE = 18,
    ATTACK_DELAY = 0.1,
    
    -- บอสเป้าหมาย
    -- ใช้ชื่อโมเดลในเกม (จาก RaidBossList ของเกม) ไม่ใช่ชื่อที่โชว์บนจอ / เทียบแบบ "มีคำนี้อยู่ในชื่อ"
    -- ตัวรองใส่คิว / ตัวหลักอยู่ตี + หยิบดาบ / กันย้ายเซิร์ฟ เฉพาะบอสในรายการนี้
    -- ลำดับในคิว: Serpent ก่อน แล้วมังกร แล้วน้ำวน (ดู queueEntryRank ใน fetchQueue)
    -- (Maru บนตัวหลักต้องเปิดตีมังกรด้วย ไม่งั้นตัวหลักไปถึงแล้วยืนเฉย ๆ)
    TARGET_BOSSES = {
        "Serpent",                      -- Serpent: บอสทะเล เลือด 10M ดรอป Acromask (เกิดจากตกปลา WhirlpoolBeast ในน้ำวน)
        "ThirdSeaDragon",               -- Drakenfyr the Inferno King (เกิดตามตัวนับเวลาที่ถ้วย)
        "SeaDragon",                    -- Abyssal Tyrant (เกิดตามตัวนับเวลาที่ถ้วย / probe 19:35 วันที่ 24)
    },
    
    -- ประสานงานเรียกเพื่อน & ตามเพื่อน
    BROADCAST_BOSS = true,
    BROADCAST_WHIRLPOOL = true, -- เจอน้ำวนก็เรียกเพื่อน (ทุกไอดีมารวมเซิร์ฟเดียวตั้งแต่ยังไม่เกิดบอส)
    SIGNAL_HEARTBEAT = true,
    BLOCK_HOP_SCRIPTS = false, -- ปิดไว้ ให้ Maru Hub (SerpentHop) ย้ายเซิร์ฟได้ตามปกติ
    -- แต่ห้าม Maru ย้ายออก ตอนเซิร์ฟเรามีน้ำวน / บอส / บอสกำลังจะเกิด (ไม่งั้นเพื่อนวาร์ปมารวมแล้วโดนพาออกก่อนบอสเกิด)
    HOLD_SERVER_AT_WHIRLPOOL_BOSS = true,
    -- บอสพวกนี้ในเซิร์ฟเราหายไป/ตีจบแล้ว -> ย้ายไปเซิร์ฟใหม่ทันที (ใช้ชื่อโมเดลในเกม)
    -- (ไม่รอ Maru: เน็ตเครื่องนี้ต่อ games.roblox.com ไม่ได้ Maru โหลดรายชื่อเซิร์ฟไม่ขึ้นเลยไม่ย้ายให้)
    HOP_AFTER_BOSSES = { "Serpent", "ThirdSeaDragon", "SeaDragon" },
    HOP_AFTER_BOSS_DELAY = 2, -- วินาที
    -- เลือกเซิร์ฟจากรายชื่อของ games.roblox.com ก่อน (ปิดไว้: เน็ตนี้ต่อไม่ได้ ค้างรอ 21 วิเปล่า ๆ)
    -- ปิด = ใช้ TeleportService:Teleport ให้ Roblox เลือกเซิร์ฟให้เอง ไม่ต้องผ่าน games.roblox.com
    HOP_USE_SERVER_LIST = false,
    -- ย้ายไม่สำเร็จ -> สุ่มเซิร์ฟใหม่ลองต่อ สูงสุดกี่ครั้ง (เซิร์ฟเต็ม/เน็ตสะดุดลองใหม่ใน 3 วิ / เงียบไม่มีผลรอ 15 วิ)
    HOP_MAX_ATTEMPTS = 10,
    AUTO_FOLLOW_FRIENDS = true,
    SIGNAL_TIMEOUT = 120, -- เน็ตช้า อ่าน/เขียนครั้งละ 11-21 วิ ต้องเผื่อเวลา (heartbeat ต่ออายุทุก 5 วิ)
    CHECK_INTERVAL = 3,
    
    -- ระบบคิว: ตัวรองย้ายเซิร์ฟหา Serpent / น้ำวน แล้วใส่ JobId ลงคิว -> ตัวหลักตีจบแล้วดึงเซิร์ฟถัดไปจากคิวทีละอัน
    -- (ไฟล์เดียวกันทุกไอดี: ชื่อตรงกับ MAIN_ACCOUNTS = ตัวหลัก / ไอดีอื่นทั้งหมด = ตัวรอง)
    -- เปิดโหมดนี้แล้วระบบเรียกเพื่อนแบบเดิม (ช่อง signal เดียว + วาร์ปตามกัน) จะปิดเอง
    QUEUE_MODE = true,
    MAIN_ACCOUNTS = { "Kikiesir6", "NOWAYOUT888" },
    -- false (ใช้อยู่): ตัวหลักแต่ละตัวอยู่เซิร์ฟตัวเอง ดึงคิวเอง ว่าง ๆ ไม่ตามกัน / มีของเมื่อไหร่ไปทำด้วยกัน:
    --   ตัวหลักเจอบอส / น้ำวนในเซิร์ฟตัวเอง -> ใส่คิวเหมือนตัวรอง (ติดป้าย byMain = งานของปาร์ตี้)
    --   งานของปาร์ตี้ + บอสทุกตัวในคิว -> ตัวหลักทุกตัวไป (ไม่สนการจอง) / น้ำวนที่ตัวรองเจอ -> แยกกันคนละเซิร์ฟ
    --   ลำดับ: Serpent > มังกร > น้ำวน / ประเภทเดียวกัน ของตัวหลักก่อน เรียงตามใครเจอก่อน
    --   เช่น Kikiesir6 เจอบอสก่อน NOWAYOUT888 เจอน้ำวนทีหลัง -> NOWAYOUT888 ใส่น้ำวนลงคิวไว้ ไปช่วย Kikiesir6 ตีก่อน
    --        ตีจบ -> ทั้งคู่ดึงคิวอันถัดไป = น้ำวนของ NOWAYOUT888 -> กลับไปตกเรียก Serpent แล้วตีด้วยกัน
    -- true (แบบเดิม): ไปเซิร์ฟเดียวกันเสมอ ตัวแรกในรายการ = หัวหน้า ดึงคิว แล้วเขียน "เซิร์ฟของปาร์ตี้" ลง Firebase
    --   ตัวอื่น = ตามหัวหน้า (ไม่ดึงคิวเอง) / หัวหน้าเงียบเกิน PARTY_TTL (ออฟไลน์) -> ตัวอื่นดึงคิวเองแทน
    PARTY_ALWAYS_TOGETHER = false,
    QUEUE_MAIN_FIND_REFRESH = 60,   -- ตัวหลักเจอของ: ใส่คิวซ้ำ (ต่ออายุ + อัปเดต HP) ทุกกี่วินาทีระหว่างของยังอยู่
    QUEUE_MAIN_WHIRLPOOL_TTL = 600, -- น้ำวนที่ตัวหลักเจอ อยู่ในคิวได้นานกว่า (ทิ้งไว้ไปช่วยตีที่อื่น ตีจบแล้วจะได้กลับมา)
    QUEUE_CLAIM_SECONDS = 120, -- เซิร์ฟที่ตัวหลักอีกตัวจองไว้ ข้ามกี่วินาที (ใช้ตอนหัวหน้าออฟไลน์แล้วตัวอื่นดึงคิวเอง)
    PARTY_TTL = 300,           -- เซิร์ฟของปาร์ตี้ใช้ได้กี่วินาทีนับจากหัวหน้าเขียนล่าสุด
    PARTY_HEARTBEAT = 120,     -- หัวหน้าเขียนเซิร์ฟที่อยู่ซ้ำทุกกี่วินาที (ต่ออายุ ให้รู้ว่ายังออนไลน์)
    -- ตัวตามตีจบแล้ว รอหัวหน้าบอกเซิร์ฟถัดไปนานสุดกี่วินาที (ไม่มา -> ดึงคิวเอง)
    -- (หัวหน้าสุ่มย้าย ~20-40 วิ + เขียน Firebase ~20 วิ + ตัวตามอ่าน ~20 วิ บนเน็ตนี้)
    PARTY_WAIT_AFTER_BOSS = 120,
    QUEUE_BOSS_TTL = 180,      -- บอส (Serpent / มังกร) ในคิวใช้ได้กี่วินาทีนับจากตัวรองเจอ
    QUEUE_WHIRLPOOL_TTL = 240, -- น้ำวนในคิวใช้ได้กี่วินาที
    QUEUE_POLL_INTERVAL = 5,   -- ตัวหลักว่างอยู่ -> เช็คคิวทุกกี่วินาที (เน็ตช้า อ่านครั้งละ 11-21 วิ อยู่แล้ว)
    QUEUE_LEAVE_WHIRLPOOL_FOR_BOSS = true, -- ตัวหลักยืนตกที่น้ำวนอยู่ แต่ในคิวมีบอสเกิดแล้ว (Serpent / มังกร) -> ไปตีบอสก่อน
    QUEUE_MAX_TRIES = 5,       -- ดึงจากคิวรอบหนึ่ง ลองวาร์ปได้กี่เซิร์ฟ (เต็ม/เข้าไม่ได้ -> อันถัดไปทันที)
    QUEUE_TELEPORT_WAIT = 45,  -- รอผลวาร์ปไปเซิร์ฟในคิวนานสุดกี่วินาที (เน็ตนี้วาร์ปจริงใช้ ~40 วิ)
    SCOUT_SCAN_SECONDS = 6,    -- ตัวรองเข้าเซิร์ฟแล้วดูหา Serpent กี่วินาที
    SCOUT_MIN_STAY = 12,       -- ตัวรองอยู่แต่ละเซิร์ฟอย่างน้อยกี่วินาที (ย้ายถี่เกิน Roblox ขึ้น Flooded)
    SCOUT_SEEN_SECONDS = 300,  -- ตัวรองจำเซิร์ฟที่เพิ่งสำรวจกี่วินาที (Roblox สุ่มกลับมาเซิร์ฟเดิมบ่อย)
    SCOUT_REPEAT_STAY = 3,     -- กลับมาเซิร์ฟที่จำไว้: อยู่แค่กี่วินาทีแล้วย้ายต่อ
    SCOUT_REFRESH_SECONDS = 120, -- เซิร์ฟเดิมยังมีของเดิม: ใส่คิวซ้ำ (ต่ออายุ) ได้เมื่อใส่ไปนานเกินนี้ (ไม่แจ้ง Discord ซ้ำ)

    -- ป้องกัน
    ANTI_AFK = false, -- Maru Hub มี Anti AFK อยู่แล้ว
    DEATH_RECOVERY = true
}

-- ตั้งค่าเองได้โดยไม่ต้องแก้ไฟล์ (คนที่รันผ่าน loadstring จาก GitHub): ใส่ก่อนบรรทัด loadstring
--   getgenv().KL_CONFIG = { DISCORD_WEBHOOK_URL = "...", FIREBASE_URL = "...", MAIN_ACCOUNTS = { "ชื่อไอดี" } }
do
    local userConfig = scriptEnv.KL_CONFIG
    if type(userConfig) == "table" then
        for key, value in pairs(userConfig) do
            CONFIG[key] = value
        end
    end
end
-- ไม่มี Firebase -> ปิดระบบคิว / เรียกเพื่อน (ไม่งั้นทุกไอดีกลายเป็นตัวรอง ไม่ตกปลา ย้ายเซิร์ฟตลอด)
if tostring(CONFIG.FIREBASE_URL or "") == "" then
    CONFIG.FIREBASE_URL = ""
    CONFIG.QUEUE_MODE = false
    CONFIG.BROADCAST_BOSS = false
    CONFIG.BROADCAST_WHIRLPOOL = false
    CONFIG.AUTO_FOLLOW_FRIENDS = false
    CONFIG.SIGNAL_HEARTBEAT = false
end

-- บทบาทในโหมดคิว: ตัวหลักตีอย่างเดียว / ตัวรองไม่ตกปลา ไม่ตี ย้ายเซิร์ฟหา JobId อย่างเดียว
-- MAIN_INDEX = ลำดับของไอดีนี้ใน MAIN_ACCOUNTS (nil = ไม่ใช่ตัวหลัก) ใช้แบ่งเซิร์ฟในคิวไม่ให้ตัวหลักแย่งอันเดียวกัน
local MAIN_INDEX = nil
for index, name in ipairs(CONFIG.MAIN_ACCOUNTS or {}) do
    local lowerName = string.lower(tostring(name))
    if lowerName == string.lower(LocalPlayer.Name) or lowerName == string.lower(LocalPlayer.DisplayName) then
        MAIN_INDEX = index
        break
    end
end
local IS_SCOUT = CONFIG.QUEUE_MODE and not MAIN_INDEX
if CONFIG.QUEUE_MODE then
    CONFIG.BROADCAST_BOSS = false
    CONFIG.BROADCAST_WHIRLPOOL = false
    CONFIG.AUTO_FOLLOW_FRIENDS = false
    if IS_SCOUT then
        CONFIG.AUTO_FISHING = false
    end
    print(string.format("[KL-Fisher] 🧭 โหมดคิว: ไอดีนี้เป็น%s", IS_SCOUT
        and "ตัวรอง (ย้ายเซิร์ฟหาบอส/น้ำวน แล้วใส่ JobId ลงคิว)"
        or string.format("ตัวหลักลำดับที่ %d (ตีอย่างเดียว ตีจบแล้วดึงเซิร์ฟถัดไปจากคิว)", MAIN_INDEX or 0)))
end

----------------------------------------------------------------------
-- 2. ANTI-AFK (ป้องกันตัดการเชื่อมต่อ 20 นาที 24 ชม.)
----------------------------------------------------------------------
pcall(function()
    LocalPlayer.Idled:Connect(function()
        if not CONFIG.ANTI_AFK then return end
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
        pcall(function()
            local cam = workspace.CurrentCamera
            local cf = cam and cam.CFrame or CFrame.new()
            VirtualUser:Button2Down(Vector2.zero, cf)
            task.wait(0.2)
            VirtualUser:Button2Up(Vector2.zero, cf)
        end)
        print("[KL-Fisher] 🛡️ Anti-AFK: ป้องกันตัดการเชื่อมต่อสำเร็จ")
    end)
end)

task.spawn(function()
    while true do
        task.wait(300)
        if CONFIG.ANTI_AFK then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.zero)
            end)
        end
    end
end)

----------------------------------------------------------------------
-- 3. HTTP HELPER (รองรับ Executor ทุกค่าย)
----------------------------------------------------------------------
local httpRequest = (syn and syn.request) 
    or (http and http.request) 
    or http_request 
    or request 
    or (fluxus and fluxus.request)

local function httpGet(url)
    if not httpRequest or not url or url == "" or string.find(url, "YOUR-PROJECT-ID") then return nil end
    local ok, response = pcall(function()
        return httpRequest({
            Url = url,
            Method = "GET",
            Headers = { ["Content-Type"] = "application/json" }
        })
    end)
    if ok and response and response.StatusCode == 200 and response.Body then
        local decodeOk, data = pcall(function()
            return HttpService:JSONDecode(response.Body)
        end)
        if decodeOk then
            return data
        end
    end
    return nil
end

local function httpPut(url, data)
    if not httpRequest or not url or url == "" or string.find(url, "YOUR-PROJECT-ID") then return false end
    local ok, response = pcall(function()
        return httpRequest({
            Url = url,
            Method = "PUT",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end)
    local success = ok and response and (response.StatusCode == 200 or response.StatusCode == 204)
    if not success then return false end
    -- Firebase ส่งค่าที่เขียนลงไปกลับมา (ใช้อ่านเวลาเซิร์ฟเวอร์ได้)
    if response.Body and response.Body ~= "" then
        local decodeOk, decoded = pcall(function()
            return HttpService:JSONDecode(response.Body)
        end)
        if decodeOk then
            return true, decoded
        end
    end
    return true
end

local function httpDelete(url)
    if not httpRequest or not url or url == "" then return false end
    local ok, response = pcall(function()
        return httpRequest({ Url = url, Method = "DELETE" })
    end)
    return ok and response and (response.StatusCode == 200 or response.StatusCode == 204) or false
end

-- เขียนทับเฉพาะฟิลด์ที่ส่งไป (ฟิลด์อื่นใน path เดิมยังอยู่)
local function httpPatch(url, data)
    if not httpRequest or not url or url == "" then return false end
    local ok, response = pcall(function()
        return httpRequest({
            Url = url,
            Method = "PATCH",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end)
    return ok and response and (response.StatusCode == 200 or response.StatusCode == 204) or false
end

----------------------------------------------------------------------
-- 4. SAFETY PLATFORM (แท่นลอยน้ำนิรภัยกันผลปีศาจจมน้ำ 100%)
----------------------------------------------------------------------
local safetyPlatform = nil

local function ensureSafetyPlatform(position)
    if not CONFIG.ANTI_DROWN_PLATFORM then return nil end
    pcall(function()
        if not safetyPlatform or not safetyPlatform.Parent then
            safetyPlatform = Instance.new("Part")
            safetyPlatform.Name = "KL_FisherSafetyPlatform"
            safetyPlatform.Size = Vector3.new(14, 1, 14)
            safetyPlatform.Anchored = true
            safetyPlatform.CanCollide = true
            safetyPlatform.Transparency = 1 -- ซ่อนไว้ มองไม่เห็นแต่ยืนได้จริง
            safetyPlatform.Parent = workspace
        end
        safetyPlatform.CFrame = CFrame.new(position - Vector3.new(0, 3.2, 0))
    end)
    return safetyPlatform
end

local function removeSafetyPlatform()
    if safetyPlatform then
        pcall(function()
            if safetyPlatform.Parent then
                safetyPlatform:Destroy()
            end
        end)
        safetyPlatform = nil
    end
end

----------------------------------------------------------------------
-- 5. WHIRLPOOL DETECTOR (ตรวจหาน้ำวนในเซิร์ฟเวอร์)
----------------------------------------------------------------------
local function getWhirlpoolTarget()
    local ok, resPos, resName = pcall(function()
        local effects = workspace:FindFirstChild("Effects")
        local serpentWhirlpool = effects and effects:FindFirstChild("SerpentWhirlpool")
        if serpentWhirlpool then
            local pos = serpentWhirlpool:IsA("Model") and serpentWhirlpool:GetPivot().Position or serpentWhirlpool.Position
            return pos, "SerpentWhirlpool (ใน Effects)"
        end
        
        local alt = workspace:FindFirstChild("SerpentWhirlpool", true)
        if alt and alt.Name == "SerpentWhirlpool" and alt.Parent ~= workspace:FindFirstChild("Areas") then
            local pos = alt:IsA("Model") and alt:GetPivot().Position or alt.Position
            return pos, "SerpentWhirlpool (ใน Workspace)"
        end
        
        return nil, nil
    end)
    
    if ok then
        return resPos, resName
    end
    return nil, nil
end

----------------------------------------------------------------------
-- 6. FIREBASE COORDINATOR (ระบบเรียกเพื่อน & ตามเพื่อน)
----------------------------------------------------------------------
local isFightingBoss = false
local currentFightingBossName = nil
local maruBossName = nil -- บอสที่อยู่ในเซิร์ฟและปล่อยให้ Maru Hub ตี (ตอน AUTO_ATTACK_BOSS ปิด)
-- ตกได้ปลา WhirlpoolBeast = Serpent กำลังจะเกิด -> หยุดตกปลา/ห้ามสลับกลับไปถือเบ็ด จนบอสเกิด (หรือครบเวลา)
local WHIRLPOOL_BEAST_ICON = "rbxassetid://88523269369843" -- ไอคอนเฉพาะของปลานี้ใน Fishing() ของเกม
local BOSS_INCOMING_TIMEOUT = 30
local bossIncomingUntil = 0
local onWhirlpoolBeastCaught = nil -- ตั้งค่าใน section 10.5 (ต้องใช้ ensureSwordReady ที่ประกาศทีหลัง)
local isTeleportingToFriend = false
local bypassHopBlock = false
local heartbeatSignalThread = nil
local activeBroadcastKey = nil
local lastBroadcastAt = 0
local broadcastInFlight = false
-- เลขรุ่นของการส่งสัญญาณ: ตามเพื่อน / ล้างสัญญาณ / ย้ายเซิร์ฟ = เพิ่มเลข -> งานส่งสัญญาณที่ค้างอยู่รู้ว่าถูกยกเลิก
-- (เน็ตช้า PUT ใช้ 11-21 วิ ระหว่างนั้นเราอาจตัดสินใจไปหาเพื่อนแล้ว ห้ามเขียนสัญญาณของเราทับตามหลัง)
local broadcastGeneration = 0
local followingSignal = nil -- สัญญาณของเพื่อนที่เรากำลังวาร์ปไปหา (ไว้เขียนคืนถ้าเราเผลอทับไปแล้ว)
local followAttempts = {}
local MAX_FOLLOW_ATTEMPTS = 3
local isHoppingServer = false -- กำลังย้ายเซิร์ฟเองหลังบอสจบ (ห้ามไปตามเพื่อนแทรก)
local hopToNewServerRef = nil -- ตั้งค่าหลังประกาศ hopToNewServer (followFriend อยู่ก่อนหน้า เรียกตรงไม่ได้)
local findBossInServerRef = nil -- ตั้งค่าหลังประกาศ findBossInServer (เหตุผลเดียวกัน)
-- ช่วงกำลังวาร์ปไปหาเพื่อน: บล็อคการย้ายเซิร์ฟอื่นทั้งหมด (Maru SerpentHop) ยกเว้นคำสั่งไป JobId เพื่อน
local FOLLOW_BLOCK_SECONDS = 15
local followTargetJobId = nil
local followBlockUntil = 0
local lastTeleportFailReason = nil -- จาก TeleportInitFailed (ใช้บอกเหตุผลใน log วาร์ปไม่สำเร็จ)
local lastTeleportFailKind = nil   -- ชื่อ Enum.TeleportResult เช่น "GameFull" / "IsTeleporting" / "Failure"
local lastTeleportFailAt = 0       -- os.clock() ตอน Roblox แจ้งว่าวาร์ปไม่สำเร็จ

-- รอผลการวาร์ปที่เพิ่งสั่ง: Roblox แจ้งล้มเหลว -> คืนชนิด (ไม่ต้องรอจนครบเวลา) / ไม่มีแจ้ง -> nil
-- (วาร์ปสำเร็จ = สคริปต์นี้หายไปพร้อมเซิร์ฟเดิมก่อนรอเสร็จ)
local function waitTeleportOutcome(startedAt, maxSeconds)
    local deadline = os.clock() + maxSeconds
    while os.clock() < deadline do
        if lastTeleportFailAt > startedAt then
            return lastTeleportFailKind or "Failure"
        end
        task.wait(0.25)
    end
    return nil
end

-- ปลายทางใช้ไม่ได้แน่ ๆ (เต็ม / ปิด / ไม่มีสิทธิ์) -> ลองซ้ำก็ไม่ได้
local DEAD_TARGET_RESULTS = { GameFull = true, GameNotFound = true, GameEnded = true, Unauthorized = true }
local installHopBlockHooksWhenSafe = nil -- ประกาศจริงใน section กัน Hop (ด้านล่าง)

-- นาฬิกากลางจาก Firebase (กันเวลาเครื่องแต่ละเครื่องไม่ตรงกันจนสัญญาณหมดอายุผิด)
local serverTimeOffset = 0

local function localNowSeconds()
    return DateTime.now().UnixTimestampMillis / 1000
end

local function serverNow()
    return localNowSeconds() + serverTimeOffset
end

-- เวลาในสัญญาณ: Firebase ประทับเวลาเองตอนรับข้อมูล ({".sv":"timestamp"} = มิลลิวินาที)
-- (เดิมประทับเวลาเครื่องก่อนอ่าน/เขียนที่ใช้ 11-21 วิ -> เพื่อนเห็นสัญญาณเกือบหมดอายุตั้งแต่ได้รับ)
local FIREBASE_SERVER_TIMESTAMP = { [".sv"] = "timestamp" }

-- รองรับทั้งมิลลิวินาที (ตัวใหม่) และวินาที (ไอดีที่ยังใช้ main.lua ตัวเก่า)
local function signalTimestampSeconds(value)
    local ts = tonumber(value) or 0
    if ts > 1e12 then ts = ts / 1000 end
    return ts
end

local function calibrateServerTime()
    local base = string.match(CONFIG.FIREBASE_URL, "^(.*/)[^/]+%.json$")
    if not base then return end
    local sentAt = localNowSeconds()
    local clockStart = os.clock()
    local ok, serverMs = httpPut(base .. "clock/" .. tostring(LocalPlayer.UserId) .. ".json", FIREBASE_SERVER_TIMESTAMP)
    local roundTrip = os.clock() - clockStart
    if ok and type(serverMs) == "number" then
        -- เซิร์ฟเวอร์ประทับเวลาราว ๆ กลางทางของคำขอ (เน็ตช้าไปกลับ 10-20 วิ ถ้าไม่หักครึ่งจะคลาดเท่านั้น)
        serverTimeOffset = serverMs / 1000 - (sentAt + roundTrip / 2)
        print(string.format("[KL-Fisher] 🕒 ซิงค์เวลากับ Firebase แล้ว (ต่างจากเครื่องนี้ %.1f วินาที, ไปกลับ %.1f วินาที)", serverTimeOffset, roundTrip))
    end
end

local function stopHeartbeat()
    if heartbeatSignalThread then
        pcall(task.cancel, heartbeatSignalThread)
        heartbeatSignalThread = nil
    end
end

local function isSelfSignal(data)
    if not data or type(data) ~= "table" then return true end
    
    if data.finder and LocalPlayer and LocalPlayer.Name then
        local finderName = string.lower(string.gsub(tostring(data.finder), "%s+", ""))
        local myName = string.lower(string.gsub(tostring(LocalPlayer.Name), "%s+", ""))
        if finderName == myName then
            return true
        end
    end
    
    if data.jobId and game.JobId and game.JobId ~= "" then
        if tostring(data.jobId) == tostring(game.JobId) then
            return true
        end
    end
    
    return false
end

-- เซิร์ฟที่ไม่ตามสัญญาณไปอีก (เก็บเป็นไฟล์แยกต่อไอดี เพราะตัวนับในหน่วยความจำหายทุกครั้งที่ย้ายเซิร์ฟ)
--   - เซิร์ฟที่เพิ่งออกมาหลังบอสตาย: สัญญาณเก่าที่ยังไม่หมดอายุจะไม่ดึงเรากลับไปเซิร์ฟบอสตายแล้ว
--   - เซิร์ฟเพื่อนที่วาร์ปไม่สำเร็จครบ 3 ครั้ง (เต็ม/ปิด): ไม่วนย้ายเซิร์ฟแล้วกลับมาลองใหม่ไม่จบ
local SKIP_JOBS_FILE = "kl_skip_jobs_" .. tostring(LocalPlayer.UserId) .. ".json"
local skipJobs = {} -- jobId -> เวลาหมดอายุ (os.time)

do
    pcall(function()
        if isfile and readfile and isfile(SKIP_JOBS_FILE) then
            local loaded = HttpService:JSONDecode(readfile(SKIP_JOBS_FILE))
            local now = os.time()
            for jobId, expiresAt in pairs(loaded or {}) do
                if tonumber(expiresAt) and tonumber(expiresAt) > now then
                    skipJobs[jobId] = tonumber(expiresAt)
                end
            end
        end
    end)
end

local function markSkipJob(jobId, seconds)
    if not jobId or jobId == "" then return end
    skipJobs[tostring(jobId)] = os.time() + seconds
    pcall(function()
        if writefile then writefile(SKIP_JOBS_FILE, HttpService:JSONEncode(skipJobs)) end
    end)
end

local function isSkippedJob(jobId)
    local expiresAt = skipJobs[tostring(jobId)]
    return expiresAt ~= nil and expiresAt > os.time()
end

-- สัญญาณของเพื่อนที่ยังใช้ได้ (ไม่ใช่ของเรา / รหัสตรง / JobId ถูกรูปแบบ / ยังไม่หมดอายุ / ไม่อยู่ในรายการข้าม) -> คืน data ไม่งั้น nil
local function evaluateForeignSignal(data)
    if not data or type(data) ~= "table" then return nil end
    if isSelfSignal(data) then return nil end
    if isSkippedJob(data.jobId) then return nil end -- ถือว่าไม่มีสัญญาณ: ไม่ตาม และส่งสัญญาณของเราทับได้
    if CONFIG.SIGNAL_KEY ~= "" and data.key ~= CONFIG.SIGNAL_KEY then return nil end

    -- JobId ต้องเป็นรูปแบบ GUID ของ Roblox เท่านั้น กันข้อมูลขยะ/ข้อมูลปลอม
    local jobIdOk = type(data.jobId) == "string" and string.match(data.jobId, "^%x+%-%x+%-%x+%-%x+%-%x+$") ~= nil
    if data.status == "active" and data.finder and jobIdOk then
        local age = serverNow() - signalTimestampSeconds(data.timestamp)
        if age <= CONFIG.SIGNAL_TIMEOUT then
            return data
        end
    end
    return nil
end

-- กติกา "ใครเจอก่อนได้ก่อน": มีสัญญาณเพื่อนที่ยังใช้ได้ค้างอยู่ = ห้ามทับ (เราไปหาเพื่อนแทน)
-- ยกเว้นเราเจอบอส แต่ของเพื่อนเป็นแค่น้ำวน (บอสด่วนกว่า)
-- (ทุกไอดีมี Maru เรียกน้ำวนในเซิร์ฟตัวเอง ถ้าต่างคนต่างทับกันจะวาร์ปสลับกันไปมาไม่จบ)
local function canOverwriteSignal(myType, current)
    local foreign = evaluateForeignSignal(current)
    if not foreign then return true, nil end
    if myType == "Boss" and foreign.targetType ~= "Boss" then return true, foreign end
    return false, foreign
end

-- log การเรียกเพื่อนเข้า Discord (ส่งเบื้องหลัง ไม่รอผล / ไม่ลองซ้ำ เพราะเป็นแค่บันทึก)
local function shortJobId(jobId)
    local text = tostring(jobId or "")
    return #text > 8 and (string.sub(text, 1, 8) .. "…") or text
end

-- ชื่อโมเดลบอสในเกม -> ชื่อที่โชว์บนจอ (จาก RaidBossList ของเกม) ใช้แสดงใน log / Discord / สัญญาณเพื่อน
local BOSS_DISPLAY_NAMES = {
    Serpent = "Serpent",
    ThirdSeaDragon = "Drakenfyr the Inferno King",
    SeaDragon = "Abyssal Tyrant",
}

local function bossDisplayName(name)
    return BOSS_DISPLAY_NAMES[tostring(name)] or tostring(name)
end

local function targetLabel(targetType, targetName)
    if targetType == "Whirlpool" then
        return string.format("🌊 น้ำวน `%s`", tostring(targetName))
    end
    return string.format("🐉 บอส `%s`", bossDisplayName(targetName))
end

local function postCoordLog(message)
    local url = CONFIG.DISCORD_COORD_WEBHOOK_URL
    if not CONFIG.DISCORD_COORD_LOG or not httpRequest or not url or url == "" then return end
    task.spawn(function()
        pcall(function()
            httpRequest({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({ username = "KING-JOIN-FRIEND", content = message })
            })
        end)
    end)
end

local coordLoggedFinds = {} -- "<JobId>:<ประเภท>" ที่เคย log ว่าเจอแล้ว (ไม่ log ซ้ำทุกรอบเหวี่ยงเบ็ด)
local lastYieldedJobId = nil

local function broadcastTarget(targetType, targetName)
    if targetType == "Boss" and not CONFIG.BROADCAST_BOSS then return end
    if targetType == "Whirlpool" and not CONFIG.BROADCAST_WHIRLPOOL then return end

    -- กันส่งซ้ำทุกรอบ: เป้าเดิมที่ heartbeat ยังทำงานอยู่ หรือเพิ่งส่งไปไม่ถึง 10 วินาที
    -- (ห้ามตั้ง isFightingBoss ที่นี่ ให้ attackTarget เป็นคนตั้งเท่านั้น ไม่งั้นค้างถาวรถ้าไม่ได้เข้าตีบอส)
    local key = targetType .. ":" .. tostring(targetName)
    local heartbeatAlive = heartbeatSignalThread ~= nil and coroutine.status(heartbeatSignalThread) ~= "dead"
    -- broadcastInFlight: เน็ตช้า PUT ครั้งแรกค้างนาน (log จริง 11 วิ) heartbeat ยังไม่เกิด -> อย่าส่งซ้ำระหว่างรอ
    if activeBroadcastKey == key and (heartbeatAlive or broadcastInFlight or os.clock() - lastBroadcastAt < 10) then
        return
    end
    -- เป้าเปลี่ยน (เช่นจากน้ำวนเป็นบอส): ยกเลิกงานส่ง/ต่ออายุของเป้าเดิมก่อน
    -- ไม่งั้นสัญญาณน้ำวนที่ยังเขียนค้างอยู่จะลงทีหลังแล้วทับสัญญาณบอส และ heartbeat เก่าหลุดการควบคุม
    if activeBroadcastKey ~= key then
        broadcastGeneration = broadcastGeneration + 1
        stopHeartbeat()
    end
    activeBroadcastKey = key
    lastBroadcastAt = os.clock()
    broadcastInFlight = true

    task.spawn(function()
        local myGeneration = broadcastGeneration
        local function superseded()
            return myGeneration ~= broadcastGeneration or isTeleportingToFriend or isHoppingServer
        end

        local payload = {
            finder = LocalPlayer.Name,
            targetType = targetType,
            -- เพื่อนเห็นชื่อที่อ่านง่าย (heartbeat ยังเทียบด้วยชื่อโมเดล targetName เหมือนเดิม)
            boss = (targetType == "Boss") and bossDisplayName(targetName) or targetName,
            jobId = game.JobId,
            placeId = game.PlaceId,
            timestamp = FIREBASE_SERVER_TIMESTAMP, -- Firebase ประทับเวลาเองตอนเขียน (มิลลิวินาที)
            key = CONFIG.SIGNAL_KEY,
            status = "active"
        }

        -- เพื่อนส่งสัญญาณมาก่อน -> ไม่ทับ (ตัวเช็คสัญญาณเบื้องหลังจะพาวาร์ปไปหาเพื่อนเอง) / ลองใหม่ได้อีกใน 10 วิ
        local allowed, foreign = canOverwriteSignal(targetType, httpGet(CONFIG.FIREBASE_URL))
        if not allowed then
            broadcastInFlight = false
            lastBroadcastAt = os.clock()
            if foreign.jobId ~= lastYieldedJobId then
                lastYieldedJobId = foreign.jobId
                print(string.format("[KL-Fisher] ℹ️ เพื่อน '%s' เจอ%s '%s' ก่อนแล้ว -> ไม่ทับสัญญาณ ไปรวมที่เซิร์ฟเพื่อนแทน",
                    tostring(foreign.finder), foreign.targetType == "Boss" and "บอส" or "น้ำวน", tostring(foreign.boss)))
                postCoordLog(string.format("🤝 **%s** เจอ %s ด้วย แต่ **%s** เจอ %s ก่อน → ไปรวมที่เซิร์ฟ **%s** (JobId `%s`)",
                    LocalPlayer.Name, targetLabel(targetType, targetName), tostring(foreign.finder),
                    targetLabel(foreign.targetType, foreign.boss), tostring(foreign.finder), shortJobId(foreign.jobId)))
            end
            return
        end

        -- ระหว่างรออ่าน (เน็ตช้า) เราเริ่มไปหาเพื่อน / ล้างสัญญาณ / ย้ายเซิร์ฟแล้ว -> ไม่ต้องส่ง
        if superseded() then
            broadcastInFlight = false
            return
        end

        local putOk = httpPut(CONFIG.FIREBASE_URL, payload)
        broadcastInFlight = false
        lastBroadcastAt = os.clock()

        -- เขียนเสร็จทีหลังที่เราตัดสินใจไปหาเพื่อนแล้ว = เราทับสัญญาณเพื่อนไป -> เขียนสัญญาณเพื่อนคืน ไม่งั้นเพื่อนวาร์ปสวนมาหาเรา
        if superseded() then
            -- เขียนคืนเฉพาะตอนที่ถูกยกเลิกเพราะกำลังวาร์ปไปหาเพื่อนจริง ๆ
            -- (ถูกยกเลิกเพราะล้างสัญญาณ/ย้ายเซิร์ฟ ห้ามเขียนสัญญาณเพื่อนเก่าคืน = ปลุกสัญญาณที่ตายแล้วให้อยู่ต่ออีก 120 วิ)
            if followingSignal and isTeleportingToFriend then
                httpPut(CONFIG.FIREBASE_URL, followingSignal)
            end
            return
        end

        -- กันสองไอดีเจอพร้อมกัน (อ่านช่องว่างทั้งคู่ แล้วเขียนทับกัน): เช็คซ้ำว่าช่องยังเป็นของเราไหม
        -- เจอของเพื่อน 2 ครั้งติด (ห่างกัน 5 วิ) ค่อยยอมถอย เผื่ออีกฝ่ายกำลังเขียนสัญญาณเราคืน
        task.wait(3)
        if not superseded() and not canOverwriteSignal(targetType, httpGet(CONFIG.FIREBASE_URL)) then
            task.wait(5)
            if not superseded() and not canOverwriteSignal(targetType, httpGet(CONFIG.FIREBASE_URL)) then
                print("[KL-Fisher] ℹ️ เพื่อนส่งสัญญาณทับพร้อมกัน -> ยอมถอย ไปรวมที่เซิร์ฟเพื่อนแทน")
                return
            end
        end
        if superseded() then return end

        local findKey = tostring(game.JobId) .. ":" .. targetType
        if putOk and not coordLoggedFinds[findKey] then
            coordLoggedFinds[findKey] = true
            postCoordLog(string.format("📢 **%s** เจอ %s → เรียกเพื่อนมารวม (PlaceId `%s` / JobId `%s`)",
                LocalPlayer.Name, targetLabel(targetType, targetName), tostring(game.PlaceId), tostring(game.JobId)))
        end
        local typeLabel = (targetType == "Whirlpool") and "🌊 น้ำวน" or "🐉 บอส"
        print("══════════════════════════════════════════════════")
        print(string.format("📢 [KL-Fisher] พบ%s '%s' ในเซิร์ฟนี้! (JobId: %s)", typeLabel, tostring(payload.boss), tostring(game.JobId)))
        print(" -> ส่งสัญญาณเรียกเพื่อน A, B, C ทาง Firebase เรียบร้อย")
        print("══════════════════════════════════════════════════")
        
        stopHeartbeat()

        if CONFIG.SIGNAL_HEARTBEAT then
            heartbeatSignalThread = task.spawn(function()
                while true do
                    task.wait(5)
                    local shouldKeepAlive = false
                    if targetType == "Boss" and ((isFightingBoss and currentFightingBossName == targetName) or maruBossName == targetName) then
                        shouldKeepAlive = true
                    elseif targetType == "Whirlpool" and getWhirlpoolTarget() ~= nil and not isFightingBoss then
                        shouldKeepAlive = true
                    end
                    
                    if superseded() then shouldKeepAlive = false end

                    -- ระหว่างนี้มีเพื่อนส่งสัญญาณทับมา (เช่นเพื่อนเจอบอส) -> หยุดต่ออายุของเรา ไม่ทับกลับ
                    if shouldKeepAlive and not canOverwriteSignal(targetType, httpGet(CONFIG.FIREBASE_URL)) then
                        print("[KL-Fisher] ℹ️ มีสัญญาณเพื่อนเข้ามาใหม่ -> หยุดต่ออายุสัญญาณของเรา")
                        shouldKeepAlive = false
                    end

                    -- อ่านช้า ระหว่างรออาจถูกยกเลิกไปแล้ว -> เช็คอีกรอบก่อนเขียน
                    if shouldKeepAlive and superseded() then shouldKeepAlive = false end

                    if shouldKeepAlive then
                        payload.timestamp = FIREBASE_SERVER_TIMESTAMP
                        httpPut(CONFIG.FIREBASE_URL, payload)
                    else
                        break
                    end
                end
            end)
        end
    end)
end

-- แจ้ง Discord: ส่งครั้งเดียวต่อเรื่องต่อเซิร์ฟ (ส่งไม่สำเร็จลองใหม่ได้ทุก 30 วิ กันโดน rate limit)
local DISCORD_RETRY_SECONDS = 30
local discordNotified = {} -- key -> true (ส่งแล้ว) หรือ os.clock() ตอนลองล่าสุด

-- ส่งการ์ดแจ้งเตือน (ชื่อเป้า + ผู้พบ + PlaceId + JobId + คำสั่งวาร์ป) เข้า webhook
local function postDiscordTarget(url, key, emoji, kindLabel, targetName, color)
    if not httpRequest or not url or url == "" then return end

    local state = discordNotified[key]
    if state == true then return end
    if type(state) == "number" and os.clock() - state < DISCORD_RETRY_SECONDS then return end
    discordNotified[key] = os.clock()

    local joinCommand = string.format('game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s")', game.PlaceId, tostring(game.JobId))
    local payload = {
        username = "KL-Fisher",
        content = string.format("%s พบ%s **%s** !", emoji, kindLabel, tostring(targetName)),
        embeds = { {
            title = emoji .. " " .. tostring(targetName),
            color = color,
            fields = {
                { name = kindLabel, value = tostring(targetName), inline = true },
                { name = "ผู้พบ", value = LocalPlayer.Name, inline = true },
                { name = "PlaceId", value = tostring(game.PlaceId), inline = true },
                { name = "JobId", value = "```" .. tostring(game.JobId) .. "```" },
                { name = "คำสั่งวาร์ป (วางใน executor)", value = "```lua\n" .. joinCommand .. "\n```" },
            },
            timestamp = DateTime.now():ToIsoDate(),
        } },
    }

    task.spawn(function()
        local ok, response = pcall(function()
            return httpRequest({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)
        local status = ok and response and response.StatusCode
        if status == 200 or status == 204 then
            discordNotified[key] = true
            print(string.format("[KL-Fisher] 📨 ส่ง%s '%s' + JobId เข้า Discord แล้ว", kindLabel, tostring(targetName)))
        else
            warn(string.format("[KL-Fisher] ⚠️ ส่ง Discord (%s) ไม่สำเร็จ (สถานะ: %s) -> ลองใหม่ใน %d วิ", kindLabel, tostring(status or response), DISCORD_RETRY_SECONDS))
        end
    end)
end

local function notifyDiscordBoss(bossName)
    if not CONFIG.DISCORD_NOTIFY_BOSS then return end
    postDiscordTarget(CONFIG.DISCORD_WEBHOOK_URL, tostring(game.JobId) .. ":Boss:" .. tostring(bossName),
        "🐉", "บอส", bossDisplayName(bossName), 15158332)
end

local function notifyDiscordWhirlpool(whirlpoolName)
    if not CONFIG.DISCORD_NOTIFY_WHIRLPOOL then return end
    -- ชื่อที่ส่งมามีวงเล็บบอกตำแหน่ง เช่น "SerpentWhirlpool (ใน Effects)" -> นับเป็นน้ำวนเดียวกันต่อเซิร์ฟ
    postDiscordTarget(CONFIG.DISCORD_WHIRLPOOL_WEBHOOK_URL, tostring(game.JobId) .. ":Whirlpool",
        "🌊", "น้ำวน", whirlpoolName, 3447003)
end

local function broadcastBossFound(bossName)
    notifyDiscordBoss(bossName)
    broadcastTarget("Boss", bossName)
end

local function broadcastWhirlpoolFound(whirlpoolName)
    notifyDiscordWhirlpool(whirlpoolName)
    broadcastTarget("Whirlpool", whirlpoolName)
end

local function clearSignal(force)
    isFightingBoss = false
    currentFightingBossName = nil
    activeBroadcastKey = nil
    broadcastGeneration = broadcastGeneration + 1 -- ยกเลิกงานส่งสัญญาณที่ค้างอยู่ ไม่ให้เขียน "active" ตามหลังการล้าง
    stopHeartbeat()

    task.spawn(function()
        if not force then
            -- Firebase มีช่องสัญญาณเดียว: ถ้าตอนนี้เป็นสัญญาณของเพื่อนเครื่องอื่น ห้ามล้างทับ
            local current = httpGet(CONFIG.FIREBASE_URL)
            if type(current) == "table" and current.status == "active" and not isSelfSignal(current) then
                print(string.format("[KL-Fisher] ℹ️ สัญญาณปัจจุบันเป็นของเพื่อน '%s' -> ไม่ล้างทับ", tostring(current.finder)))
                return
            end
        end

        local payload = {
            finder = "",
            targetType = "None",
            boss = "",
            jobId = "",
            placeId = game.PlaceId,
            timestamp = 0,
            status = "idle"
        }
        httpPut(CONFIG.FIREBASE_URL, payload)
        print("[KL-Fisher] 🏁 เคลียร์สัญญาณ Firebase เรียบร้อย (สถานะ: ว่าง/ตกปลาต่อ)")
    end)
end

local function checkActiveSignal()
    return evaluateForeignSignal(httpGet(CONFIG.FIREBASE_URL))
end

local function followFriend(signal)
    if not CONFIG.AUTO_FOLLOW_FRIENDS then return end
    if isTeleportingToFriend or isFightingBoss or isHoppingServer then return end
    if maruBossName then return end -- เซิร์ฟเรามีบอสที่ Maru กำลังตีอยู่ ห้ามวาร์ปหนี
    if isSelfSignal(signal) then return end
    -- ตกได้ WhirlpoolBeast แล้ว บอสกำลังจะเกิดในเซิร์ฟเรา -> อยู่ก่อน (เดี๋ยวเราเรียกเพื่อนมาแทน)
    if os.clock() < bossIncomingUntil then return end
    -- (เลิกบล็อคตอนเซิร์ฟเรามีน้ำวนแล้ว: ทุกไอดีมี Maru เรียกน้ำวนเอง เลยไม่มีใครวาร์ปตามใครเลย
    --  ตอนนี้ใช้กติกา "ใครเจอก่อนได้ก่อน" ใน broadcastTarget แทน -> ไปรวมที่เซิร์ฟของคนที่ส่งสัญญาณก่อน)

    -- บอสเพิ่งเกิดในเซิร์ฟเรา แต่ลูปหลักยังไม่ทันเห็น -> ห้ามวาร์ปหนีบอสตัวเอง
    if findBossInServerRef and findBossInServerRef() then return end

    -- เซิร์ฟเต็ม/ปิดไปแล้ว: ลองซ้ำได้จำกัด (เช็คก่อนทำอะไรทั้งนั้น: เดิมยกเลิกสัญญาณเราก่อนเช็ค
    -- พอครบแล้วก็ยังไปตัดสัญญาณบอสของเรา + เขียนสัญญาณเซิร์ฟที่ตามไม่ได้คืนทุก 3 วิ)
    local jobKey = tostring(signal.jobId)
    if (followAttempts[jobKey] or 0) >= MAX_FOLLOW_ATTEMPTS then
        followAttempts[jobKey] = MAX_FOLLOW_ATTEMPTS
        warn(string.format("[KL-Fisher] ⚠️ วาร์ปไป JobId %s ไม่สำเร็จครบ %d ครั้ง -> ข้ามสัญญาณนี้", jobKey, MAX_FOLLOW_ATTEMPTS))
        postCoordLog(string.format("⛔ **%s** วาร์ปไปหา **%s** ไม่สำเร็จครบ %d ครั้ง → เลิกตามสัญญาณนี้ (JobId `%s`)",
            LocalPlayer.Name, tostring(signal.finder), MAX_FOLLOW_ATTEMPTS, shortJobId(jobKey)))
        -- จดเซิร์ฟนี้ลงไฟล์ 10 นาที: ย้ายเซิร์ฟแล้วตัวนับในหน่วยความจำรีเซ็ต ถ้าไม่จดจะวนกลับมาลองใหม่ไม่จบ
        -- (และถือว่าไม่มีสัญญาณนี้ -> เจอน้ำวน/บอสเองก็เรียกเพื่อนได้ ไม่โดนสัญญาณที่ตามไม่ได้ขวางไว้)
        markSkipJob(jobKey, 10 * 60)
        -- ตามไม่ได้แล้ว (เซิร์ฟเพื่อนเต็ม/ปิด) -> ไม่ยืนรอในเซิร์ฟเดิม ย้ายไปเซิร์ฟใหม่เลย
        if hopToNewServerRef then
            task.spawn(hopToNewServerRef, string.format("วาร์ปไปหา %s ไม่สำเร็จครบ %d ครั้ง", tostring(signal.finder), MAX_FOLLOW_ATTEMPTS))
        end
        return
    end
    followAttempts[jobKey] = (followAttempts[jobKey] or 0) + 1

    -- หยุดส่ง/ต่ออายุสัญญาณของเราก่อนวาร์ป ไม่งั้นจะไปทับสัญญาณเพื่อน แล้วเพื่อนวาร์ปสวนมาหาเรา
    -- (เพิ่มเลขรุ่น = ยกเลิกงานส่งสัญญาณที่ค้างอยู่ด้วย ไม่ใช่แค่ heartbeat)
    broadcastGeneration = broadcastGeneration + 1
    stopHeartbeat()
    followingSignal = {
        finder = signal.finder, targetType = signal.targetType, boss = signal.boss,
        jobId = signal.jobId, placeId = signal.placeId, key = signal.key,
        status = "active", timestamp = FIREBASE_SERVER_TIMESTAMP,
    }
    -- ถ้าช่องตอนนี้เป็นสัญญาณของเรา (เราเผลอเขียนทับเพื่อนไปก่อนหน้า) -> เขียนสัญญาณเพื่อนคืน (ทำเบื้องหลัง ไม่ถ่วงการวาร์ป)
    task.spawn(function()
        local current = httpGet(CONFIG.FIREBASE_URL)
        if type(current) == "table" and tostring(current.finder) == LocalPlayer.Name and current.status == "active" then
            httpPut(CONFIG.FIREBASE_URL, followingSignal)
        end
    end)

    -- ไม่ลบแท่นลอยก่อนวาร์ป: ถ้าวาร์ปล้มเหลวจะได้ไม่ตกน้ำจม (ออกจากเซิร์ฟแล้วแท่นหายเอง)
    isTeleportingToFriend = true

    local typeLabel = (signal.targetType == "Whirlpool" or string.find(tostring(signal.boss):lower(), "whirlpool")) and "🌊 น้ำวน" or "🐉 บอส"
    
    print("══════════════════════════════════════════════════")
    print(string.format("🏃‍♂️ [KL-Fisher] ได้รับสัญญาณจากเพื่อน '%s' พบ%s '%s'!", tostring(signal.finder), typeLabel, tostring(signal.boss)))
    print(string.format(" -> กำลังวาร์ปตามไปช่วยเพื่อนที่ JobId: %s...", tostring(signal.jobId)))
    print("══════════════════════════════════════════════════")
    
    pcall(function()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if pGui and pGui:FindFirstChild("FishingUI") then
            pGui.FishingUI:Destroy()
        end
    end)
    
    -- ช่วงนี้บล็อคการย้ายเซิร์ฟอื่น (Maru SerpentHop) ให้ผ่านเฉพาะคำสั่งไป JobId เพื่อน กันชนกันจนวาร์ปไม่ติด
    followTargetJobId = tostring(signal.jobId)
    followBlockUntil = os.clock() + FOLLOW_BLOCK_SECONDS
    if installHopBlockHooksWhenSafe then installHopBlockHooksWhenSafe() end
    lastTeleportFailReason = nil

    postCoordLog(string.format("🏃 **%s** กำลังวาร์ปไปหา **%s** (%s) ครั้งที่ %d/%d → JobId `%s`",
        LocalPlayer.Name, tostring(signal.finder), targetLabel(signal.targetType, signal.boss),
        followAttempts[jobKey], MAX_FOLLOW_ATTEMPTS, shortJobId(signal.jobId)))

    local targetPlaceId = tonumber(signal.placeId) or game.PlaceId
    local attemptStart = os.clock()
    local called = pcall(function()
        TeleportService:TeleportToPlaceInstance(targetPlaceId, tostring(signal.jobId), LocalPlayer)
    end)

    -- วาร์ปสำเร็จ = สคริปต์นี้หายไปพร้อมเซิร์ฟเดิมก่อนครบเวลา (เน็ตช้า วาร์ปอาจใช้ 10 วิ จึงรอสูงสุด 12 วิ)
    -- Roblox แจ้งล้มเหลวมาก่อน -> รู้ทันที ไม่ต้องรอจนครบ
    local failKind = called and waitTeleportOutcome(attemptStart, 12) or "Failure"

    local function finishFollow()
        followTargetJobId = nil
        followBlockUntil = 0
        followingSignal = nil -- ไม่ได้ไปหาเพื่อนแล้ว ห้ามค้างไว้ (ไม่งั้นโดนเขียนคืนทีหลังตอนล้างสัญญาณ/ย้ายเซิร์ฟ)
        isTeleportingToFriend = false
    end

    if failKind == "IsTeleporting" then
        -- มีการวาร์ปอื่นค้างอยู่ (ส่วนใหญ่เป็น Maru ย้ายเซิร์ฟ) -> ไม่นับเป็นครั้งที่ล้มเหลว รอให้อันนั้นจบก่อน
        followAttempts[jobKey] = math.max(0, followAttempts[jobKey] - 1)
        task.wait(8)
        finishFollow()
        return true
    end

    if failKind and DEAD_TARGET_RESULTS[failKind] then
        -- เซิร์ฟเพื่อนเต็ม/ปิดแล้ว -> ลองอีกก็ไม่ได้ ไม่ต้องรอครบ 3 ครั้ง: ข้ามเซิร์ฟนี้ 10 นาที แล้วย้ายเซิร์ฟใหม่เลย
        postCoordLog(string.format("🚫 **%s** วาร์ปไปหา **%s** ไม่ได้: เซิร์ฟ%s (%s) → ข้ามเซิร์ฟนี้ 10 นาที แล้วย้ายเซิร์ฟใหม่",
            LocalPlayer.Name, tostring(signal.finder), failKind == "GameFull" and "เต็ม" or "ปิด/เข้าไม่ได้", failKind))
        markSkipJob(jobKey, 10 * 60)
        finishFollow()
        if hopToNewServerRef then
            task.spawn(hopToNewServerRef, string.format("เซิร์ฟของ %s เต็ม/เข้าไม่ได้", tostring(signal.finder)))
        end
        return true
    end

    -- ยังอยู่เซิร์ฟเดิม (เน็ตสะดุด ฯลฯ) -> ปล่อยให้ย้ายเซิร์ฟได้ตามปกติ แล้วลองใหม่รอบหน้า (สูงสุด 3 ครั้ง)
    postCoordLog(string.format("⚠️ **%s** วาร์ปไปหา **%s** ไม่สำเร็จ (ครั้งที่ %d/%d)%s",
        LocalPlayer.Name, tostring(signal.finder), followAttempts[jobKey], MAX_FOLLOW_ATTEMPTS,
        lastTeleportFailReason and (": " .. lastTeleportFailReason) or " (ยังอยู่เซิร์ฟเดิมหลัง 12 วิ)"))
    finishFollow()
    return true
end

pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage)
        if player ~= LocalPlayer then return end
        warn(string.format("[KL-Fisher] ⚠️ วาร์ปไม่สำเร็จ (%s): %s", tostring(result), tostring(errorMessage)))
        lastTeleportFailReason = string.format("%s - %s", tostring(result), tostring(errorMessage))
        lastTeleportFailKind = (typeof(result) == "EnumItem") and result.Name or tostring(result)
        lastTeleportFailAt = os.clock()
    end)
end)

-- ป้องกันสคริปต์ Hop อื่นหนีระหว่างกำลังมีบอสหรือน้ำวน
local BLOCKED_TELEPORT_METHODS = {
    Teleport = true,
    TeleportToPlaceInstance = true,
    TeleportAsync = true,
    TeleportToPrivateServer = true
}
local lastHopBlockWarn = 0

-- method / jobId ของคำสั่งวาร์ปที่โดนดัก -> บล็อคไหม
local function shouldBlockHop(method, jobId)
    -- 1) กำลังวาร์ปไปหาเพื่อน: ให้ผ่านเฉพาะคำสั่งไป JobId เพื่อน อย่างอื่นบล็อคหมด
    --    (Maru SerpentHop สั่งย้ายพร้อมกัน -> Roblox ไม่รับคำสั่งของเรา "IsTeleporting" แล้วไปโผล่เซิร์ฟสุ่ม)
    if followTargetJobId and os.clock() < followBlockUntil then
        return not (method == "TeleportToPlaceInstance" and tostring(jobId) == followTargetJobId)
    end
    -- ปุ่ม Rejoin ของเราเอง / ตัวกู้คืนตอนหน้าต่าง error ค้าง ต้องผ่านเสมอ
    if bypassHopBlock or isTeleportingToFriend or scriptEnv.KL_REJOINING then return false end
    -- 2) ตัวหลักในโหมดคิว: ย้ายเซิร์ฟได้เฉพาะตอนสคริปต์สั่งเอง (ดึงคิว / ตามตัวหลักอีกตัว / ตีจบแล้วคิวว่าง)
    --    จาก log 20:18-20:31 วันที่ 25: Maru SerpentHop ย้าย Kikiesir6 ทุก ~1 นาที ระหว่างรอคิว (+ 279 สองครั้ง)
    if CONFIG.QUEUE_MODE and MAIN_INDEX then return true end
    -- 3) เซิร์ฟเรามีน้ำวน / บอส / บอสกำลังจะเกิด -> ห้ามย้ายออก
    if not (CONFIG.BLOCK_HOP_SCRIPTS or CONFIG.HOLD_SERVER_AT_WHIRLPOOL_BOSS) then return false end
    return isFightingBoss or maruBossName ~= nil or os.clock() < bossIncomingUntil or getWhirlpoolTarget() ~= nil
end

local function warnHopBlocked(method)
    if os.clock() - lastHopBlockWarn < 15 then return end -- Maru ลองย้ายถี่ ไม่ต้องพิมพ์ทุกครั้ง
    lastHopBlockWarn = os.clock()
    local reason = (followTargetJobId and os.clock() < followBlockUntil) and "กำลังวาร์ปไปหาเพื่อน"
        or ((CONFIG.QUEUE_MODE and MAIN_INDEX) and "ตัวหลักย้ายเซิร์ฟตามคิวเท่านั้น (กัน Maru SerpentHop)" or "เซิร์ฟนี้มีน้ำวน/บอส")
    warn(string.format("[KL-Fisher] 🛡️ บล็อคการย้ายเซิร์ฟ (%s) เพราะ%s", tostring(method), reason))
end

-- ติดตั้ง hook เฉพาะตอนต้องใช้ (วาร์ปหาเพื่อน / เจอน้ำวนหรือบอส / เปิด Block Hop Scripts)
-- (Maru Hub เช็คตอนโหลดว่ามีคน hook เกมไหม ถ้าเจอจะไม่ยอมทำงาน -> ห้าม hook ตั้งแต่เริ่มโดยไม่จำเป็น)
local hopHooksInstalled = false
local function installHopBlockHooks()
    if hopHooksInstalled then return end
    hopHooksInstalled = true

    pcall(function()
        if not hookfunction then return end
        for methodName in pairs(BLOCKED_TELEPORT_METHODS) do
            pcall(function()
                local original
                original = hookfunction(TeleportService[methodName], function(self, ...)
                    -- TeleportToPlaceInstance(placeId, jobId, ...) -> jobId คือ argument ที่ 2
                    if shouldBlockHop(methodName, (select(2, ...))) then
                        warnHopBlocked(methodName)
                        return
                    end
                    return original(self, ...)
                end)
            end)
        end
    end)

    -- สคริปต์ Hop ส่วนใหญ่เรียกแบบ TeleportService:Teleport(...) ซึ่งวิ่งผ่าน __namecall ไม่ผ่านฟังก์ชันที่ hookfunction ไว้
    pcall(function()
        if not hookmetamethod or not getnamecallmethod then return end
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            if self == TeleportService then
                local method = getnamecallmethod()
                if BLOCKED_TELEPORT_METHODS[method] then
                    if shouldBlockHop(method, (select(2, ...))) then
                        warnHopBlocked(method)
                        return
                    end
                    -- shouldBlockHop เรียก method อื่นข้างใน อาจทับชื่อ namecall เดิม ต้องตั้งคืนก่อนส่งต่อ
                    if setnamecallmethod then setnamecallmethod(method) end
                end
            end
            return oldNamecall(self, ...)
        end)
    end)
end

-- รู้ว่า Maru โหลดผ่านแล้วหรือยัง (เช็คจากข้อความที่ Maru พิมพ์ลง console) -> ค่อย hook ได้ ไม่ทำให้ Maru ไม่ทำงาน
-- Maru พิมพ์เลข 6 หลัก และ "Anti AFK Activated" เป็นระยะ / ไม่เจอเลยใน 60 วิ = ถือว่าไม่ได้ใช้ Maru
local MARU_DETECT_TIMEOUT = 60
local maruDetected = false
pcall(function()
    local LogService = game:GetService("LogService")
    local function checkMaruMessage(message)
        if message == "Anti AFK Activated" or string.match(tostring(message), "^%d%d%d%d%d%d$") then
            maruDetected = true
        end
    end
    for _, entry in ipairs(LogService:GetLogHistory()) do
        checkMaruMessage(entry.message)
    end
    LogService.MessageOut:Connect(checkMaruMessage)
end)

installHopBlockHooksWhenSafe = function()
    if hopHooksInstalled then return true end
    if not maruDetected and time() < MARU_DETECT_TIMEOUT then return false end
    installHopBlockHooks()
    print("[KL-Fisher] 🛡️ เปิดตัวกันย้ายเซิร์ฟ (ช่วงวาร์ปหาเพื่อน / เซิร์ฟมีน้ำวนหรือบอส)")
    return true
end

if CONFIG.BLOCK_HOP_SCRIPTS then
    task.spawn(function()
        while not installHopBlockHooksWhenSafe() do task.wait(2) end
    end)
end

----------------------------------------------------------------------
-- 7. BOSS DETECTOR (ค้นหาบอสครอบคลุมทุกจุด ตรงจุด 100% ไม่ตรวจจับมั่ว)
----------------------------------------------------------------------
local function checkFolderForBoss(folder)
    if not folder then return nil, nil end
    for _, entity in ipairs(folder:GetChildren()) do
        if entity:IsA("Model") then
            local eName = entity.Name:lower()
            for _, bossName in ipairs(CONFIG.TARGET_BOSSES) do
                local bTarget = bossName:lower()
                if string.find(eName, bTarget) then
                    local hum = entity:FindFirstChildOfClass("Humanoid")
                    local root = entity:FindFirstChild("HumanoidRootPart") 
                        or entity.PrimaryPart 
                        or entity:FindFirstChildWhichIsA("BasePart")
                    if hum and hum.Health > 0 and root then
                        return entity.Name, entity
                    end
                end
            end
        end
    end
    return nil, nil
end

local function findBossInServer()
    -- 1. ตรวจสอบ SeaMonster (Serpent, Sea Dragons ฯลฯ)
    local name, entity = checkFolderForBoss(workspace:FindFirstChild("SeaMonster"))
    if name and entity then return name, entity end

    -- 2. ตรวจสอบ GhostMonster (Ghost Galleon Boss)
    name, entity = checkFolderForBoss(workspace:FindFirstChild("GhostMonster"))
    if name and entity then return name, entity end

    -- 3. ตรวจสอบ Monster.Boss (Raid Bosses เช่น Beck, Dark Beard, Lucidus)
    local monsterFolder = workspace:FindFirstChild("Monster")
    if monsterFolder then
        name, entity = checkFolderForBoss(monsterFolder:FindFirstChild("Boss"))
        if name and entity then return name, entity end
        name, entity = checkFolderForBoss(monsterFolder:FindFirstChild("Mon"))
        if name and entity then return name, entity end
    end

    -- 4. ตรวจสอบ MOB
    name, entity = checkFolderForBoss(workspace:FindFirstChild("MOB"))
    if name and entity then return name, entity end

    -- 5. ตรวจสอบใน workspace โดยตรง (เฉพาะ Model ที่มี Humanoid เลือด > 0 และ RootPart)
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") then
            local cName = child.Name:lower()
            for _, bossName in ipairs(CONFIG.TARGET_BOSSES) do
                if string.find(cName, bossName:lower()) then
                    local hum = child:FindFirstChildOfClass("Humanoid")
                    local root = child:FindFirstChild("HumanoidRootPart") or child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
                    if hum and hum.Health > 0 and root then
                        return child.Name, child
                    end
                end
            end
        end
    end

    return nil, nil
end
findBossInServerRef = findBossInServer

----------------------------------------------------------------------
-- 8. TOOL & WEAPON MANAGEMENT (จัดการอาวุธ & เบ็ดตกปลา)
----------------------------------------------------------------------
local function normalizeToolName(str)
    if not str then return "" end
    return str:lower():gsub("%s+", ""):gsub("[^%w]", "")
end

local function isCombatTool(item)
    if not item or not item:IsA("Tool") then return false end
    local name = item.Name:lower()
    local ignoreKeywords = {
        "rod", "fish", "reel", "compass", "potion", "candy", 
        "ticket", "gift", "box", "chest", "scroll"
    }
    for _, kw in ipairs(ignoreKeywords) do
        if string.find(name, kw) then
            return false
        end
    end
    -- ท่าโพส/อีโมทจาก gamepass (เช่น LegacyPose) ไม่ใช่อาวุธ
    -- (เช็คแค่ลงท้ายด้วย pose เพื่อไม่ตัดอาวุธชื่อ Poseidon ฯลฯ)
    if string.find(name, "pose$") or string.find(name, "emote") then
        return false
    end
    return true
end

local function isSwordTool(item)
    if not item or not item:IsA("Tool") then return false end
    if not isCombatTool(item) then return false end
    
    local name = item.Name:lower()
    if item:GetAttribute("WeaponType") == "Sword" or item:FindFirstChild("Sword") then
        return true
    end
    
    local swordKeywords = {
        "mace", "authentic", "kioru", "sword", "blade", "katana", "saber", "dagger", "scythe", 
        "trident", "bisento", "muramasa", "acrodagger", "pole",
        "axe", "spear", "cutlass", "rapier", "greatsword", "pyreblade", "surge"
    }
    for _, kw in ipairs(swordKeywords) do
        if string.find(name, kw) then
            return true
        end
    end
    return false
end

local function getCombatTools()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local allAvailable = {}
    
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") and isCombatTool(item) and not table.find(allAvailable, item) then
                table.insert(allAvailable, item)
            end
        end
    end
    
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and isCombatTool(item) and not table.find(allAvailable, item) then
                table.insert(allAvailable, item)
            end
        end
    end
    
    local preferredTool = nil
    local otherTools = {}
    local prefNorm = normalizeToolName(CONFIG.PREFERRED_SWORD)
    
    for _, item in ipairs(allAvailable) do
        local iNorm = normalizeToolName(item.Name)
        if prefNorm ~= "" and (string.find(iNorm, prefNorm) or string.find(prefNorm, iNorm)) then
            preferredTool = item
        else
            table.insert(otherTools, item)
        end
    end
    
    table.sort(otherTools, function(a, b) return a.Name < b.Name end)
    
    local tools = {}
    if preferredTool then
        table.insert(tools, preferredTool)
    end
    for _, item in ipairs(otherTools) do
        table.insert(tools, item)
    end
    
    return tools
end

local lastRodName = nil
local DEFAULT_ROD_NAME = "Basic Rod" -- เบ็ดเล่มเดียวในเกม (Swords.Basic Rod_Data) ใช้ตอนยังไม่รู้ชื่อเบ็ดที่ใช้อยู่

local function isRodName(name)
    -- ห้ามนับ "pole": ในเกม Pole คือดาบ (Swords.Pole_Data) เบ็ดมีแค่ชื่อลงท้าย Rod เช่น Basic Rod
    local n = string.lower(name or "")
    return string.find(n, "rod") ~= nil or string.find(n, "fishing") ~= nil
end

local function getRodTool()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    
    local allTools = {}
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then table.insert(allTools, item) end
        end
    end
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then table.insert(allTools, item) end
        end
    end
    
    for _, item in ipairs(allTools) do
        if isRodName(item.Name) or item:GetAttribute("Fishing") then
            -- จำชื่อเบ็ดไว้ หลังสู้บอสเสร็จจะได้หยิบเล่มเดิมกลับจากกระเป๋าเกม
            lastRodName = item.Name
            return item
        end
    end
    return nil
end

----------------------------------------------------------------------
-- กระเป๋าเกม (MainGui > StarterFrame > Inventory_Frame)
-- King Legacy ถือดาบได้ทีละเล่ม และเบ็ดก็อยู่หมวดดาบ (ScrollingFrameSwords) ใช้ช่องเดียวกัน
-- ดาบที่ไม่ได้ใส่ช่องอยู่จะไม่อยู่ใน Backpack ต้องกดปุ่มไอเทมในหน้านี้เพื่อหยิบออกมา
----------------------------------------------------------------------
-- เกมผูกปุ่มด้วย MouseButton1Click (ดู ConnectButton ใน MainGui) จึงลองตัวนี้ก่อน
local INVENTORY_CLICK_SIGNALS = { "MouseButton1Click", "Activated" }
local INVENTORY_RETRY_COOLDOWN = 60
local inventoryFailedAt = {}

local function getInventoryFrame()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local mainGui = pGui and pGui:FindFirstChild("MainGui")
    local starter = mainGui and mainGui:FindFirstChild("StarterFrame")
    return starter and starter:FindFirstChild("Inventory_Frame")
end

local function findOwnedTool(itemName)
    local targetNorm = normalizeToolName(itemName)
    local containers = {}
    if LocalPlayer.Character then table.insert(containers, LocalPlayer.Character) end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then table.insert(containers, backpack) end

    for _, container in ipairs(containers) do
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and normalizeToolName(item.Name) == targetNorm then
                return item
            end
        end
    end
    return nil
end

local function waitForOwnedTool(itemName, timeout)
    local start = os.clock()
    repeat
        local tool = findOwnedTool(itemName)
        if tool then return tool end
        task.wait(0.15)
    until os.clock() - start > timeout
    return nil
end

-- กดปุ่ม GUI ได้แม้หน้าต่างปิดอยู่ (ยิง signal ตรง ไม่ต้องคลิกจริง)
local function fireGuiSignal(btn, signalName)
    local ok, signal = pcall(function() return btn[signalName] end)
    if not ok or not signal then return false end
    if firesignal then
        return (pcall(firesignal, signal))
    end
    if getconnections then
        local fired = false
        pcall(function()
            for _, conn in ipairs(getconnections(signal)) do
                if conn.Function then
                    task.spawn(conn.Function)
                    fired = true
                elseif conn.Fire then
                    conn:Fire()
                    fired = true
                end
            end
        end)
        return fired
    end
    return false
end

-- ดัก InventoryEq ที่เกมเรียกเองตอนกดปุ่มในกระเป๋า เพื่อ:
-- 1) รู้ว่ากดปุ่มแล้วเกมส่งคำขอจริงไหม (ไม่ส่ง = ปุ่มยังไม่ถูกผูก ต้องเปิดกระเป๋าก่อน)
-- 2) จำรูปแบบคำขอไว้ ครั้งต่อไปเรียก remote ตรง ๆ ไม่ต้องพึ่ง GUI
-- 3) พิมพ์ผลตอบกลับจากเซิร์ฟเวอร์ลง console ไว้ดูว่าทำไมใส่ไม่ได้
local inventoryEqRemotes = {}
local inventoryEqCallCount = 0
local lastInventoryEqCall = nil
local inventoryEqTemplate = nil

do
    local chest = ReplicatedStorage:FindFirstChild("Chest")
    local remotes = chest and chest:FindFirstChild("Remotes")
    local fnFolder = remotes and remotes:FindFirstChild("Functions")
    local evFolder = remotes and remotes:FindFirstChild("Events")
    local fn = fnFolder and fnFolder:FindFirstChild("InventoryEq")
    local ev = evFolder and evFolder:FindFirstChild("InventoryEq")
    if fn then inventoryEqRemotes[fn] = "Functions.InventoryEq" end
    if ev then inventoryEqRemotes[ev] = "Events.InventoryEq" end
end

local function serializeValue(value, depth)
    depth = depth or 0
    local t = typeof(value)
    if t == "string" then
        return string.format("%q", value)
    elseif t == "Instance" then
        local ok, fullName = pcall(function() return value:GetFullName() end)
        return "Instance(" .. (ok and fullName or "?") .. ")"
    elseif t == "table" then
        if depth > 3 then return "{...}" end
        local parts = {}
        for k, v in pairs(value) do
            table.insert(parts, "[" .. serializeValue(k, depth + 1) .. "] = " .. serializeValue(v, depth + 1))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return t .. "(" .. tostring(value) .. ")"
end

local function valueContainsString(value, text, depth)
    depth = depth or 0
    if type(value) == "string" then return value == text end
    if type(value) == "table" and depth < 4 then
        for k, v in pairs(value) do
            if valueContainsString(k, text, depth + 1) or valueContainsString(v, text, depth + 1) then
                return true
            end
        end
    end
    return false
end

local function replaceString(value, from, to)
    if type(value) == "string" then
        return value == from and to or value
    elseif type(value) == "table" then
        local copy = {}
        for k, v in pairs(value) do
            copy[replaceString(k, from, to)] = replaceString(v, from, to)
        end
        return copy
    end
    return value
end

local function logInventoryEqCall(remoteName, method, args, results)
    local argParts = {}
    for i = 1, args.n do
        table.insert(argParts, serializeValue(args[i]))
    end
    local resultText = ""
    if results then
        local resultParts = {}
        for i = 1, results.n do
            table.insert(resultParts, serializeValue(results[i]))
        end
        resultText = " -> " .. (#resultParts > 0 and table.concat(resultParts, ", ") or "(ไม่มีค่าตอบกลับ)")
    end
    print(string.format("[KL-Fisher] 🔎 %s:%s(%s)%s", remoteName, method, table.concat(argParts, ", "), resultText))
end

-- ติดตั้งตอนต้องหยิบของจากกระเป๋าครั้งแรกเท่านั้น (ไม่ hook ตั้งแต่เริ่ม เพราะ Maru Hub เช็ค hook ตอนโหลด)
local inventoryEqHookInstalled = false
local function installInventoryEqHook()
    if inventoryEqHookInstalled then return end
    inventoryEqHookInstalled = true

    pcall(function()
        if not hookmetamethod or not getnamecallmethod or next(inventoryEqRemotes) == nil then return end
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local remoteName = inventoryEqRemotes[self]
            if remoteName then
                local method = getnamecallmethod()
                if method == "InvokeServer" or method == "FireServer" then
                    -- ห้ามเรียก method ของ Instance ก่อนส่งต่อ (จะทับชื่อ namecall) จึงทำแค่เก็บค่า
                    inventoryEqCallCount = inventoryEqCallCount + 1
                    local args = table.pack(...)
                    lastInventoryEqCall = { remote = self, remoteName = remoteName, method = method, args = args }
                    if method == "InvokeServer" then
                        local results = table.pack(oldNamecall(self, ...))
                        task.spawn(logInventoryEqCall, remoteName, method, args, results)
                        return table.unpack(results, 1, results.n)
                    end
                    task.spawn(logInventoryEqCall, remoteName, method, args, nil)
                end
            end
            return oldNamecall(self, ...)
        end)
    end)
end

-- เรียก InventoryEq ตรง ๆ ตามรูปแบบที่จำไว้ (เปลี่ยนแค่ชื่อไอเทม)
local function invokeInventoryEqFor(itemName)
    local template = inventoryEqTemplate
    if not template then return false end
    local args = {}
    for i = 1, template.args.n do
        args[i] = replaceString(template.args[i], template.itemName, itemName)
    end
    return (pcall(function()
        if template.method == "InvokeServer" then
            template.remote:InvokeServer(table.unpack(args, 1, template.args.n))
        else
            template.remote:FireServer(table.unpack(args, 1, template.args.n))
        end
    end))
end

local function findInventoryEquipButton(invFrame)
    for _, d in ipairs(invFrame:GetDescendants()) do
        if d:IsA("GuiButton") then
            local label = d:IsA("TextButton") and d.Text or ""
            if label == "" then
                local tl = d:FindFirstChildWhichIsA("TextLabel")
                label = tl and tl.Text or ""
            end
            label = string.lower(label)
            if string.find(label, "^%s*equip") or string.find(label, "สวมใส่", 1, true) or string.find(d.Name:lower(), "^equip") then
                return d
            end
        end
    end
    return nil
end

local function getInventoryButton()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local mainGui = pGui and pGui:FindFirstChild("MainGui")
    local baseFrame = mainGui and mainGui:FindFirstChild("BaseFrame")
    local buttonFrame = baseFrame and baseFrame:FindFirstChild("ButtonFrame")
    return buttonFrame and buttonFrame:FindFirstChild("InventoryButton")
end

-- เปิดกระเป๋าด้วยปุ่มของเกม (ให้เกมสร้าง/ผูกปุ่มไอเทม) คืนฟังก์ชันสำหรับปิดคืน
local function openInventoryTemporarily(invFrame)
    local invButton = getInventoryButton()
    local wasVisible = invFrame.Visible
    if not invButton or not fireGuiSignal(invButton, "MouseButton1Click") then
        return nil
    end
    task.wait(0.8)
    return function()
        -- ปุ่มนี้สลับเปิด/ปิด: ถ้าตอนแรกปิดอยู่ให้กดอีกทีเพื่อปิดคืน
        if not wasVisible and invFrame.Visible then
            task.wait(0.15) -- ปุ่มของเกมกันกดรัว 0.1 วินาที
            fireGuiSignal(invButton, "MouseButton1Click")
        end
    end
end

-- ใส่ดาบ/เบ็ดด้วย remote ตรง ๆ ไม่ต้องพึ่งปุ่มในกระเป๋า (ปุ่มกดไม่ติดบ่อย รอบ 14:52 กว่าจะติดใช้ 3 นาที) ลองตามลำดับ:
--   1) EtcFunction:InvokeServer("EquipWeapon", {WeaponName = ชื่อ, Type = "Primary"})  <- ที่เกมส่งตอนกดใส่เอง (ดักด้วย Cobalt)
--   2) Functions.InventoryEq:InvokeServer(ชื่อ) -> true                               <- จาก log จริง 14:55:21
local REMOTE_RETRY_COOLDOWN = 5
local remoteTriedAt = {}
-- ลองครบทุกวิธีแล้วไม่ได้ติดกันกี่รอบ (ต่อชื่อไอเทม) -> ใช้เว้นช่วงห่างขึ้น
-- จาก log 20:32: กลางไฟต์ Serpent เซิร์ฟเวอร์ไม่ยอมให้เปลี่ยนอาวุธ แต่บอทขอ Authentic Mace ซ้ำทุก ~4 วิ (2 remote สลับกัน)
local remoteFailCount = {}
local IN_FIGHT_RETRY_COOLDOWN = 60 -- กำลังสู้บอส: ลองครั้งละห่าง ๆ (ส่วนใหญ่ได้ตอนจบไฟต์ / ระหว่างไฟต์หลุดช่วงไม่โดนตี)
local IDLE_RETRY_COOLDOWN = 15

local function equipRetryCooldown(itemName)
    local fails = remoteFailCount[itemName] or 0
    if fails < 2 then return REMOTE_RETRY_COOLDOWN end
    if maruBossName ~= nil or isFightingBoss then return IN_FIGHT_RETRY_COOLDOWN end
    return IDLE_RETRY_COOLDOWN
end

local function getEquipRemoteAttempts(itemName)
    local attempts = {}
    local chest = ReplicatedStorage:FindFirstChild("Chest")
    local remotes = chest and chest:FindFirstChild("Remotes")
    local functions = remotes and remotes:FindFirstChild("Functions")
    local etcFunction = functions and functions:FindFirstChild("EtcFunction")
    if etcFunction then
        table.insert(attempts, {
            label = "EtcFunction.EquipWeapon",
            remote = etcFunction,
            args = { "EquipWeapon", { WeaponName = itemName, Type = "Primary" } },
        })
    end
    local inventoryEq = functions and functions:FindFirstChild("InventoryEq")
    if inventoryEq then
        table.insert(attempts, { label = "InventoryEq", remote = inventoryEq, args = { itemName } })
    end
    return attempts
end

local function equipViaRemote(itemName)
    if not itemName or itemName == "" then return nil end
    local owned = findOwnedTool(itemName)
    if owned then
        remoteFailCount[itemName] = nil
        return owned -- อยู่ในตัวแล้ว ห้ามส่งซ้ำ (อาจเป็นการถอดออก)
    end
    if remoteTriedAt[itemName] and os.clock() - remoteTriedAt[itemName] < equipRetryCooldown(itemName) then
        return nil
    end
    remoteTriedAt[itemName] = os.clock()
    -- เกิน 2 รอบแล้ว: ไม่ต้องพิมพ์ทุกวิธีที่ล้ม (log ท่วม) พิมพ์สรุปบรรทัดเดียวตอนท้ายแทน
    local quietLog = (remoteFailCount[itemName] or 0) >= 2

    -- จาก log 15:23: ขอใส่ดาบตอนยังถือเบ็ด/ยังอยู่ในสถานะตกปลา (4 วิหลังมินิเกม) เซิร์ฟเวอร์ตอบ nil ทุกครั้ง
    -- ส่วนรอบที่ได้ true (14:55) คือตอนเลิกตกปลาไปแล้ว -> เก็บเบ็ดออกจากมือ รอสถานะตกปลาหายก่อนค่อยขอ
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not isRodName(itemName) then
        local held = char and char:FindFirstChildOfClass("Tool")
        if hum and held and isRodName(held.Name) then
            hum:UnequipTools()
        end
        local waitStart = os.clock()
        while char and char.Parent and char:GetAttribute("Fishing") and os.clock() - waitStart < 4 do
            task.wait(0.1)
        end
    end

    local function describeState()
        local heldTool = char and char:FindFirstChildOfClass("Tool")
        local names = {}
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            for _, item in ipairs(backpack:GetChildren()) do
                if item:IsA("Tool") then table.insert(names, item.Name) end
            end
        end
        return string.format("ถืออยู่: %s | ตกปลาอยู่: %s | Backpack: [%s]",
            heldTool and heldTool.Name or "-",
            tostring(char and char:GetAttribute("Fishing")),
            table.concat(names, ", "))
    end

    for _, attempt in ipairs(getEquipRemoteAttempts(itemName)) do
        local ok, result = pcall(function()
            return attempt.remote:InvokeServer(table.unpack(attempt.args))
        end)
        if not ok then
            if not quietLog then
                warn(string.format("[KL-Fisher] ⚠️ %s('%s') error: %s", attempt.label, itemName, tostring(result)))
            end
        else
            local tool = waitForOwnedTool(itemName, 3)
            if tool then
                remoteFailCount[itemName] = nil
                print(string.format("[KL-Fisher] 🎒 ใส่ '%s' ผ่าน %s สำเร็จ (ตอบ %s)", itemName, attempt.label, tostring(result)))
                return tool
            end
            if not quietLog then
                warn(string.format("[KL-Fisher] ⚠️ %s('%s') ตอบ %s แต่ของไม่เข้า Backpack -> ลองวิธีถัดไป (%s)", attempt.label, itemName, tostring(result), describeState()))
            end
        end
    end
    remoteFailCount[itemName] = (remoteFailCount[itemName] or 0) + 1
    if remoteFailCount[itemName] >= 2 then
        warn(string.format("[KL-Fisher] ⏸️ ใส่ '%s' ไม่ได้ %d รอบติด%s -> พัก %d วิ ค่อยลองใหม่",
            itemName, remoteFailCount[itemName],
            (maruBossName ~= nil or isFightingBoss) and " (กำลังสู้บอส เซิร์ฟเวอร์ไม่ให้เปลี่ยนอาวุธ)" or "",
            equipRetryCooldown(itemName)))
    end
    return nil
end

-- หยิบไอเทมหมวดดาบ/เบ็ดจากกระเป๋าเกมเข้า Backpack คืนค่า Tool ที่ได้ (หรือ nil)
-- exactName: ชื่อไอเทมเป๊ะ ๆ ถ้ารู้ -> ส่ง InventoryEq ตรงก่อน ไม่ได้ค่อยกดปุ่มในกระเป๋า
local function equipFromGameInventory(matchName, label, exactName)
    if exactName then
        local tool = equipViaRemote(exactName)
        if tool then
            inventoryFailedAt[label] = nil
            return tool
        end
        -- มี remote ให้ใช้แล้ว ไม่ต้องไปกดปุ่มในกระเป๋า (เปิด/ปิดหน้ากระเป๋าบนจอกลางไฟต์ และกดซ้ำอาจถอดของออก)
        -- ไม่ได้ = เซิร์ฟเวอร์ยังไม่ให้ใส่ (เช่นกำลังสู้อยู่) -> รอลองใหม่รอบหน้า
        if #getEquipRemoteAttempts(exactName) > 0 then
            return nil
        end
    end
    if inventoryFailedAt[label] and os.clock() - inventoryFailedAt[label] < INVENTORY_RETRY_COOLDOWN then
        return nil
    end
    installInventoryEqHook()

    local invFrame = getInventoryFrame()
    local swordList = invFrame and invFrame:FindFirstChild("ScrollingFrameSwords")
    if not swordList then
        warn("[KL-Fisher] ⚠️ ไม่พบหน้ากระเป๋าเกม (MainGui.StarterFrame.Inventory_Frame.ScrollingFrameSwords)")
        inventoryFailedAt[label] = os.clock()
        return nil
    end

    local function findItemButton()
        for _, btn in ipairs(swordList:GetChildren()) do
            if btn:IsA("GuiButton") and matchName(btn.Name) then
                return btn
            end
        end
        return nil
    end

    -- จาก log: รายการไอเทมในกระเป๋าอาจยังว่างจนกว่าจะเปิดกระเป๋าครั้งแรก -> หาไม่เจอให้เปิดกระเป๋าแล้วหาใหม่
    local closeInventory = nil
    local itemBtn = findItemButton()
    if not itemBtn then
        closeInventory = openInventoryTemporarily(invFrame)
        itemBtn = findItemButton()
    end
    if not itemBtn then
        if closeInventory then closeInventory() end
        warn(string.format("[KL-Fisher] ⚠️ ไม่พบ '%s' ในกระเป๋าเกม (หมวดดาบ มีอยู่: %d ชิ้น)", label, #swordList:GetChildren()))
        inventoryFailedAt[label] = os.clock()
        return nil
    end

    -- อยู่ในตัวแล้ว ห้ามกดซ้ำ (กดซ้ำอาจเป็นการถอดออก)
    local owned = findOwnedTool(itemBtn.Name)
    if owned then
        if closeInventory then closeInventory() end
        return owned
    end

    local requestSent = false

    -- กดปุ่มแล้วดูว่าเกมส่ง InventoryEq จริงไหม: ถ้าส่งแล้วให้รอผล ห้ามกดซ้ำ (กดซ้ำอาจเป็นการถอดออก)
    local function fireAndWait(btn, signalName)
        local before = inventoryEqCallCount
        if not fireGuiSignal(btn, signalName) then return nil end
        local tool = waitForOwnedTool(itemBtn.Name, 0.6)
        if tool then return tool end
        if inventoryEqCallCount > before then
            requestSent = true
            return waitForOwnedTool(itemBtn.Name, 3)
        end
        return nil
    end

    local function tryClickItem()
        for _, signalName in ipairs(INVENTORY_CLICK_SIGNALS) do
            -- ปุ่มอาจถูกสร้างใหม่ตอนเปิดกระเป๋า ถ้าตัวเก่าถูกลบไปแล้วให้หาใหม่
            local btn = itemBtn.Parent and itemBtn or swordList:FindFirstChild(itemBtn.Name)
            if btn then
                local tool = fireAndWait(btn, signalName)
                if tool then return tool end
                if requestSent then return nil end
                -- บางเวอร์ชันกดไอเทมแล้วต้องกดปุ่ม Equip อีกที
                local equipBtn = findInventoryEquipButton(invFrame)
                if equipBtn then
                    tool = fireAndWait(equipBtn, signalName)
                    if tool then return tool end
                    if requestSent then return nil end
                end
            end
        end
        return nil
    end

    -- 1. รู้รูปแบบคำขอแล้ว -> ส่งตรงหาเซิร์ฟเวอร์เลย ไม่ต้องกด GUI
    local tool = nil
    if inventoryEqTemplate and invokeInventoryEqFor(itemBtn.Name) then
        requestSent = true
        tool = waitForOwnedTool(itemBtn.Name, 3)
    end

    -- 2. ยังไม่รู้รูปแบบ -> กดปุ่มไอเทม
    -- จาก log: กดตอนยังไม่เคยเปิดกระเป๋า เกมไม่ยิง InventoryEq เลย (ปุ่มยังไม่ถูกผูก)
    -- -> ถ้ากดแล้วเกมไม่ส่งคำขอ ให้เปิดกระเป๋าก่อนแล้วกดใหม่ จากนั้นปิดคืน
    if not tool and not requestSent then
        tool = tryClickItem()
    end
    if not tool and not requestSent and not closeInventory then
        closeInventory = openInventoryTemporarily(invFrame)
        if closeInventory then
            tool = tryClickItem()
        end
    end
    if closeInventory then closeInventory() end

    if tool then
        print(string.format("[KL-Fisher] 🎒 หยิบ '%s' จากกระเป๋าเกมเข้ามือสำเร็จ", tool.Name))
        inventoryFailedAt[label] = nil
        -- จำรูปแบบคำขอที่ได้ผล (ต้องมีชื่อไอเทมอยู่ในคำขอ ถึงจะเปลี่ยนชื่อไปใช้กับไอเทมอื่นได้)
        local call = lastInventoryEqCall
        if not inventoryEqTemplate and call and valueContainsString(call.args, itemBtn.Name) then
            inventoryEqTemplate = { remote = call.remote, method = call.method, args = call.args, itemName = itemBtn.Name }
            print(string.format("[KL-Fisher] 🧠 จำรูปแบบ %s:%s ไว้แล้ว ครั้งต่อไปจะส่งตรงไม่ต้องกดปุ่ม", call.remoteName, call.method))
        end
        return tool
    end

    if requestSent then
        warn(string.format("[KL-Fisher] ⚠️ ส่งคำขอใส่ '%s' แล้ว แต่เซิร์ฟเวอร์ไม่ให้ใส่ (ดูผลตอบกลับใน log 🔎 ด้านบน | ลองใหม่ใน %d วินาที)", itemBtn.Name, INVENTORY_RETRY_COOLDOWN))
    else
        warn(string.format("[KL-Fisher] ⚠️ กดหยิบ '%s' แล้วเกมไม่ส่งคำขอ InventoryEq เลย (ปุ่มไม่ทำงาน | ลองใหม่ใน %d วินาที)", itemBtn.Name, INVENTORY_RETRY_COOLDOWN))
    end
    inventoryFailedAt[label] = os.clock()
    return nil
end

local function equipRod()
    -- หากกำลังต่อสู้บอสอยู่ (เราเองหรือ Maru Hub) หรือบอสกำลังจะเกิด ล็อคห้ามสลับกลับมาถือเบ็ดตกปลา 100%!
    if isFightingBoss or maruBossName or os.clock() < bossIncomingUntil then
        return false
    end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    
    if not hum or hum.Health <= 0 then
        local waitChar = tick()
        while tick() - waitChar < 5 do
            char = LocalPlayer.Character
            hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then break end
            task.wait(0.3)
        end
    end
    if not hum or hum.Health <= 0 then return false end
    
    local currentTool = char:FindFirstChildOfClass("Tool")
    if currentTool and isRodName(currentTool.Name) then
        lastRodName = currentTool.Name
        return true
    end

    local rod = getRodTool()
    if not rod then
        for _ = 1, 3 do
            task.wait(0.3)
            rod = getRodTool()
            if rod then break end
        end
    end

    -- เบ็ดไม่อยู่ใน Backpack = ดาบเข้าไปแทนช่อง (เช่นหลังสู้บอส) -> หยิบเบ็ดกลับจากกระเป๋าเกม
    if not rod then
        rod = equipFromGameInventory(function(itemName)
            if lastRodName then
                return normalizeToolName(itemName) == normalizeToolName(lastRodName)
            end
            return isRodName(itemName)
        end, lastRodName or "เบ็ดตกปลา", lastRodName or DEFAULT_ROD_NAME)
    end
    
    if rod then
        hum:UnequipTools()
        task.wait(0.15)
        hum:EquipTool(rod)
        task.wait(0.2)
        print(string.format("[KL-Fisher] 🎣 สลับถือเบ็ดตกปลา: %s", rod.Name))
        return true
    else
        return false
    end
end

local function equipSword()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    
    local combatTools = getCombatTools()
    local preferredName = CONFIG.PREFERRED_SWORD or ""
    local prefNorm = normalizeToolName(preferredName)
    
    -- 1. ค้นหาอาวุธหลักตามที่เลือกไว้ใน CONFIG.PREFERRED_SWORD
    local chosenSword = nil
    if preferredName ~= "" and preferredName ~= "Any Sword" then
        for _, tool in ipairs(combatTools) do
            local tName = tool.Name:lower()
            local tNorm = normalizeToolName(tool.Name)
            if string.find(tName, preferredName:lower()) 
                or (prefNorm ~= "" and (string.find(tNorm, prefNorm) or string.find(prefNorm, tNorm))) then
                chosenSword = tool
                break
            end
        end
        
        -- ไม่อยู่ใน Backpack = ยังอยู่ในกระเป๋าเกม (ช่องดาบถูกเบ็ดใช้อยู่) -> หยิบออกมาจากกระเป๋าเกม
        if not chosenSword and prefNorm ~= "" then
            chosenSword = equipFromGameInventory(function(itemName)
                return string.find(normalizeToolName(itemName), prefNorm, 1, true) ~= nil
            end, preferredName, preferredName)
            if chosenSword then
                combatTools = getCombatTools()
            end
        end
    end
    
    -- 2. ถ้าไม่พบอาวุธหลัก ให้เลือกดาบเล่มใดก็ได้ที่มีในกระเป๋า
    if not chosenSword then
        for _, tool in ipairs(combatTools) do
            if isSwordTool(tool) then
                chosenSword = tool
                break
            end
        end
    end
    
    -- 3. ถ้าไม่มีดาบเลย ให้เลือกอาวุธต่อสู้ใดๆ (เช่น หมัด / Gale Fist)
    local toEquip = chosenSword or combatTools[1]
    
    -- ตรวจสอบว่าถืออาวุธนี้อยู่แล้วหรือไม่
    local currentTool = char:FindFirstChildOfClass("Tool")
    if currentTool and toEquip and currentTool == toEquip then
        return
    end
    
    -- ถอดเบ็ดตกปลาออกและถืออาวุธต่อสู้
    hum:UnequipTools()
    task.wait(0.12)
    
    if toEquip then
        hum:EquipTool(toEquip)
        task.wait(0.18)
        if chosenSword and chosenSword == toEquip and preferredName ~= "" and preferredName ~= "Any Sword" then
            print(string.format("[KL-Fisher] ⚔️ สลับถืออาวุธหลัก: %s (ตามการตั้งค่า)", toEquip.Name))
        else
            local availList = {}
            for _, t in ipairs(combatTools) do table.insert(availList, t.Name) end
            warn(string.format("[KL-Fisher] ⚔️ สลับถืออาวุธต่อสู้: %s (ไม่พบ '%s' ในกระเป๋า | มีในกระเป๋า: [%s])",
                toEquip.Name,
                preferredName,
                #availList > 0 and table.concat(availList, ", ") or "ไม่มีอาวุธอื่น"
            ))
        end
    else
        warn("[KL-Fisher] ⚠️ ไม่พบอาวุธต่อสู้ใดๆ ในตัวละครหรือกระเป๋า Backpack เลย!")
    end
end

----------------------------------------------------------------------
-- 9. COMBAT & BULLETPROOF AIM LOCK (ป้องกัน C stack overflow 100%)
----------------------------------------------------------------------
local noclipConn = nil
local function setNoclip(enabled)
    if enabled and CONFIG.NOCLIP_COMBAT then
        if not noclipConn then
            noclipConn = RunService.Stepped:Connect(function()
                local char = LocalPlayer.Character
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end)
        end
    else
        if noclipConn then
            noclipConn:Disconnect()
            noclipConn = nil
        end
    end
end

local function getTargetPart(bossModel)
    if not bossModel then return nil end
    local ok, part = pcall(function()
        return bossModel:FindFirstChild("HumanoidRootPart")
            or bossModel.PrimaryPart
            or bossModel:FindFirstChild("Head")
            or bossModel:FindFirstChild("UpperTorso")
            or bossModel:FindFirstChild("Torso")
            or bossModel:FindFirstChildWhichIsA("BasePart")
    end)
    return ok and part or nil
end

local currentCombatTarget = nil
local aimLockConn = nil

local function startAimLock(targetModel)
    if not CONFIG.AIM_LOCK then return end
    currentCombatTarget = targetModel
    if not aimLockConn then
        aimLockConn = RunService.RenderStepped:Connect(function()
            if not currentCombatTarget or not currentCombatTarget.Parent then return end
            local targetPart = getTargetPart(currentCombatTarget)
            if not targetPart then return end
            
            local targetPos = targetPart.Position
            local targetCF = CFrame.new(targetPos)
            _G.MouseHit = targetCF
            _G.MouseHitMobile = targetCF
            
            local camera = workspace.CurrentCamera
            if camera then
                camera.CFrame = CFrame.new(camera.CFrame.Position, targetPos)
                local screenPoint, onScreen = camera:WorldToViewportPoint(targetPos)
                if onScreen then
                    pcall(function()
                        VirtualInputManager:SendMouseMoveEvent(screenPoint.X, screenPoint.Y, game)
                    end)
                end
            end
        end)
    end
end

local function stopAimLock()
    currentCombatTarget = nil
    if aimLockConn then
        aimLockConn:Disconnect()
        aimLockConn = nil
    end
end

-- ติดตั้งตอนเราตีบอสเองครั้งแรกเท่านั้น (ไม่ hook ตั้งแต่เริ่ม เพราะ Maru Hub เช็ค hook ตอนโหลด)
local aimHookInstalled = false
local function installAimHook()
if aimHookInstalled then return end
aimHookInstalled = true
pcall(function()
    if not hookmetamethod then return end
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if checkcaller() or not currentCombatTarget then
            return oldIndex(self, key)
        end
        
        if key ~= "Hit" and key ~= "Target" then
            return oldIndex(self, key)
        end
        
        local isPlayerMouse = false
        pcall(function()
            local myMouse = LocalPlayer and LocalPlayer:GetMouse()
            if self == myMouse or (typeof(self) == "Instance" and self:IsA("Mouse")) then
                isPlayerMouse = true
            end
        end)
        
        if isPlayerMouse then
            local targetModel = currentCombatTarget
            local hasParent = false
            pcall(function()
                hasParent = (oldIndex(targetModel, "Parent") ~= nil)
            end)
            
            if hasParent then
                local root = getTargetPart(targetModel)
                if root then
                    if key == "Hit" then
                        return CFrame.new(root.Position)
                    elseif key == "Target" then
                        return root
                    end
                end
            end
        end
        
        return oldIndex(self, key)
    end)
end)
end

local function pressSkillKey(keyCode)
    pcall(function()
        if currentCombatTarget and currentCombatTarget.Parent then
            local root = getTargetPart(currentCombatTarget)
            if root then
                _G.MouseHit = CFrame.new(root.Position)
                _G.MouseHitMobile = CFrame.new(root.Position)
            end
        end
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.06)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

local ALL_SKILL_KEYS = {
    Enum.KeyCode.E,
    Enum.KeyCode.Z,
    Enum.KeyCode.X,
    Enum.KeyCode.C,
    Enum.KeyCode.V,
    Enum.KeyCode.B
}

local hakiAppliedChar = nil

local function ensureHaki()
    if not CONFIG.AUTO_BUSO_HAKI then return end
    local char = LocalPlayer.Character
    if not char then return end
    if char:GetAttribute("Haki") or char:GetAttribute("Buso") then return end
    -- ไม่พบ attribute สถานะฮาคิในเกม -> กด J ครั้งเดียวต่อตัวละคร (เกิดใหม่ค่อยกดใหม่)
    -- ถ้ากดทุกลูป ฮาคิจะเปิด-ปิดสลับกันรัว ๆ
    if hakiAppliedChar == char then return end
    hakiAppliedChar = char
    pressSkillKey(Enum.KeyCode.J)
    task.wait(0.2)
end

local function attackTarget(bossModel)
    if not CONFIG.AUTO_ATTACK_BOSS then return end
    if not bossModel or not bossModel.Parent then return end
    local humanoid = bossModel:FindFirstChildOfClass("Humanoid") or bossModel:WaitForChild("Humanoid", 4)
    if not humanoid or humanoid.Health <= 0 then return end

    -- ล็อคสถานะต่อสู้บอสทันที (ป้องกันไม่ให้ equipRod สลับถือเบ็ดตกปลาเด็ดขาด)
    isFightingBoss = true
    currentFightingBossName = bossModel.Name

    local hpText = (humanoid.MaxHealth > 0) and string.format("%d/%d", math.floor(humanoid.Health), math.floor(humanoid.MaxHealth)) or "N/A"
    print(string.format("[KL-Fisher] ⚔️ ล็อคเป้าบอส '%s' (HP: %s)! ลอยโจมตีมุมสูง %d studs ทันที!", bossModel.Name, hpText, CONFIG.ATTACK_DISTANCE))
    
    if CONFIG.AIM_LOCK then installAimHook() end
    setNoclip(true)
    equipSword()
    ensureHaki()
    startAimLock(bossModel)

    local root = getTargetPart(bossModel)
    -- จับเวลาจริงด้วย os.clock() (ลูปจริงช้ากว่า ATTACK_DELAY มากเพราะกดสกิล/สลับอาวุธ)
    local lastWeaponCycle = os.clock()
    local lastSkillBurst = 0
    local currentToolIndex = 1
    
    while bossModel and bossModel.Parent and humanoid and humanoid.Health > 0 and CONFIG.AUTO_ATTACK_BOSS do
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local myHum = char and char:FindFirstChildOfClass("Humanoid")
        
        if not myHum or myHum.Health <= 0 then
            if CONFIG.DEATH_RECOVERY then
                warn("[KL-Fisher] ⚠️ ตัวละครเสียชีวิตขณะสู้บอส! กำลังรอเกิดใหม่...")
                stopAimLock()
                setNoclip(false)
                repeat
                    task.wait(0.5)
                    char = LocalPlayer.Character
                    myHum = char and char:FindFirstChildOfClass("Humanoid")
                until myHum and myHum.Health > 0
                task.wait(2)
                
                if bossModel and bossModel.Parent and humanoid and humanoid.Health > 0 then
                    setNoclip(true)
                    equipSword()
                    ensureHaki()
                    startAimLock(bossModel)
                    root = getTargetPart(bossModel)
                else
                    break
                end
            else
                break
            end
        end
        
        char = LocalPlayer.Character
        hrp = char and char:FindFirstChild("HumanoidRootPart")
        myHum = char and char:FindFirstChildOfClass("Humanoid")
        
        if char and hrp and myHum and myHum.Health > 0 and root and root.Parent then
            local attackOffset = Vector3.new(0, CONFIG.ATTACK_DISTANCE, 14)
            local targetCFrame = CFrame.new(root.Position + attackOffset, root.Position)
            hrp.Velocity = Vector3.zero
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
            hrp.CFrame = targetCFrame
            
            ensureHaki()
            
            -- ป้องกันไม่ให้ตัวละครเผลอถือเบ็ดตกปลาในขณะที่กำลังสู้บอส
            local activeTool = char:FindFirstChildOfClass("Tool")
            if not activeTool or not isCombatTool(activeTool) then
                equipSword()
                activeTool = char:FindFirstChildOfClass("Tool")
            end
            
            if CONFIG.CYCLE_WEAPONS and os.clock() - lastWeaponCycle >= CONFIG.WEAPON_CYCLE_DELAY then
                local tools = getCombatTools()
                if #tools > 1 then
                    lastWeaponCycle = os.clock()
                    currentToolIndex = (currentToolIndex % #tools) + 1
                    local nextTool = tools[currentToolIndex]
                    if nextTool and myHum and isCombatTool(nextTool) then
                        myHum:EquipTool(nextTool)
                    end
                end
            end

            if CONFIG.AUTO_SPAM_SKILLS and os.clock() - lastSkillBurst >= 0.3 then
                lastSkillBurst = os.clock()
                for _, key in ipairs(ALL_SKILL_KEYS) do
                    pressSkillKey(key)
                end
            end
            
            activeTool = char:FindFirstChildOfClass("Tool")
            if activeTool and isCombatTool(activeTool) then
                activeTool:Activate()
            end
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.zero)
        else
            task.wait(0.3)
            root = getTargetPart(bossModel)
            humanoid = bossModel:FindFirstChildOfClass("Humanoid")
        end
        task.wait(CONFIG.ATTACK_DELAY)
    end
    
    stopAimLock()
    setNoclip(false)
    
    local endReason = "กำจัดสำเร็จ"
    if not (bossModel and bossModel.Parent) then
        endReason = "บอสหายไปจากเซิร์ฟเวอร์ (Despawned / ถูกกำจัด)"
    elseif not humanoid or humanoid.Health <= 0 then
        endReason = "เลือดบอสหมด (HP <= 0) ชนะแล้ว!"
    elseif not CONFIG.AUTO_ATTACK_BOSS then
        endReason = "ปิดโหมดโจมตีบอส"
    end
    
    print(string.format("[KL-Fisher] 🏆 จบการต่อสู้กับบอส: %s (%s)", tostring(bossModel and bossModel.Name), endReason))
    
    isFightingBoss = false
    currentFightingBossName = nil
    clearSignal()
    task.wait(1.5)
    equipRod()
end

----------------------------------------------------------------------
-- 10. AUTO FISHING & MINIGAME SOLVER (พร้อม Watchdog)
----------------------------------------------------------------------
local isSolvingFishing = false
local currentMinigameConn = nil
local lastMinigameStart = 0

task.spawn(function()
    while true do
        task.wait(2)
        if isSolvingFishing and (tick() - lastMinigameStart > CONFIG.MINIGAME_TIMEOUT) then
            print("[KL-AutoFish] ⚠️ มินิเกมนานผิดปกติ รีเซ็ตสถานะอัตโนมัติ")
            if currentMinigameConn then
                currentMinigameConn:Disconnect()
                currentMinigameConn = nil
            end
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end)
            isSolvingFishing = false
        end
    end
end)

local function ensurePopupContainer()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end
    if not playerGui:FindFirstChild("Popup") then
        local restoredPopup = Instance.new("ScreenGui")
        restoredPopup.Name = "Popup"
        restoredPopup.ResetOnSpawn = false
        
        local frame = Instance.new("Frame")
        frame.Name = "Frame"
        frame.Visible = false
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 1
        frame.Parent = restoredPopup
        
        local clickFrame = Instance.new("TextButton")
        clickFrame.Name = "ClickFrame"
        clickFrame.Size = UDim2.new(1, 0, 1, 0)
        clickFrame.BackgroundTransparency = 1
        clickFrame.Text = ""
        clickFrame.Parent = frame
        
        restoredPopup.Parent = playerGui
        print("[KL-Fisher] 🛡️ ตรวจพบ Popup หายไป -> ทำการกู้คืน PlayerGui.Popup ทันที (แก้ Infinite Yield)")
    end
end

local watchedPopups = setmetatable({}, { __mode = "k" })

local function handlePopup(popupGui)
    -- Popup เป็น GUI ถาวร (ไม่ถูกสร้างใหม่) ChildAdded จึงไม่ยิงซ้ำ -> ต้องดักตอน Frame ถูกเปิดขึ้นมาแทน
    if not watchedPopups[popupGui] then
        watchedPopups[popupGui] = true
        local frame = popupGui:FindFirstChild("Frame")
        if frame then
            frame:GetPropertyChangedSignal("Visible"):Connect(function()
                if frame.Visible then
                    handlePopup(popupGui)
                end
            end)
        end
    end

    if not CONFIG.AUTO_CLOSE_POPUP then return end
    task.delay(0.4, function()
        if not popupGui or not popupGui.Parent or not CONFIG.AUTO_CLOSE_POPUP then return end
        -- 1. จำลองการคลิกปิดตามระบบของเกม King Legacy
        -- (ห้ามคลิกระหว่างมินิเกม: คลิกซ้ายคือปุ่มบังคับแถบตกปลา)
        if not isSolvingFishing then
            pcall(function()
                VirtualUser:CaptureController()
                local cam = workspace.CurrentCamera
                local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
                VirtualUser:ClickButton1(Vector2.new(vp.X / 2, vp.Y / 2))
            end)
        end

        -- 2. ห้ามใช้ :Destroy() กับตัว Popup เด็ดขาด! เพราะสคริปต์เกม (BeckEvent) รอ WaitForChild("Popup") อยู่
        -- ให้ทำการซ่อน Frame และปิด Enabled แทนเพื่อไม่ให้เกิด Infinite Yield
        task.wait(0.2)
        pcall(function()
            local frame = popupGui:FindFirstChild("Frame")
            if frame then
                frame.Visible = false
            end
            if popupGui:IsA("ScreenGui") then
                popupGui.Enabled = false
            end
        end)
    end)
end

-- ปิด Auto Close Popup แล้ว ให้ Popup กลับมาแสดงตามปกติ
local function restorePopups()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local popupGui = playerGui and playerGui:FindFirstChild("Popup")
    if popupGui and popupGui:IsA("ScreenGui") then
        pcall(function() popupGui.Enabled = true end)
    end
end

local function setupAutoFishingSolver()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    
    -- กู้คืน Popup ทันทีหากก่อนหน้านี้เคยถูกลบไป
    ensurePopupContainer()
    
    -- (Popup ที่มีอยู่แล้วจะถูกจัดการโดย handleGui -> handlePopup ด้านล่าง ตามสถานะปุ่ม Auto Close Popup)
    -- ลบ FishingUI ค้างเฉพาะตอนเราแก้มินิเกมเอง (ไม่งั้นจะไปลบมินิเกมที่ Maru Hub กำลังเล่นอยู่)
    if CONFIG.AUTO_SOLVE_MINIGAME then
        for _, oldGui in ipairs(playerGui:GetChildren()) do
            if oldGui.Name == "FishingUI" then
                pcall(function() oldGui:Destroy() end)
            end
        end
    end
    
    -- BYPASS มินิเกม (อ่านจาก Fishing() ใน FOUND_Fishing_Controller_PeodizEffects.lua):
    --   progress (u57) เป็น local ที่แชร์กับ closure UpdateProgressBar ของเกม
    --   ลูปมินิเกมทำ u57 = clamp(u57 + delta, 0, 100) แล้ว break ทันทีเมื่อ u57 >= 100 (= ชนะ)
    --   -> หา UpdateProgressBar ของรอบนี้ใน GC แล้วตั้ง upvalue progress ให้เกินร้อย เกมจะจบเป็นชนะเอง
    local function findMinigameProgress(fishingGui)
        if not getgc or not debug.getupvalues or not debug.setupvalue then return nil end
        local ok, found = pcall(function()
            for _, fn in ipairs(getgc()) do
                if type(fn) == "function" then
                    local nameOk, fnName = pcall(debug.info, fn, "n")
                    if nameOk and fnName == "UpdateProgressBar" then
                        local progressIdx, isThisRound = nil, false
                        for idx, value in pairs(debug.getupvalues(fn)) do
                            if type(value) == "number" then
                                progressIdx = idx
                            elseif typeof(value) == "Instance" and value:IsDescendantOf(fishingGui) then
                                isThisRound = true -- ProgressBar ของมินิเกมรอบนี้ (ไม่ใช่รอบเก่าที่ค้างใน GC)
                            end
                        end
                        if progressIdx and isThisRound then
                            return { fn = fn, idx = progressIdx }
                        end
                    end
                end
            end
            return nil
        end)
        return ok and found or nil
    end

    local function bypassMinigame(fishingGui)
        local progress = nil
        for _ = 1, 5 do
            if not fishingGui.Parent then return end
            progress = findMinigameProgress(fishingGui)
            if progress then break end
            task.wait(0.2) -- เกมสร้าง UpdateProgressBar หลัง UI ขึ้นเล็กน้อย
        end
        if not progress then
            warn("[KL-AutoFish] ⚠️ bypass มินิเกมไม่ได้ (executor ไม่มี getgc/debug.setupvalue หรือหา progress ไม่เจอ) -> ใช้วิธีบังคับแถบแทน")
            return
        end

        local winAt = lastMinigameStart + (tonumber(CONFIG.MINIGAME_WIN_DELAY) or 0)
        while fishingGui.Parent and tick() < winAt do
            task.wait(0.1)
        end
        if not fishingGui.Parent then return end
        print("⚡ [KL-AutoFish] bypass มินิเกม: ตั้ง progress เต็ม -> ชนะทันที")
        -- ตั้งซ้ำทุกเฟรมจน UI หาย (กันเกมคำนวณทับในเฟรมเดียวกัน)
        local setStart = tick()
        while fishingGui.Parent and tick() - setStart < 3 do
            pcall(debug.setupvalue, progress.fn, progress.idx, 1e6)
            RunService.Heartbeat:Wait()
        end
    end

    local function handleGui(child)
        if child.Name == "FishingUI" and CONFIG.AUTO_SOLVE_MINIGAME then
            isSolvingFishing = true
            lastMinigameStart = tick()
            print("🎣 [KL-AutoFish] ตรวจพบมินิเกมตกปลา! กำลังแก้เกมให้อัตโนมัติ 100%...")
            if CONFIG.MINIGAME_INSTANT_WIN then
                task.spawn(bypassMinigame, child)
            end
            
            local bg = child:WaitForChild("FishingBackground", 5)
            if not bg then
                isSolvingFishing = false
                return
            end
            
            local bar = bg:WaitForChild("FishingBar", 3)
            local fish = bg:WaitForChild("FishLabel", 3)

            if not bar or not fish then
                isSolvingFishing = false
                return
            end

            -- ปลารอบนี้คือ WhirlpoolBeast ไหม (เกมตั้งไอคอนก่อนเอา UI ขึ้นจอ) -> ถ้าใช่ Serpent จะเกิดหลังจบมินิเกม
            local isWhirlpoolBeast = false
            pcall(function()
                local icon = fish:FindFirstChild("Icon")
                local iconColor = icon and icon:FindFirstChild("IconColor")
                isWhirlpoolBeast = iconColor ~= nil and iconColor.Image == WHIRLPOOL_BEAST_ICON
            end)
            if isWhirlpoolBeast then
                bossIncomingUntil = os.clock() + BOSS_INCOMING_TIMEOUT
                print("🐉 [KL-AutoFish] ตกได้ WhirlpoolBeast -> Serpent กำลังจะเกิด (จะหยิบดาบทันทีที่จบมินิเกม ก่อนเข้าไฟต์)")
            end
            
            if currentMinigameConn then
                currentMinigameConn:Disconnect()
                currentMinigameConn = nil
            end
            
            currentMinigameConn = RunService.RenderStepped:Connect(function()
                if not child.Parent or not bar.Parent or not fish.Parent then
                    if currentMinigameConn then
                        currentMinigameConn:Disconnect()
                        currentMinigameConn = nil
                    end
                    pcall(function()
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                    end)
                    isSolvingFishing = false
                    print("🎉 [KL-AutoFish] ชนะมินิเกมตกปลาสำเร็จ 100%!")
                    if isWhirlpoolBeast and onWhirlpoolBeastCaught then
                        task.spawn(onWhirlpoolBeastCaught)
                    end
                    return
                end
                
                local barCenter = bar.AbsolutePosition.X + (bar.AbsoluteSize.X / 2)
                local fishCenter = fish.AbsolutePosition.X + (fish.AbsoluteSize.X / 2)
                local diff = barCenter - fishCenter
                fish.Position = fish.Position + UDim2.new(0, diff, 0, 0)
                
                if bar.Position.X.Offset < -30 then
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                elseif bar.Position.X.Offset > 30 then
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                end
            end)
        elseif child.Name == "Popup" then
            handlePopup(child)
        end
    end
    
    playerGui.ChildAdded:Connect(handleGui)
    for _, child in ipairs(playerGui:GetChildren()) do
        handleGui(child)
    end
end

----------------------------------------------------------------------
-- 10.5 MARU HUB COMPANION (AUTO_ATTACK_BOSS ปิด: ให้ Maru Hub ตีบอสเอง)
----------------------------------------------------------------------
-- ดาบกับเบ็ดใช้ช่องเดียวกัน ตอนตกปลาเบ็ดอยู่ในช่อง -> Maru (SelectWeapon = Sword&Fruit) ไม่มีดาบให้ใช้
-- บอสเกิด: หยิบดาบหลักจากกระเป๋าเกมขึ้นมาถือรอ (โหมดพร้อมตี) แล้วให้ Maru ตีต่อ
local swordReadyForBoss = false

local function findOwnedToolMatching(matchFn)
    local containers = {}
    if LocalPlayer.Character then table.insert(containers, LocalPlayer.Character) end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then table.insert(containers, backpack) end
    for _, container in ipairs(containers) do
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and matchFn(item.Name) then
                return item
            end
        end
    end
    return nil
end

-- เรียกซ้ำได้ทุกรอบระหว่างบอสยังอยู่: ถ้าหยิบไม่สำเร็จจะลองใหม่เอง (equipFromGameInventory คุมคูลดาวน์ 60 วิ)
-- ถือดาบให้แค่ครั้งแรก หลังจากนั้นปล่อยให้ Maru สลับดาบ/ผลเองตามปกติ
local function ensureSwordReady()
    local preferredName = CONFIG.PREFERRED_SWORD or ""
    local prefNorm = normalizeToolName(preferredName)
    if prefNorm == "" or preferredName == "Any Sword" then return end

    local function isPreferred(itemName)
        return string.find(normalizeToolName(itemName), prefNorm, 1, true) ~= nil
    end

    -- เคยถือแล้ว และดาบยังอยู่กับตัว (มือหรือ Backpack) -> ไม่ต้องทำอะไร ปล่อย Maru สลับดาบ/ผลเอง
    -- ดาบหายไปแล้ว (เช่นระหว่างรอบอส บอทสลับกลับไปถือเบ็ด) -> หยิบใหม่ ไม่งั้น Maru ตีทั้งไฟต์โดยไม่มีดาบ
    if swordReadyForBoss and findOwnedToolMatching(isPreferred) then return end
    swordReadyForBoss = false

    local sword = findOwnedToolMatching(isPreferred) or equipFromGameInventory(isPreferred, preferredName, preferredName)
    if not sword then return end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    if sword.Parent ~= char then
        hum:EquipTool(sword)
    end
    swordReadyForBoss = true
    print(string.format("[KL-Fisher] ⚔️ ถือ '%s' แล้ว -> โหมดพร้อมตี (ให้ Maru Hub ตีต่อ)", sword.Name))
end

-- บอสหายแล้ว: หยิบเบ็ดกลับเข้า Backpack ให้ Maru ตกปลา/เรียกน้ำวนต่อได้ (ไม่ถือเอง)
local function restoreRodForMaru()
    if not CONFIG.RESTORE_ROD_AFTER_BOSS then return end
    if findOwnedToolMatching(isRodName) then return end
    equipFromGameInventory(function(itemName)
        if lastRodName then
            return normalizeToolName(itemName) == normalizeToolName(lastRodName)
        end
        return isRodName(itemName)
    end, lastRodName or "เบ็ดตกปลา", lastRodName or DEFAULT_ROD_NAME)
end

-- จาก log: ขอใส่ดาบหลังบอสเกิด (Maru เข้าตีแล้ว = อยู่ในไฟต์) เซิร์ฟเวอร์ตอบ nil ไป 1.5-3.5 นาที
-- -> หยิบดาบตั้งแต่ชนะมินิเกม WhirlpoolBeast ตอนบอสยังไม่เกิด ยังไม่เข้าไฟต์
onWhirlpoolBeastCaught = function()
    local rod = findOwnedToolMatching(isRodName)
    if rod then lastRodName = rod.Name end
    print("[KL-Fisher] ⚔️ ชนะ WhirlpoolBeast -> หยิบดาบรอก่อนบอสเกิด (ยังไม่เข้าไฟต์ = เซิร์ฟเวอร์ยอมให้เปลี่ยนอาวุธ)")
    swordReadyForBoss = false
    -- ช่วงนี้เซิร์ฟเวอร์ยอมให้เปลี่ยนอาวุธ -> ล้างตัวนับพักที่ค้างจากไฟต์ก่อน ให้ลองถี่ได้ทันที
    table.clear(remoteFailCount)
    table.clear(remoteTriedAt)
    ensureSwordReady()
end

-- ย้ายไปเซิร์ฟใหม่ (หลังบอสจบ): เลือกเซิร์ฟจากรายชื่อเซิร์ฟสาธารณะของ Roblox ที่ยังไม่เต็ม และไม่ใช่เซิร์ฟเดิม
-- เน็ตช้าโหลดรายชื่อไม่ทันใน 8 วิ -> ใช้ Teleport ธรรมดาให้ Roblox สุ่มเซิร์ฟให้ / ยังอยู่เซิร์ฟเดิมหลัง 15 วิ -> ลองใหม่
local function pickNewServerJobId()
    if not CONFIG.HOP_USE_SERVER_LIST or not httpRequest then return nil end
    local result, finished = nil, false
    task.spawn(function()
        pcall(function()
            local response = httpRequest({
                Url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true", game.PlaceId),
                Method = "GET"
            })
            if response and response.StatusCode == 200 then
                local data = HttpService:JSONDecode(response.Body)
                local candidates = {}
                for _, server in ipairs((data and data.data) or {}) do
                    local playing, maxPlayers = tonumber(server.playing), tonumber(server.maxPlayers)
                    if server.id ~= game.JobId and playing and maxPlayers and playing < maxPlayers - 1 then
                        table.insert(candidates, server.id)
                    end
                end
                if #candidates > 0 then
                    result = candidates[math.random(#candidates)]
                end
            end
        end)
        finished = true
    end)
    local start = os.clock()
    while not finished and os.clock() - start < 8 do task.wait(0.2) end
    return result
end

-- บอสตัวใหม่อยู่ในเซิร์ฟเรา (เพิ่งโผล่ระหว่างรอย้าย / ตกได้ WhirlpoolBeast แล้ว) -> ห้ามย้ายหนี
local function newBossHere()
    return maruBossName ~= nil or os.clock() < bossIncomingUntil or findBossInServer() ~= nil
end

-- เขียน "จบแล้ว" ลง Firebase ทันที (ไม่อ่านก่อน เน็ตช้า อ่าน+เขียนรวม 22-42 วิ ย้ายเซิร์ฟก่อนทุกที)
-- รอเขียนเสร็จก่อนค่อยย้าย สูงสุด 25 วิ: ไม่งั้นสัญญาณเก่าที่ยังไม่หมดอายุดึงเพื่อนกลับมาเซิร์ฟที่บอสตายแล้ว
local function writeEndedSignal()
    local done = false
    task.spawn(function()
        httpPut(CONFIG.FIREBASE_URL, {
            finder = LocalPlayer.Name, targetType = "None", boss = "",
            jobId = game.JobId, placeId = game.PlaceId,
            timestamp = FIREBASE_SERVER_TIMESTAMP, key = CONFIG.SIGNAL_KEY, status = "ended",
        })
        done = true
    end)
    local start = os.clock()
    while not done and os.clock() - start < 25 do task.wait(0.2) end
end

-- options.endSignal = true: หลังบอสตาย -> ปิดสัญญาณของเซิร์ฟนี้ + จดเซิร์ฟนี้ลงรายการข้าม 30 นาที ก่อนย้าย
-- options.ignoreBoss = true: ย้ายแม้มีบอสในเซิร์ฟ (ตัวรองในโหมดคิว ใส่คิวแล้วไปต่อ ไม่อยู่ตี)
-- options.quiet = true: ไม่ส่ง log เข้า Discord (ตัวรองย้ายทุก 20-30 วิ จะท่วมห้อง)
local function hopToNewServer(reason, options)
    options = options or {}
    local function bossBlocksHop()
        return not options.ignoreBoss and newBossHere()
    end
    if isHoppingServer then return end
    if bossBlocksHop() then return end
    isHoppingServer = true
    broadcastGeneration = broadcastGeneration + 1
    stopHeartbeat()
    followingSignal = nil
    bypassHopBlock = true -- การย้ายของเราเอง ต้องไม่โดนตัวกันย้ายเซิร์ฟ (HOLD) บล็อค
    print(string.format("[KL-Fisher] 🔁 %s -> ย้ายไปเซิร์ฟใหม่", reason))
    if not options.quiet then
        postCoordLog(string.format("🔁 **%s** %s → ย้ายไปเซิร์ฟใหม่ (JobId เดิม `%s`)", LocalPlayer.Name, reason, shortJobId(game.JobId)))
    end

    if options and options.endSignal then
        markSkipJob(game.JobId, 30 * 60)
        writeEndedSignal()
    end

    local function abortForNewBoss()
        warn("[KL-Fisher] ↩️ ยกเลิกย้ายเซิร์ฟ: มีบอสตัวใหม่ในเซิร์ฟนี้")
        postCoordLog(string.format("↩️ **%s** ยกเลิกย้ายเซิร์ฟ เพราะมีบอสตัวใหม่โผล่ในเซิร์ฟนี้", LocalPlayer.Name))
        bypassHopBlock = false
        isHoppingServer = false
    end

    local maxAttempts = tonumber(CONFIG.HOP_MAX_ATTEMPTS) or 6
    for attempt = 1, maxAttempts do
        -- ระหว่างรอ (เขียนสัญญาณ / ลองครั้งก่อน) บอสตัวใหม่อาจโผล่ -> อยู่ตีต่อ ไม่ย้ายหนี
        if bossBlocksHop() then
            abortForNewBoss()
            return
        end
        local targetJobId = pickNewServerJobId()
        lastTeleportFailReason = nil
        local attemptStart = os.clock()
        local called = pcall(function()
            if targetJobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, targetJobId, LocalPlayer)
            else
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end
        end)
        -- ย้ายสำเร็จ = สคริปต์นี้หายไปพร้อมเซิร์ฟเดิมก่อนรอเสร็จ / Roblox แจ้งล้มเหลว = รู้ทันที ไม่ต้องรอครบ 15 วิ
        local failKind = called and waitTeleportOutcome(attemptStart, 15) or "Failure"
        if failKind == "IsTeleporting" then
            -- มีการวาร์ปอื่นค้างอยู่ (มักเป็น Maru) -> น่าจะได้ย้ายอยู่แล้ว รอให้จบก่อน ไม่นับว่าล้มเหลว
            warn(string.format("[KL-Fisher] ⏳ มีการวาร์ปอื่นค้างอยู่ รอก่อน (ครั้งที่ %d/%d)", attempt, maxAttempts))
            task.wait(10)
        elseif failKind == "Flooded" then
            -- วาร์ปถี่เกิน Roblox ไม่รับชั่วคราว -> ลองใหม่เร็ว ๆ ยิ่งโดนนาน พักก่อน
            warn(string.format("[KL-Fisher] ⏳ วาร์ปถี่เกิน (Flooded) ครั้งที่ %d/%d -> พัก 30 วิ", attempt, maxAttempts))
            task.wait(30)
        elseif failKind then
            -- เซิร์ฟที่สุ่มได้เต็ม / เน็ตสะดุด -> Teleport สุ่มเซิร์ฟใหม่ทุกครั้ง ลองใหม่ใน 3 วิ
            warn(string.format("[KL-Fisher] ⚠️ ย้ายเซิร์ฟไม่สำเร็จ (%s) ครั้งที่ %d/%d -> สุ่มเซิร์ฟใหม่ใน 3 วิ%s", failKind, attempt, maxAttempts,
                lastTeleportFailReason and (": " .. lastTeleportFailReason) or ""))
            task.wait(3)
        else
            warn(string.format("[KL-Fisher] ⚠️ ย้ายเซิร์ฟยังไม่สำเร็จหลัง 15 วิ (ครั้งที่ %d/%d)", attempt, maxAttempts))
        end
    end
    if not options.quiet then
        postCoordLog(string.format("⚠️ **%s** ย้ายเซิร์ฟไม่สำเร็จครบ %d ครั้ง → อยู่เซิร์ฟเดิมต่อ", LocalPlayer.Name, maxAttempts))
    end
    bypassHopBlock = false
    isHoppingServer = false
end
hopToNewServerRef = hopToNewServer

local function shouldHopAfterBoss(bossName)
    for _, name in ipairs(CONFIG.HOP_AFTER_BOSSES or {}) do
        if string.find(string.lower(tostring(bossName)), string.lower(name), 1, true) then
            return true
        end
    end
    return false
end

----------------------------------------------------------------------
-- 10.6 SERVER QUEUE (ตัวรองหาเซิร์ฟ -> ใส่คิว Firebase -> ตัวหลักดึงไปตีทีละเซิร์ฟ)
----------------------------------------------------------------------
-- เก็บแยกต่อเซิร์ฟที่ queue/<JobId>: ตัวรองหลายตัวเขียนพร้อมกันได้ ไม่แย่งช่องเดียวกันแบบ signal
local FIREBASE_BASE = string.match(CONFIG.FIREBASE_URL, "^(.*/)[^/]+%.json$")
-- ตัวหลักจดไว้ก่อนวาร์ปว่ากำลังไปเซิร์ฟไหนจากคิว (สคริปต์หายตอนย้ายเซิร์ฟ -> ไปถึงแล้วอ่านไฟล์นี้ log ว่ามาถึง)
local QUEUE_TARGET_FILE = "kl_queue_target_" .. tostring(LocalPlayer.UserId) .. ".json"
local queueStepRunning = false

local function isValidJobId(jobId)
    return type(jobId) == "string" and string.match(jobId, "^%x+%-%x+%-%x+%-%x+%-%x+$") ~= nil
end

local function queueEntryUrl(jobId)
    if not FIREBASE_BASE or not isValidJobId(jobId) then return nil end
    return FIREBASE_BASE .. "queue/" .. jobId .. ".json"
end

-- ลบออกจากคิวเบื้องหลัง (ไม่รอ: เน็ตช้า 11-21 วิ)
local function removeQueueEntry(jobId)
    local url = queueEntryUrl(jobId)
    if url then task.spawn(httpDelete, url) end
end

local function queueEntryTtl(entry)
    if entry.type == "Boss" then return tonumber(CONFIG.QUEUE_BOSS_TTL) or 180 end
    if entry.byMain then return tonumber(CONFIG.QUEUE_MAIN_WHIRLPOOL_TTL) or 600 end
    return tonumber(CONFIG.QUEUE_WHIRLPOOL_TTL) or 240
end

local function queueEntryLabel(entry)
    local label = targetLabel(entry.type == "Boss" and "Boss" or "Whirlpool", entry.name)
    if entry.type == "Boss" and tonumber(entry.hp) then
        label = label .. string.format(" HP %d%%", tonumber(entry.hp))
    end
    return label
end

-- อ่านคิวทั้งหมด -> รายการที่ยังใช้ได้ เรียง Serpent > มังกร > น้ำวน / ใหม่ก่อนเก่า (ของหมดอายุลบทิ้งเบื้องหลัง)
local function fetchQueue()
    if not FIREBASE_BASE then return {} end
    local data = httpGet(FIREBASE_BASE .. "queue.json")
    local list = {}
    if type(data) ~= "table" then return list end
    local now = serverNow()
    for key, entry in pairs(data) do
        local valid = type(entry) == "table" and isValidJobId(entry.jobId) and tostring(key) == entry.jobId
            and (entry.type == "Boss" or entry.type == "Whirlpool")
            and (CONFIG.SIGNAL_KEY == "" or entry.key == CONFIG.SIGNAL_KEY)
        if not valid then
            removeQueueEntry(tostring(key))
        else
            local age = now - signalTimestampSeconds(entry.foundAt)
            if age > queueEntryTtl(entry) then
                removeQueueEntry(entry.jobId) -- หมดอายุ
            elseif entry.jobId == game.JobId then
                -- เซิร์ฟที่เราอยู่แล้ว: ของตัวรอง -> ลบ / ของตัวหลักเจอ -> เก็บไว้ (ตัวที่เจอลบเองตอนของหาย
                -- ไม่งั้นทิ้งน้ำวนไปช่วยตีที่อื่นแล้วกลับมาไม่ได้)
                if not entry.byMain then removeQueueEntry(entry.jobId) end
            elseif tonumber(entry.placeId) == game.PlaceId and not isSkippedJob(entry.jobId) then
                -- ตัวหลักอีกตัวจองไปแล้ว (กำลังวาร์ปไป / อยู่ที่นั่น) -> ข้าม จนกว่าการจองจะหมดเวลา
                local claimAge = entry.claimedBy and (now - signalTimestampSeconds(entry.claimedAt)) or math.huge
                -- (บอส / ของที่ตัวหลักเจอ: ตัวหลักทุกตัวไปด้วยกัน ไม่สนการจอง / น้ำวนของตัวรอง: แยกกันไปคนละเซิร์ฟ)
                local claimedByOther = entry.type ~= "Boss" and not entry.byMain
                    and entry.claimedBy and entry.claimedBy ~= LocalPlayer.Name
                    and claimAge < (tonumber(CONFIG.QUEUE_CLAIM_SECONDS) or 120)
                if not claimedByOther then
                    entry.age = math.max(0, age)
                    table.insert(list, entry)
                end
            end
        end
    end
    -- ลำดับ: Serpent (1) -> มังกร / บอสอื่นในรายการ (2) -> น้ำวน (3)
    -- อันดับเท่ากัน: ของที่ตัวหลักเจอก่อน (เรียงตามใครเจอก่อน ตัวหลักทุกตัวได้ลำดับเดียวกัน -> ไปที่เดียวกัน)
    --               แล้วของตัวรอง (ใหม่ก่อนเก่า)
    local function queueEntryRank(entry)
        if entry.type ~= "Boss" then return 3 end
        return string.find(string.lower(tostring(entry.name)), "serpent", 1, true) and 1 or 2
    end
    table.sort(list, function(a, b)
        local rankA = queueEntryRank(a)
        local rankB = queueEntryRank(b)
        if rankA ~= rankB then return rankA < rankB end
        if (a.byMain == true) ~= (b.byMain == true) then return a.byMain == true end
        if a.byMain then
            local firstA, firstB = tonumber(a.firstAt) or 0, tonumber(b.firstAt) or 0
            if firstA ~= firstB then return firstA < firstB end
            return tostring(a.jobId) < tostring(b.jobId)
        end
        return a.age < b.age
    end)
    return list
end

-- ตัวรอง: ใส่เซิร์ฟนี้ลงคิว แล้วรอเขียนเสร็จ (สูงสุด 25 วิ) ก่อนย้าย ไม่งั้นย้ายแล้วคำขอที่ค้างอยู่หายไปด้วย
local function pushQueueEntry(entry)
    local url = queueEntryUrl(game.JobId)
    if not url then return false end
    local done, ok = false, false
    task.spawn(function()
        ok = httpPut(url, entry)
        done = true
    end)
    local start = os.clock()
    while not done and os.clock() - start < 25 do task.wait(0.2) end
    return ok
end

-- ตัวหลักมีงานในเซิร์ฟนี้อยู่ (บอส / WhirlpoolBeast ติดแล้ว / กำลังย้าย) -> ห้ามดึงคิว
local function mainBusyHere()
    return isHoppingServer or isTeleportingToFriend or isFightingBoss or maruBossName ~= nil
        or os.clock() < bossIncomingUntil or findBossInServer() ~= nil
end

-- วาร์ปไปเซิร์ฟในคิว: คืนชนิดความล้มเหลว (วาร์ปสำเร็จ = สคริปต์นี้หายไปพร้อมเซิร์ฟเดิมก่อนคืนค่า)
local function teleportToQueued(entry)
    pcall(function()
        if writefile then
            writefile(QUEUE_TARGET_FILE, HttpService:JSONEncode({
                jobId = entry.jobId, type = entry.type, name = entry.name, scout = entry.scout,
            }))
        end
    end)
    -- ระหว่างวาร์ป บล็อคการย้ายเซิร์ฟอื่น (Maru SerpentHop) ให้ผ่านเฉพาะคำสั่งไป JobId นี้
    -- (จาก log 20:14-20:15: วาร์ปจริงใช้ ~40 วิ ระหว่างนั้นมีวาร์ปอื่นแทรก -> IsTeleporting)
    local waitSeconds = tonumber(CONFIG.QUEUE_TELEPORT_WAIT) or 45
    scriptEnv.KL_REJOIN_JOBID = entry.jobId -- ขึ้น Join Error ระหว่างวาร์ป -> ตัวกู้คืนลองไปเซิร์ฟนี้ต่อก่อน
    followTargetJobId = entry.jobId
    followBlockUntil = os.clock() + waitSeconds
    if installHopBlockHooksWhenSafe then installHopBlockHooksWhenSafe() end
    lastTeleportFailReason = nil
    local attemptStart = os.clock()
    local called = pcall(function()
        TeleportService:TeleportToPlaceInstance(tonumber(entry.placeId) or game.PlaceId, entry.jobId, LocalPlayer)
    end)
    local failKind = called and waitTeleportOutcome(attemptStart, waitSeconds) or "Failure"
    scriptEnv.KL_REJOIN_JOBID = maruBossName and game.JobId or nil
    followTargetJobId = nil
    followBlockUntil = 0
    return failKind
end

-- ปาร์ตี้ตัวหลัก (ไปเซิร์ฟเดียวกันเสมอ): ตัวหลักลำดับ 1 = หัวหน้า ดึงคิว แล้วเขียนเซิร์ฟที่จะไป/อยู่ลง party.json
-- ตัวหลักลำดับ 2 ขึ้นไป = ตามหัวหน้า / ไม่มีเซิร์ฟของปาร์ตี้ที่ยังสด (หัวหน้าออฟไลน์) -> ดึงคิวเองแทน
local party = {
    url = FIREBASE_BASE and (FIREBASE_BASE .. "party.json") or nil,
}

function party.isLeader()
    return MAIN_INDEX == 1
end

-- เขียนเซิร์ฟของปาร์ตี้ (เบื้องหลัง ไม่รอ: เน็ตช้า 11-21 วิ)
function party.publish(jobId, label)
    if not party.url or not MAIN_INDEX or not isValidJobId(jobId) then return end
    task.spawn(httpPut, party.url, {
        jobId = jobId, placeId = game.PlaceId, by = LocalPlayer.Name, label = label,
        at = FIREBASE_SERVER_TIMESTAMP, key = CONFIG.SIGNAL_KEY,
    })
end

-- เซิร์ฟของปาร์ตี้ที่ยังสดและเป็นของตัวหลักตัวอื่น -> data / ไม่มี / เก่า / ของเราเอง -> nil
function party.fetch()
    if not party.url then return nil end
    local data = httpGet(party.url)
    if type(data) ~= "table" or not isValidJobId(data.jobId) or data.by == LocalPlayer.Name then return nil end
    if CONFIG.SIGNAL_KEY ~= "" and data.key ~= CONFIG.SIGNAL_KEY then return nil end
    if tonumber(data.placeId) ~= game.PlaceId then return nil end
    local age = serverNow() - signalTimestampSeconds(data.at)
    if age > (tonumber(CONFIG.PARTY_TTL) or 300) then return nil end
    data.age = math.max(0, age)
    return data
end

-- ตัวหลัก: ดึงเซิร์ฟจากคิวทีละอันแล้ววาร์ปไป (เต็ม / เข้าไม่ได้ -> อันถัดไปทันที ไม่ต้องรอใคร)
-- leaveIfEmpty = true (ตีบอสจบแล้ว): คิวว่าง / ไปไม่ได้สักอัน -> สุ่มย้ายเซิร์ฟเหมือนเดิม
local function runQueueStep(leaveIfEmpty, reason)
    if queueStepRunning then return end
    queueStepRunning = true
    local ok, err = pcall(function()
        local entries = fetchQueue()
        -- อ่านช้า ระหว่างรออาจมีบอส / WhirlpoolBeast โผล่ในเซิร์ฟเรา -> อยู่ตีต่อ
        if mainBusyHere() then return end

        -- ยืนตกที่น้ำวนอยู่: ไม่ทิ้งน้ำวนเราไปหาน้ำวนอื่น ไปเฉพาะเซิร์ฟที่ Serpent เกิดแล้ว
        local bossOnly = not leaveIfEmpty and getWhirlpoolTarget() ~= nil
        if bossOnly and not CONFIG.QUEUE_LEAVE_WHIRLPOOL_FOR_BOSS then return end

        local maxTries = tonumber(CONFIG.QUEUE_MAX_TRIES) or 5
        local tries = 0
        for _, entry in ipairs(entries) do
            if tries >= maxTries or mainBusyHere() then break end
            if not bossOnly or entry.type == "Boss" then
                tries = tries + 1
                -- จองเซิร์ฟนี้ก่อนไป (เบื้องหลัง ไม่รอ): ตัวหลักอีกตัวจะข้าม / ไปถึงแล้วเซิร์ฟนี้ถูกลบจากคิวเอง (fetchQueue)
                local claimUrl = queueEntryUrl(entry.jobId)
                if claimUrl then
                    task.spawn(httpPatch, claimUrl, { claimedBy = LocalPlayer.Name, claimedAt = FIREBASE_SERVER_TIMESTAMP })
                end
                -- บอกตัวหลักตัวอื่นให้ตามมาเซิร์ฟนี้ (เขียนก่อนวาร์ป: ตัวตามจะได้ออกเดินทางไล่เลี่ยกัน)
                if CONFIG.PARTY_ALWAYS_TOGETHER then
                    party.publish(entry.jobId, queueEntryLabel(entry))
                end
                print(string.format("[KL-Fisher] 🎯 ดึงเซิร์ฟจากคิว: %s (%s '%s' เจอ ต่ออายุล่าสุด %d วิก่อน) -> วาร์ปไป JobId %s",
                    queueEntryLabel(entry), entry.byMain and "ตัวหลัก" or "ตัวรอง", tostring(entry.scout),
                    math.floor(entry.age), entry.jobId))
                postCoordLog(string.format("🎯 **%s** ดึงเซิร์ฟจากคิว: %s ที่ **%s** เจอเมื่อ %d วิก่อน → วาร์ปไป (JobId `%s`)",
                    LocalPlayer.Name, queueEntryLabel(entry), tostring(entry.scout), math.floor(entry.age), shortJobId(entry.jobId)))

                isHoppingServer = true
                bypassHopBlock = true -- การย้ายของเราเอง ต้องไม่โดนตัวกันย้ายเซิร์ฟ (HOLD) บล็อค
                broadcastGeneration = broadcastGeneration + 1
                local failKind = teleportToQueued(entry)
                if failKind == "Failure" or failKind == "IsTeleporting" then
                    -- Failure ส่วนใหญ่เป็น "Http error" (เน็ตสะดุด) / IsTeleporting = มีวาร์ปอื่นค้าง
                    -- -> เซิร์ฟยังดีอยู่ ลองไปเซิร์ฟเดิมซ้ำอีกครั้งก่อน ไม่ทิ้งไปอันถัดไป
                    warn(string.format("[KL-Fisher] ⚠️ วาร์ปไปเซิร์ฟในคิวไม่สำเร็จ (%s) -> ลองเซิร์ฟเดิมอีกครั้งใน 3 วิ", failKind))
                    task.wait(3)
                    -- (ระหว่างรอ บอสโผล่ในเซิร์ฟเรา -> อยู่ตีต่อ)
                    if not (maruBossName or os.clock() < bossIncomingUntil or findBossInServer()) then
                        failKind = teleportToQueued(entry)
                    end
                end
                bypassHopBlock = false
                isHoppingServer = false

                if failKind == nil then
                    -- ไม่มีแจ้งล้มเหลว แต่ยังไม่ย้ายหลัง 45 วิ -> อาจยังวาร์ปอยู่ ห้ามสั่งวาร์ปเซิร์ฟอื่นทับ
                    warn("[KL-Fisher] ⏳ ยังไม่ย้ายหลังรอ 45 วิ -> หยุดดึงคิวรอบนี้ รอบหน้าค่อยดึงใหม่")
                    postCoordLog(string.format("⏳ **%s** สั่งวาร์ปไปเซิร์ฟในคิวแล้ว แต่ยังไม่ย้ายหลัง 45 วิ (JobId `%s`)",
                        LocalPlayer.Name, shortJobId(entry.jobId)))
                    return
                end
                markSkipJob(entry.jobId, 10 * 60)
                postCoordLog(string.format("🚫 **%s** วาร์ปไปเซิร์ฟในคิวไม่ได้ (%s) → ลองอันถัดไป",
                    LocalPlayer.Name, failKind == "GameFull" and "เซิร์ฟเต็ม" or tostring(lastTeleportFailReason or failKind)))
                if failKind == "Flooded" then task.wait(20) end
            end
        end

        if leaveIfEmpty and not mainBusyHere() then
            hopToNewServer((reason or "ตีจบแล้ว") .. " (คิวว่าง)")
        end
    end)
    queueStepRunning = false
    if not ok then
        warn("[KL-Fisher] ⚠️ ดึงคิวไม่สำเร็จ: " .. tostring(err))
    end
end

-- ตัวตาม: วาร์ปไปเซิร์ฟของปาร์ตี้ (ใช้ตัวล็อกเดียวกับดึงคิว ไม่ให้สั่งวาร์ปซ้อนกัน)
function party.follow(target)
    if queueStepRunning or mainBusyHere() then return end
    queueStepRunning = true
    local ok, err = pcall(function()
        print(string.format("[KL-Fisher] 👥 ตามหัวหน้า '%s' ไปเซิร์ฟเดียวกัน (%s) -> JobId %s",
            tostring(target.by), tostring(target.label), target.jobId))
        postCoordLog(string.format("👥 **%s** ตาม **%s** ไปเซิร์ฟเดียวกัน (%s) → JobId `%s`",
            LocalPlayer.Name, tostring(target.by), tostring(target.label), shortJobId(target.jobId)))

        isHoppingServer = true
        bypassHopBlock = true
        broadcastGeneration = broadcastGeneration + 1
        local entry = { jobId = target.jobId, placeId = target.placeId, type = "Party", name = target.label, scout = target.by }
        local failKind = teleportToQueued(entry)
        if failKind == "Failure" or failKind == "IsTeleporting" then
            task.wait(3)
            if not (maruBossName or os.clock() < bossIncomingUntil or findBossInServer()) then
                failKind = teleportToQueued(entry)
            end
        end
        bypassHopBlock = false
        isHoppingServer = false

        if failKind and failKind ~= "IsTeleporting" then
            -- เซิร์ฟหัวหน้าเต็ม / เข้าไม่ได้ -> ไม่ลองเซิร์ฟนี้อีก 10 นาที รอหัวหน้าไปเซิร์ฟถัดไป (หรือดึงคิวเองถ้าหัวหน้าเงียบ)
            markSkipJob(target.jobId, 10 * 60)
            postCoordLog(string.format("🚫 **%s** ตาม **%s** ไปไม่ได้ (%s)", LocalPlayer.Name, tostring(target.by),
                failKind == "GameFull" and "เซิร์ฟเต็ม" or tostring(lastTeleportFailReason or failKind)))
        end
    end)
    queueStepRunning = false
    if not ok then
        warn("[KL-Fisher] ⚠️ ตามหัวหน้าไม่สำเร็จ: " .. tostring(err))
    end
end

-- ตัวตาม ตีจบแล้ว: รอหัวหน้าบอกเซิร์ฟถัดไป (หัวหน้าดึงคิว / สุ่มย้ายแล้วเขียนเซิร์ฟใหม่) ไม่มาภายในเวลา -> ดึงคิวเอง
function party.afterBoss(reason)
    local deadline = os.clock() + (tonumber(CONFIG.PARTY_WAIT_AFTER_BOSS) or 90)
    while os.clock() < deadline do
        if mainBusyHere() then return end
        local target = party.fetch()
        if target and target.jobId ~= game.JobId and not isSkippedJob(target.jobId) then
            party.follow(target)
            return
        end
        task.wait(3)
    end
    if not mainBusyHere() then
        runQueueStep(true, reason)
    end
end

-- ตัวรอง: ดูเซิร์ฟนี้ว่ามี Serpent (ยังมีชีวิต) / น้ำวนไหม -> ใส่คิว แล้วย้ายเซิร์ฟต่อทันที (ไม่ตกปลา ไม่ตี)
local function runScout()
    local arrivedAt = os.clock()

    -- เซิร์ฟที่เพิ่งสำรวจ (ไฟล์แยกต่อไอดี: ย้ายเซิร์ฟแล้วสคริปต์เริ่มใหม่ ความจำในหน่วยความจำหาย)
    -- จาก log 03:56-04:01 วันที่ 25: Roblox สุ่มส่ง lilkao113 กลับเซิร์ฟ fcc45175 เดิม 9 รอบติด (ทุก ~30 วิ)
    -- -> ใส่คิว + แจ้ง Discord ซ้ำทุกรอบ / เสียเวลาสำรวจเซิร์ฟเดิม
    local seenFile = "kl_scout_seen_" .. tostring(LocalPlayer.UserId) .. ".json"
    local seenSeconds = tonumber(CONFIG.SCOUT_SEEN_SECONDS) or 300
    local seen = {}
    pcall(function()
        if isfile and readfile and isfile(seenFile) then
            local now = os.time()
            for jobId, info in pairs(HttpService:JSONDecode(readfile(seenFile)) or {}) do
                if type(info) == "table" and tonumber(info.at) and now - tonumber(info.at) < seenSeconds then
                    seen[jobId] = info
                end
            end
        end
    end)
    local prev = seen[game.JobId]

    if prev then
        print(string.format("[KL-Fisher] 🔭 ตัวรอง: กลับมาเซิร์ฟเดิม (สำรวจไปเมื่อ %d วิก่อน เจอ: %s) -> ดูแป๊บเดียวแล้วย้ายต่อ",
            os.time() - prev.at, tostring(prev.type)))
    else
        print("[KL-Fisher] 🔭 ตัวรอง: สำรวจเซิร์ฟนี้หาบอส (Serpent / มังกร) / น้ำวน...")
    end

    local found = nil
    -- เซิร์ฟเดิม: ดูสั้น ๆ พอ (ดูแค่ว่า Serpent เพิ่งเกิดไหม)
    local scanSeconds = prev and 3 or (tonumber(CONFIG.SCOUT_SCAN_SECONDS) or 6)
    local scanUntil = os.clock() + scanSeconds
    repeat
        local bossName, bossModel = findBossInServer()
        if bossName and bossModel then
            local hum = bossModel:FindFirstChildOfClass("Humanoid")
            local hp = nil
            if hum and hum.MaxHealth > 0 then
                hp = math.floor(hum.Health / hum.MaxHealth * 100 + 0.5)
            end
            found = { type = "Boss", name = bossName, hp = hp }
            break
        end
        task.wait(0.5)
    until os.clock() >= scanUntil
    if not found and getWhirlpoolTarget() ~= nil then
        found = { type = "Whirlpool", name = "SerpentWhirlpool" }
    end

    -- ตัวหลักอยู่เซิร์ฟนี้แล้ว (กำลังตี / ตกปลาที่น้ำวน) -> ไม่ใส่คิว
    -- (จาก log 20:23: ตัวรองสุ่มมาเจอเซิร์ฟที่ตัวหลักตีอยู่ แล้วใส่คิวซ้ำ JobId เดียวกัน)
    -- (ตัวหลักมีหลายตัว: ตัวไหนอยู่ก็ไม่ใส่)
    if found then
        local mainNames = {}
        for _, name in ipairs(CONFIG.MAIN_ACCOUNTS or {}) do
            mainNames[string.lower(tostring(name))] = true
        end
        for _, player in ipairs(Players:GetPlayers()) do
            if mainNames[string.lower(player.Name)] or mainNames[string.lower(player.DisplayName)] then
                print(string.format("[KL-Fisher] ⏭️ เจอ%s แต่ตัวหลัก '%s' อยู่เซิร์ฟนี้แล้ว -> ไม่ใส่คิว",
                    found.type == "Boss" and "บอส" or "น้ำวน", player.Name))
                found = nil
                break
            end
        end
    end

    local pushedAt = prev and tonumber(prev.pushedAt) or nil
    if found then
        found.jobId = game.JobId
        found.placeId = game.PlaceId
        found.scout = LocalPlayer.Name
        found.players = #Players:GetPlayers()
        found.maxPlayers = Players.MaxPlayers
        found.foundAt = FIREBASE_SERVER_TIMESTAMP -- Firebase ประทับเวลาเอง (ตัวหลักใช้นับอายุ)
        found.key = CONFIG.SIGNAL_KEY

        -- เจอของใหม่ = เซิร์ฟที่ไม่เคยมา / เคยเจอแค่น้ำวนหรือไม่เจออะไร แต่ตอนนี้ Serpent เกิดแล้ว ฯลฯ -> แจ้งตามปกติ
        -- เจอของเดิม -> ไม่แจ้ง Discord / ห้อง coordination ซ้ำ ใส่คิวซ้ำแบบเงียบ ๆ เฉพาะตอนที่ใส่ไว้นานแล้ว (ต่ออายุในคิว)
        -- (เทียบชื่อด้วย: บอสตัวเดิมตายแล้วเกิดตัวอื่น เช่น Serpent -> Abyssal Tyrant = ของใหม่)
        local isNewInfo = not prev or prev.type ~= found.type or prev.name ~= found.name
        local refreshSeconds = tonumber(CONFIG.SCOUT_REFRESH_SECONDS) or 120
        local needRefresh = not pushedAt or os.time() - pushedAt >= refreshSeconds
        if isNewInfo or needRefresh then
            if isNewInfo then
                if found.type == "Boss" then
                    notifyDiscordBoss(found.name)
                else
                    notifyDiscordWhirlpool(found.name)
                end
            end
            if pushQueueEntry(found) then
                pushedAt = os.time()
                print(string.format("[KL-Fisher] 📥 %s: %s (JobId %s)", isNewInfo and "ใส่คิวแล้ว" or "ต่ออายุในคิว",
                    queueEntryLabel(found), game.JobId))
                if isNewInfo then
                    postCoordLog(string.format("📥 **%s** ใส่คิว: %s — ผู้เล่น %d/%d (JobId `%s`)",
                        LocalPlayer.Name, queueEntryLabel(found), found.players, found.maxPlayers, shortJobId(game.JobId)))
                end
            else
                warn("[KL-Fisher] ⚠️ ใส่คิวไม่สำเร็จ (Firebase ไม่ตอบ) -> ย้ายเซิร์ฟต่อ")
            end
        else
            print(string.format("[KL-Fisher] ⏭️ %s อยู่ในคิวแล้ว (ใส่ไปเมื่อ %d วิก่อน) -> ไม่ใส่ซ้ำ",
                queueEntryLabel(found), os.time() - pushedAt))
        end
    end

    -- จดเซิร์ฟนี้ไว้ (รวมเซิร์ฟที่ไม่เจออะไร: กลับมาอีกจะได้ย้ายออกเร็ว)
    seen[game.JobId] = { at = os.time(), type = found and found.type or "None", name = found and found.name or nil, pushedAt = pushedAt }
    pcall(function()
        if writefile then writefile(seenFile, HttpService:JSONEncode(seen)) end
    end)

    -- เซิร์ฟเดิม: ย้ายต่อแทบทันที (Roblox สุ่มเซิร์ฟให้เรา เลือกเองไม่ได้ ยิ่งออกเร็วยิ่งได้สุ่มใหม่เร็ว)
    -- เซิร์ฟใหม่: อยู่ครบ SCOUT_MIN_STAY ก่อน (ย้ายถี่เกิน Roblox ขึ้น Flooded)
    local minStay = prev and (tonumber(CONFIG.SCOUT_REPEAT_STAY) or 3) or (tonumber(CONFIG.SCOUT_MIN_STAY) or 12)
    local stay = minStay - (os.clock() - arrivedAt)
    if stay > 0 then task.wait(stay) end
    while true do
        hopToNewServer(found and "ใส่คิวแล้ว" or "ไม่มีบอส/น้ำวน", { ignoreBoss = true, quiet = true })
        task.wait(10) -- ย้ายไม่สำเร็จครบทุกครั้ง -> พักแล้วลองใหม่ (ตัวรองไม่มีงานอื่นในเซิร์ฟนี้)
    end
end

-- ตัวหลักเจอบอส / น้ำวนในเซิร์ฟตัวเอง -> ใส่เซิร์ฟนี้ลงคิว (แบบเดียวกับตัวรอง) ติดป้าย byMain = งานของปาร์ตี้
-- (เดิมโหมดคิวปิดการเรียกเพื่อน ตัวหลักเจอของเองแจ้งแค่ Discord ตัวหลักอีกตัวไม่รู้)
-- firstAt = เวลาที่เจอครั้งแรก (เวลาเซิร์ฟ Firebase) ใช้เรียงคิวตามใครเจอก่อน
-- ต่ออายุทุก QUEUE_MAIN_FIND_REFRESH วิ ระหว่างของยังอยู่ / ของหายแล้ว (บอสตาย / น้ำวนหาย) -> clear ลบออกจากคิว
-- (เก็บสถานะในตารางเดียว: main chunk ใกล้เพดาน local 200 ตัวของ Luau แล้ว)
local mainFind = { lastAt = {}, logged = {}, firstAt = nil, shared = false, arrivedFrom = nil }

function mainFind.isOtherMain(name)
    if not name or string.lower(tostring(name)) == string.lower(LocalPlayer.Name) then return false end
    for _, mainName in ipairs(CONFIG.MAIN_ACCOUNTS or {}) do
        if string.lower(tostring(mainName)) == string.lower(tostring(name)) then return true end
    end
    return false
end

function mainFind.send(targetType, targetName)
    if not CONFIG.QUEUE_MODE or not MAIN_INDEX then return end
    -- มาเซิร์ฟนี้เพราะตามของที่ตัวหลักอีกตัวเจอ -> ตัวนั้นดูแลคิวเซิร์ฟนี้เอง ไม่ใส่ทับ (ลำดับ firstAt จะเพี้ยน)
    if mainFind.isOtherMain(mainFind.arrivedFrom) then return end
    local url = queueEntryUrl(game.JobId)
    if not url then return end
    if os.clock() - (mainFind.lastAt[targetType] or -math.huge) < (tonumber(CONFIG.QUEUE_MAIN_FIND_REFRESH) or 60) then return end
    mainFind.lastAt[targetType] = os.clock()

    local hp = nil
    if targetType == "Boss" then
        local _, bossModel = findBossInServer()
        local hum = bossModel and bossModel:FindFirstChildOfClass("Humanoid")
        if hum and hum.MaxHealth > 0 then
            hp = math.floor(hum.Health / hum.MaxHealth * 100 + 0.5)
        end
    end
    mainFind.firstAt = mainFind.firstAt or serverNow()
    local entry = {
        type = targetType, name = targetName, hp = hp,
        jobId = game.JobId, placeId = game.PlaceId, scout = LocalPlayer.Name,
        byMain = true, firstAt = mainFind.firstAt,
        players = #Players:GetPlayers(), maxPlayers = Players.MaxPlayers,
        foundAt = FIREBASE_SERVER_TIMESTAMP, key = CONFIG.SIGNAL_KEY,
    }
    mainFind.shared = true
    task.spawn(function()
        if not httpPut(url, entry) then
            warn("[KL-Fisher] ⚠️ ตัวหลักใส่เซิร์ฟนี้ลงคิวไม่สำเร็จ (Firebase ไม่ตอบ) -> ลองใหม่รอบหน้า")
            mainFind.lastAt[targetType] = -math.huge
            return
        end
        if not mainFind.logged[targetType] then
            mainFind.logged[targetType] = true
            print(string.format("[KL-Fisher] 📥 ตัวหลักเจอ %s ในเซิร์ฟตัวเอง -> ใส่คิว ให้ตัวหลักอีกตัวมาทำด้วยกัน (JobId %s)",
                queueEntryLabel(entry), game.JobId))
            postCoordLog(string.format("📥 **%s** (ตัวหลัก) เจอ %s ในเซิร์ฟตัวเอง → ใส่คิว ให้ตัวหลักอีกตัวมาด้วย (JobId `%s`)",
                LocalPlayer.Name, queueEntryLabel(entry), shortJobId(game.JobId)))
        end
    end)
end

-- ของในเซิร์ฟนี้หมดแล้ว -> ลบเซิร์ฟนี้ออกจากคิว (เฉพาะที่เราเป็นคนใส่ ไม่งั้นตัวหลักอีกตัววาร์ปมาเปล่า ๆ)
function mainFind.clear()
    if not mainFind.shared then return end
    mainFind.shared = false
    mainFind.firstAt = nil
    table.clear(mainFind.lastAt)
    table.clear(mainFind.logged)
    removeQueueEntry(game.JobId)
end

local function handBossToMaru(bossName)
    if maruBossName ~= bossName then
        maruBossName = bossName
        bossIncomingUntil = 0
        scriptEnv.KL_REJOIN_JOBID = game.JobId -- หลุดกลางไฟต์ (279) -> ตัวกู้คืนพากลับมาเซิร์ฟนี้ก่อน
        -- จำชื่อเบ็ดที่ Maru ใช้อยู่ ไว้คืนให้ถูกเล่มหลังบอสตาย
        local rod = findOwnedToolMatching(isRodName)
        if rod then lastRodName = rod.Name end
        print(string.format("[KL-Fisher] 🐉 พบบอส '%s' -> เรียกเพื่อน + หยิบดาบพร้อมตี (Maru Hub เป็นคนตี)", bossDisplayName(bossName)))
        -- ไม่เก็บแท่นลอยตอนนี้: ถ้า Maru ยังไม่ได้พาตัวไปไหน ตัวละครจะตกน้ำ (ผลปีศาจจม) -> เก็บตอนบอสหายแล้ว
        setNoclip(false)
    end
    broadcastBossFound(bossName)
    mainFind.send("Boss", bossName)
    ensureSwordReady()
end

----------------------------------------------------------------------
-- 11. CAST EXECUTION (เหวี่ยงเบ็ด)
----------------------------------------------------------------------
local function executeCastFishing()
    if isFightingBoss or maruBossName or isSolvingFishing or not CONFIG.AUTO_FISHING then return end
    -- ตกได้ WhirlpoolBeast แล้ว: ถือดาบรอบอส ห้ามเหวี่ยงเบ็ดต่อ (จะสลับกลับไปถือเบ็ด)
    if os.clock() < bossIncomingUntil then return end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end
    
    if isFightingBoss then return end
    equipRod()
    local rod = getRodTool()
    if not rod then return end
    
    local targetPos, targetName = getWhirlpoolTarget()
    local isAtWhirlpool = (targetPos ~= nil and CONFIG.AUTO_WHIRLPOOL)
    
    local castTargetCFrame
    if isAtWhirlpool then
        print(string.format("[KL-Fisher] 🌊 พบคู่กรณีน้ำวน [%s]! ยืนแท่นลอยนิรภัย...", targetName))
        broadcastWhirlpoolFound(targetName)
        mainFind.send("Whirlpool", "SerpentWhirlpool")
        setNoclip(true)
        
        local hoverPos = targetPos + Vector3.new(0, CONFIG.PLATFORM_HEIGHT, 0)
        ensureSafetyPlatform(hoverPos)
        
        local safeHover = CFrame.new(hoverPos + Vector3.new(0, 3.2, 0), targetPos)
        hrp.Velocity = Vector3.zero
        pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
        hrp.CFrame = safeHover
        castTargetCFrame = CFrame.new(targetPos)
    else
        removeSafetyPlatform()
        local forwardPoint = hrp.Position + (hrp.CFrame.LookVector * 20) + Vector3.new(0, -6, 0)
        castTargetCFrame = CFrame.new(forwardPoint)
    end
    
    if rod.Parent ~= char then
        hum:EquipTool(rod)
        task.wait(0.3)
    end
    
    if CONFIG.AUTO_CAST_ROD then
        local skillAction = ReplicatedStorage:FindFirstChild("Chest") 
            and ReplicatedStorage.Chest:FindFirstChild("Remotes")
            and ReplicatedStorage.Chest.Remotes:FindFirstChild("Functions")
            and ReplicatedStorage.Chest.Remotes.Functions:FindFirstChild("SkillAction")
            
        if skillAction then
            -- ตอนกดเองเกมส่ง Charge ตามเวลาที่กดค้าง (ดักด้วย Cobalt: 98.43) -> สุ่ม 95-100 ทุกครั้ง ไม่ส่ง 100 เป๊ะซ้ำ ๆ
            local minCharge = math.clamp(tonumber(CONFIG.CAST_CHARGE_MIN) or 95, 0, 100)
            local maxCharge = math.clamp(tonumber(CONFIG.CAST_CHARGE_MAX) or 100, minCharge, 100)
            local charge = minCharge + math.random() * (maxCharge - minCharge)
            pcall(function()
                local remoteKey = "SW_" .. rod.Name .. "_M1"
                skillAction:InvokeServer(remoteKey, {Charge = charge, MouseHit = castTargetCFrame})
            end)
        else
            rod:Activate()
        end
    end
    
    local waitStart = tick()
    while tick() - waitStart < CONFIG.BITE_TIMEOUT do
        task.wait(1)

        -- (ไม่เช็คสัญญาณเพื่อนตรงนี้แล้ว: ยิง Firebase ทุกวิ เน็ตช้าค้างได้ถึง 21 วิ ทำให้เห็นบอสช้า
        --  ตัวเช็คสัญญาณเบื้องหลังใน supervisor ทำทุก CHECK_INTERVAL อยู่แล้ว)

        -- บอสโผล่ระหว่างรอปลา: ตีเองถ้าเปิด AUTO_ATTACK_BOSS ไม่งั้นส่งต่อให้ Maru Hub
        local bName, bModel = findBossInServer()
        if bName and bModel then
            if CONFIG.AUTO_ATTACK_BOSS then
                print(string.format("[KL-Fisher] 🐉 บอส '%s' ปรากฏตัวขึ้นแล้ว! กำลังเข้าตี...", bName))
                removeSafetyPlatform()
                broadcastBossFound(bName)
                mainFind.send("Boss", bName)
                attackTarget(bModel)
            else
                handBossToMaru(bName)
            end
            break
        end
        
        if not isAtWhirlpool and CONFIG.AUTO_WHIRLPOOL then
            local wPos, wName = getWhirlpoolTarget()
            if wPos then
                print(string.format("[KL-Fisher] 🌊 ตรวจพบน้ำวนเกิดใหม่ '%s'!", wName))
                broadcastWhirlpoolFound(wName)
                mainFind.send("Whirlpool", "SerpentWhirlpool")
                break
            end
        end
        
        -- FishingUI โผล่เฉพาะตอนปลากินเบ็ดแล้ว ช่วงรอปลาจึงต้องดู attribute "Fishing" ที่เกมตั้งบนตัวละครแทน
        -- (ถ้าเช็คแค่ FishingUI บอทจะเหวี่ยงใหม่ทุก 3 วินาทีจนปลาไม่ทันกิน)
        if not isSolvingFishing and (tick() - waitStart > 3) then
            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            local hasMinigame = pGui and pGui:FindFirstChild("FishingUI")
            local stillFishing = char.Parent ~= nil and char:GetAttribute("Fishing")
            if not hasMinigame and not stillFishing then
                break
            end
        end
    end
    
    if isAtWhirlpool then
        setNoclip(false)
    end
end

----------------------------------------------------------------------
-- 12. CONTROLLER CYCLE (วงรอบการทำงานหลัก)
----------------------------------------------------------------------
local bossMissingSince = nil

local function runFishingCycle()
    -- หากกำลังต่อสู้บอสอยู่ ให้คงสถานะต่อสู้ไว้ ห้ามรันรอบตกปลาซ้อนทับ
    if isFightingBoss then
        task.wait(0.5)
        return
    end

    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        local waitCharStart = tick()
        while tick() - waitCharStart < 8 do
            char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then break end
            task.wait(0.5)
        end
    end
    
    char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 10)
    if not hrp then return end
    
    -- 0. บอสที่ Maru Hub ตีอยู่หายไปแล้ว -> ล้างสัญญาณ แล้วกลับไปตกปลาต่อ
    -- ต้องหายติดกัน 3 วิ ถึงนับว่าหายจริง (บอสเพิ่งเกิด HP ยังไม่โหลด / โมเดลกระพริบ -> ห้ามเข้าใจผิดแล้วย้ายเซิร์ฟทิ้ง)
    local bossGone = false
    if maruBossName and not findBossInServer() then
        bossMissingSince = bossMissingSince or os.clock()
        bossGone = os.clock() - bossMissingSince >= 3
    else
        bossMissingSince = nil
    end
    if bossGone then
        bossMissingSince = nil
        print(string.format("[KL-Fisher] 🏆 บอส '%s' หายไปแล้ว (Maru ตีจบ) -> ล้างสัญญาณ คืนเบ็ดให้ Maru", bossDisplayName(maruBossName)))
        postCoordLog(string.format("🏆 บอส `%s` ในเซิร์ฟที่ **%s** อยู่หายไปแล้ว (ตีจบ) → จบการเรียกเพื่อนรอบนี้ (JobId `%s`)",
            bossDisplayName(maruBossName), LocalPlayer.Name, shortJobId(game.JobId)))
        local finishedBoss = maruBossName
        maruBossName = nil
        scriptEnv.KL_REJOIN_JOBID = nil
        swordReadyForBoss = false
        table.clear(remoteFailCount) -- จบไฟต์แล้ว ใส่อาวุธได้ปกติ -> เลิกพักยาว
        removeSafetyPlatform()
        mainFind.clear() -- บอสเซิร์ฟนี้จบแล้ว ห้ามให้ตัวหลักอีกตัววาร์ปมาอีก (น้ำวนยังอยู่ -> รอบหน้าใส่คิวใหม่เอง)
        if shouldHopAfterBoss(finishedBoss) then
            -- บอสจบแล้ว -> ย้ายเซิร์ฟใหม่ทันที (ไม่ต้องคืนเบ็ดที่นี่ ไปเซิร์ฟใหม่ค่อยหยิบเบ็ดตอนตกปลา)
            -- ไม่ใช้ clearSignal (อ่านก่อนเขียน ช้าเกิน ย้ายเซิร์ฟก่อนทุกที) -> hopToNewServer เขียน "จบแล้ว" เองแบบรอให้เสร็จ
            isFightingBoss = false
            currentFightingBossName = nil
            activeBroadcastKey = nil
            task.wait(tonumber(CONFIG.HOP_AFTER_BOSS_DELAY) or 2)
            local reason = string.format("บอส %s ตีจบแล้ว", bossDisplayName(finishedBoss))
            if CONFIG.QUEUE_MODE then
                -- โหมดคิว: ไปเซิร์ฟถัดไปที่ตัวรองหาไว้ (คิวว่าง -> สุ่มย้ายเซิร์ฟ) / ไม่ใช้ช่อง signal แล้ว
                markSkipJob(game.JobId, 30 * 60)
                while queueStepRunning do task.wait(0.5) end -- ตัวเช็คคิวเบื้องหลังกำลังดึงอยู่ -> รอให้จบก่อน
                if MAIN_INDEX and not party.isLeader() and CONFIG.PARTY_ALWAYS_TOGETHER then
                    party.afterBoss(reason) -- ตัวตาม: รอหัวหน้าบอกเซิร์ฟถัดไป แล้วตามไป
                else
                    runQueueStep(true, reason)
                end
            else
                hopToNewServer(reason, { endSignal = true })
            end
            -- มาถึงตรงนี้ = ยังอยู่เซิร์ฟเดิม (ยกเลิกเพราะบอสใหม่ / ย้ายไม่สำเร็จ) -> คืนเบ็ด กลับไปทำงานต่อ
            restoreRodForMaru()
            return
        end
        clearSignal()
        restoreRodForMaru()
    end

    -- 1. ตรวจสอบบอส: ตีเองถ้าเปิด AUTO_ATTACK_BOSS ไม่งั้นส่งต่อให้ Maru Hub แล้วรอเฉย ๆ
    local bossName, bossModel = findBossInServer()
    if bossName and bossModel then
        if CONFIG.AUTO_ATTACK_BOSS then
            print(string.format("[KL-Fisher] 🎯 พบบอส '%s'! กำลังเข้าโจมตี...", bossName))
            removeSafetyPlatform()
            broadcastBossFound(bossName)
            mainFind.send("Boss", bossName)
            attackTarget(bossModel)
        else
            handBossToMaru(bossName)
            task.wait(1)
        end
        return
    end

    -- 1.5 ตกได้ WhirlpoolBeast แล้ว บอสกำลังจะเกิด: พยายามหยิบดาบซ้ำทุกรอบในช่วงนี้ (ยังไม่เข้าไฟต์ = เซิร์ฟเวอร์ยอมให้เปลี่ยน)
    -- (เดิมลองแค่ครั้งเดียวตอนจบมินิเกม ถ้าโดนปฏิเสธเพราะยังอยู่ในสถานะตกปลา ก็ไปลองอีกทีตอนเข้าไฟต์แล้ว = ช้า 1.5-3.5 นาที)
    if os.clock() < bossIncomingUntil then
        ensureSwordReady()
        task.wait(1)
        return
    end

    -- 2. ตรวจสอบน้ำวน
    if CONFIG.AUTO_WHIRLPOOL then
        local whirlpoolPos = getWhirlpoolTarget()
        if whirlpoolPos then
            -- (executeCastFishing จะ print + ส่งสัญญาณน้ำวนเอง ไม่ต้องส่งซ้ำตรงนี้)
            executeCastFishing()
            return
        end
    end
    
    -- 3. (ไม่เช็คสัญญาณเพื่อนในลูปหลักแล้ว: ยิง Firebase ทุกรอบ เน็ตช้าค้าง 11-21 วิ ทั้งรอบตกปลา
    --     ตัวเช็คสัญญาณเบื้องหลังใน supervisor ทำทุก CHECK_INTERVAL และวาร์ปให้เองอยู่แล้ว)

    -- 4. ตกปลาทั่วไป (ไม่มีบอส / น้ำวนแล้ว -> ของที่เราใส่คิวไว้หมดแล้ว ลบออก)
    mainFind.clear()
    if CONFIG.AUTO_FISHING then
        executeCastFishing()
    end
    task.wait(CONFIG.CAST_COOLDOWN)
end

----------------------------------------------------------------------
-- 13. SCOOT UI INTEGRATION (โหลดและจัดวางหน้าจอเมนู)
----------------------------------------------------------------------
print("[KL-Fisher] 📦 กำลังโหลด Scoot UI Library...")

local Library
local ok = pcall(function()
    -- ดึงตัว Library แบบเพียวจากต้นฉบับของผู้สร้าง
    Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/sametexe001/sametlibs/refs/heads/main/Scoot/Library.lua"))()
end)

if not ok or not Library then
    local fallbackOk, fallbackCode = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/x2Swiftz/UI-Library/refs/heads/main/Libraries/Scoot%20UI%20-%20Example.lua")
    end)
    if fallbackOk and fallbackCode then
        -- ตัดส่วน Example Window ท้ายไฟล์ออก เพื่อไม่ให้เปิดหน้าต่างจำลองซ้ำ
        local cutPos = string.find(fallbackCode, "local Window = Library:Window")
        if cutPos then
            fallbackCode = string.sub(fallbackCode, 1, cutPos - 1) .. "\nreturn Library"
        end
        -- ตัวสำรองพังก็ห้ามทำให้สคริปต์ตาย (ระบบหลักเริ่มหลังส่วน UI)
        pcall(function()
            Library = loadstring(fallbackCode)()
        end)
    end
end

-- สร้างเมนูทั้งหมดในฟังก์ชันนี้ แล้วเรียกผ่าน pcall:
-- ถ้า UI พัง (GitHub ล่ม / library เปลี่ยน) บอทยังต้องทำงานต่อเบื้องหลังได้ ไม่งั้นสคริปต์ตายและรันซ้ำไม่ได้ (ติดตัวกันรันซ้อน)
local function buildUI()
    local Window = Library:Window({
        Logo = "77218680285262",
        FadeTime = 0.3,
    })

    local Watermark = Library:Watermark("King Legacy | Auto Fishing & Coordinator")
    local KeybindList = Library:KeybindList()

    -- สร้างหน้าต่างหลักแบบ 2 คอลัมน์ สะอาดตา จัดวางเป็นระเบียบ
    local FishingPage = Window:Page({Name = "Fishing", Columns = 2})
    local CombatPage = Window:Page({Name = "Combat", Columns = 2})
    local CoordinatorPage = Window:Page({Name = "Coordinator", Columns = 2})
    local MiscPage = Window:Page({Name = "Misc", Columns = 2})
    local SettingsPage = Library:CreateSettingsPage(Window, Watermark, KeybindList)

    ------------------------------------------------------------------
    -- TAB 1: FISHING (ตกปลา & น้ำวน)
    ------------------------------------------------------------------
    do
        local MainFishingSection = FishingPage:Section({Name = "Auto Fishing (ระบบตกปลา)", Side = 1}) do
            MainFishingSection:Toggle({
                Name = "Auto Fishing (เปิดบอทตกปลา)",
                Flag = "AutoFishingFlag",
                Default = CONFIG.AUTO_FISHING,
                Callback = function(v)
                    CONFIG.AUTO_FISHING = v
                end
            })

            MainFishingSection:Toggle({
                Name = "100% Perfect Win Solver",
                Flag = "AutoSolveFlag",
                Default = CONFIG.AUTO_SOLVE_MINIGAME,
                Callback = function(v)
                    CONFIG.AUTO_SOLVE_MINIGAME = v
                end
            })

            MainFishingSection:Toggle({
                Name = "Instant Win Bypass (ตั้ง progress เต็ม ชนะทันที)",
                Flag = "InstantWinFlag",
                Default = CONFIG.MINIGAME_INSTANT_WIN,
                Callback = function(v)
                    CONFIG.MINIGAME_INSTANT_WIN = v
                end
            })

            MainFishingSection:Slider({
                Name = "Instant Win Delay (รอก่อนชนะ)",
                Flag = "InstantWinDelayFlag",
                Min = 0,
                Max = 6,
                Default = CONFIG.MINIGAME_WIN_DELAY,
                Decimals = 0.1,
                Suffix = "s",
                Callback = function(v)
                    CONFIG.MINIGAME_WIN_DELAY = v
                end
            })

            MainFishingSection:Toggle({
                Name = "Auto Cast Rod (เหวี่ยงเบ็ดอัตโนมัติ)",
                Flag = "AutoCastFlag",
                Default = CONFIG.AUTO_CAST_ROD,
                Callback = function(v)
                    CONFIG.AUTO_CAST_ROD = v
                end
            })

            MainFishingSection:Toggle({
                Name = "Auto Close Popup (ปิดแจ้งเตือนของรางวัล)",
                Flag = "AutoClosePopupFlag",
                Default = CONFIG.AUTO_CLOSE_POPUP,
                Callback = function(v)
                    CONFIG.AUTO_CLOSE_POPUP = v
                    if not v then restorePopups() end
                end
            })

            MainFishingSection:Slider({
                Name = "Cast Cooldown (ดีเลย์เหวี่ยงเบ็ด)",
                Flag = "CastCooldownFlag",
                Min = 0.5,
                Max = 5.0,
                Default = CONFIG.CAST_COOLDOWN,
                Decimals = 0.1,
                Suffix = "s",
                Callback = function(v)
                    CONFIG.CAST_COOLDOWN = v
                end
            })

            MainFishingSection:Slider({
                Name = "Watchdog Timeout (ตัดค้างมินิเกม)",
                Flag = "MinigameTimeoutFlag",
                Min = 5,
                Max = 20,
                Default = CONFIG.MINIGAME_TIMEOUT,
                Decimals = 1,
                Suffix = "s",
                Callback = function(v)
                    CONFIG.MINIGAME_TIMEOUT = v
                end
            })

            local BtnRod = MainFishingSection:Button()
            BtnRod:Add("Equip Rod (สลับถือเบ็ด)", function()
                equipRod()
                Library:Notification("Fishing", "สลับถือเบ็ดตกปลาเรียบร้อย", 3)
            end)
        end

        local WhirlpoolSection = FishingPage:Section({Name = "Whirlpool & Sea (น้ำวน & ทะเล)", Side = 2}) do
            WhirlpoolSection:Toggle({
                Name = "Auto Whirlpool (บินไปตกน้ำวนอัตโนมัติ)",
                Flag = "AutoWhirlpoolFlag",
                Default = CONFIG.AUTO_WHIRLPOOL,
                Callback = function(v)
                    CONFIG.AUTO_WHIRLPOOL = v
                end
            })

            WhirlpoolSection:Toggle({
                Name = "Anti-Drown Platform (แท่นลอยน้ำนิรภัย)",
                Flag = "AntiDrownFlag",
                Default = CONFIG.ANTI_DROWN_PLATFORM,
                Callback = function(v)
                    CONFIG.ANTI_DROWN_PLATFORM = v
                    if not v then removeSafetyPlatform() end
                end
            })

            WhirlpoolSection:Slider({
                Name = "Platform Height (ความสูงแท่นลอย)",
                Flag = "PlatformHeightFlag",
                Min = 5,
                Max = 25,
                Default = CONFIG.PLATFORM_HEIGHT,
                Decimals = 1,
                Suffix = " studs",
                Callback = function(v)
                    CONFIG.PLATFORM_HEIGHT = v
                end
            })

            local BtnWhirlpool = WhirlpoolSection:Button()
            BtnWhirlpool:Add("Scan Whirlpool (ตรวจหาน้ำวน)", function()
                local pos, name = getWhirlpoolTarget()
                if pos then
                    Library:Notification("Whirlpool", string.format("พบคู่กรณี: %s", name), 4)
                else
                    Library:Notification("Whirlpool", "ไม่พบน้ำวนในเซิร์ฟเวอร์ขณะนี้", 3)
                end
            end)
        end
    end

    ------------------------------------------------------------------
    -- TAB 2: COMBAT (ล่าบอส & สกิล)
    ------------------------------------------------------------------
    do
        local BossSection = CombatPage:Section({Name = "Boss Hunting (ล่าบอส)", Side = 1}) do
            BossSection:Toggle({
                Name = "Auto Attack Boss (ตีบอสเอง - ปิดไว้ถ้าใช้ Maru Hub)",
                Flag = "AutoAttackBossFlag",
                Default = CONFIG.AUTO_ATTACK_BOSS,
                Callback = function(v)
                    CONFIG.AUTO_ATTACK_BOSS = v
                end
            })

            BossSection:Toggle({
                Name = "Auto Buso Haki (เปิดฮาคิเกราะ)",
                Flag = "AutoHakiFlag",
                Default = CONFIG.AUTO_BUSO_HAKI,
                Callback = function(v)
                    CONFIG.AUTO_BUSO_HAKI = v
                end
            })

            BossSection:Toggle({
                Name = "Aim Lock (ล็อคเป้าบอส 100%)",
                Flag = "AimLockFlag",
                Default = CONFIG.AIM_LOCK,
                Callback = function(v)
                    CONFIG.AIM_LOCK = v
                end
            })

            BossSection:Toggle({
                Name = "Noclip in Combat (ทะลุกำแพง/บอส)",
                Flag = "NoclipFlag",
                Default = CONFIG.NOCLIP_COMBAT,
                Callback = function(v)
                    CONFIG.NOCLIP_COMBAT = v
                end
            })

            BossSection:Slider({
                Name = "Hover Distance (ระยะลอยเหนือหัว)",
                Flag = "AttackDistFlag",
                Min = 10,
                Max = 35,
                Default = CONFIG.ATTACK_DISTANCE,
                Decimals = 1,
                Suffix = " studs",
                Callback = function(v)
                    CONFIG.ATTACK_DISTANCE = v
                end
            })

            BossSection:Slider({
                Name = "Attack Delay (ดีเลย์คลิกฟัน)",
                Flag = "AttackDelayFlag",
                Min = 0.05,
                Max = 0.5,
                Default = CONFIG.ATTACK_DELAY,
                Decimals = 0.01,
                Suffix = "s",
                Callback = function(v)
                    CONFIG.ATTACK_DELAY = v
                end
            })

            local BtnBossScan = BossSection:Button()
            BtnBossScan:Add("Scan Boss (ตรวจหาบอส)", function()
                local bName, _ = findBossInServer()
                if bName then
                    Library:Notification("Boss", string.format("พบบอส: %s ในเซิร์ฟนี้!", bName), 4)
                else
                    Library:Notification("Boss", "ไม่พบบอสเป้าหมายในเซิร์ฟเวอร์", 3)
                end
            end)
        end

        local WeaponSection = CombatPage:Section({Name = "Weapons & Skills (อาวุธ & สกิล)", Side = 2}) do
            WeaponSection:Dropdown({
                Name = "Preferred Sword (ดาบหลัก)",
                Flag = "PreferredSwordFlag",
                Items = {"Authentic Mace", "Kioru", "Acrodagger", "Muramasa", "Any Sword"},
                Default = CONFIG.PREFERRED_SWORD,
                Multi = false,
                Callback = function(v)
                    CONFIG.PREFERRED_SWORD = v
                end
            })

            WeaponSection:Toggle({
                Name = "Cycle Weapons (สลับอาวุธ 3 สาย)",
                Flag = "CycleWeaponsFlag",
                Default = CONFIG.CYCLE_WEAPONS,
                Callback = function(v)
                    CONFIG.CYCLE_WEAPONS = v
                end
            })

            WeaponSection:Slider({
                Name = "Cycle Delay (เวลาสลับอาวุธ)",
                Flag = "CycleDelayFlag",
                Min = 0.5,
                Max = 4.0,
                Default = CONFIG.WEAPON_CYCLE_DELAY,
                Decimals = 0.1,
                Suffix = "s",
                Callback = function(v)
                    CONFIG.WEAPON_CYCLE_DELAY = v
                end
            })

            WeaponSection:Toggle({
                Name = "Spam Skills (Z, X, C, V, B, E)",
                Flag = "SpamSkillsFlag",
                Default = CONFIG.AUTO_SPAM_SKILLS,
                Callback = function(v)
                    CONFIG.AUTO_SPAM_SKILLS = v
                end
            })

            local BtnWeapon = WeaponSection:Button()
            BtnWeapon:Add("Equip Combat Tool (ถืออาวุธสู้)", function()
                equipSword()
                Library:Notification("Combat", "สลับถืออาวุธต่อสู้เรียบร้อย", 3)
            end)
        end
    end

    ------------------------------------------------------------------
    -- TAB 3: COORDINATOR (เรียกเพื่อน & ตามเพื่อน)
    ------------------------------------------------------------------
    do
        local CallFriendSection = CoordinatorPage:Section({Name = "Call Friends (เรียกเพื่อน)", Side = 1}) do
            CallFriendSection:Toggle({
                Name = "Broadcast Boss (ส่งสัญญาณพบบอส)",
                Flag = "BroadcastBossFlag",
                Default = CONFIG.BROADCAST_BOSS,
                Callback = function(v)
                    CONFIG.BROADCAST_BOSS = v
                end
            })

            CallFriendSection:Toggle({
                Name = "Broadcast Whirlpool (ส่งสัญญาณพบน้ำวน)",
                Flag = "BroadcastWhirlpoolFlag",
                Default = CONFIG.BROADCAST_WHIRLPOOL,
                Callback = function(v)
                    CONFIG.BROADCAST_WHIRLPOOL = v
                end
            })

            CallFriendSection:Toggle({
                Name = "Signal Heartbeat (ต่ออายุสัญญาณ)",
                Flag = "SignalHeartbeatFlag",
                Default = CONFIG.SIGNAL_HEARTBEAT,
                Callback = function(v)
                    CONFIG.SIGNAL_HEARTBEAT = v
                end
            })

            CallFriendSection:Toggle({
                Name = "Block Hop Scripts (บล็อคสคริปต์ Hop)",
                Flag = "BlockHopFlag",
                Default = CONFIG.BLOCK_HOP_SCRIPTS,
                Callback = function(v)
                    CONFIG.BLOCK_HOP_SCRIPTS = v
                    if v then installHopBlockHooksWhenSafe() end
                end
            })

            local BtnClear = CallFriendSection:Button()
            BtnClear:Add("Clear Firebase Signal (ล้างสัญญาณ)", function()
                clearSignal(true) -- กดเองจากปุ่ม = ล้างทุกกรณี
                Library:Notification("Coordinator", "ล้างสัญญาณ Firebase เรียบร้อย", 3)
            end)
        end

        local FollowFriendSection = CoordinatorPage:Section({Name = "Follow Friends (ตามเพื่อน)", Side = 2}) do
            FollowFriendSection:Toggle({
                Name = "Auto Follow (วาร์ปตามเพื่อนอัตโนมัติ)",
                Flag = "AutoFollowFlag",
                Default = CONFIG.AUTO_FOLLOW_FRIENDS,
                Callback = function(v)
                    CONFIG.AUTO_FOLLOW_FRIENDS = v
                end
            })

            FollowFriendSection:Slider({
                Name = "Check Interval (ความถี่ตรวจสัญญาณ)",
                Flag = "CheckIntervalFlag",
                Min = 1,
                Max = 10,
                Default = CONFIG.CHECK_INTERVAL,
                Decimals = 1,
                Suffix = "s",
                Callback = function(v)
                    CONFIG.CHECK_INTERVAL = v
                end
            })

            FollowFriendSection:Slider({
                Name = "Signal Timeout (สัญญาณหมดอายุ)",
                Flag = "SignalTimeoutFlag",
                Min = 15,
                Max = 120,
                Default = CONFIG.SIGNAL_TIMEOUT,
                Decimals = 1,
                Suffix = "s",
                Callback = function(v)
                    CONFIG.SIGNAL_TIMEOUT = v
                end
            })

            local BtnCheckSignal = FollowFriendSection:Button()
            BtnCheckSignal:Add("Check Signal (เช็คสัญญาณเพื่อน)", function()
                local s = checkActiveSignal()
                if s then
                    Library:Notification("Friend Signal", string.format("เพื่อน '%s' พบ %s ที่ JobId: %s", tostring(s.finder), tostring(s.boss), tostring(s.jobId)), 5)
                else
                    Library:Notification("Friend Signal", "ยังไม่มีเพื่อนเครื่องอื่นส่งสัญญาณ", 3)
                end
            end)
        end
    end

    ------------------------------------------------------------------
    -- TAB 4: MISC (อื่นๆ & ข้อมูล)
    ------------------------------------------------------------------
    do
        local ProtectionSection = MiscPage:Section({Name = "Protection & Safety", Side = 1}) do
            ProtectionSection:Toggle({
                Name = "Anti-AFK (กันหลุด 20 นาที 24 ชม.)",
                Flag = "AntiAFKFlag",
                Default = CONFIG.ANTI_AFK,
                Callback = function(v)
                    CONFIG.ANTI_AFK = v
                end
            })

            ProtectionSection:Toggle({
                Name = "Death Recovery (เกิดใหม่กลับมารุมตี)",
                Flag = "DeathRecoveryFlag",
                Default = CONFIG.DEATH_RECOVERY,
                Callback = function(v)
                    CONFIG.DEATH_RECOVERY = v
                end
            })

            local BtnTest = ProtectionSection:Button()
            BtnTest:Add("Test Notification (ทดสอบแจ้งเตือน)", function()
                Library:Notification("Test", "Scoot UI ทำงานได้สมบูรณ์แบบ 100%!", 3)
            end)
        end

        local InfoSection = MiscPage:Section({Name = "Server & Player Info", Side = 2}) do
            local BtnCopyJob = InfoSection:Button()
            BtnCopyJob:Add("Copy JobId (คัดลอกรหัสเซิร์ฟเวอร์)", function()
                if setclipboard then
                    setclipboard(tostring(game.JobId))
                    Library:Notification("Clipboard", "คัดลอก JobId ลงคลิปบอร์ดแล้ว!", 3)
                else
                    Library:Notification("JobId", tostring(game.JobId), 6)
                end
            end)

            BtnCopyJob:Add("Rejoin Server (รีจอยน์เซิร์ฟนี้)", function()
                -- กดเองจากปุ่ม ต้องไม่โดน Block Hop Scripts บล็อค
                bypassHopBlock = true
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
                end)
                task.delay(10, function() bypassHopBlock = false end)
            end)
        end
    end

    Library:Notification("Loaded!", "King Legacy Auto-Fisher & Coordinator พร้อมใช้งาน (กด Ctrl ขวา เปิด/ปิดเมนู)", 4)

    -- ซ่อนเมนูหลังโหลดเสร็จ: หน้าต่างบังปุ่ม ENTER GAME และ library ซ่อนเมาส์ตอนเมนูเปิด
    -- เปิด/ปิดด้วย Ctrl ขวา (Library.MenuKeybind ของ Scoot ค่าเริ่มต้นคือ RightControl)
    -- Window:SetOpen ไม่รับคำสั่งระหว่างเฟดเปิด (Debounce ใน library) -> ลองซ้ำจนปิดได้จริง
    pcall(function() Library.MenuKeybind = tostring(Enum.KeyCode.RightControl) end)
    if type(Window.SetOpen) == "function" then
        task.spawn(function()
            for _ = 1, 20 do
                task.wait(0.25)
                pcall(function() Window:SetOpen(false) end)
                if Window.IsOpen == false then
                    print("[KL-Fisher] 🙈 ซ่อนเมนูแล้ว (กด Ctrl ขวา เพื่อเปิด/ปิด)")
                    break
                end
            end
        end)
    end
end

if not Library then
    warn("[KL-Fisher] ❌ ไม่สามารถโหลด Scoot UI Library ได้! ตัวบอทจะทำงานในโหมดเบื้องหลัง (Console Only)")
else
    local uiOk, uiErr = pcall(buildUI)
    if not uiOk then
        warn("[KL-Fisher] ❌ สร้างเมนูไม่สำเร็จ: " .. tostring(uiErr) .. " -> บอททำงานต่อในโหมดเบื้องหลัง (Console Only)")
    end
end

----------------------------------------------------------------------
-- 14. SUPERVISOR RUNNER (รันเบื้องหลัง 24 ชม.)
----------------------------------------------------------------------
pcall(function()
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(2)
        -- ถือเบ็ดเองเฉพาะตอนเราตกปลาเอง (ปกติ Maru Hub เป็นคนเลือกของในมือ)
        if CONFIG.AUTO_FISHING then
            equipRod()
        end
    end)
end)

local function supervisor()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    pcall(function() char:WaitForChild("HumanoidRootPart", 10) end)
    task.wait(2)

    -- ตัวรองในโหมดคิว: ไม่ตกปลา / ไม่ตี / ไม่ hook อะไร สำรวจเซิร์ฟ -> ใส่คิว -> ย้ายต่อ (วนจนกว่าจะย้ายสำเร็จ)
    if IS_SCOUT then
        runScout()
        return
    end

    setupAutoFishingSolver()
    if CONFIG.AUTO_FISHING then
        equipRod()
    end

    -- ซิงค์เวลากับ Firebase ตอนเริ่ม และทุก 10 นาที
    task.spawn(function()
        while true do
            calibrateServerTime()
            task.wait(600)
        end
    end)

    -- มาถึงเซิร์ฟเพื่อนแล้วหรือยัง: สัญญาณใน Firebase ชี้มาที่ JobId นี้ และคนเจอไม่ใช่เรา -> log ว่ามาถึงแล้ว
    task.spawn(function()
        if CONFIG.QUEUE_MODE then return end -- โหมดคิวไม่ใช้ช่อง signal (มี log มาถึงของคิวแยกด้านล่าง)
        task.wait(3)
        local data = httpGet(CONFIG.FIREBASE_URL)
        if not (type(data) == "table" and tostring(data.jobId) == tostring(game.JobId)
            and tostring(data.finder) ~= LocalPlayer.Name) then
            return
        end

        -- มาถึงช้า: คนเจอตีจบแล้ว/เขียน "จบแล้ว" ไปแล้ว -> ไม่ต้องยืนรอ ย้ายเลย
        if data.status ~= "active" then
            postCoordLog(string.format("⌛ **%s** มาถึงเซิร์ฟของ **%s** ช้าไป (จบไปแล้ว) → ย้ายเซิร์ฟใหม่", LocalPlayer.Name, tostring(data.finder)))
            markSkipJob(game.JobId, 30 * 60)
            hopToNewServer(string.format("มาถึงเซิร์ฟของ %s ช้าไป", tostring(data.finder)))
            return
        end

        print(string.format("[KL-Fisher] ✅ มาถึงเซิร์ฟของ '%s' แล้ว", tostring(data.finder)))
        postCoordLog(string.format("✅ **%s** มาถึงเซิร์ฟของ **%s** แล้ว (%s) — ในเซิร์ฟมี %d คน",
            LocalPlayer.Name, tostring(data.finder), targetLabel(data.targetType, data.boss), #Players:GetPlayers()))

        -- มาถึงแล้วแต่ไม่มีอะไรให้ทำ (บอสตายแล้ว / น้ำวนหาย / คนเจอหลุด) -> สัญญาณชี้มาเซิร์ฟเรา เลยถูกนับเป็นของเรา
        -- ไม่มีใครพาออก (Maru ย้ายเซิร์ฟไม่ได้บนเน็ตนี้) -> รอ 45 วิ ถ้ายังว่างเปล่าให้ย้ายเอง
        task.wait(45)
        local nothingHere = not maruBossName and os.clock() >= bossIncomingUntil and not findBossInServer()
            and getWhirlpoolTarget() == nil and not isHoppingServer and not isTeleportingToFriend
        if nothingHere then
            postCoordLog(string.format("🫥 **%s** อยู่เซิร์ฟของ **%s** แล้ว 45 วิ ไม่มีบอสหรือน้ำวน → ย้ายเซิร์ฟใหม่", LocalPlayer.Name, tostring(data.finder)))
            markSkipJob(game.JobId, 30 * 60)
            hopToNewServer("มาถึงแล้วไม่มีบอสหรือน้ำวน")
        end
    end)

    -- บอสโผล่ใน SeaMonster ปุ๊บ -> เรียกเพื่อน + หยิบดาบทันที ไม่รอรอบเช็คของลูปหลัก (อาจค้างหลายวิตอนเหวี่ยงเบ็ด/หยิบเบ็ด)
    -- สำคัญกับ Drakenfyr / Abyssal Tyrant ที่ไม่มีสัญญาณล่วงหน้าแบบ WhirlpoolBeast: ยิ่งเร็วยิ่งมีโอกาสหยิบดาบก่อนเข้าไฟต์
    task.spawn(function()
        local seaMonster = workspace:WaitForChild("SeaMonster", 60)
        if not seaMonster then return end
        seaMonster.ChildAdded:Connect(function(model)
            if CONFIG.AUTO_ATTACK_BOSS or not model:IsA("Model") then return end
            local lowerName = string.lower(model.Name)
            local isTarget = false
            for _, targetName in ipairs(CONFIG.TARGET_BOSSES) do
                if string.find(lowerName, string.lower(targetName), 1, true) then
                    isTarget = true
                    break
                end
            end
            if not isTarget then return end
            -- รอโมเดลโหลด Humanoid/HP ก่อน (findBossInServer ต้องเห็นว่ามีชีวิต) สูงสุด 5 วิ
            for _ = 1, 25 do
                local foundName = findBossInServer()
                if foundName then
                    print(string.format("[KL-Fisher] ⚡ บอส '%s' โผล่แล้ว -> เรียกเพื่อน + หยิบดาบทันที", bossDisplayName(foundName)))
                    handBossToMaru(foundName)
                    return
                end
                task.wait(0.2)
            end
        end)
    end)

    -- เซิร์ฟมีน้ำวน / บอส / บอสกำลังจะเกิด -> เปิดตัวกันย้ายเซิร์ฟ (ติดตั้ง hook ตอนนี้ ไม่ใช่ตอนเริ่ม ให้ Maru โหลดผ่านก่อน)
    task.spawn(function()
        while not hopHooksInstalled do
            task.wait(2)
            if CONFIG.HOLD_SERVER_AT_WHIRLPOOL_BOSS or CONFIG.BLOCK_HOP_SCRIPTS then
                local needHold = maruBossName ~= nil or isFightingBoss or os.clock() < bossIncomingUntil
                    or getWhirlpoolTarget() ~= nil or findBossInServer() ~= nil
                if needHold then
                    installHopBlockHooksWhenSafe()
                end
            end
        end
    end)

    if CONFIG.QUEUE_MODE then
        -- มาถึงเซิร์ฟที่ดึงจากคิวแล้ว -> log ว่าเจออะไร (ไม่มีอะไรแล้ว = จดข้ามไว้ ตัวเช็คคิวด้านล่างพาไปอันถัดไปเอง)
        task.spawn(function()
            local target = nil
            pcall(function()
                if isfile and readfile and isfile(QUEUE_TARGET_FILE) then
                    target = HttpService:JSONDecode(readfile(QUEUE_TARGET_FILE))
                    if writefile then writefile(QUEUE_TARGET_FILE, "{}") end
                end
            end)
            if type(target) ~= "table" or target.jobId ~= game.JobId then return end
            mainFind.arrivedFrom = target.scout -- ตามของตัวหลักอีกตัวมา -> ไม่ใส่คิวเซิร์ฟนี้ทับ
            task.wait(8)
            local followedLeader = target.type == "Party"
            local bossName = findBossInServer()
            local status
            if bossName or maruBossName then
                status = "เจอ " .. targetLabel("Boss", bossName or maruBossName) .. " → ตีเลย"
            elseif getWhirlpoolTarget() ~= nil then
                status = "เจอ 🌊 น้ำวน → ตกปลาเรียก Serpent"
            elseif followedLeader then
                status = "ยังไม่มีบอส/น้ำวน → อยู่กับหัวหน้า รอเซิร์ฟถัดไป"
            else
                status = "ไม่มีอะไรแล้ว (ถูกตีจบ / น้ำวนหาย) → ดึงเซิร์ฟถัดไปจากคิว"
                markSkipJob(game.JobId, 30 * 60)
            end
            if followedLeader then
                print(string.format("[KL-Fisher] 👥 มาถึงเซิร์ฟเดียวกับหัวหน้าแล้ว: %s", status))
                postCoordLog(string.format("👥 **%s** มาถึงเซิร์ฟเดียวกับ **%s** แล้ว — %s",
                    LocalPlayer.Name, tostring(target.scout), status))
            else
                print(string.format("[KL-Fisher] ✅ มาถึงเซิร์ฟจากคิวแล้ว: %s", status))
                postCoordLog(string.format("✅ **%s** มาถึงเซิร์ฟจากคิว (ที่ **%s** เจอ) — %s",
                    LocalPlayer.Name, tostring(target.scout), status))
            end
        end)

        if MAIN_INDEX then
            -- ตัวหลัก: กัน Maru (SerpentHop) ย้ายเซิร์ฟตลอด (ติดตั้ง hook หลัง Maru โหลดผ่านแล้ว / หรือครบ 60 วิ)
            task.spawn(function()
                while not installHopBlockHooksWhenSafe() do task.wait(2) end
            end)
        end

        if party.isLeader() and CONFIG.PARTY_ALWAYS_TOGETHER then
            -- หัวหน้า: เขียนเซิร์ฟที่อยู่ตอนนี้ (มาถึงจากการสุ่มย้าย ตัวตามจะได้รู้) และต่ออายุทุก PARTY_HEARTBEAT วิ
            task.spawn(function()
                task.wait(3)
                while true do
                    if not isHoppingServer then
                        party.publish(game.JobId, maruBossName and bossDisplayName(maruBossName) or "เซิร์ฟที่หัวหน้าอยู่")
                    end
                    task.wait(tonumber(CONFIG.PARTY_HEARTBEAT) or 120)
                end
            end)
        end

        -- ตัวหลักว่าง (ไม่มีบอส / WhirlpoolBeast ยังไม่ติด):
        --   PARTY_ALWAYS_TOGETHER = false -> ทุกตัวเช็คคิวเอง (บอสที่ตัวหลักอีกตัวเจอก็มาทางคิวนี้)
        --   หัวหน้า -> เช็คคิวเรื่อย ๆ มีเซิร์ฟก็ไปเลย
        --   ตัวตาม -> หัวหน้าอยู่เซิร์ฟอื่น ตามไป / ไม่มีเซิร์ฟของปาร์ตี้ที่ยังสด (หัวหน้าออฟไลน์) -> เช็คคิวเองแทน
        task.spawn(function()
            while true do
                task.wait(tonumber(CONFIG.QUEUE_POLL_INTERVAL) or 5)
                if not queueStepRunning and not mainBusyHere() then
                    if party.isLeader() or not CONFIG.PARTY_ALWAYS_TOGETHER then
                        runQueueStep(false)
                    else
                        local target = party.fetch()
                        if target then
                            if target.jobId ~= game.JobId and not isSkippedJob(target.jobId) then
                                party.follow(target)
                            end
                        else
                            runQueueStep(false)
                        end
                    end
                end
            end
        end)
    end

    -- Background Signal Watcher คอยฟัง Firebase แบบ Realtime
    task.spawn(function()
        while true do
            task.wait(CONFIG.CHECK_INTERVAL)
            if CONFIG.AUTO_FOLLOW_FRIENDS and not isFightingBoss and not isTeleportingToFriend then
                local signal = checkActiveSignal()
                if signal and signal.jobId and game.JobId ~= signal.jobId then
                    followFriend(signal)
                end
            end
        end
    end)
    
    -- Main Worker Cycle
    while true do
        local ok, err = pcall(function()
            runFishingCycle()
        end)
        if not ok then
            warn("[KL-Fisher] ⚠️ ข้อผิดพลาดในรอบการทำงาน: " .. tostring(err))
            removeSafetyPlatform()
            isSolvingFishing = false
            task.wait(2)
        end
        task.wait(0.5)
    end
end

----------------------------------------------------------------------
-- 15. DROP ALERT (ได้ของดรอปในรายการ -> แจ้ง Discord)
----------------------------------------------------------------------
-- ยังไม่รู้ว่าเกมแจ้งของดรอปทางไหน (rbxlua ปิดอยู่ตอนเขียน ตรวจ GUI สดไม่ได้) -> ดักหลายทาง:
--   1) ข้อความบนจอที่ "เพิ่งเปลี่ยน/เพิ่งโผล่" และมองเห็นอยู่ (popup / แจ้งเตือน) ยกเว้นหน้ากระเป๋า (มีชื่อไอเทมอยู่แล้ว)
--   2) แชท: ข้อความระบบ หรือข้อความที่มีชื่อไอดีนี้ + ชื่อไอเทม (ประกาศของหายากทั้งเซิร์ฟ)
--   3) หน้ากระเป๋าเกม: ปุ่มชื่อไอเทมโผล่ใหม่ / ตัวเลขจำนวนในปุ่มเพิ่มขึ้น
-- ไอเทมเดียวกันแจ้งซ้ำได้ทุก 60 วิ / 15 วิแรกหลังเข้าเซิร์ฟไม่แจ้ง (GUI สร้างใหม่ทั้งหมด)
do
    local dropItems = CONFIG.DROP_ALERT_ITEMS or {}
    local webhook = CONFIG.DROP_ALERT_WEBHOOK_URL
    if CONFIG.DROP_ALERT and httpRequest and webhook and webhook ~= "" and #dropItems > 0 and not IS_SCOUT then
        local lastAlertAt = {}
        local watchStartedAt = os.clock()

        local function matchDropItem(text)
            local lower = string.lower(tostring(text or ""))
            if lower == "" then return nil end
            for _, item in ipairs(dropItems) do
                if string.find(lower, string.lower(item), 1, true) then return item end
            end
            return nil
        end

        local function sendDropAlert(item, source, detail)
            if os.clock() - watchStartedAt < 15 then return end
            if lastAlertAt[item] and os.clock() - lastAlertAt[item] < 60 then return end
            lastAlertAt[item] = os.clock()
            local cleanDetail = string.sub(string.gsub(tostring(detail or ""), "<[^>]+>", ""), 1, 200) -- ตัด RichText tag
            print(string.format("[KL-Fisher] 🎁 ได้ '%s' (%s): %s", item, source, cleanDetail))
            local payload = {
                username = "KL-Drop",
                content = string.format("🎁 **%s** ได้ **%s** !", LocalPlayer.Name, item),
                embeds = { {
                    title = "🎁 " .. item,
                    color = 15844367,
                    fields = {
                        { name = "ไอดี", value = LocalPlayer.Name, inline = true },
                        { name = "บอสล่าสุด", value = bossDisplayName(maruBossName or "-"), inline = true },
                        { name = "จับได้จาก", value = source, inline = true },
                        { name = "ข้อความในเกม", value = cleanDetail ~= "" and cleanDetail or "-" },
                        { name = "JobId", value = "```" .. tostring(game.JobId) .. "```" },
                    },
                    timestamp = DateTime.now():ToIsoDate(),
                } },
            }
            task.spawn(function()
                for attempt = 1, 3 do -- ของหายาก ห้ามพลาด: ส่งไม่สำเร็จลองใหม่ 3 ครั้ง
                    local ok, response = pcall(function()
                        return httpRequest({
                            Url = webhook,
                            Method = "POST",
                            Headers = { ["Content-Type"] = "application/json" },
                            Body = HttpService:JSONEncode(payload)
                        })
                    end)
                    local status = ok and response and response.StatusCode
                    if status == 200 or status == 204 then return end
                    task.wait(5 * attempt)
                end
                warn(string.format("[KL-Fisher] ⚠️ ส่งแจ้งเตือน '%s' เข้า Discord ไม่สำเร็จ", item))
            end)
        end

        -- 1) ข้อความบนจอ
        local playerGui = LocalPlayer:WaitForChild("PlayerGui")
        local function isShownOnScreen(obj)
            local node = obj
            while node and node ~= playerGui do
                if node:IsA("GuiObject") and not node.Visible then return false end
                if node:IsA("LayerCollector") and not node.Enabled then return false end
                node = node.Parent
            end
            return node == playerGui
        end
        local function isInventoryText(obj)
            local mainGui = playerGui:FindFirstChild("MainGui")
            local starter = mainGui and mainGui:FindFirstChild("StarterFrame")
            local inventory = starter and starter:FindFirstChild("Inventory_Frame")
            return inventory ~= nil and obj:IsDescendantOf(inventory)
        end
        local function checkLabel(obj)
            local item = matchDropItem(obj.Text)
            if item and not isInventoryText(obj) and isShownOnScreen(obj) then
                sendDropAlert(item, "ข้อความบนจอ (" .. obj:GetFullName() .. ")", obj.Text)
            end
        end
        local function watchLabel(obj)
            if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
            obj:GetPropertyChangedSignal("Text"):Connect(function() checkLabel(obj) end)
            obj:GetPropertyChangedSignal("Visible"):Connect(function() checkLabel(obj) end)
            task.defer(checkLabel, obj) -- เพิ่งโผล่: เกมมักตั้งข้อความหลังใส่ลงจอ
        end
        playerGui.DescendantAdded:Connect(watchLabel)
        for _, obj in ipairs(playerGui:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                obj:GetPropertyChangedSignal("Text"):Connect(function() checkLabel(obj) end)
                obj:GetPropertyChangedSignal("Visible"):Connect(function() checkLabel(obj) end)
            end
        end

        -- 3) หน้ากระเป๋าเกม: ปุ่มไอเทมชื่อตรงกับไอเทม (เช่น Inventory_Frame.ScrollingFrameMaterial.Pebblefish จาก dump 23 ต.ค.)
        --    ปุ่มโผล่ใหม่ = เพิ่งได้ชิ้นแรก / ตัวเลขในปุ่มเพิ่มขึ้น = ได้เพิ่ม (รายการอาจยังว่างจนกว่าจะเปิดกระเป๋าครั้งแรก)
        local function itemCount(button)
            local best = nil
            for _, obj in ipairs(button:GetDescendants()) do
                if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    local num = tonumber(string.match(string.gsub(obj.Text, ",", ""), "(%d+)"))
                    if num and (not best or num > best) then best = num end
                end
            end
            return best
        end
        local function watchInventoryButton(button)
            local item = nil
            for _, name in ipairs(dropItems) do
                if string.lower(button.Name) == string.lower(name) then item = name break end
            end
            if not item or not button:IsA("GuiObject") then return end
            local lastCount = itemCount(button)
            if os.clock() - watchStartedAt >= 15 then
                sendDropAlert(item, "กระเป๋า: ได้ชิ้นแรก", button:GetFullName())
            end
            button.DescendantAdded:Connect(function() task.defer(function()
                local count = itemCount(button)
                if count and lastCount and count > lastCount then
                    sendDropAlert(item, "กระเป๋า: จำนวนเพิ่ม", string.format("%d → %d", lastCount, count))
                end
                lastCount = count or lastCount
            end) end)
            for _, obj in ipairs(button:GetDescendants()) do
                if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    obj:GetPropertyChangedSignal("Text"):Connect(function()
                        local count = itemCount(button)
                        if count and lastCount and count > lastCount then
                            sendDropAlert(item, "กระเป๋า: จำนวนเพิ่ม", string.format("%d → %d", lastCount, count))
                        end
                        lastCount = count or lastCount
                    end)
                end
            end
        end
        task.spawn(function()
            local mainGui = playerGui:WaitForChild("MainGui", 30)
            local starter = mainGui and mainGui:WaitForChild("StarterFrame", 30)
            local inventory = starter and starter:WaitForChild("Inventory_Frame", 30)
            if not inventory then return end
            inventory.DescendantAdded:Connect(watchInventoryButton)
            for _, obj in ipairs(inventory:GetDescendants()) do
                watchInventoryButton(obj)
            end
        end)

        -- 2) แชท: ข้อความระบบ (ไม่มีคนพิมพ์) หรือข้อความที่มีชื่อไอดีนี้
        local function checkChat(text, isSystem)
            local item = matchDropItem(text)
            if not item then return end
            local lower = string.lower(tostring(text))
            local mentionsMe = string.find(lower, string.lower(LocalPlayer.Name), 1, true)
                or string.find(lower, string.lower(LocalPlayer.DisplayName), 1, true)
            if mentionsMe or isSystem then
                sendDropAlert(item, isSystem and "แชทระบบ" or "แชท", text)
            end
        end
        pcall(function()
            TextChatService.MessageReceived:Connect(function(message)
                checkChat(message.Text, message.TextSource == nil)
            end)
        end)
        pcall(function()
            local events = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            local filtered = events and events:FindFirstChild("OnMessageDoneFiltering")
            if filtered then
                filtered.OnClientEvent:Connect(function(data)
                    if type(data) == "table" then
                        checkChat(data.Message, data.FromSpeaker == nil or data.MessageType == "System")
                    end
                end)
            end
        end)
        print(string.format("[KL-Fisher] 🎁 เปิดแจ้งเตือนของดรอป: %s", table.concat(dropItems, ", ")))
    end
end

task.spawn(supervisor)
