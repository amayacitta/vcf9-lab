## script originally from https://github.com/jhasensio
## adapted for use by https://github.com/amayacitta

if [[ $# -ne 2 ]] ; then
    echo 'Usage: check.sh fqdn_name interval'
    echo " where  server_name = FQDN of the server you want to check"
    echo "        interval = loop interval in seconds"
    echo
    echo "   Example:"
    echo -e "\033[1;33m"./check-dns.sh application01.aclab.uk 2"\033[0m"
    exit 0
fi

server=$1
interval=$2

while true; do
        echo -e "\033[0;31m--------------------------------------------------\033[0m"
        bold=$(tput bold)
        normal=$(tput sgr0)
        echo "${bold}DNS Response:${normal}"
        dnsAnswer=$(dig +noall +answer $server | grep IN)
        name=$(echo $dnsAnswer | awk '{print $1}')
        ttl=$(echo $dnsAnswer | awk '{print $2}')
        alias=$(echo $dnsAnswer | awk '{print $5}')
        ipAddress=$(echo $dnsAnswer | awk '{print $10}')
        echo -e "   DNS Name:" $name
        echo -e "   TTL: \033[1;33m"$ttl"\033[0m"
        echo -e "   Alias: \033[0;32m"$alias"\033[0m"
        echo -e "   IP Address: \033[0;32m"$ipAddress"\033[0m"
        # Displayserver response http headers
        echo "${bold}HTTP Header Response:${normal}"
        curl -m 2 $server -I -L
        echo -e "\033[0;31m--------------------------------------------------\033[0m"
        sleep $interval
done