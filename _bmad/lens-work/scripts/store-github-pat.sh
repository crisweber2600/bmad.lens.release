#!/usr/bin/env bash
# store-github-pat.sh — Securely store GitHub PATs as environment variables outside of LLM context
# Run this script in a terminal window (NOT inside Copilot/Claude/LLM chat)
set -euo pipefail

INVENTORY_FILE="_bmad-output/lens-work/repo-inventory.yaml"

echo ""
echo "🔐 GitHub PAT Storage (Secure Terminal)"
echo "========================================"
echo ""
echo "⚠️  This script runs outside of LLM context for security."
echo "   Your PAT will NOT be visible to any AI assistant."
echo ""

# Detect GitHub domains from repo inventory
domains=()
if [[ -f "$INVENTORY_FILE" ]]; then
  # Extract unique GitHub domains from remote URLs
  while IFS= read -r domain; do
    if [[ -n "$domain" ]]; then
      domains+=("$domain")
    fi
  done < <(grep -oP 'https?://\K[^/]+' "$INVENTORY_FILE" 2>/dev/null | grep -i github | sort -u)
fi

# Default to github.com if no domains detected
if [[ ${#domains[@]} -eq 0 ]]; then
  domains=("github.com")
fi

echo "Detected GitHub domain(s):"
for d in "${domains[@]}"; do
  echo "  • $d"
done
echo ""

# Determine shell profile file to persist env vars
detect_profile() {
  if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
    echo "${HOME}/.zshrc"
  elif [[ -f "${HOME}/.bash_profile" ]]; then
    echo "${HOME}/.bash_profile"
  else
    echo "${HOME}/.bashrc"
  fi
}

PROFILE_FILE="$(detect_profile)"

for domain in "${domains[@]}"; do
  echo ""
  echo "──────────────────────────────────────"
  echo "Domain: $domain"
  echo ""

  if [[ "$domain" == "github.com" ]]; then
    echo "  Generate a token at: https://github.com/settings/tokens"
    env_var="GITHUB_PAT"
  else
    echo "  Generate a token at: https://${domain}/settings/tokens"
    env_var="GH_ENTERPRISE_TOKEN"
  fi
  echo "  Required scopes: repo, read:org"
  echo "  Will be stored as: \$${env_var}"
  echo ""

  read -rsp "  Enter PAT for ${domain} (input hidden): " pat
  echo ""

  if [[ -z "$pat" ]]; then
    echo "  ⏭️  Skipped ${domain}"
    continue
  fi

  # Remove any existing export for this variable from profile
  if [[ -f "$PROFILE_FILE" ]]; then
    grep -v "^export ${env_var}=" "$PROFILE_FILE" > "${PROFILE_FILE}.tmp" || true
    mv "${PROFILE_FILE}.tmp" "$PROFILE_FILE"
  fi

  # Append export to shell profile for persistence
  echo "export ${env_var}=\"${pat}\"" >> "$PROFILE_FILE"

  # Set in current session immediately
  export "${env_var}=${pat}"

  echo "  ✅ Stored \$${env_var} in environment"
done

echo ""
echo "========================================"
echo ""
echo "✅ PATs stored as environment variables"
echo ""
echo "Verifying stored variables:"
stored_count=0
for domain in "${domains[@]}"; do
  if [[ "$domain" == "github.com" ]]; then
    env_var="GITHUB_PAT"
  else
    env_var="GH_ENTERPRISE_TOKEN"
  fi
  val="${!env_var:-}"
  if [[ -n "$val" ]]; then
    if [[ ${#val} -ge 8 ]]; then
      masked="${val:0:4}****${val: -4}"
    else
      masked="****"
    fi
    echo "  ✅ \$${env_var} = ${masked}"
    stored_count=$((stored_count + 1))
  else
    echo "  ❌ \$${env_var} not set"
  fi
done

echo ""
if [[ $stored_count -gt 0 ]]; then
  echo "✅ ${stored_count} PAT(s) verified."
  echo ""
  echo "📌 Persisted to: ${PROFILE_FILE}"
  echo "   Reload your shell or run: source ${PROFILE_FILE}"
else
  echo "⚠️  No PATs were stored."
fi
