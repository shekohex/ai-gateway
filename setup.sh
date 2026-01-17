#!/usr/bin/env bash

# AI Gateway Setup Utility
# Resilient, portable, and comprehensive CLI for onboarding and management

set -o pipefail

# --- Configuration & Constants ---
STATE_FILE=".setup-state.jsonl"
ENV_FILE=".env"
ENV_EXAMPLE=".env.example"
VERBOSE=${VERBOSE:-0}
INTERACTIVE=1
USE_COLORS=1

# --- Color Definitions ---
setup_colors() {
    if [[ -t 1 ]] && [[ "${NO_COLOR:-}" == "" ]] && [[ "${TERM:-}" != "dumb" ]] && [[ "${COLOR:-}" != "0" ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[0;33m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        GRAY='\033[0;90m'
        NC='\033[0m'
        BOLD='\033[1m'
    else
        RED='' GREEN='' YELLOW='' BLUE='' CYAN='' GRAY='' NC='' BOLD=''
        USE_COLORS=0
    fi
}
setup_colors

# --- Logging & State ---
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

record_state() {
    local action="$1"
    local detail="$2"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    printf '{"timestamp": "%s", "action": "%s", "detail": "%s"}\n' "$timestamp" "$action" "$detail" >> "$STATE_FILE"
}

run_cmd() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo -e "${BOLD}> Running:${NC} $1"
    fi
    record_state "exec" "$1"
    eval "$1"
}

# --- Detection ---
check_deps() {
    log "Checking dependencies..."
    local deps=("curl" "openssl" "jq" "docker" "git")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            error "Missing dependency: $dep. Please install it first."
        fi
    done
    
    if ! docker compose version >/dev/null 2>&1; then
        error "Docker Compose (v2) is required."
    fi
    success "All dependencies met."
}

# --- Onboarding Logic ---
generate_secret() {
    openssl rand -hex 32
}

ask() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    local hide_default="${4:-0}"
    local value

    if [[ $INTERACTIVE -eq 0 ]]; then
        eval "$var_name=\"$default\""
        return
    fi

    if [[ "$hide_default" -eq 1 ]]; then
        # Mask input for secrets
        printf "%b%s%b: " "${BOLD}" "${prompt}" "${NC}"
        stty -echo
        read value
        stty echo
        printf "\n"
    else
        read -p "$(echo -e "${BOLD}${prompt}${NC} ${GRAY}(${default})${NC}: ")" value
    fi

    if [[ -z "$value" ]]; then
        eval "$var_name=\"$default\""
    else
        eval "$var_name=\"$value\""
    fi
}

onboard() {
    check_deps
    log "Starting onboarding process..."

    if [[ ! -f "$ENV_EXAMPLE" ]]; then
        error "Missing $ENV_EXAMPLE. Cannot proceed."
    fi

    # Load existing env if available
    if [[ -f "$ENV_FILE" ]]; then
        warn "Existing $ENV_FILE found. Missing variables will be appended."
        # shellcheck source=/dev/null
        set -a; source "$ENV_FILE"; set +a
    fi

    local temp_env=".env.tmp"
    touch "$temp_env"

    # Helper to get current value or example
    get_val() {
        local key="$1"
        local example
        example=$(grep "^$key=" "$ENV_EXAMPLE" | cut -d'=' -f2- | tr -d '"')
        if [[ -n "${!key:-}" ]]; then
            echo "${!key}"
        else
            echo "$example"
        fi
    }

    # Core Variables
    log "Configuring Security..."
    local master_key; ask "LiteLLM Master Key" "$(get_val LITELLM_MASTER_KEY)" master_key 1
    local salt_key; ask "LiteLLM Salt Key" "$(get_val LITELLM_SALT_KEY)" salt_key 1
    local mgmt_pass; ask "Management Password" "$(get_val MANAGEMENT_PASSWORD)" mgmt_pass 1
    
    log "Configuring Database..."
    local pg_user; ask "Postgres User" "$(get_val POSTGRES_USER)" pg_user
    local pg_pass; ask "Postgres Password" "$(get_val POSTGRES_PASSWORD)" pg_pass 1
    local db_url="postgresql://${pg_user}:${pg_pass}@db:5432/litellm"
    
    log "Configuring Langfuse..."
    local lf_salt; ask "Langfuse Salt" "$(generate_secret)" lf_salt 1
    local lf_enc; ask "Langfuse Encryption Key" "$(generate_secret)" lf_enc 1
    local lf_next_secret; ask "Langfuse NextAuth Secret" "$(generate_secret)" lf_next_secret 1
    
    log "Configuring Newt..."
    local pangolin_endpoint; ask "Pangolin Endpoint" "$(get_val PANGOLIN_ENDPOINT)" pangolin_endpoint
    local newt_id; ask "Newt Site ID" "$(get_val NEWT_ID)" newt_id
    local newt_secret; ask "Newt Site Secret" "$(get_val NEWT_SECRET)" newt_secret 1

    # Configuration Analysis Section

    echo -e "\n${BOLD}Configuration Comparison:${NC}"
    local compare_configs
    ask "Compare current configs with examples to see missing features?" "n" compare_configs
    
    if [[ "$compare_configs" =~ ^[Yy]$ ]]; then
        local configs=(
            "config/litellm/config.yaml:config/litellm/config.example.yaml"
            "config/cliproxyapi/config.yaml:config/cliproxyapi/config.example.yaml"
        )
        
        for cfg in "${configs[@]}"; do
            local current="${cfg%%:*}"
            local example="${cfg##*:}"
            
            if [[ -f "$current" ]] && [[ -f "$example" ]]; then
                log "Analyzing $current..."
                # Use git diff to show differences between current and example
                # --no-index allows comparing files outside a git repo or untracked ones
                # --word-diff=color gives a nice side-by-side feel for values
                if ! git diff --no-index --quiet "$current" "$example"; then
                    warn "Differences found in $current compared to the latest example:"
                    git diff --no-index --color=always "$current" "$example" | sed 's/^/  /'
                    echo ""
                else
                    success "$current is up to date with example."
                fi
            fi
        done
        echo -e "${GRAY}Note: Above changes show what is in the example but missing or different in your config.${NC}"
    fi

    # Ensure config files exist
    log "Initializing configuration files..."
    mkdir -p config/litellm config/cliproxyapi
    
    if [[ ! -f "config/litellm/config.yaml" ]]; then
        cp config/litellm/config.example.yaml config/litellm/config.yaml
        record_state "init" "Created config/litellm/config.yaml from example"
    fi
    if [[ ! -f "config/cliproxyapi/config.yaml" ]]; then
        cp config/cliproxyapi/config.example.yaml config/cliproxyapi/config.yaml
        record_state "init" "Created config/cliproxyapi/config.yaml from example"
    fi

    # Fix Data Directory Permissions
    log "Preparing data directories..."
    # Map directories to their expected container UIDs for better security
    # Postgres: 999, Redis: 999, Clickhouse: 101, Prometheus: 65534, Minio: 1001
    declare -A dir_map=(
        ["data/postgres"]="999:999"
        ["data/redis"]="999:999"
        ["data/clickhouse/data"]="101:101"
        ["data/clickhouse/logs"]="101:101"
        ["data/minio"]="1001:1001"
        ["data/prometheus"]="65534:65534"
        ["data/cliproxyapi/auth-dir"]="1000:1000"
    )

    for dir in "${!dir_map[@]}"; do
        mkdir -p "$dir"
        local owner="${dir_map[$dir]}"
        
        # Try chown first for better security
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo chown -R "$owner" "$dir" 2>/dev/null || chmod -R 777 "$dir"
        else
            # macOS handles bind mount permissions differently (usually mapped to host user)
            chmod -R 777 "$dir"
        fi
    done
    record_state "init" "Initialized data directories with mapped permissions"

    # Write final .env
    {
        echo "# Generated by setup.sh on $(date)"
        echo "LITELLM_MASTER_KEY=\"$master_key\""
        echo "LITELLM_SALT_KEY=\"$salt_key\""
        echo "MANAGEMENT_PASSWORD=\"$mgmt_pass\""
        echo "CLIPROXYAPI_KEY=\"$(get_val CLIPROXYAPI_KEY)\""
        echo "POSTGRES_DB=\"litellm\""
        echo "POSTGRES_USER=\"$pg_user\""
        echo "POSTGRES_PASSWORD=\"$pg_pass\""
        echo "DATABASE_URL=\"$db_url\""
        echo ""
        echo "# Langfuse"
        echo "LANGFUSE_DATABASE_URL=\"postgresql://${pg_user}:${pg_pass}@db:5432/langfuse\""
        echo "LANGFUSE_SALT=\"$lf_salt\""
        echo "LANGFUSE_ENCRYPTION_KEY=\"$lf_enc\""
        echo "NEXTAUTH_SECRET=\"$lf_next_secret\""
        echo "NEXTAUTH_URL=\"http://localhost:3000\""
        echo "LANGFUSE_PUBLIC_KEY=\"\""
        echo "LANGFUSE_SECRET_KEY=\"\""
        echo "LANGFUSE_HOST=\"http://langfuse-web:3000\""
        echo ""
        echo "# Redis"
        echo "REDIS_HOST=\"redis\""
        echo "REDIS_PORT=\"6379\""
        echo "REDIS_PASSWORD=\"\""
        echo ""
        echo "# Minio"
        echo "MINIO_ROOT_USER=\"minio\""
        echo "MINIO_ROOT_PASSWORD=\"miniosecret\""
        echo ""
        echo "# Clickhouse"
        echo "CLICKHOUSE_USER=\"clickhouse\""
        echo "CLICKHOUSE_PASSWORD=\"clickhouse\""
        echo ""
        echo "# Newt"
        echo "PANGOLIN_ENDPOINT=\"$pangolin_endpoint\""
        echo "NEWT_ID=\"$newt_id\""
        echo "NEWT_SECRET=\"$newt_secret\""
    } > "$ENV_FILE"

    rm "$temp_env"
    record_state "onboard" "Configuration generated in $ENV_FILE"
    success "Onboarding complete. Configuration saved to $ENV_FILE"
    
    echo -e "\n${BOLD}Pangolin Site Configuration:${NC}"
    echo -e "Configure these Resources in your Pangolin Dashboard for this Site:"
    echo -e "  - ${CYAN}LiteLLM Proxy${NC}: http://litellm:4000"
    echo -e "  - ${CYAN}CLI-Proxy-API${NC}: http://cli-proxy-api:8317"
    echo -e "  - ${CYAN}Prometheus${NC}: http://prometheus:9090"
    echo -e "  - ${CYAN}Langfuse UI${NC}: http://langfuse-web:3000"
    
    echo -e "\n${BOLD}Next Steps:${NC}"
    echo -e "1. Run ${BOLD}./setup.sh up -d${NC} to start the stack."
    echo -e "2. Access LiteLLM Admin UI at ${BOLD}http://localhost:4000/ui${NC}"
    echo -e "3. Access Langfuse at ${BOLD}http://localhost:3000${NC}"
}

# --- Command Handlers ---
cmd_up() {
    log "Starting AI Gateway..."
    run_cmd "docker compose up $*"
}

cmd_down() {
    log "Stopping AI Gateway..."
    run_cmd "docker compose down $*"
}

cmd_restart() {
    log "Restarting AI Gateway..."
    run_cmd "docker compose restart $*"
}

cmd_update() {
    log "Updating images and restarting..."
    run_cmd "docker compose pull && docker compose up -d"
}

cmd_cleanup() {
    warn "This will stop all containers and remove them."
    run_cmd "docker compose down --remove-orphans"
}

cmd_reset() {
    warn "CRITICAL: This will destroy ALL data and reset your configuration."
    if [[ $INTERACTIVE -eq 1 ]]; then
        read -p "Are you sure you want to proceed? [y/N]: " confirm
        [[ "$confirm" != "y" ]] && return
    fi
    run_cmd "docker compose down -v"
    rm -rf data/
    rm -f "$ENV_FILE" "$STATE_FILE"
    success "System reset complete."
}

# --- CLI Entry Point ---
usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  onboard     Run the interactive onboarding process"
    echo "  up          Start the stack (pass -d for detached mode)"
    echo "  down        Stop the stack"
    echo "  restart     Restart all services"
    echo "  update      Pull latest images and restart"
    echo "  cleanup     Remove orphans and stop services"
    echo "  reset       Wipe all data and configuration"
    echo "  help        Show this help message"
    echo ""
    echo "Options:"
    echo "  --no-interactive  Disable interactive prompts"
    echo "  --verbose         Enable verbose logging"
    echo "  --no-color        Disable color output"
    exit 1
}

main() {
    local cmd="${1:-}"
    shift || true

    # Parse global flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-interactive) INTERACTIVE=0; shift ;;
            --verbose) VERBOSE=1; shift ;;
            --no-color) setup_colors; shift ;; # Re-run with NO_COLOR pattern
            *) break ;;
        esac
    done

    case "$cmd" in
        onboard) onboard ;;
        up)      cmd_up "$@" ;;
        down)    cmd_down "$@" ;;
        restart) cmd_restart "$@" ;;
        update)  cmd_update ;;
        cleanup) cmd_cleanup ;;
        reset)   cmd_reset ;;
        help|*)  usage ;;
    esac
}

main "$@"
