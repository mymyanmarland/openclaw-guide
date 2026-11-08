# 03 — Custom Base URL

## Wizard နည်း
`openclaw onboard --classic --install-daemon` မှာ Custom Provider ကို ရွေးပါ။
Compatibility ကို OpenAI-compatible လို့ ရွေးပါ။
Base URL, API key, Model ID ကို ထည့်ပါ။

## Config နည်း
`~/.openclaw/openclaw.json` ထဲမှာ provider ကို ရေးပါ။

- OpenAI ပုံစံ provider မှာ base URL က `/v1` နဲ့ ဆုံးရတယ်။ ဥပမာ `https://api.example.com/v1`
- `/v1/chat/completions` အထိ အပြည့်မရေးပါနဲ့။
- Ollama လို provider မှာ `/v1` မပါတဲ့ လိပ်စာ သုံးရတယ်။ ဥပမာ `http://127.0.0.1:11434` — ဒါက ခြွင်းချက် ဖြစ်သည်။

Provider ပြောင်းနည်း။ `agents.defaults.model.primary` ကို `provider/model-id` ပုံစံ ပြောင်းပါ။
ဥပမာ `myprovider/your-model-id`။

## စမ်းသပ်ချက်
- 401 ဆိုရင် key မှားတယ်။
- 404 ဆိုရင် base URL မှားတယ်။
- key ပြောင်းပြီးရင် auth profile ကိုလည်း ပြန်စစ်ပါ။ config ပြောင်းရုံနဲ့ တချို့ tool တွေ key အဟောင်း ကို သုံးနေတတ်တယ်။
