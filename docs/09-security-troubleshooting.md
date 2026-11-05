# 09 — လုံခြုံရေး နဲ့ ပြဿနာဖြေရှင်းနည်း

## လုံခြုံရေး checklist
- [ ] port 18789 public မဖွင့်ထားဘူး။
- [ ] `~/.openclaw/openclaw.json` backup ရှိတယ်။ permission 600 ဖြစ်သည်။
- [ ] API key, bot token ကို GitHub / chat / screenshot ထဲမှာ မတင်ထားဘူး။
- [ ] Telegram pairing / device approval ကို ကိုယ်တိုင် approve လုပ်တယ်။

## ပြဿနာဖြေရှင်းနည်း
- `openclaw: command not found` — terminal ကို ပြန်ဖွင့်၊ PATH ကို စစ်ပါ။
- Gateway မတက်ဘူး — `openclaw gateway status`၊ `openclaw doctor` လို့ စစ်ပါ။
- Telegram မချိတ်ဘူး — `openclaw channels status --probe`၊ token နဲ့ pairing ကို စစ်ပါ။
- Model 401 — key မှားတယ်။ Model 404 — base URL မှားတယ်။
- Dashboard မပွင့်ဘူး — tunnel တက်နေလား၊ `127.0.0.1` ကို သုံးနေလား စစ်ပါ။
