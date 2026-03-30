# ==============================
# Universal AI - Direct OpenRouter API
# ==============================

_ai_help() {
    local B='\033[1m' C='\033[36m' Y='\033[33m' D='\033[2m' R='\033[0m'
    printf "\n${B}ai${R} — prompt direto para qualquer modelo OpenRouter\n"
    printf "${D}Uso: ai [-r] <model> [\"prompt\"]  |  echo 'prompt' | ai <model>${R}\n\n"

    printf "${B}Atalhos${R}\n"
    printf "  ${C}ai-cheap${R}    deepseek/deepseek-r1         ${D}custo-beneficio${R}\n"
    printf "  ${C}ai-fast${R}     openai/gpt-4o-mini           ${D}rapido e barato${R}\n"
    printf "  ${C}ai-smart${R}    google/gemini-2.0-flash      ${D}analise inteligente${R}\n"
    printf "  ${C}ai-long${R}     moonshotai/kimi-k2           ${D}contexto longo${R}\n"
    printf "  ${C}ai-minimax${R}  minimax/minimax-m2.7\n"
    printf "  ${C}ai-nvidia${R}   nvidia/llama-3.1-nemotron-70b\n"
    printf "  ${C}ai-auto${R}     openai/auto\n\n"

    printf "${B}Flags${R}\n"
    printf "  ${Y}-r${R}  output raw ${D}(sem metadata de modelo/tokens)${R}\n\n"

    printf "${B}Exemplos${R}\n"
    printf "  ${D}ai-fast \"Explique Docker em 3 linhas\"${R}\n"
    printf "  ${D}cat arquivo.py | ai-smart \"Revise este codigo\"${R}\n"
    printf "  ${D}ai -r google/gemini-2.0-flash \"ping\" | wc -w${R}\n\n"
}

ai() {
    local model prompt raw=0

    # Parse flags
    while [[ "$1" == -* ]]; do
        case "$1" in
            -r|--raw) raw=1; shift ;;
            *) echo "Flag desconhecida: $1"; return 1 ;;
        esac
    done

    # help subcommand
    if [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        _ai_help; return 0
    fi

    model="$1"
    prompt="$2"

    if [ -z "$model" ]; then
        _ai_help; return 1
    fi

    # Suporte a stdin
    if [ -z "$prompt" ] && [ ! -t 0 ]; then
        prompt=$(cat)
    fi

    if [ -z "$prompt" ]; then
        echo "Erro: prompt vazio. Passe como argumento ou via stdin."
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        echo "Erro: jq nao instalado. sudo apt install jq"
        return 1
    fi

    local body response content
    body=$(jq -n --arg m "$model" --arg p "$prompt" \
        '{model: $m, messages: [{role: "user", content: $p}]}')

    response=$(curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        -d "$body" 2>&1)

    if echo "$response" | jq -e '.error' &>/dev/null; then
        echo "Erro da API: $(echo "$response" | jq -r '.error.message')"
        return 1
    fi

    content=$(echo "$response" | jq -r '.choices[0].message.content // empty')

    if [ -z "$content" ]; then
        echo "Resposta vazia ou inesperada:"
        echo "$response" | jq .
        return 1
    fi

    echo "$content"

    if [ "$raw" -eq 0 ]; then
        echo ""
        echo "── $(echo "$response" | jq -r '.model') ──"
        local pt ct tt
        pt=$(echo "$response" | jq -r '.usage.prompt_tokens // 0')
        ct=$(echo "$response" | jq -r '.usage.completion_tokens // 0')
        tt=$(echo "$response" | jq -r '.usage.total_tokens // 0')
        echo "tokens: prompt=$pt completion=$ct total=$tt"
    fi
}

ai-cheap()  { ai deepseek/deepseek-r1 "$@"; }
ai-fast()   { ai openai/gpt-4o-mini "$@"; }
ai-smart()  { ai google/gemini-2.0-flash "$@"; }
ai-long()   { ai moonshotai/kimi-k2 "$@"; }
ai-minimax(){ ai minimax/minimax-m2.7 "$@"; }
ai-nvidia() { ai nvidia/llama-3.1-nemotron-70b-instruct "$@"; }
ai-auto()   { ai openai/auto "$@"; }

ai-help() { _ai_help; }
