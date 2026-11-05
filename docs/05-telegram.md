# 05 — Telegram Bot

1. Telegram မှာ @BotFather ကို ဖွင့်ပါ။ `/newbot` လို့ ပို့ပါ။ bot နာမည် ပေးပါ။ token ကို ရယူပါ။
2. OpenClaw မှာ channel ထည့်ပါ။

```bash
openclaw channels add --channel telegram --token "YOUR_BOT_TOKEN"
openclaw gateway restart
openclaw channels status --probe
```

3. Bot ကို Telegram မှာ စာပို့ပါ။ pairing code ရရင် approve လုပ်ပါ။

```bash
openclaw pairing list telegram
openclaw pairing approve telegram <PAIRING-CODE>
```

Pairing code က ၁ နာရီ အတွင်း သက်တမ်းကုန်တယ်။ Token ကို ဘယ်သူနဲ့မှ မမျှပါနဲ့။
