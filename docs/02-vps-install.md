# 02 — VPS ပေါ် Install

လိုအပ်ချက်။ Ubuntu/Debian VPS, Node 24.16+ သို့မဟုတ် 26.1+ (installer က လိုရင် Node ကို သူ့ဟာသူ ထည့်ပေးတယ်)။

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
openclaw onboard --classic --install-daemon
openclaw gateway status
openclaw dashboard
```

`--install-daemon` က systemd user service အနေနဲ့ တင်ပေးတယ်။ reboot လုပ်လည်း ပြန် run တယ်။
Gateway ကို foreground မှာ စမ်းချင်ရင် `openclaw gateway --port 18789` လို့ run ပါ။
