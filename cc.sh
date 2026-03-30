# ==============================
# Claude Code + OpenRouter setup
# ==============================

# ---- INTERNAL HELPERS ----

_cc_openrouter() {
    export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
    export ANTHROPIC_AUTH_TOKEN="$OPENROUTER_API_KEY"
    unset ANTHROPIC_API_KEY
}

_cc_pick_model() {
    local B='\033[1m' C='\033[36m' Y='\033[33m' D='\033[2m' R='\033[0m'

    # Carrega aliases
    local names=() models=()
    if [ -s "$_CC_RUN_FILE" ]; then
        while IFS='=' read -r n m; do
            names+=("$n"); models+=("$m")
        done < "$_CC_RUN_FILE"
    fi

    printf "\n${B}Escolha o modelo OpenRouter${R}\n\n"
    printf "  ${D}0)${R} padrao ${D}(sem override)${R}\n"
    local i
    for i in "${!names[@]}"; do
        printf "  ${Y}%d)${R} %-14s ${D}%s${R}\n" "$((i+1))" "${names[$i]}" "${models[$i]}"
    done
    printf "  ${D}m)${R} digitar modelo manualmente\n"
    printf "\n${C}>${R} "

    local choice
    read -r choice

    case "$choice" in
        0|"")
            unset ANTHROPIC_MODEL
            printf "${D}modelo padrao${R}\n"
            ;;
        m|M)
            printf "modelo: "
            read -r ANTHROPIC_MODEL
            export ANTHROPIC_MODEL
            printf "✓ ${ANTHROPIC_MODEL}\n"
            ;;
        *)
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#names[@]}" ]; then
                export ANTHROPIC_MODEL="${models[$((choice-1))]}"
                printf "✓ ${names[$((choice-1))]} → ${ANTHROPIC_MODEL}\n"
            else
                printf "${D}opcao invalida, usando padrao${R}\n"
                unset ANTHROPIC_MODEL
            fi
            ;;
    esac
    printf "\n"
}

_cc_oauth() {
    unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY
    echo "✓ OAuth (Claude direto)"
}

_cc_reset() {
    unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY
    unset ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL
    unset ANTHROPIC_DEFAULT_HAIKU_MODEL CLAUDE_CODE_SUBAGENT_MODEL
    echo "✓ Vars limpas"
}

_cc_status() {
    echo "provider:  ${ANTHROPIC_BASE_URL:-oauth}"
    echo "token:     ${ANTHROPIC_AUTH_TOKEN:+[SET]}${ANTHROPIC_AUTH_TOKEN:-<unset>}"
    echo "sonnet:    ${ANTHROPIC_DEFAULT_SONNET_MODEL:-<default>}"
    echo "opus:      ${ANTHROPIC_DEFAULT_OPUS_MODEL:-<default>}"
    echo "haiku:     ${ANTHROPIC_DEFAULT_HAIKU_MODEL:-<default>}"
    echo "agent:     ${CLAUDE_CODE_SUBAGENT_MODEL:-<default>}"
}


_cc_model() {
    case "$1" in
        sonnet) [ -z "$2" ] && { echo "Uso: cc model sonnet <modelo>"; return 1; }
                export ANTHROPIC_DEFAULT_SONNET_MODEL="$2"; echo "✓ sonnet=$2" ;;
        opus)   [ -z "$2" ] && { echo "Uso: cc model opus <modelo>"; return 1; }
                export ANTHROPIC_DEFAULT_OPUS_MODEL="$2";   echo "✓ opus=$2" ;;
        haiku)  [ -z "$2" ] && { echo "Uso: cc model haiku <modelo>"; return 1; }
                export ANTHROPIC_DEFAULT_HAIKU_MODEL="$2";  echo "✓ haiku=$2" ;;
        agent)  [ -z "$2" ] && { echo "Uso: cc model agent <modelo>"; return 1; }
                export CLAUDE_CODE_SUBAGENT_MODEL="$2";     echo "✓ agent=$2" ;;
        pack)   [ -z "$5" ] && { echo "Uso: cc model pack <opus> <sonnet> <haiku> <agent>"; return 1; }
                export ANTHROPIC_DEFAULT_OPUS_MODEL="$2" ANTHROPIC_DEFAULT_SONNET_MODEL="$3"
                export ANTHROPIC_DEFAULT_HAIKU_MODEL="$4" CLAUDE_CODE_SUBAGENT_MODEL="$5"
                echo "✓ opus=$2 sonnet=$3 haiku=$4 agent=$5" ;;
        *)      echo "Uso: cc model sonnet|opus|haiku|agent|pack <valor>" ;;
    esac
}

_CC_RUN_FILE="$HOME/.config/claude-code-router/run-aliases"

_cc_run_load() {
    [ -f "$_CC_RUN_FILE" ] && grep -E '^[^#=]+=.+' "$_CC_RUN_FILE"
}

