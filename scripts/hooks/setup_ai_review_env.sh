#!/bin/bash
################################################################################
# AI REVIEW ENVIRONMENT SETUP SCRIPT
# Purpose: Automatically configure AI review environment variables
# Usage: source scripts/hooks/setup_ai_review_env.sh
#        OR: ./scripts/hooks/setup_ai_review_env.sh (to create .git/hooks/pre-commit.env)
################################################################################

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
HOOKS_DIR="${REPO_ROOT}/.git/hooks"
ENV_FILE="${HOOKS_DIR}/pre-commit.env"
EXAMPLE_FILE="${SCRIPT_DIR}/pre-commit.env.example"

# Color codes
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     AI REVIEW ENVIRONMENT SETUP                               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if .git/hooks directory exists
if [ ! -d "${HOOKS_DIR}" ]; then
    echo -e "${YELLOW}⚠ WARNING: ${HOOKS_DIR} not found${NC}"
    echo "This script should be run from a git repository root."
    exit 1
fi

# Function to export variables (for sourcing)
export_env_vars() {
    # Primary Provider: Anthropic (Claude)
    export AI_REVIEW_PROVIDER="${AI_REVIEW_PROVIDER:-anthropic}"
    export AI_REVIEW_API_URL="${AI_REVIEW_API_URL:-https://api.anthropic.com/v1/messages}"
    export AI_REVIEW_MODEL="${AI_REVIEW_MODEL:-claude-3-opus-20240229}"
    
    # Check if token is set
    if [ -z "${AI_REVIEW_TOKEN:-}" ]; then
        echo -e "${YELLOW}⚠ WARNING: AI_REVIEW_TOKEN not set${NC}"
        echo "  Set it with: export AI_REVIEW_TOKEN='sk-ant-your-key'"
        echo "  Or configure in: ${ENV_FILE}"
    else
        echo -e "${GREEN}✓ AI_REVIEW_TOKEN is set${NC}"
    fi
    
    # Secondary Provider: Disabled by default
    export AI_REVIEW_SECONDARY_PROVIDER="${AI_REVIEW_SECONDARY_PROVIDER:-none}"
    
    # Optional: OpenAI as secondary
    if [ "${AI_REVIEW_SECONDARY_PROVIDER}" != "none" ] && [ -n "${AI_REVIEW_SECONDARY_TOKEN:-}" ]; then
        export AI_REVIEW_SECONDARY_API_URL="${AI_REVIEW_SECONDARY_API_URL:-https://api.openai.com/v1/chat/completions}"
        export AI_REVIEW_SECONDARY_MODEL="${AI_REVIEW_SECONDARY_MODEL:-gpt-4.1-mini}"
        echo -e "${GREEN}✓ Secondary provider configured: ${AI_REVIEW_SECONDARY_PROVIDER}${NC}"
    else
        echo -e "${BLUE}• Secondary provider: disabled (recommended)${NC}"
    fi
    
    # Advanced settings (optional)
    export AI_REVIEW_MAX_TOKENS="${AI_REVIEW_MAX_TOKENS:-2048}"
    export AI_REVIEW_SECONDARY_MAX_TOKENS="${AI_REVIEW_SECONDARY_MAX_TOKENS:-1024}"
    export AI_REVIEW_TIMEOUT="${AI_REVIEW_TIMEOUT:-60}"
    export AI_REVIEW_MAX_LINES="${AI_REVIEW_MAX_LINES:-400}"
    export SKIP_AI_REVIEW="${SKIP_AI_REVIEW:-0}"
    
    echo ""
    echo -e "${GREEN}✓ Environment variables exported${NC}"
    echo ""
    echo "Configuration:"
    echo "  Primary Provider: ${AI_REVIEW_PROVIDER}"
    echo "  Model: ${AI_REVIEW_MODEL}"
    echo "  Secondary Provider: ${AI_REVIEW_SECONDARY_PROVIDER}"
}

# Function to create .git/hooks/pre-commit.env file
create_env_file() {
    echo "Creating ${ENV_FILE}..."
    
    # Check if file already exists
    if [ -f "${ENV_FILE}" ]; then
        echo -e "${YELLOW}⚠ File already exists: ${ENV_FILE}${NC}"
        echo "  Backing up to ${ENV_FILE}.backup"
        cp "${ENV_FILE}" "${ENV_FILE}.backup"
    fi
    
    # Create file from example if it exists, otherwise create new
    if [ -f "${EXAMPLE_FILE}" ]; then
        cp "${EXAMPLE_FILE}" "${ENV_FILE}"
        echo -e "${GREEN}✓ Created ${ENV_FILE} from example${NC}"
    else
        # Create basic configuration
        cat > "${ENV_FILE}" <<'EOF'
# shell environment overrides for pre-commit
# This file is automatically sourced by the pre-commit hook

# Primary Provider: Anthropic (Claude) - REQUIRED
export AI_REVIEW_TOKEN="sk-ant-your-anthropic-api-key"
export AI_REVIEW_API_URL="https://api.anthropic.com/v1/messages"
export AI_REVIEW_MODEL="claude-3-opus-20240229"
export AI_REVIEW_PROVIDER="anthropic"

# Secondary Provider: Disabled (recommended)
export AI_REVIEW_SECONDARY_PROVIDER="none"
EOF
        echo -e "${GREEN}✓ Created ${ENV_FILE} with default configuration${NC}"
    fi
    
    # Set restrictive permissions
    chmod 600 "${ENV_FILE}"
    echo -e "${GREEN}✓ Set permissions to 600 (read/write owner only)${NC}"
    echo ""
    echo -e "${YELLOW}⚠ IMPORTANT: Edit ${ENV_FILE} and add your API keys!${NC}"
}

# Main logic
if [ "${0}" != "${BASH_SOURCE[0]}" ]; then
    # Script is being sourced
    echo "Sourcing environment variables..."
    export_env_vars
else
    # Script is being executed
    echo "Setting up AI review environment..."
    echo ""
    
    # Create .git/hooks/pre-commit.env file
    create_env_file
    
    # Also export for current session
    echo "Exporting variables for current session..."
    export_env_vars
    
    echo ""
    echo -e "${GREEN}✓ Setup complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Edit ${ENV_FILE} and add your API keys"
    echo "  2. Test with: git commit --no-verify (to test without hooks)"
    echo "  3. Or test hooks: git add <file> && git commit"
    echo ""
fi

