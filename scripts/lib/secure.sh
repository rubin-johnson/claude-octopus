#!/usr/bin/env bash
# lib/secure.sh — Security utilities extracted from orchestrate.sh
# Anti-injection wrappers, secure temp files, and output guards.
# Sourced by orchestrate.sh at startup.

[[ -n "${_OCTOPUS_SECURE_LOADED:-}" ]] && return 0
_OCTOPUS_SECURE_LOADED=true

# v8.41.0: Anti-injection nonce wrapper for untrusted content
# Wraps external/file-sourced content in random boundary tokens to prevent
# prompt injection from memory files, earned skills, or provider history.
# The nonce is a random hex string that cannot be predicted or forged.
# This is purely internal — users never see the nonces.
# Args: $1=content, $2=label (e.g. "memory", "earned-skills")
# Returns: content wrapped in nonce boundaries
sanitize_external_content() {
    local content="$1"
    local label="${2:-external}"

    [[ -z "$content" ]] && return

    # Generate random 16-char hex nonce
    local nonce
    nonce=$(head -c 8 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n' 2>/dev/null) || nonce="$(date +%s%N)"

    echo "<!-- BEGIN-UNTRUSTED:${label}:${nonce} -->
${content}
<!-- END-UNTRUSTED:${label}:${nonce} -->"
}

# ═══════════════════════════════════════════════════════════════════════════════
# TEMP FILE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

# Create secure temporary file
# Returns path to temp file in the secure temp directory
secure_tempfile() {
    local prefix="${1:-tmp}"
    mktemp "${OCTOPUS_TMP_DIR:-/tmp}/${prefix}.XXXXXX"
}

# Guard against oversized output that could flood Claude's context window
# If content exceeds 49KB, writes to a temp file and returns a pointer instead
# Usage: guard_output "$content" "label"
guard_output() {
    local content="$1" label="${2:-output}" max_bytes=49000
    if [[ ${#content} -gt $max_bytes ]]; then
        local f; f=$(secure_tempfile "guard-${label}")
        printf '%s\n' "$content" > "$f"
        echo "[Output exceeded ${max_bytes} bytes. Full content at:]"
        echo "@file:${f}"
    else
        printf '%s\n' "$content"
    fi
}

# ── Extracted from orchestrate.sh ──
sanitize_secrets() {
    local text="$1"

    # Apply sed-based stripping patterns
    echo "$text" | sed \
        -e 's/sk-[A-Za-z0-9_-]\{20,\}/[REDACTED-API-KEY]/g' \
        -e 's/AKIA[A-Z0-9]\{16\}/[REDACTED-AWS-KEY]/g' \
        -e 's/ghp_[A-Za-z0-9]\{36,\}/[REDACTED-GITHUB-PAT]/g' \
        -e 's/gho_[A-Za-z0-9]\{36,\}/[REDACTED-GITHUB-OAUTH]/g' \
        -e 's/glpat-[A-Za-z0-9_-]\{20,\}/[REDACTED-GITLAB-PAT]/g' \
        -e 's/xoxb-[A-Za-z0-9-]\{20,\}/[REDACTED-SLACK-BOT]/g' \
        -e 's/xoxp-[A-Za-z0-9-]\{20,\}/[REDACTED-SLACK-USER]/g' \
        -e 's/Bearer [A-Za-z0-9._-]\{20,\}/Bearer [REDACTED-BEARER]/g' \
        -e 's/eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*/[REDACTED-JWT]/g' \
        -e 's/-----BEGIN[A-Z ]*PRIVATE KEY-----[^-]*-----END[A-Z ]*PRIVATE KEY-----/[REDACTED-PRIVATE-KEY]/g' \
        -e 's|postgres://[^[:space:]]*|[REDACTED-CONNECTION-STRING]|g' \
        -e 's|mysql://[^[:space:]]*|[REDACTED-CONNECTION-STRING]|g' \
        -e 's|mongodb://[^[:space:]]*|[REDACTED-CONNECTION-STRING]|g' \
        -e 's|mongodb+srv://[^[:space:]]*|[REDACTED-CONNECTION-STRING]|g' \
        -e 's|redis://[^[:space:]]*|[REDACTED-CONNECTION-STRING]|g' \
        -e 's/password=[^[:space:]&]*/password=[REDACTED-PASSWORD]/g'
}
