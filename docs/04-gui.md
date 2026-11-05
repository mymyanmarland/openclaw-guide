# 04 — GUI (Control UI)

Local မှာ `openclaw dashboard` လို့ run ရင် `http://127.0.0.1:18789/` ပွင့်တယ်။
အဲဒီမှာ chat လုပ်လို့ရတယ်။ session, config, channel ကို စစ်လို့ရတယ်။

VPS ကို အဝေးကနေ သုံးနည်း ၄ ခု။
1. SSH tunnel: `ssh -L 18789:127.0.0.1:18789 user@your-server-ip` ပြီးရင် local browser မှာ `http://127.0.0.1:18789` ဖွင့်ပါ။
2. nginx subdomain + HTTPS + basic auth။
3. Tailscale။
4. Telegram Mini App `/controlui` (တချို့ version မှာ)။

သတိ။ port 18789 ကို firewall မှာ public ဖွင့်တာ ဘယ်တော့မှ မလုပ်ပါနဲ့။
