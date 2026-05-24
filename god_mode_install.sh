#!/usr/bin/env bash
# =============================================================================
# PoseidonDNS - "God Mode" Guided Installer
# =============================================================================
# This script is the friendliest possible way to install the PoseidonDNS
# server. It walks a user with zero Linux knowledge through every step,
# explains what is about to happen *before* doing it, and asks for
# confirmation between phases.
#
# Invocation (run on a fresh Linux VPS as root):
#
#     curl -fsSL https://raw.githubusercontent.com/DarkPoesidon/PoseidonDns/main/god_mode_install.sh | bash
#
# If you're not sure what any of that means, read guide.txt in this repo
# first. It explains the whole thing in plain English.
# =============================================================================

set -euo pipefail

# ---- Colours ----------------------------------------------------------------
if [[ -t 1 ]]; then
  C_RESET="\033[0m"; C_BOLD="\033[1m"; C_DIM="\033[2m"
  C_RED="\033[31m"; C_GREEN="\033[32m"; C_YELLOW="\033[33m"
  C_BLUE="\033[34m"; C_CYAN="\033[36m"
else
  C_RESET=""; C_BOLD=""; C_DIM=""
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

REPO_OWNER="${REPO_OWNER:-DarkPoesidon}"
REPO_NAME="${REPO_NAME:-PoseidonDns}"
UPSTREAM_INSTALLER_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/server_linux_install.sh"

# ---- Pretty printers --------------------------------------------------------
say()      { printf "%b\n" "$*"; }
header()   { printf "\n%b\n%b\n%b\n" "${C_BOLD}${C_CYAN}===============================================================================" "  $*" "===============================================================================${C_RESET}"; }
step()     { printf "\n%b▸ %s%b\n" "${C_BOLD}${C_BLUE}" "$*" "${C_RESET}"; }
explain()  { printf "%b  %s%b\n" "${C_DIM}" "$*" "${C_RESET}"; }
note()     { printf "%b  ℹ %s%b\n" "${C_CYAN}" "$*" "${C_RESET}"; }
ok()       { printf "%b  ✓ %s%b\n" "${C_GREEN}" "$*" "${C_RESET}"; }
warn()     { printf "%b  ⚠ %s%b\n" "${C_YELLOW}" "$*" "${C_RESET}"; }
fail()     { printf "%b  ✗ %s%b\n" "${C_RED}" "$*" "${C_RESET}"; exit 1; }

pause_for_user() {
  local prompt="${1:-Press Enter to continue, or Ctrl+C to abort...}"
  printf "\n%b%s%b " "${C_BOLD}${C_YELLOW}" "$prompt" "${C_RESET}"
  # If stdin is not a TTY (e.g. piped from curl), read from /dev/tty so the
  # script remains interactive even when invoked via curl | bash.
  if [[ -t 0 ]]; then
    read -r _ || true
  else
    read -r _ </dev/tty || true
  fi
}

# ---- Phase 0: Welcome -------------------------------------------------------
clear || true
header "Welcome to PoseidonDNS"

cat <<'EOF'

  This installer is going to do FIVE things, in order:

      1. Check that this machine is ready (root access, internet, basics).
      2. Install a couple of small system tools the server needs.
      3. Download the latest PoseidonDNS server program.
      4. Ask you a few simple questions to configure it.
      5. Start the server and show you the encryption key you'll need
         on your client devices.

  Before each step, it will tell you what is about to happen and wait
  for you to press Enter. You can press Ctrl+C at any point to abort
  cleanly.

  Total time: about 5 minutes.

EOF

pause_for_user "Ready? Press Enter to begin..."

# ---- Phase 1: Environment check --------------------------------------------
header "Step 1 of 5  -  Checking your server"

step "Checking you have root access"
explain "Installing system services requires admin rights. We're looking for"
explain "either: you are the 'root' user, or 'sudo' is available."
if [[ "$(id -u)" -eq 0 ]]; then
  ok "Running as root."
elif command -v sudo >/dev/null 2>&1; then
  warn "Not running as root, but sudo is available."
  warn "Please re-run with:    curl -fsSL <url> | sudo bash"
  exit 1
else
  fail "No root and no sudo. Log in as the root user and try again."
fi

step "Checking which Linux distribution you're on"
explain "Different Linux flavors use different package managers. We need to"
explain "know which one so we can install dependencies in Step 2."
PKG_MGR=""
if   command -v apt-get >/dev/null 2>&1; then PKG_MGR="apt"
elif command -v dnf     >/dev/null 2>&1; then PKG_MGR="dnf"
elif command -v yum     >/dev/null 2>&1; then PKG_MGR="yum"
elif command -v apk     >/dev/null 2>&1; then PKG_MGR="apk"
else
  fail "Unsupported distribution. Need one of: apt, dnf, yum, apk."
