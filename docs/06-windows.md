# 06 — Windows

လမ်းကြောင်း ၃ ခု ရှိတယ်။

## 1. Windows Hub (အလွယ်ဆုံး)
Native Windows app ဖြစ်သည်။ admin မလိုဘဲ install လုပ်လို့ရတယ်။ tray, chat, node mode ပါတယ်။

## 2. PowerShell native CLI
```powershell
iwr -useb https://openclaw.ai/install.ps1 | iex
openclaw onboard --install-daemon
openclaw dashboard
```

## 3. WSL2
Linux နဲ့ အတူဆုံး runtime လိုချင်ရင် WSL2 ထဲမှာ Linux install နည်းအတိုင်း တင်ပါ။
Gateway service က systemd user unit အနေနဲ့ run တယ်။
