# PoseidonDNS

A high-throughput DNS-tunneling VPN. Your traffic is wrapped inside ordinary-looking DNS queries, so it gets through networks that block conventional VPN protocols — captive portals, restrictive corporate Wi-Fi, censored networks, and similar environments where UDP/TCP VPNs are dropped.

Forked from [masterking32/MasterDnsVPN](https://github.com/masterking32/MasterDnsVPN) with added support for **configurable DNS record types** (TXT / NULL) and **toggleable EDNS0** for higher throughput.

> [!WARNING]
> Use this tool responsibly. It is intended for personal privacy, network research, and CTF-style environments. Don't use it to break the law in your country.

---

## Quick Install (God Mode)

Run this **on your Linux VPS, as root**. It walks you through every step, explains what's about to happen before doing it, and waits for you to press Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/DarkPoesidon/PoseidonDns/main/god_mode_install.sh | bash
```

If that command makes no sense to you, **read [guide.txt](guide.txt) first** — it explains the whole setup in plain English for users with zero IT background, including how to rent a VPS, set up your domain, and connect from your laptop.

---

## What's in this fork

| Feature | Status |
|---|---|
| Configurable DNS record type (`TXT`, `NULL`) end-to-end | ✅ New |
| Configurable EDNS0 UDP payload size (0–4096) | ✅ New |
| Server auto-mirrors client's qtype (no negotiation drift) | ✅ New |
| "God mode" guided installer for non-technical users | ✅ New |
| Plain-English beginner guide ([guide.txt](guide.txt)) | ✅ New |
| Jacobson-style adaptive RTO, per-stream multiplexing, MLQ priority queue | ✅ Upstream |
| MTU discovery, packet duplication, compression (deflate/zstd) | ✅ Upstream |
| SOCKS5 client, local DNS cache | ✅ Upstream |

### Why NULL records?

`TXT` rdata is split into 255-byte strings, so a 3000-byte payload requires 12 length-prefix bytes of framing overhead. `NULL` records carry opaque rdata up to ~3500 bytes in a single answer — zero framing overhead. For resolvers that pass NULL through, this is a meaningful throughput win.

Pick the record type during install (the installer asks). Default is `TXT` for maximum compatibility.

---

## How it works (one-paragraph version)

The client encrypts your traffic, encodes it into DNS labels, and sends it as a normal-looking DNS query to a public DNS resolver. That resolver, following the rules of DNS, forwards the query to the *authoritative server* for the subdomain — which is your PoseidonDNS server. The server decrypts, forwards the real traffic to its destination, and tunnels the reply back the same way through the answer record. Because the network only ever sees DNS traffic to its trusted resolver, this works in environments that block other VPN protocols.

---

## Requirements

**Server side:**
- A Linux VPS (Debian 12 / Ubuntu 22.04+ / RHEL-family / Alpine all supported)
- A domain name you control DNS for
- Ability to set `A` and `NS` records at your registrar
- Root or sudo access

**Client side:**
- Windows 10/11, macOS (Intel or Apple Silicon), or Linux
- A SOCKS5-capable application (any modern browser via FoxyProxy, or system-wide proxy settings)

---

## Manual install (for advanced users)

If you'd rather skip the guided wrapper and run the underlying installer directly:

```bash
curl -fsSL https://raw.githubusercontent.com/DarkPoesidon/PoseidonDns/main/server_linux_install.sh | bash
```

This is the same installer the god-mode wrapper eventually invokes — it just doesn't pause to explain each step.

---

## Configuration

After install, the client side has two new keys in `client_config.toml` (section 1, near the encryption key):

```toml
# DNS record type used for tunnel queries.
# TXT  = standard, most compatible
# NULL = opaque rdata, higher per-record payload density
DNS_RECORD_TYPE = "TXT"

# EDNS0 advertised UDP payload size.
# 0 disables EDNS entirely; non-zero is clamped to 512..4096.
EDNS_UDP_PAYLOAD_SIZE = 4096
```

The server requires no configuration for these — it inspects each incoming question and answers in the same record type the client asked for. So the only place to set them is the client.

---

## Building from source

Standard Go build, requires Go 1.22+:

```bash
git clone https://github.com/DarkPoesidon/PoseidonDns.git
cd PoseidonDns
go build ./cmd/server   # produces ./server (Linux/macOS) or server.exe (Windows)
go build ./cmd/client   # produces ./client
```

Run the test suite:

```bash
go test ./...
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Client connects but websites don't load | Resolver path may strip NULL/EDNS | Set `DNS_RECORD_TYPE = "TXT"` and `EDNS_UDP_PAYLOAD_SIZE = 0` |
| `proxy refused connection` in browser | Client process not running | Start the client; check it's listening on `127.0.0.1:18000` |
| Server install fails at "Binary not found" | No release published in this repo yet | See note below about releases |
| Slow throughput | TXT chunking overhead | Try `DNS_RECORD_TYPE = "NULL"` |
| One-liner returns 404 | URL path or branch wrong | Confirm the URL points at this repo's `main` branch |

More detail in [guide.txt](guide.txt) → **Troubleshooting** section.

---

## Notes on releases

> [!IMPORTANT]
> For the one-line installer to download binaries, this repository needs a published GitHub Release containing the compiled server binaries (`PoseidonDns_server_linux_amd64.zip`, `_linux_arm64.zip`, etc.). Until you publish one, the installer will fall back to whatever is configured in `server_linux_install.sh` — check that file before relying on the one-liner publicly.

To cut a release locally:

```bash
GOOS=linux GOARCH=amd64 go build -o PoseidonDns_server_linux_amd64 ./cmd/server
GOOS=linux GOARCH=arm64 go build -o PoseidonDns_server_linux_arm64 ./cmd/server
# zip them, then:
gh release create v0.1.0 PoseidonDns_server_linux_*.zip --title "v0.1.0" --notes "Initial PoseidonDNS release"
```

A GitHub Actions workflow that builds on push lives in `.github/workflows/` — review it before relying on it for releases.

---

## Credits

- Upstream project: [masterking32/MasterDnsVPN](https://github.com/masterking32/MasterDnsVPN) — the original DNS-tunneling VPN this is forked from. All the hard architectural work (ARQ, MTU discovery, dispatcher, MLQ priority queue, encryption pipeline) is theirs.
- This fork adds: record-type/EDNS configurability, NULL-record transport, the god-mode installer, and the beginner guide.

---

## License

Same as upstream — see [LICENSE](LICENSE).
