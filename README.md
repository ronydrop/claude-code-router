# claude-code-router

Bash toolkit to route [Claude Code](https://claude.ai/code) through [OpenRouter](https://openrouter.ai) and send quick prompts to any AI model directly from your terminal.

## Requirements

- [Claude Code](https://claude.ai/code) (`claude` CLI)
- `curl` and `jq`
- An [OpenRouter API key](https://openrouter.ai/keys) in your environment as `OPENROUTER_API_KEY`

## Install

```bash
git clone https://github.com/ronydrop/claude-code-router.git
cd claude-code-router
chmod +x install.sh
./install.sh
source ~/.bashrc
```

## Usage

### `cc` — Claude Code launcher

```bash
cc                        # open Claude (default OAuth)
cc or                     # activate OpenRouter and open Claude
cc run <alias|model>      # OpenRouter + specific model
cc oauth                  # switch back to direct OAuth
cc status                 # show current config
cc reset                  # clear all env vars
cc model sonnet <model>   # override sonnet model
cc model pack <o> <s> <h> <a>  # set all models at once
cc help                   # show help
```

#### Model aliases for `cc run`

```bash
cc run add deepseek deepseek/deepseek-r1   # create alias
cc run add glm5 thudm/glm-4-32b           # create alias
cc run deepseek                            # launch with alias
cc run anthropic/claude-opus-4-6          # launch with direct model ID
cc run list                               # list saved aliases
cc run rm deepseek                        # remove alias
```

### `ai` — Quick prompt to any model

```bash
ai <model> "prompt"                       # send prompt to any OpenRouter model
ai-cheap "explain docker"                 # deepseek/deepseek-r1
ai-fast "write a fibonacci function"      # openai/gpt-4o-mini
ai-smart "review this architecture"       # google/gemini-2.0-flash
ai-long "summarize this 10k line file"    # moonshotai/kimi-k2
ai help                                   # show help
```

Stdin support:
```bash
cat file.py | ai-smart "review this code"
cat file.py | ai google/gemini-2.0-flash "find bugs"
```

Raw output (no metadata):
```bash
ai -r openai/gpt-4o-mini "ping" | wc -w
```

## Uninstall

```bash
./uninstall.sh
```

## License

MIT
