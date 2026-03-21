#!/bin/bash
# tests/unit/test-adapter-flags.sh
# Tests for adapter flag ordering, parameter forwarding, and env var allowlists
# Validates fixes from repo-audit-2026-03-21 (Phase 1B, 1C, 1D)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../helpers/test-framework.sh"

test_suite "Adapter Flag Ordering & Parameter Forwarding"

MCP_SRC="$PROJECT_ROOT/mcp-server/src/index.ts"
OC_SRC="$PROJECT_ROOT/openclaw/src/index.ts"

# ═══════════════════════════════════════════════════════════════════════════════
# Debate Flag Placement (Phase 1C fix)
# grapple-specific flags (-r, --mode) must go AFTER the command, not before
# ═══════════════════════════════════════════════════════════════════════════════

test_mcp_debate_uses_post_flags() {
    test_case "MCP debate passes grapple flags via postFlags (after command)"
    if grep -q 'runOrchestrate("grapple".*\[\].*postFlags' "$MCP_SRC"; then
        test_pass
    else
        test_fail "MCP debate should use postFlags parameter for grapple-specific flags"
    fi
}

test_oc_debate_uses_post_flags() {
    test_case "OpenClaw debate passes grapple flags via postFlags (after command)"
    if grep -q 'executeOrchestrate("grapple".*\[\].*\[' "$OC_SRC"; then
        test_pass
    else
        test_fail "OpenClaw debate should use postFlags parameter for grapple-specific flags"
    fi
}

test_mcp_has_post_flags_param() {
    test_case "MCP runOrchestrate accepts postFlags parameter"
    if grep -q 'postFlags: string\[\] = \[\]' "$MCP_SRC"; then
        test_pass
    else
        test_fail "runOrchestrate should accept postFlags parameter"
    fi
}

test_oc_has_post_flags_param() {
    test_case "OpenClaw executeOrchestrate accepts postFlags parameter"
    if grep -q 'postFlags: string\[\] = \[\]' "$OC_SRC"; then
        test_pass
    else
        test_fail "executeOrchestrate should accept postFlags parameter"
    fi
}

test_mcp_args_include_post_flags() {
    test_case "MCP args array includes postFlags after command"
    if grep -q '\.\.\.postFlags, prompt' "$MCP_SRC"; then
        test_pass
    else
        test_fail "MCP args should spread postFlags between command and prompt"
    fi
}

test_oc_args_include_post_flags() {
    test_case "OpenClaw args array includes postFlags after command"
    if grep -q '\.\.\.postFlags, prompt' "$OC_SRC"; then
        test_pass
    else
        test_fail "OpenClaw args should spread postFlags between command and prompt"
    fi
}

test_oc_no_dash_d_flag() {
    test_case "OpenClaw debate does NOT use -d flag (was wrongly mapped to --dir)"
    # The old bug: OpenClaw used "-d" for style, which global parser grabbed as --dir
    if grep -A5 'grapple' "$OC_SRC" | grep -q '"-d"'; then
        test_fail "OpenClaw debate should not use -d flag (conflicts with global --dir)"
    else
        test_pass
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Quality Threshold Forwarding (Phase 1B fix)
# ═══════════════════════════════════════════════════════════════════════════════

test_mcp_forwards_quality_threshold() {
    test_case "MCP develop forwards quality_threshold as -q flag"
    if grep -q '"-q"' "$MCP_SRC" && grep -q 'quality_threshold' "$MCP_SRC"; then
        test_pass
    else
        test_fail "MCP develop should forward quality_threshold as -q flag"
    fi
}

test_oc_forwards_quality_threshold() {
    test_case "OpenClaw develop forwards quality_threshold as -q flag"
    if grep -q '"-q"' "$OC_SRC" && grep -q 'quality_threshold' "$OC_SRC"; then
        test_pass
    else
        test_fail "OpenClaw develop should forward quality_threshold as -q flag"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Environment Variable Allowlists (Phase 1D fix)
# ═══════════════════════════════════════════════════════════════════════════════

test_mcp_forwards_anthropic_base_url() {
    test_case "MCP env allowlist includes ANTHROPIC_BASE_URL"
    if grep -q 'ANTHROPIC_BASE_URL' "$MCP_SRC"; then
        test_pass
    else
        test_fail "MCP should forward ANTHROPIC_BASE_URL for Ollama compatibility"
    fi
}

test_mcp_forwards_anthropic_auth_token() {
    test_case "MCP env allowlist includes ANTHROPIC_AUTH_TOKEN"
    if grep -q 'ANTHROPIC_AUTH_TOKEN' "$MCP_SRC"; then
        test_pass
    else
        test_fail "MCP should forward ANTHROPIC_AUTH_TOKEN for Ollama compatibility"
    fi
}

test_oc_forwards_anthropic_base_url() {
    test_case "OpenClaw env allowlist includes ANTHROPIC_BASE_URL"
    if grep -q 'ANTHROPIC_BASE_URL' "$OC_SRC"; then
        test_pass
    else
        test_fail "OpenClaw should forward ANTHROPIC_BASE_URL for Ollama compatibility"
    fi
}

test_oc_forwards_anthropic_auth_token() {
    test_case "OpenClaw env allowlist includes ANTHROPIC_AUTH_TOKEN"
    if grep -q 'ANTHROPIC_AUTH_TOKEN' "$OC_SRC"; then
        test_pass
    else
        test_fail "OpenClaw should forward ANTHROPIC_AUTH_TOKEN for Ollama compatibility"
    fi
}

test_oc_forwards_perplexity_key() {
    test_case "OpenClaw env allowlist includes PERPLEXITY_API_KEY"
    if grep -q 'PERPLEXITY_API_KEY' "$OC_SRC"; then
        test_pass
    else
        test_fail "OpenClaw should forward PERPLEXITY_API_KEY (parity with MCP)"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Debate Description Accuracy
# ═══════════════════════════════════════════════════════════════════════════════

test_oc_debate_says_four_way() {
    test_case "OpenClaw debate description says Four-way (not Three-way)"
    if grep -q 'Four-way' "$OC_SRC"; then
        test_pass
    else
        test_fail "OpenClaw debate description should say 'Four-way' (v9.4.0 added Sonnet)"
    fi
}

test_oc_debate_has_mode_param() {
    test_case "OpenClaw debate exposes mode parameter (not style)"
    if grep -q 'cross-critique.*blinded\|mode.*cross-critique' "$OC_SRC"; then
        test_pass
    else
        test_fail "OpenClaw debate should have mode param (cross-critique/blinded)"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Run all tests
# ═══════════════════════════════════════════════════════════════════════════════

# Debate flag placement
test_mcp_debate_uses_post_flags
test_oc_debate_uses_post_flags
test_mcp_has_post_flags_param
test_oc_has_post_flags_param
test_mcp_args_include_post_flags
test_oc_args_include_post_flags
test_oc_no_dash_d_flag

# Quality threshold
test_mcp_forwards_quality_threshold
test_oc_forwards_quality_threshold

# Env var allowlists
test_mcp_forwards_anthropic_base_url
test_mcp_forwards_anthropic_auth_token
test_oc_forwards_anthropic_base_url
test_oc_forwards_anthropic_auth_token
test_oc_forwards_perplexity_key

# Description accuracy
test_oc_debate_says_four_way
test_oc_debate_has_mode_param

test_summary
