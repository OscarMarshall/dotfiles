# AI chat

Open WebUI is a chat interface for the local AI models running on the server. It works like ChatGPT — type a message,
get a reply — but everything runs on the home server; nothing is sent to any cloud service.

**Address:** <https://ai.@domain@>

## Using the chat

1. Go to <https://ai.@domain@> and sign in with your account.
2. Click **New chat** (top left).
3. Pick a model from the dropdown at the top of the chat window.
4. Type your message and press **Enter** (or click the send button).

### Choosing a model

Each model has different strengths. The dropdown shows which models are currently installed; the server has no GPU, so
smaller models reply faster.

- **General questions and writing** — any model works; start with the smallest one that gives good answers.
- **Code** — look for a model with "coder" in its name (e.g. `qwen2.5-coder`).
- **Step-by-step reasoning** — look for one with "r1" or "thinking" in its name (e.g. `deepseek-r1`).

!!! tip "Adding models"

    @admin@ can add more models. If a model you want isn't listed, ask and it can be pulled with `ollama pull <name>`.
    Browse available models at [ollama.com/library](https://ollama.com/library).

## Using from an app or script

The server exposes an **OpenAI-compatible API** at `https://ollama.@host_name@.@domain@`. Any app that supports a custom
OpenAI endpoint works with it.

- **Base URL:** `https://ollama.@host_name@.@domain@`
- **API key:** an HTTP Basic Auth credential — ask @admin@ for yours.
- **Model name:** use the Ollama model name exactly as shown in the chat dropdown (e.g. `qwen3:4b`).

### Continue.dev (VS Code / JetBrains)

1. Open the Continue config (`~/.continue/config.yaml` or via the Continue sidebar → ⚙).
2. Add a model entry:

```yaml
models:
  - name: qwen3:4b
    provider: ollama
    model: qwen3:4b
    apiBase: https://ollama.@host_name@.@domain@
    apiKey: "your-api-key"
```

### curl

```sh
curl https://ollama.@host_name@.@domain@/api/chat \
  -u "ollama:your-api-key" \
  -d '{"model":"qwen3:4b","messages":[{"role":"user","content":"Hello"}]}'
```

The `/v1/` prefix also works for OpenAI-compatible clients:

```sh
curl https://ollama.@host_name@.@domain@/v1/chat/completions \
  -u "ollama:your-api-key" \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3:4b","messages":[{"role":"user","content":"Hello"}]}'
```

## Good to know

- **Privacy** — all inference runs locally on the server. No data leaves the home network.
- **Speed** — the server has no GPU, so generation is slower than cloud services. Smaller models (3–4B) are noticeably
  faster than larger ones (7B+).
- **Conversations are saved** — your chat history is stored in your Open WebUI account, not the browser. Sign in from
  any device to continue where you left off.
