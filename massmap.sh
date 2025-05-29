#!/bin/bash

VERSION="2.1"

UDP_SCAN=0
RESULTS_PATH=""
RATE=100000

usage() {
    echo -e "\nUsage: $0 [-u] [-d <results_directory>] [-t <rate>] <file-with-IP/CIDR>\n"
    exit 1
}

while getopts ":ud:t:" opt; do
    case $opt in
        u) UDP_SCAN=1 ;;
        d) RESULTS_PATH="$OPTARG" ;;
        t) RATE="$OPTARG" ;;
        \?) usage ;;
    esac
done
shift $((OPTIND-1))

TARGET="$1"
if [[ -z "$TARGET" ]]; then usage; fi

WORKING_DIR="$(cd "$(dirname "$0")" ; pwd -P)"
if [[ -z "$RESULTS_PATH" ]]; then
    RESULTS_PATH="$WORKING_DIR/results"
fi

RED="\033[1;31m"
GREEN="\033[1;32m"
BLUE="\033[1;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"

displayLogo(){
echo -e "${GREEN}                               
 _______                     _______              
|   |   |.---.-.-----.-----.|   |   |.---.-.-----.
|       ||  _  |__ --|__ --||       ||  _  |  _  |
|__|_|__||___._|_____|_____||__|_|__||___._|   __|${RESET} ${RED}v$VERSION${RESET}  
                                           ${GREEN}|__|${RESET}    by ${YELLOW}@CaptMeelo${RESET}\n
"
}

checkArgs(){
    if [[ ! -s $1 ]]; then
        echo -e "\t${RED}[!] ERROR:${RESET} File is empty and/or does not exist!\n"
        usage
    fi
}

scan_ports(){
    local proto=$1
    local masscan_opt nmap_opt suffix

    if [[ "$proto" == "udp" ]]; then
        masscan_opt="-pU:1-65535"
        nmap_opt="-sUV"
        suffix="-udp"
    else
        masscan_opt="-p 1-65535"
        nmap_opt="-sVC"
        suffix=""
    fi

    echo -e "${GREEN}[+] Running Masscan (${proto^^}).${RESET}"
    sudo masscan $masscan_opt --rate $RATE --wait 0 --open -iL $TARGET -oX "$RESULTS_PATH/masscan${suffix}.xml"
    if [ -f "$WORKING_DIR/paused.conf" ]; then
        sudo rm "$WORKING_DIR/paused.conf"
    fi
    open_ports=$(grep portid "$RESULTS_PATH/masscan${suffix}.xml" | cut -d "\"" -f 10 | sort -n | uniq | paste -sd,)
    grep portid "$RESULTS_PATH/masscan${suffix}.xml" | cut -d "\"" -f 4 | sort -V | uniq > "$WORKING_DIR/nmap_targets.tmp"
    echo -e "${RED}[*] Masscan ${proto^^} Done!"

    echo -e "${GREEN}[+] Running Nmap (${proto^^}).${RESET}"
    sudo nmap $nmap_opt -p $open_ports --open -v -Pn -n -T4 -iL "$WORKING_DIR/nmap_targets.tmp" -oX "$RESULTS_PATH/nmap${suffix}.xml"
    sudo rm "$WORKING_DIR/nmap_targets.tmp"
    xsltproc -o "$RESULTS_PATH/nmap${suffix}-native.html" "$RESULTS_PATH/nmap${suffix}.xml"
    xsltproc -o "$RESULTS_PATH/nmap${suffix}-bootstrap.html" "$WORKING_DIR/bootstrap-nmap.xsl" "$RESULTS_PATH/nmap${suffix}.xml"
    echo -e "${RED}[*] Nmap ${proto^^} Done! View the HTML reports at $RESULTS_PATH${RESET}"
}

displayLogo
checkArgs "$TARGET"

echo -e "${GREEN}[+] Checking if results directory already exists.${RESET}"
if [ -d "$RESULTS_PATH" ]
then
    echo -e "${BLUE}[-] Directory already exists. Skipping...${RESET}"
else
    echo -e "${GREEN}[+] Creating results directory.${RESET}"
    mkdir -p "$RESULTS_PATH"
fi

if [[ $UDP_SCAN -eq 1 ]]; then
    scan_ports "udp"
else
    scan_ports "tcp"
fi