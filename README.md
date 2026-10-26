# King Legacy - Auto Fishing

วางใน executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/LilSky1/king-legacy/main/main.lua"))()
```

ย้ายเซิร์ฟแล้วสคริปต์รันต่อเอง (executor ต้องมี `queue_on_teleport`)

## ตั้งค่าเพิ่ม (ไม่ใส่ก็ได้)

ใส่ไว้บรรทัดก่อน `loadstring` เช่นแจ้งเตือน Discord ตอนเจอบอส / ได้ของดรอป:

```lua
getgenv().KL_CONFIG = {
    DISCORD_WEBHOOK_URL = "",            -- เจอบอส
    DISCORD_WHIRLPOOL_WEBHOOK_URL = "",  -- เจอน้ำวน
    DROP_ALERT_WEBHOOK_URL = "",         -- ได้ Acromask / Acrodagger / Serpent Heart / Serpent Fin
}
loadstring(game:HttpGet("https://raw.githubusercontent.com/LilSky1/king-legacy/main/main.lua"))()
```

ระบบคิวหลายไอดี (ตัวรองหาเซิร์ฟ ตัวหลักไปตี) ต้องมี Firebase Realtime Database ของตัวเอง:
ใส่ `FIREBASE_URL = "https://<project>.firebasedatabase.app/signal.json"` และ `MAIN_ACCOUNTS = { "ชื่อไอดีตัวหลัก" }`
ไม่ใส่ Firebase = ตกปลาอย่างเดียว ไม่มีระบบคิว
