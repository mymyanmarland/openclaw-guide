# 07 — Linux နဲ့ VM

Linux desktop မှာ Linux install နည်းအတိုင်း တင်ပါ။
VM မှာ သီးသန့် version မလိုဘူး။ VM ထဲက OS က Windows ဆိုရင် Windows နည်း၊ Linux ဆိုရင် Linux နည်းကို သုံးပါ။

VM သုံးရင် သတိထားစရာ။
- VM ကို snapshot ယူထားပါ။ Install မလုပ်ခင် snapshot ယူရင် ပြန်လည် လွယ်တယ်။
- Network ကို စစ်ပါ။ Gateway ကို အဝေးက ဖွင့်ချင်ရင် SSH tunnel သို့မဟုတ် Tailscale ကို သုံးပါ။ port 18789 ကို public မဖွင့်ပါနဲ့။
- VM ပိတ်ရင် Gateway ရပ်တယ်။ 24/7 လိုချင်ရင် VM ကို အမြဲ run ထားရမယ်။