fi
ok "Detected package manager: ${PKG_MGR}"

step "Checking internet connectivity"
explain "We need to download the server program from GitHub."
if curl -fsSL --max-time 10 https://github.com >/dev/null 2>&1; then
  ok "GitHub is reachable."
else
  fail "Can't reach github.com. Check the VPS's network and try again."
fi

step "Checking the system architecture"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)  ARCH_LABEL="amd64";  ok "64-bit Intel/AMD CPU detected." ;;
  aarch64|arm64) ARCH_LABEL="arm64";  ok "64-bit ARM CPU detected." ;;
  *) fail "Unsupported CPU architecture: $ARCH (need x86_64 or arm64)." ;;
esac

# ---- Phase 2: Dependencies --------------------------------------------------
header "Step 2 of 5  -  Installing tools the server needs"

cat <<'EOF'

  We're going to install a handful of small command-line tools that the
  main installer uses internally:

      curl     - downloads files from the internet
      unzip    - extracts the server program archive
      ca-certs - so HTTPS downloads can be verified
      tar      - secondary archive extractor

  These are tiny (a few MB total) and standard on most VPS systems
  anyway. If they're already installed, nothing happens.

EOF

pause_for_user

step "Installing dependencies via ${PKG_MGR}"
case "$PKG_MGR" in
  apt)
    DEBIAN_FRONTEND=noninteractive apt-get update -y -qq >/dev/null 2>&1 || true
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
      curl ca-certificates unzip tar bash sed grep coreutils >/dev/null
    ;;
  dnf|yum)
    "$PKG_MGR" install -y -q curl ca-certificates unzip tar bash sed grep coreutils >/dev/null
    ;;
  apk)
    apk add --no-cache curl ca-certificates unzip tar bash sed grep coreutils >/dev/null
    ;;
esac
ok "All tools installed."

# ---- Phase 3: Hand off to upstream installer -------------------------------
header "Step 3 of 5  -  Downloading the PoseidonDNS server"

cat <<EOF

  We've reached the point where the real installer takes over. It will:

      a) Download the latest PoseidonDNS server binary from GitHub
         (the one matching your CPU: ${ARCH_LABEL}).
      b) Ask you for your DOMAIN NAME (the subdomain you set up in your
         DNS provider's panel - see guide.txt Step 1.1).
      c) Ask you to pick a DNS RECORD TYPE:
           1) TXT   - safest, works everywhere (recommended)
           2) NULL  - faster, works on most resolvers
           3) CNAME - reserved (falls back to TXT)
         If unsure, type 1.
      d) Ask whether to enable EDNS0 (bigger DNS responses, faster).
         The answer is almost always YES - just press Enter.
      e) Generate your ENCRYPTION KEY and start the server.

  COPY THE ENCRYPTION KEY when it appears - you'll paste it into your
  client_config.toml on every device you want to use.

EOF

pause_for_user "Press Enter to start the real installer..."

step "Fetching upstream installer"
TMP_SCRIPT="$(mktemp -t poseidon-install.XXXXXX.sh)"
trap 'rm -f "$TMP_SCRIPT"' EXIT

if ! curl -fsSL "$UPSTREAM_INSTALLER_URL" -o "$TMP_SCRIPT"; then
  fail "Failed to download installer from: $UPSTREAM_INSTALLER_URL"
fi
chmod +x "$TMP_SCRIPT"
ok "Installer downloaded."

header "Step 4 of 5  -  Configuring the server"
note "You'll see prompts from the underlying installer below. Read each one."
note "If a prompt has a default in [brackets], pressing Enter accepts it."
echo

bash "$TMP_SCRIPT" </dev/tty

# ---- Phase 5: Post-install summary -----------------------------------------
header "Step 5 of 5  -  All done"

cat <<'EOF'

  Your PoseidonDNS server should now be running. Here's a quick checklist
  for the next 5 minutes:

  [ ] Did you copy the ENCRYPTION KEY printed above? If not, scroll up.
      You can also find it on this server at:
          /opt/PoseidonDns/encrypt_key.txt   (path may vary)

  [ ] Was a file called client_recommended_settings.txt created?
      It has the DNS_RECORD_TYPE and EDNS_UDP_PAYLOAD_SIZE values you
      picked. You'll paste those into every client.

  [ ] Check the server is alive:
          systemctl status PoseidonDns       (or 'masterdnsvpn' on older builds)

  Next step: set up a client. Download the matching client zip from:
      https://github.com/DarkPoesidon/PoseidonDns/releases/latest

  Then follow PART 2 of guide.txt.

EOF

ok "Installer finished successfully."
echo
