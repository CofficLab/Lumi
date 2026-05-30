#!/usr/bin/env bash

# Shared helpers for Lumi automation scripts.

lumi_automation_api_url() {
    local port="$1"
    echo "http://localhost:${port}/api/action"
}

lumi_automation_candidate_ports() {
    local start_port="${LUMI_AUTOMATION_PORT:-18765}"
    local attempts="${LUMI_AUTOMATION_PORT_ATTEMPTS:-10}"
    local i

    for i in $(seq 0 $((attempts - 1))); do
        echo $((start_port + i))
    done
}

lumi_automation_probe_url() {
    local url="$1"
    local response

    response=$(curl -sS --connect-timeout 1 --max-time 2 -X POST "$url" \
        -H "Content-Type: application/json" \
        -d '{"action":"automation.debug_state","payload":{}}' 2>/dev/null || true)

    echo "$response" | grep -qE '"status"\s*:\s*"ok"'
}

lumi_resolve_automation_base_url() {
    if [ -n "${LUMI_AUTOMATION_BASE_URL:-}" ]; then
        echo "$LUMI_AUTOMATION_BASE_URL"
        return 0
    fi

    local port
    local url
    for port in $(lumi_automation_candidate_ports); do
        url="$(lumi_automation_api_url "$port")"
        if lumi_automation_probe_url "$url"; then
            echo "$url"
            return 0
        fi
    done

    echo "$(lumi_automation_api_url "${LUMI_AUTOMATION_PORT:-18765}")"
    return 1
}
