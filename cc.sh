# ==============================
# Claude Code + OpenRouter setup
# ==============================

# ---- INTERNAL HELPERS ----

_cc_openrouter() {
    export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
    export ANTHROPIC_AUTH_TOKEN="$OPENROUTER_API_KEY"
    unset ANTHROPIC_API_KEY
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

# ---- RUN ALIASES ----

_CC_RUN_FILE="$HOME/.config/claude-code-router/run-aliases"

# Reescreve o arquivo agrupado por provider (extraido do modelo)
_cc_run_reorganize() {
    [ ! -f "$_CC_RUN_FILE" ] && return
    local pairs=()
    while IFS='=' read -r n m; do
        [[ "$n" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$n" || -z "$m" ]] && continue
        pairs+=("$m=$n")  # inverte pra sort por modelo/provider
    done < "$_CC_RUN_FILE"

    [ ${#pairs[@]} -eq 0 ] && { > "$_CC_RUN_FILE"; return; }

    IFS=$'\n' sorted=($(printf '%s\n' "${pairs[@]}" | sort)); unset IFS

    local out="" cur_provider=""
    for pair in "${sorted[@]}"; do
        local model="${pair%%=*}"
        local name="${pair#*=}"
        local provider="${model%%/*}"
        if [ "$provider" != "$cur_provider" ]; then
            [ -n "$cur_provider" ] && out+="\n"
            out+="# $provider\n"
            cur_provider="$provider"
        fi
        out+="$name=$model\n"
    done
    printf '%b' "$out" > "$_CC_RUN_FILE"
}

# Exibe aliases agrupados com headers de provider
_cc_print_aliases() {
    local C='\033[36m' D='\033[2m' R='\033[0m'
    if [ ! -s "$_CC_RUN_FILE" ]; then
        printf "  ${D}(nenhum alias)${R}\n"
        return
    fi
    while IFS= read -r line; do
        if [[ "$line" =~ ^#[[:space:]]*(.+) ]]; then
            printf "  ${D}── %s${R}\n" "${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^([^=]+)=(.+) ]]; then
            printf "  ${C}%-16s${R}  ${D}%s${R}\n" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        fi
    done < "$_CC_RUN_FILE"
}

_cc_run() {
    case "$1" in
        add)
            [ -z "$2" ] || [ -z "$3" ] && { echo "Uso: cc run add <nome> <modelo>"; return 1; }
            grep -v "^$2=" "$_CC_RUN_FILE" 2>/dev/null > "$_CC_RUN_FILE.tmp"
            printf '%s=%s\n' "$2" "$3" >> "$_CC_RUN_FILE.tmp"
            mv "$_CC_RUN_FILE.tmp" "$_CC_RUN_FILE"
            _cc_run_reorganize
            echo "✓ run $2 → $3"
            ;;
        rm)
            [ -z "$2" ] && { echo "Uso: cc run rm <nome>"; return 1; }
            grep -v "^$2=" "$_CC_RUN_FILE" 2>/dev/null > "$_CC_RUN_FILE.tmp"
            mv "$_CC_RUN_FILE.tmp" "$_CC_RUN_FILE"
            _cc_run_reorganize
            echo "✓ removido: $2"
            ;;
        list)
            _cc_print_aliases
            ;;
        "")
            echo "Uso: cc run <alias|modelo>  |  cc run add <nome> <modelo>  |  cc run rm <nome>  |  cc run list"
            ;;
        *)
            local model
            model=$(grep "^$1=" "$_CC_RUN_FILE" 2>/dev/null | cut -d= -f2-)
            [ -z "$model" ] && model="$1"
            _cc_openrouter
            ANTHROPIC_MODEL="$model" claude "${@:2}"
            ;;
    esac
}

# ---- MODEL PICKER (cc or) ----

_cc_pick_draw() {
    local i
    for i in "${!_cc_pick_types[@]}"; do
        if [ "${_cc_pick_types[$i]}" = "header" ]; then
            printf "  \033[2m── %s\033[0m\n" "${_cc_pick_names[$i]}"
        elif [ "$i" -eq "$_cc_pick_sel" ]; then
            printf "  \033[36m▶ \033[1m%-16s\033[0m  \033[2m%s\033[0m\n" \
                "${_cc_pick_names[$i]}" "${_cc_pick_display[$i]}"
        else
            printf "    %-16s  \033[2m%s\033[0m\n" \
                "${_cc_pick_names[$i]}" "${_cc_pick_display[$i]}"
        fi
    done
}

_cc_pick_move() {
    local dir=$1 new=$((_cc_pick_sel + $1)) count=${#_cc_pick_types[@]}
    while [ "$new" -ge 0 ] && [ "$new" -lt "$count" ]; do
        [ "${_cc_pick_types[$new]}" = "option" ] && { _cc_pick_sel=$new; return; }
        ((new += dir))
    done
}

_cc_pick_model() {
    _cc_pick_types=("option")
    _cc_pick_names=("padrao")
    _cc_pick_values=("")
    _cc_pick_display=("sem override")

    if [ -s "$_CC_RUN_FILE" ]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^#[[:space:]]*(.+) ]]; then
                _cc_pick_types+=("header")
                _cc_pick_names+=("${BASH_REMATCH[1]}")
                _cc_pick_values+=("")
                _cc_pick_display+=("")
            elif [[ "$line" =~ ^([^=]+)=(.+) ]]; then
                _cc_pick_types+=("option")
                _cc_pick_names+=("${BASH_REMATCH[1]}")
                _cc_pick_values+=("${BASH_REMATCH[2]}")
                _cc_pick_display+=("${BASH_REMATCH[2]}")
            fi
        done < "$_CC_RUN_FILE"
    fi

    _cc_pick_types+=("option")
    _cc_pick_names+=("manual")
    _cc_pick_values+=("__manual__")
    _cc_pick_display+=("digitar modelo")

    local count=${#_cc_pick_types[@]}
    _cc_pick_sel=0

    printf "\n\033[1mEscolha o modelo OpenRouter\033[0m\n\n"
    tput civis 2>/dev/null
    _cc_pick_draw

    while true; do
        local k
        IFS= read -rsn1 k
        if [[ "$k" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 k
            case "$k" in
                '[A') _cc_pick_move -1 ;;
                '[B') _cc_pick_move  1 ;;
            esac
        elif [[ "$k" == "" ]]; then
            break
        fi
        tput cuu "$count" 2>/dev/null
        _cc_pick_draw
    done

    tput cnorm 2>/dev/null
    printf "\n"

    local chosen="${_cc_pick_values[$_cc_pick_sel]}"
    if [ "$chosen" = "__manual__" ]; then
        printf "modelo: "
        read -r chosen
    fi

    if [ -z "$chosen" ]; then
        unset ANTHROPIC_MODEL
        printf "\033[2mmodelo padrao\033[0m\n\n"
    else
        export ANTHROPIC_MODEL="$chosen"
        printf "✓ \033[36m%s\033[0m\n\n" "$chosen"
    fi

    unset _cc_pick_types _cc_pick_names _cc_pick_values _cc_pick_display _cc_pick_sel
}

# ---- HELP ----

_cc_help() {
    local B='\033[1m' C='\033[36m' D='\033[2m' R='\033[0m'
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
    _cc_print_aliases
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
            aliases=$(grep -v '^#' "$HOME/.config/claude-code-router/run-aliases" 2>/dev/null | cut -d= -f1 | tr '\n' ' ')
            COMPREPLY=($(compgen -W "add rm list $aliases" -- "$cur"))
            ;;
        cc)    COMPREPLY=($(compgen -W "or oauth status reset model run help" -- "$cur")) ;;
        *)     COMPREPLY=() ;;
    esac
}
complete -F _cc_completions cc

# ---- BACKWARD COMPAT ----

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
