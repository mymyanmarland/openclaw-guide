# 08 — Browser Control

Agent ကို browser ထိန်းခိုင်းနည်း ၂ ခု ရှိတယ်။

## 1. Managed profile `openclaw`
OpenClaw က သူ့ဟာသူ ထိန်းတဲ့ Chromium ဖြစ်သည်။ ကိုယ့် personal browser နဲ့ မရောဘူး။

```bash
openclaw browser install
openclaw browser --browser-profile openclaw start
openclaw browser --browser-profile openclaw open https://example.com
openclaw browser --browser-profile openclaw snapshot
```

## 2. Extension relay `chrome`
ကိုယ့် Chrome tab ကို agent က ထိန်းတာဖြစ်သည်။
Extension ကို install လုပ်ပါ။ Developer mode ဖွင့်ပြီး Load unpacked လုပ်ပါ။
Extension icon ကို နှိပ်ပြီး tab ကို attach လုပ်ပါ။ badge က ON ပြရင် ရပြီ။
Agent က attach လုပ်ထားတဲ့ tab ကိုပဲ ထိန်းတယ်။ တခြား tab ကို မထိဘူး။

VPS Gateway + PC browser ချိတ်နည်း။
- VPS မှာ Gateway run တယ်။
- PC မှာ node host / browser relay run တယ်။
- နှစ်ခုကြားကို Tailscale သို့မဟုတ် SSH tunnel နဲ့ ချိတ်တယ်။
- Login ထားတဲ့ session ပါတဲ့ tab ကို သုံးရင် သီးသန့် Chrome profile ကို သုံးပါ။ personal profile ကို မသုံးပါနဲ့။
