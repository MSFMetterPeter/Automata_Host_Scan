#!/bin/bash
# Színek
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
#Ascii art Source:https://github.com/nmap/nmap/blob/master/docs/leet-nmap-ascii-art-eye.txt
cat << 'EOF'
                ___.-------.___
             _.-' ___.--;--.___ `-._
          .-' _.-'  /  .+.  \  `-._ `-.
        .' .-'      |-|-o-|-|      `-. `.
       (_ <O__      \  `+'  /      __O> _)
         `--._``-..__`._|_.'__..-''_.--'
               ``--._________.--''
  ____  _____  ____    ____       _       _______
 |_   \|_   _||_   \  /   _|     / \     |_   __ \
   |   \ | |    |   \/   |      / _ \      | |__) |
   | |\ \| |    | |\  /| |     / ___ \     |  ___/
  _| |_\   |_  _| |_\/_| |_  _/ /   \ \_  _| |_
 |_____|\____||_____||_____||____| |____||_____|
EOF
echo -e "${RED} Inditáshoz nyomj entert!"
read "enter"
echo -e "${GREEN}====================================="
echo -e "I${NC}    Nmap Host Discover Inditása${GREEN}    I"
echo -e "====================================="
echo -e "${GREEN}====================================="
echo -e "I${NC}    Author: MSF Metter Peter${GREEN}       I"
echo -e "=====================================${NC}"

# Hálózat kinyerése ip addr-ból (első nem-loopback inet cím)
TARGET=$(ip addr | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -n1)

if [ -z "$TARGET" ]; then
    echo "Nem találtam hálózati címet."
    exit 1
fi

echo "Megtalált hálózat: $TARGET"
echo "----------------------------------------"

# ---------- Alapértelmezett értékek ----------
OUTPUT_FILE=""
VERBOSE=false
SCAN_MODE="standard"   # standard | stealth | aggressive
PORTS=""

# ---------- Súgó ----------
usage() {
    echo -e "${CYAN}Host Discovery Script${NC}"
    echo ""
    echo "Használat: $0 [opciók] <célhálózat>"
    echo ""
    echo "Opciók:"
    echo "  -o <fájl>    Eredmények mentése fájlba (XML + txt)"
    echo "  -m <mód>     Scan mód: standard | stealth | aggressive (alap: standard)"
    echo "  -p <portok>  Extra portok vizsgálata (pl. 22,80,443)"
    echo "  -v           Részletes kimenet"
    echo "  -h           Súgó megjelenítése"
    echo ""
    echo "Példák:"
    echo "  $0 192.168.1.0/24"
    echo "  $0 -m stealth -o scan_results 10.0.0.0/24"
    echo "  $0 -m aggressive -p 8080,3306 172.16.0.0/16"
    exit 0
}

# ---------- Argumentumok feldolgozása ----------
while getopts "o:m:p:vh" opt; do
    case $opt in
        o) OUTPUT_FILE="$OPTARG" ;;
        m) SCAN_MODE="$OPTARG" ;;
        p) PORTS="$OPTARG" ;;
        v) VERBOSE=true ;;
        h) usage ;;
        *) echo "Ismeretlen opció: -$OPTARG"; usage ;;
    esac
done
shift $((OPTIND - 1))

TARGET="${TARGET}"

# ---------- Ellenőrzések ----------
if [[ -z "$TARGET" ]]; then
    echo -e "${RED}[HIBA]${NC} Nincs megadva célhálózat!"
    usage
fi

if ! command -v nmap &> /dev/null; then
    echo -e "${RED}[HIBA]${NC} Az nmap nincs telepítve. Telepítsd: sudo apt install nmap"
    exit 1
fi

# Root ellenőrzés (stealth/SYN scan-hez szükséges)
if [[ "$SCAN_MODE" == "stealth" ]] && [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}[FIGYELEM]${NC} A stealth mód root jogot igényel. Sudo-val futtasd!"
    exit 1
fi

# ---------- Banner ----------
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════╗"
echo "║        HOST DISCOVERY – nmap script      ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  Célhálózat : ${GREEN}$TARGET${NC}"
echo -e "  Scan mód   : ${GREEN}$SCAN_MODE${NC}"
echo -e "  Időpont    : $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ---------- Nmap paraméterek összeállítása ----------
NMAP_ARGS=()

case "$SCAN_MODE" in
    standard)
        # Ping sweep + ARP (helyi hálón gyors)
        NMAP_ARGS+=("-sn")                  # No port scan, csak host discovery
        NMAP_ARGS+=("--send-ip")            # IP-alapú ping
        NMAP_ARGS+=("-PE" "-PP" "-PM")      # ICMP echo, timestamp, netmask
        NMAP_ARGS+=("-PS22,80,443,3389")    # TCP SYN probe
        NMAP_ARGS+=("-PA80,443")            # TCP ACK probe
        NMAP_ARGS+=("--host-timeout" "5s")
        ;;
    stealth)
        # Csendes SYN scan (root szükséges)
        NMAP_ARGS+=("-sS")                  # SYN (half-open) scan
        NMAP_ARGS+=("-sn")
        NMAP_ARGS+=("-T2")                  # Lassú, kevésbé feltűnő timing
        NMAP_ARGS+=("--randomize-hosts")    # Véletlenszerű hostsorrend
        NMAP_ARGS+=("-PE")
        NMAP_ARGS+=("--data-length" "15")   # Véletlenszerű adathossz
        ;;
    aggressive)
        # Gyors, agresszív scan
        NMAP_ARGS+=("-sS" "-O")             # SYN + OS detection
        NMAP_ARGS+=("-sV" "--version-intensity" "5")  # Verziódetektálás
        NMAP_ARGS+=("-T4")                  # Gyors timing
        NMAP_ARGS+=("-A")                   # OS, verzió, script, traceroute
        NMAP_ARGS+=("-PE" "-PP")
        NMAP_ARGS+=("-PS21,22,23,25,80,443,3306,3389,8080,8443")
        if [[ -n "$PORTS" ]]; then
            NMAP_ARGS+=("-p" "$PORTS")
        else
            NMAP_ARGS+=("--top-ports" "100")
        fi
        ;;
    *)
        echo -e "${RED}[HIBA]${NC} Ismeretlen scan mód: $SCAN_MODE"
        exit 1
        ;;
esac

# Extra portok (nem aggressive módban)
if [[ -n "$PORTS" && "$SCAN_MODE" != "aggressive" ]]; then
    NMAP_ARGS+=("-p" "$PORTS")
fi

# Verbose
if $VERBOSE; then
    NMAP_ARGS+=("-v")
fi

# Output fájlok
if [[ -n "$OUTPUT_FILE" ]]; then
    NMAP_ARGS+=("-oX" "${OUTPUT_FILE}.xml")   # XML formátum
    NMAP_ARGS+=("-oN" "${OUTPUT_FILE}.txt")   # Normál szöveges
    echo -e "  Output     : ${GREEN}${OUTPUT_FILE}.xml / .txt${NC}"
fi

echo ""
echo -e "${YELLOW}[*] Scan indítása...${NC}"
echo -e "${YELLOW}[*] Parancs: nmap ${NMAP_ARGS[*]} $TARGET${NC}"
echo ""

# ---------- Scan futtatása ----------
TEMP_OUTPUT=$(mktemp)

nmap "${NMAP_ARGS[@]}" "$TARGET" | tee "$TEMP_OUTPUT"

# ---------- Összefoglaló ----------
echo ""
echo -e "${CYAN}══════════════════ ÖSSZEFOGLALÓ ══════════════════${NC}"

ONLINE_HOSTS=$(grep -c "Host is up" "$TEMP_OUTPUT" 2>/dev/null || echo 0)
echo -e "  Aktív hosztok száma : ${GREEN}${ONLINE_HOSTS}${NC}"

if $VERBOSE && [[ $ONLINE_HOSTS -gt 0 ]]; then
    echo ""
    echo -e "${GREEN}  Aktív IP-k:${NC}"
    grep "Nmap scan report" "$TEMP_OUTPUT" | awk '{print "    → "$NF}' | tr -d '()'
fi

echo ""
echo -e "  Befejezés : $(date '+%Y-%m-%d %H:%M:%S')"

if [[ -n "$OUTPUT_FILE" ]]; then
    echo -e "  Mentve    : ${OUTPUT_FILE}.txt és ${OUTPUT_FILE}.xml"
fi

echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"

rm -f "$TEMP_OUTPUT"

echo -e "A script lefutott nyomj entert miután megvizsgáltad"
read 
exit
