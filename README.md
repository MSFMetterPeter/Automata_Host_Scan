Ez egy nmap automata host discovery script.
Magyar nyelv
Csak gyakorlásként csináltam de mivel jó lett ezért megosztom.
Ha bármi hibát tapasztalsz, kérlek jelezd.

Mi a célja?
Ez egy automatizált hálózati szkennelő szkript, amelynek célja a helyi hálózaton lévő aktív (online) hosztok felderítése az nmap eszköz segítségével. A szkript három különböző scan módot támogat, és képes az eredményeket fájlba menteni.

Hogyan működik? – Lépésről lépésre
1. Indítás és hálózat automatikus felderítése
bashTARGET=$(ip addr | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -n1)
Az ip addr parancs kimenetéből kiszűri az első nem-loopback hálózati interfész IP-címét/alhálózatát (pl. 192.168.1.0/24). Ez lesz a scan célpontja – nem kell kézzel megadni.

2. Argumentumok kezelése
KapcsolóLeírás-o <fájl>Kimenet mentése .xml és .txt formátumban-m <mód>Scan mód választása (lásd lent)-p <portok>Extra portok vizsgálata-vRészletes (verbose) kimenet-hSúgó megjelenítése

3. Scan módok
Standard (alapértelmezett)
bash-sn -PE -PP -PM -PS22,80,443,3389 -PA80,443

Csak host discovery, port scan nélkül
ICMP ping + TCP SYN/ACK probe-ok kombinációja
Gyors, mindennapi használatra szánt

Stealth (lopakodó)
bash-sS -T2 --randomize-hosts --data-length 15

Root jogot igényel
Lassú, félnyitott SYN csomagokat küld
Véletlenszerű hostsorrend + adathossz → nehezebb detektálni

Aggressive (agresszív)
bash-sS -O -sV -T4 -A

OS-detektálás, verziófelismerés, scriptek, traceroute
Gyors, de zajosabb – könnyen észlelhető
Top 100 portot vizsgál (vagy megadott portokat)


4. Összefoglaló
A szkript a scan után megszámlálja az aktív hosztokat:
bashONLINE_HOSTS=$(grep -c "Host is up" "$TEMP_OUTPUT")
Verbose módban kilistázza az aktív IP-címeket is.