_cc_run() {
    case "$1" in
        add)
            [ -z "$2" ] || [ -z "$3" ] && { echo "Uso: cc run add <nome> <modelo>"; return 1; }
            # remove entrada existente e adiciona nova
            local tmp; tmp=$(grep -v "^$2=" "$_CC_RUN_FILE" 2>/dev/null)
            printf '%s\n%s=%s\n' "$tmp" "$2" "$3" | grep -v '^$' > "$_CC_RUN_FILE"
            echo "✓ run $2 → $3"
            ;;
        rm)
            [ -z "$2" ] && { echo "Uso: cc run rm <nome>"; return 1; }
            grep -v "^$2=" "$_CC_RUN_FILE" 2>/dev/null > "$_CC_RUN_FILE.tmp" && mv "$_CC_RUN_FILE.tmp" "$_CC_RUN_FILE"
            echo "✓ removido: $2"
            ;;
        list)
            if [ ! -s "$_CC_RUN_FILE" ]; then echo "(nenhum alias)"; return; fi
            while IFS='=' read -r name model; do
                printf "  %-15s %s\n" "$name" "$model"
            done < "$_CC_RUN_FILE"
            ;;
        "")
            echo "Uso: cc run <nome|modelo>  |  cc run add <nome> <modelo>  |  cc run rm <nome>  |  cc run list"
            ;;
        *)
            # busca no arquivo de aliases
            local model
            model=$(grep "^$1=" "$_CC_RUN_FILE" 2>/dev/null | cut -d= -f2-)
            [ -z "$model" ] && model="$1"  # trata como modelo direto
            _cc_openrouter
            ANTHROPIC_MODEL="$model" claude "${@:2}"
            ;;
    esac
}

_cc_help() {
    local B='\033[1m' C='\033[36m' Y='\033[33m' D='\033[2m' R='\033[0m'
    printf "\n${B}cc${R} — Claude Code launcher via OpenRouter\n"
    printf "${D}Uso: cc [subcomando] [args]${R}\n\n"

    printf "${B}Launch${R}\n"
    printf "  ${C}cc${R}                     Abre Claude (OAuth padrao)\n"
    printf "  ${C}cc or${R}                  Ativa OpenRouter e abre Claude\n"
    printf "  ${C}cc run${R} <alias|modelo>  OpenRouter + modelo especifico\n\n"

    printf "${B}Aliases de run${R}\n"
    printf "  ${C}cc run add${R} <nome> <modelo>  Cria ou edita alias\n"
    printf "  ${C}cc run rm${R} <nome>            Remove alias\n"
    printf "  ${C}cc run list${R}                 Lista aliases\n"
    if [ -s "$_CC_RUN_FILE" ]; then
        while IFS='=' read -r name model; do
            printf "  ${Y}%-14s${R} %s\n" "$name" "$model"
        done < "$_CC_RUN_FILE"
    else
        printf "  ${D}(nenhum alias cadastrado)${R}\n"
    fi
    printf "\n"

    printf "${B}Provider${R}\n"
    printf "  ${C}cc oauth${R}         Volta para OAuth direto\n\n"

    printf "${B}Config${R}\n"
    printf "  ${C}cc status${R}        Mostra config atual\n"
    printf "  ${C}cc reset${R}         Limpa todas as variaveis\n"
    printf "  ${C}cc model${R} <slot> <m>  Define modelo\n"
    printf "       ${D}slots: sonnet | opus | haiku | agent | pack${R}\n\n"
}

# ---- MAIN DISPATCHER ----

cc() {
    case "$1" in
        or|openrouter) _cc_openrouter; _cc_pick_model; claude ;;
        oauth)  _cc_oauth ;;
        status) _cc_status ;;
        reset)  _cc_reset ;;
        model)  _cc_model "${@:2}" ;;
        run)    _cc_run "${@:2}" ;;
        help|-h|--help) _cc_help ;;
        "")     claude ;;
        *)      claude "$@" ;;
    esac
}

# ---- TAB COMPLETION ----

_cc_completions() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    case "$prev" in
        model) COMPREPLY=($(compgen -W "sonnet opus haiku agent pack" -- "$cur")) ;;
        run)
            local aliases
            aliases=$(cut -d= -f1 "$HOME/.config/claude-tools/run-aliases" 2>/dev/null | tr '\n' ' ')
            COMPREPLY=($(compgen -W "add rm list $aliases" -- "$cur"))
            ;;
        cc)    COMPREPLY=($(compgen -W "or oauth status reset model run help" -- "$cur")) ;;
        *)     COMPREPLY=() ;;
    esac
}
complete -F _cc_completions cc

# ---- BACKWARD COMPAT ----
# Mantidos temporariamente para nao quebrar musculo-memoria

cc-oauth()      { cc oauth; claude; }
cc-or()         { cc or; }
cc-openrouter() { cc or; }
cc-status()     { cc status; }
cc-check()      { cc status; }
cc-reset()      { cc reset; }
cc-minimax()    { cc run minimax "$@"; }
cc-glm5()       { cc run glm5 "$@"; }
cc-sonnet() {
    [ -z "$1" ] && { echo "Uso: cc-sonnet <modelo>"; return 1; }
    cc model sonnet "$1"
    claude
}
