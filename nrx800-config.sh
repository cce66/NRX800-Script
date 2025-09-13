#!/bin/bash
# cce66

# Variable Titre - Title
G_MODEL="NRX800"
G_VERSION="v1.1"
G_TITLE="$G_MODEL-GCE $G_VERSION"

# Variable globale langue ("fr" ou "en", défaut "fr"), Country_code, Timezone, OS
G_LANG="fr"
G_COUNTRY_CODE="FR"
G_TIMEZONE="Europe/Paris"
G_OS="debian"
G_PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Variable MESSAGE DE BIENVENUE - WELCOME MESSAGE
G_MESSAGE_FR="Bienvenue dans le script d'installation pour le NRX800 de GCE.
Il permet d'installer des logiciels (Node-Red, Home-Assistant etc)
sous forme de containers ou de packages, d'outils système pour la
sécurité comme OpenSSH, Fail2Ban, Ufw pour votre système NRX800,
de drivers pour le Raspberry Pi cm 4 (GPIO, horloge RTC).
Il permet aussi de configurer la carte réseau, le fuseau horaire,
changer le password et hostname, agrandir la partition du disque,
mettre en place l'overlay, réduire le système, configurer le NTP.
Il permet de changer l'ordre de démarrage (SD, NVMe,USB) et faire
des mises à jour (update et full-upgrade)."

G_MESSAGE_EN="Welcome to the installation script for the NRX800 by GCE.
It allows you to install software (Node-Red, Home-Assistant etc)
in the form of containers or system tool packages for security
such as OpenSSH, Fail2Ban, Ufw for your NRX800 system drivers
for the Raspberry Pi cm 4 (GPIO, RTC clock).
It also allows you to configure the network card, time zone,
change the password and hostname, enlarge the disk partition,
Set up the overlay, reduce the system, configure NTP.
It allows you to change the boot order (SD, NVMe, USB) and
perform updates (update and full-upgrade)."


##########   GESTION DES ERREURS - ERROR MANAGEMENT
# Si G_CLEAR <>"True" les messages affichés avec echo ne seront pas effacés pour permettre le débogage
G_CLEAR="True"

# Définir le fichier de log des erreurs
G_ERR_FILE="$(dirname "$0")/NRX800_err.log"

# Vide le fichier d'erreur à chaque exécution
> "$G_ERR_FILE"

# Redirige toutes les sorties (stdout et stderr) vers le fichier de log, tout en les affichant également dans le terminal.
exec &> >(tee -a "$G_ERR_FILE")

# Activer les options de débogage et de gestion des erreurs , arrêter le script en cas d'erreur 
# Enable debugging and error handling options, stop the script in case of error
#set -o errexit  
# Capturer les erreurs dans les pipelines -Capture errors in pipelines
set -o pipefail 

# Arrêter le script si une variable non définie est utilisée 
# set -o nounset  

# Fonction pour enregistrer les erreurs
# Function to log errors
function activate_error_log() {

  local msg_timestamp="$(active_timestamp)"
  local err_msg="[$msg_timestamp] Erreur détectée à la ligne $LINENO : $BASH_COMMAND \n"
  echo "$err_msg" >> "$G_ERR_FILE"
	
}

# Configurer le trap pour capturer les erreurs 
trap 'activate_error_log' ERR

##########   GESTION DU DEBOGAGE - MANAGEMENT DEBUGGING  

# Variable globale mode de débogage (0:sort|1:affiche|2:affiche-écris|3:écris|4:écris dans log et cmd)
# Global variable debug mode (0:sort|1:display|2:display-write|3:write|4:write to log and cmd)
G_DEBUG_MODE=3



##########   FONCTION GLOBALES - GLOBAL FUNCTIONS

# Fonction pour initialiser les variables globales
# Function to initialize global variables
function activate_globals_variables() {

  # Récupère l'IP de la machine 
  G_IP_HOST=$(hostname -I | awk '{print $1}')
  if [[ -z "${G_IP_HOST}" ]]; then
    G_IP_HOST="192.168.0.1"
  fi
  
  # 1. Initialisation des variables utilisateur
  if [ -n "$SUDO_USER" ]; then
    # Cas où le script est exécuté avec sudo
    G_USERNAME="$SUDO_USER"
    G_USER_DIR=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  else
    # Cas normal sans sudo
    G_USERNAME=$(whoami)
    G_USER_DIR="$HOME"
  fi

  # 2. Validation de l'utilisateur
  if ! id -u "$G_USERNAME" >/dev/null 2>&1; then
    echo "Erreur: Utilisateur '$G_USERNAME' non trouvé" >&2
    return 1
  fi

  # 3. Récupération des IDs utilisateur/groupe
  G_USER_ID=$(id -u "$G_USERNAME")
  G_USER_GROUP=$(id -gn "$G_USERNAME")
  G_USER_GROUP_ID=$(id -g "$G_USERNAME")

  # 4. Initialisation des fichiers de log
  # Chemin absolu du script
  local script_dir=$(dirname "$(readlink -f "$0")")
  G_FILE_CFG="${script_dir}/NRX800.cfg"
  G_FILE_CMD="${script_dir}/NRX800_cmd.log"
  G_FILE_LOG="${script_dir}/NRX800_debug.log"
  G_FILE_TMP="${script_dir}/NRX800_temp.sh"

  # 5. Initialisation des autres variables
  G_CHOICE=""

  # 6. Activation des autres variables globales
  activate_globals_variables_echo
  activate_globals_variables_containers
  activate_globals_variables_drivers
  activate_globals_variables_packages
  activate_globals_variables_packages_npm
  activate_globals_variables_packages_npm_node_red
  activate_globals_variables_system_tools

  # 7. Gestion des permissions des containers
  for container_name in "${!G_DOCKER_NAME[@]}"; do
    container_id="${G_DOCKER_NAME[$container_name]}"
    dir="/home/$G_USERNAME/docker/$container_id"
    
    # Création du répertoire s'il n'existe pas
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || {
            echo "Erreur: Impossible de créer $dir" >&2
            continue
        }
    fi
    # Vérifie les permissions
    check_and_set_permissions "$dir" "$G_USERNAME" "$G_USER_GROUP" 750
  done

  # Efface l'écran
  [ "$G_CLEAR" = "True" ] && clear

}
  
#### Tableaux pour la gestion des containers
#### Tables for containers management
function activate_globals_variables_containers() {

  # Pour obtenir une liste de containers avec leurs paramètres https://hub.docker.com/
  declare -gA G_DOCKER_NAME=(
    ["BunkerWeb"]="bunkerweb"
    ["Dozzle"]="dozzle"
    ["Gladys-Assistant"]="gladys"
    ["Grafana"]="grafana"
    ["Home-Assistant"]="home-assistant"
    ["Jeedom"]="jeedom"
    ["Lighttpd"]="lighttpd"
    ["Linux-Dash"]="linux-dash"
    ["Mosquitto"]="mosquitto"
    ["Node-Red"]="node-red"
    ["Php"]="php"
    ["OpenHAB"]="openhab"
    ["Portainer"]="portainer"
    ["Directus"]="directus"
    ["Metabase"]="metabase"
    ["InfluxDB"]="influxdb"
    ["Sqlite"]="sqlite"
    ["Syncthing"]="syncthing"
    ["Watchtower"]="watchtower"
    ["WireGuard"]="wireguard"
    ["WireGuard-UI"]="wireguard-ui"
    ["WireGuard-Easy"]="wg-easy"
    ["Zigbee2Mqtt"]="zigbee2mqtt"
  )
  declare -gA G_DOCKER_RESUME
  declare -gA G_DOCKER_RESUME_FR=(
    ["BunkerWeb"]='BunkerWeb est un serveur web sécurisé avec reverse proxy, gestion de certificats SSL et protection contre les attaques.'
    ["Directus"]='Directus est un CMS headless pour gérer des bases de données SQL via une API REST et GraphQL.'
    ["Dozzle"]='Dozzle est une interface web pour visualiser les logs des containers Docker en temps réel.'
    ["Gladys-Assistant"]='Gladys-Assistant est un assistant domestique open source pour automatiser et gérer votre maison intelligente.'
    ["Grafana"]="Grafana est un outil de visualisation et d'analyse de données, souvent utilisé avec des bases de données comme InfluxDB ou Prometheus."
    ["Home-Assistant"]='Home-Assistant est une plateforme de domotique centralisée pour contrôler et automatiser les appareils connectés.'
    ["InfluxDB"]='InfluxDB est une base de données temporelle optimisée pour les données de séries temporelles et les métriques.'
    ["Jeedom"]='Jeedom est une solution de domotique open source pour piloter et automatiser votre maison.'
    ["Lighttpd"]='Lighttpd est un serveur web léger et rapide, idéal pour les applications simples.'
    ["Linux-Dash"]='Linux-Dash est un tableau de bord web pour surveiller les performances du système Linux.'
    ["Metabase"]='Metabase est un outil de visualisation de données et de création de tableaux de bord interactifs.'
    ["Mosquitto"]='Mosquitto est un broker MQTT léger pour la communication entre appareils IoT.'
    ["Node-Red"]='Node-Red est un outil de programmation visuelle pour connecter des appareils IoT et des services.'
    ["OpenHAB"]='OpenHAB est une plateforme domotique open-source permettant de centraliser et automatiser divers appareils connectés.'
    ["Php"]='Php est un environnement d exécution PHP pour développer et exécuter des applications web.'
    ["Portainer"]='Potrainer est une interface de gestion web pour administrer les containers et services Docker.'
    ["Sqlite"]='Sqlite est une base de données SQL légère et embarquée, sans serveur.'
    ["Syncthing"]='Syncthing est un outil de synchronisation de fichiers peer-to-peer sécurisé et open-source.'
    ["Watchtower"]='Watchtower eest un service de mise à jour automatique des containers Docker.'
    ["WireGuard"]='WireGuard est un protocole VPN moderne, rapide et sécurisé qui utilise la cryptographie de pointe pour créer des tunnels réseau sécurisés.'
    ["WireGuard-UI"]="wireguard-ui admin admin"
    ["WireGuard-Easy"]="WireGuard-Easy est une interface web tout-en-un pour gérer un serveur WireGuard. Elle permet d'ajouter, supprimer et configurer des clients VPN facilement avec génération de QR codes."
    ["Zigbee2Mqtt"]='Zigbee2Mqtt est une passerelle pour connecter les appareils Zigbee à un broker MQTT.'
  )
  declare -gA G_DOCKER_RESUME_EN=(
    ["BunkerWeb"]='BunkerWeb is a secure web server with reverse proxy, SSL certificate management, and attack protection.'
    ["Directus"]='Directus is a headless CMS to manage SQL databases via a REST and GraphQL API.'
    ["Dozzle"]='Dozzle is a web interface to view Docker container logs in real time.'
    ["Gladys-Assistant"]='Gladys-Assistant is an open-source home assistant to automate and manage your smart home.'
    ["Grafana"]="Grafana is a data visualization and analytics tool, commonly used with databases like InfluxDB or Prometheus."
    ["Home-Assistant"]='Home-Assistant is a centralized home automation platform to control and automate connected devices.'
    ["InfluxDB"]='InfluxDB is a time-series database optimized for time-series data and metrics.'
    ["Jeedom"]='Jeedom is an open-source home automation solution to control and automate your home.'
    ["Lighttpd"]='Lighttpd is a lightweight and fast web server, ideal for simple applications.'
    ["Linux-Dash"]='Linux-Dash is a web dashboard to monitor Linux system performance.'
    ["Metabase"]='Metabase is a data visualization tool for creating interactive dashboards.'
    ["Mosquitto"]='Mosquitto is a lightweight MQTT broker for communication between IoT devices.'
    ["Node-Red"]='Node-Red is a visual programming tool to connect IoT devices and services.'
    ["Php"]='Php is a PHP runtime environment for developing and running web applications.'
    ["OpenHAB"]='OpenHAB is an open-source home automation platform that centralizes and automates various connected devices.'
    ["Portainer"]='Portainer is a web management interface to administer Docker containers and services.'
    ["Sqlite"]='Sqlite is a lightweight, serverless SQL database.'
    ["Syncthing"]='Syncthing is a secure, open-source peer-to-peer file synchronization tool.'
    ["Watchtower"]='Watchtower is a service for automatic Docker container updates.'
    ["WireGuard"]='WireGuard is a modern, fast, and secure VPN protocol that uses cutting-edge cryptography to create secure network tunnels.'
    ["WireGuard-UI"]="wireguard-ui"
    ["WireGuard-Easy"]="WireGuard-Easy is an all-in-one web interface to manage a WireGuard server. It allows adding, removing, and configuring VPN clients with QR code generation."
    ["Zigbee2Mqtt"]='Zigbee2Mqtt is a gateway to connect Zigbee devices to an MQTT broker.'
  )
  declare -gA G_DOCKER_CMD_INS=(
    ["BunkerWeb"]='sudo docker run -d --name bunkerweb -p 80:8080 -p 443:8443 -e SERVER_NAME=www.example.com --restart unless-stopped bunkerity/bunkerweb:1.5.12'
    ["Directus"]='sudo docker run -d --name directus -p 8055:8055 -v /home/${G_USERNAME}/docker/directus:/data --restart unless-stopped directus/directus:latest'
    ["Dozzle"]='docker run -d --name dozzle -p 58080:8080 -v "/var/run/docker.sock:/var/run/docker.sock" --restart unless-stopped amir20/dozzle:latest'
    ["Gladys-Assistant"]='sudo docker run -d --name gladys -p 53080:80 --log-driver json-file --log-opt max-size=10m --restart=always --network=bridge -e NODE_ENV=production -e SERVER_PORT=80 -e TZ=Europe/Paris -e SQLITE_FILE_PATH=/home/${G_USERNAME}/docker/gladysassistant -v /home/${G_USERNAME}/docker/gladysassistant:/var/lib/gladysassistant gladysassistant/gladys:v4'
    ["Grafana"]='sudo docker run -d --name grafana -p 3001:3000 -v "/home/${G_USERNAME}/docker/grafana:/var/lib/grafana" -e GF_SECURITY_ADMIN_USER="admin" -e GF_SECURITY_ADMIN_PASSWORD="admin" --user "$(id -u ${G_USERNAME}):$(id -g ${G_USERNAME})" --restart unless-stopped grafana/grafana-oss:latest'
    ["Home-Assistant"]='sudo docker run -d --name home-assistant -p 58123:8123 -v "/home/${G_USERNAME}/docker/home-assistant/config:/config" --user "$(id -u ${G_USERNAME}):$(id -g ${G_USERNAME})" --restart unless-stopped homeassistant/home-assistant:latest'
    ["InfluxDB"]='sudo docker run -d --name influxdb -p 8086:8086 -v "/home/${G_USERNAME}/docker/influxdb:/var/lib/influxdb" --restart unless-stopped influxdb:latest'
    ["Jeedom"]='sudo docker run -d --name jeedom -p 51080:80 -v "/home/${G_USERNAME}/docker/jeedom/www:/var/www/html" -v "/home/${G_USERNAME}/docker/jeedom/db:/var/lib/mysql" --restart unless-stopped jeedom/jeedom:latest'
    ["Lighttpd"]='sudo docker run -d --name lighttpd -p 52080:80 -v "/home/${G_USERNAME}/docker/lighttpd:/etc/lighttpd" --restart unless-stopped sebp/lighttpd:latest'
    ["Linux-Dash"]='sudo docker run -d --name linux-dash -p 53180:80 -e SERVER_PORT=80 --restart always alysivji/linux-dash'
    ["Metabase"]='sudo docker run -d --name metabase -p 3002:3000 -v "/home/${G_USERNAME}/docker/metabase:/metabase-data" --restart unless-stopped metabase/metabase:latest'
    ["Mosquitto"]='sudo docker run -d --name mosquitto -p 51883:1883 -p 9001:9001 -v "/home/${G_USERNAME}/docker/mosquitto/config:/mosquitto/config" --restart unless-stopped eclipse-mosquitto:latest'
    ["Node-Red"]='sudo docker run -d --name node-red -p 51880:1880 -v "/home/${G_USERNAME}/docker/node-red/data:/data" --user "$(id -u ${G_USERNAME}):$(id -g ${G_USERNAME})" --restart unless-stopped nodered/node-red:latest'
    ["OpenHAB"]='sudo docker run -d --name openhab -p 53080:8080 -p 50000:50000 -v "${OPENHAB_DIR}/addons:/openhab/addons" -v "${OPENHAB_DIR}/conf:/openhab/conf" -v "${OPENHAB_DIR}/userdata:/openhab/userdata" -e USER_ID=1000 -e GROUP_ID=1000 -e CRYPTO_POLICY=unlimited --restart unless-stopped openhab/openhab:latest'
    ["Php"]='sudo docker run -d --name php -p 59000:9000 -v "/home/${G_USERNAME}/docker/php/www:/var/www/html" --restart unless-stopped php:latest'
    ["Portainer"]='sudo docker run -d --name portainer -p 9000:9000 -p 9443:9443 -v "/var/run/docker.sock:/var/run/docker.sock" -v "/home/${G_USERNAME}/docker/portainer:/data" --restart unless-stopped portainer/portainer-ce:latest'
    ["Sqlite"]='sudo docker run -d --name sqlite -v "/home/${G_USERNAME}/docker/sqlite:/var/lib/sqlite" --restart unless-stopped nouchka/sqlite3:latest'
    ["Syncthing"]='sudo docker run -d --name syncthing -p 8384:8384 -p 22000:22000 -p 21027:21027/udp -v "/home/${G_USERNAME}/docker/syncthing:/var/syncthing" --restart unless-stopped syncthing/syncthing:latest'
    ["Watchtower"]='sudo docker run -d --name=watchtower -e TZ=Europe/Paris -e WATCHTOWER_CLEANUP=true -e WATCHTOWER_INCLUDE_STOPPED=true -e WATCHTOWER_REVIVE_STOPPED=false -e WATCHTOWER_INCLUDE_STOPPED=true -e WATCHTOWER_REVIVE_STOPPED=false -e -v /var/run/docker.sock:/var/run/docker.sock -v /home/${G_USERNAME}/docker/watchtower/email.yaml:/config/email.yaml --user $G_USER_ID:$G_USER_GROUP_ID --cap-drop=ALL --restart unless-stopped containrrr/watchtower:latest'
    ["WireGuard"]='docker run -d --name wireguard --cap-add NET_ADMIN --cap-add SYS_MODULE -e PUID=1000 -e PGID=1000 -e TZ=Europe/Paris -e SERVERURL=auto -e SERVERPORT=51820 -e PEERS=1 -e PEERDNS=auto -e INTERNAL_SUBNET=10.13.13.0 -e ALLOWEDIPS=0.0.0.0/0 -v /path/to/appdata/config:/config -v /lib/modules:/lib/modules -p 51820:51820/udp --restart unless-stopped lscr.io/linuxserver/wireguard'
    ["WireGuard-UI"]="sudo docker run -d --name wireguard-ui -v /etc/wireguard:/etc/wireguard -p 5000:5000 ngoduykhanh/wireguard-ui"
    ["WireGuard-Easy"]="sudo docker run -d --name wg-easy -e WG_HOST=192.168.1.216 -e PASSWORD=admin -v /etc/wireguard:/etc/wireguard -p 51820:51820/udp -p 51821:51821/tcp --cap-add=NET_ADMIN --cap-add=SYS_MODULE --sysctl net.ipv4.ip_forward=1 --restart unless-stopped ghcr.io/wg-easy/wg-easy"
    ["Zigbee2Mqtt"]='sudo docker run -d --name zigbee2mqtt -v "/home/${G_USERNAME}/docker/zigbee2mqtt/data:/app/data" --restart unless-stopped koenkk/zigbee2mqtt:latest'
  )
  declare -gA G_DOCKER_COMMANDS_UNINS=(
    ["BunkerWeb"]='sudo docker stop bunkerweb && sudo docker rm --volumes bunkerweb && sudo rm -rf "/home/${G_USERNAME}/docker/bunkerweb"'
    ["Directus"]='sudo docker stop directus && sudo docker rm --volumes directus && sudo rm -rf "/home/${G_USERNAME}/docker/directus"'
    ["Dozzle"]='sudo docker stop dozzle && sudo docker rm --volumes dozzle && sudo rm -rf "/home/${G_USERNAME}/docker/dozzle"'
    ["Gladys-Assistant"]='sudo docker stop gladys && sudo docker rm --volumes gladys && sudo rm -rf "/home/${G_USERNAME}/docker/gladysassistant"'
    ["Grafana"]='sudo docker stop grafana && sudo docker rm --volumes grafana && sudo rm -rf "/home/${G_USERNAME}/docker/grafana"'
    ["Home-Assistant"]='sudo docker stop home-assistant && sudo docker rm --volumes home-assistant && sudo rm -rf "/home/${G_USERNAME}/docker/home-assistant"'
    ["InfluxDB"]='sudo docker stop influxdb && sudo docker rm --volumes influxdb && sudo rm -rf "/home/${G_USERNAME}/docker/influxdb"'
    ["Jeedom"]='sudo docker stop jeedom && sudo docker rm --volumes jeedom && sudo rm -rf "/home/${G_USERNAME}/docker/jeedom"'
    ["Lighttpd"]='sudo docker stop lighttpd && sudo docker rm --volumes lighttpd && sudo rm -rf "/home/${G_USERNAME}/docker/lighttpd"'
    ["Linux-Dash"]='sudo docker stop linux-dash && sudo docker rm --volumes linux-dash && sudo rm -rf "/home/${G_USERNAME}/docker/linux-dash"'
    ["Metabase"]='sudo docker stop metabase && sudo docker rm --volumes metabase && sudo rm -rf "/home/${G_USERNAME}/docker/metabase"'
    ["Mosquitto"]='sudo docker stop mosquitto && sudo docker rm --volumes mosquitto && sudo rm -rf "/home/${G_USERNAME}/docker/mosquitto"'
    ["Node-Red"]='sudo docker stop node-red && sudo docker rm --volumes node-red && sudo rm -rf "/home/${G_USERNAME}/docker/node-red"'
    ["OpenHAB"]='sudo docker stop openhab && sudo docker rm --volumes openhab && sudo rm -rf "/home/${G_USERNAME}/docker/openhab"'
    ["Php"]='sudo docker stop php && sudo docker rm --volumes php && sudo rm -rf "/home/${G_USERNAME}/docker/php"'
    ["Portainer"]='sudo docker stop portainer && sudo docker rm --volumes portainer && sudo rm -rf "/home/${G_USERNAME}/docker/portainer"'
    ["Sqlite"]='sudo docker stop sqlite && sudo docker rm --volumes sqlite && sudo rm -rf "/home/${G_USERNAME}/docker/sqlite"'
    ["Syncthing"]='sudo docker stop syncthing && sudo docker rm --volumes syncthing && sudo rm -rf "/home/${G_USERNAME}/docker/syncthing"'
    ["Watchtower"]='sudo docker stop watchtower && sudo docker rm --volumes watchtower'
    ["WireGuard"]='sudo docker stop wireguard && sudo docker rm --volumes wireguard && sudo rm -rf "/home/${G_USERNAME}/docker/wireguard"'
    ["WireGuard-UI"]='sudo docker stop wireguard-ui --volumes wireguard && sudo rm -rf "/home/${G_USERNAME}/docker/wireguard-ui"'
    ["WireGuard-Easy"]='sudo docker stop wg-easy && sudo docker rm --volumes wg-easy && sudo rm -rf "/etc/wireguard"'
    ["Zigbee2Mqtt"]='sudo docker stop zigbee2mqtt && sudo docker rm --volumes zigbee2mqtt && sudo rm -rf "/home/${G_USERNAME}/docker/zigbee2mqtt"'
  )
    
}

#### Tableaux pour la gestion des pilotes 
#### Tables for drivers management
function activate_globals_variables_drivers() {

  declare -gA G_DRIVER_NAME=(
    ["gpio"]="GPIO"
    ["gpio-remote"]="GPIO Remote"
    ["i2c"]="I2C"
    ["rtc"]="RTC"
    ["ov_bt"]="Bluetooth Overlay"
    ["ov_i2c_rtc"]="I2C RTC Overlay"
    ["ov_vc4_kms_v3d"]="VC4 KMS V3D Overlay"
  )
  declare -gA G_DRIVER_RESUME
  declare -gA G_DRIVER_RESUME_FR=(
    ["gpio"]="Pilote pour la gestion des broches GPIO (General Purpose Input/Output)."
    ["gpio-remote"]="Pilote pour la gestion des broches GPIO à distance."
    ["i2c"]="Pilote pour la communication via le bus I2C (Inter-Integrated Circuit)."
    ["rtc"]="Pilote pour la gestion des horloges temps réel (RTC)."
    ["ov_bt"]="Overlay pour activer le support Bluetooth."
    ["ov_i2c_rtc"]="Overlay pour activer le support I2C et RTC."
    ["ov_vc4_kms_v3d"]="Overlay pour activer le support graphique VC4 KMS V3D."
  )
  declare -gA G_DRIVER_RESUME_EN=(
    ["gpio"]="Driver for managing GPIO (General Purpose Input/Output) pins."
    ["gpio-remote"]="Driver for managing remote GPIO pins."
    ["i2c"]="Driver for communication via the I2C (Inter-Integrated Circuit) bus."
    ["rtc"]="Driver for managing Real-Time Clocks (RTC)."
    ["ov_bt"]="Overlay to enable Bluetooth support."
    ["ov_i2c_rtc"]="Overlay to enable I2C and RTC support."
    ["ov_vc4_kms_v3d"]="Overlay to enable VC4 KMS V3D graphics support."
  )
  declare -gA G_DRIVER_COMMANDS=(
    ["gpio"]="menu_5_drivers_config_gpio"
    ["gpio-remote"]="menu_5_drivers_config_gpio_remote"
    ["i2c"]="menu_5_drivers_config_i2c"
    ["rtc"]="menu_5_drivers_config_rtc"
    ["ov_bt"]="menu_5_drivers_config_ov_bt"
    ["ov_i2c_rtc"]="menu_5_drivers_config_ov_i2c_rtc"
    ["ov_vc4_kms_v3d"]="menu_5_drivers_config_ov_vc4_kms_v3d"
  )
  declare -gA G_DRIVER_CMD_INS=(
    ["gpio"]="sudo apt-get install gpio-driver"
    ["gpio-remote"]="sudo apt-get install gpio-remote-driver"
    ["i2c"]="sudo apt-get install i2c-tools"
    ["rtc"]="sudo apt-get install rtc-ds1307"
    ["ov_bt"]="sudo dtoverlay pi3-disable-bt"
    ["ov_i2c_rtc"]="sudo dtoverlay i2c-rtc ds1307"
    ["ov_vc4_kms_v3d"]="sudo dtoverlay vc4-kms-v3d"
  )
  declare -gA G_DRIVER_CMD_UNINS=(
    ["gpio"]="sudo apt-get remove gpio-driver"
    ["gpio-remote"]="sudo apt-get remove gpio-remote-driver"
    ["i2c"]="sudo apt-get remove i2c-tools"
    ["rtc"]="sudo apt-get remove rtc-ds1307"
    ["ov_bt"]="sudo dtoverlay -r pi3-disable-bt"
    ["ov_i2c_rtc"]="sudo dtoverlay -r i2c-rtc"
    ["ov_vc4_kms_v3d"]="sudo dtoverlay -r vc4-kms-v3d"
  )

}

# Fonction pour initialiser les variables globales pour les messages echo
# Function to initialize global variables for echo messages
function activate_globals_variables_echo() {
 
  # Récupérer pour les commandes whiptail et echo le nombre de lignes du terminal (défaut : 24)
  G_TTY_ROWS=$(stty size | awk '{print $1}')
  # Récupérer pour les commandes whiptail et echo le nombre de colonnes du terminal (défaut : 80)
  G_TTY_COLS=$(stty size | awk '{print $2}')
 
	# Récupère la couleur actuelle du texte du terminal (foreground)
  G_TXT_COL_ORIGIN=$(tput colors)
  # Récupère la couleur actuelle du fond du terminal (background)
  G_BCK_COL_ORIGIN=$(tput setab)
	
  # Décomposition de \e[1;36m
  # 1 ️   \e[  → Séquence d'échappement ANSI, qui signale un changement de style ou de couleur.
  # 2     1;  → Définit le style du texte :
  #       0   = Réinitialisation (par défaut).
  #       1   = Gras ou couleur de haute intensité.
  #       4   = Souligné.
  #       7   = Inversion des couleurs (fond devient texte et inversement).
  # 3️     36  → Définit la couleur cyan (bleu clair).
  # 4     m   → Termine la séquence de formatage.
    
  # Couleurs Texte
  G_TXT_BLACK="\e[30m"         # Texte noir
  G_TXT_RED="\e[31m"           # Texte rouge
  G_TXT_GREEN="\e[32m"         # Texte vert
  G_TXT_YELLOW="\e[33m"        # Texte jaune
  G_TXT_BLUE="\e[34m"          # Texte bleu
  G_TXT_MAGENTA="\e[35m"       # Texte magenta
  G_TXT_CYAN="\e[36m"          # Texte cyan
  G_TXT_WHITE="\e[37m"         # Texte blanc
  # Couleurs Texte gras 
  G_TXT_BLACK_BD="\e[1;30m"    # Texte noir gras
  G_TXT_RED_BD="\e[1;31m"      # Texte rouge gras
  G_TXT_GREEN_BD="\e[1;32m"    # Texte vert gras
  G_TXT_YELLOW_BD="\e[1;33m"   # Texte jaune gras
  G_TXT_BLUE_BD="\e[1;34m"     # Texte bleu gras
  G_TXT_MAGENTA_BD="\e[1;35m"  # Texte magenta gras
  G_TXT_CYAN_BD="\e[1;36m"     # Texte cyan gras
  G_TXT_WHITE_BD="\e[1;37m"    # Texte blanc gras
  # Couleurs Texte clair
  G_TXT_BLACK_BR="\e[90m"      # Texte noir clair
  G_TXT_RED_BR="\e[91m"        # Texte rouge clair
  G_TXT_GREEN_BR="\e[92m"      # Texte vert clair
  G_TXT_YELLOW_BR="\e[93m"     # Texte jaune clair
  G_TXT_BLUE_BR="\e[94m"       # Texte bleu clair
  G_TXT_MAGENTA_BR="\e[95m"    # Texte magenta clair
  G_TXT_CYAN_BR="\e[96m"       # Texte cyan clair 
  G_TXT_WHITE_BR="\e[97m"      # Texte blanc clair
  
  # Couleurs fond
  G_BCK_BLACK="\e[40m"         # Fond noir
  G_BCK_RED="\e[41m"           # Fond rouge
  G_BCK_GREEN="\e[42m"         # Fond vert
  G_BCK_YELLOW="\e[43m"        # Fond yellow
  G_BCK_BLUE="\e[44m"          # Fond blue
  G_BCK_MAGENTA="\e[45m"       # Fond magenta
  G_BCK_CYAN="\e[46m"          # Fond cyan
  G_BCK_WHITE="\e[47m"         # Fond blanc
  # Couleurs fond clair
  G_BCK_BLACK_BR="\e[48m"      # Fond noir clair
  G_BCK_RED_BR="\e[49m"        # Fond rouge clair
  G_BCK_GREEN_BR="\e[50m"      # Fond vert clair
  G_BCK_YELLOW_BR="\e[51m"     # Fond jaune clair
  G_BCK_BLUE_BR="\e[52m"       # Fond bleu clair
  G_BCK_BR_MAGENTA="\e[53m"    # Fond magenta clair
  G_BCK_CYAN_BR="\e[54m"       # Fond cyan clair
  G_BCK_WHITE_BR="\e[55m"      # Fond blanc clair
  
  G_RESET_COLOR="\e[0m"        # Réinitialisation des couleurs
  
  # Icones unicode  # https://en.wikipedia.org/wiki/Emoji#Unicode_blocks
  G_ICO_ERROR="❌"
  G_ICO_SUCCESS="✅"
  G_ICO_ALERT="⚠️"
  G_ICO_INFO="ℹ️"
  G_ICO_LOAD="🔄️"
  G_ICO_WAIT="🔃️"
  G_ICO_HOURGLASS="⏳️"
  G_ICO_HOURGLASS_END="⌛️"
  G_ICO_FOLDER="📂️"
  G_ICO_FILE="📝"
  G_ICO_DISK="💾️"
  G_ICO_TOOL="🛠️"
  G_ICO_LAUNCH="🚀"
  G_ICO_QUESTION="❓"
  G_ICO_NETWORK="🌐" 
  G_ICO_PARAMETER="⚙" 
  G_ICO_MAINTENANCE="🔧"
  G_ICO_COMPUTER="️🖥"
  G_ICO_USER="️👤"
  G_ICO_BUILD="️🏗"
 	G_ICO_FLAG="🏁"
    
}

#### Tableaux pour la gestion des packages
#### Tables for packages management
function activate_globals_variables_packages() {

  declare -gA G_PACKAGE_NAME=(
    ["Grafana"]="grafana"
    ["Home-Assistant"]="home-assistant"
    ["InfluxDB"]="influxdb"
    ["Jeedom"]="jeedom"
    ["Lighttpd"]="lighttpd"
    ["Mosquitto"]="mosquitto"
    ["Node-Red"]="node-red"
    ["OpenHABian"]="openhabian"
    ["Php"]="php"
    ["Portainer"]="portainer" 
    ["Sqlite3"]="sqlite3"
    ["Syncthing"]="syncthing"
    ["Zigbee2Mqtt"]="zigbee2mqtt"
  )
  declare -gA G_PACKAGE_RESUME
  declare -gA G_PACKAGE_RESUME_FR=(
    ["Grafana"]="Grafana est un outil de visualisation et d'analyse de données, souvent utilisé avec des bases de données comme InfluxDB ou Prometheus."
    ["Home-Assistant"]="Home-Assistant est une plateforme de domotique centralisée pour contrôler et automatiser les appareils connectés."
    ["InfluxDB"]="InfluxDB est une base de données temporelle optimisée pour les données de séries temporelles et les métriques."
    ["Jeedom"]="Jeedom est une solution de domotique open source pour piloter et automatiser votre maison."
    ["Lighttpd"]="Lighttpd est un serveur web léger et rapide, idéal pour les applications simples."
    ["Mosquitto"]="Mosquitto est un broker MQTT léger pour la communication entre appareils IoT."
    ["Node-Red"]="Node-Red est un outil de programmation visuelle pour connecter des appareils IoT et des services."
    ["OpenHABian"]="OpenHABian est un système domotique optimisé basé sur OpenHAB, conçu pour fonctionner efficacement sur Raspberry Pi."
    ["Php"]="Php est un environnement d'exécution PHP pour développer et exécuter des applications web."
    ["Portainer"]="Portainer est une interface de gestion web pour administrer les containers et services Docker."
    ["Sqlite3"]="Sqlite3 est une base de données SQL légère et embarquée, sans serveur."
    ["Syncthing"]="Syncthing est un outil open-source de synchronisation de fichiers entre plusieurs appareils, sans serveur central."
    ["Zigbee2Mqtt"]="Zigbee2Mqtt est une passerelle pour connecter les appareils Zigbee à un broker MQTT."
  )

  declare -gA G_PACKAGE_RESUME_EN=(
    ["Grafana"]="Grafana is a data visualization and analytics tool, commonly used with databases like InfluxDB or Prometheus."
    ["Home-Assistant"]="Home-Assistant is a centralized home automation platform to control and automate connected devices."
    ["InfluxDB"]="InfluxDB is a time-series database optimized for time-series data and metrics."
    ["Jeedom"]="Jeedom is an open-source home automation solution to control and automate your home."
    ["Lighttpd"]="Lighttpd is a lightweight and fast web server, ideal for simple applications."
    ["Mosquitto"]="Mosquitto is a lightweight MQTT broker for communication between IoT devices."
    ["Node-Red"]="Node-Red is a visual programming tool to connect IoT devices and services."
    ["OpenHABian"]="OpenHABian is an optimized home automation system based on OpenHAB, designed to run efficiently on Raspberry Pi."
    ["Php"]="Php is a PHP runtime environment for developing and running web applications."
    ["Portainer"]="Portainer is a web management interface to administer Docker containers and services."
    ["Sqlite3"]="Sqlite3 is a lightweight, serverless SQL database."
    ["Syncthing"]="Syncthing is an open-source file synchronization tool that syncs files between devices without a central server."
    ["Zigbee2Mqtt"]="Zigbee2Mqtt is a gateway to connect Zigbee devices to an MQTT broker."
  )

  declare -gA G_PACKAGE_CMD_INS=(
    ["Grafana"]="sudo apt update && sudo apt install -y grafana && sudo systemctl enable grafana-server && sudo systemctl start grafana-server && systemctl status grafana-server --no-pager"
    ["Home-Assistant"]="sudo apt-get update && sudo apt-get install -y home-assistant && sudo systemctl enable home-assistant && sudo systemctl start home-assistant && systemctl status home-assistant --no-pager"
    ["InfluxDB"]="sudo apt-get update && sudo apt-get install -y influxdb2 && sudo systemctl enable influxdb && sudo systemctl start influxdb"
    ["Jeedom"]="sudo wget -O /tmp/install_jeedom.sh https://www.jeedom.com/install && sudo chmod +x /tmp/install_jeedom.sh && sudo /tmp/install_jeedom.sh && rm -f /tmp/install_jeedom.sh"
    ["Lighttpd"]="sudo apt-get install -y lighttpd && sudo systemctl enable lighttpd && sudo systemctl restart lighttpd && systemctl status lighttpd --no-pager"
    ["Mosquitto"]="sudo apt-get install -y mosquitto && sudo systemctl enable mosquitto && sudo systemctl restart mosquitto && systemctl status mosquitto --no-pager"
    ["Node-Red"]="sudo apt-get update && sudo apt-get install -y node-red && sudo systemctl enable node-red && sudo systemctl start node-red && systemctl status node-red --no-pager"
    ["Php"]="sudo apt-get install -y php"
    ["Sqlite3"]="sudo apt-get install -y sqlite3"
    ["Syncthing"]="sudo apt-get update && sudo apt-get install -y syncthing && sudo systemctl enable syncthing@${USER} && sudo systemctl start syncthing@${USER} && systemctl status syncthing@${USER} --no-pager"
    ["Zigbee2Mqtt"]="sudo curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs git make g++ gcc libsystemd-dev && sudo npm install -g pnpm && sudo mkdir /opt/zigbee2mqtt && sudo chown -R ${USER}: /opt/zigbee2mqtt && git clone --depth 1 https://github.com/Koenkk/zigbee2mqtt.git /opt/zigbee2mqtt && cd /opt/zigbee2mqtt && pnpm i --frozen-lockfile && sudo pnpm run build && cp /opt/zigbee2mqtt/data/configuration.example.yaml /opt/zigbee2mqtt/data/configuration.yaml && cd /opt/zigbee2mqtt && sudo pnpm start"
  )

  declare -gA G_PACKAGE_CMD_UNINS=(
    ["Grafana"]="sudo systemctl stop grafana-server && sudo systemctl disable grafana-server && sudo apt-get remove --purge -y grafana && sudo rm -rf /var/lib/grafana /etc/grafana"
    ["Home-Assistant"]="sudo systemctl stop home-assistant && sudo systemctl disable home-assistant && sudo apt-get remove --purge -y home-assistant"
    ["InfluxDB"]="sudo systemctl stop influxdb && sudo systemctl disable influxdb && sudo apt-get remove --purge -y influxdb2"
    ["Jeedom"]="sudo rm -rf /usr/local/bin/jeedom /var/www/html/jeedom /var/lib/mysql/jeedom"
    ["Lighttpd"]="sudo systemctl stop lighttpd && sudo systemctl disable lighttpd && sudo apt-get remove --purge -y lighttpd"
    ["Mosquitto"]="sudo systemctl stop mosquitto && sudo systemctl disable mosquitto && sudo apt-get remove --purge -y mosquitto"
    ["Node-Red"]="sudo systemctl stop node-red && sudo systemctl disable node-red && sudo apt-get remove --purge -y node-red"
    ["Php"]="sudo apt-get remove --purge -y php"
    ["Sqlite3"]="sudo apt-get remove --purge -y sqlite3"
    ["Syncthing"]="sudo systemctl stop syncthing@${USER} && sudo systemctl disable syncthing@${USER} && sudo apt-get remove --purge -y syncthing"
    ["Zigbee2Mqtt"]="sudo systemctl stop zigbee2mqtt && sudo systemctl disable zigbee2mqtt && sudo rm -rf /opt/zigbee2mqtt"
  )

}

#### Tableaux pour la gestion des package npm
#### Tables for packages npm management
function activate_globals_variables_packages_npm() {

  declare -gA G_PACKAGE_NPM_NAME=(
    ["Corepack"]="corepack"
    ["Directus"]="directus"
    ["InfluxDB"]="influxdb"
    ["Node-red"]="node-red"
    ["Npm"]="npm"
  )
	 declare -gA G_PACKAGE_NPM_RESUME
  declare -gA G_PACKAGE_NPM_RESUME_FR=(
    ["Corepack"]="Corepack est un gestionnaire de paquets pour les outils JavaScript comme Yarn et pnpm."
    ["Directus"]="Directus est une interface de gestion de contenu headless pour bases de données SQL."
    ["InfluxDB"]="InfluxDB est une base de données temporelle optimisée pour les données de séries temporelles et les métriques."
    ["Node-red"]="Node-Red est un outil de programmation visuelle pour connecter des appareils IoT et des services."
    ["Npm"]="Npm est le gestionnaire de paquets officiel pour Node.js, utilisé pour installer des bibliothèques JavaScript."
  )
  declare -gA G_PACKAGE_NPM_RESUME_EN=(
    ["Corepack"]="Corepack is a package manager for JavaScript tools like Yarn and pnpm."
    ["Directus"]="Directus is a headless content management interface for SQL databases."
    ["InfluxDB"]="InfluxDB is a time-series database optimized for time-series data and metrics."
    ["Node-red"]="Node-Red is a visual programming tool to connect IoT devices and services."
    ["Npm"]="Npm is the official package manager for Node.js, used to install JavaScript libraries."
  )
  declare -gA G_PACKAGE_NPM_CMD_INS=(  # @latest pour avoir le dernier, les numéros de version sont ceux de l'image
    ["Corepack"]="sudo npm install -g corepack@0.29.4"
    ["Directus"]="sudo npm install -g directus@latest"
    ["InfluxDB"]="sudo npm install -g influxdb@latest"
    ["Node-red"]="sudo npm install -g --unsafe-perm node-red@3.1.3"
# pour update du package ajouter à la fin de la commande : && bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered)
    ["Npm"]="sudo npm install -g --unsafe-perm npm@10.8.2"
  )
  declare -gA G_PACKAGE_NPM_CMD_UNINS=(
    ["Corepack"]="sudo npm uninstall -g corepack" 
    ["Directus"]="sudo npm uninstall -g directus"
    ["InfluxDB"]="sudo npm uninstall -g influxdb@latest"
    ["Node-red"]="sudo npm uninstall -g node-red"
    ["Npm"]="sudo npm uninstall -g npm"
  )
# bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered)
# sudo systemctl enable nodered.service

}

#### Tableaux pour la gestion des package npm de Node-red 
#### Tables for node-red packages npm management
function activate_globals_variables_packages_npm_node_red() {

  declare -gA G_PACKAGE_NPM_NODERED_NAME=(
    ["Buffer-Parser"]="node-red-contrib-buffer-parser" # node-red-contrib-buffer-parser@3.2.2 (image gce)
    ["Play-Audio"]="node-red-contrib-play-audio"       # node-red-contrib-play-audio@2.5.0 (image gce)
    ["Pi-GPIO"]="node-red-node-pi-gpio"                # node-red-node-pi-gpio@2.0.6 (image gce)
    ["Ping"]="node-red-node-ping"                      # node-red-node-ping@0.3.3 (image gce)
    ["Random"]="node-red-node-random"                  # node-red-node-random@0.4.1 (image gce)
    ["SerialPort"]="node-red-node-serialport"          # node-red-node-serialport@2.0.2 (image gce)
    ["Smooth"]="node-red-node-smooth"                  # node-red-node-smooth@0.1.2 (image gce)
  )
  declare -gA G_PACKAGE_NPM_NODERED_RESUME
  declare -gA G_PACKAGE_NPM_NODERED_RESUME_FR=(
    ["Buffer-Parser"]="Permet d'analyser et de manipuler des buffers binaires dans Node-RED."
    ["Play-Audio"]="Joue des fichiers audio ou du texte en synthèse vocale dans Node-RED."
    ["Pi-GPIO"]="Contrôle les broches GPIO du Raspberry Pi avec Node-RED."
    ["Ping"]="Permet d'envoyer des requêtes ping et de mesurer la latence dans Node-RED."
    ["Random"]="Génère des nombres aléatoires dans Node-RED."
    ["SerialPort"]="Ajoute la gestion des ports série dans Node-RED."
    ["Smooth"]="Applique un filtrage ou un lissage des données dans Node-RED."
  )
  declare -gA G_PACKAGE_NPM_NODERED_RESUME_EN=(
    ["Buffer-Parser"]="Allows parsing and manipulation of binary buffers in Node-RED."
    ["Play-Audio"]="Plays audio files or text-to-speech in Node-RED."
    ["Pi-GPIO"]="Controls Raspberry Pi GPIO pins with Node-RED."
    ["Ping"]="Sends ping requests and measures latency in Node-RED."
    ["Random"]="Generates random numbers in Node-RED."
    ["SerialPort"]="Adds serial port management in Node-RED."
    ["Smooth"]="Applies filtering or smoothing to data in Node-RED."
  )
  declare -gA G_PACKAGE_NPM_NODERED_CMD_INS=(
    ["Buffer-Parser"]="npm install -g node-red-contrib-buffer-parser"
    ["Play-Audio"]="npm install -g node-red-contrib-play-audio"
    ["Pi-GPIO"]="npm install -g node-red-node-pi-gpio"
    ["Ping"]="npm install -g node-red-node-ping"
    ["Random"]="npm install -g node-red-node-random"
    ["SerialPort"]="npm install -g node-red-node-serialport"
    ["Smooth"]="npm install -g node-red-node-smooth"
  )
  declare -gA G_PACKAGE_CMD_NPM_NODERED_UNINS=(
    ["Buffer-Parser"]="npm uninstall -g node-red-contrib-buffer-parser"
    ["Play-Audio"]="npm uninstall -g node-red-contrib-play-audio"
    ["Pi-GPIO"]="npm uninstall -g node-red-node-pi-gpio"
    ["Ping"]="npm uninstall -g node-red-node-ping"
    ["Random"]="npm uninstall -g node-red-node-random"
    ["SerialPort"]="npm uninstall -g node-red-node-serialport"
    ["Smooth"]="npm uninstall -g node-red-node-smooth"
  )

}

#### Tableaux pour la gestion des outils système
#### Tables for tools system management
function activate_globals_variables_system_tools() {

  declare -gA G_SYSTEM_TOOL_NAME=(
    ["Docker-ce"]="docker-ce"
    ["Fail2Ban"]="fail2ban"
    ["Midnight-Commander"]="mc"
    ["Ntp-Server"]="ntp"
    ["OpenSSH-Server"]="openssh-server"
    ["OpenVpn"]="openvpn"
    ["Samba-Client"]="smbclient"
    ["Ufw"]="ufw"
    ["WireGuard"]="wireguard"
  )
  declare -gA G_SYSTEM_TOOL_RESUME
  declare -gA G_SYSTEM_TOOL_RESUME_FR=(
    ["Docker-ce"]="Docker-ce est une plateforme de conteneurisation qui permet de créer, déployer et exécuter des applications dans des conteneurs."
    ["Fail2Ban"]="Fail2Ban est un outil de sécurité qui protège les serveurs contre les attaques par force brute."
    ["Midnight-Commander"]="Midnight-Commander est un gestionnaire de fichiers en mode texte pour les systèmes Linux."
    ["Ntp-Server"]="Ntp-Server est un serveur de synchronisation de temps pour les réseaux informatiques."
    ["OpenSSH-Server"]="OpenSSH-Server est un serveur SSH pour accéder et gérer des systèmes à distance de manière sécurisée."
    ["OpenVpn"]="OpenVpn est un logiciel de réseau privé virtuel (VPN) pour créer des connexions sécurisées."
    ["Samba-Client"]="Samba-Client est un client pour accéder aux partages de fichiers et d'imprimantes sur les réseaux Windows."
    ["Ufw"]="Ufw (Uncomplicated Firewall) est un outil de gestion de pare-feu simple à utiliser pour les systèmes Linux."
    ["WireGuard"]="WireGuard est un VPN moderne, rapide et sécurisé pour établir des connexions chiffrées entre machines."
  )
  declare -gA G_SYSTEM_TOOL_RESUME_EN=(
    ["Docker-ce"]="Docker-ce is a containerization platform that allows you to create, deploy, and run applications in containers."
    ["Fail2Ban"]="Fail2Ban is a security tool that protects servers against brute-force attacks."
    ["Midnight-Commander"]="Midnight-Commander is a text-mode file manager for Linux systems."
    ["Ntp-Server"]="Ntp-Server is a time synchronization server for computer networks."
    ["OpenSSH-Server"]="OpenSSH-Server is an SSH server for securely accessing and managing remote systems."
    ["OpenVpn"]="OpenVpn is a virtual private network (VPN) software for creating secure connections."
    ["Samba-Client"]="Samba-Client is a client for accessing file and printer shares on Windows networks."
    ["Ufw"]="Ufw (Uncomplicated Firewall) is an easy-to-use firewall management tool for Linux systems."
    ["WireGuard"]="WireGuard is a modern, fast, and secure VPN for creating encrypted connections between machines."
  )
  declare -gA G_SYSTEM_TOOL_COMMANDS=(
    ["Docker-ce"]="menu_4_system_tools_docker_ce"
    ["Fail2Ban"]="menu_4_system_tools_fail2ban"
    ["Midnight-Commander"]="menu_4_system_tools_mc"
    ["Ntp-Server"]="menu_4_system_tools_ntp_server"
    ["OpenSSH-Server"]="menu_4_system_tools_openssh_server"
    ["OpenVpn"]="menu_4_system_tools_openvpn"
    ["Samba-Client"]="menu_4_system_tools_smbclient"
    ["Ufw"]="menu_4_system_tools_ufw"
    ["WireGuard"]="menu_4_system_tools_wireguard"
  )
  declare -gA G_SYSTEM_TOOL_CHECK=(
    ["Docker-ce"]="command -v docker >/dev/null 2>&1"
    ["Fail2Ban"]="command -v fail2ban-client >/dev/null 2>&1"
    ["Midnight-Commander"]="command -v mc >/dev/null 2>&1"
    ["Ntp-Server"]="dpkg-query -W ntp 2>/dev/null | grep -q 'install ok installed'"
    ["OpenSSH-Server"]="systemctl is-active --quiet ssh"
    ["OpenVpn"]="command -v openvpn >/dev/null 2>&1"
    ["Samba-Client"]="command -v smbclient >/dev/null 2>&1"
    ["Ufw"]="command -v ufw >/dev/null 2>&1"
    ["WireGuard"]="apt list --installed wireguard-tools 2>/dev/null | grep -q 'wireguard-tools'"
  )
  
}

# Renvoie une valeur comme : 2025-03-22 01:39:36
# Returns a value like : 2025-03-22_01:39:36_CET
function active_timestamp() { 
  # utilisation : echo "$(timestamp)"
  printf "%(%F %T)T\\n" "-1"; 

}



##########   FONCTIONS DIVERSES - VARIOUS FUNCTIONS

# Fonction pour vérifier et ajuster les permissions des répertoires
# Function to check and adjust directory permissions
function check_and_set_permissions() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local dir_not_exist_msg="Le répertoire $dir n'existe pas./nCréation du répertoire..."
    local adjust_permissions_msg="Ajustement des permissions pour $dir..."
    local success_msg="Permissions vérifiées et ajustées avec succès pour $dir."
    local error_missing_args="Erreur: Tous les arguments (dir, user, group) doivent être fournis."
    local error_create_dir="Erreur: Impossible de créer le répertoire $dir."
    local error_stat="Erreur: Impossible de récupérer les informations de $dir."
    local error_chown="Erreur: Impossible de modifier le propriétaire/groupe de $dir."
    local error_chmod="Erreur: Impossible de modifier les permissions de $dir."
  else
    local dir_not_exist_msg="The directory $dir does not exist./nCreating the directory..."
    local adjust_permissions_msg="Adjusting permissions for $dir..."
    local success_msg="Permissions checked and adjusted successfully for $dir."
    local error_missing_args="Error: All arguments (dir, user, group) are required."
    local error_create_dir="Error: Failed to create the directory $dir."
    local error_stat="Error: Failed to retrieve information for $dir."
    local error_chown="Error: Failed to change owner/group for $dir."
    local error_chmod="Error: Failed to change permissions for $dir."
  fi

  # Récupère les paramètres
  local dir="$1"
  local user="$2"
  local group="$3"
  local permissions="$4"

  # Vérifie si les arguments sont fournis
  if [[ -z "$dir" || -z "$user" || -z "$group" || -z "$permissions" ]]; then
    echo "$error_missing_args" >&2
    return 1
  fi

  # Valide les permissions
  if ! [[ "$permissions" =~ ^[0-7]{3}$ ]]; then
    echo "$error_invalid_permissions" >&2
    return 1
  fi
  
  # Vérifie si le répertoire existe, sinon le crée
  if [ ! -d "$dir" ]; then
    echo "$dir_not_exist_msg"
    if ! mkdir -p "$dir"; then
      echo "$error_create_dir" >&2
      return 1
    fi
  fi

  # Vérifie les permissions actuelles
  local current_owner current_group current_permissions
  if ! current_owner=$(stat -c '%U' "$dir" 2>/dev/null); then
    echo "$error_stat" >&2
    return 1
  fi
  if ! current_group=$(stat -c '%G' "$dir" 2>/dev/null); then
    echo "$error_stat" >&2
    return 1
  fi
  if ! current_permissions=$(stat -c '%a' "$dir" 2>/dev/null); then
    echo "$error_stat" >&2
    return 1
  fi

  # Ajuste les permissions si nécessaire
  if [ "$current_owner" != "$user" ] || [ "$current_group" != "$group" ] || [ "$current_permissions" != "$permissions" ]; then
    echo "$adjust_permissions_msg"
    if ! chown -R "$user:$group" "$dir"; then
      echo "$error_chown" >&2
      return 1
    fi
    if ! chmod "$permissions" "$dir"; then
      echo "$error_chmod" >&2
      return 1
    fi
  fi

  # Succès
  # echo "$success_msg"
  return 0
    
}

# Fonction pour récupérer le "country code"
# Function to check "Country code"
function check_country_code() {

  # Récupérer le pays basé sur l'IP publique
  G_COUNTRY_CODE=$(curl -s http://ipinfo.io/country)

  # Vérifier si la récupération du pays a fonctionné
  if [ -z "$G_COUNTRY_CODE" ]; then
    G_COUNTRY_CODE=""
    exit 1
  fi
  
  # Si le country code est "FR" alors affecte à la variable G_LANG la valeur "fr"
  if [[ "$G_COUNTRY_CODE" == "FR" ]]; then
    G_LANG="fr"
  fi
 
}

# Fonction pour vérifier le système d'exploitation
# Function to check operting system
function check_operating_system() {
  
  # Vérifie si le fichier /etc/debian_version existe (spécifique aux distrib Debian comme Ubuntu, Debian, etc.)
  if [[ -e /etc/debian_version ]]; then
    G_OS=$(hostnamectl | grep "Operating System" | awk -F': ' '{print $2}')
    # Charge les informations du fichier /etc/os-release ($ID, $VERSION etc)
    source /etc/os-release
    # Vérifie si la variable $ID (chargée depuis /etc/os-release) est égale à "raspbian"
    if [[ $ID = "raspbian" ]]; then
      G_OS="raspbian"
      return 0
    fi
  else
    G_OS=""
  fi
    
}

# Fonction pour récupérer le "timezone"
# Function to check "timezone"
function check_timezone() {

  # Associer le pays à un fuseau horaire
  G_TIMEZONE=$(curl -s http://ipinfo.io/timezone)

  # Vérifier si le fuseau horaire est valide
  if [ -z "$G_TIMEZONE" ]; then
    G_TIMEZONE=""
    exit 1
  fi

}

# Fonction pour vérifier si whiptail est installé, si absent installe, arrêt du script si échec
# Function to check if whiptail is installed, if absent install, stop script if failed
function check_whiptail() {

  if ! command -v whiptail &> /dev/null; then
    echo "Whiptail n'est pas installé. Installation en cours...\nWhiptail is not installed. Installing..."
    cmd_execute "sudo apt-get update && sudo apt-get install -y whiptail"
    if ! command -v whiptail &> /dev/null; then
      echo "Impossible d'installer Whiptail. Arrêt du script.\nFailed to install Whiptail. Exiting script."
      pause 3
      exit 1
    fi
  fi

}

# Fonction pour lancer une commande et gérer les erreurs
# Function to launch a command and handle errors
function cmd_execute() {
  
  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_error="Erreur : Code $error_code dans la fonction $caller_function lors de l'exécution de la commande : $cmd"
  else
    local msg_error="Error: Code $error_code in function $caller_function while executing command: $cmd"
  fi

  # Récupère le nom de la fonction où cmd_execute a été appelée
  local caller_function="${FUNCNAME[1]}"
  # Récupère la commande passée en paramètre
  local cmd=$1

  # Exécute la commande passée en paramètre
  eval "$cmd"
  local error_code=$?

  # Si une erreur survient
  if [ "$error_code" -ne 0 ]; then
    # Log l'erreur avec la fonction debug
    debug "err : $error_code / func : $caller_function / cmd : eval $cmd" "$error_code"
    # Affiche un message d'erreur avec whiptail
    echo_msgbox "$msg_error" "$G_TITLE"
    return $error_code
  fi

  return 0
  
}

# Fonction pour lire-écrire les paramètres dans le fichier nrx800.cfg
# Function to read-write parameters in nrx800.cfg file
function config_params_load_write() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_file_exists="Le fichier $G_FILE_CFG existe déjà. Chargement des paramètres..."
    local msg_file_not_exists="Le fichier $G_FILE_CFG n'existe pas. Création du fichier et écriture des paramètres..."
    local msg_params_loaded="Les paramètres ont été chargés depuis $G_FILE_CFG."
    local msg_params_written="Les paramètres ont été écrits dans $G_FILE_CFG."
    local msg_err_not_load_parameter="Erreur : Impossible de charger les paramètres depuis $G_FILE_CFG."
    local msg_err_not_write_parameter="Erreur : Impossible d'écrire les paramètres dans $G_FILE_CFG."
  else
    local msg_file_exists="The file $G_FILE_CFG already exists. Loading parameters..."
    local msg_file_not_exists="The file $G_FILE_CFG does not exist. Creating the file and writing parameters..."
    local msg_params_loaded="Parameters have been loaded from $G_FILE_CFG."
    local msg_params_written="Parameters have been written to $G_FILE_CFG."
    local msg_err_not_load_parameter="Error: Failed to load parameters from $G_FILE_CFG."
    local msg_err_not_write_parameter="Error: Failed to write parameters to $G_FILE_CFG."
  fi

  # Si le fichier existe déjà
  if [[ -f "$G_FILE_CFG" ]]; then
    # Chargement des paramètres
    whiptail --infobox "$msg_file_exists" 15 70 --fb --title "$G_TITLE"
    if ! source "$G_FILE_CFG"; then
      echo_msgbox "$msg_err_not_load_parameter" "$G_TITLE"
      return 1
    fi
    whiptail --infobox "$msg_params_loaded" 15 70 --fb --title "$G_TITLE"
  else
    # Si le fichier n'existe pas
    whiptail --infobox "$msg_file_not_exists" 15 70 --fb --title "$G_TITLE"

    # Écriture des paramètres dans le fichier
    {
      echo "# Variables globales pour stocker les paramètres des conteneurs"
      echo "declare -A G_DOCKER_CMD_INS=("
      for key in "${!G_DOCKER_CMD_INS[@]}"; do
        echo "  [\"$key\"]=\"${G_DOCKER_CMD_INS[$key]}\""
      done
      echo ")"

      echo "# Variables globales pour stocker les paramètres des packages"
      echo "declare -A G_PACKAGE_CMD_INS=("
      for key in "${!G_PACKAGE_CMD_INS[@]}"; do
        echo "  [\"$key\"]=\"${G_PACKAGE_CMD_INS[$key]}\""
      done
      echo ")"

      echo "# Variables globales pour stocker les paramètres des packages npm"
      echo "declare -A G_PACKAGE_NPM_CMD_INS=("
      for key in "${!G_PACKAGE_NPM_CMD_INS[@]}"; do
        echo "  [\"$key\"]=\"${G_PACKAGE_NPM_CMD_INS[$key]}\""
      done
      echo ")"

      echo "# Variables globales pour stocker les paramètres des pilotes"
      echo "declare -A G_DRIVER_COMMANDS=("
      for key in "${!G_DRIVER_COMMANDS[@]}"; do
        echo "  [\"$key\"]=\"${G_DRIVER_COMMANDS[$key]}\""
      done
      echo ")"

      echo "# Variables globales pour stocker les paramètres des outils système"
      echo "declare -A G_SYSTEM_TOOL_COMMANDS=("
      for key in "${!G_SYSTEM_TOOL_COMMANDS[@]}"; do
        echo "  [\"$key\"]=\"${G_SYSTEM_TOOL_COMMANDS[$key]}\""
      done
      echo ")"
    } > "$G_FILE_CFG"

    # Vérifie si l'écriture a réussi
    if [ $? -ne 0 ]; then
      echo_msgbox "$msg_err_not_write_parameter" "$G_TITLE"
      return 1
    fi

    whiptail --infobox "$msg_params_written" 15 70 --fb --title "$G_TITLE"
  fi

  return 0
  
}

# Fonction pour redémarrer avec un compte à rebours
# Function to restart with a countdown timer
function countdown_before_reboot() {
  
  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    msg_reboot_in="Redémarrage dans"
  else
    msg_reboot_in="Reboot in"
  fi

  # Boucle de compte à rebours
  for ii in {5..1}; do
    [ "$G_CLEAR" == "True" ] && clear

    # Construire le message complet
    local msg_reboot="$msg_reboot_in $ii secondes..."

    # Calculer la largeur du message et ajouter un minimum de marge
    message_length=${#msg_reboot}
    frame_width=$((message_length + 10)) # Ajout de marges pour le cadre

    # S'assurer que la largeur du cadre ne dépasse pas la largeur du terminal
    if [ "$frame_width" -gt "$G_TTY_COLS" ]; then
      frame_width=$((G_TTY_COLS - 2))  # Ajuster pour ne pas dépasser la largeur
    fi

    # Calculer le padding pour centrer horizontalement dans le terminal
    horizontal_padding=$(( (G_TTY_COLS - frame_width) / 2 ))

    # Calculer le padding pour centrer le message dans le cadre
    padding_left=$(( (frame_width - message_length) / 2 ))
    padding_right=$(( frame_width - message_length - padding_left ))

    # Ajuster le centrage si la largeur est impaire
    if (( (frame_width - message_length) % 2 != 0 )); then
      padding_right=$((padding_right + 1))
    fi

    # Calculer les lignes vides nécessaires pour centrer verticalement
    vertical_padding=$(( (G_TTY_ROWS - 5) / 2 )) # 5 lignes pour le cadre

    # Dessiner les lignes vides au-dessus du texte
    for ((i=0; i<vertical_padding; i++)); do
      echo
    done

    # Ajouter l'indentation pour centrer horizontalement
    indent=$(printf "%*s" "$horizontal_padding" "")

    # Dessiner le cadre supérieur
    printf "%s $G_TXT_RED╭%s╮$G_RESET_COLOR\n" "$indent" "$(printf '─%.0s' $(seq 1 $frame_width))"

    # Dessiner une ligne vide dans le cadre
    printf "%s $G_TXT_RED│%*s│$G_RESET_COLOR\n" "$indent" "$frame_width" ""

    # Afficher le message centré avec correction d'alignement
    printf "%s $G_TXT_RED│%*s$G_BCK_MAGENTA$G_TXT_BLACK%s$G_BCK_BLACK$G_TXT_RED%*s│\e[0m\n" "$indent" "$padding_left" "" "$msg_reboot" "$padding_right" ""

    # Dessiner une ligne vide dans le cadre
    printf "%s $G_TXT_RED│%*s│$G_RESET_COLOR\n" "$indent" "$frame_width" ""

    # Dessiner le cadre inférieur
    printf "%s $G_TXT_RED╰%s╯$G_RESET_COLOR\n" "$indent" "$(printf '─%.0s' $(seq 1 $frame_width))"

    # Dessiner les lignes vides en dessous du texte
    for ((i=0; i<vertical_padding; i++)); do
      echo
    done

    sleep 1
  done

  [ "$G_CLEAR" == "True" ] && clear
  sudo reboot
  exit
  
}

# Fonction pour créer et exécuter un script temporaire
# Function to create and execute a temporary script
function create_and_execute_temp_script() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_error_no_command="Erreur: Aucune commande personnalisée fournie."
    local msg_error_no_dir="Erreur: Le répertoire utilisateur $G_USER_DIR n'existe pas."
    local msg_error_create_script="Erreur: Impossible de créer le script temporaire $G_FILE_TMP."
    local msg_error_add_command="Erreur: Impossible d'ajouter la commande au script temporaire."
    local msg_error_make_executable="Erreur: Impossible de rendre le script temporaire exécutable."
    local msg_warning_delete_script="Avertissement: Impossible de supprimer le script temporaire $G_FILE_TMP."
  else
    local msg_error_no_command="Error: No custom command provided."
    local msg_error_no_dir="Error: User directory $G_USER_DIR does not exist."
    local msg_error_create_script="Error: Failed to create temporary script $G_FILE_TMP."
    local msg_error_add_command="Error: Failed to add command to temporary script."
    local msg_error_make_executable="Error: Failed to make temporary script executable."
    local msg_warning_delete_script="Warning: Failed to delete temporary script $G_FILE_TMP."
  fi

  # Récupère les paramètres
  local custom_command=$1
  local caller_function=$2  # Nom de la fonction appelante
  local name="$3"
  
  # Affiche dans le terminal le début du traitement
  echo_process_start  

  # Vérifie si la commande personnalisée est fournie
  if [[ -z "$custom_command" ]]; then
    printf "${G_TXT_RED} $G_ICO_ERROR $msg_error_no_command ${G_RESET_COLOR}" # >&2
    return 1
  fi

  # Vérifie si le répertoire de l'utilisateur existe
  if [[ ! -d "$G_USER_DIR" ]]; then
    printf "${G_TXT_RED} $G_ICO_ERROR $msg_error_no_dir ${G_RESET_COLOR}" # >&2
    return 1
  fi

  # Supprime l'ancien script temporaire s'il existe
  sudo rm -f "$G_FILE_TMP"

  # Écrit le script
  if ! printf "$custom_command" | sudo tee "$G_FILE_TMP" > /dev/null; then
    printf "${G_TXT_RED} $G_ICO_ERROR $msg_error_create_script ${G_RESET_COLOR}" # >&2
    exit 1
  fi
  if [[ ! -f "$G_FILE_TMP" ]]; then
    printf "${G_TXT_RED} $G_ICO_ERROR $msg_error_create_script ${G_RESET_COLOR}" # >&2
    return 1
  fi

  # Rend le script temporaire exécutable
  if ! sudo chmod +x "$G_FILE_TMP"; then
    printf "${G_TXT_RED} $G_ICO_ERROR $msg_error_make_executable ${G_RESET_COLOR}" # >&2
    sudo rm -f "$G_FILE_TMP"
    return 1
  fi

  # Affiche dans le terminal le début du traitement en cours
  echo_process_start "$name"

  # Exécute le script temporaire et capture le code de sortie
  sudo bash "$G_FILE_TMP"
  local exit_status=$?

  # Supprime le script temporaire après exécution
  if ! sudo rm -f "$G_FILE_TMP"; then
    echo "${G_TXT_RED}$G_ICO_ERROR $msg_warning_delete_script ${G_RESET_COLOR}" # >&2
  fi

  # Affiche dans le terminal la fin du traitement en cours
  echo_process_stop "$name"

  # Retourne le code de sortie du script temporaire
  return $exit_status
  
}

# Fonction débogage avec mode (0:sort|1:affiche|2:affiche-écris|3:écris|4:écris dans log et cmd)
# Debug function with mode (0:exit|1:display|2:display-write|3:write|4:write to log and cmd)
function debug() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_debug_title="Débogage"
    local msg_invalid_mode="Mode de débogage invalide : $G_DEBUG_MODE"
  else
    local msg_debug_title="Debug"
    local msg_invalid_mode="Invalid debug mode: $G_DEBUG_MODE"
  fi

  # Commande ou message passé en paramètre
  local cmd="$1"                          
  # Nom de la fonction appelante
  local caller_function="${FUNCNAME[1]}"  
  # Code d'erreur actuel (par défaut "INFO" si non spécifié)
  local error_code="${2:-INFO}"           

  # Si une erreur est détectée (code d'erreur différent de 0 ou "INFO")
  if [[ "$error_code" != "INFO" && "$error_code" -ne 0 ]]; then
    # Si le paramètre contient "/ cmd :", l'erreur vient de la fonction cmd_execute
    local msg_debug=""
    if [[ "$cmd" == *"/ cmd :"* ]]; then
      msg_debug="$(date '+%Y-%m-%d %H:%M:%S') / $cmd"
    else
      msg_debug="$(date '+%Y-%m-%d %H:%M:%S') / func : $caller_function / err : $error_code / cmd : $cmd"
    fi
  else
    # Si aucun code d'erreur n'est spécifié, traiter comme un message informatif
    msg_debug="$(date '+%Y-%m-%d %H:%M:%S') / func : $caller_function / msg : $cmd"
  fi

  # Gestion du mode de débogage selon $G_DEBUG_MODE
  case $G_DEBUG_MODE in
    0) return ;;  # Aucun affichage ou enregistrement
    1) echo_msgbox "$msg_debug" "$msg_debug_title" ;;
    2) echo_msgbox "$msg_debug" "$msg_debug_title"
       echo "$msg_debug" >> "$G_FILE_LOG" ;;
    3) echo "$msg_debug" >> "$G_FILE_LOG" ;;
    4) echo "$msg_debug" >> "$G_FILE_LOG"
       echo "$msg_debug" >> "$G_FILE_CMD" ;;
    *) echo "$msg_invalid_mode" >&2 ;;  # Mode invalide
  esac
  
}



##########   FONCTIONS LIEES AUX DISQUES - DISK RELATED FUNCTIONS

# Fonction pour étendre la partition
# Function to extend the partition
function disk_extend_partition() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_no="Non"
    local msg_button_yes="Oui"
    local msg_error="Erreur lors de l'extension de la partition."
    local msg_error_extend="La partition $partition n'est pas la dernière partition. Impossible de l'étendre."
    local msg_part_number_error="Erreur : Impossible de déterminer le numéro de partition."
    local msg_reboot_in="Redémarrage dans "
    local msg_reboot_required="La partition racine a été redimensionnée.\nLe système de fichiers sera étendu au prochain redémarrage.\nVoulez-vous redémarrer maintenant pour appliquer les changements ?"
    local msg_success="La partition a été redimensionnée. Le système de fichiers sera étendu après le redémarrage."
  else
    local msg_button_no="No"
    local msg_button_yes="Yes"
    local msg_error="Error expanding the partition."
    local msg_error_extend="Partition $partition is not the last partition. Cannot extend it."
    local msg_part_number_error="Error: Unable to determine the partition number."
    local msg_reboot_in="Restarting in "
    local msg_reboot_required="Root partition has been resized.\nThe filesystem will be enlarged upon the next reboot.\nDo you want to reboot now to apply the changes?"
    local msg_success="The partition has been resized. The filesystem will be extended after reboot."
  fi

  # Récupère les paramètres
  local disk=$1       # Exemple : /dev/mmcblk0
  local partition=$2  # Exemple : /dev/mmcblk0p2
  local size=$3       # Exemple : 123 (en Go)

  # Convertir la partition en numéro
  local part_number=$(echo "$partition" | grep -oP '(?<=p)\d+$')
  if [ -z "$part_number" ]; then
    echo_msgbox "$msg_part_number_error" "$G_TITLE"
    return 1
  fi

  # Vérifier si la partition est la dernière
  local last_part_num=$(parted "$disk" -ms unit s p | tail -n 1 | cut -f 1 -d:)
  if [ "$last_part_num" -ne "$part_number" ]; then
    echo_msgbox "$msg_error_extend" "$G_TITLE"
    return 1
  fi

  # Obtenir le point de départ de la partition
  local part_start=$(parted "$disk" -ms unit s p | grep "^${part_number}" | cut -f 2 -d: | sed 's/[^0-9]//g')
  if [ -z "$part_start" ]; then
    echo_msgbox "$msg_error" "$G_TITLE"
    return 1
  fi

  # Redimensionner la partition avec fdisk
  fdisk "$disk" <<EOF
p
d
$part_number
n
p
$part_number
$part_start

p
w
EOF

  # Créer un script resize2fs_once pour étendre le système de fichiers au prochain démarrage
  cat <<EOF > /etc/init.d/resize2fs_once &&
#!/bin/sh
### BEGIN INIT INFO
# Provides:          resize2fs_once
# Required-Start:
# Required-Stop:
# Default-Start: 3
# Default-Stop:
# Short-Description: Resize the root filesystem to fill partition
# Description:
### END INIT INFO

. /lib/lsb/init-functions

case "\$1" in
  start)
    log_daemon_msg "Starting resize2fs_once" &&
    resize2fs "$partition" &&
    update-rc.d resize2fs_once remove &&
    rm /etc/init.d/resize2fs_once &&
    log_end_msg \$?
    ;;
  *)
    echo "Usage: \$0 start" >&2
    exit 3
    ;;
esac
EOF

  # Rend le script resize2fs_once exécutable.
  #  Configure le script pour qu'il s'exécute automatiquement au démarrage du système.
  sudo chmod +x /etc/init.d/resize2fs_once &&
  update-rc.d resize2fs_once defaults &&

  # Demande à l'utilisateur s'il souhaite redémarrer maintenant
  if whiptail --yesno "$msg_reboot_required" 12 70 2 --fb --title "$G_TITLE" --yes-button "$msg_button_yes" --no-button "$msg_button_no"; then
    # Redémarre avec un compte à rebours
    countdown_before_reboot
  fi
  
  return 0
  
}

# Fonction pour récupérer les disques disponibles
# Function to retrieve available disks
function disk_get_availables() {

  # Définit le message d'erreur en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_error="disk_get_availables : Erreur lors de la récupération des disques disponibles."
  else
    local msg_error="disk_get_availables : Error retrieving available disks."
  fi

  # Récupère la liste des disques disponibles
  local disks
  disks=$(lsblk -d -o NAME,TYPE | grep disk | awk '{print "/dev/" $1}' | xargs echo)

  # Si une erreur survient lors de la récupération des disques
  if [ $? -ne 0 ]; then
    # Log l'erreur avec la fonction debug
    debug "$msg_error" 1
    return 1
  fi

  # Retourne la liste des disques
  echo "$disks"
  return 0

}

# Fonction pour obtenir la liste des partitions avec leur taille
# Function to get the list of partitions with their size
function disk_get_partitions() {

  # Définit le message d'erreur en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_error="disk_get_partitions : Erreur lors de la récupération des partitions disponibles."
  else
    local msg_error="disk_get_partitions : Error retrieving available partitions."
  fi

  # Paramètre en entrée : le disque à analyser
  local disk=$1

  # Récupère la liste des partitions avec leur taille
  local partitions
  partitions=$(sudo parted "$disk" unit GB print | grep '^ [0-9]' | awk '{print $1 " (" $4 ")"}')

  # Si une erreur survient lors de la récupération des partitions
  if [ $? -ne 0 ]; then
    # Log l'erreur avec la fonction debug
    debug "$msg_error" 1
    return 1
  fi

  # Retourne la liste des partitions avec leur taille
  echo "$partitions"
  return 0
  
}

# Fonction pour sélectionner le chemin d'un fichier ou d'un répertoire
# Function to select the path of a file or directory
disk_get_filepath() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" == "fr" ]; then
    if [ "$selection_type" == "R" ]; then 
      local msg_button_cancel="Sélectionner"
      local msg_button_ok="Explorer"
      local msg_current_choice="Cliquez 'Sélectionner' pour choisir le répertoire en cours suivant :"
    fi
    if [ "$selection_type" == "F" ]; then 
      local msg_button_cancel="Annuler"
      local msg_button_ok="Valider"
      local msg_current_choice="Selectionnez votre fichier dans le répertoire en cours suivant :"
    fi
    local msg_back="Retour"
    local msg_choice_directory="répertoire"
    local msg_choice_file="fichier"
  else
    if [ "$selection_type" == "R" ]; then 
      local msg_button_cancel="Select"
      local msg_button_ok="Browse"
      local msg_current_choice="Click 'Select' to choose the following current directory :"
    fi
    if [ "$selection_type" == "F" ]; then 
      local msg_button_cancel="Cancel"
      local msg_button_ok="Validate"
      local msg_current_choice="Select your file in the following current directory :"
    fi
    local msg_back="Back"
    local msg_choice_directory="directory"
    local msg_choice_file="file"
  fi

  # Récupère les paramètres
  local title="$1"
  local selection_type="$2"   # "F" pour fichiers, "R" pour répertoires
  local current_dir="${3:-/}" # Répertoire courant, par défaut la racine "/"

  # Vérifie si le répertoire passé en paramètre existe, remplace par "/" s'il n'existe pas
  if ! [ -d "$current_dir" ]; then
    current_dir="/"
  fi
  
  # Boucle principale pour naviguer dans l'arborescence
  while true; do
      
    # Ajouter une option pour revenir en arrière
    local dir_content=(".." "    $msg_back")
  
    # Parcourt les éléments du répertoire courant
    for entry in "$current_dir"/*; do
      # Si l'entrée n'existe pas, passer (cas des répertoires vides)
      [ ! -e "$entry" ] && continue

      # Ajoute les répertoires (mode fichier ou répertoire)
      [ -d "$entry" ] && dir_content+=("$(basename "$entry")" "    ($msg_choice_directory)")

      # Ajoute les fichiers uniquement si en mode fichier
      [ "$selection_type" == "F" ] && [ -f "$entry" ] && dir_content+=("$(basename "$entry")" "    ($msg_choice_file)")
    done

    # Afficher le menu avec whiptail
    selected=$(whiptail --menu "\n$msg_current_choice \n$(echo "$current_dir" | sed 's|//|/|g')" 20 75 7 "${dir_content[@]}" --fb --title "$title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)

    # Si l'utilisateur appuie sur "Cancel" sort
    if [ $? -ne 0 ]; then
      # Si en mode choix fichier 
      if [ "$selection_type" == "F" ]; then 
        # envoit message annulation
        echo "***"
      else 
        # sinon renvoit repertoire courant
        echo "$current_dir/$selected" | sed 's#//#/#g'
      fi 
      break  
    fi

    # Si la sélection est ".." remonte dans l'arborescence
    if [ "$selected" == ".." ]; then
      current_dir=$(dirname "$current_dir")
      
    # Explore le répertoire sélectionné par l'utilisateur 
    elif [ -d "$current_dir/$selected" ]; then
      current_dir="$current_dir/$selected"
      
    # L'utilisateur a sélectionné un fichier (sans double slash), renvoie le fichier et sort
    elif [ -f "$current_dir/$selected" ]; then
      echo "$current_dir/$selected" | sed 's#//#/#g'
      break  
    fi
  done
  
}

# Fonction pour récupérer la taille maximale du disque sélectionné (en Go)
# Function to retrieve the maximum size of the selected disk (in GB)
function disk_get_size() {

  # Définit le message d'erreur en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_disk_invalid="disk_get_size : Disque invalide $disk"
    local msg_disk_size_error="disk_get_size : Erreur lors de la récupération de la taille du disque $disk."
  else
    local msg_disk_invalid="disk_get_size : Invalid disk $disk"
    local msg_disk_size_error="disk_get_size : Error retrieving disk size for $disk."
  fi

  # Paramètre en entrée : le disque à analyser
  local disk=$1

  # Vérifie si le disque est un périphérique de bloc valide
  if [ ! -b "$disk" ]; then
    # Log l'erreur avec la fonction debug
    debug "$msg_disk_invalid" 1
    return 1
  fi

  # Récupère la taille du disque en Go
  local size
  size=$(sudo parted "$disk" unit GB print | grep '^Disk' | awk '{print $3}' | sed 's/GB//')

  # Si une erreur survient lors de la récupération de la taille
  if [ $? -ne 0 ] || [ -z "$size" ]; then
    # Log l'erreur avec la fonction debug
    debug "$msg_disk_size_error" 1
    return 1
  fi

  # Retourne la taille du disque en Go
  echo "$size"
  return 0

}

# Fonction pour changer la taille de la partition principale
# Function to change the size of the primary partition
function disk_resize_partition() {

  # Définir les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_busy="La partition est occupée. Êtes-vous sûr de vouloir continuer ?"
    local msg_cancel="Annulation. Aucune modification n'a été effectuée."
    local msg_confirm="Êtes-vous sûr de vouloir redimensionner la partition principale ?"
    local msg_error="Une erreur est survenue en redimensionnant la partition."
    local msg_size_prompt="Entrez la nouvelle taille (en Go) pour la partition principale :"
    local msg_success="La partition principale a été redimensionnée avec succès."
    local msg_button_yes="Ok"
    local msg_button_no="Retour"
  else
    local msg_busy="The partition is busy. Are you sure you want to continue?"
    local msg_cancel="Cancelled. No changes were made."
    local msg_confirm="Are you sure you want to resize the main partition?"
    local msg_error="An error occurred while resizing the partition."
    local msg_size_prompt="Enter the new size (in GB) for the main partition :"
    local msg_success="The main partition has been resized successfully."
    local msg_button_yes="Ok"
    local msg_button_no="Back"
  fi

  # Demander confirmation avant de redimensionner
  whiptail --yesno "$msg_confirm" 15 70 --fb --title "$G_TITLE" --yes-button "$msg_button_yes" --no-button "$msg_button_no"
  if [ $? -ne 0 ]; then
    echo_msgbox "$msg_cancel" "$G_TITLE"
    return
  fi

  # Récupère les infos de la partition principale
  local DEVICE PART_NUM DISK
  DEVICE=$(findmnt -n -o SOURCE /)
  PART_NUM=$(echo "$DEVICE" | grep -o '[0-9]*$')
  DISK=$(echo "$DEVICE" | sed 's/p[0-9]*$//')

  # Calculer la taille maximale disponible sur le disque
  local max_size
  max_size=$(sudo parted "$DISK" unit GB print free | grep 'Free Space' | tail -n 1 | awk '{print $3}' | sed 's/GB//')

  # Demander la nouvelle taille pour la partition principale
  local new_size
  new_size=$(whiptail --inputbox "$msg_size_prompt (max: $max_size Go)" 10 60 "$max_size" --fb --title "$G_TITLE" 3>&1 1>&2 2>&3)
  if [ $? -ne 0 ]; then
    echo_msgbox "$msg_cancel" "$G_TITLE"
    return
  fi

  # Vérifier si la partition est occupée
  if mount | grep -q "$DEVICE"; then
    whiptail --yesno "$msg_busy" 15 70 --fb --title "$G_TITLE" --yes-button "$msg_button_yes" --no-button "$msg_button_no"
    if [ $? -ne 0 ]; then
      echo_msgbox "$msg_cancel" "$G_TITLE"
      return
    fi
  fi

  # Démonter la partition si nécessaire
  if mount -l | grep -q "$DEVICE"; then
    if ! umount "$DEVICE"; then
      echo_msgbox "$msg_error" "$G_TITLE"
      return 1
    fi
  fi

  # Redimensionner la partition avec parted
  if ! parted --script "$DISK" resizepart "$PART_NUM" "${new_size}GB"; then
    echo_msgbox "$msg_error" "$G_TITLE"
    return 1
  fi

  # Réactiver la partition
  partprobe "$DISK"

  # Redimensionner le système de fichiers
  if ! resize2fs "$DEVICE"; then
    echo_msgbox "$msg_error" "$G_TITLE"
    return 1
  fi

  # Remonter la partition
  if ! mount "$DEVICE" /; then
    echo_msgbox "$msg_error" "$G_TITLE"
    return 1
  fi

  # Afficher un message de succès
  echo_msgbox "$msg_success"
  return 0
  
}



##########   FONCTIONS LIEES AUX MESSAGES - MESSAGES RELATED FUNCTIONS

# Fonction log l'installation 
# Function log install
function echo_logging() {
  
  # Créer le répertoire de logs si inexistant
  local LOG_DIR="${G_PROJECT_DIR}/logs"
  
  mkdir -p "${LOG_DIR}" || {
    echo "ERREUR: Impossible de créer le répertoire de logs ${LOG_DIR}" >&2
    return 1
  }

  # Nom du fichier de log avec timestamp précis
  local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  local LOG_FILE="${LOG_DIR}/install_${TIMESTAMP}.log"

  # Vérification des permissions
  if ! touch "${LOG_FILE}"; then
    echo "ERREUR: Pas de permissions en écriture pour ${LOG_FILE}" >&2
    return 1
  fi

  # Sauvegarde des descripteurs standards
  exec 3>&1 4>&2

  # Redirection complète des sorties
  exec > >(tee -a "${LOG_FILE}") 2>&1

  # En-tête du log
  echo "=============================================="
  echo "Début de l'installation - $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Répertoire du projet: ${G_PROJECT_DIR}"
  echo "Utilisateur: $(whoami)"
  echo "Hostname: $(hostname)"
  echo "=============================================="

  # Déclarer les variables comme globales pour qu'elles soient accessibles dans le trap
  declare -g G_LOG_FILE="${LOG_FILE}"
  declare -g G_LOG_DIR="${LOG_DIR}"

  # Fonction de restauration
  echo_logging_restore_outputs() {
    # Restaure les sorties standards
    exec 1>&3 2>&4
    # Affiche le message sur la sortie standard originale (écran)
    echo "Logs =>${G_LOG_FILE}"
  }

  # Configure la restauration à la sortie du script
  trap echo_logging_restore_outputs EXIT
    
  # Test d'écriture continue
  if ! echo "Test d'écriture dans le log" >> "${LOG_FILE}"; then
    echo "ERREUR CRITIQUE: Échec d'écriture dans le fichier de log" >&2
    return 1
  fi
}

# Fonction rotation des log en fixant à 10 le max de logs
# Function log rotate and fix max log to 10
function echo_logs_rotate() {
    
    local LOG_DIR="${G_PROJECT_DIR}/logs"
    local MAX_LOG_FILES=10
    
    # Supprimer les anciens fichiers de log si on dépasse le maximum
    if [ -d "$LOG_DIR" ]; then
        local file_count=$(ls -1 "$LOG_DIR" | wc -l)
        if [ "$file_count" -gt "$MAX_LOG_FILES" ]; then
            ls -t "$LOG_DIR" | tail -n +$(($MAX_LOG_FILES + 1)) | xargs -I {} rm -f "$LOG_DIR/{}"
            echo "Rotation des logs effectuée. $MAX_LOG_FILES fichiers les plus récents conservés."
        fi
    fi
    
}

# Fonction pour afficher un message dans une boîte whiptail avec dimensions automatiques
# Function to display a message in a whiptail box with automatic dimensions
function echo_msgbox() {

  # Récupère le message à afficher
  local msg="$1"

  # Gestion du titre selon G_CLEAR
  if [ "${G_CLEAR}" = "True" ]; then
    local title="${2:-$G_TITLE}"
  else
    local title="${2:-$G_TITLE ($(caller 0 | awk '{print $2}'))}"
  fi
 
  # Recupère la largeur du terminal
  local term_width=$(tput cols)
  
  # Calcul de la largeur maxi de la msgbox = largeur terminal - 6
  local max_width=$((term_width - 6))
  
  # Calcul de la largeur du message
  local msg_width=${#msg}
  
  # Calcul de la hauteur et largeur de la msgbox
  local box_width=$max_width
  local box_height=10
  
  # si le message est plus large que la msgbox, fractionne en x lignes et ajuste la hauteur de la msgbox à x lignes (+ marges)
  if [[ $msg_width -gt $max_width ]]; then
    # Calculer nombre de linges necéssaires
    local wrapped_lines=$(echo "$msg" | fold -w $max_width | wc -l)
    box_height=$((wrapped_lines + 9))
  fi
  
  # Affichage avec whiptail
  whiptail --msgbox "$msg" $box_height $box_width --title "$title" --fb
    
}

# Affiche dans le terminal le début du traitement
# Display in the terminal the start of the processing
function echo_process_start() {
  
  # Définit le message à afficher 
  local msg_tty=" => $G_ICO_LAUNCH $1  "

  # Calcul le nombre d'espaces à ajouter pour compléter la ligne à la largeur du terminal
  local current_length=$(echo_string_length "$msg_tty")
  local padding=$((G_TTY_COLS - current_length - 2))

  # Ajoute les espaces nécessaires pour atteindre 80 caractères
  msg_tty="${msg_tty}$(printf '%*s' "$padding" "")"

  # Affiche le message avec un fond coloré
  [ "$G_CLEAR" == "True" ] && clear
  printf "${G_BCK_CYAN} ${G_TXT_BLACK}"
  printf "%-*s" "$padding" "$msg_tty"
  printf "${G_RESET_COLOR}"
  printf "\n"

  # Pause de 100 ms
  sleep 0.1
	
}

# Affiche dans le terminal la fin du traitement
# Display in the terminal the end of the processing
function echo_process_stop() {

  # Définit le message à afficher
  local msg_tty=" <= $G_ICO_FLAG $1  "

  # Calcul le nombre d'espaces à ajouter pour compléter la ligne à la largeur du terminal
  local current_length=$(echo_string_length "$msg_tty")
  local padding=$((G_TTY_COLS - current_length - 2))

  # Ajoute les espaces nécessaires pour atteindre 80 caractères
  msg_tty="${msg_tty}$(printf '%*s' "$padding" "")"

  # Affiche le message avec un fond coloré
  printf "\n"
  printf "${G_BCK_YELLOW} ${G_TXT_BLACK}"
  printf ""
  printf "%-*s" "$padding" "$msg_tty"
  printf "${G_RESET_COLOR}"

  # Pause de 2000 ms
  sleep 4
  [ "$G_CLEAR" == "True" ] && clear
	
}

# Affiche dans le terminal la fin du traitement en cours avec erreur
# Display in the terminal the ongoing processing end with error
function echo_step_end_with_error() {

  # Définit le message à afficher
  local msg_tty="    $G_ICO_ERROR $1  "

  # Calcul le nombre d'espaces à ajouter pour compléter la ligne à la largeur du terminal
  local current_length=$(echo_string_length "$msg_tty")
  local padding=$((G_TTY_COLS - current_length - 2))
        
  # Ajoute les espaces nécessaires pour atteindre 80 caractères
  msg_tty="${msg_tty}$(printf '%*s' "$padding" "")"

  # Affiche un icone  erreur avec un fond coloré
  printf "  ${G_TXT_RED_BR} $G_ICO_ERROR \r"

  # Pause de 100 ms
  sleep 0.05

  # Affiche le message avec un fond coloré
  printf "${G_TXT_RED}%-*s\n" "$target_length" "$msg_tty"
  printf "${G_RESET_COLOR}"
  
}

# Affiche dans le terminal la fin du traitement en cours avec succés
# Display in the terminal the ongoing processing end with success
function echo_step_end_with_success() {

  # Définit le message à afficher
  local msg_tty="    $G_ICO_SUCCESS $1  "

  # Calcul le nombre d'espaces à ajouter pour compléter la ligne à la largeur du terminal
  local current_length=$(echo_string_length "$msg_tty")
  local padding=$((G_TTY_COLS - current_length - 2))

  # Ajoute les espaces nécessaires pour atteindre 80 caractères
  msg_tty="${msg_tty}$(printf '%*s' "$padding" "")"

  # Affiche un icone succès avec un fond coloré
  printf "  ${G_TXT_GREEN_BR} $G_ICO_SUCCESS \r"

  # Pause de 100 ms
  sleep 0.05

  # Affiche le message avec un fond coloré
  printf "${G_TXT_GREEN}%-*s\n" "$target_length" "$msg_tty"
  printf "${G_RESET_COLOR}"
  
}

# Affiche dans le terminal une info sur l'étape en cours
# Displays information about the current step in the terminal 
function echo_step_info() {

  # Définit le message à afficher
  local msg_tty="    $G_ICO_INFO $1  "

  # Calcul le nombre d'espaces à ajouter pour compléter la ligne à la largeur du terminal caractères
  local current_length=$(echo_string_length "$msg_tty")
  local padding=$((G_TTY_COLS - current_length - 2))

  # Ajoute les espaces nécessaires pour atteindre 80 caractères
  msg_tty="${msg_tty}$(printf '%*s' "$padding" "")"

  # Affiche un icone sablier avec un fond coloré
  printf "  ${G_TXT_YELLOW_BR} $G_ICO_INFO \r"
  
  # Pause de 100 ms
  sleep 0.05

  # Affiche le message avec un fond coloré
  printf "${G_TXT_YELLOW} %-*s \n" "$padding" "$msg_tty"
  printf "${G_RESET_COLOR}"
    
}

# Affiche dans le terminal le début du traitement en cours
# Display in the terminal the ongoing processing start  
function echo_step_start() {
  
  # Définit le message à afficher
  local msg_tty="    $G_ICO_HOURGLASS $1  "

  # Calcul le nombre d'espaces à ajouter pour compléter la ligne à la largeur du terminal caractères
  local current_length=$(echo_string_length "$msg_tty")
  local padding=$((G_TTY_COLS - current_length - 2))

  # Ajoute les espaces nécessaires pour atteindre 80 caractères
  msg_tty="${msg_tty}$(printf '%*s' "$padding" "")"

  # Affiche un icone sablier avec un fond coloré
  printf "  ${G_TXT_RED_BR} $G_ICO_HOURGLASS️ \r"
  
  # Pause de 100 ms
  sleep 0.05

  # Affiche le message avec un fond coloré
  printf "${G_TXT_RED} %-*s \r" "$padding" "$msg_tty"
  printf "${G_RESET_COLOR}"

  # Pause de 100 ms
  sleep 0.05
	
}

# # Affiche dans le terminal la fin du traitement en cours
# # Display in the terminal the ongoing processing end
function echo_step_stop() {

  # Définit le message à afficher
  local msg_tty="    $G_ICO_SUCCESS $1  "

  # Calcul le nombre d'espaces à ajouter pour compléter la ligne à la largeur du terminal
  local current_length=$(echo_string_length "$msg_tty")
  local padding=$((G_TTY_COLS - current_length - 2))

  # Ajoute les espaces nécessaires pour atteindre 80 caractères
  msg_tty="${msg_tty}$(printf '%*s' "$padding" "")"

  # Affiche un icone succès avec un fond coloré
  printf "  ${G_TXT_GREEN_BR} $G_ICO_SUCCESS \r"

  # Pause de 100 ms
  sleep 0.05

  # Affiche le message avec un fond coloré
  printf "${G_TXT_GREEN}%-*s \n" "$target_length" "$msg_tty" 
  printf "${G_RESET_COLOR}"

  # Pause de 100 ms
  sleep 0.05
  
}

# Fonction pour calculer la longueur réelle d'une chaîne (sans les caractères de contrôle ANSI)
function echo_string_length() {

  # Récupère le paramètre
  local msg_str="$1"
  
  # Supprime les séquences ANSI (couleurs) avant de calculer la longueur
  msg_str=$(echo -n "$msg_str" | sed 's/\x1b\[[0-9;]*m//g')
  
  # Renvoit la taille du paramètre
  echo -n "$msg_str" | wc -m
  
}


##########   FONCTIONS LIEES AUX PACKAGES 

# Fonction : Vérifie si une commande liée à un package (comme docker avec docker-ce) est disponible dans le PATH
# Function to Check Package (as docker with docker-ce) Command Availability in PATH
function is_command_available() {

  local cmd="$1"
  command -v -- "$cmd" >/dev/null 2>&1 || {
    # Commande non trouvée
    return 1
  }
  return 0

}

# Fonction : Vérifie si un paquet est installé via dpkg/apt
# Function : Checks if a package is installed via dpkg/apt
function is_package_installed() {

  local pkg="$1"
  sudo dpkg-query -W -f='${db:Status-Status}' "$pkg" 2>/dev/null | grep -q '^installed$' || {
    # Paquet non installé
    return 1
  }
  return 0

}

# Fonction : Vérifie si un service est actif (running)
# Function : Checks if a service is active (running)
function is_service_active() {

  local service="$1"
  if sudo systemctl is-active --quiet "$service" 2>/dev/null; then
    return 0
  elif sudo service "$service" status 2>/dev/null | grep -q 'is running'; then
    return 0
  fi
  # Service inactif
  return 1
  
}

# Fonction : Vérifie si un service est activé au démarrage
# Function : Checks if a service is enabled at boot
function is_service_enabled() {

  local service="$1"
  sudo systemctl is-enabled "$service" 2>/dev/null | grep -qE '^(enabled|static|indirect)$' || {
    # Service non activé
    return 1  
  }
  return 0
  
}



##########   FONCTIONS LIEES AUX CONTAINERS

# Fonction : Vérifie si un container est installé
# Function : Checks if a container installed
function container_is_installed() {
  
  local container="$1"
  sudo docker container inspect "$container_name" >/dev/null 2>&1 || {
    # Container inexistant
    return 1
  }
  
  #sudo docker ps -a --filter "name=^/${container}$" --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$" || {
  #  # Container inexistant
  #  return 1
  #}
  
}

# Fonction : Vérifie l'état santé d'un container (si healthcheck configuré)
# Function : Checks container health status (if healthcheck configured)
function container_is_healthy() {
  
  local container="$1"
  local timeout=${2:-10}  # Default 10s timeout

  health_status=$(sudo docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
  case "$health_status" in
    healthy)    return 0 ;;
    unhealthy)  return 1 ;;
    *) # No health check or starting
     # Wait for health status if container is running
     if container_is_running "$container"; then
       for ((i=0; i<timeout; i++)); do
         sleep 1
         health_status=$(sudo docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
         [ "$health_status" = "healthy" ] && return 0
       done
     fi
     return 1 ;;
  esac
}

# Fonction : Vérifie si un container est en cours d'exécution
# Function : Checks if a container is running
function container_is_running() {
  
  local container="$1"
  sudo docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null | grep -q 'true' || {
    # le container est en cours d'exécution
    return 1
  }
  return 0
  
}

# Fonction : Vérifie si un container est stoppé
# Function : Checks if a container is stopped
function container_is_stopped() {

  local container="$1"
  
  sudo docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null | grep -q 'false' && {
    # Le conteneur est stoppé
    return 1
  }
  return 0

}

# Fonction : Supprime un container
# Function : Force removes a container
function container_remove() {

  local container="$1"
  
  # Supprime le container
  if sudo docker rm -f "$container" &>/dev/null; then
    return 0  # Suppression réussie
  fi

  # Capture le statut de sortie de Docker
  local exit_status=$?
  case $exit_status in
    1) # Code 1 : Conteneur non trouvé -> Considéré comme supprimé 
      return 0 
      ;;
    *) # Tout autre code -> Erreur critique
      return 1
      ;;
  esac

}

# Fonction : Stoppe un container avec sudo
# Function : Stops a container with sudo
function container_stop() {

  local container="$1"

  # Tente d'arrêter le container
  if sudo docker stop "$container" &>/dev/null; then
    return 0  # Arrêt réussi
  fi

  # Capture le statut de sortie de Docker
  local exit_status=$?
  case $exit_status in
    1)  # Docker retourne 1 si le conteneur n'existe pas ou est déjà arrêté
      return 0
      ;;
    *)  # Tout autre code = échec
      return 1
      ;;
  esac
}

# Fonction : Démarre un container avec sudo
# Function : Starts a container with sudo
function container_start() {

  local container="$1"

  # Tente de démarrer le container
  if sudo docker start "$container" &>/dev/null; then
    return 0  # Démarrage réussi
  fi
  return 1

}

# Fonction : Récupère l'état complet d'un container
# Function : Gets complete container state
function container_get_state() {
  
  local container="$1"
  local state
  
  # Sortie : running|exited|paused|restarting|removing|dead|unknown
  state=$(sudo docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
  echo "$state" | tr -d '\r\n'  # Nettoyage supplémentaire
 
}

# Fonction : Vérifie si un container a terminé avec succès (avec exit 0)
# Function : Checks if container exited successfully (exit 0)
function container_get_exited_cleanly() {

  local container="$1"
  local exit_code

  exit_code=$(sudo docker inspect -f '{{.State.ExitCode}}' "$container" 2>/dev/null)
  [ "$exit_code" = "0" ] 2>/dev/null && return 0
  return 1

}



##########   MENU PRINCIPAL

# Fonction pour le menu principal 
# Function for main menu
function menu_0_main_menu() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Quitter"
    local msg_button_no="Non"
    local msg_button_ok="Sélectionner"
    local msg_button_yes="Oui"
    local msg_ask_action="Choisissez l'action à effectuer :"
    local msg_confirm_quit="Voulez-vous vraiment quitter le script d'installation ?"
    local msg_invalid_choice="Choix invalide. Veuillez réessayer."
    local msg_options=(
      "1" "Gestion des Containers"
      "2" "Gestion des Packages"
      "3" "Gestion des Packages Npm"
      "4" "Gestion des Outils Système"
      "5" "Gestion des Pilotes"
      "6" "Divers"
      "7" "Inventaire"
      "8" "Langage"
    )
    local msg_title="$G_TITLE - Menu Principal"
    local msg_unexpected_error="Une erreur inattendue s'est produite. Le script va quitter."
  else
    local msg_button_cancel="Quit"
    local msg_button_no="No"
    local msg_button_ok="Select"
    local msg_button_yes="Yes"
    local msg_ask_action="Choose the action to perform :"
    local msg_confirm_quit="Do you really want to quit the installation script ?"
    local msg_invalid_choice="Invalid choice. Please try again."
    local msg_options=(
      "1" "Container Management"
      "2" "Package Management"
      "3" "Npm Package Management"
      "4" "System Tool Management"
      "5" "Driver Management"
      "6" "Miscellaneous"
      "7" "Inventory"
      "8" "Language"
    )
    local msg_title="$G_TITLE - Main Menu"
    local msg_unexpected_error="An unexpected error occurred. The script will exit."
  fi

  while true; do
  
    # Afficher la boîte de dialogue et récupérer le choix de l'utilisateur
    local choice_menu
    choice_menu=$(whiptail --menu "\n$msg_ask_action" 20 75 8 "${msg_options[@]}" --fb --title "$msg_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
    # Récupérer le statut de sortie de whiptail
    local exit_status=$?
    
    # L'utilisateur a cliqué sur "Quitter"
    if [ $exit_status -eq 1 ]; then
      if (whiptail --yesno " $msg_confirm_quit" 15 70 --fb --title "$msg_title" --yes-button "$msg_button_yes" --no-button "$msg_button_no"); then
        # Quitter le script
        exit 0
      fi
    
    # L'utilisateur a cliqué sur "Sélectionner"
    elif [ $exit_status -eq 0 ]; then
      case $choice_menu in
        1) menu_1_containers ;;
        2) menu_2_packages ;;
        3) menu_3_packages_npm ;;
        4) menu_4_system_tools ;;
        5) menu_5_drivers ;;
        6) menu_6_misc ;;
        7) menu_7_inventory ;;
        8) menu_8_language ;;
        *) echo_msgbox "$msg_invalid_choice" "$msg_title" ;;
      esac
    
    # Gestion des erreurs inattendues
    else
      echo_msgbox "$msg_unexpected_error" "$msg_title"
      exit 1
    fi
  
  done

}

# Fonction pour afficher le menu de choix (container/package/pilote/outil systeme) 
# Function to display the choice menu (container/package/driver/system tool)
function menu_0_main_menu_action() {

  # Récuoère les paramètres 
  local msg_action_type=$1
  local msg_action_name=$2

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_ok="Suivant"
    local msg_ask_action="\nQue voulez-vous faire ?"
    local msg_options=(
      "1" " Installer un $msg_action_type $msg_action_name"
      "2" " Désinstaller un $msg_action_type $msg_action_name"
    )
    local msg_title="$G_TITLE - Installer / Désinstaller"
    ### Cherche le résumé dans les tableaux correspondant à l'action à faire
    # Copier G_DOCKER_RESUME_FR dans G_DOCKER_RESUME
    for key in "${!G_DOCKER_RESUME_FR[@]}"; do
      G_DOCKER_RESUME["$key"]="${G_DOCKER_RESUME_FR[$key]}"
    done
    # Copier G_PACKAGE_RESUME_FR dans G_PACKAGE_RESUME
    for key in "${!G_PACKAGE_RESUME_FR[@]}"; do
      G_PACKAGE_RESUME["$key"]="${G_PACKAGE_RESUME_FR[$key]}"
    done
    # Copier G_PACKAGE_RESUME_FR dans G_PACKAGE_NPM_RESUME
    for key in "${!G_PACKAGE_NPM_RESUME_FR[@]}"; do
      G_PACKAGE_NPM_RESUME["$key"]="${G_PACKAGE_NPM_RESUME_FR[$key]}"
    done
    # Copier G_SYSTEM_TOOL_RESUME_EN dans G_SYSTEM_TOOL_RESUME
    for key in "${!G_SYSTEM_TOOL_RESUME_FR[@]}"; do
      G_SYSTEM_TOOL_RESUME["$key"]="${G_SYSTEM_TOOL_RESUME_FR[$key]}"
    done
    # Copier G_DRIVERS_RESUME_FR dans G_DRIVERS_RESUME
    for key in "${!G_DRIVER_RESUME_FR[@]}"; do
      G_DRIVER_RESUME["$key"]="${G_DRIVER_RESUME_FR[$key]}"
    done
  else
    local msg_button_cancel="Back"
    local msg_button_ok="Next"
    local msg_ask_action="\nWhat do you want to do ?"
    local msg_options=(
      "1" "Install a $msg_action_type $msg_action_name"
      "2" "Uninstall a $msg_action_type $msg_action_name"
    )
    local msg_title="$G_TITLE - Install / Uninstall"
    ### Cherche le résumé dans les tableaux correspondant à l'action à faire
    # Copier G_DOCKER_RESUME_EN dans G_DOCKER_RESUME
    for key in "${!G_DOCKER_RESUME_EN[@]}"; do
      G_DOCKER_RESUME["$key"]="${G_DOCKER_RESUME_EN[$key]}"
    done
    # Copier G_PACKAGE_RESUME_EN dans G_PACKAGE_RESUME
    for key in "${!G_PACKAGE_RESUME_EN[@]}"; do
      G_PACKAGE_RESUME["$key"]="${G_PACKAGE_RESUME_EN[$key]}"
    done
    # Copier G_PACKAGE_RESUME_EN dans G_PACKAGE_NPM_RESUME
    for key in "${!G_PACKAGE_NPM_RESUME_EN[@]}"; do
      G_PACKAGE_NPM_RESUME["$key"]="${G_PACKAGE_NPM_RESUME_EN[$key]}"
    done
    # Copier G_SYSTEM_TOOL_RESUME_EN dans G_SYSTEM_TOOL_RESUME
    for key in "${!G_SYSTEM_TOOL_RESUME_EN[@]}"; do
      G_SYSTEM_TOOLS_RESUME["$key"]="${G_SYSTEM_TOOL_RESUME_EN[$key]}"
    done
    # Copier G_DRIVERS_RESUME_EN dans G_DRIVERS_RESUME
    for key in "${!G_DRIVER_RESUME_EN[@]}"; do
      G_DRIVER_RESUME["$key"]="${G_DRIVER_RESUME_EN[$key]}"
    done
  fi

  # Ajouter le résumé correspondant si la fonction appelante est 
  local msg_resume
  case "${FUNCNAME[1]}" in
    menu_1_containers_1_install_uninstall)
      local msg_resume="${G_DOCKER_RESUME[$msg_action_name]}"
      ;;
    menu_2_packages_1_install_uninstall)
      local msg_resume="${G_PACKAGE_RESUME[$msg_action_name]}"
      ;;
    menu_3_packages_npm_1_install_uninstall)
      local msg_resume="${G_PACKAGE_NPM_RESUME[$msg_action_name]}"
      ;;
    menu_4_system_tools_*)
      local msg_resume="${G_SYSTEM_TOOL_RESUME[$msg_action_name]}"
      ;;
    menu_5_drivers_*)
      local msg_resume="${G_DRIVER_RESUME[$msg_action_name]}"
      ;;
  esac
  
  # Formate le résumé
  if [ -n "$msg_resume" ]; then
	   # Retour à la ligne tous les 70 caractères
    msg_resume=$(echo "$msg_resume" | fold -s -w 70)
    msg_ask_action="$msg_ask_action \n\n$msg_resume\n\n"
  fi
  
  # Afficher la boîte de dialogue
  local choice_menu
  choice_menu=$(whiptail --menu "$msg_ask_action" 20 75 2 "${msg_options[@]}" --fb --title "$msg_title" --notags --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)

  # Récupérer le statut de sortie
  local exit_status=$?

	 # Clic sur "Valider"
  if [ $exit_status -eq 0 ]; then 
    case $choice_menu in
      1) G_CHOICE="I" ;;
      2) G_CHOICE="D" ;;
    esac
  fi

  # Clic sur "Annuler"
  if [ $exit_status -eq 1 ]; then 
    G_CHOICE="A"
    return 0
  fi
  
}



##########   MENU CONTAINERS

# Fonction pour le menu des containers
# Function for the containers menu
function menu_1_containers() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_ask_install_docker="Voulez-vous aller directement au menu pour installer Docker ?"
    local msg_button_cancel="Retour"
    local msg_button_no="Non"
    local msg_button_ok="Suivant"
    local msg_button_yes="Oui"
    local msg_docker_not_installed="Docker n'est pas installé.\nVeuillez installer Docker avant de continuer."
    local msg_docker_not_started="Le service Docker n'est pas démarré. Démarrage en cours..."
    local msg_docker_started_success="Docker a été démarré avec succès."
    local msg_docker_started_error="Échec du démarrage de Docker."
    local msg_error="Une erreur s'est produite."
    local msg_error_inspect="Erreur lors de l'inspection du conteneur $container_name : $exposed_port"
    local msg_free_on="libre sur"
    local msg_install_uninstall="\nSélectionnez les containers à installer ou désinstaller :\nS:Statut P:Port C:Taille container I:Taille image"
    local msg_list_container_check="Traitement du container :"
    local msg_list_container_processing="Analyse des containers..."
    local msg_no_selection="Aucun container sélectionné.\nVeuillez sélectionner au moins un container."
    local msg_status_installed="Installé"
    local msg_status_not_installed="Non installé"
    local msg_status_started="Démarré"
    local msg_title="$G_TITLE - Gestion des Containers"
    local msg_watchtower="Quels containers voulez-vous surveiller ?"
  else
    local msg_ask_install_docker="Would you like to go directly to the menu to install Docker ?"
    local msg_button_cancel="Back"
    local msg_button_no="No"
    local msg_button_ok="Next"
    local msg_button_yes="Yes"
    local msg_docker_not_installed="Docker is not installed.\nPlease install Docker before proceeding."
    local msg_docker_not_started="The Docker service is not started. Starting now..."
    local msg_docker_started_success="Docker has been started successfully."  
    local msg_docker_started_error="Failed to start Docker."
    local msg_error="Error occured"
    local msg_error_inspect="Error while inspecting the container $container_name : $exposed_port"
    local msg_free_on="free on"
    local msg_install_uninstall="\nSelect containers to install or uninstall :\nS:Status P:Port C: Container tail I: Image tail"
    local msg_list_container_check="Processing container : "
    local msg_list_container_processing="Analyzing containers..."
    local msg_no_selection="No container selected.\nPlease select at least one container."
    local msg_status_installed="Installed"
    local msg_status_not_installed="Not installed"
    local msg_status_started="Started"
    local msg_title="$G_TITLE - Container Management"
    local msg_watchtower="Which containers do you want to monitor?"
  fi
  
  # Vérifie si Docker est installé
  if ! command -v docker &> /dev/null; then

    # Docker est pas installé, demande pour installer Docker avec whiptail
    whiptail --yesno "$msg_docker_not_installed\n$msg_ask_install_docker" 12 70 --fb --title "$G_TITLE" --yes-button "$msg_button_yes" --no-button "$msg_button_no"
    
    # Si clic "Non" sort car l'utilisateur veut pas installer Docker 
    if [ $? -eq 1 ]; then
      return 1
    fi

    # Si clic sur "Oui" Appelle le menu pour installer Docker 
    if [ $? -eq 0 ]; then
    
      # Appelle le menu pour installer Docker 
      menu_4_system_tools
      
      #Sort si l'utilisateur a annulé l'installation
      if ! command -v docker &> /dev/null; then
        return 1
      fi
      
      # Vérifie si Docker est installé et fonctionnel
      if ! systemctl is-active --quiet docker; then
        echo_process_start "Docker"
        echo_step_info "$msg_docker_not_started"
        if sudo systemctl start docker; then
          echo_step_end_with_success "$msg_docker_started_success"
        else
          echo_step_end_with_error "$msg_docker_started_error"
          return 1
        fi
        echo_process_stop "Docker"
      fi
      
    fi 
    
  fi
  
  # Affiche dans le terminal le début du traitement
  echo_process_start "$msg_list_container_processing"
  
  # Crée la liste des conteneurs à installer par ordre alphabétique
  local max_length=59
  local options=()
  local installed_containers=()

  # Trie les containers par ordre alphabétique en fonction des noms de containers
  local sorted_list=($(echo "${!G_DOCKER_CMD_INS[@]}" | tr ' ' '\n' | sort))

  for list_name in "${sorted_list[@]}"; do
    
    local container_name="${G_DOCKER_NAME[$list_name]}"
    local container_command="${G_DOCKER_CMD_INS[$list_name]}"

    # Affiche dans le terminal le début de l'étape en cours
    echo_step_start "$msg_list_container_check $list_name"

    # extrait le numéro de port du container de la commande d'installation du container, si hors plage,invalide ou vide alors =""  
    local container_port=$(echo "$container_command" | grep -oP '\s-p\s+\K[0-9]+(:[0-9]+)?' | head -n 1 | awk -F: '$NF ~ /^[0-9]+$/ && $NF <= 65535 && $NF > 0 {print $NF; exit 0} END {exit 1}') || container_port=""

    local info="$list_name${container_port:+ ($container_port)}"
  
    # Si le container est installé
  #  if ! container_is_installed "$container_name"; then
    if sudo docker container inspect "$container_name" >/dev/null 2>&1; then

      # Récupère le port réel du container si celui-ci a été modifié pendant l'installation, si hors plage,invalide ou vide alors = port de la commande   
      local exposed_port=$(sudo docker inspect --format '{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{(index $conf 0).HostPort}}{{break}}{{end}}{{end}}' "$container_name" 2>/dev/null) || exposed_port="${container_port:-}"

      # Récupère la taille de l'image
      image_id=$(sudo docker inspect --format '{{.Image}}' "$container_name" 2>/dev/null || echo "")
      if [[ -n "$image_id" ]]; then
          image_size_bytes=$(sudo docker image inspect --format '{{.Size}}' "$image_id" 2>/dev/null || echo "0")
          image_size=$(echo "$image_size_bytes" | numfmt --to=iec --suffix=B --format="%.0f" 2>/dev/null || echo "0B")
      else
          image_size="N/A"
      fi

      # Récupère la taille du container seul avec gestion spécifique de <nil>
      container_size_bytes=$(sudo du -sh $(sudo docker inspect --format='{{.GraphDriver.Data.UpperDir}}' "$container_name") | awk '{print $1}')  
      
      # Récupération de la taille formatée
      if [[ "$container_size_bytes" == "<nil>" ]] || [[ -z "$container_size_bytes" ]]; then
        container_size="0B"
        container_bytes="0"
      else
      
        # Récupération de la taille du container formatée
        container_size_raw=$(sudo du -sh $(sudo docker inspect --format='{{.GraphDriver.Data.UpperDir}}' "$container_name" 2>/dev/null) 2>/dev/null | awk '{print $1}')

        # Ajoute les unités
        if [[ -z "$container_size_raw" ]]; then
          container_size="0B"
        else
          case $container_size_raw in
            *K) container_size="${container_size_raw%K}KB" ;;
            *M) container_size="${container_size_raw%M}MB" ;;
            *G) container_size="${container_size_raw%G}GB" ;;
            *) container_size="${container_size_raw}B" ;;
          esac
        fi

      fi

      # Récupère le statut "démarré" ou "installé
      if sudo docker ps --filter "name=$container_name" | grep -q "$container_name"; then 
        local status="S:$msg_status_started P:$exposed_port C:$container_size I:$image_size"
      else         
        local status="S:$msg_status_installed P:$exposed_port C:$container_size I:$image_size"
      fi
  
    # Si le container est pas installé
    else
      local status="S:$msg_status_not_installed"
    fi
    
    # Calcule la longueur totale de la ligne (info + statut)
    local info_length=$(( ${#info} + ${#status} ))
		  # Calcule le nombre de caractères "." à mettre entre info et statut
    local dots_length=$((max_length - info_length))
        if [ $dots_length -lt 0 ]; then
      dots_length=0
    fi
    local dots=$(printf "%${dots_length}s" "" | tr ' ' '.')
    
    # Ajoute la ligne au tableau 
    options+=("$list_name" "$info $dots $status " OFF)

    # Affiche dans le terminal la fin de l'étape en cours
    echo_step_stop "$msg_list_container_check $list_name"
  
  done
  
  # Affiche dans le terminal la fin du traitement
  echo_process_stop "$msg_button_cancel $G_TITLE"
  
  # Récupère l'espace libre sur la partition principale
  free_space=$(sudo df -h "$(pwd)" | awk -v msg_free_on="$msg_free_on" 'NR==2 {printf "%s %s %s", $4, msg_free_on, $1}')

  # Calculer la hauteur dynamique de la liste et limite à 9
  local num_items=${#sorted_list[@]}
  if (( num_items > 7 )); then
    num_items=7
  fi
  # Hauteur de base + nombre d'éléments
  local menu_height=$((12 + num_items))
  # Limiter la hauteur maximale pour éviter des problèmes d'affichage
  if [ $menu_height -gt 22 ]; then
    menu_height=22
  fi

  # Afficher la boîte de dialogue
  local selected_containers
  selected_containers=$(whiptail --checklist "$msg_install_uninstall\n$free_space" $menu_height 75 $num_items "${options[@]}" --fb --title "$msg_title" --cancel-button "$msg_button_cancel" --ok-button "$msg_button_ok" --notags 3>&1 1>&2 2>&3)
  # Récupère le statut de sortie de whiptail
  local exit_status=$?
  
  # clic "Retour"
  if [ $exit_status -eq 1 ]; then 
    return 0
  
  # clic "Suivant"
  elif [ $exit_status -eq 0 ]; then
    
    # Si pas de choix coché
    if [ -z "$selected_containers" ]; then
      echo_msgbox "$msg_no_selection" "$msg_title"
    # Au moins un choix coché, récupère la liste des éléments cochés
    else

      # Initialise la variable install_watchtower à false
      local install_watchtower=false 
      local install_node_red=false 

      # Installe ou désinstalle les éléments sélectionnés
      selected_containers=($(echo "$selected_containers" | tr -d '"'))
      for container in "${selected_containers[@]}"; do
      
				# Si le container à installer est Watchtower, passe au suivant
				if [ "$container" = "Watchtower" ]; then
					install_watchtower=true
				else
				
					# Si le container à installer est Node-Red, passe au suivant
					if [ "$container" = "Node-Red" ]; then
						install_node_red=true
					fi

					# Appelle le menu d'installation/désinstallation du container
					menu_1_containers_1_install_uninstall "$container" "${G_DOCKER_CMD_INS[$container]}"

				fi

      done
      
      # Si le container watchtower est installé
      if [ "$install_watchtower" = true ]; then
              
        # Obtenir la liste des noms de containers et les stocker dans un tableau
        local installed_containers=()
        local installed_containers_filtered=()
        sudo mapfile -t installed_containers < <(docker ps -a --format '{{.Names}}')

        # Exclure "Watchtower" de la liste des containers installés
        for list_name in "${installed_containers[@]}"; do
          if [ "$list_name" != "watchtower" ]; then
            installed_containers_filtered+=("$list_name" "$list_name" OFF)
          fi
        done      

        # Recalcule le nombre de conteneurs installés divisé par 3
        local num_installed=${#installed_containers_filtered[@]}
        local watchtower_num_items=$(( num_installed / 3 ))

        # Calculer la hauteur dynamique pour la boîte de dialogue Watchtower
        local watchtower_menu_height=$(( watchtower_num_items + 9 ))  # Calcul de la hauteur du menu
        # Limiter la hauteur du menu entre 1 et 20
        if [ "$watchtower_menu_height" -gt 20 ]; then
          watchtower_menu_height=20
        elif [ "$watchtower_menu_height" -lt 1 ]; then
          watchtower_menu_height=1
        fi

        # Vérifier que la liste filtrée n'est pas vide
        if [ ${#installed_containers_filtered[@]} -eq 0 ]; then
          echo_msgbox "$msg_no_selection. (Except: Watchtower)" "$msg_title"
          return 1
        fi
  
        # Afficher la boîte de dialogue Whiptail avec la liste des containers installés
        local watchtower_containers
        watchtower_containers=$(whiptail --checklist "\n$msg_watchtower" $watchtower_menu_height 75 $watchtower_num_items "${installed_containers_filtered[@]}" --fb --title "$msg_title" --cancel-button "$msg_button_cancel" --ok-button "$msg_button_ok" --notags 3>&1 1>&2 2>&3)
        # Recupére le statut de whiptail 
        local watchtower_exit_status=$?
        
        # Si clic sur Suivant" modifie la liste des containers à surveiller
        if [ $watchtower_exit_status -eq 0 ]; then
          local watchtower_config=" --schedule '0 6 * * *'"
          watchtower_containers=($(echo "$watchtower_containers" | tr -d '"'))
          for watchtower_container in "${watchtower_containers[@]}"; do
            watchtower_config+=" --scope $watchtower_container"
          done
          # Lance le menu d'installation du container Watchtower pour modifier les paramètres 
          menu_1_containers_1_install_uninstall "Watchtower" "${G_DOCKER_CMD_INS["Watchtower"]}"
        fi
      fi
    
      # Si le container node-red est installé, demande si il faut installer les packages npm node-red
      if [ "$install_node-red" = true ]; then
        menu_1_containers_3_node_red
      fi
      
    fi
  else
    echo_msgbox "$msg_error" "$msg_title"
  fi
  
}

# Fonction pour installer ou désinstaller un container
# Function to install or uninstall a container
function menu_1_containers_1_install_uninstall() {
  
  # Récupère les paramètres
  local container_name=$1
  local container_default_command=$2
  
  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_no="Non"
    local msg_button_ok="Suivant"
    local msg_button_yes="Oui"
    local msg_ask_new_port="Le port est déjà utilisé, indiquez un autre port que "
    local msg_container_running="Le conteneur est en cours d'exécution."
    local msg_container_paused="Le conteneur est en pause."
    local msg_container_exited="Le conteneur est arrêté."
    local msg_container_unknown="Etat du container inconnu: $container_status"
    local msg_custom_command_prompt="Voulez-vous modifier les paramètres de création du conteneur $container_name ?\n(Si vide, utilisation des paramètres par défaut)"
    local msg_invalid_name="$container_name n'est pas installé. Installation en cours..."
    local msg_installation_canceled="Installation annulée."
    local msg_install_error="Erreur lors de l'installation de $container_name."
    local msg_install_success="$container_name a été installé avec succès."
    local msg_not_installed_cancel="$container_name n'est pas installé, désinstallation annulée."
    local msg_not_running_prompt="Le conteneur $container_name existe mais n'est pas démarré. \nSouhaitez-vous le démarrer ?"
    local msg_remove="Suppression du container $container_name"
    local msg_remove_image="Suppression de l'image $container_image_name"
    local msg_remove_image_failure="Erreur lors de la suppression de l'image $container_image_name du conteneur $container_name."
    local msg_remove_image_success="L'image du conteneur $container_image_name a été supprimée avec succès."
    local msg_start_failure="Le conteneur $container_name n'a pas été démarré."
    local msg_start_prompt="Voulez-vous démarrer le conteneur $container_name maintenant ?"
    local msg_start_success="Le conteneur $container_name a été démarré avec succès."
    local msg_stop="Arrêt du container $container_name..."
    local msg_stop_and_uninstall="Arrêter et supprimer le container."
    local msg_stop_and_uninstall_and_remove_img="Arrêter et supprimer le container et l'image "
    local msg_stop_error="Erreur lors de l'arrêt du conteneur $container_name"
    local msg_stop_only="Arrêter seulement"
    local msg_stop_prompt="Que voulez-vous faire pour le container $container_name ?"
    local msg_stop_success="Le conteneur $container_name a été arrêté avec succès."
    local msg_uninstall="$container_name a été désinstallé avec succès."
    local msg_uninstall_success="$container_name a été désinstallé avec succès."
    local msg_yet_installed="$container_name est déjà installé."
  else
    local msg_button_cancel="Back"
    local msg_button_no="No"
    local msg_button_ok="Next"
    local msg_button_yes="Yes"
    local msg_ask_new_port="The port is already in use, please specify a other port than "
    local msg_container_running="The container is running."
    local msg_container_paused="The container is paused."
    local msg_container_exited="The container is stopped."
    local msg_container_unknown="Unknown container state: $container_status"
    local msg_custom_command_prompt="Do you want to modify the creation parameters of the container $container_name?\n(If blank, use the default parameters)"
    local msg_invalid_name="$container_name is not installed. Installing now..."
    local msg_installation_canceled="Installation canceled."
    local msg_install_error="Error installing $container_name."
    local msg_install_success="$container_name has been installed successfully."
    local msg_not_installed_cancel="$container_name is not installed, uninstall canceled."
    local msg_not_running_prompt="The container $container_name exists but is not running. \nDo you want to start it ?"
    local msg_remove="Removing the container $container_name..."
    local msg_remove_image="Removing the image $container_image_name"
    local msg_remove_image_failure="Error while deleting the image of the container $container_name."
    local msg_remove_image_success="The image of the container $container_image_name has been successfully deleted."
    local msg_start_failure="The container $container_name has not been started."
    local msg_start_prompt="Do you want to start the container $container_name now?"
    local msg_start_success="The container $container_name has been started successfully."
    local msg_stop="Stopping the container $container_name..."
    local msg_stop_and_uninstall="Stop and remove the container"
    local msg_stop_and_uninstall_and_remove_img="Stop and remove the container and the image "
    local msg_stop_error="Error stopping the container $container_name."
    local msg_stop_only="Stop only"
    local msg_stop_prompt="What do you want to do with the container $container_name ?"
    local msg_stop_success="The container $container_name has been stopped successfully."
    local msg_uninstall_success="$container_name has been uninstalled successfully."
    local msg_yet_installed="$container_name is already installed."
  fi

  # Appel de la fonction pour afficher le menu d'action pour les containers
  menu_0_main_menu_action "container" "$container_name"

  # Sort si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" == "A" ]; then
    return 0
  fi
  
  # Extrait le nom du container dans la commande, sort si non defini
  local container_name_cmd=$(echo "$container_default_command" | tr ' ' '\n' | grep -A1 -e '--name' | tail -n1 | sed 's/^--name=//')

  if [ -z "$container_name_cmd" ]; then
    echo_msgbox "$msg_invalid_name"
    return 1
  fi

  # Si l'utilisateur a choisi d'installer
  if [ "$G_CHOICE" == "I" ]; then

    # Teste si le conteneur existe, qu'il soit en cours d'exécution ou non
    if ! container_is_installed "$container_name"; then
 
      # Afficher la boîte de dialogue pour personnaliser la commande
      local custom_command
      custom_command=$(whiptail --inputbox "\n$msg_custom_command_prompt" 20 70 "$container_default_command" --fb --title "$G_TITLE" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
      local exit_status=$?
      
      # Clic "Retour"
      if [ $exit_status -eq 1 ]; then
        return 1
      fi

      # Clic "Suivant"
      if [ $exit_status -eq 0 ]; then
      
        # Si la commande d'installation est vide, utilise la valeur par défaut
        custom_command=${custom_command:-$container_default_command}

        # Vérifie si le port est déjà utilisé
        local port=$(echo "$custom_command" | grep -oP '(?<=-p )\d+(?=:)')
        if [ -n "$port" ] && lsof -i :$port > /dev/null 2>&1; then
   
          # Demande un nouveau port
          while true; do
            local new_port
            new_port=$(whiptail --inputbox "\n$msg_ask_new_port$port" 20 70 --fb --title "$G_TITLE" --ok-button "Ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
            local input_status=$?

            if [ $input_status -eq 1 ]; then # Clic "Annuler"
              echo_msgbox "$msg_installation_canceled"
              return 1
            fi

            # Vérifie si le nouveau port est libre
            if ! lsof -i :$new_port > /dev/null 2>&1; then
              custom_command=$(echo "$custom_command" | sed "s/-p $port:/-p $new_port:/")
              break
            fi
          done
          
        fi
 
        # Appeler la fonction pour créer et exécuter le script temporaire
        if create_and_execute_temp_script "$custom_command" "menu_1_containers_1_install_uninstall" "$container_name"; then

          # Écrire la nouvelle configuration dans le fichier nrx800.cfg
          config_params_load_write

          # Demander si l'utilisateur souhaite démarrer le conteneur
          if whiptail --yesno "$msg_install_success\n$msg_start_prompt" 12 70 --fb --title "$G_TITLE" --yes-button "$msg_button_yes" --no-button "$msg_button_no"; then
            if docker start "$container_name_cmd"; then
              echo_msgbox "$msg_start_success"
            else
              echo_msgbox "$msg_start_failure"
            fi
          fi
        else
          echo_msgbox "$msg_install_error"
          return 1
        fi
      fi
    
    # Le conteneur existe
    else
      #  Vérifier s'il est en cours d'exécution
      if ! docker ps --format '{{.Names}}' | grep -q "^$container_name_cmd$"; then
        #  Si le container n'est pas démarré, demander à l'utilisateur s'il souhaite le démarrer
        if whiptail --yesno "\n$msg_not_running_prompt" 12 70 --fb --title "$G_TITLE" --yes-button "$msg_button_yes" --no-button "$msg_button_no"; then
            if docker start "$container_name_cmd"; then
              echo_msgbox "$msg_start_success"
            else
              echo_msgbox "$msg_start_failure"
            fi
        fi
      else
        echo_msgbox "$msg_yet_installed"
      fi
      
    fi
  fi

  # Si l'utilisateur a choisi de désinstaller
  if [ "$G_CHOICE" == "D" ]; then

     # Verifie que le conteneur existe, qu'il soit en cours d'exécution ou non
    if ! container_is_installed "$container_name"; then
  
      # Récupère l'état du conteneur
      container_status=$(docker inspect -f '{{.State.Status}}' "$container_name_cmd")
      if [ "$container_status" == "running" ]; then
        msg_status=$msg_container_running
      elif [ "$container_status" == "paused" ]; then
        msg_status=$msg_container_paused
      elif [ "$container_status" == "exited" ]; then
        msg_status=$msg_container_exited
      else
        msg_status=$msg_container_unknown
      fi
      
			# Propose à l'utilisateur de simplement arrêter le conteneur ou de l'arrêter et le désinstaller
			local stop_state="false"
			local stop_and_uninstall_state="false"
			local stop_and_uninstall_and_remove_img_state="false"
			local action_choice

			action_choice=$(whiptail --radiolist "\n$msg_stop_prompt\n($msg_status)" 20 70 3 \
				"1" "$msg_stop_only" ON \
				"2" "$msg_stop_and_uninstall" OFF \
				"3" "$msg_stop_and_uninstall_and_remove_img" OFF \
				--fb --title "$G_TITLE" --notags --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
			local exit_status=$?

			# Sort si clic "Retour"
			if [ "$exit_status" -eq 1 ]; then 
				return 0
			fi  

			# Récupère le nom de l'image du conteneur avant suppression du conteneur
			local container_image_name=""
			if [[ -n "$container_name_cmd" ]]; then
				container_image_name=$(sudo docker ps -a --filter "name=$container_name_cmd" --format '{{.Image}}' 2>/dev/null)
			fi

			# Comparaison numérique pour activer les étapes de la désinstallation
			[ "$action_choice" -ge 1 ] && stop_state="true"
			[ "$action_choice" -ge 2 ] && stop_and_uninstall_state="true"
			[ "$action_choice" -ge 3 ] && stop_and_uninstall_and_remove_img_state="true"
 			
      # Si Arrêt
      if [ "$stop_state" == "true" ]; then

        # Affiche dans le terminal le début du traitement
     		echo_process_start "$container_name"
	   
        # Affiche dans le terminal le début de l'étape en cours
        echo_step_start "$msg_stop"

        # Vérifier si le conteneur est en cours d'exécution
        if container_is_running "$container_name_cmd"; then
        # if "docker ps | grep -q "$container_name_cmd"; then
          
					# Le conteneur est en cours d'exécution, on tente de l'arrêter    
          if sudo docker stop "$container_name_cmd" > /dev/null 2>&1; then
            echo_step_stop "$msg_stop_success"
            sleep 5
          else
            echo_msgbox "$msg_stop_error"
            return 1
          fi
					
        fi

      fi

      # Si Arrêt et suppression du container 
      if [ "$stop_and_uninstall_state" == "true" ]; then

        # Affiche dans le terminal le début de l'étape en cours
        echo_step_start "$msg_remove"
        
        # Suppression du container 
        if sudo docker rm "$container_name_cmd" > /dev/null 2>&1; then
          echo_step_stop "$msg_uninstall_success"
        else
          echo_msgbox "$container_uninstall_error_msg"
          return 1
        fi

      fi

      # Si Arrêt et suppression du container et de son image 
      if [ "$stop_and_uninstall_and_remove_img_state" == "true" ]; then

        # Affiche dans le terminal le début de l'étape en cours
        echo_step_start "$msg_remove_image $container_image_name"
        
        # Vérifie si il existe une image du container  
        if [ -z "$container_image_name" ]; then
          echo_msgbox "$container_unable_retrieve_image_msg" "$G_TITLE"
          return 1
        else  
          # Supprime l'image
          if sudo docker rmi "$container_image_name" > /dev/null 2>&1; then
            # Affiche dans le terminal la fin de l'étape en cours
            echo_step_stop "$msg_remove_image_success"
          else
            echo_msgbox "$msg_remove_image_failure"
          fi
        fi

      fi
      
      # Affiche dans le terminal la fin du traitement
      echo_process_stop "$container_name"
      
      sleep 2
      
    else
    
      # Avertit que le container est pas installé, donc pas désinstallable
      echo_msgbox "$msg_not_installed_cancel"
    fi
  fi
  
}

# Fonction pour vérifier les paramètres des conteneurs
# Function to check container parameters
function menu_1_containers_2_check_parametres() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_no="Non"
    local msg_button_yes="Oui"
    local msg_cancel_message="Annulation du lancement des conteneurs."
    local msg_command_label="Commande:"
    local msg_confirmation_message="Voulez-vous lancer les conteneurs avec ces paramètres ?"
    local msg_container_label="Conteneur:"
    local msg_directory_missing="Le répertoire %s n'existe pas. Création du répertoire..."
    local msg_permissions_check="Vérification des permissions des répertoires de volumes..."
    local msg_permissions_error="Le répertoire %s n'appartient pas à %s. Ajustement des permissions..."
    local msg_port_used="Le port %s est déjà utilisé par le conteneur %s."
    local msg_summary_title="Résumé des paramètres des conteneurs:"
    local msg_title="Vérification des paramètres des conteneurs"
  else
    local msg_button_no="No"
    local msg_button_yes="Yes"
    local msg_cancel_message="Canceling container launch."
    local msg_command_label="Command:"
    local msg_confirmation_message="Do you want to start the containers with these parameters?"
    local msg_container_label="Container:"
    local msg_directory_missing="The directory %s does not exist. Creating the directory..."
    local msg_permissions_check="Checking volume directory permissions..."
    local msg_permissions_error="The directory %s does not belong to %s. Adjusting permissions..."
    local msg_port_used="Port %s is already in use by container %s."
    local msg_summary_title="Summary of container parameters:"
    local msg_title="Check Container Parameters"
  fi

  # Vérifier les permissions des répertoires de volumes
  echo_msgbox "$msg_permissions_check" "$msg_title"
  
  for container in "${!G_DOCKER_CMD_INS[@]}"; do
    local command="${G_DOCKER_CMD_INS[$container]}"
    local volumes=$(echo "$command" | grep -oP '(?<=-v )[^ ]+')
    for volume in $volumes; do
      local host_path=$(echo "$volume" | cut -d':' -f1)
      if [ -d "$host_path" ]; then
        if [ "$(stat -c %U "$host_path")" != "$G_USERNAME" ]; then
          echo_msgbox "$(printf "$msg_permissions_error" "$host_path" "$G_USERNAME")" "Permissions"
          sudo chown -R "$G_USERNAME":"$G_USERNAME" "$host_path"
        fi
      else
        echo_msgbox "$(printf "$msg_directory_missing" "$host_path")" "Directory Missing"
        sudo mkdir -p "$host_path"
        sudo chown -R "$G_USERNAME":"$G_USERNAME" "$host_path"
      fi
    done
  done

  # Vérifier les ports utilisés
  for container in "${!G_DOCKER_CMD_INS[@]}"; do
    local command="${G_DOCKER_CMD_INS[$container]}"
    local ports=$(echo "$command" | grep -oP '(?<=-p )[^ ]+')
    for port in $ports; do
      local host_port=$(echo "$port" | cut -d':' -f1)
      if lsof -i :"$host_port" > /dev/null 2>&1; then
        echo_msgbox "$(printf "$msg_port_used" "$host_port" "$container")" "Port Used"
      fi
    done
  done

  # Afficher un résumé des paramètres
  local summary=""
  for container in "${!G_DOCKER_CMD_INS[@]}"; do
    local command="${G_DOCKER_CMD_INS[$container]}"
    summary+="$msg_container_label $container\n"
    summary+="$msg_command_label $command\n"
    summary+="-----------------------------\n"
  done
  echo_msgbox "$msg_summary_title\n\n$summary" "$msg_title"

  # Demander une confirmation avant de lancer les conteneurs
  if ! whiptail --yesno "$msg_confirmation_message" 10 60 --fb --title "Confirmation" --yes-button "$msg_button_yes" --no-button "$msg_button_no"; then
    echo_msgbox "$msg_cancel_message" "$msg_title"
    return 1
  fi

  return 0
  
}

# Fonction pour installer les packages du container node-red 
# Function to install packages for the node-red container
function menu_1_containers_3_node_red() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_title="$G_TITLE - Gestion des Containers"
    local msg_button_ok="Suivant"
    local msg_button_cancel="Retour"
  else
    local msg_title="$G_TITLE - Gestion des Containers"
    local msg_button_ok="Next"
    local msg_button_cancel="Back"
  fi

  echo_msgbox "menu_1_containers_3_node_red / nodered" "$msg_title"

}



##########   MENU PACKAGES

# Fonction pour le menu des packages
# Function for the packages menu
function menu_2_packages() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_no="Non"
    local msg_button_ok="Suivant"
    local msg_button_yes="Oui"
    local msg_error_message="Une erreur s'est produite"
    local msg_free_on="libre sur"
    local msg_install_uninstall="\nSélectionnez les packages à installer ou désinstaller :\n("
    local msg_list_package_check="Traitement du package : "
    local msg_list_package_processing="Analyse des packages..."
    local msg_no_selection="Aucun package sélectionné. Veuillez sélectionner au moins un package."
    local msg_status_installed="Installé"
    local msg_status_not_installed="Non installé"
    local msg_title="$G_TITLE - Gestion des Packages"
  else
    local msg_button_cancel="Back"
    local msg_button_no="No"
    local msg_button_ok="Next"
    local msg_button_yes="Yes"
    local msg_error_message="An error occurred"
    local msg_free_on="free on"
    local msg_install_uninstall="\nSelect packages to install or uninstall :\n("
    local msg_list_package_check="Processing package : "
    local msg_list_package_processing="Analyzing packages..."
    local msg_no_selection="No package selected. Please select at least one package."
    local msg_status_installed="installed"
    local msg_status_not_installed="not installed"
    local msg_title="$G_TITLE - Package Management"
  fi

  # Affiche dans le terminal le début du traitement
  echo_process_start "$msg_list_package_processing"

  # Crée la liste des packages à installer
  local max_length=59
  local options=()
  local installed_packages=()
 
  # Trie les packages par ordre alphabétique en fonction des noms de package
  local sorted_list=($(echo "${!G_PACKAGE_CMD_INS[@]}" | tr ' ' '\n' | sort))

  # Crée la liste des packages à installer
	for list_name in "${sorted_list[@]}"; do

    local package_name="${G_PACKAGE_NAME[$list_name]}"
    local package_command="${G_PACKAGE_CMD_INS[$list_name]}"

    # Affiche dans le terminal le début de l'étape en cours
    echo_step_start "$msg_list_package_check $list_name"
   
    # Vérifie si le package npm est installé globalement
	   local status=""
    if is_package_installed "$package_name" >/dev/null; then
      status="$msg_status_installed"
    else
      status="$msg_status_not_installed"
    fi

    # Calcule la longueur totale de la ligne (nom + statut)
    local info_length=$(( ${#list_name} + ${#status} ))
    # Calcule le nombre de caractères "." à mettre entre nom et statut
    local dots_length=$((max_length - info_length))
    if [ $dots_length -lt 0 ]; then
      dots_length=0
    fi
    local dots=$(printf "%${dots_length}s" "" | tr ' ' '.')

    # Ajoute l'information formatée à la liste des options
    options+=("$list_name" "$list_name $dots $status " OFF)
    
    # Affiche dans le terminal la fin de l'étape en cours
    echo_step_stop "$msg_list_package_check $list_name"
    
  done
  
  # Affiche dans le terminal la fin du traitement
  echo_process_stop "$msg_button_cancel $G_TITLE"
  
  # Récupère l'espace libre sur la partition principale
  free_space=$(df -h "$(pwd)" | awk -v msg_free_on="$msg_free_on" 'NR==2 {printf "%s %s %s", $4, msg_free_on, $1}')

  # Calculer la hauteur dynamique de la liste et limite à 10 si sup à 10
  local num_items=${#sorted_list[@]}
  if (( num_items > 9 )); then
    num_items=9
  fi
  # Hauteur de base + nombre d'éléments
  local menu_height=$((11 + num_items))
  # Limiter la hauteur maximale pour éviter des problèmes d'affichage
  if [ $menu_height -gt 20 ]; then
    menu_height=20
  fi

  # Affiche la boîte de dialogue avec whiptail
  local selected_packages
  selected_packages=$(whiptail --checklist "$msg_install_uninstall$free_space)" $menu_height 75 $num_items "${options[@]}" \
               --fb --title "$msg_title" --notags --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
  # Récupère le statut de sortie de whiptail
  local exit_status=$?
  
  # clic "Retour"
  if [ $exit_status -eq 1 ]; then 
    return 0
  
  # clic "Suivant"
  elif [ $exit_status -eq 0 ]; then
    
    # Si pas de choix coché
    if [ -z "$selected_packages" ]; then
      echo_msgbox "$msg_no_selection" "$msg_title"

    # Au moins un choix coché, récupère la liste des éléments cochés
    else
        
      selected_packages=($(echo "$selected_packages" | tr -d '"'))
      
      # Installe ou désinstalle les éléments sélectionnés
      for package in "${selected_packages[@]}"; do

        # Si erreur d'installation d'un package sort
        if ! menu_2_packages_1_install_uninstall "$package" "${G_PACKAGE_CMD_INS[$package]}"; then
          echo_msgbox "$msg_error_message : $package" "$msg_title"
          return 1
        fi

      done

    fi

  else
    echo_msgbox "$msg_error_message" "$msg_title"
    return 1
  fi

}

# Fonction pour installer ou désinstaller un package
# Function to install or uninstall a package
function menu_2_packages_1_install_uninstall() {

  # Récupère les paramètres
  local package_name=$1
  local package_default_command=$2

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_no="Non"
    local msg_button_ok="Suivant"
    local msg_button_yes="Oui"
    local msg_wait_install="Patientez...Installation en cours"
    local msg_wait_end_install="L'installation est terminée"
    local msg_wait_uninstall="Patientez...Désinstallation en cours"
    local msg_wait_end_uninstall="La désinstallation eest terminée"
    local msg_cmd_not_defined="Erreur : Les commandes pour $package_name ne sont pas définies."
    local msg_not_installed="$package_name n'est pas installé. Installation en cours..."
    local msg_install_success="$package_name a été installé avec succès."
    local msg_install_error="Erreur lors de l'installation de $package_name."
    local msg_yet_installed="$package_name est déjà installé."
    local msg_uninstall_success="$package_name a été désinstallé avec succès."
    local msg_uninstall_error="Erreur lors de la désinstallation de $package_name."
    local msg_not_installed_cancel="$package_name n'est pas installé, désinstallation annulée."
    local msg_custom_command_prompt="Voulez-vous modifier les paramètres d'installation du package ? \n(Laissez vide pour utiliser les paramètres par défaut)"
  else
    local msg_button_cancel="Back"
    local msg_button_no="No"
    local msg_button_ok="Next"
    local msg_button_yes="Yes"
    local msg_wait_install="Please wait...Installation in progress"
    local msg_wait_end_install="Installation is complete"
    local msg_wait_uninstall="Please wait...Uninstallation in progress"
    local msg_wait_end_uninstall="Uninstallation is complete"
    local msg_cmd_not_defined="Error: Commands for $package_name are not defined."
    local msg_not_installed="$package_name is not installed. Installing now..."
    local msg_install_success="$package_name has been installed successfully."
    local msg_install_error="Error installing $package_name."
    local msg_yet_installed="$package_name is already installed."
    local msg_uninstall_success="$package_name has been uninstalled successfully."
    local msg_uninstall_error="Error uninstalling $package_name."
    local msg_not_installed_cancel="$package_name is not installed, uninstall canceled."
    local msg_custom_command_prompt="Do you want to modify the package installation parameters ?\n(Leave empty to use default parameters)"
  fi

  # Récupère les commandes d'installation et de désinstallation par défaut depuis les tableaux
  local package_default_install_command=${G_PACKAGE_CMD_INS["$package_name"]}
  local package_default_uninstall_command=${G_PACKAGE_CMD_UNINS["$package_name"]}
  
  # Vérifie si les commandes d'installation et de désinstallation sont définies
  if [ -z "$package_default_install_command" ] || [ -z "$package_default_uninstall_command" ]; then
    echo_msgbox "$msg_cmd_not_defined"
    return 1
  fi

  # Appel de la fonction pour afficher le menu d'action pour les containers
  menu_0_main_menu_action "package" "$package_name"

  # Sort si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" == "A" ]; then
    return 0
  fi

  # Si l'utilisateur choisit d'installer le package
  if [ "$G_CHOICE" == "I" ]; then

    # Vérifie si le package est déjà installé
    if ! is_package_installed "$package_name" > /dev/null; then
      # Propose de modifier la commande d'installation par défaut
      local custom_command
      custom_command=$(whiptail --inputbox "\n$msg_custom_command_prompt" 20 70 "$package_default_install_command" --fb --title "$G_TITLE" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)

      # Si l'utilisateur annule, quitte la fonction
      if [ $? -ne 0 ]; then
        return 1
      fi

      # Utilise la commande par défaut si l'utilisateur n'en fournit pas une nouvelle
      if [ -z "$custom_command" ]; then
        custom_command="$package_default_command"
      fi
     
      # Exécute la commande d'installation en capturant les erreurs
      echo_process_start "$package_name $msg_wait_install"
      
      local error_message=$(eval "$custom_command" 2>&1)
      
      echo_process_stop "$package_name $msg_wait_end_install"
      
      # Si l'installation a echoué
      if [ $? -ne 0 ]; then
        echo_msgbox "$msg_install_error\n\nDétails de l'erreur :\n$error_message"
        return 1
      fi

      # Si l'installation a réussi
      echo_msgbox "$msg_install_success"

    # Informe que le package est déjà installé
    else

      echo_msgbox "$msg_yet_installed" 
    fi

  fi

  # Si l'utilisateur choisit de désinstaller le package
  if [ "$G_CHOICE" == "D" ]; then

    # Vérifie si le package est installé
    if dpkg -s "$package_name" &> /dev/null; then
    
      # Exécute la commande de désinstallation en capturant les erreurs
      echo_process_start " $G_ICO_SUCCESS $package_name $msg_wait_uninstall"
      local error_message=$(eval "$package_default_uninstall_command" 2>&1)
      echo_process_stop " $G_ICO_SUCCESS $package_name $msg_wait_end_uninstall"
      
      # Si la désinstallation a echoué
      if [ $? -ne 0 ]; then
        echo_msgbox "$msg_uninstall_error\n\nDétails de l'erreur :\n$error_message"
        return 1
      fi

      # Si la dsinstallation a réussi
      echo_msgbox "$msg_uninstall_success"

    # Informe que le package n'est pas installé
    else
      echo_msgbox "$msg_not_installed_cancel"
    fi

  fi
  
}



##########   MENU PACKAGES NPM

# Fonction pour le menu des packages npm
# Function for the npm packages menu
function menu_3_packages_npm() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
	  local msg_button_cancel="Retour"
    local msg_button_no="Non"
    local msg_button_ok="Suivant"
    local msg_button_yes="Oui"
    local msg_free_on="libre sur"
    local msg_error_message="Une erreur s'est produite"
    local msg_install_uninstall="\nSélectionnez les packages npm à installer ou désinstaller :\n("
    local msg_status_installed="installé"
    local msg_status_not_installed="non installé"
    local msg_list_npm_processing="Analyse des packages npm..."
    local msg_list_npm_check="Traitement du package npm : "
    local msg_no_selection="Aucun package sélectionné. Veuillez sélectionner au moins un package."
    local msg_title="$G_TITLE - Gestion des Packages Npm"
  else
	  local msg_button_cancel="Back"
    local msg_button_no="No"
    local msg_button_ok="Next"
    local msg_button_yes="Yes"
    local msg_error_message="An error occurred"
    local msg_free_on="free on"
    local msg_install_uninstall="\nSelect npm packages to install or uninstall :\n("
    local msg_list_npm_processing="Analyzing npm packages..."
    local msg_list_npm_check="Processing npm package : "
    local msg_no_selection="No package selected. Please select at least one package."
    local msg_status_installed="installed"
    local msg_status_not_installed="not installed"
    local msg_title="$G_TITLE - Npm Package Management"
  fi

  # Affiche dans le terminal le début du traitement
  echo_process_start "$msg_list_npm_processing"

  # Liste des packages npm installés globalement (sans la version)
  local installed_packages
  installed_packages=$(npm list -g --depth=0 2>/dev/null | awk -F'@' '/─/ {print tolower($1)}' | sed 's/^[├└─]*//' | sed 's/^ *//')

  # Trie les packages npm par ordre alphabétique en fonction des noms de package
  local sorted_list=($(echo "${!G_PACKAGE_NPM_CMD_INS[@]}" | tr ' ' '\n' | sort))

  # Crée la liste des packages npm à installer
  local max_length=59
  local options=()
  for list_name in "${sorted_list[@]}"; do
   
    # Récupère le nom réel du package npm (en minuscules) depuis G_PACKAGE_NPM_NAME
    local npm_package_name="${G_PACKAGE_NPM_NAME[$list_name]}"
  
    # Affiche dans le terminal le début de l'étape en cours
    echo_step_start "$msg_list_npm_check $list_name"
    
    # Vérifie si le package npm est installé globalement
    local status=""
    if echo "$installed_packages" | grep -qw "^$npm_package_name$"; then
      status="$msg_status_installed"
    else
      status="$msg_status_not_installed"
    fi

    # Calcule la longueur totale de la ligne (nom + statut)
    local info_length=$(( ${#list_name} + ${#status} ))
    # Calcule le nombre de caractères "." à mettre entre nom et statut
    local dots_length=$((max_length - info_length))
    if [ $dots_length -lt 0 ]; then
      dots_length=0
    fi
    local dots=$(printf "%${dots_length}s" "" | tr ' ' '.')

    # Ajoute l'information formatée à la liste des options
    options+=("$list_name" "$list_name $dots $status " OFF)
    
    # Affiche dans le terminal la fin de l'étape en cours
    echo_step_stop "$msg_list_npm_check $list_name"

  done
  
  # Affiche dans le terminal la fin du traitement
  echo_process_stop "$button_cancel $G_TITLE"

  # Récupère l'espace libre sur la partition principale
  free_space=$(df -h "$(pwd)" | awk -v msg_free_on="$msg_free_on" 'NR==2 {printf "%s %s %s", $4, msg_free_on, $1}')

  # Calculer la hauteur dynamique de la liste et limite à 10 si sup à 10
  local num_items=${#sorted_list[@]}
  if (( num_items > 10 )); then
    num_items=10
  fi
  # Hauteur de base + nombre d'éléments
  local menu_height=$((10 + num_items))
  # Limiter la hauteur maximale pour éviter des problèmes d'affichage
  if [ $menu_height -gt 20 ]; then
    menu_height=20
  fi

  # Affiche la boîte de dialogue avec whiptail
  local selected_packages
  selected_packages=$(whiptail --checklist "$msg_install_uninstall$free_space)" $menu_height 75 $num_items "${options[@]}" --fb --title "$msg_title" --notags --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
  # Récupère le statut de sortie de whiptail
  local exit_status=$?
  
	# clic "Retour"
  if [ $exit_status -eq 1 ]; then
    return 0
 
 # clic "Suivant"		
  elif [ $exit_status -eq 0 ]; then

    # Si pas de choix coché
    if [ -z "$selected_packages" ]; then
        echo_msgbox "$msg_no_selection" "$msg_title"

    # Au moins un choix coché, récupère la liste des éléments cochés
    else

        selected_packages=($(echo "$selected_packages" | tr -d '"'))

        # Installe ou désinstalle les éléments sélectionnés
        for package in "${selected_packages[@]}"; do

          if ! menu_3_packages_npm_1_install_uninstall "$package" "${G_PACKAGE_NPM_CMD_INS[$package]}"; then
            echo_msgbox "$msg_error_message : $package" "$msg_title"
            return 1
          fi

        done

    fi

  else
    echo_msgbox "$msg_error_message" "$msg_title"
    return 1
  fi

}

# Fonction pour installer ou désinstaller un package npm
# Function to install or uninstall an npm package
function menu_3_packages_npm_1_install_uninstall() {

  # Récupère les paramètres
  local package_name=$1

  # Définit les messages et options en fonction de la langue
  if [ "$G_LANG" = "fr" ]; then
		local msg_button_cancel="Retour"
		local msg_button_no="Non"
		local msg_button_ok="Suivant"
		local msg_button_yes="Oui"
    local msg_ask_action="\nQue voulez-vous faire ?"
    local msg_command_invalid="Commande invalide"
    local msg_command_expected="Le format attendu est : sudo npm install -g <nom_du_package>[@version]"
    local msg_custom_command_prompt="Voulez-vous modifier les paramètres d'installation du package ? \n(Laissez vide pour utiliser les paramètres par défaut)"
    local msg_end_install="L'installation est terminée"
    local msg_install_error="Erreur lors de l'installation de $package_name."
    local msg_install_success="$package_name a été installé avec succès."
    local msg_not_installed="$package_name n'est pas installé. Installation en cours..."
    local msg_uninstall_error="Erreur lors de la désinstallation de $package_name."
    local msg_uninstall_success="$package_name a été désinstallé avec succès."
    local msg_not_installed_cancel="$package_name n'est pas installé, désinstallation annulée."
    local msg_yet_installed="$package_name est déjà installé."
    local msg_wait_install="Patientez...Installation en cours"
  else
    local msg_button_cancel="Back"
		local msg_button_no="No"
		local msg_button_ok="Next"
		local msg_button_yes="Yes"
    local msg_ask_action="\nWhat do you want to do?"
    local msg_command_invalid="Invalid command"
    local msg_command_expected="The expected format is: sudo npm install -g <package_name>[@version]"
    local msg_custom_command_prompt="Do you want to modify the package installation parameters ?\n(Leave empty to use default parameters)"
    local msg_end_install="Installation is complete"
    local msg_install_error="Error installing $package_name."
    local msg_install_success="$package_name has been installed successfully."
    local msg_not_installed="$package_name is not installed. Installing now..."
    local msg_not_installed_cancel="$package_name is not installed, uninstall canceled."
    local msg_uninstall_error="Error uninstalling $package_name."
    local msg_uninstall_success="$package_name has been uninstalled successfully."
    local msg_yet_installed="$package_name is already installed."
    local msg_wait_install="Please wait...Installation in progress"
  fi

  # Appel de la fonction pour afficher le menu d'action pour les containers
  menu_0_main_menu_action "package npm" "$package_name"

  # Récupère le nom réel du package npm (en minuscules) depuis G_PACKAGE_NPM_NAME
  local npm_name="${G_PACKAGE_NPM_NAME[$package_name]}"

  # Récupère les commandes d'installation et de désinstallation par défaut depuis les tableaux
  local package_default_install_command="${G_PACKAGE_NPM_CMD_INS[$package_name]}"
  local package_default_uninstall_command="${G_PACKAGE_NPM_CMD_UNINS[$package_name]}"

  # Vérifie si les commandes d'installation et de désinstallation sont définies
  if [ -z "$package_default_install_command" ] || [ -z "$package_default_uninstall_command" ]; then
    echo_msgbox "Erreur : Les commandes pour $package_name ne sont pas définies."
    return 1
  fi

  # Sort si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" == "A" ]; then
    return 0
  fi

  # Si l'utilisateur choisit d'installer le package
  if [ "$G_CHOICE" == "I" ]; then

    # Vérifie si le package est déjà installé globalement
    installed_packages=$(npm list -g --depth=0 2>/dev/null | awk -F'@' '/─/ {print tolower($1)}' | sed 's/^[├└─]*//' | sed 's/^ *//')
    
		if ! echo "$installed_packages" | grep -Fxq "$npm_name"; then

  		# Affiche un message informant que l'installation va commencer
      echo_msgbox "$msg_not_installed" "$G_TITLE"

      # Propose de modifier la commande d'installation par défaut
      local custom_command
      custom_command=$(whiptail --inputbox "\n$msg_custom_command_prompt" 20 70 "$package_default_install_command" --fb --title "$G_TITLE" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)

      # Si l'utilisateur annule, quitte la fonction
      if [ $? -ne 0 ]; then
        return 1
      fi

      # Utilise la commande par défaut si l'utilisateur n'en fournit pas une nouvelle
      if [ -z "$custom_command" ]; then
        custom_command="$package_default_install_command"
      fi

      # Validation et execution de la commande
      if [[ ! "$custom_command" =~ ^sudo\ npm\ install\ -g\ [a-zA-Z0-9@\.\-]+$ ]]; then
        echo_msgbox "$msg_command_invalid : $custom_command\n\n$msg_command_expected"
        return 1
      fi
			
			# Exécute la commande d'installation en capturant les erreurs
      echo_process_start " $G_ICO_SUCCESS $package_name $msg_wait_install"
      local error_message=$(eval "$custom_command" 2>&1)
      echo_process_stop " $G_ICO_SUCCESS $package_name $msg_end_install"

      # Vérifie si l'installation a réussi
      if [ $? -eq 0 ]; then
        echo_msgbox "$msg_install_success"
      else
        echo_msgbox "$msg_install_error\n\nDétails de l'erreur :\n$error_message"
        return 1
      fi

    # Informe que le package est déjà installé
    else
      echo_msgbox "$msg_yet_installed"
    fi
  
	fi

  # Si l'utilisateur choisit de désinstaller le package
  if [ "$G_CHOICE" == "D" ]; then
  
    installed_packages=$(npm list -g --depth=0 2>/dev/null | awk -F'@' '/─/ {print tolower($1)}' | sed 's/^[├└─]*//' | sed 's/^ *//')
    if echo "$installed_packages" | grep -Fxq "$npm_name"; then
      # Exécute la commande de désinstallation en capturant les erreurs
      local error_message
      error_message=$(eval "$package_default_uninstall_command" 2>&1)

      # Vérifie si la désinstallation a réussi
      if [ $? -eq 0 ]; then
        echo_msgbox "$msg_uninstall_success"
      else
        echo_msgbox "$msg_uninstall_error\n\nDétails de l'erreur :\n$error_message"
        return 1
      fi
    else
    
      # Informe que le package n'est pas installé
      echo_msgbox "$msg_not_installed_cancel" 
    fi

  fi

}



##########   MENU GESTION DES OUTILS SYSTEME - SYSTEM TOOLS MANAGEMENT MENU

# Fonction pour le menu des outils système
# Function for system tools menu
function menu_4_system_tools() {

  # Définir les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_list_tool_check="Traitement de l'outil :"
    local msg_list_tools_processing="Analyse des outils système :"
    local msg_message="\nSélectionnez les outils à installer ou désinstaller :"
    local msg_no_selection="Aucun outil sélectionné. Veuillez sélectionner au moins un outil."
    local msg_button_ok="Suivant"
    local msg_status_installed="installé"
    local msg_status_not_installed="non installé"
    local msg_title="$G_TITLE - Gestion des Outils Système"
  else
    local msg_button_cancel="Back"
    local msg_list_tool_check="Processing tool :"
    local msg_list_tools_processing="Analyzing system tools..."
    local msg_message="\nSelect tools to install or uninstall :"
    local msg_no_selection="No tool selected. Please select at least one tool."
    local msg_button_ok="Next"
    local msg_status_installed="installed"
    local msg_status_not_installed="not installed"
    local msg_title="$G_TITLE - System Tool Management"
  fi

  # Trier la liste des outils par ordre alphabétique
  local sorted_list=($(echo "${!G_SYSTEM_TOOL_COMMANDS[@]}" | tr ' ' '\n' | sort))

  local options=()
  local max_length=58

  # Afficher le message de début de traitement
  echo_process_start "$msg_list_tools_processing"

  for list_name in "${sorted_list[@]}"; do

    # Afficher le message de début de l'étape
    echo_step_start "$msg_list_tool_check $list_name"

    # Extraire le nom du package de l'outil à partir de la valeur
    # local tool_name=$(echo "${G_SYSTEM_TOOL_NAME[$list_name]}")
    local tool_name="${G_SYSTEM_TOOL_NAME[$list_name]}"

    # Vérifier si l'outil est installé
    local status=""
    if eval "${G_SYSTEM_TOOL_CHECK[$list_name]}"; then
      status="$msg_status_installed"
    else
      status="$msg_status_not_installed"
    fi

    # Calculer la longueur de l'information à afficher
    local info_length=$(( ${#list_name} + ${#status} ))
    # Calculer le nombre de points à ajouter
    local dots_length=$((max_length - info_length))
    if [ $dots_length -lt 0 ]; then
      dots_length=0
    fi
    local dots
    dots=$(printf "%${dots_length}s" "" | tr ' ' '.')
    # Ajouter l'information formatée à la liste des options
    options+=("$list_name" "$list_name $dots $status " OFF)

    # Afficher le message de fin de l'étape
    echo_step_stop "$msg_list_tool_check $list_name"

  done
  
  # Affiche dans le terminal la fin du traitement
  echo_process_stop "$cancel_button $G_TITLE"
  
  # Calculer la hauteur du menu en fonction du nombre d'éléments
  local num_items=${#sorted_list[@]}
  if (( num_items > 10 )); then
    num_items=10
  fi
  local menu_height=$((10 + num_items))

  # Afficher le menu
  local choice_menu
  choice_menu=$(whiptail --checklist "$msg_message" $menu_height 75 $num_items "${options[@]}" \
               --fb --title "$msg_title" --notags --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)

  # Obtenir le statut de sortie
  local exit_status=$?

  # Si l'utilisateur annule, quitter la fonction
  if [ $exit_status -eq 1 ]; then
    return 0
  fi

  # Si l'utilisateur sélectionne "Suivant"
  if [ $exit_status -eq 0 ]; then
    
    # Si pas de choix coché, afficher un message d'erreur
    if [ -z "$choice_menu" ]; then
      echo_msgbox "$msg_no_selection" "$msg_title"
    else
    
      # Traiter les outils sélectionnés
      selected_packages=($(echo "$choice_menu" | tr -d '"' | tr ' ' '\n'))
      for selected in "${selected_packages[@]}"; do
      
        command_name="${G_SYSTEM_TOOL_COMMANDS[$selected]}"
        if [ -n "$command_name" ]; then
          $command_name "$selected"
        else
          echo_msgbox "$msg_no_selection" "$msg_title"
        fi
      done

    fi
  else
    whiptail --infobox "Une erreur s'est produite (Code: $exit_status)" 15 70 --fb --title "$msg_title"
  fi

}

# Fonction pour installer ou désinstaller Docker
# Function to install or uninstall Docker
function menu_4_system_tools_docker_ce() {

  # Définir les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_already_installed="Docker est déjà installé."
    local msg_data_deleted="Les répertoires de données Docker ont été supprimés."
    local msg_data_kept="Les répertoires de données Docker ont été conservés."
    local msg_data_warning="Les répertoires de données Docker (/var/lib/docker et /var/lib/containerd) contiennent des images, des conteneurs, des volumes et des réseaux. Voulez-vous les supprimer ?"
    local msg_install_error="Erreur lors de l'installation de Docker."
    local msg_install_script_error="Erreur lors de l'exécution du script d'installation de Docker."
    local msg_install_success="Docker a été installé avec succès."
    local msg_not_installed_cancel="Docker n'est pas installé, désinstallation annulée."
    local msg_tool_type="outil système"
    local msg_uninstall_error="Erreur lors de la désinstallation de Docker."
    local msg_uninstall_script_error="Erreur lors de l'exécution du script de désinstallation de Docker."
    local msg_uninstall_success="Docker a été désinstallé avec succès."
    local msg_uninstalling="Docker est en cours de désinstallation."
  else
    local msg_already_installed="Docker is already installed."
    local msg_data_deleted="Docker data directories have been deleted."
    local msg_data_kept="Docker data directories have been kept."
    local msg_data_warning="The Docker data directories (/var/lib/docker and /var/lib/containerd) contain images, containers, volumes, and networks. Do you want to delete them?"
    local msg_install_error="Error installing Docker."
    local msg_install_script_error="Error executing Docker installation script."
    local msg_install_success="Docker has been installed successfully."
    local msg_not_installed_cancel="Docker is not installed, uninstall canceled."
    local msg_tool_type="system tool"
    local msg_uninstall_error="Error uninstalling Docker."
    local msg_uninstall_script_error="Error executing Docker uninstallation script."
    local msg_uninstall_success="Docker has been uninstalled successfully."
    local msg_uninstalling="Docker is being uninstalled."
  fi

  # Appeler la fonction pour afficher le menu de gestion des actions
  menu_0_main_menu_action "$msg_tool_type" "Docker-ce"

  # Vérifier si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" == "A" ]; then
    return 0
  fi

  # Si l'utilisateur choisit d'installer Docker
  if [ "$G_CHOICE" == "I" ]; then

    # Vérifier si Docker est déjà installé, si oui sort
    if command -v docker &> /dev/null; then
      echo_msgbox "$msg_already_installed"
      return 0
    fi
    
    # Crée le répertoire docker sil il existes pas et donne les droits à l'utilisateur courant d'y accéder
    if [ ! -d "/home/$G_USERNAME/docker" ]; then
      mkdir -p "/home/$G_USERNAME/docker"
      chown -R "$G_USERNAME:$G_USERNAME" "/home/$G_USERNAME/docker"
    fi


    # Créer et exécuter le script temporaire avec les commandes d'installation
    local temp_install_commands
    temp_install_commands="
#!/bin/bash

# 1. Mise à jour des paquets existants
echo -e \"\${G_TXT_GREEN}\${G_ICO_SUCCESS} $1 Mise à jour des paquets existants... \${G_RESET_COLOR}\"
sudo apt update -y || { echo -e \"\${G_TXT_RED}\${G_ICO_ERROR} Échec de la mise à jour des paquets. \${G_RESET_COLOR}\" >&2; exit 1; }

# 2. Installation des dépendances nécessaires (curl, gnupg, etc.)
echo -e \"\${G_TXT_GREEN}\${G_ICO_SUCCESS} $1 Installation des dépendances nécessaires... \${G_RESET_COLOR}\"
sudo apt install -y apt-transport-https ca-certificates curl gnupg || { echo -e \"\${G_TXT_RED}\${G_ICO_ERROR} Échec de l'installation des dépendances. \${G_RESET_COLOR}\" >&2; exit 1; }

# 3. Ajout de la clé GPG officielle de Docker
echo -e \"\${G_TXT_GREEN}\${G_ICO_SUCCESS} $1 Ajout de la clé GPG officielle de Docker... \${G_RESET_COLOR}\"
sudo mkdir -p /etc/apt/keyrings  # Crée le répertoire pour stocker les clés GPG
sudo chmod 0755 /etc/apt/keyrings  # Définit les permissions du répertoire
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg || { echo -e \"\${G_TXT_RED}\${G_ICO_ERROR} Échec de l'ajout de la clé GPG. \${G_RESET_COLOR}\" >&2; exit 1; }
sudo chmod a+r /etc/apt/keyrings/docker.gpg  # Rend la clé lisible par tous

# 4. Ajout du dépôt Docker pour Debian (compatible Raspberry Pi OS)
echo -e \"\${G_TXT_GREEN}\${G_ICO_SUCCESS} $1 Ajout du dépôt Docker pour Debian... \${G_RESET_COLOR}\"
sudo rm -f /etc/apt/sources.list.d/docker.list  # Supprime l'ancien fichier de dépôt s'il existe
echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || { echo -e \"\${G_TXT_RED}\${G_ICO_ERROR} Échec de l'ajout du dépôt Docker. \${G_RESET_COLOR}\" >&2; exit 1; }

# 5. Mise à jour des paquets avec le nouveau dépôt Docker
echo -e \"\${G_TXT_GREEN}\${G_ICO_SUCCESS} $1 Mise à jour des paquets avec le dépôt Docker... \${G_RESET_COLOR}\"
sudo apt update -y || { echo -e \"\${G_TXT_RED}\${G_ICO_ERROR} Échec de la mise à jour des paquets après ajout du dépôt Docker. \${G_RESET_COLOR}\" >&2; exit 1; }

# 6. Installation de Docker et des plugins associés
echo -e \"\${G_TXT_GREEN}\${G_ICO_SUCCESS} $1 Installation de Docker... \${G_RESET_COLOR}\"
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || { echo -e \"\${G_TXT_RED}\${G_ICO_ERROR} Échec de l'installation de Docker. \${G_RESET_COLOR}\" >&2; exit 1; }

# 7. Ajout de l'utilisateur actuel au groupe docker (pour éviter d'utiliser sudo)
echo -e \"\${G_TXT_GREEN}\${G_ICO_SUCCESS} $1 Ajout de l'utilisateur au groupe docker... \${G_RESET_COLOR}\"
sudo usermod -aG docker \$USER || { echo -e \"\${G_TXT_RED}\${G_ICO_ERROR} Échec de l'ajout de l'utilisateur au groupe docker. \${G_RESET_COLOR}\" >&2; exit 1; }

# 8. Vérification de l'installation de Docker
echo -e \"\${G_TXT_GREEN}\${G_ICO_SUCCESS} $1 Vérification de l'installation de Docker... \${G_RESET_COLOR}\"
docker --version || { echo -e \"\${G_TXT_RED}\${G_ICO_ERROR} Docker n'est pas installé correctement. \${G_RESET_COLOR}\" >&2; exit 1; }

# 9. Test de Docker avec un conteneur Hello World
echo -e \"\${G_TXT_GREEN}\${G_ICO_SUCCESS} $1 Test de Docker avec un conteneur Hello World... \${G_RESET_COLOR}\"
docker run --rm hello-world || { echo -e \"\${G_TXT_RED}\${G_ICO_ERROR} Le test Docker a échoué. \${G_RESET_COLOR}\" >&2; exit 1; }

# 10. Message de succès et instructions supplémentaires
echo -e \"\${G_TXT_GREEN}\${G_ICO_SUCCESS} $1 Docker a été installé avec succès ! \${G_RESET_COLOR}\"
echo -e \"\${G_TXT_YELLOW} Remarque : Vous devrez peut-être vous déconnecter et vous reconnecter pour que les changements de groupe prennent effet. \${G_RESET_COLOR}\"
sleep 2
# clear
"
    # Créer et exécuter le script temporaire
    create_and_execute_temp_script "$temp_install_commands" "menu_4_system_tools_docker_ce" "Docker-ce"

    # Afficher un message de succès ou d'erreur en fonction du retour de create_and_execute_temp_script
    if [ $? -eq 0 ]; then
      echo_msgbox "$msg_install_success"
    else
      echo_msgbox "$msg_install_script_error"
      return 1
    fi
  fi

  # Si l'utilisateur choisit de désinstaller Docker
  if [ "$G_CHOICE" == "D" ]; then

    # Vérifier si Docker est installé
    if ! command -v docker &> /dev/null; then
#   if ! package_is_installed "docker" &> /dev/null; then
      echo_msgbox "$msg_not_installed_cancel"
      return 0
    fi

    # Afficher un avertissement concernant la suppression des répertoires de données Docker
    whiptail --yesno "$msg_data_warning" 14 70 --fb --title "$G_TITLE" --yes-button "$msg_button_yes" --no-button "$msg_button_no"
    local exit_status=$?

    # Créer et exécuter le script temporaire avec les commandes de désinstallation
    local temp_uninstall_commands
    temp_uninstall_commands="
#!/bin/bash

# 1. Désinstallation de Docker et de ses composants
echo -e \"\${G_TXT_GREEN}\${G_ICO_SUCCESS} $1 Désinstallation de Docker et de ses composants... \${G_RESET_COLOR}\"
sudo apt remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || { echo -e \"\${G_TXT_RED}\${G_ICO_ERROR} Échec de la désinstallation de Docker. \${G_RESET_COLOR}\" >&2; exit 1; }

# 2. Suppression des fichiers de configuration de Docker
echo -e \"\${G_TXT_GREEN}\${G_ICO_SUCCESS} $1 Suppression des fichiers de configuration de Docker... \${G_RESET_COLOR}\"
sudo rm -rf /var/lib/docker || { echo -e \"\${G_TXT_RED}\${G_ICO_ERROR} Échec de la suppression des fichiers de configuration de Docker. \${G_RESET_COLOR}\" >&2; exit 1; }
sudo rm -rf /var/lib/containerd || { echo -e \"\${G_TXT_RED}\${G_ICO_ERROR} Échec de la suppression des fichiers de configuration de Docker. \${G_RESET_COLOR}\" >&2; exit 1; }

# 3. Suppression du dépôt Docker
echo -e \"\${G_TXT_GREEN}\${G_ICO_SUCCESS} $1 Suppression du dépôt Docker... \${G_RESET_COLOR}\"
sudo rm -f /etc/apt/sources.list.d/docker.list || { echo -e \"\${G_TXT_RED}\${G_ICO_ERROR} Échec de la suppression du dépôt Docker. \${G_RESET_COLOR}\" >&2; exit 1; }

# 4. Mise à jour des paquets après suppression de Docker
echo -e \"\${G_TXT_GREEN}\${G_ICO_SUCCESS} $1 Mise à jour des paquets après suppression de Docker... \${G_RESET_COLOR}\"
sudo apt update -y || { echo -e \"\${G_TXT_RED}\${G_ICO_ERROR} Échec de la mise à jour des paquets. \${G_RESET_COLOR}\" >&2; exit 1; }

# 5. Suppression des dépendances inutilisées
echo -e \"\${G_TXT_GREEN}\${G_ICO_SUCCESS} $1 Suppression des dépendances inutilisées... \${G_RESET_COLOR}\"
sudo apt autoremove -y || { echo -e \"\${G_TXT_RED}\${G_ICO_ERROR} Échec de la suppression des dépendances inutilisées. \${G_RESET_COLOR}\" >&2; exit 1; }

# 6. Message de succès
echo \"\${G_TXT_GREEN}\${G_ICO_SUCCESS} Docker a été désinstallé avec succès ! \${G_RESET_COLOR}\"
sleep 2
# clear
"

    # Créer et exécuter le script temporaire
    create_and_execute_temp_script "$temp_uninstall_commands" "menu_4_system_tools_docker_ce" "Docker-ce"

    # Afficher un message de succès ou d'erreur en fonction du retour de create_and_execute_temp_script
    if [ $? -eq 0 ]; then
      echo_msgbox "$msg_uninstall_success"
    else
      echo_msgbox "$msg_uninstall_script_error"
      return 1
    fi

    # Si l'utilisateur a choisi de supprimer les données, images, etc., supprimer les répertoires
    if [ $exit_status -eq 0 ]; then
      if ! sudo rm -rf /var/lib/docker; then
        debug "sudo rm -rf /var/lib/docker error"
      fi
      if ! sudo rm -rf /var/lib/containerd; then
        debug "sudo rm -rf /var/lib/containerd error"
      fi
      if ! sudo apt-get autoremove -y; then
        debug "sudo apt-get autoremove -y error"
      fi

      echo_msgbox "$msg_data_deleted"
    else
      echo_msgbox "$msg_data_kept"
    fi
  fi
  
}

# Fonction pour installer et configurer Fail2Ban
# Function to install and configure Fail2Ban
function menu_4_system_tools_fail2ban() {

  # Définir les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_ask_banaction="Action à entreprendre après le nombre maximal de tentatives :"
    local msg_ask_bantime="Durée de l'interdiction en secondes : \n(par défaut 600)"
    local msg_ask_findtime="Fenêtre de temps pour les tentatives échouées en secondes : \n(par défaut 600)"
    local msg_ask_maxretry="Nombre de tentatives échouées avant l'interdiction : \n(par défaut 3)"
    local msg_ask_usedns="Utiliser le DNS inversé oui/non : \n(par défaut non)"
    local msg_ask_ignoreip="Adresses IP à ignorer (séparées par des espaces) : \n(par défaut 127.0.0.1/8 ::1)"
    local msg_banaction_iptables_multiport="Bannir l'IP sur plusieurs ports spécifiés (iptables-multiport)"
    local msg_banaction_iptables_allports="Bannir l'IP sur tous les ports (iptables-allports)"
    local msg_banaction_nftables="Bloque l'IP avec nftables plus récent (nftables)"
    local msg_banaction_route="Bloque l'IP en la redirigeant vers une route 'null' (route)"
    local msg_banaction_ufw="Bannir les IP avec UFW (ufw)"
    local msg_banaction_ufw_allports="Bannir les IP sur tous les ports avec UFW (ufw-allports)"
    local msg_button_ok="Valider"
    local msg_button_cancel="Annuler"
    local msg_config_error="Erreur lors de la configuration de Fail2Ban."
    local msg_config_prompt="Veuillez configurer Fail2Ban :"
    local msg_config_success="Configuration de Fail2Ban réussie."
    local msg_config_title="Configuration de Fail2Ban"
    local msg_install="Installation"
    local msg_install_error="Erreur lors de l'installation de Fail2Ban."
    local msg_install_success="Fail2Ban a été installé avec succès."
    local msg_not_installed_cancel="Fail2Ban n'est pas installé, désinstallation annulée."
    local msg_tool_type="l'outil système"
    local msg_uninstall="Désinstallation"
    local msg_uninstall_error="Erreur lors de la désinstallation de Fail2Ban."
    local msg_uninstall_success="Fail2Ban a été désinstallé avec succès."
    local msg_usedns_default="non"
    local msg_yet_installed="Fail2Ban est déjà installé."
  else
    local msg_ask_banaction="Action to take after max retries:"
    local msg_ask_bantime="Ban time duration in seconds : \n(default 600)"
    local msg_ask_findtime="Time window for failed attempts in seconds : \n(default 600)"
    local msg_ask_maxretry="Number of failed attempts before banning : \n(default 3)"
    local msg_ask_usedns="Use reverse DNS yes/no : \n(default no)"
    local msg_ask_ignoreip="IP addresses to ignore (separated by spaces) : \n(default 127.0.0.1/8 ::1)"
    local msg_banaction_iptables_multiport="Ban IP on specified multiple ports (iptables-multiport)"
    local msg_banaction_iptables_allports="Ban IP on all ports (iptables-allports)"
    local msg_banaction_nftables="Block IP with nftables more recent (nftables)"
    local msg_banaction_route="Block IP by redirecting to a 'null' route"
    local msg_banaction_ufw="Ban IP using UFW (ufw)"
    local msg_banaction_ufw_allports="Ban IP on all ports using UFW (ufw-allports)"
    local msg_button_cancel="Cancel"
    local msg_button_ok="Validate"
    local msg_config_error="Error configuring Fail2Ban."
    local msg_config_prompt="Please configure Fail2Ban:"
    local msg_config_success="Fail2Ban configuration successful."
    local msg_config_title="Fail2Ban Configuration"
    local msg_install="Install"
    local msg_install_error="Error installing Fail2Ban."
    local msg_install_success="Fail2Ban has been installed successfully."
    local msg_not_installed_cancel="Fail2Ban is not installed, uninstall canceled."
    local msg_tool_type="the system tool"
    local msg_uninstall="Uninstall"
    local msg_uninstall_error="Error uninstalling Fail2Ban."
    local msg_uninstall_success="Fail2Ban has been uninstalled successfully."
    local msg_usedns_default="no"
    local msg_yet_installed="Fail2Ban is already installed."
  fi

  # Appeler la fonction pour afficher le menu de gestion des actions
  menu_0_main_menu_action "$msg_tool_type" "Fail2Ban"

  # Vérifier si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" == "A" ]; then
    return 0
  fi

  # Si l'utilisateur choisit d'installer Fail2Ban
  if [ "$G_CHOICE" == "I" ]; then

    # Vérifier si Fail2Ban n'est pas installé
    if [[ ! $(dpkg -s fail2ban 2>/dev/null | grep "Status:" | awk '{print $2}') =~ ^(install|installed)$ ]]; then

      # Affiche dans le terminal le début du traitement
      echo_process_start "Fail2Ban"

      # Mettre à jour la liste des paquets
      echo_step_start "$msg_install"
      if sudo apt-get update -y -qq > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_install"
      else
        echo_step_end_with_error "$msg_install"
      fi
      
      # Installer Fail2Ban
      echo_step_start "$msg_install"
      if sudo apt-get install -y -qq fail2ban > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_install"
      else
        echo_step_end_with_error "$msg_install"
      fi
      
      # Affiche dans le terminal le début du traitement
      echo_process_stop "Fail2Ban"

      # Vérifier si l'installation a réussi
      if [ $? -eq 0 ]; then
        # Afficher un message de succès
        echo_msgbox "$msg_install_success"
      else
        # Afficher un message d'erreur
        echo_msgbox "$msg_install_error"
        return 1
      fi
    else
      # Afficher un message indiquant que Fail2Ban est déjà installé
      echo_msgbox "$msg_yet_installed"
    fi

    # Demander à l'utilisateur de configurer la durée de l'interdiction
    local bantime
    while true; do
      bantime=$(whiptail --inputbox "\n$msg_ask_bantime" 15 70 "600" --fb --title "$msg_config_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
      local exit_status=$?
      # Si l'utilisateur annule, quitter la fonction
      if [ $exit_status -ne 0 ]; then
        return 1
      fi
      # Si la valeur entrée est un nombre valide, quitter la boucle
      if [[ "$bantime" =~ ^[0-9]+$ ]]; then
        break
      fi
    done

    # Demander à l'utilisateur de configurer le nombre de tentatives échouées avant l'interdiction
    local maxretry
    while true; do
      maxretry=$(whiptail --inputbox "\n$msg_ask_maxretry" 15 70 "3" --fb --title "$msg_config_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
      local exit_status=$?
      # Si l'utilisateur annule, quitter la fonction
      if [ $exit_status -ne 0 ]; then
        return 1
      fi
      # Si la valeur entrée est un nombre valide, quitter la boucle
      if [[ "$maxretry" =~ ^[0-9]+$ ]]; then
        break
      fi
    done

    # Demander à l'utilisateur de configurer la fenêtre de temps pour les tentatives échouées
    local findtime
    while true; do
      findtime=$(whiptail --inputbox "\n$msg_ask_findtime" 15 70 "600" --fb --title "$msg_config_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
      local exit_status=$?
      # Si l'utilisateur annule, quitter la fonction
      if [ $exit_status -ne 0 ]; then
        return 1
      fi
      # Si la valeur entrée est un nombre valide, quitter la boucle
      if [[ "$findtime" =~ ^[0-9]+$ ]]; then
        break
      fi
    done

    # Demander à l'utilisateur de configurer l'action à entreprendre après le nombre maximal de tentatives
    local banaction
    while true; do
      banaction=$(whiptail --radiolist "\n$msg_ask_banaction" 20 75 6 \
        "iptables-multiport" "$msg_banaction_iptables_multiport" ON \
        "iptables-allports" "$msg_banaction_iptables_allports" OFF \
        "nftables" "$msg_banaction_nftables" OFF \
        "route" "$msg_banaction_route" OFF \
        "ufw" "$msg_banaction_ufw" OFF \
        "ufw-allports" "$msg_banaction_ufw_allports" OFF \
        --fb --title "$G_TITLE - Fail2Ban "  --notags --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel"  3>&1 1>&2 2>&3)
      local exit_status=$?
      # Si l'utilisateur annule, quitter la fonction
      if [ $exit_status -ne 0 ]; then
        return 1
      fi
      # Si une action est sélectionnée, quitter la boucle
      if [[ -n "$banaction" ]]; then
        # Supprimer les guillemets autour de l'action sélectionnée
        banaction=$(echo "$banaction" | tr -d '"')
        break
      fi
    done

    # Demander à l'utilisateur s'il veut utiliser le DNS inversé
    local usedns
    while true; do
      usedns=$(whiptail --inputbox "\n$msg_ask_usedns" 15 70 "$msg_usedns_default" --fb --title "$msg_config_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
      local exit_status=$?
      # Si l'utilisateur annule, quitter la fonction
      if [ $exit_status -ne 0 ]; then
        return 1
      fi
      # Si la valeur entrée est valide, quitter la boucle
      if [[ "$usedns" == "yes" || "$usedns" == "oui" ]]; then
        usedns="yes"
        break
      elif [[ "$usedns" == "no" || "$usedns" == "non" ]]; then
        usedns="no"
        break
      fi
    done

    # Demander à l'utilisateur de configurer les adresses IP à ignorer
    local ignoreip
    while true; do
      ignoreip=$(whiptail --inputbox "\n$msg_ask_ignoreip" 15 70 "127.0.0.1/8 ::1" --fb --title "$msg_config_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
      local exit_status=$?
      # Si l'utilisateur annule, quitter la fonction
      if [ $exit_status -ne 0 ]; then
        return 1
      fi
      # Si la valeur entrée est valide, quitter la boucle
      if [[ -n "$ignoreip" ]]; then
        break
      fi
    done

    # Copier le fichier de configuration par défaut vers le fichier de configuration local
    sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

    # Modifier les paramètres de configuration dans le fichier de configuration local
    sudo sed -i "s/^bantime *=.*/bantime = $bantime/" /etc/fail2ban/jail.local
    sudo sed -i "s/^maxretry *=.*/maxretry = $maxretry/" /etc/fail2ban/jail.local
    sudo sed -i "s/^findtime *=.*/findtime = $findtime/" /etc/fail2ban/jail.local
    sudo sed -i "s/^banaction *=.*/banaction = $banaction/" /etc/fail2ban/jail.local
    sudo sed -i "s/^ignoreip *=.*/ignoreip = $ignoreip/" /etc/fail2ban/jail.local
    sudo sed -i "s/^usedns *=.*/usedns = $usedns/" /etc/fail2ban/jail.local

    # Configurer la section [sshd] si le service est installé
    if command -v sshd &> /dev/null; then
      sudo sed -i 's/^\[sshd\]/[sshd]\nenabled = true/' /etc/fail2ban/jail.local
      sudo sed -i "s/^\[sshd\]\s*$/[sshd]\nenabled = true\nbantime = $bantime\nfindtime = $findtime\nmaxretry = $maxretry/" /etc/fail2ban/jail.local
    fi

    # Configurer la section [apache] si le service est installé
    if command -v apache2 &> /dev/null; then
      sudo sed -i 's/^\[apache\]/[apache]\nenabled = true/' /etc/fail2ban/jail.local
      sudo sed -i "s/^\[apache\]\s*$/[apache]\nenabled = true\nbantime = $bantime\nfindtime = $findtime\nmaxretry = $maxretry/" /etc/fail2ban/jail.local
    fi

    # Configurer la section [nginx-http-auth] si le service est installé
    if command -v nginx &> /dev/null; then
      sudo sed -i 's/^\[nginx-http-auth\]/[nginx-http-auth]\nenabled = true/' /etc/fail2ban/jail.local
      sudo sed -i "s/^\[nginx-http-auth\]\s*$/[nginx-http-auth]\nenabled = true\nbantime = $bantime\nfindtime = $findtime\nmaxretry = $maxretry/" /etc/fail2ban/jail.local
    fi

    # Configurer la section [mysqld-auth] si le service est installé
    if command -v mysqld &> /dev/null; then
      sudo sed -i 's/^\[mysqld-auth\]/[mysqld-auth]\nenabled = true/' /etc/fail2ban/jail.local
      sudo sed -i "s/^\[mysqld-auth\]\s*$/[mysqld-auth]\nenabled = true\nbantime = $bantime\nfindtime = $findtime\nmaxretry = $maxretry/" /etc/fail2ban/jail.local
    fi

    # Configurer la section [recidive] si le service est installé
    sudo sed -i 's/^\[recidive\]/[recidive]\nenabled = true/' /etc/fail2ban/jail.local
    sudo sed -i "s/^\[recidive\]\s*$/[recidive]\nenabled = true\nbantime = $bantime\nfindtime = $findtime\nmaxretry = $maxretry/" /etc/fail2ban/jail.local

    # Redémarrer le service Fail2Ban
    sudo systemctl restart fail2ban

    # Vérifier si le redémarrage a réussi
    if [ $? -eq 0 ]; then
      # Afficher un message de succès
      echo_msgbox "\n$msg_config_success"
    else
      # Afficher un message d'erreur
      echo_msgbox "\n$msg_config_error"
      return 1
    fi
  fi

  # Si l'utilisateur choisit de désinstaller Fail2Ban
  if [ "$G_CHOICE" == "D" ]; then

    # Vérifier si Fail2Ban est installé
    if [[ $(dpkg -s fail2ban 2>/dev/null | grep "Status:" | awk '{print $2}') =~ ^(install|installed)$ ]]; then
    
      # Affiche dans le terminal le début du traitement
      echo_process_start "Fail2Ban"
      
      # Arrêter le service Fail2Ban
      sudo systemctl stop fail2ban

      # Supprimer les fichiers de configuration personnalisés
      sudo rm -f /etc/fail2ban/jail.local

      # Restaurer le fichier de configuration par défaut
      sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
      
      # Désinstaller Fail2Ban
      echo_step_start "$msg_uninstall"
      if sudo apt-get remove -y -qq fail2ban > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_uninstall"
      else
        echo_step_end_with_error "$msg_uninstall"
      fi
      
      # Affiche dans le terminal le début du traitement
      echo_process_stop "Fail2Ban"

      # Vérifier si la désinstallation a réussi
      if [ $? -eq 0 ]; then
        # Afficher un message de succès
        echo_msgbox "$msg_uninstall_success"
      else
        # Afficher un message d'erreur
        echo_msgbox "$msg_uninstall_error"
        return 1
      fi
    else
      # Afficher un message indiquant que Fail2Ban n'est pas installé
      echo_msgbox "$msg_not_installed_cancel"
    fi

  fi

}

# Fonction pour installer et désinstaller Midnight-Commander
# Function to install and uninstall Midnight-Commander
function menu_4_system_tools_mc() {

  # Définir les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_no="Non"
    local msg_button_yes="Oui"
    local msg_install="Installation"
    local msg_install_error="Erreur lors de l'installation de Midnight-Commander."
    local msg_install_success="Midnight-Commander a été installé avec succès."
    local msg_launch_prompt="Voulez-vous lancer Midnight-Commander maintenant ?"
    local msg_not_installed_cancel="Midnight-Commander n'est pas installé, désinstallation annulée."
    local msg_tool_type="l'outil système"
    local msg_uninstall="Désinstallation"
    local msg_uninstall_error="Erreur lors de la désinstallation de Midnight-Commander."
    local msg_uninstall_success="Midnight-Commander a été désinstallé avec succès."
    local msg_yet_installed="Midnight-Commander est déjà installé."
  else
    local msg_button_no="No"
    local msg_button_yes="Yes"
    local msg_install="Install"
    local msg_install_error="Error installing Midnight-Commander."
    local msg_install_success="Midnight-Commander has been installed successfully."
    local msg_launch_prompt="Do you want to launch Midnight-Commander now?"
    local msg_not_installed_cancel="Midnight-Commander is not installed, uninstall canceled."
    local msg_tool_type="the system tool"
    local msg_uninstall="Uninstall"
    local msg_uninstall_error="Error uninstalling Midnight-Commander."
    local msg_uninstall_success="Midnight-Commander has been uninstalled successfully."
    local msg_yet_installed="Midnight-Commander is already installed."
  fi

  # Appeler la fonction pour afficher le menu de gestion des actions
  menu_0_main_menu_action "$msg_tool_type" "Midnight-Commander"

  # Vérifier si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" == "A" ]; then
    return 0
  fi

  # Si l'utilisateur choisit d'installer Midnight-Commander
  if [ "$G_CHOICE" == "I" ]; then
    
    # Vérifier si Midnight-Commander est pas installé
    if ! eval "${G_SYSTEM_TOOL_CHECK["Midnight-Commander"]}"; then
    
      # Affiche dans le terminal le début du traitement
      echo_process_start "Midnight-Commander"
  
      # Mettre à jour la liste des paquets
      echo_step_start "$msg_install"
      if sudo apt-get update -y -qq > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_install"
      else
        echo_step_end_with_error "$msg_install"
      fi
      
      # Installer Midnight-Commander
      echo_step_start "$msg_install"
      if sudo apt-get install -y -qq mc > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_install"
      else
        echo_step_end_with_error "$msg_install"
      fi

      # Affiche dans le terminal le début du traitement
      echo_process_stop "Midnight-Commander"

      # Vérifier si l'installation a réussi
      if [ $? -eq 0 ]; then
        # Afficher un message de succès
        echo_msgbox "$msg_install_success"
        # Demander à l'utilisateur s'il veut lancer Midnight-Commander
        whiptail --yesno "$msg_launch_prompt" 15 70 --fb --title "$G_TITLE" --yes-button "$msg_button_yes" --no-button "$msg_button_no"
        if [ $? -eq 0 ]; then
          # Lancer Midnight-Commander
          mc
        fi
      else
        # Afficher un message d'erreur
        echo_msgbox "$msg_install_error"
        return 1
      fi
    else
      # Afficher un message indiquant que Midnight-Commander est déjà installé
      echo_msgbox "$msg_yet_installed"
    fi
  fi

  # Si l'utilisateur choisit de désinstaller Midnight-Commander
  if [ "$G_CHOICE" == "D" ]; then
  
    # Vérifier si Midnight-Commander est installé
    if eval "${G_SYSTEM_TOOL_CHECK["Midnight-Commander"]}"; then
    
      # Affiche dans le terminal le début du traitement
      echo_process_start "Midnight-Commander"

      # Désinstaller Midnight-Commander
      echo_step_start "$msg_uninstall"
      if sudo apt-get remove -y -qq mc > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_uninstall"
      else
        echo_step_end_with_error "$msg_uninstall"
      fi

      # Affiche dans le terminal le début du traitement
      echo_process_stop "Midnight-Commander"

      # Vérifier si la désinstallation a réussi
      if [ $? -eq 0 ]; then
        # Afficher un message de succès
        echo_msgbox "$msg_uninstall_success"
      else
        # Afficher un message d'erreur
        echo_msgbox "$msg_uninstall_error"
        return 1
      fi
    else
      # Afficher un message indiquant que Midnight-Commander n'est pas installé
      echo_msgbox "$msg_not_installed_cancel"
    fi
  fi

}

# Fonction pour installer et configurer un serveur NTP
# Function to install and configure an NTP server
function menu_4_system_tools_ntp_server() {

  # Définir les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_backup_error="Erreur : Impossible de sauvegarder /etc/ntp.conf."
    local msg_backup_success="La configuration NTP a été restaurée à partir de la sauvegarde."
    local msg_button_cancel="Annuler"
    local msg_button_ok="Valider"
    local msg_config_error="Erreur lors de la configuration du serveur NTP."
    local msg_config_success="Configuration du serveur NTP réussie."
    local msg_install="Installation"
    local msg_install_error="Erreur lors de l'installation de NTP."
    local msg_install_success="NTP a été installé avec succès."
    local msg_modify_port_error="Erreur : Impossible de modifier le port NTP dans /etc/ntp.conf."
    local msg_modify_server_error="Erreur : Impossible de modifier le serveur NTP dans /etc/ntp.conf."
    local msg_no_backup="Erreur : Aucune sauvegarde trouvée pour /etc/ntp.conf."
    local msg_not_installed_cancel="NTP n'est pas installé, désinstallation annulée."
    local msg_ntp_conf_create_error="Erreur : Impossible de créer /etc/ntp.conf."
    local msg_ntp_conf_created="Le fichier /etc/ntp.conf a été créé avec une configuration par défaut."
    local msg_ntp_conf_missing="Erreur : Le fichier /etc/ntp.conf n'existe pas. Souhaitez-vous le créer avec une configuration par défaut ?"
    local msg_port_prompt="Entrez le port sur lequel les appareils se synchroniseront : \n(défaut: 123)"
    local msg_port_range="Le port doit être un nombre entre 1 et 65535."
    local msg_restart_error="Erreur : Impossible de redémarrer le service NTP."
    local msg_restore_error="Erreur : Impossible de restaurer /etc/ntp.conf à partir de la sauvegarde."
    local msg_restrict_network_prompt="Entrez le réseau local à autoriser (ex: 192.168.1.0/24) :"
    local msg_server_prompt="Entrez le serveur NTP à utiliser (par défaut: fr.pool.ntp.org):"
    local msg_tool_type="l'outil système"
    local msg_uninstall="Désinstallation"
    local msg_uninstall_error="Erreur lors de la désinstallation de NTP."
    local msg_uninstall_success="NTP a été désinstallé avec succès."
    local msg_yet_installed="NTP est déjà installé."
  else
    local msg_backup_error="Error: Unable to backup /etc/ntp.conf."
    local msg_backup_success="NTP configuration has been restored from backup."
    local msg_button_cancel="Cancel"
    local msg_button_ok="Validate"
    local msg_config_error="Error configuring NTP server."
    local msg_config_success="NTP server configuration successful."
    local msg_install="Install"
    local msg_install_error="Error installing NTP."
    local msg_install_success="NTP has been installed successfully."
    local msg_modify_port_error="Error: Unable to modify NTP port in /etc/ntp.conf."
    local msg_modify_server_error="Error: Unable to modify NTP server in /etc/ntp.conf."
    local msg_no_backup="Error: No backup found for /etc/ntp.conf."
    local msg_not_installed_cancel="NTP is not installed, uninstall canceled."
    local msg_ntp_conf_create_error="Error: Unable to create /etc/ntp.conf."
    local msg_ntp_conf_created="The file /etc/ntp.conf has been created with a default configuration."
    local msg_ntp_conf_missing="Error: The file /etc/ntp.conf does not exist. Do you want to create it with a default configuration?"
    local msg_port_prompt="Enter the port on which devices will synchronize : \n(default: 123)"
    local msg_port_range="The port must be a number between 1 and 65535."
    local msg_restart_error="Error: Unable to restart NTP service."
    local msg_restore_error="Error: Unable to restore /etc/ntp.conf from backup."
    local msg_restrict_network_prompt="Enter the local network to allow (ex: 192.168.1.0/24):"
    local msg_server_prompt="Enter the NTP server to use (default: fr.pool.ntp.org):"
    local msg_tool_type="the system tool"
    local msg_uninstall="Uninstall"
    local msg_uninstall_error="Error uninstalling NTP."
    local msg_uninstall_success="NTP has been uninstalled successfully."
    local msg_yet_installed="NTP is already installed."
  fi

  # Appeler la fonction pour afficher le menu de gestion des actions
  menu_0_main_menu_action "$msg_tool_type" "Ntp-Server"

  # Vérifier si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" == "A" ]; then
    return 0
  fi

  # Si l'utilisateur choisit d'installer NTP
  if [ "$G_CHOICE" == "I" ]; then
    # Vérifier si NTP est déjà installé
    if ! dpkg-query -W -f='${Status}' ntp 2>/dev/null | grep -q "install ok installed"; then

      # Affiche dans le terminal le début du traitement
      echo_process_start "Ntp-Server"
      
      # Mettre à jour la liste des paquets
      echo_step_start "$msg_install"
      if sudo apt-get update -y -qq > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_install"
      else
        echo_step_end_with_error "$msg_install"
      fi

      # Installer NTP
      echo_step_start "$msg_install"
      if sudo apt-get install -y -qq ntp > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_install"
      else
        echo_step_end_with_error "$msg_install"
      fi

      # Affiche dans le terminal le début du traitement
      echo_process_stop "Ntp-Server"
      
      # Vérifier si l'installation a réussi
      if [ $? -eq 0 ]; then
        # Afficher un message de succès
        echo_msgbox "$msg_install_success"
      else
        # Afficher un message d'erreur
        echo_msgbox "$msg_install_error"
        return 1
      fi
    else
      # Afficher un message indiquant que NTP est déjà installé
      echo_msgbox "$msg_yet_installed"
    fi

    # Vérifier si le fichier /etc/ntp.conf existe
    if [ ! -f "/etc/ntp.conf" ]; then
      # Demander à l'utilisateur s'il veut créer le fichier
      if whiptail --yesno "$msg_ntp_conf_missing" 15 70 --fb --title "$G_TITLE" --yes-button "$msg_button_ok" --no-button "$msg_button_cancel"; then
        # Demander le réseau local à autoriser
        local restrict_network
        restrict_network=$(whiptail --inputbox "\n$msg_restrict_network_prompt" 12 70 "192.168.1.0/24" --fb --title "$G_TITLE" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
        local exit_status=$?
        if [ $exit_status -ne 0 ]; then
          return 1
        fi

        # Créer le fichier /etc/ntp.conf avec une configuration par défaut
        sudo bash -c "cat > /etc/ntp.conf <<EOF
# Fichier de configuration NTP
driftfile /var/lib/ntp/ntp.drift
logfile /var/log/ntp.log

# Serveurs NTP français
server 0.fr.pool.ntp.org
server 1.fr.pool.ntp.org
server 2.fr.pool.ntp.org
server 3.fr.pool.ntp.org

# Restriction d'accès réseau
restrict default nomodify notrap nopeer noquery
restrict 127.0.0.1
restrict $restrict_network mask 255.255.255.0 nomodify notrap
EOF"
        if [ $? -eq 0 ]; then
          echo_msgbox "$msg_ntp_conf_created"
        else
          echo_msgbox "$msg_ntp_conf_create_error"
          return 1
        fi
      else
        return 1
      fi
    fi

    # Boucler jusqu'à ce qu'un serveur NTP valide soit entré ou que l'utilisateur annule
    while true; do
      local sntp_server="fr.pool.ntp.org"
      local choice_sntp_server
      choice_sntp_server=$(whiptail --inputbox "\n$msg_server_prompt" 12 70 "$sntp_server" --fb --title "$G_TITLE" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
      local exit_status=$?
      if [ $exit_status -ne 0 ]; then
        return 1
      fi
      if [ -z "$choice_sntp_server" ]; then
        sntp_server="fr.pool.ntp.org"
      else
        sntp_server="$choice_sntp_server"
      fi
      break
    done

    # Boucler jusqu'à ce qu'un port valide soit entré ou que l'utilisateur annule
    while true; do
      local sntp_port="123"
      sntp_port=$(whiptail --inputbox "\n$msg_port_prompt" 12 70 "123" --fb --title "$G_TITLE" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
      local exit_status=$?
      if [ $exit_status -ne 0 ]; then
        return 1
      fi
      if [ -z "$sntp_port" ]; then
        sntp_port="123"
      fi
      if network_validate_port "$sntp_port"; then
        break
      else
        echo_msgbox "$msg_port_range"
      fi
    done

    # Sauvegarder le fichier de configuration original
    if [ -f "/etc/ntp.conf" ]; then
      sudo cp /etc/ntp.conf /etc/ntp.conf.bak
      if [ $? -ne 0 ]; then
        echo_msgbox "$msg_backup_error"
        return 1
      fi
    fi

    # Modifier le fichier de configuration NTP
    sudo sed -i "s/^pool .*/server $sntp_server/" /etc/ntp.conf
    if [ $? -ne 0 ]; then
      
      echo_msgbox "$msg_modify_server_error" "$G_TITLE"
      
      # Restaurer la sauvegarde en cas d'échec
      if [ -f "/etc/ntp.conf.bak" ]; then
        sudo cp /etc/ntp.conf.bak /etc/ntp.conf
        if [ $? -eq 0 ]; then
          echo_msgbox "$msg_backup_success"
        else
          echo_msgbox "$msg_restore_error"
        fi
      else
        echo_msgbox "$msg_no_backup"
      fi
      return 1
    fi

    sudo sed -i "s/^port .*/port $sntp_port/" /etc/ntp.conf
    if [ $? -ne 0 ]; then
      
      echo_msgbox "$msg_modify_port_error" "$G_TITLE"
      
      # Restaurer la sauvegarde en cas d'échec
      if [ -f "/etc/ntp.conf.bak" ]; then
        sudo cp /etc/ntp.conf.bak /etc/ntp.conf
        if [ $? -eq 0 ]; then
          echo_msgbox "$msg_backup_success"
        else
          echo_msgbox "$msg_restore_error"
        fi
      else
        echo_msgbox "$msg_no_backup"
      fi
      return 1
    fi

    # Afficher un message de succès
    echo_msgbox "$msg_config_success"

    # Redémarrer le service NTP
    sudo systemctl restart ntp
    if [ $? -ne 0 ]; then
      echo_msgbox "$msg_restart_error"
    fi
  fi

  # Si l'utilisateur choisit de désinstaller NTP
  if [ "$G_CHOICE" == "D" ]; then
  
    # Vérifier si NTP est installé
    if dpkg-query -W -f='${Status}' ntp 2>/dev/null | grep -q "install ok installed"; then
      
      # Affiche dans le terminal le début du traitement
      echo_process_start "Ntp-Server"
  
      # Arrêter le service NTP
      sudo systemctl stop ntp
    
      # Restaurer le fichier de configuration original
      if [ -f "/etc/ntp.conf.bak" ]; then
        sudo cp /etc/ntp.conf.bak /etc/ntp.conf
      fi

      # Désinstaller NTP
      echo_step_start "$msg_uninstall"
      if sudo apt-get remove -y -qq ntp > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_uninstall"
      else
        echo_step_end_with_error "$msg_uninstall"
      fi

      # Supprimer les dépendances inutilisées
      sudo apt-get autoremove -y -qq

      # Affiche dans le terminal la fin du traitement
      echo_process_stop "Ntp-Server"

      # Vérifier si la désinstallation a réussi
      if [ $? -eq 0 ]; then
        # Afficher un message de succès
        echo_msgbox "$msg_uninstall_success"
      else
        # Afficher un message d'erreur
        echo_msgbox "$msg_uninstall_error"
        return 1
      fi
    else
      # Afficher un message indiquant que NTP n'est pas installé
      echo_msgbox "$msg_not_installed_cancel"
    fi
  fi

}

# Fonction pour installer et désinstaller OpenSSH Server
# Function to install and uninstall OpenSSH Server
function menu_4_system_tools_openssh_server() {

  # Définir les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
		local msg_button_cancel="Retour"
		local msg_button_no="Non"
		local msg_button_ok="Suivant"
		local msg_button_yes="Oui"
    local msg_config_error="Erreur lors de la configuration d'OpenSSH."
    local msg_config_success="Configuration d'OpenSSH réussie."
    local msg_install="Installation"
    local msg_install_error="Erreur lors de l'installation d'OpenSSH."
    local msg_install_success="OpenSSH a été installé avec succès."
    local msg_not_installed_cancel="OpenSSH n'est pas installé, désinstallation annulée."
    local msg_port_invalid="Le port doit être un nombre entre 1 et 65535."
    local msg_port_prompt="Entrez le port sur lequel OpenSSH doit écouter :"
    local msg_tool_type="l'outil système"
    local msg_uninstall="Désinstallation"
    local msg_uninstall_error="Erreur lors de la désinstallation d'OpenSSH."
    local msg_uninstall_success="OpenSSH a été désinstallé avec succès."
    local msg_users_prompt="Sélectionnez les utilisateurs autorisés à se connecter à OpenSSH :"
    local msg_users_success="Seuls les utilisateurs sélectionnés sont désormais autorisés à se connecter à OpenSSH :"
    local msg_yet_installed="OpenSSH est déjà installé."
  else
 		local msg_button_cancel="Back"
		local msg_button_no="No"
		local msg_button_ok="Next"
		local msg_button_yes="Yes"
    local msg_config_error="Error configuring OpenSSH."
    local msg_config_success="OpenSSH configuration successful."
    local msg_install="Install"
    local msg_install_error="Error installing OpenSSH."
    local msg_install_success="OpenSSH has been installed successfully."
    local msg_not_installed_cancel="OpenSSH is not installed, uninstall canceled."
    local msg_port_invalid="The port must be a number between 1 and 65535."
    local msg_port_prompt="Enter the port on which OpenSSH should listen:"
    local msg_tool_type="the system tool"
    local msg_uninstall="Uninstall"
    local msg_uninstall_error="Error uninstalling OpenSSH."
    local msg_uninstall_success="OpenSSH has been uninstalled successfully."
    local msg_users_prompt="Select the users allowed to connect to OpenSSH:"
    local msg_users_success="Only the selected users are now allowed to connect to OpenSSH:"
    local msg_yet_installed="OpenSSH is already installed."
  fi

  # Appeler la fonction pour afficher le menu de gestion des actions
  menu_0_main_menu_action "$msg_tool_type" "OpenSSH-Server"

  # Vérifier si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" == "A" ]; then
    return 0
  fi

  # Si l'utilisateur choisit d'installer OpenSSH
  if [ "$G_CHOICE" == "I" ]; then

    # Vérifier si OpenSSH est pas déjà installé
    # apt-cache policy openssh-server
    if ! dpkg-query -W -f='${Status}' ssh 2>/dev/null | grep -q "install ok installed"; then

      # Affiche dans le terminal le début du traitement
      echo_process_start "OpenSSH-Server"
  
      # Mettre à jour la liste des paquets
      echo_step_start "$msg_install"
      if sudo apt-get update -y -qq > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_install"
      else
        echo_step_end_with_error "$msg_install"
      fi

      # Installer OpenSSH-Server
      echo_step_start "$msg_install"
      if sudo apt-get install -y -qq openssh-server > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_install"
      else
        echo_step_end_with_error "$msg_install"
      fi

      # Affiche dans le terminal la fin du traitement
      echo_process_stop "OpenSSH-Server"

      # Vérifier si l'installation a réussi
      if [ $? -eq 0 ]; then
        # Afficher un message de succès
        echo_msgbox "$msg_install_success"
      else
        # Afficher un message d'erreur
        echo_msgbox "$msg_install_error"
        return 1
      fi
    else
      # Afficher un message indiquant qu'OpenSSH est déjà installé
      echo_msgbox "$msg_yet_installed"
    fi

    # Boucler jusqu'à ce qu'un port valide soit entré ou que l'utilisateur annule
    while true; do
      local ssh_port
      ssh_port=$(whiptail --inputbox "\n$msg_port_prompt" 20 70 22 --fb --title "$G_TITLE" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
      local exit_status=$?
      if [ $exit_status -ne 0 ]; then
        return 1
      fi

      # Vérifier si le port est valide
      if [[ "$ssh_port" =~ ^[0-9]+$ ]] && [ "$ssh_port" -ge 1 ] && [ "$ssh_port" -le 65535 ]; then
        break
      else
        echo_msgbox "$msg_port_invalid"
      fi
    done

    # Modifier le port dans le fichier de configuration SSH
    sudo sed -i "s/^#*Port .*/Port $ssh_port/" /etc/ssh/sshd_config
    if [ $? -eq 0 ]; then
      echo_msgbox "$msg_config_success"
    else
      echo_msgbox "$msg_config_error"
      return 1
    fi

    # Redémarrer le service SSH pour appliquer les modifications
    sudo systemctl restart ssh

    # Récupérer la liste des utilisateurs
    local users
    users=$(getent passwd | cut -d: -f1)
    local users_list=()
    while IFS= read -r user; do
      users_list+=("$user" "" "OFF")
    done <<< "$users"

    # Demander à l'utilisateur de sélectionner les utilisateurs autorisés à se connecter à OpenSSH
    local selected_users
    selected_users=$(whiptail --checklist "$msg_users_prompt" 20 75 10 "${users_list[@]}" --fb --title "$G_TITLE" 3>&1 1>&2 2>&3)
    local exit_status=$?

    if [ $exit_status -ne 0 ]; then
      return 1
    fi

    # Formater la liste des utilisateurs sélectionnés
    selected_users=$(echo $selected_users | tr -d '"' | tr ' ' ',')
    sudo sed -i "s/^#*AllowUsers .*/AllowUsers $selected_users/" /etc/ssh/sshd_config
    sudo systemctl restart ssh

    # Afficher un message de succès avec la liste des utilisateurs autorisés
    echo_msgbox "$msg_users_success\n$selected_users"
  fi

  # Si l'utilisateur choisit de désinstaller OpenSSH
  if [ "$G_CHOICE" == "D" ]; then

    # Vérifier si OpenSSH est déjà installé
    if is_package_installed "ssh" >/dev/null; then

      # Affiche dans le terminal le début du traitement
      echo_process_start "OpenSSH-Server"
      
      # Arrêter le service SSH
      sudo systemctl stop ssh

      # Restaurer le fichier de configuration par défaut
      sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
      sudo cp /etc/ssh/sshd_config.default /etc/ssh/sshd_config
      
      # Désinstaller OpenSSH Server
      echo_step_start "$msg_uninstall"
      if sudo apt-get remove -y -qq openssh-server > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_uninstall"
      else
        echo_step_end_with_error "$msg_uninstall"
      fi
      
      # Affiche dans le terminal la fin du traitement
      echo_process_stop "OpenSSH-Server"

      # Vérifier si la désinstallation a réussi
      if [ $? -eq 0 ]; then
        # Afficher un message de succès
        echo_msgbox "$msg_uninstall_success"
      else
        # Afficher un message d'erreur
        echo_msgbox "$msg_uninstall_error"
        return 1
      fi
    else
      # Afficher un message indiquant qu'OpenSSH n'est pas installé
      echo_msgbox "$msg_not_installed_cancel"
    fi
  fi

}

# Fonction pour installer, configurer et désinstaller OpenVPN
# Function to install and uninstall OpenVPN
function menu_4_system_tools_openvpn() {

  # Définir les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
		local msg_button_cancel="Retour"
		local msg_button_no="Non"
		local msg_button_ok="Suivant"
		local msg_button_yes="Oui"
    local msg_config_error="Erreur lors de la configuration d'OpenVPN."
    local msg_config_success="Configuration d'OpenVPN réussie."
    local msg_config_title="Configuration d'OpenVPN"
    local msg_install="Installation"
    local msg_install_error="Erreur lors de l'installation d'OpenVPN."
    local msg_install_success="OpenVPN a été installé avec succès."
    local msg_not_installed_cancel="OpenVPN n'est pas installé, désinstallation annulée."
    local msg_port_prompt="Entrez le port pour OpenVPN (par défaut : 1194) :"
    local msg_proto_prompt="Choisissez le protocole (UDP ou TCP) :"
    local msg_tool_type="l'outil système"
    local msg_ufw_not_installed="Attention, UFW n'est pas installé, les règles pour OpenVPN n'ont pas été appliquées !"
    local msg_uninstall="Désinstallation"
    local msg_uninstall_error="Erreur lors de la désinstallation d'OpenVPN."
    local msg_uninstall_success="OpenVPN a été désinstallé avec succès."
    local msg_yet_installed="OpenVPN est déjà installé."
  else
 		local msg_button_cancel="Back"
		local msg_button_no="No"
		local msg_button_ok="Next"
		local msg_button_yes="Yes"
    local msg_config_error="Error configuring OpenVPN."
    local msg_config_success="OpenVPN configuration successful."
    local msg_config_title="OpenVPN Configuration"
    local msg_install="Install"
    local msg_install_error="Error installing OpenVPN."
    local msg_install_success="OpenVPN has been installed successfully."
    local msg_not_installed_cancel="OpenVPN is not installed, uninstall canceled."
    local msg_port_prompt="Enter the port for OpenVPN (default: 1194):"
    local msg_proto_prompt="Choose the protocol (UDP or TCP):"
    local msg_tool_type="the system tool"
    local msg_ufw_not_installed="Warning: UFW is not installed, the rules for OpenVPN have not been applied!"
    local msg_uninstall="Uninstall"
    local msg_uninstall_error="Error uninstalling OpenVPN."
    local msg_uninstall_success="OpenVPN has been uninstalled successfully."
    local msg_yet_installed="OpenVPN is already installed."
  fi


  # Appeler la fonction pour afficher le menu de gestion des actions
  menu_0_main_menu_action "$msg_tool_type" "OpenVpn"

  # Vérifier si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" = "A" ]; then
    return 0
  fi

  # Si l'utilisateur choisit d'installer OpenVPN
  if [ "$G_CHOICE" = "I" ]; then

    # Vérifier si OpenVPN est déjà installé
    if ! command -v openvpn &> /dev/null; then

      # Affiche dans le terminal le début du traitement
      echo_process_start "OpenVpn"

      # Mettre à jour la liste des paquets
      echo_step_start "$msg_install"
      if sudo apt-get update -y -qq > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_install"
      else
        echo_step_end_with_error "$msg_install"
      fi
  
      # Installer OpenVPN et easy-rsa
      echo_step_start "$msg_install"
      if sudo apt-get install -y -qq openvpn easy-rsa > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_install"
      else
        echo_step_end_with_error "$msg_install"
      fi

      # Affiche dans le terminal la fin du traitement
      echo_process_stop "OpenVpn"
      
      # Vérifier si l'installation a réussi
      if [ $? -eq 0 ]; then
        # Afficher un message de succès
        echo_msgbox "$msg_install_success"
      fi
    else
      # Afficher un message indiquant que OpenVpn est déjà installé
      echo_msgbox "$msg_yet_installed"
    fi

    # Configuration du port OpenVPN
    local ovpn_port
    ovpn_port=$(whiptail --inputbox "\n$msg_port_prompt" 15 70 "1194" --fb --title "$msg_config_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
      return 1
    fi

    # Configuration du protocole OpenVPN
    local ovpn_proto
    ovpn_proto=$(whiptail --menu "\n$msg_proto_prompt" 15 70 2 "UDP" "" "TCP" "" --fb --title "$msg_config_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
      return 1
    fi

    # Configuration d'OpenVPN
    echo "port $ovpn_port
proto $ovpn_proto
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
keepalive 10 120
tls-auth ta.key 0
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3" > /etc/openvpn/server.conf

    # Générer les certificats
    mkdir -p /etc/openvpn/easy-rsa
    cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/
    cd /etc/openvpn/easy-rsa/ || return
    ./easyrsa init-pki
    ./easyrsa build-ca nopass
    ./easyrsa build-server-full server nopass
    ./easyrsa gen-dh
    openvpn --genkey --secret /etc/openvpn/ta.key

    # Activer le transfert IP
    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-openvpn.conf
    sysctl --system

    # Vérifier si UFW est déjà installé
    if ! command -v ufw &> /dev/null; then

      # Appeler la fonction pour installer et configurer UFW
      menu_4_system_tools_ufw

      # Vérifier si l'installation de UFW a réussi
      if command -v ufw &> /dev/null; then
        # Configurer les règles UFW pour OpenVPN
        sudo ufw allow "$ovpn_port/$ovpn_proto"
        sudo ufw allow OpenSSH
        sudo ufw --force enable
      else
        echo_msgbox "$msg_ufw_not_installed"
      fi
    fi

    # Démarrer OpenVPN
    systemctl enable openvpn@server
    systemctl start openvpn@server

    echo_msgbox "$msg_config_success"
  fi

  # Si l'utilisateur choisit de désinstaller OpenVPN
  if [ "$G_CHOICE" = "D" ]; then
  
    # Vérifier si OpenVPN est installé
    if command -v openvpn &> /dev/null; then

      # Affiche dans le terminal le début du traitement
      echo_process_start "OpenVpn"

      # Arrêter et désactiver OpenVPN
      systemctl stop openvpn@server
      systemctl disable openvpn@server

      # Désinstaller OpenVPN
      echo_step_start "$msg_uninstall"
      if sudo apt-get remove -y -qq openvpn easy-rsa > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_uninstall"
      else
        echo_step_end_with_error "$msg_uninstall"
      fi

      # Supprimer les fichiers de configuration
      rm -rf /etc/openvpn
      rm -f /etc/sysctl.d/99-openvpn.conf

      # Supprimer les dépendances inutilisées
      sudo apt-get autoremove -y -qq > /dev/null 2>&1
      
      # Affiche dans le terminal la fin du traitement
      echo_process_stop "OpenVpn"
      
      echo_msgbox "$msg_uninstall_success"
    else
      echo_msgbox "$msg_not_installed_cancel"
    fi
  fi

}

# Fonction pour installer et désinstaller Samba Client
# Fonction pour installer et désinstaller Samba Client
function menu_4_system_tools_smbclient() {

  # Définir les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Annuler"
    local msg_button_ok="Valider"
    local msg_button_no="Non"
    local msg_button_yes="Oui"
    local msg_cancel_ip="Annulation de la saisie de l'adresse IP."
    local msg_cancel_mount_point="Annulation de la saisie du point de montage."
    local msg_cancel_password="Annulation de la saisie du mot de passe."
    local msg_cancel_share="Annulation de la sélection du partage."
    local msg_cancel_username="Annulation de la saisie du nom d'utilisateur."
    local msg_exemple="Pour accéder sur un PC ayant l'ip '192.168.1.130' à un partage windows nommé 'partage-smb' avec les droits pour l'utilisateur 'admin' ayant un password 'pass' sur le point de montage situé sur votre NRX800 dans le répertoire '/home/nrx800/partage-smb' (créé automatiquement s'il n'existe pas) entrez successivement les valeurs suivantes :\n
    Adresse IP du serveur Samba : 192.168.1.130
    Nom d'utilisateur : admin
    Mot de passe : pass
    Nom du partage Samba : partage-smb
    Point de montage local : /home/nrx800/partage-smb"
    local msg_install="Installation"
    local msg_install_error="Erreur lors de l'installation de Samba Client."
    local msg_install_success="Samba Client a été installé avec succès."
    local msg_mount_on="a été monté sur"
    local msg_no_mounted_shares="Aucun partage Samba n'est actuellement monté."
    local msg_no_shares_found="Aucun partage Samba trouvé sur le serveur."
    local msg_not_installed_cancel="Samba Client n'est pas installé, désinstallation annulée."
    local msg_ask_unmount_share="Un ou plusieurs partages Samba sont montés. Souhaitez-vous les démonter avant de désinstaller ?"
    local msg_custom_mount_point_prompt="Entrez le nom du point de montage :"
    local msg_install_cifs="Le paquet cifs-utils est requis pour monter un partage Samba. Souhaitez-vous l'installer ?"
    local msg_invalid_mount_name="Le nom du répertoire est invalide.\nUtilisez uniquement des lettres, chiffres, tirets, underscores et points."
    local msg_ip_prompt="Adresse IP du serveur Samba :\n (exemple : 192.168.1.130)"
    local msg_mount_error="Erreur lors du montage du partage Samba."
    local msg_mount_point_prompt="Point de montage local :\n (exemple : /home/nrx800/partage-smb)"
    local msg_mount_success="Le partage Samba a été monté avec succès."
    local msg_mount_title="Montage du partage Samba"
    local msg_mount_prompt="Voulez-vous monter un partage Samba ?"
    local msg_password_prompt="Mot de passe (laisser vide pour un accès anonyme) :\n (exemple : pass)"
    local msg_share_prompt="Sélectionnez un partage Samba (exemple: partage-smb) sur :\n"
    local msg_unmount_error="Erreur lors du démontage du partage '%s'."
    local msg_unmount_success="Le partage '%s' a été démonté avec succès."
    local msg_use_share_name_prompt="Voulez-vous utiliser comme point de montage le nom du partage Samba ? "
    local msg_tool_type="l'outil système"
    local msg_uninstall="Désinstallation"
    local msg_uninstall_error="Erreur lors de la désinstallation de Samba Client."
    local msg_uninstall_menu_prompt="Que souhaitez-vous faire ?"
    local msg_uninstall_option1="Désinstaller Samba et démonter tous les partages"
    local msg_uninstall_option2="Démonter des partages Samba spécifiques"
    local msg_uninstall_option3="Retour"
    local msg_uninstall_success="Samba Client a été désinstallé avec succès."
    local msg_select_shares_prompt="Sélectionnez les partages à démonter :"
    local msg_username_prompt="Nom d'utilisateur (laisser vide pour un accès anonyme) :\n (exemple : admin)"
    local msg_yet_installed="Samba Client est déjà installé."
  else
    local msg_button_cancel="Cancel"
    local msg_button_no="No"
    local msg_button_ok="Validate"
    local msg_button_yes="Yes"
    local msg_cancel_ip="Cancelled entering the IP address."
    local msg_cancel_mount_point="Cancelled entering the mount point."
    local msg_cancel_password="Cancelled entering the password."
    local msg_cancel_share="Cancelled selecting the share."
    local msg_cancel_username="Cancelled entering the username."
    local msg_exemple="To access a Windows share named 'partage-smb' on a PC with the IP address '192.168.1.130,' using the credentials for the user 'admin' with the password 'pass,' and mounting it on your NRX800 at the directory '/home/nrx800/partage-smb' (automatically created if it does not exist), enter the following values in sequence:\n
    Samba server IP address: 192.168.1.130
    Username: admin
    Password: pass
    Samba share name: partage-smb
    Local mount point: /home/nrx800/partage-smb"
    local msg_install="Install"
    local msg_install_error="Error installing Samba Client."
    local msg_install_success="Samba Client has been installed successfully."
    local msg_mount_on="was mounted on"
    local msg_no_mounted_shares="No Samba shares are currently mounted."
    local msg_no_shares_found="No Samba shares found on the server."
    local msg_not_installed_cancel="Samba Client is not installed, uninstall canceled."
    local msg_ask_unmount_share="One or more Samba shares are mounted. Do you want to unmount them before uninstalling ?"
    local msg_custom_mount_point_prompt="Enter the mount point name:"
    local msg_install_cifs="The cifs-utils package is required to mount a Samba share. Do you want to install it?"
    local msg_invalid_mount_name="The directory name is invalid.\nUse only letters, numbers, hyphens, underscores, and dots."
    local msg_ip_prompt="Samba server IP address:\n (example : 192.168.1.130)"
    local msg_mount_error="Error mounting Samba share."
    local msg_mount_point_prompt="Local mount point:\n (example : /home/nrx800/partage-smb)"
    local msg_mount_success="Samba share mounted successfully."
    local msg_mount_title="Mount Samba Share"
    local msg_mount_prompt="Do you want to mount a Samba share?"
    local msg_password_prompt="Password (leave empty for anonymous access):\n (example : pass)"
    local msg_share_prompt="Select a Samba share (example: partage-smb) on :\n"
    local msg_unmount_error="Error unmounting the share '%s'."
    local msg_unmount_success="The share '%s' has been unmounted successfully."
    local msg_use_share_name_prompt="Do you want to use the Samba share name as the mount point ? "
    local msg_tool_type="the system tool"
    local msg_uninstall="Uninstall"
    local msg_uninstall_error="Error uninstalling Samba Client."
    local msg_uninstall_menu_prompt="What do you want to do?"
    local msg_uninstall_option1="Uninstall Samba and unmount all shares"
    local msg_uninstall_option2="Unmount specific Samba shares"
    local msg_uninstall_option3="Return"
    local msg_uninstall_success="Samba Client has been uninstalled successfully."
    local msg_select_shares_prompt="Select shares to unmount:"
    local msg_username_prompt="Username (leave empty for anonymous access):\n (example : admin)"
    local msg_yet_installed="Samba Client is already installed."
  fi

  # Appeler la fonction pour afficher le menu de gestion des actions
  menu_0_main_menu_action "$msg_tool_type" "Samba-Client"

  # Vérifier si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" = "A" ]; then
    return 0
  fi

  # Si l'utilisateur choisit d'installer Samba Client
  if [ "$G_CHOICE" = "I" ]; then
  
    # Vérifier si Samba Client est déjà installé
    if ! command -v smbclient &> /dev/null; then

      # Affiche dans le terminal le début du traitement
      echo_process_start "Samba Client"
  
      # Mettre à jour la liste des paquets
      echo_step_start "$msg_install"
      if sudo apt-get update -y -qq > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_install"
      else
        echo_step_end_with_error "$msg_install"
      fi
      
      # Installer Samba Client
      echo_step_start "$msg_install"
      if sudo apt-get install -y -qq smbclient > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_install"
      else
        echo_step_end_with_error "$msg_install"
      fi

      # Affiche dans le terminal la fin du traitement
      echo_process_stop "Samba Client"

      # Vérifier si l'installation a réussi
      if [ $? -eq 0 ]; then
        # Afficher un message de succès
        echo_msgbox "$msg_install_success"
      else
        # Afficher un message d'erreur
        echo_msgbox "$msg_install_error"
        return 1
      fi
    else
      # Afficher un message indiquant que Samba Client est déjà installé
      echo_msgbox "$msg_yet_installed"
    fi

    # Demander à l'utilisateur s'il veut monter un partage Samba
    if whiptail --yesno "$msg_mount_prompt" 12 70 --fb --title "$msg_mount_title" --yes-button "$msg_button_ok" --no-button "$msg_button_cancel"; then
      # Vérifier si cifs-utils est installé
      if ! command -v mount.cifs &> /dev/null; then
        if whiptail --yesno "$msg_install_cifs" 12 70 --fb --title "$msg_mount_title" --yes-button "$msg_button_ok" --no-button "$msg_button_cancel"; then
          sudo apt-get install -y -qq cifs-utils
          # Quitter si cifs-utils ne peut pas être installé
          if [ $? -ne 0 ]; then
            echo_msgbox "$msg_mount_error"
            return 1
          fi
        else
          # Quitter si annulé
          return 0
        fi
      fi

      # Afficher un exemple de partage
      echo_msgbox "$msg_exemple" "$msg_mount_title"

      # Demander l'adresse IP du PC où se trouve le répertoire partagé Samba
      local smb_ip
      smb_ip=$(whiptail --inputbox "\n$msg_ip_prompt " 15 70 --fb --title "$msg_mount_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
      if [ $? -ne 0 ]; then
        echo "$msg_cancel_ip"
        return 1
      fi

      # Nom d'utilisateur autorisé sur le partage Samba sélectionné
      local smb_username
      smb_username=$(whiptail --inputbox "\n$msg_username_prompt" 15 70 --fb --title "$msg_mount_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
      if [ $? -ne 0 ]; then
        echo "$msg_cancel_username"
        return 1
      fi

      # Mot de passe de l'utilisateur autorisé sur le partage Samba sélectionné
      local smb_password
      smb_password=$(whiptail --inputbox "\n$msg_password_prompt" 15 70 --fb --title "$msg_mount_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
      if [ $? -ne 0 ]; then
        echo "$msg_cancel_password"
        return 1
      fi

      # Lister les partages Samba disponibles
      local smb_shares
      if [ -z "$smb_username" ]; then
        smb_shares=$(smbclient -L "$smb_ip" -N -g 2>/dev/null | awk -F'|' '/^Disk/ && $2 != "print$" {print $2}')
      else
        smb_shares=$(smbclient -L "$smb_ip" -U "$smb_username"%"$smb_password" -g 2>/dev/null | awk -F'|' '/^Disk/ && $2 != "print$" {print $2}')
      fi

      # Quitter si aucun partage n'est trouvé
      if [ -z "$smb_shares" ]; then
        echo_msgbox "$msg_no_shares_found" "$msg_mount_title"
        return 1
      fi

      # Convertir la liste des partages en un format pour whiptail
      local shares_list=()
      while IFS= read -r share; do
        [ -n "$share" ] && shares_list+=("$share" "")
      done <<< "$smb_shares"

      # Afficher un dialogue pour sélectionner un partage
      local smb_share
      smb_share=$(whiptail --menu "\n$msg_share_prompt $smb_ip" 20 75 8 "${shares_list[@]}" --fb --title "$msg_mount_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
      if [ $? -ne 0 ]; then
        echo "$msg_cancel_share"
        return 1
      fi

      # Demander à l'utilisateur s'il veut utiliser le nom du partage comme point de montage
      local smb_mount_name
      if whiptail --yesno "$msg_use_share_name_prompt\smb_share" 12 75 --fb --title "$msg_mount_title" --yes-button "$msg_button_yes" --no-button "$msg_button_no"; then

        # Si l'utilisateur annule, utiliser le nom du partage comme nom du point de montage et quitter la boucle
        if [ $? -ne 0 ]; then
          smb_mount_name="$smb_share"
          break
        fi

      # Demander à l'utilisateur de fournir un nom de point de montage personnalisé
      else

        while true; do

          smb_mount_name=$(whiptail --inputbox "\n$msg_custom_mount_point_prompt" 15 70 "$smb_share" --fb --title "$msg_mount_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
          # Si l'utilisateur annule, utiliser le nom du partage comme nom du point de montage et quitter la boucle
          if [ $? -ne 0 ]; then
            smb_mount_name="$smb_share"
            break
          fi

          # Vérifier si le nom de répertoire saisi est valide
          if [[ "$smb_mount_name" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
            # Le nom est valide, quitter la boucle
            break
          else
            # Afficher un message d'erreur si le nom est invalide
            echo_msgbox "$msg_invalid_mount_name" "$msg_mount_title"
          fi
        done
      fi

      # Demander à l'utilisateur où il veut monter le partage Samba sur le NRX800
      smb_mount_point=$(disk_get_filepath "$msg_mount_title : $smb_share" "R" "/")

      # Quitter si annulé
      if [ "$smb_mount_point" = "***" ]; then
        return 1
      fi

      # Ajouter le nom du point de montage au point de montage
      smb_mount_point=$smb_mount_point + $smb_mount_name
      # Créer le point de montage s'il n'existe pas
      if [ ! -d "$smb_mount_point" ]; then
        sudo mkdir -p "$smb_mount_point"
      fi

      # Monter le partage Samba
      if [ -z "$smb_username" ]; then
        sudo mount -t cifs "//$smb_ip/$smb_share" "$smb_mount_point" -o guest
      else
        sudo mount -t cifs "//$smb_ip/$smb_share" "$smb_mount_point" -o username="$smb_username",password="$smb_password"
      fi

      # Vérifier si le montage a réussi
      if [ $? -eq 0 ]; then
        echo_msgbox "$msg_mount_success\n'//$smb_ip/$smb_share' \n$msg_mount_on \n'$smb_mount_point$smb_mount_name'"
      else
        echo_msgbox "$msg_mount_error"
      fi
    fi
  fi

  # Si l'utilisateur choisit de désinstaller Samba Client
  if [ "$G_CHOICE" = "D" ]; then

    # Vérifier si Samba Client est installé
    if dpkg-query -W -f='${Status}' smbclient 2>/dev/null | grep -q "install ok installed"; then
    
      # Demander à l'utilisateur ce qu'il veut faire
      local uninstall_choice
      uninstall_choice=$(whiptail --menu "\n$msg_uninstall_menu_prompt" 15 70 4 \
        "1" "$msg_uninstall_option1" \ # "Désinstaller Samba et démonter tous les partages"
        "2" "$msg_uninstall_option2" \ # "Démonter des partages Samba spécifiques"
        "3" "$msg_uninstall_option3" \ # "Retour"
        --fb --title "$msg_mount_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
    
      # Si l'utilisateur annule, revenir au menu principal
      if [ $? -ne 0 ]; then
        return 0
      fi

      # Traiter le choix de l'utilisateur
      case "$uninstall_choice" in
        "1") # Démontage de tous les partages Samba montés
          if mount | grep -q "type cifs"; then
            if whiptail --yesno "$msg_ask_unmount_share" 12 70 --fb --title "$msg_mount_title" --yes-button "$msg_button_yes" --no-button "$msg_button_no"; then
              sudo umount -a -t cifs
              if [ $? -eq 0 ]; then
                echo_msgbox "$msg_unmount_success"
              else
                echo_msgbox "$msg_unmount_error" 
              fi
            fi
          fi

          # Affiche dans le terminal le début du traitement
          echo_process_start "Samba-Client"
  
          # Désinstaller Samba Client et cifs-utils
          echo_step_start "$msg_uninstall"
          if sudo apt-get remove -y -qq smbclient cifs-utils > /dev/null 2>&1; then
            echo_step_end_with_success "$msg_uninstall"
          else
            echo_step_end_with_error "$msg_uninstall"
          fi
          
          # Supprimer les dépendances inutilisées
          sudo apt-get autoremove -y -qq

          # Affiche dans le terminal la fin du traitement
          echo_process_stop "Samba-Client"
      
          # Vérifier la désinstallation
          if [ $? -eq 0 ]; then
            echo_msgbox "$msg_uninstall_success"
          else
            echo_msgbox "$msg_uninstall_error"
            return 1
          fi
          ;;

        "2") # Lister les partages Samba montés
          local mounted_shares
          mounted_shares=$(mount | grep "type cifs" | awk '{print $3}')

          # Si aucun partage n'est monté, afficher un message et revenir
          if [ -z "$mounted_shares" ]; then
            echo_msgbox "$msg_no_mounted_shares" "$msg_mount_title"
            return 0
          fi

          # Convertir la liste des partages montés en un format pour whiptail
          local shares_list=()
          while IFS= read -r share; do
            [ -n "$share" ] && shares_list+=("$share" "")
          done <<< "$mounted_shares"

          # Afficher un dialogue pour sélectionner les partages à démonter
          local shares_to_unmount
          shares_to_unmount=$(whiptail --checklist "\n$msg_select_shares_prompt" 20 75 10 "${shares_list[@]}" --fb --title "$msg_mount_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)

          # Si l'utilisateur annule, revenir au menu principal
          if [ $? -ne 0 ]; then
            return 0
          fi

          # Démontage des partages sélectionnés
          for share in $shares_to_unmount; do
            # Supprimer les guillemets autour du partage
            share=$(echo "$share" | tr -d '"')
            sudo umount "$share"
            if [ $? -eq 0 ]; then
              echo_msgbox "$(printf "$msg_unmount_success" "$share")"
            else
              echo_msgbox "$(printf "$msg_unmount_error" "$share")"
            fi
          done
          ;;

        "3")
          # Revenir au menu principal
          return 0
          ;;
      esac

    else
      # Afficher un message indiquant que Samba Client n'est pas installé
      echo_msgbox "$msg_not_installed_cancel"
    fi
  fi

}

# Fonction pour installer, configurer et désinstaller UFW
# Function to install, configure and uninstall UFW
function menu_4_system_tools_ufw() {

  # Définir les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
		local msg_button_cancel="Retour"
		local msg_button_no="Non"
		local msg_button_ok="Suivant"
		local msg_button_yes="Oui"
    local msg_config_error="Erreur lors de la configuration de UFW."
    local msg_config_success="Configuration de UFW réussie."
    local msg_config_title="Configuration de UFW"
    local msg_install="Installation"
    local msg_install_error="Erreur lors de l'installation de UFW."
    local msg_installed_inactived="UFW est installé mais pas activé."
    local msg_install_success="UFW a été installé avec succès."
    local msg_invalid_ip="Adresse IP invalide :"
    local msg_invalid_port="Port invalide :"
    local msg_ip_prompt="Entrez les adresses IP autorisées (séparées par des virgules) :"
    local msg_not_installed_cancel="UFW n'est pas installé, désinstallation annulée."
    local msg_port_prompt="Entrez les ports autorisés (séparés par des virgules) :\n (ajout du port SSH automatique)"
    local msg_tool_type="l'outil système"
    local msg_uninstall="Désinstallation"
    local msg_uninstall_error="Erreur lors de la désinstallation de UFW."
    local msg_uninstall_success="UFW a été désinstallé avec succès."
    local msg_yet_installed="UFW est déjà installé."
  else
 		local msg_button_cancel="Back"
		local msg_button_no="No"
		local msg_button_ok="Next"
		local msg_button_yes="Yes"
    local msg_config_error="Error configuring UFW."
    local msg_config_success="UFW configuration successful."
    local msg_config_title="UFW Configuration"
    local msg_install="Install"
    local msg_install_error="Error installing UFW."
    local msg_installed_inactived="UFW is installed but not active."
    local msg_install_success="UFW has been installed successfully."
    local msg_invalid_ip="Invalid IP address:"
    local msg_invalid_port="Invalid port:"
    local msg_ip_prompt="Enter the allowed IP addresses (comma-separated):"
    local msg_not_installed_cancel="UFW is not installed, uninstall canceled."
    local msg_port_prompt="Enter the allowed ports (comma-separated):\n (automatic addition of the SSH port)"
    local msg_tool_type="the system tool"
    local msg_uninstall="Uninstall"
    local msg_uninstall_error="Error uninstalling UFW."
    local msg_uninstall_success="UFW has been uninstalled successfully."
    local msg_yet_installed="UFW is already installed."
  fi
  
  # Appeler la fonction pour afficher le menu de gestion des actions
  menu_0_main_menu_action "$msg_tool_type" "Ufw"

  # Vérifier si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" = "A" ]; then
    return 0
  fi

  # Si l'utilisateur choisit d'installer UFW
  if [ "$G_CHOICE" = "I" ]; then

    # Vérifier si UFW est déjà installé
    if ! command -v ufw &> /dev/null; then

      # Affiche dans le terminal le début du traitement
      echo_process_start "UFW" 

       # Mettre à jour la liste des paquets
      echo_step_start "$msg_install"
      if sudo apt-get update -y -qq > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_install"
      else
        echo_step_end_with_error "$msg_install"
      fi
      
      # Installer Midnight-Commander
      echo_step_start "$msg_install"
      if sudo apt-get install -y -qq ufw > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_install"
      else
        echo_step_end_with_error "$msg_install"
      fi

      # Affiche dans le terminal la fin du traitement
      echo_process_stop "UFW"

      # Vérifier si l'installation a réussi
      if [ $? -eq 0 ]; then
        # Afficher un message de succès
        echo_msgbox "$msg_install_success"
      fi  

    else
      # Afficher un message indiquant que UFW est déjà installé
      echo_msgbox "$msg_yet_installed"
    fi



    # Boucler jusqu'à ce que des adresses IP valides soient entrées ou que l'utilisateur annule
    while true; do
      # Obtenir l'adresse IP locale et définir le réseau par défaut
      local local_ip
      local_ip=$(network_get_current_ip)  # Appeler la fonction pour obtenir l'adresse IP locale

      # Vérifier si l'adresse IP a été récupérée avec succès
      if [ $? -ne 0 ]; then
        # Si la récupération de l'IP échoue, utiliser une valeur par défaut générique
        local default_ips="192.168.1.0/24"
      else
        # Utiliser le réseau par défaut /24 basé sur l'adresse IP locale (ex. : 192.168.1.0/24)
        local default_ips="${local_ip%.*}.0/24"
      fi

      # Afficher la boîte de dialogue avec la valeur par défaut
      local allowed_ips
      allowed_ips=$(whiptail --inputbox "\n$msg_ip_prompt" 15 70 "$default_ips" --fb --title "$msg_config_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
      # Obtenir le statut de sortie
      local exit_status=$?

      # Si l'utilisateur annule, quitter la fonction
      if [ $exit_status -ne 0 ]; then
        return 1
      fi

      # Si l'utilisateur n'a rien entré, utiliser la valeur par défaut
      if [ -z "$allowed_ips" ]; then
        allowed_ips="$default_ips"
      fi

      # Vérifier que les adresses IP entrées sont valides
      IFS=',' read -ra IP_ARRAY <<< "$allowed_ips"
      local invalid_entries=()
      for ip_entry in "${IP_ARRAY[@]}"; do
        if [[ $ip_entry == *"/"* ]]; then
          if ! network_validate_ip_mask "$ip_entry"; then
            invalid_entries+=("$ip_entry")
          fi
        else
          if ! network_validate_ip "$ip_entry"; then
            invalid_entries+=("$ip_entry")
          fi
        fi
      done

      # Si toutes les adresses IP sont valides, quitter la boucle
      if [ ${#invalid_entries[@]} -eq 0 ]; then
        break
      else
        # Afficher un message d'erreur pour toutes les entrées invalides
        echo_msgbox "$(printf "$msg_invalid_ip" "$(IFS=,; echo "${invalid_entries[*]}")")"
      fi
    done

    # Boucler jusqu'à ce que des ports valides soient entrés ou que l'utilisateur annule
    while true; do
      # Obtenir les ports ouverts par défaut
      local default_ports
      default_ports=$(network_get_port_opened)

      # Si aucun port n'est ouvert, utiliser une valeur par défaut
      if [ -z "$default_ports" ]; then
        default_ports="80,443,22"
      fi

      # Afficher la boîte de dialogue avec les ports par défaut
      local allowed_ports
      allowed_ports=$(whiptail --inputbox "\n$msg_port_prompt" 15 70 "$default_ports" --fb --title "$msg_config_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)

      if [ $? -ne 0 ]; then
        return 1
      fi

      if [ -z "$allowed_ports" ]; then
        allowed_ports="$default_ports"
      fi

      # Trier les ports dans l'ordre croissant
      allowed_ports=$(echo "$allowed_ports" | tr ',' '\n' | sort -n | paste -sd ',' -)

      IFS=',' read -ra PORT_ARRAY <<< "$allowed_ports"
      local valid_ports=true
      for port in "${PORT_ARRAY[@]}"; do
        if ! network_validate_port "$port"; then
          echo_msgbox "$(printf "$msg_invalid_port" "$port")"
          valid_ports=false
          break
        fi
      done

      if $valid_ports; then
        break
      fi
    done

    # Ajouter le port SSH par défaut aux ports autorisés (s'il n'est pas déjà présent)
    local default_ssh_port
    default_ssh_port=$(grep -oP 'Port \K\d+' /etc/ssh/sshd_config)
    default_ssh_port=${default_ssh_port:-22}
    if [[ ! ",$allowed_ports," =~ ",$default_ssh_port," ]]; then
      allowed_ports="$allowed_ports,$default_ssh_port"
    fi

    # Configurer UFW
    sudo ufw default deny incoming > /dev/null 2>&1
    sudo ufw default allow outgoing > /dev/null 2>&1
    for ip in "${IP_ARRAY[@]}"; do
      sudo ufw allow from "$ip" > /dev/null 2>&1
    done
    for port in "${PORT_ARRAY[@]}"; do
      sudo ufw allow "$port" > /dev/null 2>&1
    done

    # Démarrer UFW et l'activer au démarrage
    if ! sudo ufw --force enable > /dev/null 2>&1; then
      echo_msgbox "$msg_config_error"
      return 1
    fi
    sudo systemctl enable ufw > /dev/null 2>&1

    # Vérifier si UFW est actif
    if ufw status | grep -q "Status: active"; then
      echo_msgbox "$msg_config_success"
    else
      echo_msgbox "$msg_installed_inactived"
    fi

  fi

  # Si l'utilisateur choisit de désinstaller UFW
  if [ "$G_CHOICE" = "D" ]; then
    # Vérifier si UFW est installé
    if command -v ufw &> /dev/null; then
    
      # Affiche dans le terminal le début du traitement
      echo_process_start "UFW"
      
      # Désactiver UFW
      sudo ufw disable > /dev/null 2>&1

      # Désinstaller UFW
      echo_step_start "$msg_uninstall"
      if sudo apt-get remove -y -qq ufw > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_uninstall"
      else
        echo_step_end_with_error "$msg_uninstall"
      fi

      # Supprimer les dépendances inutilisées
      sudo apt-get autoremove -y -qq > /dev/null 2>&1
      
      # Affiche dans le terminal la fin du traitement
      echo_process_stop "UFW"
      
      # Vérifier si la désinstallation a réussi
      if [ $? -eq 0 ]; then
        # Afficher un message de succès
        echo_msgbox "$msg_uninstall_success"
      else
        # Afficher un message d'erreur
        echo_msgbox "$msg_uninstall_error"
        return 1
      fi
    else
        # Afficher un message indiquant que UFW n'est pas installé
      echo_msgbox "$msg_not_installed_cancel"
    fi
  fi

}

# Fonction pour installer et désinstaller WireGuard
# Function to install and uninstall WireGuard
function menu_4_system_tools_wireguard() {

  # Définir les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_no="Non"
    local msg_button_ok="Suivant"
    local msg_button_yes="Oui"
    local msg_install="Installation"
    local msg_install_error="Erreur lors de l'installation de WireGuard."
    local msg_install_success="WireGuard a été installé avec succès."
    local msg_install_UI="Voulez-vous installer l'interface WireGuard UI ?"
    local msg_yet_installed="WireGuard est déjà installé."
    local msg_uninstall="Désinstallation"
    local msg_uninstall_error="Erreur lors de la désinstallation de WireGuard."
    local msg_uninstall_success="WireGuard a été désinstallé avec succès."
    local msg_uninstall_Wireguard="Voulez-vous désinstaller WireGuard ?"
    local msg_uninstall_UI="Voulez-vous désinstaller l'interface WireGuard UI ?"
    local msg_not_installed_cancel="WireGuard n'est pas installé, désinstallation annulée."
    local msg_tool_type="outil système"
    local msg_config_success="Configuration de WireGuard terminée."
    local msg_qr_info="QR Code et configuration client disponibles dans /root/wireguard_qr/"
  else
    local msg_button_cancel="Back"
    local msg_button_no="No"
    local msg_button_ok="Next"
    local msg_button_yes="Yes"
    local msg_install="Install"
    local msg_install_error="Error installing WireGuard."
    local msg_install_success="WireGuard has been installed successfully."
    local msg_install_UI="Do you want to install WireGuard UI interface?"
    local msg_yet_installed="WireGuard is already installed."
    local msg_uninstall="Uninstall"
    local msg_uninstall_error="Error uninstalling WireGuard."
    local msg_uninstall_success="WireGuard was uninstalled with succès."
    local msg_uninstall_Wireguard="Do you want to uninstall WireGuard ?"
    local msg_uninstall_UI="Do you want to uninstall WireGuard UI interface ?"
    local msg_not_installed_cancel="WireGuard is not installed, uninstall canceled."
    local msg_tool_type="system tool"
    local msg_config_success="WireGuard configuration completed."
    local msg_qr_info="QR Code and client configuration available in /root/wireguard_qr/"
  fi

  # Appeler la fonction pour afficher le menu de gestion des actions
  menu_0_main_menu_action "$msg_tool_type" "WireGuard"

  # Vérifier si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" == "A" ]; then
    return 0
  fi

  # === INSTALLATION ===
  if [ "$G_CHOICE" == "I" ]; then

    if ! apt list --installed wireguard-tools 2>/dev/null | grep -q "wireguard-tools"; then

      # Wireguard est pas installé
      echo_process_start "WireGuard"

      # Installation des dépendances
      echo_step_start "$msg_install"
      if sudo apt-get update -y -qq > /dev/null 2>&1 && sudo apt-get install -y -qq wireguard-tools qrencode > /dev/null 2>&1; then
        echo_step_end_with_success "$msg_install"
      else
        echo_step_end_with_error "$msg_install"
        echo_process_stop "WireGuard"
        echo_msgbox "$msg_install_error"
        return 1
      fi

      # Configuration de WireGuard
      echo_step_start "Configuration de WireGuard"
      WG_DIR="/etc/wireguard"
      WG_CONF="/etc/wireguard/wg0.conf"
      WG_QR_DIR="/root/wireguard_qr"
      
      # Création du dossier de configuration /etc/wireguard
      sudo mkdir -p "/etc/wireguard"
      # sudo chown -R root:root "/etc/wireguard"
      sudo chown www-data:www-data /etc/wireguard
      sudo chmod 755 /etc/wireguard

      # Créer les répertoires des peers /etc/wireguard/peers
      sudo mkdir -p /etc/wireguard/peers
      sudo chown -R root:root /etc/wireguard/peers
      sudo chmod -R 755 /etc/wireguard/peers

      # Création du dossier de configuration /root/wireguard_qr
      sudo mkdir -p /root/wireguard_qr
      sudo chown -R root:root /root/wireguard_qr
      sudo chmod -R 755 /root/wireguard_qr
      
      # Création du fichier /etc/wireguard/wg0.conf
      sudo touch /etc/wireguard/wg0.conf
      sudo chmod 644 /etc/wireguard/wg0.conf
      sudo chown root:root /etc/wireguard/wg0.conf

      sudo chmod 644 /etc/wireguard/peers/*.png
      sudo chown www-data:www-data /etc/wireguard/peers/*.png
      
      sudo chown www-data:www-data /etc/wireguard/wg0.conf

    
      # Génération des clés
      umask 077
      wg genpsk | sudo tee /etc/wireguard/preshared.key >/dev/null
      wg genkey | sudo tee /etc/wireguard/client_private.key | wg pubkey | sudo tee /etc/wireguard/client_public.key >/dev/null
      wg genkey | sudo tee /etc/wireguard/server_private.key | wg pubkey | sudo tee /etc/wireguard/server_public.key >/dev/null
      
      # Après la génération des clés, vérifiez leur création
      if [ ! -f /etc/wireguard/server_public.key ] || [ ! -s /etc/wireguard/server_public.key ]; then
        echo "Erreur: La clé publique n'a pas été générée correctement"
        return 1
      fi
      
      # Création de la configuration serveur
      sudo bash -c "cat > /etc/wireguard/wg0.conf" << EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = $(sudo cat "$WG_DIR/server_private.key")
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $(sudo cat "$WG_DIR/client_public.key")
PresharedKey = $(sudo cat "$WG_DIR/preshared.key")
AllowedIPs = 10.0.0.2/32
EOF
      # Attribut les droits   
   
      # Création de la configuration client
      sudo bash -c "cat > '$WG_QR_DIR/client.conf'" << EOF
[Interface]
Address = 10.0.0.2/24
PrivateKey = $(sudo cat "$WG_DIR/client_private.key")
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = $(sudo cat "$WG_DIR/server_public.key")
PresharedKey = $(sudo cat "$WG_DIR/preshared.key")
Endpoint = $(hostname -I | awk '{print $1}'):51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
      
      # Génération du QR code
      sudo qrencode -t ansiutf8 < "$WG_QR_DIR/client.conf" | sudo tee "$WG_QR_DIR/client_qr.txt" >/dev/null
      sudo qrencode -o "$WG_QR_DIR/client_qr.png" < "$WG_QR_DIR/client.conf"
      
      # Activation du forwarding IP
      echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf >/dev/null
      sudo sysctl -p >/dev/null
      
      # Activation au démarrage
      sudo systemctl enable wg-quick@wg0 >/dev/null 2>&1
      sudo systemctl start wg-quick@wg0 >/dev/null 2>&1
      
      echo_step_end_with_success "$msg_config_success"
      echo_process_stop "WireGuard"
      
      # Afficher les informations de configuration
      echo_msgbox "$msg_install_success\n\n$msg_config_success\n$msg_qr_info"
      
    else
      
      echo_msgbox "$msg_yet_installed"
    fi
    
    # Demander à l'utilisateur s'il souhaite installer l'interface UI
    if whiptail --yesno "$msg_install_UI" 10 60 --fb --title "$msg_title" --yes-button "$msg_button_yes" --no-button "$msg_button_no"; then
      G_CHOICE="I"
      menu_4_system_tools_wireguard_ui
    fi
  fi

  # === DÉSINSTALLATION ===
  if [ "$G_CHOICE" == "D" ]; then
  
    # Demander à l'utilisateur s'il souhaite désinstallater l'interface UI
    if whiptail --yesno "$msg_uninstall_UI" 10 60 --fb --title "$msg_title" --yes-button "$msg_button_yes" --no-button "$msg_button_no"; then
        G_CHOICE="D"
        menu_4_system_tools_wireguard_ui
    fi

    # Wireguard est installé
    if apt list --installed wireguard-tools 2>/dev/null | grep -q "wireguard-tools"; then

      # Demander à l'utilisateur s'il souhaite désinstaller wireguard
      if whiptail --yesno "$msg_uninstall_Wireguard" 10 60 --fb --title "$msg_title" --yes-button "$msg_button_yes" --no-button "$msg_button_no"; then
        
          echo_process_start "WireGuard"

          echo_step_start "$msg_uninstall"
          sudo systemctl stop wg-quick@wg0 || true
          if sudo apt-get remove --purge -y -qq wireguard-tools qrencode > /dev/null 2>&1; then
          
            # Supprimer les fichiers de configuration
            sudo rm -rf /etc/wireguard
            sudo rm -rf /root/wireguard_qr
          
          # Désactiver le forwarding IP
            sudo sed -i '/net.ipv4.ip_forward=1/d' /etc/sysctl.conf
            sudo sysctl -p >/dev/null
            
            echo_step_end_with_success "$msg_uninstall"
          else
            echo_step_end_with_error "$msg_uninstall"
            echo_process_stop "WireGuard"
            echo_msgbox "$msg_uninstall_error"
            return 1
          fi

          echo_process_stop "WireGuard"

          echo_msgbox "$msg_uninstall_success"

      fi
    else
      echo_msgbox "$msg_not_installed_cancel"
    fi
  fi
}

# Fonction pour installer et désinstaller WireGuard UI (interface Flask)
# Function to install and uninstall WireGuard UI (Flask)
function menu_4_system_tools_wireguard_ui() {

  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_ok="Suivant"
    local msg_install="Installation"
    local msg_install_success="L'interface WireGuard-UI a été installée avec succès."
    local msg_install_error="Erreur lors de l'installation de l'interface WireGuard-UI."
    local msg_uninstall="Désinstallation"
    local msg_uninstall_success="WireGuard UI a été désinstallée avec succès."
    local msg_uninstall_error="Erreur lors de la désinstallation de WireGuard-UI."
    local msg_not_installed_cancel="WireGuard UI n'est pas installée, désinstallation annulée."
    local msg_yet_installed="WireGuard UI est déjà installée."
    local msg_tool_type="interface utilisateur"
    local msg_wireguard_start_app="Voulez-vous démarrez l'interface WIreGuard-UI ?"
    local msg_install_dependancies="Installation des dépendances"
    local msg_install_create="Création du fichier"
    local msg_install_create_service="Création du service systemd"
    local msg_install_start_service="Démarrage du service wireguard-ui"
    local msg_service_stop="Arrêt des services"
    local msg_file_remove="Suppression des fichiers"
    local msg_disable_ip_forward="Désactivation IP forwarding"
    local msg_remove_dependencies="Suppression des dependences"
    local msg_clean_systemd="Nettoyage de systemd"
    local msg_access_to="Accéder à http://${G_IP_HOST}:5000\nIdentifiants : admin/admin \nLogs disponibles dans ~/wireguard-ui.log"
  else
    local msg_button_cancel="Back"
    local msg_button_ok="Next"
    local msg_install="Install"
    local msg_install_success="WireGuard UI has been successfully installed."
    local msg_install_error="Error installing WireGuard-UI."
    local msg_uninstall="Uninstall"
    local msg_uninstall_success="WireGuard UI has been successfully uninstalled."
    local msg_uninstall_error="Error uninstalling WireGuard-UI."
    local msg_not_installed_cancel="WireGuard UI is not installed, uninstall canceled."
    local msg_yet_installed="WireGuard UI is already installed."
    local msg_tool_type="user interface"
    local msg_wireguard_start_app="Would you want start WireGuard-UI interface ?"
    local msg_install_dependancies="Install dependancies"
    local msg_install_create="Creating file"
    local msg_install_create_service="Creating systemd service"
    local msg_install_start_service="Starting service wireguard-ui"
    local msg_service_stop="Stopping services"
    local msg_file_remove="Removing files"
    local msg_disable_ip_forwward="Disabling IP forwarding"
    local msg_remove_dependencies="Removing dependencies"
    local msg_clean_systemd="Cleaning up systemd"
    local msg_access_to="Access http://${G_IP_HOST}:5000\nCredentials: admin/admin \nLogs available in ~/wireguard-ui.log"
  fi

  # opt/wireguard-ui/
  #     ├── app.py             # Serveur Flask principal
  #     ├── config.json
  #     └── templates/
  #         ├── backups.html
  #         ├── base.html
  #         ├── index.html
  #         ├── login.html
  #         └── view_peer.html
  #  etc/wireguard/wg0.conf
 
  if [ "$G_CHOICE" = "A" ]; then
    return 0
  fi

  # === INSTALLATION ===
  if [ "$G_CHOICE" = "I" ]; then

    if [ ! -f "/etc/systemd/system/wireguard-ui.service" ]; then

      echo_process_start "WireGuard-UI - NRX800"
#  echo_step_info "$msg_install"

      # Installer les dépendances
      echo_step_start "$msg_install_dependancies ..."

      apt-get update -qq >/dev/null 2>&1
      apt-get upgrade -y -qq >/dev/null 2>&1
      apt-get install -y -qq python3 python3-pip unzip >/dev/null 2>&1
      pip3 install -q -q flask qrcode humanize >/dev/null 2>&1

      local required_deps=("python3" "python3-pip" "unzip")
      for dep in "${required_deps[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$dep" 2>/dev/null | grep -q "install ok installed"; then
          echo "Error: $dep is not installed"
          return 1
        fi
      done
      echo_step_stop "$msg_install_dependancies ok"

      # Créer les répertoires nécessaires
      mkdir -p /etc/wireguard/peers /etc/wireguard/backups >/dev/null 2>&1
      chmod 755 /etc/wireguard /etc/wireguard/peers /etc/wireguard/backups >/dev/null 2>&1

      APP_DIR="/opt/wireguard-ui"
      mkdir -p "$APP_DIR/templates" >/dev/null 2>&1
      chmod 755 "$APP_DIR" >/dev/null 2>&1

      # Créer app.py
      echo_step_start "$msg_install_create app.py ..."
cat << 'EOF' > "$APP_DIR/app.py"
import sys
import os
import logging
import urllib.parse
import subprocess
import json
from flask import Flask, render_template, request, redirect, url_for, session, flash, send_from_directory, jsonify
from functools import wraps
from datetime import datetime
import shutil
import re
from io import BytesIO
import base64
import qrcode
import humanize
import socket
import zipfile

# Config logs
LOG_FILE = os.path.expanduser('~/wireguard-ui.log')
logging.basicConfig(filename=LOG_FILE, level=logging.DEBUG, format='%(asctime)s [%(levelname)s] %(message)s')
# App Flask
app = Flask(__name__)
app.secret_key = os.urandom(24)

# Config
CONFIG_PATH = os.path.join(os.path.dirname(__file__), 'config.json')
BACKUP_DIR = "/etc/wireguard/backups"
PEERS_DIR = "/etc/wireguard/peers"
WG_CONF = "/etc/wireguard/wg0.conf"
ALLOWED_IPS = "0.0.0.0/0"

try:
    with open(CONFIG_PATH) as f:
        CONFIG = json.load(f)
except Exception as e:
    logging.error(f"Erreur lecture config.json: {str(e)}")
    CONFIG = {'username': 'admin', 'password': 'admin'}

ADMIN_USER = CONFIG.get('username', 'admin')
ADMIN_PASS = CONFIG.get('password', 'admin')

# WireGuard Tools
def get_server_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        try:
            result = subprocess.run(['ip', '-4', 'addr', 'show', 'eth0'], capture_output=True, text=True, check=True)
            match = re.search(r'inet (\d+\.\d+\.\d+\.\d+)', result.stdout)
            if match:
                return match.group(1)
        except:
            try:
                result = subprocess.run(['hostname', '-I'], capture_output=True, text=True, check=True)
                ips = result.stdout.strip().split()
                if ips:
                    return ips[0]
            except:
                try:
                    with open('/etc/hosts', 'r') as f:
                        for line in f:
                            if '127.0.0.1' in line and 'localhost' in line:
                                continue
                            match = re.search(r'(\d+\.\d+\.\d+\.\d+)', line)
                            if match:
                                return match.group(1)
                except:
                    pass
    return "VOTRE_IP_SERVEUR"
SERVER_ENDPOINT = f"{get_server_ip()}:51820"

def get_server_public_key():
    try:
        server_pubkey_file = '/etc/wireguard/server_public.key'
        if os.path.exists(server_pubkey_file):
            with open(server_pubkey_file, 'r') as f:
                key = f.read().strip()
                if key:
                    logging.info("Clé publique récupérée depuis server_public.key")
                    return key
        try:
            result = subprocess.run(['wg', 'show', 'wg0', 'public-key'], capture_output=True, text=True, check=True)
            if result.stdout.strip():
                logging.info("Clé publique récupérée via wg show")
                return result.stdout.strip()
        except (subprocess.CalledProcessError, FileNotFoundError):
            pass
        server_privkey_file = '/etc/wireguard/server_private.key'
        if not os.path.exists(server_privkey_file):
            logging.info("Génération de nouvelles clés serveur")
            privkey = run_cmd(['wg', 'genkey'])
            if not privkey:
                raise Exception("Échec génération clé privée")
            with open(server_privkey_file, 'w') as f:
                f.write(privkey)
        with open(server_privkey_file, 'r') as f:
            privkey = f.read().strip()
        pubkey = run_cmd(['wg', 'pubkey'], input=privkey)
        if not pubkey:
            raise Exception("Échec génération clé publique")
        with open(server_pubkey_file, 'w') as f:
            f.write(pubkey)
        logging.info("Nouvelles clés serveur générées")
        return pubkey.strip()
    except Exception as e:
        logging.error(f"Erreur critique dans get_server_public_key(): {str(e)}")
        raise Exception("Impossible d'obtenir la clé publique du serveur")
SERVER_PUBLIC_KEY = get_server_public_key()


def add_peer(name, ip=None):
    try:
        logging.info(f"Tentative d'ajout du peer: name='{name}', ip='{ip}'")
        if not name or not name.strip():
            logging.error("Nom de peer invalide")
            return False
        name = name.strip()
        ip_address = get_next_ip(ip)
        if not ip_address:
            logging.error("Échec de l'attribution d'IP")
            return False
        private_key = run_cmd(['wg', 'genkey']).strip()
        public_key = run_cmd(['wg', 'pubkey'], input=private_key).strip()
        preshared_key = run_cmd(['wg', 'genpsk']).strip()
        if not all([private_key, public_key, preshared_key]):
            logging.error("Échec de génération des clés")
            return False
        os.makedirs(PEERS_DIR, exist_ok=True)
        with open(WG_CONF, "a") as f:
            f.write(f"\n# {name}\n[Peer]\nPublicKey = {public_key}\nPresharedKey = {preshared_key}\nAllowedIPs = {ip_address}\n")
        client_conf = f"""
[Interface]
PrivateKey = {private_key}
Address = {ip_address}
DNS = 1.1.1.1
[Peer]
PublicKey = {SERVER_PUBLIC_KEY}
PresharedKey = {preshared_key}
Endpoint = {SERVER_ENDPOINT}
AllowedIPs = {ALLOWED_IPS}
PersistentKeepalive = 25
""".strip()
        peer_filename = os.path.join(PEERS_DIR, f"{name}.conf")
        with open(peer_filename, "w") as f:
            f.write(client_conf)
        qr = qrcode.QRCode(version=1, box_size=10, border=4)
        qr.add_data(client_conf)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        qr_path = os.path.join(PEERS_DIR, f"{name}.png")
        img.save(qr_path)
        conf_exists = os.path.exists(peer_filename)
        png_exists = os.path.exists(qr_path)
        if not (conf_exists and png_exists):
            logging.error(f"Fichiers peer non créés: conf={conf_exists}, png={png_exists}")
            return False
        with open(WG_CONF, 'r') as f:
            config_content = f.read()
            if f"# {name}" not in config_content or public_key not in config_content:
                logging.error("Peer absent du fichier de configuration")
                return False
        backup_peers("add")  # Sauvegarde après ajout
        return True
    except Exception as e:
        logging.error(f"Erreur critique dans add_peer(): {str(e)}")
        return False

def backup_peers(action="backup"):
    try:
        os.makedirs(BACKUP_DIR, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        archive_name = f"peers_{action}_{timestamp}"
        archive_path = os.path.join(BACKUP_DIR, archive_name)
        # Créer un répertoire temporaire pour inclure wg0.conf et PEERS_DIR
        temp_dir = os.path.join(BACKUP_DIR, f"temp_{timestamp}")
        os.makedirs(temp_dir, exist_ok=True)
        # Copier wg0.conf
        if os.path.exists(WG_CONF):
            shutil.copy(WG_CONF, os.path.join(temp_dir, "wg0.conf"))
        # Copier PEERS_DIR
        peers_temp = os.path.join(temp_dir, "peers")
        shutil.copytree(PEERS_DIR, peers_temp, dirs_exist_ok=True)
        # Créer l'archive ZIP
        shutil.make_archive(archive_path, 'zip', temp_dir)
        # Nettoyer le répertoire temporaire
        shutil.rmtree(temp_dir)
        logging.info(f"Sauvegarde effectuée : {archive_path}.zip")
        return True
    except Exception as e:
        logging.error(f"Erreur sauvegarde peers : {str(e)}")
        return False

def clean_orphan_files():
    try:
        peer_names = [p['name'] for p in get_peers()]
        for fname in os.listdir(PEERS_DIR):
            base, ext = os.path.splitext(fname)
            if ext in [".conf", ".png"] and base not in peer_names:
                fpath = os.path.join(PEERS_DIR, fname)
                os.remove(fpath)
                logging.info(f"Fichier orphelin supprimé : {fpath}")
        return True
    except Exception as e:
        logging.error(f"Erreur nettoyage fichiers orphelins : {str(e)}")
        return False

def run_cmd(cmd, input=None):
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, input=input, check=True)
        logging.debug(f"Commande exécutée: {cmd}, sortie: {result.stdout}")
        return result.stdout
    except subprocess.CalledProcessError as e:
        logging.error(f"Erreur commande {cmd}: {e.stderr}")
        return ""

def generate_qr_code(conf):
    try:
        if not conf or not isinstance(conf, str):
            logging.error("Configuration vide ou invalide pour QR code")
            return None
        qr = qrcode.QRCode(version=1, box_size=10, border=4)
        qr.add_data(conf)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        buffered = BytesIO()
        img.save(buffered, format="PNG")
        result = base64.b64encode(buffered.getvalue()).decode('utf-8')
        logging.debug("QR code généré avec succès")
        return result
    except Exception as e:
        logging.error(f"Erreur génération QR code: {str(e)}")
        return None

def get_next_ip(provided_ip=None):
    try:
        base = "10.0.0."
        used_ips = [p['allowed_ips'].split('/')[0] for p in get_peers() if 'allowed_ips' in p]
        logging.debug(f"IPs utilisées: {used_ips}")
        if provided_ip and provided_ip.strip():
            provided_ip = provided_ip.strip().split('/')[0]
            if not provided_ip.startswith(base):
                logging.error(f"IP hors plage: {provided_ip}")
                return None
            if provided_ip in used_ips:
                logging.error(f"IP déjà utilisée: {provided_ip}")
                return None
            return f"{provided_ip}/32"
        for i in range(2, 255):
            ip = f"{base}{i}"
            if ip not in used_ips:
                logging.info(f"IP auto-attribuée: {ip}")
                return f"{ip}/32"
        logging.error("Plus d'IPs disponibles")
        return None
    except Exception as e:
        logging.error(f"Erreur get_next_ip: {str(e)}")
        return None

def get_peers():
    logging.info(f"Lecture de {WG_CONF}")
    peers = []
    if not os.path.exists(WG_CONF):
        logging.error(f"Fichier {WG_CONF} introuvable")
        return peers
    try:
        with open(WG_CONF, 'r') as f:
            lines = f.readlines()
        current_peer = {}
        for line in lines:
            line = line.strip()
            if not line:
                if current_peer.get('public_key') and current_peer.get('allowed_ips'):
                    current_peer.setdefault('name', 'Sans nom')
                    current_peer.setdefault('last_handshake', 'Jamais')
                    current_peer.setdefault('rx_bytes', '0')
                    current_peer.setdefault('tx_bytes', '0')
                    current_peer['enabled'] = False
                    peers.append(current_peer)
                    logging.debug(f"Peer ajouté: {current_peer}")
                current_peer = {}
                continue
            if line.startswith('#'):
                current_peer['name'] = line[1:].strip()
            elif line.startswith('PublicKey ='):
                current_peer['public_key'] = line.split('=', 1)[1].strip()
            elif line.startswith('AllowedIPs ='):
                current_peer['allowed_ips'] = line.split('=', 1)[1].strip()
        if current_peer.get('public_key') and current_peer.get('allowed_ips'):
            current_peer.setdefault('name', 'Sans nom')
            current_peer.setdefault('last_handshake', 'Jamais')
            current_peer.setdefault('rx_bytes', '0')
            current_peer.setdefault('tx_bytes', '0')
            current_peer['enabled'] = False
            peers.append(current_peer)
            logging.debug(f"Peer final ajouté: {current_peer}")
    except Exception as e:
        logging.error(f"Erreur lecture {WG_CONF}: {str(e)}")
        return peers
    try:
        result = subprocess.run(['wg', 'show', 'interfaces'], capture_output=True, text=True, check=True)
        if 'wg0' in result.stdout:
            result = subprocess.run(['wg', 'show', 'wg0', 'dump'], capture_output=True, text=True, check=True)
            lines = result.stdout.splitlines()
            for line in lines[1:]:
                fields = line.split('\t')
                if len(fields) < 8:
                    continue
                public_key = fields[0]
                for peer in peers:
                    if peer['public_key'] == public_key:
                        peer['last_handshake'] = fields[4] != "0" and humanize.naturaltime(datetime.fromtimestamp(int(fields[4]))) or "Jamais"
                        peer['rx_bytes'] = humanize.naturalsize(int(fields[5])) if fields[5] else "0"
                        peer['tx_bytes'] = humanize.naturalsize(int(fields[6])) if fields[6] else "0"
                        peer['enabled'] = True
                        logging.debug(f"Mise à jour peer {public_key[:16]}...: {peer}")
                        break
    except subprocess.CalledProcessError as e:
        logging.error(f"Erreur wg show: {e.stderr}")
    return peers

def get_peer_by_name(name):
    try:
        peers = get_peers()
        for peer in peers:
            if peer.get('name') == name:
                peer['public_key'] = peer.get('public_key', 'N/A')
                conf_path = os.path.join(PEERS_DIR, f"{name}.conf")
                if os.path.exists(conf_path):
                    with open(conf_path, 'r') as f:
                        peer['config_content'] = f.read()
                else:
                    peer['config_content'] = "Fichier non trouvé"
                return peer
        return None
    except Exception as e:
        logging.error(f"Erreur dans get_peer_by_name: {str(e)}")
        return None

def get_peer_by_public_key(key):
    try:
        logging.info(f"Début recherche peer avec clé: {key[:16]}...")
        if not key or len(key.strip()) != 44:
            logging.error("Clé publique invalide (longueur incorrecte)")
            return None
        key = key.strip()
        peers = get_peers()
        for peer in peers:
            peer_key = peer.get('public_key', '').strip()
            if peer_key == key:
                logging.info("Peer trouvé !")
                return {
                    'name': peer.get('name', 'Sans nom'),
                    'public_key': key,
                    'allowed_ips': peer.get('allowed_ips', 'N/A'),
                    'last_handshake': peer.get('last_handshake', 'Jamais'),
                    'rx_bytes': peer.get('rx_bytes', '0'),
                    'tx_bytes': peer.get('tx_bytes', '0'),
                    'enabled': peer.get('enabled', False)
                }
        logging.warning(f"Aucun peer ne correspond à cette clé: {key[:16]}...")
        return None
    except Exception as e:
        logging.error(f"Erreur dans get_peer_by_public_key: {str(e)}")
        return None

# Auth
def login_required(f):
    @wraps(f)
    def secured(*args, **kwargs):
        if 'logged_in' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return secured

def refresh_wireguard_config():
    try:
        with open(WG_CONF, 'r') as f:
            config = f.read()
        if '[Interface]' not in config:
            logging.warning("wg0.conf ne contient pas de section [Interface], impossible de redémarrer wg0")
            return True
        result = subprocess.run(['wg', 'show', 'interfaces'], capture_output=True, text=True, check=True)
        wg0_active = 'wg0' in result.stdout
        if wg0_active:
            try:
                subprocess.run(['wg-quick', 'down', 'wg0'], check=True, stderr=subprocess.PIPE)
                logging.debug("Interface wg0 arrêtée")
            except subprocess.CalledProcessError as e:
                logging.warning(f"Échec arrêt wg0: {e.stderr.decode()}")
        try:
            subprocess.run(['wg-quick', 'up', 'wg0'], check=True, stderr=subprocess.PIPE)
            logging.info("Configuration WireGuard rafraîchie")
            return True
        except subprocess.CalledProcessError as e:
            logging.error(f"Erreur démarrage wg0: {e.stderr.decode()}")
            return False
    except Exception as e:
        logging.error(f"Erreur rafraîchissement configuration: {str(e)}")
        return False

def remove_anonymous_peers():
    try:
        with open(WG_CONF, 'r') as f:
            lines = f.readlines()
        new_lines = []
        skip = False
        has_comment = False
        for line in lines:
            if line.strip().startswith("#"):
                has_comment = True
            if line.strip().startswith("[Peer]"):
                if not has_comment:
                    skip = True
                    continue
            if skip and line.strip() == "":
                skip = False
                has_comment = False
                continue
            if not skip:
                new_lines.append(line)
                if not line.strip():
                    has_comment = False
        with open(WG_CONF, 'w') as f:
            f.writelines(new_lines)
        logging.info("Blocs [Peer] anonymes supprimés de wg0.conf")
        return True
    except Exception as e:
        logging.error(f"Erreur suppression peers anonymes : {str(e)}")
        return False

def remove_peer(name):
    try:
        logging.info(f"Suppression du peer {name}")
        public_key = None
        with open(WG_CONF, 'r') as f:
            lines = f.readlines()
        new_lines = []
        skip = False
        inside_peer = False
        for i, line in enumerate(lines):
            if line.strip() == f"# {name}":
                skip = True
                inside_peer = True
                continue
            if skip and line.strip() == "":
                skip = False
                inside_peer = False
                continue
            if skip and "PublicKey =" in line and not public_key:
                public_key = line.split("=")[1].strip()
                public_key = public_key.strip()
                if len(public_key) != 44 or '+' in public_key or '/' in public_key:
                    logging.warning(f"Clé publique suspecte: {public_key}")
            if not skip:
                new_lines.append(line)
        with open(WG_CONF, 'w') as f:
            f.writelines(new_lines)
        logging.debug(f"Bloc du peer {name} supprimé de wg0.conf")
        for ext in [".conf", ".png"]:
            fpath = os.path.join(PEERS_DIR, f"{name}{ext}")
            if os.path.exists(fpath):
                os.remove(fpath)
                logging.debug(f"Fichier supprimé : {fpath}")
        if public_key and len(public_key) == 44:
            try:
                subprocess.run(['wg', 'set', 'wg0', 'peer', public_key, 'remove'], check=True, stderr=subprocess.PIPE)
                logging.debug(f"Peer {public_key[:16]}... supprimé en live de wg0")
            except subprocess.CalledProcessError as e:
                logging.warning(f"Suppression live échouée : {e.stderr.decode()}")
        else:
            logging.warning(f"Clé publique invalide, suppression via wg set ignorée: {public_key}")
        backup_peers("remove")
        remove_anonymous_peers()
        clean_orphan_files()
        return refresh_wireguard_config()
    except Exception as e:
        logging.error(f"Erreur dans remove_peer({name}): {str(e)}")
        return False

def toggle_peer(public_key, enable=True):
    peer = get_peer_by_public_key(public_key)
    if not peer:
        logging.error(f"Peer {public_key[:16]}... non trouvé")
        return False
    if enable:
        try:
            with open(WG_CONF, 'r') as f:
                config = f.read()
            if public_key not in config:
                with open(WG_CONF, 'a') as f:
                    f.write(f"\n# {peer['name']}\n[Peer]\nPublicKey = {public_key}\nPresharedKey = {peer.get('preshared_key', '')}\nAllowedIPs = {peer['allowed_ips']}\n")
                logging.debug(f"Peer {public_key[:16]}... activé dans {WG_CONF}")
        except Exception as e:
            logging.error(f"Erreur activation peer: {str(e)}")
            return False
    else:
        try:
            result = subprocess.run(['wg', 'show', 'interfaces'], capture_output=True, text=True, check=True)
            if 'wg0' in result.stdout:
                subprocess.run(['wg', 'set', 'wg0', 'peer', public_key, 'remove'], check=True)
                logging.debug(f"Peer {public_key[:16]}... retiré de l'interface wg0")
            with open(WG_CONF, 'r') as f:
                lines = f.readlines()
            with open(WG_CONF, 'w') as f:
                skip = False
                peer_found = False
                i = 0
                while i < len(lines):
                    line = lines[i]
                    if line.strip().startswith('PublicKey =') and public_key in line:
                        peer_found = True
                        skip = True
                        j = i - 1
                        while j >= 0 and lines[j].strip().startswith('#'):
                            j -= 1
                        i = j + 1
                        continue
                    if skip and (line.strip() == "" or line.startswith('[')):
                        skip = False
                    if not skip:
                        f.write(line)
                    i += 1
                if not peer_found:
                    logging.warning(f"Peer {public_key[:16]}... non trouvé dans {WG_CONF}")
                else:
                    logging.debug(f"Peer {public_key[:16]}... supprimé de {WG_CONF}")
        except subprocess.CalledProcessError as e:
            logging.error(f"Erreur désactivation peer: {e.stderr}")
            return False
        except Exception as e:
            logging.error(f"Erreur mise à jour {WG_CONF}: {str(e)}")
            return False
    backup_peers("toggle")  # Sauvegarde après activation/désactivation
    return refresh_wireguard_config()

def verify_peer_creation(name):
    try:
        if not os.path.exists(WG_CONF):
            return False
        with open(WG_CONF, 'r') as f:
            if f"# {name}" not in f.read():
                return False
        required_files = [
            os.path.join(PEERS_DIR, f"{name}.conf"),
            os.path.join(PEERS_DIR, f"{name}.png")
        ]
        return all(os.path.exists(f) for f in required_files)
    except Exception:
        return False

def reload_config():
    """Recharge la configuration depuis le fichier config.json"""
    global CONFIG, ADMIN_USER, ADMIN_PASS
    try:
        with open(CONFIG_PATH) as f:
            CONFIG = json.load(f)
        ADMIN_USER = CONFIG.get('username', 'admin')
        ADMIN_PASS = CONFIG.get('password', 'admin')
        logging.info("Configuration rechargée avec succès")
    except Exception as e:
        logging.error(f"Erreur rechargement config.json: {str(e)}")


# Routes

@app.route('/add', methods=['GET', 'POST'])
@login_required
def add():
    if request.method == 'POST':
        name = request.form.get('name', '').strip()
        ip = request.form.get('ip', '').strip() or None
        if not name:
            flash("Le nom du peer est requis.", "error")
            return redirect(url_for('index'))
        try:
            if add_peer(name, ip):
                if refresh_wireguard_config():
                    flash("Peer créé avec succès.", "info")
                else:
                    flash("Peer créé mais erreur de rafraîchissement", "error")
                return redirect(url_for('index'))
            else:
                flash("Échec de la création du peer.", "error")
        except Exception as e:
            logging.error(f"Erreur création peer: {str(e)}")
            flash(f"Erreur technique: {str(e)}", "error")
    return redirect(url_for('index'))

@app.after_request
def after_request(response):
    if response.status_code >= 400:
        logging.error(f"Erreur {response.status_code} : {request.method} {request.url}")
    return response

@app.route('/api/peer_details/<peer_name>')
@login_required
def api_peer_details(peer_name):
    try:
        logging.info(f"Requête API pour peer: {peer_name}")
        peer = get_peer_by_name(peer_name)
        if not peer:
            logging.warning(f"Peer non trouvé: {peer_name}")
            return jsonify({'error': f'Peer "{peer_name}" not found'}), 404
        qr_code = None
        if peer.get('config_content'):
            qr = qrcode.QRCode(version=1, box_size=10, border=4)
            qr.add_data(peer['config_content'])
            qr.make(fit=True)
            img = qr.make_image(fill_color="black", back_color="white")
            buffered = BytesIO()
            img.save(buffered, format="PNG")
            qr_code = base64.b64encode(buffered.getvalue()).decode('utf-8')
        response_data = {
            'name': peer.get('name', ''),
            'allowed_ips': peer.get('allowed_ips', ''),
            'last_handshake': peer.get('last_handshake', 'Jamais'),
            'rx_bytes': peer.get('rx_bytes', '0'),
            'tx_bytes': peer.get('tx_bytes', '0'),
            'enabled': peer.get('enabled', False),
            'public_key': peer.get('public_key', ''),
            'config_content': peer.get('config_content', ''),
            'qr_code': qr_code
        }
        logging.info(f"Réponse API pour {peer_name}: {len(response_data['config_content'])} caractères de config")
        return jsonify(response_data)
    except FileNotFoundError as e:
        logging.error(f"Fichier non trouvé pour peer {peer_name}: {str(e)}")
        return jsonify({'error': f'Configuration file for peer "{peer_name}" not found'}), 500
    except Exception as e:
        logging.error(f"Erreur dans api_peer_details: {str(e)}")
        return jsonify({'error': f'Internal server error: {str(e)}'}), 500

@app.route('/change_password', methods=['POST'])
@login_required
def change_password():
    if request.method == 'POST':
        new_password = request.form['new_password']
        CONFIG['password'] = new_password
        try:
            with open(CONFIG_PATH, 'w') as f:
                json.dump(CONFIG, f)
            # Recharger la configuration après modification
            reload_config()
            flash("Mot de passe mis à jour.", "info")
        except Exception as e:
            logging.error(f"Erreur mise à jour mot de passe: {str(e)}")
            flash("Erreur lors de la mise à jour du mot de passe.", "error")
        return redirect(url_for('index'))
    return render_template('index.html')

@app.route('/create_backup', methods=['POST'])
@login_required
def create_backup():
    try:
        if backup_peers("manual"):
            flash("Sauvegarde créée avec succès.", "info")
        else:
            flash("Échec de la création de la sauvegarde.", "error")
        return redirect(url_for('list_backups'))
    except Exception as e:
        logging.error(f"Erreur création backup : {str(e)}")
        flash(f"Erreur création sauvegarde : {str(e)}", "error")
        return redirect(url_for('list_backups'))

@app.route('/debug/api/peer/<peer_name>')
@login_required
def debug_api_peer(peer_name):
    try:
        peer = get_peer_by_name(peer_name)
        return f"<pre>{json.dumps(peer, indent=2)}</pre>" if peer else "Peer non trouvé"
    except Exception as e:
        return f"Erreur: {str(e)}"

@app.route('/debug/peers')
def debug_peers():
    peers = get_peers()
    return "<pre>" + "\n".join([str(p) for p in peers]) + "</pre>"

@app.route('/delete/<string:public_key>', methods=['POST'])
@login_required
def delete_peer(public_key):
    try:
        decoded_key = urllib.parse.unquote(public_key)
        peer = get_peer_by_public_key(decoded_key)
        if peer and remove_peer(peer['name']):
            flash("Peer supprimé.", "info")
        else:
            flash("Erreur lors de la suppression du peer.", "error")
    except Exception as e:
        logging.error(f"Erreur suppression peer: {str(e)}")
        flash(f"Erreur: {str(e)}", "error")
    return redirect(url_for('index'))

@app.route('/download_backup/<filename>')
@login_required
def download_backup(filename):
    try:
        if not filename.endswith('.zip') or '/' in filename or '\\' in filename:
            flash("Nom de fichier invalide", "error")
            return redirect(url_for("list_backups"))
        filepath = os.path.join(BACKUP_DIR, filename)
        if not os.path.exists(filepath):
            flash("Fichier de sauvegarde non trouvé", "error")
            return redirect(url_for("list_backups"))
        return send_from_directory(BACKUP_DIR, filename, as_attachment=True)
    except Exception as e:
        logging.error(f"Erreur téléchargement backup {filename}: {str(e)}")
        flash(f"Erreur téléchargement : {str(e)}", "error")
        return redirect(url_for("list_backups"))

@app.route('/download/<filename>')
@login_required
def download_peer_file(filename):
    try:
        if not filename.endswith(('.conf', '.png')) or '/' in filename or '\\' in filename:
            flash("Nom de fichier invalide", "error")
            return redirect(url_for("index"))
        filepath = os.path.join(PEERS_DIR, filename)
        if not os.path.exists(filepath):
            flash("Fichier non trouvé", "error")
            return redirect(url_for("index"))
        return send_from_directory(PEERS_DIR, filename, as_attachment=True)
    except Exception as e:
        logging.error(f"Erreur téléchargement {filename}: {str(e)}")
        flash(f"Erreur téléchargement : {str(e)}", "error")
        return redirect(url_for("index"))

@app.route('/')
@login_required
def index():
    try:
        wg_conf = "/etc/wireguard/wg0.conf"
        wg0_up = os.path.exists(wg_conf) and os.path.getsize(wg_conf) > 0
        peers = get_peers()
        for peer in peers:
            conf_path = os.path.join(PEERS_DIR, f"{peer['name']}.conf")
            if os.path.exists(conf_path):
                with open(conf_path, 'r') as f:
                    peer['config_content'] = f.read()
            else:
                peer['config_content'] = "Configuration non disponible"
        active_peers = sum(1 for p in peers if p.get("enabled"))
        default_peer = None
        if peers:
            default_peer = get_peer_by_name(peers[0].get('name'))
        return render_template(
            "index.html",
            peers=peers,
            wg0_up=wg0_up,
            active_peers=active_peers,
            default_peer=default_peer
        )
    except Exception as e:
        logging.error(f"Erreur dashboard: {str(e)}")
        flash("Erreur chargement du tableau de bord.", "error")
        return redirect(url_for("index"))

@app.route('/backups')
@login_required
def list_backups():
    try:
        os.makedirs(BACKUP_DIR, exist_ok=True)
        files = sorted([f for f in os.listdir(BACKUP_DIR) if f.endswith(".zip")], reverse=True)
        backups = [{
            "name": f.split(".zip")[0],
            "file": f,
            "date": datetime.fromtimestamp(os.path.getmtime(os.path.join(BACKUP_DIR, f))).strftime("%Y-%m-%d %H:%M")
        } for f in files]
        return render_template("backups.html", backups=backups)
    except Exception as e:
        logging.error(f"Erreur affichage backups : {str(e)}")
        flash(f"Erreur chargement des sauvegardes : {str(e)}", "error")
        return redirect(url_for("backups"))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        if request.form['username'] == ADMIN_USER and request.form['password'] == ADMIN_PASS:
            session['logged_in'] = True
            return redirect(url_for('index'))
        flash("Nom d'utilisateur ou mot de passe incorrect.", "error")
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))



@app.route('/peers')
@login_required
def peers_list():
    try:
        peers = get_peers()
        return render_template('index.html', peers=peers)
    except Exception as e:
        logging.error(f"Erreur dans peers_list(): {str(e)}")
        flash(f"Erreur inattendue: {str(e)}", "error")
        return redirect(url_for("index"))

@app.route('/restore_backup', methods=['POST'])
@login_required
def restore_backup():
    filename = request.form.get("filename")
    if not filename or not filename.endswith(".zip"):
        flash("Fichier invalide", "error")
        return redirect(url_for("list_backups"))
    try:
        zip_path = os.path.join(BACKUP_DIR, filename)
        if not os.path.exists(zip_path):
            flash("Fichier de sauvegarde non trouvé", "error")
            return redirect(url_for("list_backups"))
        # Vérifier le contenu de l'archive
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            file_list = zip_ref.namelist()
            if not any(f.startswith("peers/") or f == "wg0.conf" for f in file_list):
                flash("Archive invalide : ne contient pas de fichiers peers ou wg0.conf", "error")
                return redirect(url_for("list_backups"))
        # Sauvegarde avant restauration
        backup_peers("pre_restore")
        # Extraire l'archive
        shutil.unpack_archive(zip_path, BACKUP_DIR, 'zip')
        # Déplacer wg0.conf
        temp_wg_conf = os.path.join(BACKUP_DIR, "wg0.conf")
        if os.path.exists(temp_wg_conf):
            shutil.move(temp_wg_conf, WG_CONF)
        # Déplacer les fichiers peers
        temp_peers_dir = os.path.join(BACKUP_DIR, "peers")
        if os.path.exists(temp_peers_dir):
            shutil.rmtree(PEERS_DIR, ignore_errors=True)
            shutil.move(temp_peers_dir, PEERS_DIR)
        # Nettoyer les fichiers temporaires
        clean_orphan_files()
        if refresh_wireguard_config():
            flash("Sauvegarde restaurée avec succès", "info")
        else:
            flash("Sauvegarde restaurée mais erreur de rafraîchissement WireGuard", "error")
        return redirect(url_for("list_backups"))
    except Exception as e:
        logging.error(f"Erreur restauration backup : {str(e)}")
        flash(f"Erreur restauration : {str(e)}", "error")
        return redirect(url_for("list_backups"))

@app.route('/test_qr')
def test_qr():
    conf = """
[Interface]
PrivateKey = testkey
Address = 10.0.0.2/32
DNS = 1.1.1.1
[Peer]
PublicKey = testpubkey
Endpoint = 127.0.0.1:51820
AllowedIPs = 0.0.0.0/0
"""
    qr_code = generate_qr_code(conf)
    if qr_code:
        return f'<img src="data:image/png;base64,{qr_code}" alt="Test QR Code">'
    return "Erreur : QR code non généré"

@app.route('/toggle/<string:public_key>/<action>', methods=['POST'])
@login_required
def toggle(public_key, action):
    try:
        decoded_key = urllib.parse.unquote(public_key)
        enable = action == 'enable'
        result = toggle_peer(decoded_key, enable)
        flash(f"Peer {'activé' if enable else 'désactivé'}.", "info" if result else "error")
    except Exception as e:
        logging.error(f"Erreur toggle peer: {str(e)}")
        flash(f"Erreur: {str(e)}", "error")
    return redirect(url_for('index'))


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF
      echo_step_stop "$msg_install_create app.py ok"

      # Créer backups.html
      echo_step_start "$msg_install_create backups.html ..."
cat << 'EOF' > "$APP_DIR/templates/backups.html"
{% extends "base.html" %}
{% block title %}Sauvegardes Peers{% endblock %}
{% block content %}
<div class="container mt-4">
    <a href="{{ url_for('index') }}" class="btn btn-secondary mb-3">⬅ Retour</a>
    <div class="card p-4 shadow-sm">
        <div class="card-header bg-primary text-white d-flex justify-content-between align-items-center">
            <h3 class="card-title mb-0">Sauvegardes des Peers</h3>
            <form method="POST" action="{{ url_for('create_backup') }}" class="d-inline">
                <button type="submit" class="btn btn-light btn-sm">➕ Créer une sauvegarde</button>
            </form>
        </div>
        <!-- Messages Flash -->
        {% with messages = get_flashed_messages(with_categories=true) %}
            {% if messages %}
                {% for category, message in messages %}
                    <div class="alert alert-{{ 'success' if category == 'info' else 'danger' }} alert-dismissible fade show mt-3" role="alert">
                        {{ message }}
                        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Fermer"></button>
                    </div>
                {% endfor %}
            {% endif %}
        {% endwith %}
        {% if backups %}
            <table class="table table-hover mt-3">
                <thead>
                    <tr>
                        <th>Nom</th>
                        <th>Date</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                {% for b in backups %}
                    <tr>
                        <td>{{ b.name }}</td>
                        <td>{{ b.date }}</td>
                        <td>
                            <a href="{{ url_for('download_backup', filename=b.file) }}" class="btn btn-sm btn-outline-primary">⬇ Télécharger</a>
                            <form method="POST" action="{{ url_for('restore_backup') }}" class="d-inline">
                                <input type="hidden" name="filename" value="{{ b.file }}">
                                <button type="submit" class="btn btn-sm btn-outline-success" onclick="return confirm('Restaurer cette sauvegarde ? Cela écrasera les configurations actuelles.')">♻ Restaurer</button>
                            </form>
                        </td>
                    </tr>
                {% endfor %}
                </tbody>
            </table>
        {% else %}
            <div class="alert alert-info mt-3">Aucune sauvegarde disponible.</div>
        {% endif %}
    </div>
</div>
{% endblock %}
EOF
      echo_step_stop "$msg_install_create backups.html ok"

      # Créer base.html si absent
      echo_step_start "$msg_install_create base.html ..."
cat << 'EOF' > "$APP_DIR/templates/base.html"
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>{% block title %}WireGuard UI{% endblock %}</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
  {% block head_extra %}
  {% endblock %}
    <style>
        /* Style personnalisé pour la scrollbar */
        .table-responsive::-webkit-scrollbar {
            width: 8px;
            height: 8px;
        }
        .table-responsive::-webkit-scrollbar-thumb {
            background: #adb5bd; /* Couleur grise Bootstrap */
            border-radius: 4px;
        }
        .table-responsive::-webkit-scrollbar-track {
            background: #f8f9fa; /* Couleur de fond claire */
        }
        /* Fix pour l'en-tête sticky */
        .table-responsive thead th {
            position: sticky;
            top: 0;
            z-index: 10;
            background: white;
            box-shadow: 0 2px 2px -1px rgba(0,0,0,0.1);
        }
        .custom-card-width {
            max-width: 400px;
            width: 100%;
        }
        .password-change-section {
            margin-top: 2rem;
            padding: 1.5rem;
            background: #f8f9fa;  /* Optionnel : fond légèrement grisé */
            border-radius: 8px;
        }
        .peer-row {
            cursor: pointer;
            transition: background-color 0.2s;
        }
        .peer-row:hover {
            background-color: #f8f9fa;
        }
        .peer-row.table-active {
            background-color: #e9f7fe !important;
        }
    </style>
</head>
<body class="bg-light">
  <div class="container mt-4">
    {% block content %}
    <!-- Le contenu spécifique de chaque page viendra ici -->
    {% endblock %}
  </div>
  <!-- Toast -->
  <div class="position-fixed bottom-0 end-0 p-3" style="z-index: 9999">
    <div id="liveToast" class="toast align-items-center text-white bg-success border-0" role="alert" aria-live="assertive" aria-atomic="true">
      <div class="d-flex">
        <div class="toast-body" id="toast-message">
          OK
        </div>
        <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast" aria-label="Fermer"></button>
      </div>
    </div>
  </div>
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
  <!-- Toast management -->
  <script>
    document.addEventListener("DOMContentLoaded", function () {
      const toastEl = document.getElementById('liveToast');
      const toastMessage = document.getElementById('toast-message');

      {% with messages = get_flashed_messages(with_categories=true) %}
      {% if messages %}
          {% for category, message in messages %}
              toastMessage.textContent = "{{ message }}";
              toastEl.classList.remove('bg-success', 'bg-danger');
              toastEl.classList.add("{{ 'bg-success' if category == 'info' else 'bg-danger' }}");
              const toast = new bootstrap.Toast(toastEl);
              toast.show();
          {% endfor %}
      {% endif %}
      {% endwith %}
    });
  </script>
  {% block scripts %}{% endblock %}
</body>
</html>
EOF
      echo_step_stop "$msg_install_create base.html ok"

      # Créer index.html si absent
      echo_step_start "$msg_install_create index.html ..."
cat << 'EOF' > "$APP_DIR/templates/index.html"
{% extends "base.html" %}
{% block title %}Liste des Peers{% endblock %}
{% block content %}
<h3>Dashboard WireGuard-UI NRX800</h3>
<!-- Ligne 1 : Cartes horizontales -->
<div class="d-flex flex-wrap gap-4 mb-4">
    <!-- Carte Statut -->
    <div class="card p-4 shadow-sm flex-fill" style="min-width: 250px; max-width: 300px;">
        <div class="d-flex flex-column gap-3">
            <div class="card p-2 bg-primary text-white shadow-sm">
                <h5>🌐 Tunnel : {{ 'Actif' if wg0_up else 'Inactif' }}</h5>
            </div>
            <div class="card p-2 bg-warning text-white shadow-sm">
                <h5>📶 Actifs : {{ active_peers }}</h5>
            </div>
            <div class="card p-2 bg-success text-white shadow-sm">
                <h5>👥 Total : {{ peers|length }}</h5>
            </div>
        </div>
    </div>
    <!-- Formulaire Ajout Peer -->
    <form method="POST" action="{{ url_for('add') }}" class="card p-4 shadow-sm flex-fill" style="min-width: 250px; max-width: 330px;">
        <div class="mb-1">
            <label for="name" class="form-label">Nom</label>
            <input type="text" id="name" name="name" class="form-control" required>
        </div>
        <div class="mb-2">
            <label for="ip" class="form-label">IP (automatique si vide)</label>
            <input type="text" id="ip" name="ip" class="form-control" placeholder="ex: 10.0.0.3">
        </div>
        <button type="submit" class="btn btn-primary w-100">➕ Ajouter un Peer</button>
    </form>
    <!-- Formulaire Changement MDP -->
    <form method="POST" action="{{ url_for('change_password') }}" class="card p-4 shadow-sm flex-fill" style="min-width: 250px; max-width: 330px;">
        <div class="mb-3">
            <label for="new_password" class="form-label">Nouveau mot de passe</label>
            <input type="password" id="new_password" name="new_password" class="form-control" required minlength="6">
        </div>
        <button type="submit" class="btn btn-primary w-100">🔐 Changer MDP</button>
    </form>
    <!-- Carte Actions -->
    <div class="card p-4 shadow-sm flex-fill" style="min-width: 250px; max-width: 220px;">
        <div class="d-flex flex-column gap-3">
            <a href="{{ url_for('list_backups') }}" class="btn btn-outline-info">💾 Sauvegardes</a>
            <a href="{{ url_for('logout') }}" class="btn btn-outline-danger">🚪 Déconnexion</a>
        </div>
    </div>
</div>
<!-- Messages Flash -->
{% with messages = get_flashed_messages(with_categories=true) %}
    {% if messages %}
        {% for category, message in messages %}
            <div class="alert alert-{{ 'success' if category == 'info' else 'danger' }} alert-dismissible fade show" role="alert">
                {{ message }}
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Fermer"></button>
            </div>
        {% endfor %}
    {% endif %}
{% endwith %}
<!-- Ligne 2 : Détails du Peer Sélectionné -->
<div id="peerDetails" class="card mb-4 p-4 shadow-sm" style="display: none;">
    <h5 class="mb-3">🔍 Détails du Peer (Configuration Client pour connexion au serveur et QR Code)</h5>
    <div id="peerDetailsContent">
        <!-- Contenu chargé dynamiquement -->
    </div>
</div>
<!-- Ligne 3 : Tableau des Peers -->
{% if peers %}
    <h3 class="mb-3">Liste des Peers</h3>
    <div class="table-responsive" style="max-height: 400px; overflow-y: auto;">
        <table class="table table-hover align-left table-bordered">
            <thead class="table-light position-sticky top-0 bg-light">
                <tr>
                    <th>Nom</th>
                    <th>IP</th>
                    <th>Dernier Handshake</th>
                    <th>RX</th>
                    <th>TX</th>
                    <th>Clé Publique</th>
                    <th>Copie</th>
                    <th>Configuration</th>
                    <th>QR Code</th>
                    <th>État</th>
                    <th>Effacer</th>
                </tr>
            </thead>
            <tbody>
                {% for peer in peers %}
                <tr class="peer-row" data-peer-name="{{ peer.name }}">
                    <td>{{ peer.name }}</td>
                    <td>{{ peer.allowed_ips }}</td>
                    <td>{{ peer.last_handshake }}</td>
                    <td>{{ peer.rx_bytes }}</td>
                    <td>{{ peer.tx_bytes }}</td>
                    <td><code>{{ peer.public_key }}</code>
                    <td><button class="btn btn-outline-secondary btn-sm copy-config-detail" data-config="${peerData.public_key || ''}">🔑</button></td>
                    <td>
                        <a href="{{ url_for('download_peer_file', filename=peer.name ~ '.conf') }}" class="btn btn-primary btn-sm" onclick="event.stopPropagation()"> ⬇ ️.conf</a>
                        <button class="btn btn-outline-secondary btn-sm copy-config" data-peer-name="{{ peer.name }}" onclick="event.stopPropagation()">📋 Copier</button>
                    </td>
                    <td>
                        <a href="{{ url_for('download_peer_file', filename=peer.name ~ '.png') }}" class="btn btn-success btn-sm" onclick="event.stopPropagation()">⬇️ QR</a>
                    </td>
                    <td>
                        <form method="POST" action="{{ url_for('toggle', public_key=peer.public_key | urlencode, action='enable' if not peer.enabled else 'disable') }}" class="d-inline">
                            <button type="submit" class="btn btn-sm {{ 'btn-success' if peer.enabled else 'btn-secondary' }}" title="{{ 'Actif' if peer.enabled else 'Inactif' }}" onclick="event.stopPropagation()">
                                {{ '✅' if peer.enabled else '❌' }}
                            </button>
                        </form>
                    </td>
                    <td class="d-flex flex-wrap gap-2">
                        <form method="POST" action="{{ url_for('delete_peer', public_key=peer.public_key | urlencode) }}" class="d-inline" onclick="event.stopPropagation()">
                            <button type="submit" class="btn btn-danger btn-sm" onclick="return confirm('Supprimer ce peer ?')">🗑️</button>
                        </form>
                    </td>
                </tr>
                {% endfor %}
            </tbody>
        </table>
    </div>
{% else %}
    <div class="alert alert-info">Aucun peer configuré.</div>
{% endif %}
{% endblock %}
{% block scripts %}
<script>
// Fonction pour récupérer les détails d'un peer
async function fetchPeerDetails(peerName) {
    try {
        console.log('Récupération des détails pour:', peerName);
        const response = await fetch(`/api/peer_details/${encodeURIComponent(peerName)}`);
        if (!response.ok) {
            throw new Error(`Erreur HTTP: ${response.status}`);
        }
        const peerData = await response.json();
        console.log('Données reçues:', peerData);
        // Affichage de la section détails
        const peerDetailsSection = document.getElementById('peerDetails');
        peerDetailsSection.style.display = 'block';
        // Construction du contenu HTML avec QR code
        const detailsContent = `
            <div class="mt-2 row">

                <!-- Partie Configuration (7/12) -->
                <div class="col-md-6">
                    <pre class="bg-light p-2 rounded"><code>${peerData.config_content || 'Configuration non disponible'}</code></pre>
                </div>
                <!-- Partie QR Code (5/12) -->
                <div class="col-md-6">
                    ${peerData.qr_code ? `
                    <div class="text-center">
                        <img src="data:image/png;base64,${peerData.qr_code}" alt="QR Code" class="img-fluid" style="max-width: 200px;">
                    </div>` : '<p class="text-center">QR Code non disponible</p>'}
<p><small><strong>Note :</strong> La clé publique dans la section [Peer] est celle du serveur, utilisée pour la connexion.</small></p>
                </div>
            </div>
        `;
        document.getElementById('peerDetailsContent').innerHTML = detailsContent;
        // Mise à jour des classes CSS pour montrer la ligne active
        document.querySelectorAll('.peer-row').forEach(row => {
            row.classList.remove('table-active');
        });
        const activeRow = document.querySelector(`.peer-row[data-peer-name="${peerName}"]`);
        if (activeRow) {
            activeRow.classList.add('table-active');
        }
        // Scroll vers les détails
        peerDetailsSection.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    } catch (error) {
        console.error('Erreur lors de la récupération des détails:', error);
        const peerDetailsSection = document.getElementById('peerDetails');
        peerDetailsSection.style.display = 'block';
        document.getElementById('peerDetailsContent').innerHTML = `
            <div class="alert alert-danger">
                <strong>Erreur :</strong> Impossible de charger les détails du peer "${peerName}". 
                <br><small>Détail: ${error.message}</small>
            </div>
        `;
    }
}
// Fonction pour copier la configuration
function copyToClipboard(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text)
            .then(() => {
                showToast('Configuration copiée !', 'success');
            })
            .catch(err => {
                console.error('Erreur lors de la copie:', err);
                showToast('Erreur lors de la copie', 'error');
            });
    } else {
        const textArea = document.createElement('textarea');
        textArea.value = text;
        document.body.appendChild(textArea);
        textArea.select();
        try {
            document.execCommand('copy');
            showToast('Configuration copiée !', 'success');
        } catch (err) {
            showToast('Erreur lors de la copie', 'error');
        }
        document.body.removeChild(textArea);
    }
}
// Fonction pour afficher un toast
function showToast(message, type = 'success') {
    const toastEl = document.getElementById('liveToast');
    const toastMessage = document.getElementById('toast-message');
    toastMessage.textContent = message;
    toastEl.classList.remove('bg-success', 'bg-danger');
    toastEl.classList.add(type === 'success' ? 'bg-success' : 'bg-danger');
    const toast = new bootstrap.Toast(toastEl);
    toast.show();
}
// Initialisation au chargement de la page
document.addEventListener('DOMContentLoaded', function() {
    console.log('Page chargée, initialisation des événements...');
    // Gestion du clic sur une ligne du tableau
    document.querySelectorAll('.peer-row').forEach(row => {
        row.addEventListener('click', function(e) {
            if (e.target.tagName === 'BUTTON' || 
                e.target.tagName === 'A' || 
                e.target.closest('button, a, form')) {
                return;
            }
            const peerName = this.getAttribute('data-peer-name');
            console.log('Clic sur peer:', peerName);
            fetchPeerDetails(peerName);
        });
    });
    // Gestion des boutons de copie dans le tableau
    document.querySelectorAll('.copy-config').forEach(button => {
        button.addEventListener('click', async function(e) {
            e.stopPropagation();
            const peerName = this.getAttribute('data-peer-name');
            try {
                const response = await fetch(`/api/peer_details/${encodeURIComponent(peerName)}`);
                const peerData = await response.json();
                copyToClipboard(peerData.config_content || '');
            } catch (error) {
                console.error('Erreur:', error);
                showToast('Erreur lors de la récupération de la configuration', 'error');
            }
        });
    });
    // Gestion des boutons de copie dans les détails
    document.addEventListener('click', function(e) {
        if (e.target.classList.contains('copy-config-detail')) {
            e.preventDefault();
            const config = e.target.getAttribute('data-config');
            copyToClipboard(config);
        }
    });
    // Charger automatiquement les détails du premier peer
    {% if peers and peers|length > 0 %}
    const firstPeerName = '{{ peers[0].name }}';
    console.log('Chargement automatique du premier peer:', firstPeerName);
    fetchPeerDetails(firstPeerName);
    {% endif %}
});
</script>
{% endblock %}
EOF
      echo_step_stop "$msg_install_create index.html"

      # Créer login.html
      echo_step_start "$msg_install_create login.html ..."
cat << 'EOF' > "$APP_DIR/templates/login.html"
{% extends "base.html" %}
{% block title %}Connexion{% endblock %}
{% block content %}
<div class="container mt-5" style="max-width: 450px;">  <!-- Largeur maximale définie ici -->
    <div class="row justify-content-center">
        <div class="col-12">  <!-- Colonne prenant toute la largeur du container réduit -->
            <div class="card shadow-sm">
                <div class="card-header bg-primary text-white">
                    <h3 class="mb-0">WireGuard-UI pour NRX800</h3>
                </div>
                <div class="card-body">
                    {% with messages = get_flashed_messages(with_categories=true) %}
                        {% if messages %}
                            {% for category, message in messages %}
                                <div class="alert alert-{{ 'danger' if category == 'error' else 'info' }} alert-dismissible fade show" role="alert">
                                    {{ message }}
                                    <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Fermer"></button>
                                </div>
                            {% endfor %}
                        {% endif %}
                    {% endwith %}
                    <form method="POST" action="{{ url_for('login') }}">
                        <div class="mb-3">
                            <label for="username" class="form-label">Nom d'utilisateur</label>
                            <input type="text" class="form-control" id="username" name="username" required>
                        </div>
                        <div class="mb-3">
                            <label for="password" class="form-label">Mot de passe</label>
                            <input type="password" class="form-control" id="password" name="password" required>
                        </div>
                        <button type="submit" class="btn btn-primary w-100">🔐 Connexion</button>
                    </form>
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}
EOF
      echo_step_stop "$msg_install_create login.html ok"

      # Créer config.json
      echo_step_start "$msg_install_create config.json ..."
      sudo tee /opt/wireguard-ui/config.json > /dev/null <<EOF
{
 "username": "admin",
 "password": "admin"
}
EOF
      sudo chmod 600 /opt/wireguard-ui/config.json
      echo_step_stop "$msg_install_create config.json ok"

      # Créer wg0.con si absent
      if [ ! -f "/etc/wireguard/wg0.conf" ]; then
          echo_step_start "$msg_install_create wg0.conf ..."
          PRIVATE_KEY=$(wg genkey)
          PUBLIC_KEY=$(echo "$PRIVATE_KEY" | wg pubkey)
          echo "$PRIVATE_KEY" > /etc/wireguard/server_private.key
          echo "$PUBLIC_KEY" > /etc/wireguard/server_public.key
          cat << EOF > /etc/wireguard/wg0.conf
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = $PRIVATE_KEY
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF
          chmod 600 /etc/wireguard/wg0.conf /etc/wireguard/server_private.key
          echo_step_stop "$msg_install_create wg0.conf ok"
      fi


      # Activer le transfert IP
      echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf >/dev/null 2>&1
      sysctl -p >/dev/null 2>&1

      # Créer le service systemd
      echo_step_start "$msg_install_create_service"
      cat << EOF > /etc/systemd/system/wireguard-ui.service
  [Unit]
  Description=WireGuard-UI
  After=network.target

  [Service]
  ExecStart=/usr/bin/python3 $APP_DIR/app.py
  WorkingDirectory=$APP_DIR
  Restart=always
  User=root

  [Install]
  WantedBy=multi-user.target
  EOF
      echo_step_stop "$msg_install_create_service ok"

      # Ajouter un délai de redémarrage 
      mkdir -p /etc/systemd/system/wireguard-ui.service.d >/dev/null 2>&1
      tee /etc/systemd/system/wireguard-ui.service.d/override.conf >/dev/null <<EOF
  [Service]
  RestartSec=5s
EOF

      # Démarrer le service
      echo_step_start "$msg_install_start_service"
      systemctl daemon-reload >/dev/null 2>&1
      systemctl enable wireguard-ui >/dev/null 2>&1
      systemctl start wireguard-ui >/dev/null 2>&1
      echo_step_stop "$msg_install_start_service ok"

      # Activer WireGuard
      systemctl enable wg-quick@wg0 >/dev/null 2>&1
      systemctl start wg-quick@wg0 >/dev/null 2>&1

      # Configurer les permissions
      chown -R root:root "$APP_DIR" /etc/wireguard >/dev/null 2>&1
      chmod -R 755 "$APP_DIR" >/dev/null 2>&1
      chmod -R 600 /etc/wireguard/peers /etc/wireguard/wg0.conf /etc/wireguard/server_private.key >/dev/null 2>&1

      echo_step_end_with_success "$msg_install ok"
      echo_process_stop "WireGuard-UI - NRX800"
      echo_msgbox "$msg_install_success\n\n$msg_access_to"
    else
      echo_msgbox "$msg_yet_installed\n\n$msg_access_to"
    fi  
  fi

  # === DÉSINSTALLATION ===
  if [ "$G_CHOICE" = "D" ]; then

    if [ -f "/etc/systemd/system/wireguard-ui.service" ]; then
      echo_process_start "WireGuard-UI - NRX800"
      
      echo_step_info "$msg_uninstall"

      # Stop et désactive les services
      echo_step_start "$msg_service_stop ..."
      systemctl stop wireguard-ui >/dev/null 2>&1 || true
      systemctl disable wireguard-ui >/dev/null 2>&1 || true
      systemctl stop wg-quick@wg0 >/dev/null 2>&1 || true
      systemctl disable wg-quick@wg0 >/dev/null 2>&1 || true
      echo_step_stop "$msg_service_stop ok "

      # Supprimer les fichiers et repértoire
      echo_step_start "$msg_file_remove ..."
      rm -f /etc/systemd/system/wireguard-ui.service >/dev/null 2>&1
      rm -rf /opt/wireguard-ui >/dev/null 2>&1
      rm -rf /etc/wireguard/peers >/dev/null 2>&1
      rm -rf /etc/wireguard/backups >/dev/null 2>&1
      rm -f /etc/wireguard/wg0.conf >/dev/null 2>&1
      rm -f /etc/wireguard/server_private.key >/dev/null 2>&1
      rm -f /etc/wireguard/server_public.key >/dev/null 2>&1
      rm -f ~/wireguard-ui.log >/dev/null 2>&1
      echo_step_stop "$msg_file_remove ok "

      # Supprime l'IP forwarding
      echo_step_start "$msg_disable_ip_forward ..."
      sed -i '/net.ipv4.ip_forward=1/d' /etc/sysctl.conf >/dev/null 2>&1
      sysctl -p >/dev/null 2>&1
      echo_step_stop "$msg_disable_ip_forward ok"

      # Supprimer les dependences
      echo_step_start "$msg_remove_dependencies ..."
      apt-get remove -y python3-pip unzip wireguard >/dev/null 2>&1
      pip3 uninstall -y flask qrcode humanize >/dev/null 2>&1
      apt-get autoremove -y >/dev/null 2>&1
      echo_step_stop "$msg_remove_dependencies ok "

      # Nettoie systemd
      echo_step_start "$msg_clean_systemd ..."
      systemctl daemon-reload >/dev/null 2>&1
      systemctl reset-failed >/dev/null 2>&1
      echo_step_stop "$msg_clean_systemd ok"

      echo_step_end_with_success "$msg_uninstall ok"
      echo_process_stop "WireGuard-UI - NRX800"
      echo_msgbox "$msg_uninstall_success"
    else
      echo_msgbox "$msg_not_installed_cancel"
    fi

  fi

}





##########   MENU PILOTES - DRIVERS

# Fonction pour le menu des pilotes
# Function for the drivers menu
function menu_5_drivers() {

  # Définir les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_ok="Suivant"
    local msg_custom_command_prompt="Voulez-vous modifier les paramètres de création du pilote ? (Laissez vide pour utiliser les paramètres par défaut)"
    local msg_driver_install_error="Erreur lors de l'installation de $driver_name."
    local msg_driver_install_success="Le pilote $driver_name a été installé avec succès."
    local msg_driver_not_installed_cancel="Le pilote $driver_name n'est pas installé, désinstallation annulée."
    local msg_driver_not_installed="$driver_name n'est pas installé. Installation en cours..."
    local msg_driver_type="le pilote"
    local msg_driver_uninstall_error="Erreur lors de la désinstallation de $driver_name."
    local msg_driver_uninstall_success="Le pilote $driver_name a été désinstallé avec succès."
    local msg_driver_yet_installed="Le pilote $driver_name est déjà installé."
    local msg_error_message="Une erreur s'est produite"
		  local msg_list_driver_processing="Analyse des pilotes..."
    local msg_message="\nSélectionnez les pilotes à installer ou désinstaller :"
    local msg_no_selection="Aucun pilote sélectionné. Veuillez sélectionner au moins un pilote."
    local msg_status_installed="installé"
    local msg_status_not_installed="non installé"
    local msg_title="$G_TITLE - Gestion des Pilotes"
  else
    local msg_button_cancel="Back"
    local msg_button_ok="Next"
    local msg_custom_command_prompt="Do you want to modify the driver creation parameters? (Leave empty to use default parameters)"
    local msg_driver_install_error="Error installing $driver_name."
    local msg_driver_install_success="The driver $driver_name has been installed successfully."
    local msg_driver_not_installed_cancel="The driver $driver_name is not installed, uninstall canceled."
    local msg_driver_not_installed="$driver_name is not installed. Installing now..."
    local msg_driver_type="the driver"
    local msg_driver_uninstall_error="Error uninstalling $driver_name."
    local msg_driver_uninstall_success="The driver $driver_name has been uninstalled successfully."
    local msg_driver_yet_installed="The driver $driver_name is already installed."
    local msg_error_message="An error occurred"
		  local msg_list_driver_processing="Analyzing drivers..."
    local msg_message="\nSelect drivers to install or uninstall :"
    local msg_no_selection="No driver selected. Please select at least one driver."
    local msg_status_installed="installed"
    local msg_status_not_installed="not installed"
    local msg_title="$G_TITLE - Driver Management"
  fi

  # Affiche dans le terminal le début du traitement
  echo_process_start "$msg_list_driver_processing"
  
  # Trier la liste des pilotes par ordre alphabétique
  local sorted_list=($(echo "${!G_DRIVER_COMMANDS[@]}" | tr ' ' '\n' | sort))

  # Créer la liste des pilotes à installer
  local max_length=58
  local options=()
  
  for list_name in "${sorted_list[@]}"; do

    local command="${G_DRIVER_COMMANDS[$list_name]}"

    # Affiche dans le terminal le début de l'étape en cours
    echo_step_start "$msg_list_container_check $list_name"

    # Vérifier si le pilote est installé
    if [ "$list_name" = "gpio" ]; then
        if lsmod | grep -q gpio_bcm2835 && lsmod | grep -q "gpio_bcm2835"; then
          status="$msg_status_installed"
        else
          status="$msg_status_not_installed"
        fi
    fi
    if [ "$list_name" = "gpio-remote" ]; then
        if command -v pigpiod &> /dev/null; then
          status="$msg_status_installed"
        else
          status="$msg_status_not_installed"
        fi
    fi
    if [ "$list_name" = "i2c" ]; then
        if lsmod | grep -q i2c_dev && lsmod | grep -q "i2c-dev"; then
          status="$msg_status_installed"
        else
          status="$msg_status_not_installed"
        fi
    fi
    if [ "$list_name" = "rtc" ]; then
        if lsmod | grep -q rtc_pcf85063 && lsmod | grep -q "rtc_pcf85063"; then
          status="$msg_status_installed"
        else
          status="$msg_status_not_installed"
        fi
    fi
    if [ "$list_name" = "ov_bt" ]; then
        if grep -q "dtoverlay=disable-bt" /boot/config.txt; then
          status="$msg_status_installed"
        else
          status="$msg_status_not_installed"
        fi
    fi
    if [ "$list_name" = "ov_i2c_rtc" ]; then
        if grep -q "dtoverlay=i2c-rtc,pcf85063a,i2c_csi_dsi,addr=0x51" /boot/config.txt; then
          status="$msg_status_installed"
        else
          status="$msg_status_not_installed"
        fi
    fi
    if [ "$list_name" = "ov_vc4_kms_v3d" ]; then
        if grep -q "dtoverlay=vc4-kms-v3d" /boot/config.txt; then
          status="$msg_status_installed"
        else
          status="$msg_status_not_installed"
        fi
    fi

    # Calculer la longueur de l'information à afficher
    local info_length=$(( ${#list_name} + ${#status} ))

    # Calculer le nombre de points à ajouter
    local dots_length=$((max_length - info_length))
    if [ $dots_length -lt 0 ]; then
      dots_length=0
    fi
    local dots
    dots=$(printf "%${dots_length}s" "" | tr ' ' '.')

    # Ajouter l'information formatée à la liste des options
    options+=("$list_name" "$list_name $dots $status " OFF)

    # Affiche dans le terminal la fin de l'étape en cours
    echo_step_stop "$msg_list_container_check $list_name"
    
  done

  # Affiche dans le terminal la fin du traitement
  echo_process_stop "$msg_button_cancel $G_TITLE"

  # Calculer la hauteur du menu en fonction du nombre d'éléments
  local num_items=${#sorted_list[@]}
  if (( num_items > 10 )); then
    num_items=10
  fi
  local menu_height=$((10 + num_items))

  # Afficher le menu
  local choice_menu
  choice_menu=$(whiptail --checklist "$msg_message" $menu_height 75 $num_items "${options[@]}" --fb --title "$msg_title" --notags --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)

  # Obtenir le statut de sortie
  local exit_status=$?

  # Si l'utilisateur annule, retourner au menu principal
  if [ $exit_status -eq 1 ]; then
    return 0
  fi

  # Si l'utilisateur sélectionne "Suivant"
  if [ $exit_status -eq 0 ]; then
    # Si aucun pilote n'est sélectionné, afficher un message d'erreur
    if [ -z "$choice_menu" ]; then
      echo_msgbox "$msg_no_selection" "$msg_title"
    else
      # Traiter les pilotes sélectionnés
      selected_drivers=($(echo "$choice_menu" | tr -d '"' | tr ' ' ','))
      for selected in "${selected_drivers[@]}"; do
        selected=$(echo "$selected" | tr -d '"')
        command_name="${G_DRIVER_COMMANDS[$selected]}"
        if [ -n "$command_name" ]; then
          $command_name "$selected"
        else
          echo_msgbox "$msg_no_selection" "$msg_title"
        fi
      done
      sleep 5
    fi
  else
    echo_msgbox "$msg_error_message" "$msg_title"
    return 1
  fi

}

# Fonction pour le menu des pilotes
# Function for the drivers menu
function menu_5_drivers_1_install_uninstall() {

  # Récuprèe les paramètres
  local driver_name=$1
  local driver_default_command=$2

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_driver_custom_command_prompt="Voulez-vous modifier les paramètres de création du pilote ? (Laissez vide pour utiliser les paramètres par défaut)"
    local msg_driver_install_error="Erreur lors de l'installation de $driver_name."
    local msg_driver_install_success="$driver_name a été installé avec succès."
    local msg_driver_not_installed_cancel="$driver_name n'est pas installé, désinstallation annulée."
    local msg_driver_not_installed="$driver_name n'est pas installé. Installation en cours..."
    local msg_driver_type="le pilote"
    local msg_driver_uninstall_error="Erreur lors de la désinstallation de $driver_name."
    local msg_driver_uninstall_success="$driver_name a été désinstallé avec succès."
    local msg_driver_yet_installed="$driver_name est déjà installé."
  else
    local msg_driver_custom_command_prompt="Do you want to modify the driver creation parameters? (Leave empty to use default parameters)"
    local msg_driver_install_error="Error installing $driver_name."
    local msg_driver_install_success="$driver_name has been installed successfully."
    local msg_driver_not_installed_cancel="$driver_name is not installed, uninstall canceled."
    local msg_driver_not_installed="$driver_name is not installed. Installing now..."
    local msg_driver_type="the driver"
    local msg_driver_uninstall_error="Error uninstalling $driver_name."
    local msg_driver_uninstall_success="$driver_name has been uninstalled successfully."
    local msg_driver_yet_installed="$driver_name is already installed."
  fi

  # Appel de la fonction pour afficher le menu de gestion des pilotes
  menu_0_main_menu_action "$msg_driver_type" "$driver_name"

  # Vérifie si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" == "A" ]; then
    return 0
  fi

  # Si l'utilisateur choisit d'installer
  if [ "$G_CHOICE" == "I" ]; then

    echo_msgbox "$driver_name"

    # Vérifie si le paquet n'est pas déjà installé
    if ! dpkg -s "$msg_driver_type // $driver_name" &> /dev/null; then

      # Affiche un message indiquant que le pilote n'est pas installé
      echo_msgbox "$msg_driver_not_installed"

      # Demande à l'utilisateur de saisir une commande personnalisée pour l'installation
      local custom_command
      custom_command=$(whiptail --inputbox "\n$msg_driver_custom_command_prompt" 20 70 "$driver_default_command" --fb --title "$G_TITLE" --ok-button "Ok" --cancel-button "Cancel" 3>&1 1>&2 2>&3)
      # Si l'utilisateur annule la saisie de la commande
      if [ $? -ne 0 ]; then
        return 1
      fi

      # Si l'utilisateur n'a pas saisi de commande personnalisée, utilise la commande par défaut
      if [ -z "$custom_command" ]; then
        custom_command="$driver_default_command"
      fi

      # Exécute la commande d'installation
      eval "$custom_command"

      # Vérifie si l'installation a réussi
      if [ $? -eq 0 ]; then
        # Affiche un message de succès
        echo_msgbox "$msg_driver_install_success"
      else
        # Affiche un message d'erreur
        echo_msgbox "$msg_driver_install_error"
        return 1
      fi
    else
      # Affiche un message indiquant que le pilote est déjà installé
      echo_msgbox "$msg_driver_yet_installed"
    fi

  fi

  # Si l'utilisateur choisit de désinstaller
  if [ "$G_CHOICE" == "D" ]; then

    # Vérifie si le paquet est installé
    if dpkg -s "$driver_name" &> /dev/null; then
      # Désinstalle le paquet
      if ! sudo apt-get remove -y "$driver_name"; then
        # Affiche un message d'erreur
        echo_msgbox "$msg_driver_uninstall_error"
        return 1
      fi

      # Affiche un message de succès
      echo_msgbox "$msg_driver_uninstall_success"
    else
      # Affiche un message indiquant que le pilote n'est pas installé
      echo_msgbox "$msg_driver_not_installed_cancel"
    fi

  fi

}


# Fonction pour vérifier et configurer le pilote GPIO
# Function to check and configure GPIO driver
function menu_5_drivers_config_gpio() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_no="Non"
    local msg_button_ok="Suivant"
    local msg_button_yes="Oui"
    local msg_choose_install_method="Choisissez une méthode d'installation du pilote GPIO:"
    local msg_choose_uninstall_method="Choisissez la méthode de désinstallation:"
    local msg_compile_src="Compiler le module GPIO à partir du code source"
    local msg_disable_gpio="Désactivation de l'interface GPIO au démarrage..."
    local msg_enable_gpio="Activation de l'interface GPIO au démarrage..."
    local msg_error="Erreur lors de la configuration du pilote GPIO."
    local msg_install_drivers="Installation des pilotes pour l'interface GPIO..."
    local msg_install_pkg="Installer le package pigpio (recommandé)"
    local msg_success="Configuration du pilote GPIO terminée avec succès."
    local msg_title="Configuration du Pilote GPIO"
    local msg_uninstall_compile="Supprimer le module compilé"
    local msg_uninstall_drivers="Désinstallation des pilotes pour l'interface GPIO..."
    local msg_uninstall_error="Erreur lors de la désinstallation du pilote GPIO."
    local msg_uninstall_pkg="Désinstaller le package pigpio"
    local msg_uninstall_success="Désinstallation du pilote GPIO terminée avec succès."
    local msg_update_packages="Mise à jour des paquets..."
    local msg_update_failed="Échec de la mise à jour des paquets."
    local msg_install_failed="Échec de l'installation des dépendances."
    local msg_clone_failed="Échec du clonage du dépôt git."
    local msg_compile_failed="Échec de la compilation du module."
    local msg_module_failed="Échec du chargement du module."
    local msg_service_failed="Échec de la gestion du service."
    local msg_uninstall_failed="Échec de la désinstallation."
    local msg_nothing_to_uninstall="Aucune installation détectée."
    local msg_confirm_uninstall="Êtes-vous sûr de vouloir désinstaller le pilote GPIO? (o/n)"
    local msg_user_cancelled="Opération annulée par l'utilisateur."
    local msg_detected_package="Installation par package détectée."
    local msg_detected_compiled="Installation par compilation détectée."
  else
    local msg_button_cancel="Back"
    local msg_button_no="No"
    local msg_button_ok="Next"
    local msg_button_yes="Yes"
    local msg_choose_install_method="Choose a GPIO driver installation method:"
    local msg_choose_uninstall_method="Choose the uninstallation method:"
    local msg_compile_src="Compile GPIO module from source code"
    local msg_disable_gpio="Disabling GPIO interface at startup..."
    local msg_enable_gpio="Enabling GPIO interface at startup..."
    local msg_error="Error configuring GPIO driver."
    local msg_install_drivers="Installing drivers for GPIO interface..."
    local msg_install_pkg="Install pigpio package (recommended)"
    local msg_success="GPIO driver configuration completed successfully."
    local msg_title="GPIO Driver Configuration"
    local msg_uninstall_compile="Remove compiled module"
    local msg_uninstall_drivers="Uninstalling drivers for GPIO interface..."
    local msg_uninstall_error="Error uninstalling GPIO driver."
    local msg_uninstall_pkg="Uninstall pigpio package"
    local msg_uninstall_success="GPIO driver uninstallation completed successfully."
    local msg_update_packages="Updating packages..."
    local msg_update_failed="Failed to update packages."
    local msg_install_failed="Failed to install dependencies."
    local msg_clone_failed="Failed to clone git repository."
    local msg_compile_failed="Failed to compile module."
    local msg_module_failed="Failed to load module."
    local msg_service_failed="Failed to manage service."
    local msg_uninstall_failed="Failed to uninstall."
    local msg_nothing_to_uninstall="No installation detected."
    local msg_confirm_uninstall="Are you sure you want to uninstall the GPIO driver? (y/n)"
    local msg_user_cancelled="Operation cancelled by user."
    local msg_detected_package="Package installation detected."
    local msg_detected_compiled="Compiled installation detected."
  fi

  # Affiche le menu principal
  menu_0_main_menu_action "drivers" "gpio"
    
  # Vérifie si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" = "A" ]; then
    return 0
  fi

  # === INSTALLATION ===
  if [ "$G_CHOICE" = "I" ]; then
    INSTALL_METHOD=$(whiptail --title "\n$msg_title" --menu "$msg_choose_install_method" 15 70 2 \
      "P" "$msg_install_pkg" \
      "C" "$msg_compile_src" \
      3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then 
      echo "$msg_user_cancelled"
      return 0
    fi

    # Installation du package pigpio
    if [ "$INSTALL_METHOD" = "P" ]; then
      echo "$msg_install_drivers"

      echo "$msg_update_packages"
      if ! sudo apt-get update; then
        echo "$msg_error"
        echo "$msg_update_failed"
        return 1
      fi

      if ! sudo apt-get install -y pigpio; then
        echo "$msg_error"
        echo "$msg_install_failed"
        return 1
      fi

      if ! sudo systemctl enable pigpiod; then
        echo "$msg_error"
        echo "$msg_service_failed"
        return 1
      fi

      if ! sudo systemctl start pigpiod; then
        echo "$msg_error"
        echo "$msg_service_failed"
        return 1
      fi

    # Compilation du module GPIO
    elif [ "$INSTALL_METHOD" = "C" ]; then
      echo "$msg_install_drivers"

      echo "$msg_update_packages"
      if ! sudo apt-get update; then
        echo "$msg_error"
        echo "$msg_update_failed"
        return 1
      fi

      if ! sudo apt-get install -y git build-essential raspberrypi-kernel-headers; then
        echo "$msg_error"
        echo "$msg_install_failed"
        return 1
      fi

      # Nettoyer les anciennes sources
      rm -rf gpio-modules

      # Cloner le dépôt
      if ! git clone https://github.com/RPi-Distro/gpio-modules.git; then
        echo "$msg_error"
        echo "$msg_clone_failed"
        return 1
      fi

      # Compiler et installer
      cd gpio-modules || return 1
      if ! make; then
        echo "$msg_error"
        echo "$msg_compile_failed"
        cd ..
        return 1
      fi

      if ! sudo make install; then
        echo "$msg_error"
        echo "$msg_install_failed"
        cd ..
        return 1
      fi

      cd ..

      # Charger le module
      if ! sudo modprobe gpio_bcm2835; then
        echo "$msg_error"
        echo "$msg_module_failed"
        return 1
      fi

      # Ajouter le module au démarrage
      if ! echo "gpio_bcm2835" | sudo tee -a /etc/modules > /dev/null; then
        echo "$msg_error"
        echo "$msg_module_failed"
        return 1
      fi
    fi

    echo "$msg_success"
  fi

  # === DÉSINSTALLATION ===
  if [ "$G_CHOICE" = "D" ]; then
    # Détection de la méthode d'installation
    local detected_method=""
    if dpkg -l | grep -q pigpio; then
      detected_method="P"
      echo "$msg_detected_package"
    elif lsmod | grep -q gpio_bcm2835; then
      detected_method="C"
      echo "$msg_detected_compiled"
    else
      echo "$msg_nothing_to_uninstall"
      return 0
    fi

    # Demander confirmation
    read -p "$msg_confirm_uninstall " -n 1 -r
    echo
    if ! [[ $REPLY =~ ^[OoYy]$ ]]; then
      echo "$msg_user_cancelled"
      return 0
    fi

    # Proposer une méthode de désinstallation basée sur la détection
    if [ -n "$detected_method" ]; then
      UNINSTALL_METHOD=$(whiptail --title "\n$msg_title" --menu "$msg_choose_uninstall_method" 15 70 2 \
        "P" "$msg_uninstall_pkg" \
        "C" "$msg_uninstall_compile" \
        3>&1 1>&2 2>&3)

      if [ $? -ne 0 ]; then
        echo "$msg_user_cancelled"
        return 0
      fi
    else
      # Si aucune méthode n'est détectée, demander à l'utilisateur
      UNINSTALL_METHOD=$(whiptail --title "\n$msg_title" --menu "$msg_choose_uninstall_method" 15 70 2 \
        "P" "$msg_uninstall_pkg" \
        "C" "$msg_uninstall_compile" \
        3>&1 1>&2 2>&3)

      if [ $? -ne 0 ]; then
        echo "$msg_user_cancelled"
        return 0
      fi
    fi

    # Désinstallation du package pigpio
    if [ "$UNINSTALL_METHOD" = "P" ]; then
      echo "$msg_uninstall_drivers"
      
      # Arrêter le service s'il est actif
      if systemctl is-active pigpiod >/dev/null 2>&1; then
        if ! sudo systemctl stop pigpiod; then
          echo "Avertissement: Impossible d'arrêter le service pigpiod"
        fi
      fi
      
      # Désactiver le service s'il est activé
      if systemctl is-enabled pigpiod >/dev/null 2>&1; then
        if ! sudo systemctl disable pigpiod; then
          echo "$msg_uninstall_error"
          echo "$msg_service_failed"
          return 1
        fi
      fi
      
      # Désinstaller le package
      if dpkg -l | grep -q pigpio; then
        if ! sudo apt-get remove --purge -y pigpio; then
          echo "$msg_uninstall_error"
          echo "$msg_uninstall_failed"
          return 1
        fi
      fi
      
      # Nettoyer les dépendances inutiles
      if ! sudo apt-get autoremove -y; then
        echo "Avertissement: Impossible de nettoyer les dépendances inutiles"
      fi

    # Suppression du module compilé
    elif [ "$UNINSTALL_METHOD" = "C" ]; then
      echo "$msg_uninstall_drivers"
      
      # Décharger le module s'il est chargé
      if lsmod | grep -q gpio_bcm2835; then
        if ! sudo modprobe -r gpio_bcm2835; then
          echo "$msg_uninstall_error"
          echo "$msg_module_failed"
          return 1
        fi
      fi
      
      # Supprimer le module
      if [ -f "/lib/modules/$(uname -r)/kernel/drivers/gpio/gpio_bcm2835.ko" ]; then
        if ! sudo rm -f "/lib/modules/$(uname -r)/kernel/drivers/gpio/gpio_bcm2835.ko"; then
          echo "$msg_uninstall_error"
          echo "$msg_uninstall_failed"
          return 1
        fi
      fi
      
      # Supprimer le module de /etc/modules
      if grep -q "^gpio_bcm2835" /etc/modules; then
        if ! sudo sed -i '/^gpio_bcm2835/d' /etc/modules; then
          echo "$msg_uninstall_error"
          echo "$msg_uninstall_failed"
          return 1
        fi
      fi
      
      # Mettre à jour les dépendances des modules
      if ! sudo depmod -a; then
        echo "Avertissement: Impossible de mettre à jour les dépendances des modules"
      fi
      
      # Nettoyer les sources
      rm -rf gpio-modules
    fi

    echo "$msg_uninstall_success"
  fi

}

# Fonction pour vérifier et configurer le pilote GPIO distant
# Function to check and configure the remote GPIO driver
function menu_5_drivers_config_gpio_remote() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_choose_ips="Entrez les adresses IP autorisées pour pigpiod (par défaut: %s):"
    local msg_choose_port="Entrez le port d'écoute pour pigpiod (par défaut 8888):"
    local msg_configure_pigpiod="Configuration du service pigpiod..."
    local msg_disable_pigpiod="Désactivation du service pigpiod au démarrage..."
    local msg_enable_pigpiod="Activation du service pigpiod au démarrage..."
    local msg_error="Erreur lors de la configuration du pilote GPIO distant."
    local msg_install_pigpiod="Installation du service pigpiod..."
    local msg_success="Configuration du pilote GPIO distant terminée avec succès."
    local msg_title="Configuration du Pilote GPIO Distant"
    local msg_tool_type="le pilote"
    local msg_uninstall_error="Erreur lors de la désinstallation du pilote GPIO distant."
    local msg_uninstall_pigpiod="Désinstallation du service pigpiod..."
    local msg_uninstall_success="Désinstallation du pilote GPIO distant terminée avec succès."
    local msg_update_packages="Mise à jour des paquets..."
    local msg_update_failed="Échec de la mise à jour des paquets."
    local msg_install_failed="Échec de l'installation de pigpiod."
    local msg_service_failed="Échec de la gestion du service pigpiod."
    local msg_config_failed="Échec de la configuration de pigpiod."
    local msg_module_failed="Échec de la gestion du module gpiod."
    local msg_udev_failed="Échec de la configuration des règles udev."
    local msg_group_failed="Échec de la gestion des groupes utilisateur."
    local msg_port_invalid="Port invalide. Utilisation du port par défaut 8888."
    local msg_ips_invalid="Adresses IP invalides. Utilisation du réseau par défaut."
    local msg_user_cancelled="Opération annulée par l'utilisateur."
    local msg_confirm_uninstall="Êtes-vous sûr de vouloir désinstaller le pilote GPIO distant? (o/n)"
  else
    local msg_choose_ips="Enter the allowed IP addresses for pigpiod (default: %s):"
    local msg_choose_port="Enter the listening port for pigpiod (default 8888):"
    local msg_configure_pigpiod="Configuring pigpiod service..."
    local msg_disable_pigpiod="Disabling pigpiod service at startup..."
    local msg_enable_pigpiod="Enabling pigpiod service at startup..."
    local msg_error="Error configuring remote GPIO driver."
    local msg_install_pigpiod="Installing pigpiod service..."
    local msg_success="Remote GPIO driver configuration completed successfully."
    local msg_title="Remote GPIO Driver Configuration"
    local msg_tool_type="the driver"
    local msg_uninstall_error="Error uninstalling remote GPIO driver."
    local msg_uninstall_pigpiod="Uninstalling pigpiod service..."
    local msg_uninstall_success="Remote GPIO driver uninstallation completed successfully."
    local msg_update_packages="Updating packages..."
    local msg_update_failed="Failed to update packages."
    local msg_install_failed="Failed to install pigpiod."
    local msg_service_failed="Failed to manage pigpiod service."
    local msg_config_failed="Failed to configure pigpiod."
    local msg_module_failed="Failed to manage gpiod module."
    local msg_udev_failed="Failed to configure udev rules."
    local msg_group_failed="Failed to manage user groups."
    local msg_port_invalid="Invalid port. Using default port 8888."
    local msg_ips_invalid="Invalid IP addresses. Using default network."
    local msg_user_cancelled="Operation cancelled by user."
    local msg_confirm_uninstall="Are you sure you want to uninstall the remote GPIO driver? (y/n)"
  fi

  # Appel de la fonction pour afficher le menu de gestion des actions
  menu_0_main_menu_action "$msg_tool_type" "gpio_remote"

  # Vérifie si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" = "A" ]; then
    return 0
  fi

  # Si l'utilisateur choisit d'installer gpio-remote
  if [ "$G_CHOICE" = "I" ]; then
    # Vérifie si pigpiod est installé
    if ! command -v pigpiod &> /dev/null; then
      echo "$msg_install_pigpiod"
      
      echo "$msg_update_packages"
      if ! sudo apt-get update; then
        echo "$msg_error"
        echo "$msg_update_failed"
        return 1
      fi
      
      if ! sudo apt-get install -y pigpiod; then
        echo "$msg_error"
        echo "$msg_install_failed"
        return 1
      fi
    fi

    # Active le service pigpiod au démarrage
    if ! sudo systemctl enable pigpiod; then
      echo "$msg_error"
      echo "$msg_service_failed"
      return 1
    fi

    echo "$msg_configure_pigpiod"

    # Demande à l'utilisateur de choisir le port d'écoute pour pigpiod
    local PIGPIOD_PORT
    PIGPIOD_PORT=$(whiptail --inputbox "$msg_choose_port" 10 60 8888 3>&1 1>&2 2>&3)
    
    # Vérifie si l'utilisateur a annulé
    if [ $? -ne 0 ]; then
      echo "$msg_user_cancelled"
      return 1
    fi
    
    # Validation du port
    if [ -z "$PIGPIOD_PORT" ] || ! [[ "$PIGPIOD_PORT" =~ ^[0-9]+$ ]] || [ "$PIGPIOD_PORT" -lt 1 ] || [ "$PIGPIOD_PORT" -gt 65535 ]; then
      echo "$msg_port_invalid"
      PIGPIOD_PORT=8888
    fi

    # Détermine le réseau par défaut
    local DEFAULT_NETWORK
    DEFAULT_NETWORK=$(ip route | grep default | awk '{print $3}' | cut -d'.' -f1-3 2>/dev/null)
    if [ -n "$DEFAULT_NETWORK" ]; then
      DEFAULT_NETWORK="${DEFAULT_NETWORK}.0/24"
    else
      DEFAULT_NETWORK="192.168.1.0/24"
    fi

    # Demande à l'utilisateur de choisir les adresses IP autorisées pour pigpiod
    local PIGPIOD_ALLOWED_IPS
    PIGPIOD_ALLOWED_IPS=$(whiptail --inputbox "$(printf "$msg_choose_ips" "$DEFAULT_NETWORK")" 10 60 "$DEFAULT_NETWORK" 3>&1 1>&2 2>&3)
    
    # Vérifie si l'utilisateur a annulé
    if [ $? -ne 0 ]; then
      echo "$msg_user_cancelled"
      return 1
    fi
    
    # Validation des adresses IP
    if [ -z "$PIGPIOD_ALLOWED_IPS" ]; then
      echo "$msg_ips_invalid"
      PIGPIOD_ALLOWED_IPS="$DEFAULT_NETWORK"
    fi

    # Configure le service pigpiod avec les paramètres choisis
    if [ ! -f /etc/default/pigpiod ]; then
      # Crée le fichier de configuration s'il n'existe pas
      if ! sudo tee /etc/default/pigpiod > /dev/null <<EOF
# Configuration for pigpiod
PIGPIOD_OPTS="-l -n $PIGPIOD_ALLOWED_IPS -p $PIGPIOD_PORT"
EOF
      then
        echo "$msg_error"
        echo "$msg_config_failed"
        return 1
      fi
    else
      # Met à jour la configuration existante
      if ! sudo sed -i "s/^.*PIGPIOD_OPTS=.*/PIGPIOD_OPTS=\"-l -n $PIGPIOD_ALLOWED_IPS -p $PIGPIOD_PORT\"/" /etc/default/pigpiod; then
        echo "$msg_error"
        echo "$msg_config_failed"
        return 1
      fi
    fi

    # Démarre le service pigpiod
    if ! sudo systemctl restart pigpiod; then
      echo "$msg_error"
      echo "$msg_service_failed"
      return 1
    fi

    # Vérifie si le module gpiod est chargé
    if ! lsmod | grep -q gpiod; then
      if ! sudo modprobe gpiod; then
        echo "Avertissement: Impossible de charger le module gpiod"
      fi
    fi

    # Vérifie si le module gpiod est ajouté à /etc/modules pour être chargé au démarrage
    if ! grep -q "^gpiod" /etc/modules; then
      if ! echo "gpiod" | sudo tee -a /etc/modules > /dev/null; then
        echo "Avertissement: Impossible d'ajouter gpiod à /etc/modules"
      fi
    fi

    # Vérifie si le fichier de règles udev pour GPIO distant existe
    if [ ! -f /etc/udev/rules.d/99-remote-gpio.rules ]; then
      if ! sudo tee /etc/udev/rules.d/99-remote-gpio.rules > /dev/null <<'EOF'
KERNEL=="gpiochip*", ACTION=="add", PROGRAM="/bin/sh -c 'chown root:gpio /sys/class/gpio/export /sys/class/gpio/unexport ; chmod 220 /sys/class/gpio/export /sys/class/gpio/unexport'"
EOF
      then
        echo "Avertissement: Impossible de créer les règles udev"
      fi
    fi

    # Si l'utilisateur actuel n'appartient pas au groupe gpio, l'ajouter
    if ! groups "$USER" | grep -q gpio; then
      if ! sudo usermod -aG gpio "$USER"; then
        echo "Avertissement: Impossible d'ajouter l'utilisateur au groupe gpio"
      else
        echo "Note: Vous devrez vous déconnecter et vous reconnecter pour que les changements de groupe prennent effet"
      fi
    fi

    echo "$msg_success"
  fi

  # Si l'utilisateur choisit de désinstaller gpio-remote
  if [ "$G_CHOICE" = "D" ]; then
    # Demande confirmation
    read -p "$msg_confirm_uninstall " -n 1 -r
    echo
    if ! [[ $REPLY =~ ^[OoYy]$ ]]; then
      echo "$msg_user_cancelled"
      return 0
    fi

    echo "$msg_uninstall_pigpiod"

    # Arrête le service pigpiod s'il est actif
    if systemctl is-active pigpiod >/dev/null 2>&1; then
      if ! sudo systemctl stop pigpiod; then
        echo "Avertissement: Impossible d'arrêter le service pigpiod"
      fi
    fi

    # Désactive le service pigpiod au démarrage s'il est activé
    if systemctl is-enabled pigpiod >/dev/null 2>&1; then
      if ! sudo systemctl disable pigpiod; then
        echo "$msg_uninstall_error"
        echo "$msg_service_failed"
        return 1
      fi
    fi

    # Supprime pigpiod s'il est installé
    if dpkg -l | grep -q pigpiod; then
      if ! sudo apt-get remove -y pigpiod; then
        echo "Avertissement: Impossible de désinstaller pigpiod"
      fi
    fi

    # Décharge le module gpiod s'il est chargé
    if lsmod | grep -q gpiod; then
      if ! sudo modprobe -r gpiod; then
        echo "Avertissement: Impossible de décharger le module gpiod"
      fi
    fi

    # Supprime le module gpiod de /etc/modules
    if grep -q "^gpiod" /etc/modules; then
      if ! sudo sed -i '/^gpiod/d' /etc/modules; then
        echo "Avertissement: Impossible de supprimer gpiod de /etc/modules"
      fi
    fi

    # Supprime le fichier de règles udev pour GPIO distant s'il existe
    if [ -f /etc/udev/rules.d/99-remote-gpio.rules ]; then
      if ! sudo rm /etc/udev/rules.d/99-remote-gpio.rules; then
        echo "Avertissement: Impossible de supprimer les règles udev"
      fi
    fi

    echo "$msg_uninstall_success"
  fi
}

# Fonction pour vérifier et configurer le pilote I2C
# Function to check and configure the I2C driver
function menu_5_drivers_config_i2c() {

  # Définir les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_disable_i2c="Désactivation de l'interface I2C au démarrage..."
    local msg_enable_i2c="Activation de l'interface I2C au démarrage..."
    local msg_error="Erreur lors de la configuration du pilote I2C."
    local msg_install_drivers="Installation des pilotes pour l'interface I2C..."
    local msg_success="Configuration du pilote I2C terminée avec succès."
    local msg_tool_type="le pilote"
    local msg_uninstall_drivers="Désinstallation des pilotes pour l'interface I2C..."
    local msg_uninstall_error="Erreur lors de la désinstallation du pilote I2C."
    local msg_uninstall_success="Désinstallation du pilote I2C terminée avec succès."
    local msg_module_not_found="Erreur: Le module i2c_dev n'est pas disponible sur ce système"
    local msg_module_loaded="Le module i2c_dev est déjà chargé"
    local msg_module_unloaded="Le module i2c_dev n'est pas chargé"
    local msg_module_added="Module i2c_dev ajouté au démarrage"
    local msg_module_removed="Module i2c_dev retiré du démarrage"
    local msg_module_already_added="Le module i2c_dev est déjà configuré pour le démarrage"
    local msg_module_not_in_modules="Le module i2c_dev n'est pas dans la liste de démarrage"
    local msg_confirm_uninstall="Êtes-vous sûr de vouloir désinstaller le pilote I2C? (o/n)"
    local msg_user_cancelled="Opération annulée par l'utilisateur"
  else
    local msg_disable_i2c="Disabling I2C interface at startup..."
    local msg_enable_i2c="Enabling I2C interface at startup..."
    local msg_error="Error configuring I2C driver."
    local msg_install_drivers="Installing drivers for I2C interface..."
    local msg_success="I2C driver configuration completed successfully."
    local msg_tool_type="the driver"
    local msg_uninstall_drivers="Uninstalling drivers for I2C interface..."
    local msg_uninstall_error="Error uninstalling I2C driver."
    local msg_uninstall_success="I2C driver uninstallation completed successfully."
    local msg_module_not_found="Error: i2c_dev module is not available on this system"
    local msg_module_loaded="i2c_dev module is already loaded"
    local msg_module_unloaded="i2c_dev module is not loaded"
    local msg_module_added="i2c_dev module added to startup"
    local msg_module_removed="i2c_dev module removed from startup"
    local msg_module_already_added="i2c_dev module is already configured for startup"
    local msg_module_not_in_modules="i2c_dev module is not in the startup list"
    local msg_confirm_uninstall="Are you sure you want to uninstall the I2C driver? (y/n)"
    local msg_user_cancelled="Operation cancelled by user"
  fi

  # Appeler la fonction pour afficher le menu de gestion des actions
  menu_0_main_menu_action "$msg_tool_type" "i2c"

  # Vérifier si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" = "A" ]; then
    return 0
  fi

  # Si l'utilisateur choisit d'installer les pilotes I2C
  if [ "$G_CHOICE" = "I" ]; then
    # Vérifier si le module i2c_dev est disponible
    if ! modinfo i2c_dev >/dev/null 2>&1; then
      echo "$msg_module_not_found"
      return 1
    fi

    # Vérifier si les pilotes I2C sont déjà chargés
    if ! lsmod | grep -q i2c_dev; then
      echo "$msg_install_drivers"
      if ! sudo modprobe i2c_dev; then
        echo "$msg_error"
        return 1
      fi
    else
      echo "$msg_module_loaded"
    fi

    # Ajouter le module au démarrage si ce n'est pas déjà fait
    if ! grep -q "^i2c-dev" /etc/modules; then
      echo "$msg_enable_i2c"
      if ! echo "i2c-dev" | sudo tee -a /etc/modules >/dev/null; then
        echo "$msg_error"
        return 1
      fi
      echo "$msg_module_added"
    else
      echo "$msg_module_already_added"
    fi

    echo "$msg_success"
  fi

  # Si l'utilisateur choisit de désinstaller les pilotes I2C
  if [ "$G_CHOICE" = "D" ]; then
    # Demander confirmation
    read -p "$msg_confirm_uninstall " -n 1 -r
    echo
    if ! [[ $REPLY =~ ^[OoYy]$ ]]; then
      echo "$msg_user_cancelled"
      return 0
    fi

    echo "$msg_uninstall_drivers"

    # Décharger le module s'il est chargé
    if lsmod | grep -q i2c_dev; then
      if ! sudo modprobe -r i2c_dev; then
        echo "$msg_uninstall_error"
        return 1
      fi
      echo "$msg_module_unloaded"
    else
      echo "$msg_module_unloaded"
    fi

    # Retirer le module du démarrage
    if grep -q "^i2c-dev" /etc/modules; then
      if ! sudo sed -i '/^i2c-dev/d' /etc/modules; then
        echo "$msg_uninstall_error"
        return 1
      fi
      echo "$msg_module_removed"
    else
      echo "$msg_module_not_in_modules"
    fi

    echo "$msg_uninstall_success"
  fi

}

# Fonction pour vérifier et configurer le pilote bluetooth
# Function to check and configure bluetooth driver
function menu_5_drivers_config_ov_bt() {
  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_error="Erreur lors de la configuration du pilote Bluetooth."
    local msg_reboot="Redémarrage nécessaire pour appliquer les changements."
    local msg_success="Configuration du pilote Bluetooth terminée avec succès."
    local msg_title="Configuration de l'overlay Bluetooth"
    local msg_tool_type="l'overlay"
    local msg_uninstall_error="Erreur lors de la désinstallation du pilote Bluetooth."
    local msg_uninstall_success="Désinstallation du pilote Bluetooth terminée avec succès."
    local msg_enable_bt="Activation du Bluetooth..."
    local msg_disable_bt="Désactivation du Bluetooth..."
    local msg_config_not_found="Erreur: Fichier de configuration /boot/config.txt introuvable."
    local msg_remove_disable_bt="Suppression de l'overlay disable-bt..."
    local msg_add_disable_bt="Ajout de l'overlay disable-bt..."
    local msg_enable_service="Activation du service Bluetooth..."
    local msg_disable_service="Désactivation du service Bluetooth..."
    local msg_service_not_found="Service Bluetooth non trouvé."
    local msg_reboot_now="Redémarrage du système..."
    local msg_reboot_cancelled="Redémarrage annulé. Les changements seront appliqués au prochain redémarrage."
    local msg_confirm_reboot="Souhaitez-vous redémarrer maintenant pour appliquer les changements? (o/n)"
    local msg_overlay_already_removed="L'overlay disable-bt n'est pas présent dans le fichier de configuration."
    local msg_overlay_already_added="L'overlay disable-bt est déjà présent dans le fichier de configuration."
  else
    local msg_error="Error configuring Bluetooth driver."
    local msg_reboot="Reboot required to apply changes."
    local msg_success="Bluetooth driver configuration completed successfully."
    local msg_title="Bluetooth Driver Configuration"
    local msg_tool_type="the overlay"
    local msg_uninstall_error="Error uninstalling Bluetooth driver."
    local msg_uninstall_success="Bluetooth driver uninstallation completed successfully."
    local msg_enable_bt="Enabling Bluetooth..."
    local msg_disable_bt="Disabling Bluetooth..."
    local msg_config_not_found="Error: Configuration file /boot/config.txt not found."
    local msg_remove_disable_bt="Removing disable-bt overlay..."
    local msg_add_disable_bt="Adding disable-bt overlay..."
    local msg_enable_service="Enabling Bluetooth service..."
    local msg_disable_service="Disabling Bluetooth service..."
    local msg_service_not_found="Bluetooth service not found."
    local msg_reboot_now="Rebooting system..."
    local msg_reboot_cancelled="Reboot cancelled. Changes will be applied on next reboot."
    local msg_confirm_reboot="Do you want to reboot now to apply changes? (y/n)"
    local msg_overlay_already_removed="disable-bt overlay is not present in the configuration file."
    local msg_overlay_already_added="disable-bt overlay is already present in the configuration file."
  fi

  # Appel de la fonction pour afficher le menu de gestion des actions
  menu_0_main_menu_action "$msg_tool_type" "bluetooth"
  
  # Vérifie si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" = "A" ]; then
    return 0
  fi

  # Vérifier l'existence du fichier de configuration
  if [ ! -f /boot/config.txt ]; then
    echo "$msg_config_not_found"
    return 1
  fi

  # Si l'utilisateur choisit d'installer
  if [ "$G_CHOICE" = "I" ]; then
    echo "$msg_enable_bt"
    
    # Supprimer l'overlay disable-bt de /boot/config.txt
    echo "$msg_remove_disable_bt"
    if grep -q "dtoverlay=disable-bt" /boot/config.txt; then
      if ! sudo sed -i '/dtoverlay=disable-bt/d' /boot/config.txt; then
        echo "$msg_error"
        return 1
      fi
    else
      echo "$msg_overlay_already_removed"
    fi
    
    # Activer le service Bluetooth
    echo "$msg_enable_service"
    if systemctl list-unit-files | grep -q hciuart.service; then
      if ! sudo systemctl enable hciuart; then
        echo "$msg_error"
        return 1
      fi
      
      # Démarrer le service immédiatement
      if ! sudo systemctl start hciuart; then
        echo "Avertissement: Impossible de démarrer le service Bluetooth immédiatement"
      fi
    else
      echo "$msg_service_not_found"
    fi
    
    # Demander confirmation pour le redémarrage
    echo "$msg_success"
    echo "$msg_reboot"
    read -p "$msg_confirm_reboot " -n 1 -r
    echo
    if [[ $REPLY =~ ^[OoYy]$ ]]; then
      echo "$msg_reboot_now"
      sudo reboot
    else
      echo "$msg_reboot_cancelled"
    fi
  fi
  
  # Si l'utilisateur choisit de désinstaller
  if [ "$G_CHOICE" = "D" ]; then
    echo "$msg_disable_bt"
    
    # Ajouter l'overlay disable-bt dans /boot/config.txt
    echo "$msg_add_disable_bt"
    if grep -q "dtoverlay=disable-bt" /boot/config.txt; then
      echo "$msg_overlay_already_added"
    else
      if ! echo "dtoverlay=disable-bt" | sudo tee -a /boot/config.txt > /dev/null; then
        echo "$msg_uninstall_error"
        return 1
      fi
    fi
    
    # Désactiver le service Bluetooth
    echo "$msg_disable_service"
    if systemctl list-unit-files | grep -q hciuart.service; then
      if ! sudo systemctl disable hciuart; then
        echo "$msg_uninstall_error"
        return 1
      fi
      
      # Arrêter le service immédiatement
      if ! sudo systemctl stop hciuart; then
        echo "Avertissement: Impossible d'arrêter le service Bluetooth immédiatement"
      fi
    else
      echo "$msg_service_not_found"
    fi
    
    # Demander confirmation pour le redémarrage
    echo "$msg_uninstall_success"
    echo "$msg_reboot"
    read -p "$msg_confirm_reboot " -n 1 -r
    echo
    if [[ $REPLY =~ ^[OoYy]$ ]]; then
      echo "$msg_reboot_now"
      sudo reboot
    else
      echo "$msg_reboot_cancelled"
    fi
  fi
}

# Fonction pour vérifier et configurer l'overlay I2C RTC
# Function to check and configure I2C RTC overlay
function menu_5_drivers_config_ov_i2c_rtc() {
  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_error="Erreur lors de la configuration de l'overlay I2C RTC."
    local msg_reboot="Redémarrage nécessaire pour appliquer les changements."
    local msg_success="Configuration de l'overlay I2C RTC terminée avec succès."
    local msg_title="Configuration de l'overlay I2C RTC"
    local msg_tool_type="l'overlay"
    local msg_uninstall_error="Erreur lors de la désinstallation de l'overlay I2C RTC."
    local msg_uninstall_success="Désinstallation de l'overlay I2C RTC terminée avec succès."
    local msg_enable_overlay="Activation de l'overlay i2c-rtc,pcf85063a,i2c_csi_dsi,addr=0x51..."
    local msg_disable_overlay="Désactivation de l'overlay i2c-rtc,pcf85063a,i2c_csi_dsi,addr=0x51..."
    local msg_config_not_found="Erreur: Fichier de configuration /boot/config.txt introuvable."
    local msg_overlay_not_found="L'overlay n'est pas présent dans le fichier de configuration."
    local msg_overlay_already_exists="L'overlay est déjà présent dans le fichier de configuration."
    local msg_reboot_now="Redémarrage du système..."
    local msg_reboot_cancelled="Redémarrage annulé. Les changements seront appliqués au prochain redémarrage."
    local msg_confirm_reboot="Souhaitez-vous redémarrer maintenant pour appliquer les changements? (o/n)"
  else
    local msg_error="Error configuring I2C RTC overlay."
    local msg_reboot="Reboot required to apply changes."
    local msg_success="I2C RTC overlay configuration completed successfully."
    local msg_title="I2C RTC Overlay Configuration"
    local msg_tool_type="the overlay"
    local msg_uninstall_error="Error uninstalling I2C RTC overlay."
    local msg_uninstall_success="I2C RTC overlay uninstallation completed successfully."
    local msg_enable_overlay="Enabling overlay i2c-rtc,pcf85063a,i2c_csi_dsi,addr=0x51..."
    local msg_disable_overlay="Disabling overlay i2c-rtc,pcf85063a,i2c_csi_dsi,addr=0x51..."
    local msg_config_not_found="Error: Configuration file /boot/config.txt not found."
    local msg_overlay_not_found="Overlay is not present in the configuration file."
    local msg_overlay_already_exists="Overlay is already present in the configuration file."
    local msg_reboot_now="Rebooting system..."
    local msg_reboot_cancelled="Reboot cancelled. Changes will be applied on next reboot."
    local msg_confirm_reboot="Do you want to reboot now to apply changes? (y/n)"
  fi

  # Appel de la fonction pour afficher le menu de gestion des actions
  menu_0_main_menu_action "$msg_tool_type" "i2c_rtc"
  
  # Vérifie si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" = "A" ]; then
    return 0
  fi

  # Vérifier l'existence du fichier de configuration
  if [ ! -f /boot/config.txt ]; then
    echo "$msg_config_not_found"
    return 1
  fi

  # Si l'utilisateur choisit d'installer
  if [ "$G_CHOICE" = "I" ]; then
    echo "$msg_enable_overlay"
    
    # Vérifier si l'overlay est déjà présent
    if grep -q "dtoverlay=i2c-rtc,pcf85063a,i2c_csi_dsi,addr=0x51" /boot/config.txt; then
      echo "$msg_overlay_already_exists"
    else
      # Ajouter l'overlay dans /boot/config.txt
      if ! echo "dtoverlay=i2c-rtc,pcf85063a,i2c_csi_dsi,addr=0x51" | sudo tee -a /boot/config.txt > /dev/null; then
        echo "$msg_error"
        return 1
      fi
    fi
    
    # Demander confirmation pour le redémarrage
    echo "$msg_success"
    echo "$msg_reboot"
    read -p "$msg_confirm_reboot " -n 1 -r
    echo
    if [[ $REPLY =~ ^[OoYy]$ ]]; then
      echo "$msg_reboot_now"
      sudo reboot
    else
      echo "$msg_reboot_cancelled"
    fi
  fi
  
  # Si l'utilisateur choisit de désinstaller
  if [ "$G_CHOICE" = "D" ]; then
    echo "$msg_disable_overlay"
    
    # Vérifier si l'overlay est présent
    if ! grep -q "dtoverlay=i2c-rtc,pcf85063a,i2c_csi_dsi,addr=0x51" /boot/config.txt; then
      echo "$msg_overlay_not_found"
    else
      # Supprimer l'overlay de /boot/config.txt
      if ! sudo sed -i '/dtoverlay=i2c-rtc,pcf85063a,i2c_csi_dsi,addr=0x51/d' /boot/config.txt; then
        echo "$msg_uninstall_error"
        return 1
      fi
    fi
    
    # Demander confirmation pour le redémarrage
    echo "$msg_uninstall_success"
    echo "$msg_reboot"
    read -p "$msg_confirm_reboot " -n 1 -r
    echo
    if [[ $REPLY =~ ^[OoYy]$ ]]; then
      echo "$msg_reboot_now"
      sudo reboot
    else
      echo "$msg_reboot_cancelled"
    fi
  fi
}

# Fonction pour vérifier et configurer l'overlay vc4-kms-v3d
# Function to check and configure vc4-kms-v3d overlay
function menu_5_drivers_config_ov_vc4_kms_v3d() {
  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_error="Erreur lors de la configuration de l'overlay vc4-kms-v3d."
    local msg_install_driver="Installation du pilote vc4-kms-v3d..."
    local msg_restart_required="Un redémarrage est nécessaire pour appliquer les changements."
    local msg_success="Configuration de l'overlay vc4-kms-v3d terminée avec succès."
    local msg_title="Configuration de l'overlay vc4-kms-v3d"
    local msg_tool_type="l'overlay"
    local msg_uninstall_driver="Désinstallation du pilote vc4-kms-v3d..."
    local msg_uninstall_error="Erreur lors de la désinstallation de l'overlay vc4-kms-v3d."
    local msg_uninstall_success="Désinstallation de l'overlay vc4-kms-v3d terminée avec succès."
    local msg_update_packages="Mise à jour des paquets..."
    local msg_update_failed="Échec de la mise à jour des paquets."
    local msg_install_dependencies="Installation des dépendances nécessaires..."
    local msg_install_deps_failed="Échec de l'installation des dépendances."
    local msg_enable_kms="Activation du noyau KMS..."
    local msg_enable_kms_failed="Échec de l'activation du noyau KMS."
    local msg_disable_kms="Désactivation du noyau KMS..."
    local msg_disable_kms_failed="Échec de la désactivation du noyau KMS."
    local msg_config_not_found="Erreur: Fichier de configuration /boot/config.txt introuvable."
    local msg_reboot_now="Redémarrage du système..."
    local msg_reboot_cancelled="Redémarrage annulé. Les changements seront appliqués au prochain redémarrage."
    local msg_confirm_reboot="Souhaitez-vous redémarrer maintenant pour appliquer les changements? (o/n)"
  else
    local msg_error="Error configuring vc4-kms-v3d overlay."
    local msg_install_driver="Installing driver vc4-kms-v3d..."
    local msg_restart_required="Reboot is required to apply changes."
    local msg_success="vc4-kms-v3d overlay configuration completed successfully."
    local msg_title="vc4-kms-v3d Overlay Configuration"
    local msg_tool_type="the overlay"
    local msg_uninstall_driver="Uninstalling driver vc4-kms-v3d..."
    local msg_uninstall_error="Error uninstalling vc4-kms-v3d overlay."
    local msg_uninstall_success="vc4-kms-v3d overlay uninstallation completed successfully."
    local msg_update_packages="Updating packages..."
    local msg_update_failed="Failed to update packages."
    local msg_install_dependencies="Installing required dependencies..."
    local msg_install_deps_failed="Failed to install dependencies."
    local msg_enable_kms="Enabling KMS kernel..."
    local msg_enable_kms_failed="Failed to enable KMS kernel."
    local msg_disable_kms="Disabling KMS kernel..."
    local msg_disable_kms_failed="Failed to disable KMS kernel."
    local msg_config_not_found="Error: Configuration file /boot/config.txt not found."
    local msg_reboot_now="Rebooting system..."
    local msg_reboot_cancelled="Reboot cancelled. Changes will be applied on next reboot."
    local msg_confirm_reboot="Do you want to reboot now to apply changes? (y/n)"
  fi

  # Appel de la fonction pour afficher le menu de gestion des actions
  menu_0_main_menu_action "$msg_tool_type" "vc4_kms_v3d"
  
  # Vérifie si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" = "A" ]; then
    return 0
  fi

  # Si l'utilisateur choisit d'installer
  if [ "$G_CHOICE" = "I" ]; then
    echo "$msg_install_driver"
    
    # Vérifier l'existence du fichier de configuration
    if [ ! -f /boot/config.txt ]; then
      echo "$msg_config_not_found"
      return 1
    fi
    
    # Mettre à jour les paquets
    echo "$msg_update_packages"
    if ! sudo apt-get update; then
      echo "$msg_error"
      echo "$msg_update_failed"
      return 1
    fi
    
    # Installer les dépendances nécessaires
    echo "$msg_install_dependencies"
    if ! sudo apt-get install -y xserver-xorg-video-all xserver-xorg-video-fbdev libraspberrypi-bin libraspberrypi-dev; then
      echo "$msg_error"
      echo "$msg_install_deps_failed"
      return 1
    fi
    
    # Activer le noyau KMS
    echo "$msg_enable_kms"
    if ! sudo sed -i 's/dtoverlay=vc4-fkms-v3d/dtoverlay=vc4-kms-v3d/g' /boot/config.txt; then
      echo "$msg_error"
      echo "$msg_enable_kms_failed"
      return 1
    fi
    
    # Vérifier si le changement a été appliqué
    if ! grep -q "dtoverlay=vc4-kms-v3d" /boot/config.txt; then
      # Si la substitution n'a pas fonctionné, ajouter la ligne
      if ! echo "dtoverlay=vc4-kms-v3d" | sudo tee -a /boot/config.txt > /dev/null; then
        echo "$msg_error"
        echo "$msg_enable_kms_failed"
        return 1
      fi
    fi
    
    # Demander confirmation pour le redémarrage
    echo "$msg_success"
    echo "$msg_restart_required"
    read -p "$msg_confirm_reboot " -n 1 -r
    echo
    if [[ $REPLY =~ ^[OoYy]$ ]]; then
      echo "$msg_reboot_now"
      sudo reboot
    else
      echo "$msg_reboot_cancelled"
    fi
  fi
  
  # Si l'utilisateur choisit de désinstaller
  if [ "$G_CHOICE" = "D" ]; then
    echo "$msg_uninstall_driver"
    
    # Vérifier l'existence du fichier de configuration
    if [ ! -f /boot/config.txt ]; then
      echo "$msg_config_not_found"
      return 1
    fi
    
    # Désactiver le noyau KMS
    echo "$msg_disable_kms"
    if ! sudo sed -i 's/dtoverlay=vc4-kms-v3d/dtoverlay=vc4-fkms-v3d/g' /boot/config.txt; then
      echo "$msg_uninstall_error"
      echo "$msg_disable_kms_failed"
      return 1
    fi
    
    # Vérifier si le changement a été appliqué
    if grep -q "dtoverlay=vc4-kms-v3d" /boot/config.txt; then
      # Si la substitution n'a pas fonctionné, supprimer la ligne
      if ! sudo sed -i '/dtoverlay=vc4-kms-v3d/d' /boot/config.txt; then
        echo "$msg_uninstall_error"
        echo "$msg_disable_kms_failed"
        return 1
      fi
    fi
    
    # Demander confirmation pour le redémarrage
    echo "$msg_uninstall_success"
    echo "$msg_restart_required"
    read -p "$msg_confirm_reboot " -n 1 -r
    echo
    if [[ $REPLY =~ ^[OoYy]$ ]]; then
      echo "$msg_reboot_now"
      sudo reboot
    else
      echo "$msg_reboot_cancelled"
    fi
  fi
}

# Fonction pour vérifier et configurer l'horloge RTC
# Function to check and configure the RTC clock
function menu_5_drivers_config_rtc() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_activating_service="Activation du service rtc-sync..."
    local msg_creating_service="Création du service systemd pour la synchronisation RTC..."
    local msg_disable_rtc="Désactivation de l'horloge RTC au démarrage..."
    local msg_enable_rtc="Activation de l'horloge RTC au démarrage..."
    local msg_error="Erreur lors de la configuration de l'horloge RTC."
    local msg_failed_add_module="Échec de l'ajout du module à /etc/modules"
    local msg_failed_create_service="Échec de la création du service systemd"
    local msg_failed_disable_service="Échec de la désactivation du service rtc-sync"
    local msg_failed_enable_service="Échec de l'activation du service rtc-sync"
    local msg_failed_load_module="Échec du chargement du module rtc_pcf85063"
    local msg_failed_remove_module="Échec de la suppression du module de /etc/modules"
    local msg_failed_remove_service="Échec de la suppression du service rtc-sync"
    local msg_failed_start_service="Échec du démarrage du service rtc-sync"
    local msg_failed_stop_service="Échec de l'arrêt du service rtc-sync"
    local msg_failed_sync_rtc="Échec de la synchronisation de l'horloge RTC"
    local msg_failed_unload_module="Échec du déchargement du module rtc_pcf85063"
    local msg_hwclock_not_found="Erreur: Commande hwclock introuvable"
    local msg_install_drivers="Installation des pilotes pour l'horloge RTC..."
    local msg_module_not_found="Erreur: Le module rtc_pcf85063 n'est pas disponible sur ce système"
    local msg_rtc_not_detected="Avertissement: Impossible de lire l'horloge matérielle. Le RTC pourrait ne pas être correctement configuré"
    local msg_service_exists="Le service rtc-sync existe déjà, vérification de son état..."
    local msg_starting_service="Démarrage du service rtc-sync..."
    local msg_success="Configuration de l'horloge RTC terminée avec succès."
    local msg_sync_rtc="Synchronisation de l'horloge système avec l'horloge RTC..."
    local msg_title="Configuration de l'Horloge RTC"
    local msg_tool_type="le pilote"
    local msg_uninstall_drivers="Désinstallation des pilotes pour l'horloge RTC..."
    local msg_uninstall_error="Erreur lors de la désinstallation de l'horloge RTC."
    local msg_uninstall_success="Désinstallation de l'horloge RTC terminée avec succès."
    local msg_warning_reload_after_remove="Avertissement: Impossible de recharger systemd après suppression du service"
    local msg_warning_reload_systemd="Avertissement: Impossible de recharger systemd"
  else
    local msg_activating_service="Enabling rtc-sync service..."
    local msg_creating_service="Creating systemd service for RTC synchronization..."
    local msg_disable_rtc="Disabling RTC clock at startup..."
    local msg_enable_rtc="Enabling RTC clock at startup..."
    local msg_error="Error configuring RTC clock."
    local msg_failed_add_module="Failed to add module to /etc/modules"
    local msg_failed_create_service="Failed to create systemd service"
    local msg_failed_disable_service="Failed to disable rtc-sync service"
    local msg_failed_enable_service="Failed to enable rtc-sync service"
    local msg_failed_load_module="Failed to load rtc_pcf85063 module"
    local msg_failed_remove_module="Failed to remove module from /etc/modules"
    local msg_failed_remove_service="Failed to remove rtc-sync service"
    local msg_failed_start_service="Failed to start rtc-sync service"
    local msg_failed_stop_service="Failed to stop rtc-sync service"
    local msg_failed_sync_rtc="Failed to synchronize RTC clock"
    local msg_failed_unload_module="Failed to unload rtc_pcf85063 module"
    local msg_hwclock_not_found="Error: hwclock command not found"
    local msg_install_drivers="Installing drivers for RTC clock..."
    local msg_module_not_found="Error: rtc_pcf85063 module is not available on this system"
    local msg_rtc_not_detected="Warning: Unable to read hardware clock. RTC might not be properly configured"
    local msg_service_exists="rtc-sync service already exists, checking its status..."
    local msg_starting_service="Starting rtc-sync service..."
    local msg_success="RTC clock configuration completed successfully."
    local msg_sync_rtc="Synchronizing system clock with RTC clock..."
    local msg_title="RTC Configuration"
    local msg_tool_type="the driver"
    local msg_uninstall_drivers="Uninstalling drivers for RTC clock..."
    local msg_uninstall_error="Error uninstalling RTC clock."
    local msg_uninstall_success="RTC clock uninstallation completed successfully."
    local msg_warning_reload_after_remove="Warning: Unable to reload systemd after service removal"
    local msg_warning_reload_systemd="Warning: Unable to reload systemd"
  fi

  # Appel de la fonction pour afficher le menu de gestion des actions
  menu_0_main_menu_action "$msg_tool_type" "rtc"

  # Vérifie si l'utilisateur a choisi d'annuler
  if [ "$G_CHOICE" = "A" ]; then
    return 0
  fi

  # Si l'utilisateur choisit d'installer RTC
  if [ "$G_CHOICE" = "I" ]; then
    # Vérification et chargement du module
    if ! lsmod | grep -q "rtc_pcf85063"; then
      echo "$msg_install_drivers"
      
      # Vérification de l'existence du module avant tentative de chargement
      if ! modinfo "rtc_pcf85063" >/dev/null 2>&1; then
        echo "$msg_module_not_found"
        return 1
      fi
      
      if ! sudo modprobe "rtc_pcf85063"; then
        echo "$msg_error"
        echo "$msg_failed_load_module"
        return 1
      fi
    fi

    # Ajout du module aux modules chargés au démarrage
    echo "$msg_enable_rtc"
    if ! grep -q "^rtc_pcf85063" /etc/modules; then
      echo "rtc_pcf85063" | sudo tee -a /etc/modules >/dev/null
      if [ $? -ne 0 ]; then
        echo "$msg_error"
        echo "$msg_failed_add_module"
        return 1
      fi
    fi

    # Synchronisation de l'horloge matérielle
    echo "$msg_sync_rtc"
    if ! command -v hwclock >/dev/null 2>&1; then
      echo "$msg_hwclock_not_found"
      return 1
    fi
    
    if ! sudo hwclock --systohc; then
      echo "$msg_error"
      echo "$msg_failed_sync_rtc"
      return 1
    fi

    # Configuration du service systemd pour la synchronisation RTC
    if [ ! -f /etc/systemd/system/rtc-sync.service ]; then
      echo "$msg_creating_service"
      
      # Création du fichier de service avec vérification
      sudo tee /etc/systemd/system/rtc-sync.service >/dev/null <<EOF
[Unit]
Description=Synchronize Hardware Clock to System Clock
After=network.target ntp.service systemd-time-wait-sync.service

[Service]
Type=oneshot
ExecStart=/sbin/hwclock --hctosys
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

      if [ $? -ne 0 ]; then
        echo "$msg_error"
        echo "$msg_failed_create_service"
        return 1
      fi

      # Rechargement de systemd
      if ! sudo systemctl daemon-reload; then
        echo "$msg_warning_reload_systemd"
      fi

      # Activation du service
      if ! sudo systemctl enable rtc-sync.service; then
        echo "$msg_error"
        echo "$msg_failed_enable_service"
        return 1
      fi

      # Démarrage du service
      if ! sudo systemctl start rtc-sync.service; then
        echo "$msg_error"
        echo "$msg_failed_start_service"
        return 1
      fi
    else
      echo "$msg_service_exists"
      if ! sudo systemctl is-enabled rtc-sync.service >/dev/null 2>&1; then
        echo "$msg_activating_service"
        if ! sudo systemctl enable rtc-sync.service; then
          echo "$msg_error"
          echo "$msg_failed_enable_service"
          return 1
        fi
      fi
      
      if ! sudo systemctl is-active rtc-sync.service >/dev/null 2>&1; then
        echo "$msg_starting_service"
        if ! sudo systemctl start rtc-sync.service; then
          echo "$msg_error"
          echo "$msg_failed_start_service"
          return 1
        fi
      fi
    fi

    # Vérification finale que le RTC est détecté
    if ! sudo hwclock --verbose >/dev/null 2>&1; then
      echo "$msg_rtc_not_detected"
    fi

    echo "$msg_success"
  fi

  # Si l'utilisateur choisit de désinstaller RTC
  if [ "$G_CHOICE" = "D" ]; then
    echo "$msg_uninstall_drivers"

    # Vérification et désactivation du service rtc-sync
    if systemctl is-active rtc-sync.service >/dev/null 2>&1; then
      if ! sudo systemctl stop rtc-sync.service; then
        echo "$msg_uninstall_error"
        echo "$msg_failed_stop_service"
        return 1
      fi
    fi

    if systemctl is-enabled rtc-sync.service >/dev/null 2>&1; then
      if ! sudo systemctl disable rtc-sync.service; then
        echo "$msg_uninstall_error"
        echo "$msg_failed_disable_service"
        return 1
      fi
    fi

    # Suppression du fichier de service systemd rtc-sync
    if [ -f /etc/systemd/system/rtc-sync.service ]; then
      if ! sudo rm /etc/systemd/system/rtc-sync.service; then
        echo "$msg_uninstall_error"
        echo "$msg_failed_remove_service"
        return 1
      fi
      
      # Rechargement de systemd après suppression
      if ! sudo systemctl daemon-reload; then
        echo "$msg_warning_reload_after_remove"
      fi
    fi

    echo "$msg_disable_rtc"

    # Déchargement du module rtc_pcf85063 s'il est chargé
    if lsmod | grep -q "rtc_pcf85063"; then
      if ! sudo modprobe -r rtc_pcf85063; then
        echo "$msg_uninstall_error"
        echo "$msg_failed_unload_module"
        return 1
      fi
    fi

    # Suppression du module rtc_pcf85063 de /etc/modules
    if grep -q "^rtc_pcf85063" /etc/modules; then
      if ! sudo sed -i '/^rtc_pcf85063/d' /etc/modules; then
        echo "$msg_uninstall_error"
        echo "$msg_failed_remove_module"
        return 1
      fi
    fi

    echo "$msg_uninstall_success"
  fi
}



##########   FONCTION MENU DIVERS - MISCELLANEOUS MENU FUNCTION

# Fonction pour afficher le menu divers
# Function to display the miscellaneous menu
function menu_6_misc() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_ok="Sélectionner"
    local msg_message="Choisissez l'action à effectuer :"
    local msg_options=(
      "1" "Configurer la carte réseau" ON
      "2" "Lancer un shell dans un container" OFF
      "3" "Changer le mot de passe utilisateur" OFF
      "4" "Changer le nom du NRX800" OFF
      "5" "Etendre la partition du disque" OFF
      "6" "Système de fichiers Overlay (lecture seule)" OFF
      "7" "Changer le fuseau horaire" OFF
      "8" "Changer le clavier pour le français" OFF
      "9" "Changer les paramètres régionaux pour le français" OFF
      "10" "Changer l'ordre de démarrage (NVMe, SD)" OFF
      "11" "Mettre à jour (update & full upgrade)" OFF
      "12" "Nettoyer le système (packages minimum et pilotes)" OFF
      "13" "Configurer le serveur NTP" OFF
      "14" "Recréer le fichier /boot/firmware/config.txt de GCE" OFF
      "15" "Configurer le 'Message Of The Day'" OFF
      "16" "Créer une sauvegarde de la configuration" OFF
      "17" "Rédemarrer le NRX800" OFF
    )
    local msg_title="$G_TITLE - Divers"
  else
    local msg_button_cancel="Back"
    local msg_button_ok="Select"
    local msg_message="Choose the action to perform :"
    local msg_options=(
      "1" "Configure network card" ON
      "2" "Launch a shell in a container" OFF
      "3" "Change the user password" OFF
      "4" "Change the name of the NRX800" OFF
      "5" "Extend the disk partition" OFF
      "6" "Overlay filesystem (read-only)" OFF
      "7" "Change the time zone" OFF
      "8" "Change the keyboard to US English" OFF
      "9" "Change the locale settings to US English" OFF
      "10" "Change the boot order (NVMe, SD)" OFF
      "11" "Update (update & full upgrade)" OFF
      "12" "Clean system (packages minimum and drivers)" OFF
      "13" "Configure NTP server" OFF
      "14" "Recreate the /boot/firmware/config.txt file" OFF
      "15" "Configure the 'Message Of The Day'" OFF
      "16" "Make a configuration backup" OFF
      "17" "Reboot NRX800" OFF
    )
    local msg_title="$G_TITLE - Miscellaneous"
  fi

  while true; do
    # Calculer la hauteur dynamique de la liste et limite à 10 si sup à 10
    local num_items=$((${#msg_options[@]} / 3))  # Chaque item a 3 éléments (ID, label, état)
    if (( num_items > 10 )); then
      num_items=10
    fi

    local menu_height=$((10 + num_items))  # Hauteur de base + nombre d'éléments

    # Limiter la hauteur maximale pour éviter des problèmes d'affichage
    if [ $menu_height -gt 20 ]; then
      menu_height=20
    fi

    # Afficher la boîte de dialogue
    local choice_menu
    choice_menu=$(whiptail --radiolist "\n$msg_message" $menu_height 75 $num_items "${msg_options[@]}" \
                  --fb --title "$msg_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" --notags 3>&1 1>&2 2>&3)
    # Récupérer le statut de sortie de whiptail
    local exit_status=$?

    if [ $exit_status -eq 1 ]; then # Clic "Retour"
      return 0
    elif [ $exit_status -eq 0 ]; then # Clic "OK"
      case $choice_menu in
        1) menu_6_misc_change_config_network ;;
        2) menu_6_misc_launch_shell_in_container ;;
        3) menu_6_misc_change_password ;;
        4) menu_6_misc_change_hostname ;;
        5) menu_6_misc_expand_rootfs ;;
        6) menu_6_misc_overlay_filesystem ;;
        7) menu_6_misc_change_timezone ;;
        8) menu_6_misc_change_keyboard ;;
        9) menu_6_misc_change_locales ;;
        10) menu_6_misc_change_boot_order ;;
        11) menu_6_misc_update_system ;;
        12) menu_6_misc_clean_system ;;
        13) menu_6_misc_config_ntp_server ;;
        14) menu_6_misc_create_boot_firmware_config.txt ;;
        15) menu_6_misc_config_motd ;;
        16) menu_6_misc_config_backup ;;
        17) menu_6_misc_reboot ;;
        *) echo_msgbox "Option invalide / Invalid option" "$msg_title" ;;
      esac
    else
      echo_msgbox "Une erreur s'est produite / An error occurred" "$msg_title"
      return 1
    fi
  done

}

# Fonction pour changer l'ordre de démarrage (nvme ou carte sd)
# Function to change boot order (nvme or sd card)
function menu_6_misc_change_boot_order() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_backup_error="Erreur lors de la création de la sauvegarde du fichier de configuration."
    local msg_boot_order_change_error="Erreur lors du changement de l'ordre de démarrage pour %s."
    local msg_button_cancel="Retour"
    local msg_button_ok="Ok"
    local msg_current_boot_device="Le système démarre actuellement depuis :"
    local msg_message="Veuillez sélectionner l'ordre de démarrage."
    local msg_options=("1" "NVMe" "2" "Carte SD")
    local msg_success="L'ordre de démarrage a été changé avec succès."
    local msg_title="$G_TITLE - Changer l'ordre de démarrage"
    local msg_unsupported_device="Périphérique non pris en charge: %s. Utilisez 'nvme' ou 'sd'."
  else
    local msg_backup_error="Error creating backup of the configuration file."
    local msg_boot_order_change_error="Error changing boot order for %s."
    local msg_button_cancel="Back"
    local msg_button_ok="Ok"
    local msg_current_boot_device="The system is currently booting from:"
    local msg_message="Please select the boot order."
    local msg_options=("1" "NVMe" "2" "SD Card")
    local msg_success="The boot order has been changed successfully."
    local msg_title="$G_TITLE - Change Boot Order"
    local msg_unsupported_device="Unsupported device: %s. Use 'nvme' or 'sd'."
  fi

  readonly cmdline_file="/boot/firmware/cmdline.txt"

  # Détermine le périphérique de démarrage actuel
  local root_device
  root_device=$(grep -oP 'root=\K[^ ]+' "$cmdline_file" 2>/dev/null)
  local device_type=""
  case "$root_device" in
    /dev/nvme*) device_type="${msg_options[1]}" ;;  # NVMe
    /dev/mmcblk*) device_type="${msg_options[2]}" ;;  # Carte SD
    *) device_type="Inconnu/Unknown" ;;
  esac

  # Affiche le menu pour sélectionner le périphérique de démarrage
  local choice_menu
  choice_menu=$(whiptail --menu "\n$msg_message\n$msg_current_boot_device $device_type" 20 70 3 "${msg_options[@]}" \
          --fb --title "$msg_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
  local exit_status=$?

  if [ "$exit_status" -eq 0 ]; then
    local device
    case $choice_menu in
      1) device="nvme" ;;
      2) device="sd" ;;
      *) return 1 ;;
    esac

    # Vérifie que le périphérique est valide
    if [[ "$device" != "nvme" && "$device" != "sd" ]]; then
      echo_msgbox "$(printf "$msg_unsupported_device" "$device")" "$msg_title"
      return 1
    fi

    # Définit la nouvelle valeur pour 'root'
    local new_root=""
    case "$device" in
      nvme) new_root="root=/dev/nvme0n1p1" ;;
      sd) new_root="root=/dev/mmcblk0p1" ;;
    esac

    if [ -z "$new_root" ]; then
      echo_msgbox "$(printf "$msg_boot_order_change_error" "$device")" "$msg_title"
      return 1
    fi

    # Crée une sauvegarde du fichier de configuration
    if ! sudo cp "$cmdline_file" "$cmdline_file.bak"; then
      echo_msgbox "$msg_backup_error" "$msg_title"
      return 1
    fi

    # Modifie le fichier de configuration
    if sudo sed -i "s|root=[^ ]*|$new_root|" "$cmdline_file"; then
      echo_msgbox "$msg_success" "$msg_title"
    else
      echo_msgbox "$(printf "$msg_boot_order_change_error" "$device")" "$msg_title"
      return 1
    fi
  fi

  return 0
  
}

# Fonction pour le menu de configuration réseau
# Function for network configuration menu
function menu_6_misc_change_config_network() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_no="Non"
    local msg_button_ok="Seléctionner"
    local msg_button_yes="Oui"
    local msg_message="Que voulez-vous faire ?"
    local msg_options=(
      "1" "Configurer DHCP" ON
      "2" "Configurer IP Statique" OFF
    )
    local msg_title="$G_TITLE - Configuration de la carte réseau eth0"
  else
    local msg_button_cancel="Back"
    local msg_button_no="No"
    local msg_button_ok="Ok"
    local msg_button_yes="Yes"
    local msg_message="What do you want to do ?"
    local msg_options=(
      "1" "Configure DHCP" ON 
      "2" "Configure Static IP" OFF
    )
    local msg_title="$G_TITLE - Network Card eth0 Configuration"
  fi

  while true; do
    # Afficher la boîte de dialogue
    local choice_menu
    choice_menu=$(whiptail --radiolist "\n$msg_message" 15 70 2 "${msg_options[@]}" \
                  --fb --title "$msg_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
    # Récupérer le statut de sortie
    local exit_status=$?

    if [ $exit_status -eq 1 ]; then # Clic "Retour"
      return 0
    elif [ $exit_status -eq 0 ]; then # Clic "Sélectionner"
      case $choice_menu in
        1) menu_6_misc_change_config_network_dhcp ;;
        2) menu_6_misc_change_config_network_static_ip ;;
        *) echo_msgbox "Option invalide / Invalid option" "$title" ;;
      esac
    else
      echo_msgbox "Une erreur s'est produite / An error occurred" "$msg_title"
      return 1
    fi
  done
  
}

# Fonction pour configurer DHCP
# Function to configure DHCP
function menu_6_misc_change_config_network_dhcp() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_error="Erreur lors de la configuration DHCP."
    local msg_success="Configuration DHCP terminée avec succès."
    local msg_title="$G_TITLE - Configuration DHCP"
  else
    local msg_error="Error configuring DHCP."
    local msg_success="DHCP configuration completed successfully."
    local msg_title="$G_TITLE - DHCP Configuration"
  fi

  # Exécute la commande DHCP
  if sudo dhclient eth0; then
    echo_msgbox "$msg_success" "$msg_title"
    return 0
  else
    echo_msgbox "$msg_error" "$msg_title"
    return 1
  fi

}

# Fonction pour configurer IP statique
# Function to configure static IP
function menu_6_misc_change_config_network_static_ip() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_ok="Valider"
    local msg_dns_prompt="Entrez l'IP de DNS :"
    local msg_error="Adresse IP invalide. Configuration annulée."
    local msg_error_set_dns="Erreur lors de la configuration du serveur DNS."
    local msg_error_set_gateway="Erreur lors de l'ajout de la passerelle."
    local msg_error_set_ip="Erreur lors de la configuration de l'IP et du masque réseau."
    local msg_gateway_prompt="Entrez la passerelle :"
    local msg_ip_prompt="Entrez l'IP statique :"
    local msg_netmask_prompt="Entrez le masque de sous-réseau :"
    local msg_success="Configuration IP statique terminée."
    local msg_title="$G_TITLE - Configuration IP Statique"
  else
    local msg_button_cancel="Back"
    local msg_button_ok="Valid"
    local msg_dns_prompt="Enter the DNS IP :"
    local msg_error="Invalid IP address. Configuration aborted."
    local msg_error_set_dns="Error configuring DNS server."
    local msg_error_set_gateway="Error adding gateway."
    local msg_error_set_ip="Error configuring IP and network mask."
    local msg_gateway_prompt="Enter the gateway :"
    local msg_ip_prompt="Enter the static IP :"
    local msg_netmask_prompt="Enter the subnet mask :"
    local msg_success="Static IP configuration completed."
    local msg_title="$G_TITLE - Static IP Configuration"
  fi

  # Récupère les informations réseau actuelles
  local current_ip=$(network_get_current_ip)
  local current_netmask=$(network_get_current_netmask)
  local current_gateway=$(network_get_current_gateway)
  local current_dns=$(network_get_current_dns)

  # Boucle pour obtenir les informations réseau valides
  while true; do
    # Demande l'adresse IP statique
    local ip
    ip=$(whiptail --inputbox "\n$msg_ip_prompt" 20 70 "$current_ip" --fb --title "$msg_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
    local exit_status=$?
    if [ $exit_status -eq 1 ]; then # Clic "Retour"
      return
    elif [ $exit_status -eq 0 ]; then # Clic "Ok"
      if ! network_validate_ip "$ip"; then
        echo_msgbox "$msg_error" "$msg_title"
        continue
      fi
    fi

    # Demande le masque de sous-réseau
    local netmask
    netmask=$(whiptail --inputbox "\n$msg_netmask_prompt" 20 70 "$current_netmask" --fb --title "$msg_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
    local exit_status=$?
    if [ $exit_status -eq 1 ]; then # Clic "Retour"
      return
    elif [ $exit_status -eq 0 ]; then # Clic "Ok"
      if ! network_validate_ip "$netmask"; then
        echo_msgbox "$msg_error" "$msg_title"
        continue
      fi
    fi

    # Demande la passerelle
    local gateway
    gateway=$(whiptail --inputbox "\n$msg_gateway_prompt" 20 70 "$current_gateway" --fb --title "$msg_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
    local exit_status=$?
    if [ $exit_status -eq 1 ]; then # Clic "Retour"
      return
    elif [ $exit_status -eq 0 ]; then # Clic "Ok"
      if ! network_validate_ip "$gateway"; then
        echo_msgbox "$msg_error" "$msg_title"
        continue
      fi
    fi

    # Demande le DNS
    local dns
    dns=$(whiptail --inputbox "\n$msg_dns_prompt" 20 70 "$current_dns" --fb --title "$msg_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
    local exit_status=$?
    if [ $exit_status -eq 1 ]; then # Clic "Retour"
      return
    elif [ $exit_status -eq 0 ]; then # Clic "Ok"
      if ! network_validate_ip "$dns"; then
        echo_msgbox "$msg_error" "$msg_title"
        continue
      fi
    fi

    break
  done

  # Configure l'adresse IP et le masque de sous-réseau
  if ! sudo ifconfig $(network_get_active_interface) "$ip" netmask "$netmask"; then
    echo_msgbox "$msg_error_set_ip" "$msg_title"
    return 1
  fi

  # Ajoute la passerelle par défaut
  if ! sudo route add default gw "$gateway" $(network_get_active_interface); then
    echo_msgbox "$msg_error_set_gateway" "$msg_title"
    return 1
  fi

  # Configure le serveur DNS
  if ! echo "nameserver $dns" | sudo tee /etc/resolv.conf > /dev/null; then
    echo_msgbox "$msg_error_set_dns" "$msg_title"
    return 1
  fi

  # Affiche un message de succès
  echo_msgbox "$msg_success" "$msg_title"
  return 0

}

# Fonction pour changer le nom d'hôte
# Function to change hostname
function menu_6_misc_change_hostname() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_ok="Valider"
    local msg_error="Erreur lors du changement du nom d'hôte."
    local msg_input_prompt="Entrez un nom d'hôte (hostname)"
    local msg_prompt="Les RFC exigent qu'un nom d'hôte contienne uniquement :\n- les lettres ASCII 'a' à 'z' (insensible à la casse)\n- les chiffres '0' à '9'\n- le trait d'union \"-\"\nLe nom d'hôte ne peut commencer ou se terminer par un trait d'union. Aucun autre symbole n'est autorisé."
    local msg_success="Le nom d'hôte a été changé avec succès."
    local msg_title="$G_TITLE - Changer le nom d'hôte"
  else
    # Par défaut en anglais
    local msg_button_cancel="Back"
    local msg_button_ok="Validate"
    local msg_error="Error changing hostname."
    local msg_input_prompt="Enter a hostname"
    local msg_prompt="The RFCs require that the hostname contain only:\n- the ASCII letters 'a' to 'z' (case-insensitive)\n- the digits '0' to '9'\n- the hyphen '-'\nHostname cannot begin or end with a hyphen. No other symbols are allowed."
    local msg_success="Hostname changed successfully."
    local msg_title="$G_TITLE - Change Hostname"
  fi

  # Extrait le nom d'hôte actuel
  local current_hostname
  current_hostname=$(cat /etc/hostname | tr -d " \t\n\r")

  # Demande le nouveau nom d'hôte en affichant les règles RFC pour le nom d'hôte
  local new_hostname
  new_hostname=$(whiptail --inputbox "\n$msg_prompt \n\n$msg_input_prompt : $current_hostname" 18 70 "$current_hostname" --fb --title "$msg_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
  local exit_status=$?

  # Si l'utilisateur clique sur "Valider"
  if [ $exit_status -eq 0 ]; then
    # Valide le nouveau nom d'hôte
    if [[ ! "$new_hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$ ]]; then
      echo_msgbox "$msg_error" "$msg_title"
      return 1
    fi

    # Change le nom d'hôte
    if sudo hostnamectl set-hostname "$new_hostname"; then
      echo_msgbox "$msg_success" "$msg_title"
      return 0
    else
      echo_msgbox "$msg_error" "$msg_title"
      return 1
    fi
  fi

  return 0
  
}

# Fonction pour configurer le clavier en fonction de la langue
# Function to configure the keyboard according to the language
function menu_6_misc_change_keyboard() {

  # Définir les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_no="Non"
    local msg_button_yes="Oui"
    local msg_layout='fr'
    local msg_no_reboot="Le système ne sera pas redémarré."
    local msg_reboot="Voulez-vous redémarrer le système maintenant ?"
    local msg_title="Changer le clavier pour l'azerty français"
    local msg_variant="latin9"
    local msg_error="Erreur lors de la configuration du clavier."
    local msg_error_file="Le fichier /etc/default/keyboard est introuvable."
    local msg_error_layout="Impossible de modifier la disposition du clavier (XKBLAYOUT)."
    local msg_error_variant="Impossible de modifier la variante du clavier (XKBVARIANT)."
    local msg_error_reconfigure="Échec de la reconfiguration du clavier."
    local msg_error_service="Impossible de redémarrer le service keyboard-setup."
  else
    local msg_button_no="No"
    local msg_button_yes="Yes"
    local msg_layout="us"
    local msg_no_reboot="The system will not be restarted."
    local msg_reboot="Do you want to reboot the system now?"
    local msg_title="Change the keyboard to US QWERTY"
    local msg_variant="intl"
    local msg_error="Error configuring the keyboard."
    local msg_error_file="The file /etc/default/keyboard was not found."
    local msg_error_layout="Failed to modify keyboard layout (XKBLAYOUT)."
    local msg_error_variant="Failed to modify keyboard variant (XKBVARIANT)."
    local msg_error_reconfigure="Failed to reconfigure the keyboard."
    local msg_error_service="Failed to restart the keyboard-setup service."
  fi

  # Vérifier si le fichier de configuration du clavier existe
  if [[ ! -f /etc/default/keyboard ]]; then
    echo_msgbox "$msg_error_file" "$msg_title"
    return 1
  fi

  # Modifier la configuration du clavier
  if ! sudo sed -i "s/XKBLAYOUT=\".*\"/XKBLAYOUT=\"$msg_layout\"/" /etc/default/keyboard; then
    echo_msgbox "$msg_error_layout" "$msg_title"
    return 1
  fi
  if ! sudo sed -i "s/XKBVARIANT=\".*\"/XKBVARIANT=\"$msg_variant\"/" /etc/default/keyboard; then
    echo_msgbox "$msg_error_variant" "$msg_title"
    return 1
  fi

  # Reconfigurer le clavier
  if ! sudo dpkg-reconfigure --frontend=noninteractive keyboard-configuration; then
    echo_msgbox "$msg_error_reconfigure" "$msg_title"
    return 1
  fi
  if ! sudo service keyboard-setup restart; then
    echo_msgbox "$msg_error_service" "$msg_title"
    return 1
  fi

  # Demander à l'utilisateur s'il souhaite redémarrer le système
  if whiptail --yesno "$msg_reboot" 10 60 --fb --title "$msg_title" --yes-button "$msg_button_yes" --no-button "$msg_button_no"; then
    # Lance le reboot avec compte à rebours
    countdown_before_reboot
  else
    echo_msgbox "$msg_no_reboot" "$msg_title"
  fi

  return 0
  
}

# Fonction pour configurer les paramètres régionaux en fonction de la langue
# Function to configure regional settings according to language
function menu_6_misc_change_locales() {

  # Définir les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_no="Non"
    local msg_button_yes="Oui"
    local msg_choose_locales_label="Langue changée pour Français (fr_FR.UTF-8)"
    local msg_locale="fr_FR.UTF-8"
    local msg_no_menu_6_misc_change_locales="Les paramètres régionaux ne seront pas modifiés."
    local msg_no_reboot="Le système ne sera pas redémarré."
    local msg_reboot="Voulez-vous redémarrer maintenant ?"
    local msg_error_file="Le fichier /etc/locale.gen est introuvable."
    local msg_error_locale_gen="Erreur lors de la génération des locales."
    local msg_error_locale_update="Erreur lors de la mise à jour des paramètres régionaux."
    local msg_error_reconfigure="Erreur lors de la reconfiguration des locales."
  else
    local msg_button_no="No"
    local msg_button_yes="Yes"
    local msg_choose_locales_label="Language changed to English (en_GB.UTF-8)"
    local msg_locale="en_GB.UTF-8"
    local msg_no_menu_6_misc_change_locales="Locale settings will not be modified."
    local msg_no_reboot="The system will not be restarted."
    local msg_reboot="Do you want to reboot now?"
    local msg_error_file="The file /etc/locale.gen was not found."
    local msg_error_locale_gen="Error generating locales."
    local msg_error_locale_update="Error updating locale settings."
    local msg_error_reconfigure="Error reconfiguring locales."
  fi

  # Vérifier si le fichier /etc/locale.gen existe
  if [[ ! -f /etc/locale.gen ]]; then
    echo_msgbox "$msg_error_file"
    return 1
  fi

  # Demander à l'utilisateur s'il souhaite modifier les paramètres régionaux
  if whiptail --yesno "$msg_choose_locales_label" 10 60 --fb --title "$G_TITLE" --yes-button "$msg_button_yes" --no-button "$msg_button_no"; then
    # Modifier la configuration des locales
    if ! sudo sed -i "s/^# $msg_locale/$msg_locale/" /etc/locale.gen; then
      echo_msgbox "$msg_error_locale_update"
      return 1
    fi

    # Générer les locales
    if ! sudo locale-gen; then
      echo_msgbox "$msg_error_locale_gen" 
      return 1
    fi

    # Mettre à jour les paramètres régionaux
    if ! echo "LANG=$msg_locale" | sudo tee /etc/default/locale > /dev/null; then
      echo_msgbox "$msg_error_locale_update"
      return 1
    fi
    if ! echo "LC_ALL=$msg_locale" | sudo tee -a /etc/default/locale > /dev/null; then
      echo_msgbox "$msg_error_locale_update"
      return 1
    fi

    # Reconfigurer les locales
    if ! sudo dpkg-reconfigure --frontend=noninteractive locales; then
      echo_msgbox "$msg_error_reconfigure"
      return 1
    fi
  else
    echo_msgbox "$msg_no_menu_6_misc_change_locales"
    return 0
  fi

  # Demander à l'utilisateur s'il souhaite redémarrer le système
  if whiptail --yesno "$msg_reboot" 10 60 --fb --title "$G_TITLE" --yes-button "$msg_button_yes" --no-button "$msg_button_no"; then
    # Lance le reboot avec compte à rebours
    countdown_before_reboot
  else
    echo_msgbox "$msg_no_reboot"
  fi

  return 0
  
}

# Fonction pour changer le mot de passe de l'utilisateur avec vérification
# Function to change the user's password with verification
function menu_6_misc_change_password() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_ok="Valider"
    local msg_error="Erreur lors du changement du mot de passe."
    local msg_invalid="Mot de passe invalide. Veuillez respecter les règles de sécurité."
    local msg_prompt="Entrez un nouveau mot de passe pour l'utilisateur $USER"
    local msg_success="Le mot de passe a été changé avec succès."
    local msg_confirm_invalid="Le mot de passe ne respecte pas les règles de sécurité. Voulez-vous quand même l'utiliser ?"
  else
    # Par défaut en anglais
    local msg_button_cancel="Cancel"
    local msg_button_ok="OK"
    local msg_error="Error changing password."
    local msg_invalid="Invalid password. Please follow security rules."
    local msg_prompt="Enter a new password for the user $USER"
    local msg_success="Password changed successfully."
    local msg_confirm_invalid="The password does not meet security rules. Do you still want to use it?"
  fi

  local new_password=""
  local is_valid=1

  # Boucle jusqu'à ce qu'un mot de passe valide soit saisi ou que l'utilisateur confirme l'utilisation d'un mot de passe invalide
  while [[ $is_valid -ne 0 ]]; do
    new_password=$(whiptail --inputbox "\n$msg_prompt :" 18 70 "gce" --fb --title "$G_TITLE" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)

    # Vérifie si l'utilisateur a annulé
    if [[ -z "$new_password" ]]; then
      return
    fi

    # Vérifie la force du mot de passe avec `passwd`
    echo "$new_password" | sudo passwd --stdin "$USER" &>/dev/null
    is_valid=$?

    if [[ $is_valid -ne 0 ]]; then
      # Propose à l'utilisateur de continuer avec un mot de passe invalide
      if whiptail --yesno "$msg_confirm_invalid" 15 70 --fb --title "$G_TITLE" --yes-button "$msg_button_ok" --no-button "$msg_button_cancel"; then
        is_valid=0  # L'utilisateur a choisi de continuer avec un mot de passe invalide
      else
        echo_msgbox "$msg_invalid"
      fi
    fi
  done

  # Applique le mot de passe si valide ou si l'utilisateur a confirmé l'utilisation d'un mot de passe invalide
  if echo "$USER:$new_password" | sudo chpasswd; then
    echo_msgbox "$msg_success"
  else
    echo_msgbox "$msg_error"
  fi

  return 0
  
}

# Fonction pour changer le fuseau horaire en fonction de la langue
# Function to change time zone depending on language
function menu_6_misc_change_timezone() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_ok="Valider"
    local msg_cancel_msg="Annulation. Aucune sélection effectuée."
    local msg_choose_tz_label="Choisissez votre fuseau horaire:"
    local msg_current_tz_label="Fuseau horaire actuel:"
    local msg_success="Le fuseau horaire a été changé avec succès."
    local msg_title="Sélection du fuseau horaire"
  else
    local msg_button_cancel="Back"
    local msg_button_ok="Validate"
    local msg_cancel_msg="Cancelled. No selection made."
    local msg_choose_tz_label="Choose your timezone:"
    local msg_current_tz_label="Current Timezone:"
    local msg_success="The timezone has been changed successfully."
    local msg_title="Timezone Selection"
  fi

  # Récupérer le fuseau horaire actuel
  local CURRENT_TZ=$(timedatectl | grep "Time zone" | awk '{print $3}')

  # Afficher un menu pour choisir un nouveau fuseau horaire
  local TIMEZONE=$(whiptail --menu "\n$msg_current_tz_label $CURRENT_TZ\n$msg_choose_tz_label" 20 70 8 \
          $(timedatectl list-timezones | awk '{print NR,$1}' | tr '\n' ' ') \
          --fb --title "$G_TITLE" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
  local exit_status=$?

  # Gérer l'annulation de la sélection
  if [ "$exit_status" -eq 1 ]; then
    ecgo_msgbox "$msg_cancel_msg"
    return
  fi

  # Appliquer le nouveau fuseau horaire
  local timezone=$(timedatectl list-timezones | awk -v choice_menu=$TIMEZONE 'NR==choice_menu {print $1}')
  sudo timedatectl set-timezone "$timezone"

  # Afficher un message de succès si la commande a réussi
  if [ $? -eq 0 ]; then
    echo_msgbox "$msg_success"
  fi

}

# Function reduced to a minimal Raspberry Pi OS Lite 64-bit or generic Debian installation with essential packages for Raspberry Pi kernel, GPIO, PCF85063 RTC clock, I2C. It also includes checks and configurations to handle NVMe SSD, common USB devices, essential network tools, SSH etc.
# Fonction réduit à une installation minimale Raspberry Pi OS Lite 64 bits ou Debian générique avec les packages essentiels pour le noyau Raspberry Pi, le GPIO, l'horloge RTC PCF85063, l'I2C. Il inclut également des vérifications et des configurations pour gérer le SSD NVMe, les périphériques USB courants, les outils réseau essentiels, le SSH etc.
function menu_6_misc_clean_system() {

  # Définit les textes en fonction de la langue sélectionnée
  # Set texts based on the selected language
  if [ "$G_LANG" = "fr" ]; then
    local msg_autoclean="Suppression des fichiers de configuration obsolètes..."
    local msg_autoremove="Suppression des packages installés automatiquement..."
    local msg_clean="Suppression des fichiers de cache..."
    local msg_error="Erreur lors du nettoyage du système."
    local msg_journal="Suppression des fichiers de journalisation..."
    local msg_log="Suppression des fichiers de log dans /var/log..."
    local msg_ssh="Vérification et activation du service SSH..."
    local msg_success="Nettoyage du système terminé avec succès."
    local msg_title="Nettoyage du Système"
    local msg_update="Mise à jour de la liste des packages..."
    local msg_remove_non_essential="Suppression des packages non essentiels..."
    local msg_enable_i2c="Activation du support I2C..."
    local msg_install_i2c="Installation des outils I2C..."
    local msg_install_nvme="Installation des outils NVMe..."
    local msg_check_nvme="Vérification de l'état du SSD NVMe..."
    local msg_install_usb="Installation des outils USB..."
    local msg_install_sd="Installation des outils SD..."
    local msg_install_camera="Installation du support pour la caméra Raspberry Pi..."
    local msg_install_kernel="Installation du noyau Raspberry Pi..."
    local msg_install_network="Installation des outils réseau essentiels..."
    local msg_disable_gui="Désactivation de l'interface graphique si présente..."
    local msg_remove_gui="Suppression des packages liés à l'interface graphique..."
    local msg_configure_rtc="Configuration de l'horloge RTC PCF85063..."
    local msg_remove_fake_hwclock="Suppression de fake-hwclock..."
    local msg_add_rtc_boot="Ajout de la commande pour définir l'heure au démarrage..."
  else
    local msg_autoclean="Removing obsolete configuration files..."
    local msg_autoremove="Removing automatically installed packages..."
    local msg_clean="Cleaning up cache files..."
    local msg_error="Error during system cleanup."
    local msg_journal="Cleaning up journal files..."
    local msg_log="Cleaning up log files in /var/log..."
    local msg_ssh="Checking and enabling SSH service..."
    local msg_success="System cleanup completed successfully."
    local msg_title="System Cleanup"
    local msg_update="Updating package list..."
    local msg_remove_non_essential="Removing non-essential packages..."
    local msg_enable_i2c="Enabling I2C support..."
    local msg_install_i2c="Installing I2C tools..."
    local msg_install_nvme="Installing NVMe tools..."
    local msg_check_nvme="Checking NVMe SSD status..."
    local msg_install_usb="Installing USB tools..."
    local msg_install_sd="Installing SD tools..."
    local msg_install_camera="Installing Raspberry Pi camera support..."
    local msg_install_kernel="Installing Raspberry Pi kernel..."
    local msg_install_network="Installing essential network tools..."
    local msg_disable_gui="Disabling GUI if present..."
    local msg_remove_gui="Removing GUI-related packages..."
    local msg_configure_rtc="Configuring PCF85063 RTC clock..."
    local msg_remove_fake_hwclock="Removing fake-hwclock..."
    local msg_add_rtc_boot="Adding command to set time at boot..."
  fi

  echo "$msg_update"
  sudo apt-get update

  echo "$msg_autoremove"
  sudo apt-get autoremove --purge -y

  echo "$msg_autoclean"
  sudo apt-get autoclean -y

  echo "$msg_clean"
  sudo apt-get clean

  echo "$msg_journal"
  sudo journalctl --vacuum-time=1d

  echo "$msg_log"
  sudo rm -rf /var/log/*.log.*
  sudo rm -rf /var/log/*.gz

	local essential_packages=(
    "apt"                # Gestionnaire de packages | Package manager
    "bash"               # Shell Bash | Bash shell
    "coreutils"          # Utilitaires de base | Core utilities
    "dbus"               # Bus de communication inter-processus | Inter-process communication bus
    "dpkg"               # Gestionnaire de packages Debian | Debian package manager
    "e2fsprogs"          # Utilitaires pour systèmes de fichiers ext2/ext3/ext4 | Utilities for ext2/ext3/ext4 filesystems
    "findutils"          # Utilitaires de recherche (find, xargs) | Search utilities (find, xargs)
    "grep"               # Outil de recherche de texte | Text search tool
    "gzip"               # Outil de compression | Compression tool
    "iproute2"           # Outils de gestion réseau avancés | Advanced network tools
    "libc6"              # Bibliothèque C standard | Standard C library
    "libgcc-s1"          # Bibliothèque GCC | GCC library
    "libstdc++6"         # Bibliothèque C++ standard | Standard C++ library
    "logrotate"          # Outil de rotation des logs | Log rotation tool
    "lsb-base"           # Base pour les LSB (Linux Standard Base) | Base for LSB (Linux Standard Base)
    "mawk"               # Interpréteur de commandes AWK | AWK command interpreter
    "mount"              # Outil de montage de systèmes de fichiers | Filesystem mounting tool
    "netbase"            # Base pour les outils réseau | Base for network tools
    "openssl"            # Outil de gestion des certificats SSL | SSL certificate management tool
    "procps"             # Outils pour la gestion des processus | Process management tools
    "sed"                # Outil de manipulation de texte | Text manipulation tool
    "systemd"            # Système d'initialisation | Init system
    "systemd-sysv"       # Compatibilité SysV pour systemd | SysV compatibility for systemd
    "tar"                # Outil de compression tar | Tar compression tool
    "tzdata"             # Données de fuseau horaire | Timezone data
    "util-linux"         # Utilitaires de base pour Linux | Core Linux utilities
    "zlib1g"             # Bibliothèque de compression zlib | zlib compression library
    "openssh-server"     # Serveur SSH pour accès distant | SSH server for remote access
    "raspberrypi-kernel" # Noyau Raspberry Pi | Raspberry Pi kernel
    "i2c-tools"          # Outils pour le support I2C | I2C support tools
    "python3-rpi.gpio"   # Support pour gérer les GPIO en mode prog (node-red) sur Raspberry Pi | GPIO programming support (node-red) for Raspberry Pi
    "raspi-gpio"         # Outils pour gérer les GPIO en mode terminal sur Raspberry Pi | GPIO terminal tools for Raspberry Pi
    "bcm2835-v4l2"       # Support pour la caméra Raspberry Pi | Raspberry Pi camera support
    "nvme-cli"           # Outils pour gérer le SSD NVMe | NVMe SSD tools
    "usbutils"           # Outils pour gérer les périphériques USB | USB device tools
    "sdparm"             # Outils pour gérer les périphériques SD | SD device tools
    "isc-dhcp-client"    # Client DHCP | DHCP client
    "net-tools"          # Outils réseau (ifconfig, netstat) | Network tools (ifconfig, netstat)
    "ifupdown"           # Gestion des interfaces réseau | Network interface management
    "iputils-ping"       # Outils de ping | Ping tools
    "sudo"               # Outil pour exécuter des commandes en tant que root | Tool to run commands as root
    "htop"               # Outil de surveillance des processus | Process monitoring tool
    "nano"               # Éditeur de texte en ligne de commande | Command-line text editor
    "curl"               # Outil de transfert de données | Data transfer tool
    "wget"               # Outil de téléchargement de fichiers | File download tool
	)

  # Suppression des packages non essentiels
  echo "$msg_remove_non_essential"
  sudo apt-get purge $(dpkg -l | awk '{print $2}' | grep -vE "$(IFS=\|; echo "${essential_packages[*]}")") -y

  # Active le ssh
  echo "$msg_ssh"
  if ! command -v ssh &> /dev/null; then
    menu_4_system_tools_openssh_server
  fi
  sudo systemctl enable ssh
  sudo systemctl start ssh

  # Activation du support I2C
  echo "$msg_enable_i2c"
  if [ -f /etc/modules ]; then
    if ! grep -q "^i2c-dev" /etc/modules; then
      echo "i2c-dev" | sudo tee -a /etc/modules
    fi
    if ! grep -q "^i2c-bcm2708" /etc/modules; then
      echo "i2c-bcm2708" | sudo tee -a /etc/modules
    fi
  fi
  
	# Active le module I2C pour l'utilisation de périphériques I2C (capteurs, écrans, etc.)
  if [ -f /etc/modprobe.d/raspi-blacklist.conf ]; then
    sudo sed -i 's/^blacklist i2c-bcm2708/#blacklist i2c-bcm2708/' /etc/modprobe.d/raspi-blacklist.conf
  fi
  if [ -f /boot/config.txt ]; then
    if ! grep -q "^dtparam=i2c_arm=on" /boot/config.txt; then
      echo "dtparam=i2c_arm=on" | sudo tee -a /boot/config.txt
    fi
  fi

  # Installation des outils I2C...
  echo "$msg_install_i2c"
  sudo apt-get install -y i2c-tools

  # Installation des outils NVMe
  echo "$msg_install_nvme"
  sudo apt-get install -y nvme-cli

  # Vérification de l'état du SSD NVMe
  echo "$msg_check_nvme"
  sudo nvme list
  
	# Installation des outils USB
  echo "$msg_install_usb"
  sudo apt-get install -y usbutils
  
	# Installation des outils SD
  echo "$msg_install_sd"
  sudo apt-get install -y sdparm

  # Installation du support pour la caméra Raspberry Pi*
  echo "$msg_install_camera"
  sudo apt-get install -y bcm2835-v4l2

  # Installation du noyau Raspberry Pi
  echo "$msg_install_kernel"
  sudo apt-get install -y raspberrypi-kernel

  # Installation des outils réseau essentiels
  echo "$msg_install_network"
  sudo apt-get install -y isc-dhcp-client net-tools ifupdown iputils-ping iproute2

  # Désactivation de l'interface graphique si présente
  echo "$msg_disable_gui"
  if dpkg -l | grep -q "xserver-xorg"; then
    echo "$msg_remove_gui"
    sudo apt-get purge -y xserver-xorg* x11-common lightdm lxde* gnome* kde* xfce*
    sudo apt-get autoremove --purge -y
    sudo systemctl set-default multi-user.target
  fi

  # Configuration de l'horloge RTC PCF85063
  echo "$msg_configure_rtc"
  if [ -f /boot/config.txt ]; then
    if ! grep -q "^dtoverlay=i2c-rtc,pcf85063" /boot/config.txt; then
      echo "dtoverlay=i2c-rtc,pcf85063" | sudo tee -a /boot/config.txt
    fi
  fi
  echo "$msg_remove_fake_hwclock"
  sudo apt-get -y remove fake-hwclock
  sudo update-rc.d -f fake-hwclock remove

  # Ajout de la commande pour définir l'heure au démarrage
  echo "$msg_add_rtc_boot"
  if [ -f /etc/rc.local ]; then
    if ! grep -q "hwclock -s" /etc/rc.local; then
      sudo sed -i '/exit 0/i \
      if [ -e /run/systemd/system ]; then \
        systemctl restart hwclock-save; \
      else \
        hwclock -s; \
      fi' /etc/rc.local
    fi
  fi

  echo "$msg_success"
	
}

# Fonction pour faire le backup de la configuration
# Function to back up the configuration
function menu_6_misc_config_backup() {

  # Répertoire de sauvegarde
  local BACKUP_DIR="backup_configs"
  local CURRENT_DIR=""

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_app_config="Sauvegarde de la configuration de l'application myapp..."
    local msg_backup_services="Sauvegarde de la configuration des services de sauvegarde..."
    local msg_db="Sauvegarde des bases de données MySQL..."
    local msg_db_msg="Sauvegarde de la configuration MySQL..."
    local msg_db_services="Sauvegarde de la configuration MySQL..."
    local msg_devices="Sauvegarde de la configuration des périphériques..."
    local msg_dir_created="Le répertoire de sauvegarde $BACKUP_DIR a été créé."
    local msg_dir_not_exist="Le répertoire n'existe pas "
    local msg_docker_services="Sauvegarde de la configuration Docker..."
    local msg_dovecot_services="Sauvegarde de la configuration Dovecot..."
    local msg_kernel="Sauvegarde de la configuration des paramètres du noyau..."
    local msg_locale="Sauvegarde de la configuration des paramètres locaux..."
    local msg_mail_services="Sauvegarde de la configuration Postfix..."
    local msg_monitoring_services="Sauvegarde de la configuration Nagios..."
    local msg_network="Sauvegarde de la configuration du réseau..."
    local msg_nginx_services="Sauvegarde de la configuration Nginx..."
    local msg_packages="Sauvegarde des packages installés..."
    local msg_packages_error="Erreur lors de la sauvegarde des packages installés."
    local msg_postgresql_services="Sauvegarde de la configuration PostgreSQL..."
    local msg_security_services="Sauvegarde de la configuration des services de sécurité..."
    local msg_services="Sauvegarde de la configuration des services..."
    local msg_sources="Sauvegarde de la configuration des sources de logiciels..."
    local msg_ssl_certs="Sauvegarde des certificats SSL..."
    local msg_ssh_keys="Sauvegarde des clés SSH..."
    local msg_success="Les configurations ont été sauvegardées dans $BACKUP_DIR."
    local msg_title="Sauvegarde de la configuration" 
    local msg_tool_not_installed=" n'est pas installé. La sauvegarde est ignorée."
    local msg_users_groups="Sauvegarde de la configuration des utilisateurs et des groupes..."
    local msg_virtualization_services="Sauvegarde de la configuration Libvirt..."
    local msg_web_services="Sauvegarde de la configuration Apache..."
    local msg_zabbix_services="Sauvegarde de la configuration Zabbix..."
  else
    local msg_app_config="Backing up myapp application configuration..."
    local msg_backup_services="Backing up backup services configuration..."
    local msg_db="Backing up MySQL databases..."
    local msg_db_msg="Backing up MySQL configuration..."
    local msg_db_services="Backing up MySQL configuration..."
    local msg_devices="Backing up devices configuration..."
    local msg_dir_created="The backup directory $BACKUP_DIR has been created."
    local msg_dir_not_exist="The directory does not exist "
    local msg_docker_services="Backing up Docker configuration..."
    local msg_dovecot_services="Backing up Dovecot configuration..."
    local msg_kernel="Backing up kernel configuration..."
    local msg_locale="Backing up locale configuration..."
    local msg_mail_services="Backing up Postfix configuration..."
    local msg_monitoring_services="Backing up Nagios configuration..."
    local msg_network="Backing up network configuration..."
    local msg_nginx_services="Backing up Nginx configuration..."
    local msg_packages="Backing up installed packages..."
    local msg_packages_error="Error backing up installed packages."
    local msg_postgresql_services="Backing up PostgreSQL configuration..."
    local msg_security_services="Backing up security services configuration..."
    local msg_services="Backing up services configuration..."
    local msg_sources="Backing up software sources configuration..."
    local msg_ssl_certs="Backing up SSL certificates..."
    local msg_ssh_keys="Backing up SSH keys..."
    local msg_success="Configurations have been backed up to $BACKUP_DIR."
    local msg_title="Backup configuration" 
    local msg_tool_not_installed=" is not installed. Backup skipped."
    local msg_users_groups="Backing up users and groups configuration..."
    local msg_virtualization_services="Backing up Libvirt configuration..."
    local msg_web_services="Backing up Apache configuration..."
    local msg_zabbix_services="Backing up Zabbix configuration..."
  fi
  
  # Affiche dans le terminal le début du traitement
  echo_process_start "$msg_title"
  
  # Créer le répertoire de sauvegarde
  echo_step_start "$msg_dir_created"
  sudo mkdir -p "$BACKUP_DIR"
  echo_step_stop "$msg_dir_created"

  # Liste des packages installés
  echo_step_start "$msg_packages"
  sudo dpkg -l | grep '^ii' > "$BACKUP_DIR/package_installed.txt"
  if [ $? -ne 0 ]; then
    echo_step_info "$msg_packages_error"
    return 1
  else   
    echo_step_stop "$msg_packages"
  fi

  # Configuration du réseau
  echo_step_start "$msg_network"
  sudo cp /etc/network/interfaces "$BACKUP_DIR/interfaces.backup"
  sudo cp /etc/resolv.conf "$BACKUP_DIR/resolv.conf.backup"
  echo_step_stop "$msg_network"

  # Configuration des utilisateurs et des groupes
  echo_step_start "$msg_users_groups"
  sudo cp /etc/passwd "$BACKUP_DIR/passwd.backup"
  sudo cp /etc/group "$BACKUP_DIR/group.backup"
  sudo cp /etc/shadow "$BACKUP_DIR/shadow.backup"
  sudo cp /etc/gshadow "$BACKUP_DIR/gshadow.backup"
  echo_step_stop "$msg_users_groups"

  # Configuration des services
  echo_step_start "$msg_services"
  sudo cp -r /etc/systemd "$BACKUP_DIR/systemd.backup"
  sudo cp -r /etc/default "$BACKUP_DIR/default.backup"
  echo_step_stop "$msg_services"

  # Configuration des périphériques
  echo_step_start "$msg_devices"
  sudo cp -r /etc/modprobe.d "$BACKUP_DIR/modprobe.d.backup"
  sudo cp -r /etc/udev "$BACKUP_DIR/udev.backup"
  echo_step_stop "$msg_devices"
  
  # Configuration des sources de logiciels
  echo_step_start "$msg_sources"
  sudo cp /etc/apt/sources.list "$BACKUP_DIR/sources.list.backup"
  sudo cp -r /etc/apt/sources.list.d "$BACKUP_DIR/sources.list.d.backup"
  echo_step_stop "$msg_sources"

  # Configuration des paramètres locaux
  echo_step_start "$msg_locale"
  sudo cp /etc/timezone "$BACKUP_DIR/timezone.backup"
  sudo cp /etc/localtime "$BACKUP_DIR/localtime.backup"
  sudo cp /etc/default/locale "$BACKUP_DIR/locale.backup"
  echo_step_stop "$msg_locale"

  # Configuration des paramètres du noyau
  echo_step_start "$msg_kernel"
  sudo cp /boot/config.txt "$BACKUP_DIR/config.txt.backup"
  sudo cp /boot/cmdline.txt "$BACKUP_DIR/cmdline.txt.backup"
  echo_step_stop "$msg_kernel"

  # Configuration des services web (si applicable)
  echo_step_start "$msg_web_services"
  if [ -d /etc/apache2 ]; then
    sudo cp -r /etc/apache2 "$BACKUP_DIR/apache2.backup"
    echo_step_stop "$msg_web_services"
  else
    echo_step_info "$msg_dir_not_exist (/etc/apache2) - services web "
  fi
  echo_step_start "$msg_nginx_services"
  if [ -d /etc/nginx ]; then
    sudo cp -r /etc/nginx "$BACKUP_DIR/nginx.backup"
    echo_step_stop "$msg_nginx_services"
  else
    echo_step_info "$msg_dir_not_exist (/etc/nginx) - nginx"
  fi

  # Configuration des services de base de données (si applicable)
  echo_step_start "$msg_db_services"
  if [ -d /etc/mysql ]; then
    sudo cp -r /etc/mysql "$BACKUP_DIR/mysql.backup"
    echo_step_stop "$msg_db_services"
  else
    echo_step_info "$msg_dir_not_exist (/etc/mysql) - database"
  fi
  echo_step_start "$msg_postgresql_services"
  if [ -d /etc/postgresql ]; then
    sudo cp -r /etc/postgresql "$BACKUP_DIR/postgresql.backup"
    echo_step_stop "$msg_postgresql_services"
  else
    echo_step_info "$msg_dir_not_exist (/etc/postgresql) - postgresql"
  fi

  # Configuration des services de sécurité
  echo_step_start "$msg_security_services"
  sudo cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.backup"
  sudo cp -r /etc/ufw "$BACKUP_DIR/ufw.backup"
  echo_step_stop "$msg_security_services"

  # Configuration des services de sauvegarde
  echo_step_start "$msg_backup_services"
  sudo cp -r /etc/cron.d "$BACKUP_DIR/cron.d.backup"
  sudo cp -r /etc/cron.daily "$BACKUP_DIR/cron.daily.backup"
  sudo cp -r /etc/cron.hourly "$BACKUP_DIR/cron.hourly.backup"
  sudo cp -r /etc/cron.monthly "$BACKUP_DIR/cron.monthly.backup"
  sudo cp -r /etc/cron.weekly "$BACKUP_DIR/cron.weekly.backup"
  echo_step_stop "$msg_backup_services"

  # Configuration des services de virtualisation (si applicable)
  echo_step_start "$msg_docker_services"
  if [ -d /etc/docker ]; then
    sudo cp -r /etc/docker "$BACKUP_DIR/docker.backup"
    echo_step_stop "$msg_docker_services"
  else
    echo_step_info "$msg_dir_not_exist (/etc/docker)"
  fi

  # Sauvegarde des bases de données (exemple pour MySQL)
  echo_step_start "$msg_db"
  if command -v mysqldump &> /dev/null; then
    sudo mysqldump --all-databases > "$BACKUP_DIR/mysql_backup.sql"
    echo_step_stop "$msg_db"
  else
    echo_step_info "mysqldump $msg_tool_not_installed - MysSql"
  fi

  # Sauvegarde des clés SSH
  echo_step_start "$msg_ssh_keys"
  sudo cp -r /etc/ssh "$BACKUP_DIR/ssh.backup"
  echo_step_stop "$msg_ssh_keys"

  # Sauvegarde des certificats SSL
  echo_step_start "$msg_ssl_certs"
  sudo cp -r /etc/ssl "$BACKUP_DIR/ssl.backup"
  echo_step_stop "$msg_ssl_certs"

  # Sauvegarde des fichiers de configuration spécifiques aux applications
  echo_step_start "$msg_app_config"
  if [ -d /etc/myapp ]; then
    sudo cp -r /etc/myapp "$BACKUP_DIR/myapp.backup"
    echo_step_stop "$msg_app_config"
  else
    echo_step_info "$msg_dir_not_exist (/etc/myapp) - Applications"
  fi

  # Afficher un message de confirmation
  echo_step_start "$msg_success"
  echo_step_stop "$msg_success"

  # Affiche dans le terminal la fin du traitement
  sleep 1
  echo_process_stop "$msg_title"
  
  return 0

}

# Fonction pour afficher le Message Of The Day au démarrage d'une SSH
# Function to display the Message Of The Day at SSH startup
function menu_6_misc_config_motd() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_yes="Ok"
    local msg_button_no="Retour"
    local msg_cancel_operation="Opération annulée."
    local msg_cancellation_title="Annulation"
    local msg_confirm_disable_files="Les fichiers suivants seront désactivés en les renommant avec le suffixe .disabled :\n\n%s\n\nVoulez-vous continuer ?"
    local msg_confirmation_title="Confirmation"
    local msg_disable_success="Tous les fichiers dans /etc/update-motd.d/ ont été désactivés."
    local msg_disable_title="Désactivation"
    local msg_file_exist_replace="Le fichier /etc/motd existe déjà.\nSouhaitez-vous le désactiver et configurer un MOTD dynamique ?"
    local msg_files_in_update_motd="Fichiers dans /etc/update-motd.d/ :\n\n%s"
    local msg_modele_not_found="Matériel inconnu"
    local msg_motd_config_tool="Outil de configuration pour $G_TITLE"
    local msg_motd_cpu_info="Informations CPU"
    local msg_motd_cpu_temp="Température du CPU"
    local msg_motd_device_model="Modèle de l'appareil"
    local msg_motd_disk_size="Taille du disque"
    local msg_motd_kernel="Noyau"
    local msg_motd_lan_ip="Adresse IP locale"
    local msg_motd_optimal_temp="Température optimale"
    local msg_motd_os="Système d'exploitation"
    local msg_motd_partitions="Partitions"
    local msg_motd_ram="Mémoire RAM"
    local msg_motd_resource_monitor="Moniteur de ressources"
    local msg_motd_disable="Le fichier /etc/motd a été désactivé."
    local msg_no_update_message="Le MOTD n'a pas été modifié."
    local msg_title="Configuration dynamique du MOTD"
    local msg_update_message="Le MOTD dynamique a été configuré."
  else
    local msg_button_cancel="Cancel"
    local msg_button_no="Back"
    local msg_button_yes="Ok"
    local msg_cancel_operation="Operation canceled."
    local msg_cancellation_title="Cancellation"
    local msg_confirm_disable_files="The following files will be disabled by renaming them with the suffix .disabled:\n\n%s\n\nDo you want to continue?"
    local msg_confirmation_title="Confirmation"
    local msg_disable_success="All files in /etc/update-motd.d/ have been disabled."
    local msg_disable_title="Disable"
    local msg_file_exist_replace="The file /etc/motd already exists.\nDo you want to disable it and configure a dynamic MOTD?"
    local msg_files_in_update_motd="Files in /etc/update-motd.d/ :\n\n%s"
    local msg_modele_not_found="Unknown hardware"
    local msg_motd_config_tool="Configuration tool for $G_TITLE"
    local msg_motd_cpu_info="CPU information"
    local msg_motd_cpu_temp="CPU temperature"
    local msg_motd_device_model="Device model"
    local msg_motd_disk_size="Disk size"
    local msg_motd_kernel="Kernel"
    local msg_motd_lan_ip="LAN IP"
    local msg_motd_optimal_temp="Optimal temperature"
    local msg_motd_os="Operating System"
    local msg_motd_partitions="Partitions"
    local msg_motd_ram="RAM"
    local msg_motd_resource_monitor="Resource monitor"
    local msg_motd_disable="The /etc/motd file has been disabled."
    local msg_no_update_message="The MOTD has not been modified."
    local msg_title="Dynamic MOTD Configuration"
    local msg_update_message="Dynamic MOTD has been configured."
  fi

  # Désactive tous les fichiers motd (s'ils existent)
  if [ -d "/etc/update-motd.d" ]; then
    sudo chmod -x /etc/update-motd.d/* 2>/dev/null || true
  fi
  if [ -f "/etc/motd" ]; then
    sudo chmod -x /etc/motd
  fi
  if [ -f "/etc/issue" ]; then
    sudo chmod -x /etc/issue
  fi
  if [ -f "/etc/issue.net" ]; then
    sudo chmod -x /etc/issue.net
  fi

  # Désactive et renomme les fichiers MOTD (s'ils existent)
  if [ -d "/etc/update-motd.d" ]; then
    for file in /etc/update-motd.d/*; do
      if [ -f "$file" ]; then
        sudo mv "$file" "$file.back"
      fi
    done
  fi
  if [ -f "/etc/motd" ]; then
    sudo mv /etc/motd /etc/motd.back
  fi
  if [ -f "/etc/issue" ]; then
    sudo mv /etc/issue /etc/issue.back
  fi
  if [ -f "/etc/issue.net" ]; then
    sudo mv /etc/issue.net /etc/issue.net.back
  fi

  # Créer un script dynamique dans /etc/update-motd.d/
  local MOTD_SCRIPT="/etc/update-motd.d/99-dynamic-motd"
  cat <<EOF > "$MOTD_SCRIPT"
#!/bin/bash
# Script dynamique pour le MOTD

# Effacer l'écran
# clear

# Récupérer le modèle de l'appareil
if [ -f /proc/device-tree/model ]; then
  DEVICE_MODEL=\$(cat /proc/device-tree/model | tr -d '\0')
else
  DEVICE_MODEL="$msg_modele_not_found"
fi

# Récupérer la version de l'OS
OS_INFO=\$(lsb_release -d | cut -f2-)
if [ -z "\$OS_INFO" ]; then
  OS_INFO=\$(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')
fi

# Récupérer la version du noyau
KERNEL_VERSION=\$(uname -r)

# Récupérer l'adresse IP
IP=\$(hostname -I 2>/dev/null | awk '{print \$1}')
if [ \$? -ne 0 ] || [ -z "\$IP" ]; then
  IP="N/A"
fi

# Récupérer la température du CPU
TEMP=\$(vcgencmd measure_temp 2>/dev/null | cut -d= -f2)
if [ \$? -ne 0 ] || [ -z "\$TEMP" ]; then
  TEMP="N/A"
fi

# Récupérer la date et l'heure actuelles
DATE_TIME=\$(date +"%Y-%m-%d %H:%M")

# Récupérer la RAM totale et utilisée
RAM_TOTAL=\$(free -m | awk '/^Mem:/{print \$2}')
RAM_USED=\$(free -m | awk '/^Mem:/{print \$3}')

# Récupérer la taille du disque
DISK_SIZE_GB=\$(lsblk -o SIZE /dev/nvme0n1 | awk 'NR==2{print \$1}')
if [ -z "\$DISK_SIZE_GB" ]; then
  DISK_SIZE_GB="N/A"
fi

# Récupérer les partitions spécifiques et les trier par nom
PARTITIONS=\$(df -h | grep -E '/dev/nvme0n1p1|/dev/nvme0n1p2' | sort | awk '{printf "  %-15s : %4s / %4s (%s)\n", \$1, \$3, \$2, \$5}')

# Afficher le contenu du MOTD
echo -e "\n\n\n\n\n\n\n\n"
# clear
echo "───────────────────────────────────────────────────────────────────────"
echo " $G_TITLE - \$DATE_TIME"
echo "───────────────────────────────────────────────────────────────────────"
echo " - $msg_motd_device_model : \$DEVICE_MODEL"
echo " - $msg_motd_os : \$OS_INFO"
echo " - $msg_motd_kernel : \$KERNEL_VERSION"
echo "───────────────────────────────────────────────────────────────────────"
echo " - $msg_motd_cpu_temp : \$TEMP - $msg_motd_optimal_temp"
echo " - $msg_motd_ram : \$RAM_USED/\$RAM_TOTAL MB"
echo " - $msg_motd_disk_size : \$DISK_SIZE_GB"
echo " - $msg_motd_partitions :"
echo "\$PARTITIONS"
echo " - $msg_motd_lan_ip : \$IP (eth0)"
echo "───────────────────────────────────────────────────────────────────────"
echo " nrx800-config : $msg_motd_config_tool"
echo " htop          : $msg_motd_resource_monitor"
echo " cpu           : $msg_motd_cpu_info"
echo "───────────────────────────────────────────────────────────────────────"
echo ""
EOF

  # Rendre le script exécutable
  sudo chmod +x "$MOTD_SCRIPT"

  echo_msgbox "$msg_update_message" "$msg_title"

}

# Fonction pour configurer le serveur NTP
# Function to configure the NTP server
function menu_6_misc_config_ntp_server() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_yes="Ok"
    local msg_button_no="Retour"
    local msg_error="Erreur lors de la configuration du serveur NTP."
    local msg_message="\nEntrez le serveur NTP à utiliser (par défaut: fr.pool.ntp.org):"
    local msg_sntp_port_prompt="Entrez le port sur lequel les appareils se synchroniseront (défaut: 123):"
    local msg_sntp_server_prompt="Entrez le serveur NTP à utiliser (par défaut: fr.pool.ntp.org):"
    local msg_success="Serveur NTP configuré avec succès."
    local msg_title="Configuration du Serveur NTP"
  else
    local msg_button_cancel="Cancel"
    local msg_button_no="Back"
    local msg_button_yes="Ok"
    local msg_error="Error configuring NTP server."
    local msg_message="\nEnter the NTP server to use (default: fr.pool.ntp.org):"
    local msg_sntp_port_prompt="Enter the port on which devices will synchronize (default: 123):"
    local msg_sntp_server_prompt="Enter the NTP server to use (default: fr.pool.ntp.org):"
    local msg_success="NTP server configured successfully."
    local msg_title="NTP Server Configuration"
  fi

  # Demande à l'utilisateur de saisir le serveur NTP
  local sntp_server=$(whiptail --inputbox "$msg_message" 10 60 "fr.pool.ntp.org" --title "$msg_title" 3>&1 1>&2 2>&3)
  local exit_status=$?
  if [ $exit_status -ne 0 ]; then
    return 1
  fi
  if [ -z "$sntp_server" ]; then
    sntp_server="fr.pool.ntp.org"
  fi

  # Demande à l'utilisateur de saisir le port NTP
  local sntp_port=$(whiptail --inputbox "$msg_sntp_port_prompt" 20 70 "123" --ok-button "Ok" --cancel-button "Cancel" --title "$G_TITLE" 3>&1 1>&2 2>&3)
  local exit_status=$?
  if [ $exit_status -ne 0 ]; then
    return 1
  fi
  if [ -z "$sntp_port" ]; then
    sntp_port="123"
  fi

  # Modifie la configuration du serveur NTP
  sudo sed -i "s/^pool .*/server $sntp_server/" /etc/ntp.conf
  sudo sed -i "s/^port .*/port $sntp_port/" /etc/ntp.conf

  # Vérifie si la modification a réussi
  if [ $? -eq 0 ]; then
    echo_msgbox "$msg_success" "$msg_title"
  else
    echo_msgbox "$msg_error" "$msg_title"
    return 1
  fi

  # Redémarre le service NTP
  sudo systemctl restart ntp

}

# Fonction pour créer le fichier de boot
# Function to create the boot file
function menu_6_misc_create_boot_firmware_config.txt() {

  # Définir les textes en fonction de la langue sélectionnée
  if [ "$LANG" = "fr" ]; then
    local msg_confirm_rename="Le fichier $CONFIG_FILE existe déjà. Voulez-vous le renommer en $BACKUP_FILE et créer un nouveau fichier ?"
    local msg_created="Le fichier $CONFIG_FILE a été créé avec succès."
    local msg_operation_canceled="Opération annulée. Le fichier $CONFIG_FILE n'a pas été modifié."
    local msg_renamed="Le fichier $CONFIG_FILE a été renommé en $BACKUP_FILE."
    local msg_button_yes="Oui"
    local msg_button_no="Non"
  else
    local msg_confirm_rename="The file $CONFIG_FILE already exists. Do you want to rename it to $BACKUP_FILE and create a new file?"
    local msg_created="The file $CONFIG_FILE has been created successfully."
    local msg_operation_canceled="Operation canceled. The file $CONFIG_FILE has not been modified."
    local msg_renamed="The file $CONFIG_FILE has been renamed to $BACKUP_FILE."
    local msg_button_yes="Yes"
    local msg_button_no="No"
  fi

  # Chemin du fichier de configuration
  CONFIG_FILE="/boot/firmware/config.txt"
  BACKUP_FILE="/boot/firmware/config.txt.old"

  # Contenu du fichier de configuration
CONFIG_CONTENT=$(cat <<EOF
# DO NOT EDIT THIS FILE
#
# The file you are looking for has moved to /boot/firmware/config.txt
# Pour plus d'options et d'informations, voir le lien ci-dessous
# http://rptl.io/configtxt
# Certaines configurations peuvent affecter les fonctionnalités de l'appareil. Consultez le lien ci-dessus pour plus de détails.
# Décommentez une ou plusieurs lignes pour activer les interfaces matérielles optionnelles

# Active l'interface I2C (bus de communication)
dtparam=i2c_arm=on
# (Commenté) Active l'interface I2S (audio numérique)

#dtparam=i2s=on
# (Commenté) Active l'interface SPI (bus de communication rapide)
#dtparam=spi=on

# Active l'audio (charge le module snd_bcm2835 pour le son)
dtparam=audio=on

# Documentation supplémentaire sur les overlays et paramètres
# se trouve dans /boot/firmware/overlays/README

# Charge automatiquement les overlays pour les caméras détectées
# Active la détection automatique des caméras
camera_auto_detect=1

# Charge automatiquement les overlays pour les écrans DSI détectés
# Active la détection automatique des écrans DSI
display_auto_detect=1

# Charge automatiquement les fichiers initramfs s'ils sont trouvés
# Active le chargement automatique des fichiers initramfs
auto_initramfs=1

# Active le pilote DRM VC4 V3D pour le GPU
# Pilote pour l'accélération graphique
dtoverlay=vc4-kms-v3d
# Définit le nombre maximum de framebuffers (tampons d'images)
max_framebuffers=2

# Empêche le firmware de créer un paramètre initial "video=" dans cmdline.txt.
# Utilise à la place les paramètres par défaut du noyau.
# Désactive la configuration KMS par le firmware
disable_fw_kms_setup=1

# Active le mode 64 bits sur le processeur ARM
# Passe le processeur en mode 64 bits
arm_64bit=1             

# Désactive la compensation pour les écrans avec overscan (bordures noires)
# Désactive l'overscan
disable_overscan=1

# Permet au processeur ARM de fonctionner à la vitesse maximale autorisée par le firmware/carte
# Boost des performances du processeur
arm_boost=1

# Paramètres spécifiques pour le Raspberry Pi Compute Module 4 (CM4)
[cm4]
# Active le mode hôte sur le contrôleur USB intégré 2711 XHCI
# Supprimez cette ligne si vous avez besoin du contrôleur USB DWC2 legacy
# (pour les modes périphériques USB par exemple) ou si le support USB n'est pas nécessaire.
# Active le mode hôte USB sur le CM4
otg_mode=1

# Désactive le Bluetooth sur le CM4
# Désactive le Bluetooth
dtoverlay=disable-bt

# Active l'horloge temps réel (RTC) sur le bus I2C (caméra et affichage)
# Active le bus I2C pour la caméra et l'affichage
dtparam=i2c_vc=on       
# Active la puce RTC PCF85063A
dtoverlay=i2c-rtc,pcf85063a,i2c_csi_dsi,addr=0x51  

# Paramètres communs à tous les modèles de Raspberry Pi
[all]
# Active l'UART (communication série)
enable_uart=1
EOF
)

  # Vérifier si le fichier existe déjà
  if [ -f "$CONFIG_FILE" ]; then
      # Demander une confirmation avec whiptail avant de renommer et écrire le fichier
      if whiptail --yesno "$msg_confirm_rename" 10 60 --fb --yes-button "$msg_button_yes" --no-button "$msg_button_no"; then
        mv "$CONFIG_FILE" "$BACKUP_FILE"
        echo "$msg_renamed"
      else
        echo "$msg_operation_canceled"
        exit 0
      fi
  fi

  # Créer le fichier de configuration
  echo "$CONFIG_CONTENT" | sudo tee "$CONFIG_FILE" > /dev/null

  echo "$msg_created"

}

# Fonction pour étendre la partition du disque selon une taille définie par l'utilisateur
# Function to extend disk partition to user defined size
function menu_6_misc_expand_rootfs() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_no="Non"
    local msg_button_ok="Suivant"
    local msg_button_yes="Oui"
    local msg_disk_prompt="Sélectionnez le disque à étendre :"
    local msg_free_space_prompt="taille libre disponible :"
    local msg_no_disk_message="Aucun disque détecté."
    local msg_no_partition_message="Aucune partition détectée sur le disque sélectionné."
    local msg_partition_prompt="Sélectionnez la partition à étendre :"
    local msg_size_prompt="Entrez la nouvelle taille (en Go) pour la partition :"
  else
    local msg_button_cancel="Back"
    local msg_button_no="No"
    local msg_button_ok="Next"
    local msg_button_yes="Yes"
    local msg_disk_prompt="Select the disk to expand :"
    local msg_free_space_prompt="available free space :"
    local msg_no_disk_message="No disk detected."
    local msg_no_partition_message="No partition detected on the selected disk."
    local msg_partition_prompt="Select the partition to extend :"
    local msg_size_prompt="Enter the new size (in GB) for the partition :"
  fi

  # Lister les disques physiques avec leur taille
  list_disks=$(lsblk -o NAME,SIZE,TYPE | grep 'disk' | awk '{print "/dev/" $1 " (" $2 ")"}')

  if [ -z "$list_disks" ]; then
    echo_msgbox "$msg_no_disk_message"
    return
  fi

  # Préparer les options pour whiptail --menu
  local menu_options=()
  local i=0
  while IFS= read -r line; do
    menu_options+=("$((++i))" "$line")
  done <<< "$list_disks"

  # Afficher un menu pour sélectionner le disque
  selected_disk=$(whiptail --menu "\n$msg_disk_prompt" 16 70 4 "${menu_options[@]}" --fb --title "$G_TITLE" --cancel-button "$msg_button_cancel" --ok-button "$msg_button_ok" 3>&1 1>&2 2>&3)
  local exit_status=$?

  if [ $exit_status -ne 0 ]; then
    echo_msgbox "menu_6_misc_expand_rootfs \n$exit_status"
    return
  fi

  # Récupérer le disque sélectionné
  selected_disk=$(echo "$list_disks" | awk -v disk=$selected_disk 'NR==disk {print $1}' | sed 's/ (.*//')

  # Lister les partitions du disque sélectionné avec leur taille
  local partitions
  partitions=$(lsblk -o NAME,SIZE,TYPE $selected_disk | grep 'part' | awk '{print "/dev/" $1 " (" $2 ")"}')

  # Nettoyer la sortie pour supprimer les caractères spéciaux (├─ et └─)
  partitions=$(echo "$partitions" | sed 's/[├─└─]//g')

  if [ -z "$partitions" ]; then
    echo_msgbox "$msg_no_partition_message"
    return
  fi

  # Préparer les options pour whiptail --menu
  local partition_options=()
  local i=0
  while IFS= read -r line; do
    partition_options+=("$((++i))" "$line")
  done <<< "$partitions"

  # Afficher un menu pour sélectionner la partition
  local selected_partition
  selected_partition=$(whiptail --menu "\n$msg_partition_prompt" 16 70 4 "${partition_options[@]}" --fb --title "$G_TITLE" --cancel-button "$msg_button_cancel" --ok-button "$msg_button_ok" 3>&1 1>&2 2>&3)
  if [ $? -ne 0 ]; then
    return
  fi

  # Récupérer la partition sélectionnée
  selected_partition=$(echo "$partitions" | awk -v partition=$selected_partition 'NR==partition {print $1 " " $2}' | sed 's/ (.*//')

  # Obtenir la taille libre disponible du disque
  local free_space=$(sudo parted $selected_disk unit GB print free | grep 'Free Space' | tail -n 1 | awk '{print $3}' | sed 's/GB//')

  # Demander la taille à étendre pour la partition
  local new_size
  new_size=$(whiptail --inputbox "\n$msg_size_prompt\n$selected_partition ($msg_free_space_prompt $free_space Go) :" 16 70 $free_space --fb --title "$G_TITLE" --cancel-button "$msg_button_cancel" --ok-button "$msg_button_ok" 3>&1 1>&2 2>&3)
  if [ $? -ne 0 ]; then
    return
  fi

  # Valider et étendre la partition
  disk_extend_partition $selected_disk $selected_partition $new_size

}



########## FONCTION INVENTAIRE - INVENTORY

# Fonction pour lister pilotes, packages, services, matériel, fichiers, configurer le MOTD, créer une sauvegarde etc
# Function to list drivers, packages, services, hardware, files, configure MOTD, create a backup etc.
function menu_7_inventory() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_ok="Suivant"
    local msg_message="Choisissez l'action à effectuer :"
    local msg_options=(
      "1" "Lister les packages" ON
      "2" "Lister les packages et leurs dépendances" OFF
      "3" "Lister les packages npm" OFF
      "4" "Lister les packages npm et leurs dépendances" OFF
      "5" "Lister les packages nodered" OFF
      "6" "Lister les pilotes" OFF
      "7" "Lister les services" OFF
      "8" "Lister le matériel" OFF
      "9" "Lister tous les fichiers" OFF
      "10" "Lister tout" OFF
    )
    local msg_title="$G_TITLE - Inventaire"
  else
    local msg_button_cancel="Back"
    local msg_button_ok="Next"
    local msg_message="Choose the action to perform :"
    local msg_options=(
      "1" "List packages" ON
      "2" "List packages and their dependencies" OFF
      "3" "List npm packages" OFF
      "4" "List npm packages and their dependencies" OFF
      "5" "List nodered packages" OFF
      "6" "List drivers" OFF
      "7" "List services" OFF
      "8" "List hardware" OFF
      "9" "List all files" OFF
      "10" "List all" OFF
    )
    local msg_title="$G_TITLE - Inventory"
  fi

  while true; do
    # Afficher la boîte de dialogue
    local choice_menu
    choice_menu=$(whiptail --radiolist "\n$msg_message" 20 70 10 "${msg_options[@]}" --fb --title "$msg_title" --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" --notags 3>&1 1>&2 2>&3)
    # Récupérer le statut de sortie
    local exit_status=$?
    
    # clic "Retour"
    if [ $exit_status -eq 1 ]; then
      return 0
    fi
    
    # clic "Sélectionner"
    if [ $exit_status -eq 0 ]; then 
      case $choice_menu in
        1) menu_7_inventory_list_packages ;;
        2) menu_7_inventory_list_packages_dependencies ;;
        3) menu_7_inventory_list_packages_npm ;;
        4) menu_7_inventory_list_packages_npm_dependencies ;;
        5) menu_7_inventory_list_packages_nodered ;;
        6) menu_7_inventory_list_drivers ;;
        7) menu_7_inventory_list_services ;;
        8) menu_7_inventory_list_hardware ;;
        9) menu_7_inventory_list_all_files ;;
        10)
          G_CHOICE="ALL"
          menu_7_inventory_list_packages
          menu_7_inventory_list_packages_dependencies
          menu_7_inventory_list_packages_npm
          menu_7_inventory_list_packages_npm_dependencies
          menu_7_inventory_list_packages_nodered
          menu_7_inventory_list_drivers
          menu_7_inventory_list_services
          menu_7_inventory_list_hardware
          menu_7_inventory_list_all_files
          G_CHOICE="" ;;
      esac  
    fi
  done

}

# Fonction pour restaurer la configuration
# Function to restore the configuration
function menu_7_inventory_config_restore() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_app_config="Restauration de la configuration de l'application myapp..."
    local msg_backup_dir_not_exist="Le répertoire de sauvegarde $BACKUP_DIR n'existe pas."
    local msg_backup_services="Restauration de la configuration des services de sauvegarde..."
    local msg_db="Restauration des bases de données MySQL..."
    local msg_db_services="Restauration de la configuration MySQL..."
    local msg_devices="Restauration de la configuration des périphériques..."
    local msg_docker_services="Restauration de la configuration Docker..."
    local msg_dovecot_services="Restauration de la configuration Dovecot..."
    local msg_kernel="Restauration de la configuration des paramètres du noyau..."
    local msg_locale="Restauration de la configuration des paramètres locaux..."
    local msg_mail_services="Restauration de la configuration Postfix..."
    local msg_monitoring_services="Restauration de la configuration Nagios..."
    local msg_network="Restauration de la configuration du réseau..."
    local msg_nginx_services="Restauration de la configuration Nginx..."
    local msg_packages="Restauration des packages installés..."
    local msg_packages_error="Erreur lors de la restauration des packages installés."
    local msg_postgresql_services="Restauration de la configuration PostgreSQL..."
    local msg_security_services="Restauration de la configuration des services de sécurité..."
    local msg_services="Restauration de la configuration des services..."
    local msg_sources="Restauration de la configuration des sources de logiciels..."
    local msg_ssl_certs="Restauration des certificats SSL..."
    local msg_ssh_keys="Restauration des clés SSH..."
    local msg_success="Les configurations ont été restaurées avec succès."
    local msg_users_groups="Restauration de la configuration des utilisateurs et des groupes..."
    local msg_virtualization_services="Restauration de la configuration Libvirt..."
    local msg_web_services="Restauration de la configuration Apache..."
    local msg_zabbix_services="Restauration de la configuration Zabbix..."
  else
    local msg_app_config="Restoring myapp application configuration..."
    local msg_backup_dir_not_exist="The backup directory $BACKUP_DIR does not exist."
    local msg_backup_services="Restoring backup services configuration..."
    local msg_db="Restoring MySQL databases..."
    local msg_db_services="Restoring MySQL configuration..."
    local msg_devices="Restoring devices configuration..."
    local msg_docker_services="Restoring Docker configuration..."
    local msg_dovecot_services="Restoring Dovecot configuration..."
    local msg_kernel="Restoring kernel configuration..."
    local msg_locale="Restoring locale configuration..."
    local msg_mail_services="Restoring Postfix configuration..."
    local msg_monitoring_services="Restoring Nagios configuration..."
    local msg_network="Restoring network configuration..."
    local msg_nginx_services="Restoring Nginx configuration..."
    local msg_packages="Restoring installed packages..."
    local msg_packages_error="Error restoring installed packages."
    local msg_postgresql_services="Restoring PostgreSQL configuration..."
    local msg_security_services="Restoring security services configuration..."
    local msg_services="Restoring services configuration..."
    local msg_sources="Restoring software sources configuration..."
    local msg_ssl_certs="Restoring SSL certificates..."
    local msg_ssh_keys="Restoring SSH keys..."
    local msg_success="Configurations have been restored successfully."
    local msg_users_groups="Restoring users and groups configuration..."
    local msg_virtualization_services="Restoring Libvirt configuration..."
    local msg_web_services="Restoring Apache configuration..."
    local msg_zabbix_services="Restoring Zabbix configuration..."
  fi

  # Répertoire de sauvegarde
  local BACKUP_DIR="backup_configs"
  
  # Vérifier si le répertoire de sauvegarde existe
  if [ ! -d "$BACKUP_DIR" ]; then
    echo "$msg_backup_dir_not_exist"
    return 1
  fi

  # Restaurer les packages installés
  echo "$msg_packages"
  awk '{print $2}' "$BACKUP_DIR/package_installed.txt" | xargs apt-get install -y
  if [ $? -ne 0 ]; then
    echo "$msg_packages_error"
    return 1
  fi

  # Restaurer la configuration du réseau
  echo "$msg_network"
  cp "$BACKUP_DIR/interfaces.backup" /etc/network/interfaces
  cp "$BACKUP_DIR/resolv.conf.backup" /etc/resolv.conf

  # Restaurer la configuration des utilisateurs et des groupes
  echo "$msg_users_groups"
  cp "$BACKUP_DIR/passwd.backup" /etc/passwd
  cp "$BACKUP_DIR/group.backup" /etc/group
  cp "$BACKUP_DIR/shadow.backup" /etc/shadow
  cp "$BACKUP_DIR/gshadow.backup" /etc/gshadow

  # Restaurer la configuration des services
  echo "$msg_services"
  cp -r "$BACKUP_DIR/systemd.backup/"* /etc/systemd/
  cp -r "$BACKUP_DIR/default.backup/"* /etc/default/

  # Restaurer la configuration des périphériques
  echo "$msg_devices"
  cp -r "$BACKUP_DIR/modprobe.d.backup/"* /etc/modprobe.d/
  cp -r "$BACKUP_DIR/udev.backup/"* /etc/udev/

  # Restaurer la configuration des sources de logiciels
  echo "$msg_sources"
  cp "$BACKUP_DIR/sources.list.backup" /etc/apt/sources.list
  cp -r "$BACKUP_DIR/sources.list.d.backup/"* /etc/apt/sources.list.d/

  # Restaurer la configuration des paramètres locaux
  echo "$msg_locale"
  cp "$BACKUP_DIR/timezone.backup" /etc/timezone
  cp "$BACKUP_DIR/localtime.backup" /etc/localtime
  cp "$BACKUP_DIR/locale.backup" /etc/default/locale

  # Restaurer la configuration des paramètres du noyau
  echo "$msg_kernel"
  cp "$BACKUP_DIR/config.txt.backup" /boot/config.txt
  cp "$BACKUP_DIR/cmdline.txt.backup" /boot/cmdline.txt

  # Restaurer la configuration des services web (si applicable)
  if [ -d "$BACKUP_DIR/apache2.backup" ]; then
    echo "$msg_web_services"
    cp -r "$BACKUP_DIR/apache2.backup/"* /etc/apache2/
  fi
  if [ -d "$BACKUP_DIR/nginx.backup" ]; then
    echo "$msg_nginx_services"
    cp -r "$BACKUP_DIR/nginx.backup/"* /etc/nginx/
  fi

  # Restaurer la configuration des services de base de données (si applicable)
  if [ -d "$BACKUP_DIR/mysql.backup" ]; then
    echo "$msg_db_services"
    cp -r "$BACKUP_DIR/mysql.backup/"* /etc/mysql/
  fi
  if [ -d "$BACKUP_DIR/postgresql.backup" ]; then
    echo "$msg_postgresql_services"
    cp -r "$BACKUP_DIR/postgresql.backup/"* /etc/postgresql/
  fi

  # Restaurer la configuration des services de courrier (si applicable)
  if [ -d "$BACKUP_DIR/postfix.backup" ]; then
    echo "$msg_mail_services"
    cp -r "$BACKUP_DIR/postfix.backup/"* /etc/postfix/
  fi
  if [ -d "$BACKUP_DIR/dovecot.backup" ]; then
    echo "$msg_dovecot_services"
    cp -r "$BACKUP_DIR/dovecot.backup/"* /etc/dovecot/
  fi

  # Restaurer la configuration des services de sécurité
  echo "$msg_security_services"
  cp "$BACKUP_DIR/sshd_config.backup" /etc/ssh/sshd_config
  cp -r "$BACKUP_DIR/ufw.backup/"* /etc/ufw/

  # Restaurer la configuration des services de sauvegarde
  echo "$msg_backup_services"
  cp -r "$BACKUP_DIR/cron.d.backup/"* /etc/cron.d/
  cp -r "$BACKUP_DIR/cron.daily.backup/"* /etc/cron.daily/
  cp -r "$BACKUP_DIR/cron.hourly.backup/"* /etc/cron.hourly/
  cp -r "$BACKUP_DIR/cron.monthly.backup/"* /etc/cron.monthly/
  cp -r "$BACKUP_DIR/cron.weekly.backup/"* /etc/cron.weekly/

  # Restaurer la configuration des services de surveillance
  if [ -d "$BACKUP_DIR/nagios3.backup" ]; then
    echo "$msg_monitoring_services"
    cp -r "$BACKUP_DIR/nagios3.backup/"* /etc/nagios3/
  fi
  if [ -d "$BACKUP_DIR/zabbix.backup" ]; then
    echo "$msg_zabbix_services"
    cp -r "$BACKUP_DIR/zabbix.backup/"* /etc/zabbix/
  fi

  # Restaurer la configuration des services de virtualisation (si applicable)
  if [ -d "$BACKUP_DIR/libvirt.backup" ]; then
    echo "$msg_virtualization_services"
    cp -r "$BACKUP_DIR/libvirt.backup/"* /etc/libvirt/
  fi
  if [ -d "$BACKUP_DIR/docker.backup" ]; then
    echo "$msg_docker_services"
    cp -r "$BACKUP_DIR/docker.backup/"* /etc/docker/
  fi

  # Restaurer les bases de données (exemple pour MySQL)
  if [ -f "$BACKUP_DIR/mysql_backup.sql" ]; then
    echo "$msg_db"
    mysql < "$BACKUP_DIR/mysql_backup.sql"
  fi

  # Restaurer les clés SSH
  echo "$msg_ssh_keys"
  cp -r "$BACKUP_DIR/ssh.backup/"* /etc/ssh/

  # Restaurer les certificats SSL
  echo "$msg_ssl_certs"
  cp -r "$BACKUP_DIR/ssl.backup/"* /etc/ssl/

  # Restaurer les fichiers de configuration spécifiques aux applications
  if [ -d "$BACKUP_DIR/myapp.backup" ]; then
    echo "$msg_app_config"
    cp -r "$BACKUP_DIR/myapp.backup/"* /etc/myapp/
  fi

  # Afficher un message de confirmation
  echo "$msg_success"
  return 0

}

# Fonction pour lister tous les fichiers dans first_launch.txt avec leur taille et date de création
# Function to list all files in first_launch.txt with their size and creation date
function menu_7_inventory_list_all_files() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_title="Inventaire de tout les fichiers ($total_files)"
    local msg_scan="Scan du système en cours, cela peut prendre plusieurs minutes..."
    local msg_success="La liste complète a été enregistrée dans:\n%s\n\nNombre de fichiers listés: %s"
    local msg_warning="Certains dossiers nécessitent des permissions élevées et n'ont pas été scannés."
    local msg_error_listing="Aucun fichier n'a pu être listé. Vérifiez les permissions système."
    local msg_error_scan="Dossiers non scannés"
  else
    local msg_title="All file Inventory ($total_files)"
    local msg_scan="System scan in progress, this may take several minutes..."
    local msg_success="Complete list has been saved to:\n%s\n\nTotal files listed: %s"
    local msg_warning="Some directories require elevated permissions and were not scanned."
    local msg_error_listing="No file could be listed. Check system permissions."
    local msg_error_scan="Unscanned files"
  fi

  # Fichier de sortie
  local output_file="$G_USER_DIR/nrx800_list_all_files.txt"
  local temp_file=$(mktemp)

  # Compter le nombre total de fichiers sur le système
  total_files=$(find / -type f 2>/dev/null | wc -l)

  # Efface l'écran 
  [ "$G_CLEAR" == "True" ] && clear

  # Affiche le début du traitement
  if [ "$G_CHOICE" = "ALL" ]; then
    echo_step_start "$msg_title"
  else
    # Affiche dans le terminal le début du process en cours
    echo_process_start "$msg_title"
  fi  

  # Commande optimisée pour le scan
  {
    # Scan des dossiers accessibles
    find / -type f -exec ls -lh --time-style=long-iso {} + 2>/dev/null | awk '{print $5, $6, $7, $8, $9}'
    
    # Ajout des erreurs de permissions dans un format lisible
    find / -type d \( -path '/proc' -o -path '/sys' -o -path '/dev' \) -prune -o -print 2>&1 | 
    grep -i "denied" | 
    sort -u | 
    awk '{print "[ACCESS DENIED] " $0}'
  } > "$temp_file"

  # Traitement des résultats
  if [ -s "$temp_file" ]; then
  
    # Compter le nombre de fichiers listés
    local file_count=$(grep -v "ACCESS DENIED" "$temp_file" | wc -l)
    local denied_count=$(grep -c "ACCESS DENIED" "$temp_file")
    
    # Déplacer le fichier temporaire vers la sortie finale
    mv "$temp_file" "$output_file"

    # Message de résultat
    if [ "$G_CHOICE" = "ALL" ]; then
      # Affiche dans le terminal la fin de l'étape en cours
       echo_step_stop "$msg_title"
    else    
      # Affiche dans le terminal la fin de l'étape en cours
       echo_step_stop "$msg_scan"

      # Affiche la fin du traitement
      echo_process_stop "$msg_title"

      whiptail --title "$msg_title" \
             --msgbox "$(printf "$msg_success" "$output_file" "$file_count")\n\n$msg_warning\n($msg_error_scan): $denied_count)" 20 70
    fi    
    return 0
  else
    rm -f "$temp_file"
    whiptail --title "$msg_title" --msgbox "$msg_error_listing" 10 60
    return 1

  fi

}

# Fonction pour lister les drivers installés
# Function to list the installed drivers
function menu_7_inventory_list_drivers() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_detailed_info="Informations détaillées sur les drivers :"
    local msg_error="Erreur : Impossible de lister les drivers. Vérifiez les permissions."
    local msg_file_output="La liste des drivers installés a été enregistrée dans %s"
    local msg_kernel_messages="Messages du noyau relatifs aux drivers :"
    local msg_module_not_found="Module %s non trouvé dans /lib/modules/$(uname -r)/"
    local msg_modules_loaded="Modules du noyau chargés :"
    local msg_pci_devices="Périphériques PCI :"
    local msg_usb_devices="Périphériques USB :"
    local msg_process_start="Lister les drivers installés"
    local msg_process_stop="Traitement des drivers installés terminé"
    local msg_title="Inventaire des drivers"
  else
    local msg_detailed_info="Detailed information about drivers :"
    local msg_error="Error: Unable to list drivers. Check permissions."
    local msg_file_output="The list of installed drivers has been saved in %s"
    local msg_kernel_messages="Kernel messages related to drivers:"
    local msg_module_not_found="Module %s not found in /lib/modules/$(uname -r)/"
    local msg_modules_loaded="Loaded kernel modules:"
    local msg_pci_devices="PCI devices:"
    local msg_usb_devices="USB devices:"
    local msg_process_start="Listing installed drivers"
    local msg_process_stop="Processing of installed drivers completed"
    local msg_title="Drivers Inventory"
  fi
  # Fichier de sortie
  local output_file="$G_USER_DIR/nrx800_list_drivers.txt"

  # Vider le fichier de sortie
  > "$output_file"
  
    # Affiche le début du traitement
  if [ "$G_CHOICE" = "ALL" ]; then
    echo_step_start "$msg_title"
  else
    # Avertissement sur le temps d'exécution
    whiptail --infobox "$msg_scan" 8 60 --title "$msg_title"
    
    [ "$G_CLEAR" == "True" ] && clear
    # Affiche dans le terminal le début du process en cours
    echo_process_start "$msg_process_start"
    
  fi  
  
  # Lister les modules du noyau chargés
  if [ "$G_CHOICE" != "ALL" ]; then echo_step_start "Kernel"; fi
  echo "$msg_modules_loaded" >> "$output_file"
  if ! lsmod >> "$output_file"; then
    echo "$msg_error" >&2
    return 1
  fi
  echo "" >> "$output_file"
  # Obtenir des informations détaillées sur chaque module
  echo "$msg_detailed_info" >> "$output_file"
  for module in $(lsmod | awk '{print $1}'); do
    if [ -e "/lib/modules/$(uname -r)/$module.ko" ]; then
      if ! modinfo "$module" >> "$output_file"; then
        echo "$msg_error" >&2
        return 1
      fi
      echo "----------------------------------------" >> "$output_file"
    else
      printf "$msg_module_not_found\n" "$module" >> "$output_file"
    fi
  done
  echo "" >> "$output_file"
  # Lister les messages du noyau relatifs aux drivers
  echo "$msg_kernel_messages" >> "$output_file"
  if ! dmesg | grep -i driver >> "$output_file"; then
    echo "$msg_error" >&2
    return 1
  fi
  echo "" >> "$output_file"
  if [ "$G_CHOICE" != "ALL" ]; then echo_step_stop "Kernel"; fi

  # Lister les périphériques PCI
  if [ "$G_CHOICE" != "ALL" ]; then echo_step_start "PCI"; fi
  echo "$msg_pci_devices" >> "$output_file"
  if ! lspci -k >> "$output_file"; then
    echo "$msg_error" >&2
    return 1
  fi
  echo "" >> "$output_file"
  if [ "$G_CHOICE" != "ALL" ]; then echo_step_stop "PCI"; fi

  # Lister les périphériques USB
  if [ "$G_CHOICE" != "ALL" ]; then echo_step_start "USB"; fi
  echo "$msg_usb_devices" >> "$output_file"
  if ! lsusb -v >> "$output_file"; then
    echo "$msg_error" >&2
    return 1
  fi
  echo "" >> "$output_file"
  if [ "$G_CHOICE" != "ALL" ]; then echo_step_stop "USB"; fi

  # Message de résultat
  if [ "$G_CHOICE" = "ALL" ]; then
    # Affiche dans le terminal la fin de l'étape en cours
     echo_step_stop "$msg_title"
  else    

    # Affiche la fin du traitement
    echo_process_stop "$msg_title"

    whiptail --title "$msg_title" \
           --msgbox "$(printf "$msg_success" "$output_file" "$file_count")\n\n$msg_warning\n(Dossiers non scannés: $denied_count)" \
           20 70
    sleep 2
    [ "$G_CLEAR" == "True" ] && clear
  fi    

  return 0

}

# Fonction pour lister l'inventaire matériel
# Function to list the hardware inventory
function menu_7_inventory_list_hardware() {

  # Définition des messages en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_exec_cmd_error="Erreur lors de l'exécution de la commande"
    local msg_fichier_sortie="Inventaire matériel enregistré dans %s"
    local msg_installation_lshw="Installation de lshw en cours..."
    local msg_lshw_non_installe="lshw n'est pas installé. Installation en cours..."
    local msg_mise_a_jour_terminee="Mise à jour des paquets terminée."
    local msg_installation_terminee="Installation de lshw terminée."
    local hardware_sections=(
      "Informations matérielles détaillées (lshw)"
      "Périphériques PCI (lspci -v)"
      "Périphériques USB (lsusb -v)"
      "Informations DMI (dmidecode)"
      "Informations système (uname -a)"
      "Informations CPU (/proc/cpuinfo)"
      "Informations mémoire (/proc/meminfo)"
      "Espace disque (df -h)"
      "Partitionnement disque (fdisk -l)"
    )
  else
    local msg_exec_cmd_error="Error while executing the command"
    local msg_fichier_sortie="Hardware inventory saved in %s"
    local msg_installation_lshw="Installing lshw..."
    local msg_lshw_non_installe="lshw is not installed. Installing now..."
    local msg_mise_a_jour_terminee="Package update completed."
    local msg_installation_terminee="lshw installation completed."
    local hardware_sections=(
      "Detailed hardware information (lshw)"
      "PCI devices (lspci -v)"
      "USB devices (lsusb -v)"
      "DMI information (dmidecode)"
      "System information (uname -a)"
      "CPU information (/proc/cpuinfo)"
      "Memory information (/proc/meminfo)"
      "Disk space (df -h)"
      "Disk partitioning (fdisk -l)"
    )
  fi

  # Chemin du fichier de sortie
  local output_file="$G_USER_DIR/nrx800_list_hardware.txt"

  # Vider le fichier de sortie avant d'écrire dedans
  > "$output_file"

  # Vérifier si lshw est installé, sinon l'installer avec une boîte de dialogue
  if ! command -v lshw &> /dev/null; then
    echo "$msg_lshw_non_installe"
    
    # Utiliser whiptail pour afficher une boîte de dialogue pendant l'installation
    (
      echo "XXX"
      echo "0"
      echo "$msg_lshw_non_installe"
      echo "XXX"
      sudo apt-get update 2>&1 | while read line; do
        echo "XXX"
        echo $line
        echo "XXX"
      done
      echo "XXX"
      echo "50"
      echo "$msg_mise_a_jour_terminee"
      echo "XXX"
      sudo apt-get install -y lshw 2>&1 | while read line; do
        echo "XXX"
        echo $line
        echo "XXX"
      done
      echo "XXX"
      echo "100"
      echo "$msg_installation_terminee"
      echo "XXX"
    ) | whiptail --gauge "/n$msg_installation_lshw" 6 60 0 --fb --title "$G_TITLE" 
  fi


  # Liste les infos matérielles "Informations matérielles détaillées (lshw)"
  echo "=== ${hardware_sections[0]} ===" >> "$output_file"
  if ! lshw >> "$output_file" 2>&1; then
    echo "$msg_exec_cmd_error : lshw" >> "$output_file"
  fi
  echo -e "\n" >> "$output_file"

  # Liste les infos matérielles "Périphériques PCI (lspci -v)"
  echo "=== ${hardware_sections[1]} ===" >> "$output_file"
  if ! lspci -v >> "$output_file" 2>&1; then
    echo "$msg_exec_cmd_error : lspci -v" >> "$output_file"
  fi
  echo -e "\n" >> "$output_file"

  # Liste les infos matérielles "Périphériques USB (lsusb -v)"
  echo "=== ${hardware_sections[2]} ===" >> "$output_file"
  if ! lsusb -v >> "$output_file" 2>&1; then
    echo "$msg_exec_cmd_error : lsusb -v" >> "$output_file"
  fi
  echo -e "\n" >> "$output_file"

  # Liste les infos matérielles "Informations DMI (dmidecode)"
  echo "=== ${hardware_sections[3]} ===" >> "$output_file"
  if ! dmidecode >> "$output_file" 2>&1; then
    echo "$msg_exec_cmd_error : dmidecode" >> "$output_file"
  fi
  echo -e "\n" >> "$output_file"

  # Liste les infos matérielles "Informations système (uname -a)"
  echo "=== ${hardware_sections[4]} ===" >> "$output_file"
  if ! uname -a >> "$output_file" 2>&1; then
    echo "$msg_exec_cmd_error : uname -a" >> "$output_file"
  fi
  echo -e "\n" >> "$output_file"

  # Liste les infos matérielles "Informations CPU (/proc/cpuinfo)"
  echo "=== ${hardware_sections[5]} ===" >> "$output_file"
  if ! cat /proc/cpuinfo >> "$output_file" 2>&1; then
    echo "$msg_exec_cmd_error : cat /proc/cpuinfo" >> "$output_file"
  fi
  echo -e "\n" >> "$output_file"

  # Liste les infos matérielles "Informations mémoire (/proc/meminfo)"
  echo "=== ${hardware_sections[6]} ===" >> "$output_file"
  if ! cat /proc/meminfo >> "$output_file" 2>&1; then
    echo "$msg_exec_cmd_error : cat /proc/meminfo" >> "$output_file"
  fi
  echo -e "\n" >> "$output_file"

  # Liste les infos matérielles "Espace disque (df -h)"
  echo "=== ${hardware_sections[7]} ===" >> "$output_file"
  if ! df -h >> "$output_file" 2>&1; then
    echo "$msg_exec_cmd_error : df -h" >> "$output_file"
  fi
  echo -e "\n" >> "$output_file"

  # Liste les infos matérielles "Partitionnement disque (fdisk -l)"
  echo "=== ${hardware_sections[8]} ===" >> "$output_file"
  if ! fdisk -l >> "$output_file" 2>&1; then
    echo "$msg_exec_cmd_error : fdisk -l" >> "$output_file"
  fi
  echo -e "\n" >> "$output_file"

  # Afficher un message de confirmation
  printf "$msg_fichier_sortie\n" "$output_file"
  return 0
  
}


# Fonction pour lister les packages installés sans leurs dépendances (spécifique à Debian/Ubuntu utilisant dpkg)
# Function to list installed packages without their dependencies (specific to Debian/Ubuntu using dpkg)
function menu_7_inventory_list_packages() {

  # Définition des messages en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_dpkg_not_installed="dpkg n'est pas installé sur ce système. Cette fonction est spécifique à Debian/Ubuntu."
    local msg_unable_list_packages="Erreur : Impossible de lister les packages installés."
    local msg_file_exists="Attention : Le fichier %s existe déjà et sera remplacé."
    local msg_file_output="La liste des packages installés a été enregistrée dans %s"
    local msg_process_start="Lister les packages installés"
    local msg_process_stop="Traitement des packages installés terminé"
		local msg_title="Inventaire des packages"
    local msg_scan="Scan du système en cours, cela peut prendre plusieurs secondes..."
  else
    local msg_dpkg_not_installed="dpkg is not installed on this system. This function is specific to Debian/Ubuntu."
    local msg_unable_list_packages="Error: Unable to list installed packages."
    local msg_file_exists="Warning: The file %s already exists and will be overwritten."
    local msg_file_output="The list of installed packages has been saved in %s"
    local msg_process_start="Listing installed packages"
    local msg_process_stop="Processing of installed packages completed"
		local msg_title="Packages Inventory"
    local msg_scan="System scan in progress, this may take several secondes..."
  fi

  # Vérifier si dpkg est installé
  if ! command -v dpkg &> /dev/null; then
    echo "$msg_dpkg_not_installed" >&2
    return 1
  fi

  # Fichier de sortie
  local output_file="$G_USER_DIR/nrx800_list_packages.txt"
 
   # Affiche le début du traitement
  if [ "$G_CHOICE" = "ALL" ]; then
    echo_step_start "$msg_title"
  else
    # Avertissement sur le temps d'exécution
    whiptail --infobox "$msg_scan" 8 60 --title "$msg_title"
    
    [ "$G_CLEAR" == "True" ] && clear
    # Affiche dans le terminal le début du process en cours
    echo_process_start "$msg_process_start"
    
  fi  
 
  # Récupérer la liste des packages
  local packages=$(dpkg -l | awk '/^ii/ {print $2}')
  
  # Vérifier si la commande a réussi
  if [ $? -eq 0 ]; then
  
    # Vider le fichier de sortie (s'il existe)
    > "$output_file"
    
    # Convertir la liste des packages 
    while IFS= read -r package; do
      echo_step_start ""$package""
      
      # Écrire le package dans le fichier de sortie
      echo "$package" >> "$output_file"
      
      echo_step_stop ""$package""
    done <<< "$packages"

  else
    echo_msgbox "$msg_unable_list_packages"
    return 1
  fi

  # Afficher un message de confirmation
  printf "$msg_output_file\n" "$output_file"

  # Affiche la fin du traitement
  echo_process_stop "$msg_process_stop"
  sleep 2
  [ "$G_CLEAR" == "True" ] && clear
  
  # Afficher un message de confirmation
  echo_msgbox "$(printf "$msg_file_output $output_file")"
  
  
  # Message de résultat
  if [ "$G_CHOICE" = "ALL" ]; then
    # Affiche dans le terminal la fin de l'étape en cours
    echo_step_stop "$msg_title"
  else    
    # Affiche dans le terminal la fin de l'étape en cours
    echo_step_stop "$msg_scan"

    # Affiche la fin du traitement
    echo_process_stop "$msg_title"

    whiptail --title "$msg_title" \
         --msgbox "$(printf "$msg_success" "$output_file" "$file_count")\n\n$msg_warning\n(Dossiers non scannés: $denied_count)" \
         20 70
  fi    

  return 0
  
}

# Fonction pour lister les packages installés (spécifique à Debian/Ubuntu utilisant dpkg)
# Function to list installed packages (specific to Debian/Ubuntu using dpkg)
function menu_7_inventory_list_packages_dependencies() {

  # Définition des messages en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_dpkg_not_installed="dpkg n'est pas installé sur ce système. Cette fonction est spécifique à Debian/Ubuntu."
    local msg_file_output="La liste des packages avec dépendances installés a été enregistrée dans %s"
    local msg_unable_list_packages="Impossible de lister les packages installés"
    local msg_process_start="Lister les packages et leurs dépendances installés"
    local msg_process_stop="Traitement des packages et leurs dépendances installés terminé"
  else
    local msg_dpkg_not_installed="dpkg is not installed on this system. This function is specific to Debian/Ubuntu."
    local msg_file_output="The list of installed packages with dependencies has been saved in %s"
    local msg_unable_list_packages="Unable to list installed packages"
    local msg_process_start="Listing installed packages and dependancies"
    local msg_process_stop="Processing of installed packages and dependencies completed"
  fi

  # Vérifier si dpkg est installé
  if ! command -v dpkg &> /dev/null; then
    echo "$msg_dpkg_not_installed" >&2
    return 1
  fi

  # Fichier de sortie
  local output_file="$G_USER_DIR/nrx800_list_packages_and_dependancies.txt"

  # Affiche le début du traitement
  [ "$G_CLEAR" == "True" ] && clear
  echo_process_start "$msg_process_start"
  
  # Récupérer la liste des packages
  local packages=$(sudo dpkg -l | grep '^ii')

  # Vérifier si la commande a réussi
  if [ $? -eq 0 ]; then

    # Vider le fichier de sortie (s'il existe)
    > "$output_file"
    
    # Convertir la liste des packages 
    while IFS= read -r package; do
    #  echo_step_start ""$package""
      
      # Écrire le package dans le fichier de sortie
      echo "$package" >> "$output_file"
      
     # echo_step_stop ""$package""
    done <<< "$packages"

  else
    echo_msgbox "$msg_unable_list_packages"
    return 1
  fi  
  

  # Affiche la fin du traitement
  echo_process_stop "$msg_process_stop"
  sleep 2
  [ "$G_CLEAR" == "True" ] && clear
  
  # Afficher un message de confirmation
  echo_msgbox "$(printf "$msg_file_output $output_file")"
  return 0
  
}

# Fonction pour lister les modules installés dans Node-RED
# Function to list installed Node-RED modules
function menu_7_inventory_list_packages_nodered() {

  # Définition des messages en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_no="Non"
    local msg_button_yes="Oui"
    local msg_error_npm_list="Erreur : Impossible de lister les modules Node-RED installés."
    local msg_error_nodered_path="Erreur : Le répertoire $HOME/.node-red n'existe pas./nNode-RED est-il installé ?"
    local msg_file_exist="Attention : Le fichier %s existe déjà et sera remplacé."
    local msg_file_output="La liste des modules Node-RED installés a été enregistrée dans %s."
    local msg_npm_not_installed="npm n'est pas installé sur ce système. Cette fonction nécessite npm."
    local msg_process_start="Lister les modules installés avec Node-RED"
    local msg_process_stop="Traitement des modules installés avec Node-RED terminé"
  else
    local msg_button_no="No"
    local msg_button_yes="Yes"
    local msg_error_npm_list="Error: Unable to list installed Node-RED modules."
    local msg_error_nodered_path=" Error: The directory $HOME/.node-red does not exist./nIs Node-RED installed ?"
    local msg_file_exist="Warning: The file %s already exists and will be overwritten."
    local msg_file_output="The list of installed Node-RED modules has been saved in %s."
    local msg_npm_not_installed="npm is not installed on this system. This function requires npm."
    local msg_process_start="Listing installed Node-RED modules"
    local msg_process_stop="Processing of installed Node-RED modules completed"
  fi

  # Vérifier si npm est installé
  if ! command -v npm &> /dev/null; then
    echo_msgbox "$msg_npm_not_installed"
    return 1
  fi

  # Vérifier si le dossier ~/.node-red existe (G_USER_DIR donne le HOME de l'utilisateur)
  if [ ! -d "$G_USER_DIR/.node-red" ]; then
    echo_msgbox "$msg_error_nodered_path"
    return 1
  fi

  # Fichier de sortie
  local output_file="$G_USER_DIR/nrx800_list_nodered_npm.txt"

  # Lister les modules installés localement dans ~/.node-red
  [ "$G_CLEAR" == "True" ] && clear 
  echo_process_start "$msg_process_start"
  
  # Déplace vers le repertoire node-red
  cd "$G_USER_DIR/.node-red" || exit 1

  # Récupérer la liste des packages
  local packages=$(npm list --depth=0 | awk -F' ' '/├──|└──/ {print $2}')

  # Vérifier si la commande a réussi
  if [ $? -eq 0 ]; then
    
    # Vider le fichier de sortie (s'il existe)
    > "$output_file"
    
    # Convertir la liste des packages 
    while IFS= read -r package; do
      echo_step_start ""$package""
      
      # Écrire le package dans le fichier de sortie
      echo "$package" >> "$output_file"
      
      echo_step_stop ""$package""
    done <<< "$packages"
    
  else
    echo_msgbox "$msg_error_npm_list"
    return 1
  fi

  echo_process_stop "$msg_process_stop"

  # Afficher un message de confirmation
  echo_msgbox "$(printf "$msg_file_output" "$output_file")" "$G_TITLE"
  return 0
  
}

# Fonction pour lister les packages installés avec npm (sans leurs dépendances)
# Function to list installed packages with npm (without their dependencies)
function menu_7_inventory_list_packages_npm() {

  # Définition des messages en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_no="Non"
    local msg_button_yes="Oui"
    local msg_error_npm_list="Erreur : Impossible de lister les packages npm installés."
    local msg_error_permissions="Erreur : Vous devez exécuter ce script avec des privilèges administratifs (sudo)."
    local msg_file_exist="Attention : Le fichier %s existe déjà et sera remplacé."
    local msg_file_output="La liste des packages npm installés a été enregistrée dans %s."
    local msg_npm_not_installed="npm n'est pas installé sur ce système. Cette fonction nécessite npm."
		local msg_process_start="Lister les packages installés avec npm (sans leurs dépendances)"
    local msg_process_stop="Traitement des packages installés avec npm (sans leurs dépendances) terminé"
		local msg_warning_title="Avertissement"
  else
    local msg_button_no="No"
    local msg_button_yes="Yes"
    local msg_error_npm_list="Error: Unable to list installed npm packages."
    local msg_error_permissions="Error: You must run this script with administrative privileges (sudo)."
    local msg_file_exist="Warning: The file %s already exists and will be overwritten."
    local msg_file_output="The list of installed npm packages has been saved in %s."
    local msg_npm_not_installed="npm is not installed on this system. This function requires npm."
		local msg_process_start="Listing installed packages with npm (without their dependencies)"
    local msg_process_stop="Processing of installed npm packages completed"
		local msg_warning_title="Warning"
  fi

  # Vérifier si npm est installé
  if ! command -v npm &> /dev/null; then
    echo_msgbox "$msg_npm_not_installed" "Erreur"
    return 1
  fi

  # Fichier de sortie
  local output_file="$G_USER_DIR/nrx800_list_packages_npm.txt"
  
  # Lister les packages npm installés globalement et afficher sur le terminal
  [ "$G_CLEAR" == "True" ] && clear 
  echo_process_start "$msg_process_start"
  
  # Récupérer la liste des packages
  local packages=$(npm list -g --depth=0 | awk '/^├──/ {print $2}')
  
  # Vérifier si la commande a réussi
  if [ $? -eq 0 ]; then
    
    # Convertir la liste des packages 
    while IFS= read -r package; do
      echo_step_start ""$package""
      
      # Écrire le package dans le fichier de sortie
      echo "$package" >> "$output_file"
      
      echo_step_stop ""$package""
    done <<< "$packages"

  else
    echo "$msg_error_npm_list" >&2
    return 1
  fi
  
	echo_process_stop "$msg_process_stop"
  sleep 2
  [ "$G_CLEAR" == "True" ] && clear

  # Afficher un message de confirmation
  echo_msgbox "$(printf "$msg_file_output" "$output_file")" "Succès"
  return 0
  
}

# Function to list installed npm packages with their dependencies
# Fonction pour lister les packages npm installés avec leurs dépendances
function menu_7_inventory_list_packages_npm_dependencies() {

  # Définition des messages en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_no="Non"
    local msg_button_yes="Oui"
    local msg_error_npm_list="Erreur : Impossible de lister les packages npm installés."
    local msg_error_title="Erreur"
    local msg_file_exist="Attention : Le fichier %s existe déjà et sera remplacé."
    local msg_file_output="La liste des packages npm installés avec dépendances a été enregistrée dans %s."
    local msg_npm_not_installed="npm n'est pas installé sur ce système. Cette fonction nécessite npm."
    local msg_process_start="Lister les packages installés avec npm (avec leurs dépendances)"
    local msg_process_stop="Traitement des packages installés avec npm (avec leurs dépendances) terminé"
    local msg_success_title="Succès"
    local msg_warning_title="Avertissement"
  else
    local msg_button_no="No"
    local msg_button_yes="Yes"
    local msg_error_npm_list="Error: Unable to list installed npm packages."
    local msg_error_title="Error"
    local msg_file_exist="Warning: The file %s already exists and will be overwritten."
    local msg_file_output="The list of installed npm packages with dependencies has been saved in %s."
    local msg_npm_not_installed="npm is not installed on this system. This function requires npm."
    local msg_process_start="Listing installed packages with npm (with their dependencies)"
    local msg_process_stop="Processing of installed npm packages with dependencies completed"
    local msg_success_title="Success"
    local msg_warning_title="Warning"
  fi

  # Vérifier si npm est installé
  if ! command -v npm &> /dev/null; then
    echo_msgbox "$msg_npm_not_installed" "$msg_error_title"
    return 1
  fi

  # Fichier de sortie
  local output_file="$G_USER_DIR/nrx800_list_packages_npm_with_dependencies.txt"

  # Vérifier si le fichier de sortie existe déjà
  if [ -f "$output_file" ]; then
    if whiptail --yesno "$(printf "$msg_file_exist" "$output_file")" 15 70 --fb --title "$msg_warning_title" --yes-button "$msg_button_yes" --no-button "$msg_button_no"; then
      # Si l'utilisateur confirme, écraser le fichier
      > "$output_file"
    else
      # Si l'utilisateur annule, quitter la fonction
      return 0
    fi
  else
    # Si le fichier n'existe pas, le créer
    > "$output_file"
  fi

  # Lister les packages npm installés globalement avec leurs dépendances
  [ "$G_CLEAR" == "True" ] && clear
  echo_process_start "$msg_process_start"
  if ! npm list -g --depth=1 | tee "$output_file"; then
    echo_msgbox "$msg_error_npm_list" "$msg_error_title"
    return 1
  fi
  echo_process_stop "$msg_process_stop"
  sleep 2
  [ "$G_CLEAR" == "True" ] && clear

  # Afficher un message de confirmation
  echo_msgbox "$(printf "$msg_file_output" "$output_file")" "$msg_success_title"
  return 0
	
}


# Fonction pour lister les services installés
# Function to list installed services
function menu_7_inventory_list_services() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_error_exec_cmd="Erreur lors de l'exécution de la commande"
    local msg_error_permissions="Erreur : Vous devez exécuter ce script avec des privilèges administratifs (sudo)."
    local msg_output_file="La liste des services installés a été enregistrée dans %s."
    local msg_services_active="Services actifs :"
    local msg_services_disabled="Services désactivés :"
    local msg_services_failed="Services en échec :"
    local msg_services_inactive="Services inactifs :"
    local msg_services_masked="Services masqués :"
    local msg_services_systemd="Services systemd :"
  else
    local msg_error_exec_cmd="Error while executing the command"
    local msg_error_permissions="Error: You must run this script with administrative privileges (sudo)."
    local msg_output_file="The list of installed services has been saved in %s."
    local msg_services_active="Active services:"
    local msg_services_disabled="Disabled services:"
    local msg_services_failed="Failed services:"
    local msg_services_inactive="Inactive services:"
    local msg_services_masked="Masked services:"
    local msg_services_systemd="Systemd services:"
  fi

  # Vérifier les permissions
  if [ "$(id -u)" -ne 0 ]; then
    echo "$msg_error_permissions" >&2
    return 1
  fi

  # Fichier de sortie
  local output_file="$G_USER_DIR/nrx800_list_services.txt"

  # Vider le fichier de sortie
  > "$output_file"

  # Lister les services systemd
  echo "=== $msg_services_systemd ===" >> "$output_file"
  if ! systemctl list-units --type=service --all >> "$output_file" 2>&1; then
    echo "$msg_error_exec_cmd : systemctl list-units --type=service --all" >> "$output_file"
  fi
  echo -e "\n" >> "$output_file"

  # Lister les services actifs
  echo "=== $msg_services_active ===" >> "$output_file"
  if ! systemctl list-units --type=service --state=active >> "$output_file" 2>&1; then
    echo "$msg_error_exec_cmd : systemctl list-units --type=service --state=active" >> "$output_file"
  fi
  echo -e "\n" >> "$output_file"

  # Lister les services inactifs
  echo "=== $msg_services_inactive ===" >> "$output_file"
  if ! systemctl list-units --type=service --state=inactive >> "$output_file" 2>&1; then
    echo "$msg_error_exec_cmd : systemctl list-units --type=service --state=inactive" >> "$output_file"
  fi
  echo -e "\n" >> "$output_file"

  # Lister les services en échec
  echo "=== $msg_services_failed ===" >> "$output_file"
  if ! systemctl list-units --type=service --state=failed >> "$output_file" 2>&1; then
    echo "$msg_error_exec_cmd : systemctl list-units --type=service --state=failed" >> "$output_file"
  fi
  echo -e "\n" >> "$output_file"

  # Lister les services masqués
  echo "=== $msg_services_masked ===" >> "$output_file"
  if ! systemctl list-units --type=service --state=masked >> "$output_file" 2>&1; then
    echo "$msg_error_exec_cmd : systemctl list-units --type=service --state=masked" >> "$output_file"
  fi
  echo -e "\n" >> "$output_file"

  # Lister les services désactivés
  echo "=== $msg_services_disabled ===" >> "$output_file"
  if ! systemctl list-units --type=service --state=disabled >> "$output_file" 2>&1; then
    echo "$msg_error_exec_cmd : systemctl list-units --type=service --state=disabled" >> "$output_file"
  fi
  echo -e "\n" >> "$output_file"

  # Afficher un message de confirmation
  printf "$msg_output_file\n" "$output_file"

  return 0
  
}


# Fonction pour lancer un shell dans un container
# Function to launch a shell in a container
function menu_6_misc_launch_shell_in_container() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_ok="Lancer un shell"
    local msg_error_launch_container="Erreur : Impossible de lancer un shell dans le conteneur"
    local msg_invalid_selection="Sélection invalide. Veuillez réessayer."
    local msg_message="\nSélectionnez le container dans lequel lancer un shell :\nTapez 'exit' pour sortir du shell"
    local msg_no_containers="Aucun conteneur démarré."
    local msg_title="Container(s) démarré(s)"
  else
    local msg_button_cancel="Back"
    local msg_button_ok="Launch shell"
    local msg_error_launch_container="Error: Unable to start a shell in the container"
    local msg_invalid_selection="Invalid selection. Please try again."
    local msg_message="\nSelect the container to launch a shell in : \nType 'exit' to exit the shell."
    local msg_no_containers="No containers running."
    local msg_title="Running Container(s)"
  fi

  # Initialise un tableau pour stocker les conteneurs démarrés
  local started_containers=()

  # Parcours le tableau G_DOCKER_NAME pour vérifier les conteneurs démarrés
  for container_display_name in "${!G_DOCKER_NAME[@]}"; do
    local container_id=${G_DOCKER_NAME[$container_display_name]}
    
    # Vérifie si le conteneur est démarré
    if docker ps --filter "name=$container_id" --format '{{.Names}}' | grep -q "^$container_id$"; then
      started_containers+=("$container_display_name" "$container_display_name  " OFF)
    fi
  done

  # Si aucun conteneur n'est démarré, affiche un message et quitte
  if [ ${#started_containers[@]} -eq 0 ]; then
    echo_msgbox "$msg_no_containers" "$msg_title"
    return 0
  fi

  # Calcule la hauteur dynamique en fonction du nombre de conteneurs démarrés
  local num_containers=${#started_containers[@]}
  local menu_height=$((num_containers + 12))  # Hauteur de base + nombre de conteneurs

  # Limite la hauteur maximale pour éviter des problèmes d'affichage
  if [ $menu_height -gt 20 ]; then
    menu_height=20
  fi

  # Affiche un radiolist pour sélectionner le container
  local choice_menu=$(whiptail --radiolist "$msg_message" $menu_height 70 $((num_containers)) "${started_containers[@]}" --fb --title "$msg_title" --notags --ok-button "$msg_button_ok" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)
  local exit_status=$?

  # Si l'utilisateur a annulé, quitte la fonction
  if [ "$exit_status" -ne 0 ]; then
    return
  fi

  # Vérifie que $choice_menu est une clé valide dans G_DOCKER_NAME
  if [[ -z "$choice_menu" || -z "${G_DOCKER_NAME[$choice_menu]}" ]]; then
    echo_msgbox "$msg_invalid_selection" "$msg_title"
    return
  fi

  # Récupère l'ID du conteneur à partir de G_DOCKER_NAME
  local container_id=${G_DOCKER_NAME[$choice_menu]}

  # Configure le prompt personnalisé dans le conteneur
  local container_name=$(echo "$container_id" | tr -d '"')  # Supprime les guillemets si présents
  local custom_prompt="export PS1='root@$container_name:\w\\$ '"

  # Appliquer directement PS1 au lancement du shell
  debug "docker exec -it $container_id /bin/bash"
  [ "$G_CLEAR" == "True" ] && clear

  if ! docker exec -it "$container_id" bash --rcfile <(echo "$custom_prompt && bash --rcfile ~/.bashrc"); then
    echo_msgbox "$msg_error_launch_container $container_id" "$msg_title"
  fi
  
}

# Fonction pour le système de fichiers Overlay (en lecture seule)
# Function for Overlay file system (read-only)
function menu_6_misc_overlay_filesystem() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_confirm_disable="Êtes-vous sûr de vouloir désactiver l'overlay ?"
    local msg_confirm_enable="Êtes-vous sûr de vouloir activer l'overlay ?"
    local msg_disable_overlay="Désactivation de l'overlay..."
    local msg_enable_overlay="Configuration de l'overlay..."
    local msg_exec_root="Veuillez exécuter cette fonction en tant que root."
    local msg_install_packages="Installation des paquets nécessaires..."
    local msg_message="Que voulez-vous faire ?"
    local msg_options=("Activer" "Activer l'overlay"
                        "Désactiver" "Désactiver l'overlay"
                        "Retour" "Retour")
    local msg_reboot="Redémarrage du système pour appliquer les changements..."
    local msg_recurse_option_prompt="Entrez 'recurse=0' pour désactiver la récursivité, sinon appuyez sur Entrée : "
    local msg_swap_size_prompt="Entrez l'espace de swap pour l'overlay (en Go, par exemple 1) : "
    local msg_title="Gestion de l'Overlay"
  else
    local msg_button_cancel="Back"
    local msg_confirm_disable="Are you sure you want to disable the overlay?"
    local msg_confirm_enable="Are you sure you want to enable the overlay?"
    local msg_disable_overlay="Disabling overlay..."
    local msg_enable_overlay="Configuring overlay..."
    local msg_exec_root="Please run this function as root."
    local msg_install_packages="Installing necessary packages..."
    local msg_message="What do you want to do ?"
    local msg_options=("Enable" "Enable overlay"
                        "Disable" "Disable overlay"
                        "Back" "Back")
    local msg_reboot="Rebooting the system to apply changes..."
    local msg_recurse_option_prompt="Enter 'recurse=0' to disable recursion, otherwise press Enter : "
    local msg_swap_size_prompt="Enter swap space for the overlay (in GB, for example 1) : "
    local msg_title="Overlay Management"
  fi

  # Vérifie si l'utilisateur est root
  if [ "$EUID" -ne 0 ]; then
    echo "$msg_exec_root"
    return 1
  fi

  # Boucle principale pour afficher le menu
  while true; do
    local choice_menu=$(whiptail --menu "$msg_message" 20 70 10 --fb --title "$msg_title" --notags "${msg_options[@]}" --cancel-button "$msg_button_cancel" 3>&1 1>&2 2>&3)

    case $choice_menu in
      "Activer"|"Enable")
        # Demande confirmation pour activer l'overlay
        if (whiptail --yesno "$msg_confirm_enable" 15 70 --fb --title "$msg_title" --yes-button "$yes_button" --no-button "$no_button"); then
          echo "$msg_install_packages"
          apt-get update
          apt-get install -y overlayroot
          echo "$msg_enable_overlay"
          # Demande la taille du swap pour l'overlay
          local swap_size
          swap_size=$(whiptail --inputbox "$msg_swap_size_prompt" 8 78 1 --fb --title "$msg_title" 3>&1 1>&2 2>&3)
          # Demande l'option de récursivité
          local recurse_option
          recurse_option=$(whiptail --inputbox "$msg_recurse_option_prompt" 8 78 --fb --title "$msg_title" 3>&1 1>&2 2>&3)
          # Configure l'overlay
          echo "OVERLAYROOT=\"tmpfs:swap=$swap_size,recurse=$recurse_option\"" | tee /etc/overlayroot.conf
          echo "$msg_reboot"
          reboot
        fi
        break
        ;;
      "Désactiver"|"Disable")
        # Demande confirmation pour désactiver l'overlay
        if (whiptail --yesno "$msg_confirm_disable" 15 70 --fb --title "$msg_title" --yes-button "$yes_button" --no-button "$no_button"); then
          echo "$msg_disable_overlay"
          rm /etc/overlayroot.conf
          echo "$msg_reboot"
          reboot
        fi
        break
        ;;
      "Retour"|"Back")
        # Retour au menu précédent
        break
        ;;
    esac
  done

}

# Fonction pour redémarrer le nrx800
# Function to reboot the NRX800
function menu_6_misc_reboot() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_no="Non"
    local msg_button_yes="Oui"
    local msg_reboot_cancel="Redémarrage annulé."
    local msg_reboot_prompt="Êtes-vous sûr de vouloir redémarrer le NRX800 ?"
    local msg_reboot_success="Le NRX800 va redémarrer..."
    local msg_reboot_title="Redémarrage du NRX800"
  else
    local msg_button_no="No"
    local msg_button_yes="Yes"
    local msg_reboot_cancel="Reboot canceled."
    local msg_reboot_prompt="Are you sure you want to reboot the NRX800?"
    local msg_reboot_success="The NRX800 is restarting..."
    local msg_reboot_title="Reboot NRX800"
  fi

  # Demande à l'utilisateur s'il souhaite redémarrer maintenant
  if whiptail --yesno "\n$msg_reboot_prompt" 12 70 --fb --title "$G_TITLE" --yes-button "$msg_button_yes" --no-button "$msg_button_no"; then
    # Si l'utilisateur confirme, redémarre le système
    echo_msgbox "\n$msg_reboot_success" "$msg_reboot_title"

    # Lance le reboot avec compte à rebours
    countdown_before_reboot

  # Si l'utilisateur annule, affiche un message d'annulation
  else
    echo_msgbox "\n$msg_reboot_cancel" "$msg_reboot_title"
  fi

}

# Function to update the system
# Fonction pour mettre à jour le système
function menu_6_misc_update_system() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_button_cancel="Retour"
    local msg_button_ok="Ok"
    local msg_confirm="Voulez-vous vraiment mettre à jour le système ?"
    local msg_success="La mise à jour du système est terminée."
    local msg_updating_packages="Mise à jour des paquets..."
    local msg_upgrading_packages="Mise à niveau des paquets..."
    local msg_executing_update="Exécution de apt-get update..."
    local msg_executing_upgrade="Exécution de apt-get full-upgrade -sy..."
    local msg_total_packages_update="Nombre total de paquets à mettre à jour:"
    local msg_total_packages_upgrade="Nombre total de paquets à mettre à niveau:"
  else
    local msg_button_cancel="Back"
    local msg_button_ok="Ok"
    local msg_confirm="Do you really want to update the system?"
    local msg_success="The system update is complete."
    local msg_updating_packages="Updating packages..."
    local msg_upgrading_packages="Upgrading packages..."
    local msg_executing_update="Running apt-get update..."
    local msg_executing_upgrade="Running apt-get full-upgrade -sy..."
    local msg_total_packages_update="Total packages to update:"
    local msg_total_packages_upgrade="Total packages to upgrade:"
  fi

  # Demande confirmation pour mettre à jour le système
  if (whiptail --yesno "$msg_confirm\n(apt-get update && apt-get full-upgrade)" 15 70 --fb --title "$G_TITLE" --yes-button "$msg_button_ok" --no-button "$msg_button_cancel"); then

    # Fichier temporaire pour capturer la sortie de apt-get update
    temp_file=$(mktemp)

    # Exécuter apt-get update et capturer la sortie dans un fichier temporaire
    echo "$msg_executing_update"
    sudo apt-get update 2>&1 | tee "$temp_file"

    # Récupérer le nombre total de paquets à mettre à jour
    total_packages=$(grep 'Get:' "$temp_file" | wc -l)
    echo "$msg_total_packages_update $total_packages"

    # Si aucun paquet n'est à mettre à jour, simuler une barre de progression
    if [ "$total_packages" -eq 0 ]; then
      {
        for i in {1..100}; do
          sleep 0.05
          echo "$i"
        done
      } | whiptail --gauge "$msg_updating_packages ($i/100)" 15 70 0 --fb --title "$G_TITLE"
    else
      # Exécuter apt-get update et afficher la progression
      current_package=0
      while read -r line; do
        if echo "$line" | grep -q 'Get:'; then
          current_package=$((current_package + 1))
          percent=$((current_package * 100 / total_packages))
          echo "$percent" | whiptail --gauge "$msg_updating_packages ($current_package/$total_packages)" 15 70 0 --fb --title "$G_TITLE"
        fi
      done < "$temp_file"
    fi

    # Réinitialiser le compteur pour le full-upgrade
    current_package=0

    # Exécuter apt-get full-upgrade -sy et capturer la sortie dans un fichier temporaire
    echo "$msg_executing_upgrade"
    sudo apt-get full-upgrade -sy 2>&1 | tee "$temp_file"

    # Récupérer le nombre total de paquets à mettre à niveau
    total_packages=$(grep 'Processing' "$temp_file" | wc -l)
    echo "$msg_total_packages_upgrade $total_packages"

    # Si aucun paquet n'est à mettre à niveau, simuler une barre de progression
    if [ "$total_packages" -eq 0 ]; then
      {
        for i in {1..100}; do
          sleep 0.05
          echo "$i"
        done
      } | whiptail --gauge "$msg_upgrading_packages ($i/100)" 15 70 0 --fb --title "$G_TITLE"
    else
      # Exécuter apt-get full-upgrade et afficher le gauge
      sudo apt-get full-upgrade -y 2>&1 | while read -r line; do
        if echo "$line" | grep -q 'Processing'; then
          current_package=$((current_package + 1))
          percent=$((current_package * 100 / total_packages))
          echo "$percent" | whiptail --gauge "$msg_upgrading_packages ($current_package/$total_packages)" 15 70 0 --fb --title "$G_TITLE"
        fi
      done
    fi

    # Afficher un message de fin
    echo_msgbox "$msg_success" "$G_TITLE"

  fi

}



##########   FONCTION LIEES AUX MENUS - MENU RELATED FUNCTIONS

# Fonction pour le choix de la langue puis affichage d'un message de bienvenue et appel au menu principal 
# Function for welcome menu and language selection and call to main menu
function menu_8_language() {

  local options=("1" "  Français "
                 "2" "  English  ")

  while true; do

    # Afficher la boîte de dialogue
    local choice_menu
    choice_menu=$(whiptail --menu "\nChoisissez votre langue | Choose your language : " 13 70 2 "${options[@]}" --fb --title "$G_TITLE" --ok-button "Choisir | Choose" --cancel-button " Quitter | Quit " 3>&1 1>&2 2>&3)
    # Récupérer le statut de sortie
    local exit_status=$?
    
    # clic "Quitter"
    if [ $exit_status -eq 1 ]; then
      if (whiptail --yesno "    Voulez-vous vraiment quitter le script d'installation ?\n      Do you really want to quit the installation script ?" 8 60 0 --fb --title "$G_TITLE" --yes-button "Oui/Yes" --no-button "Non/No"); then
        exit
      fi
    # clic "Choisir"
    elif [ $exit_status -eq 0 ]; then
      case $choice_menu in
        1) G_LANG="fr"
           local msg_welcome=$G_MESSAGE_FR
           break ;;
        2) G_LANG="en"
           local msg_welcome=$G_MESSAGE_EN
           break ;;
      esac
    fi
  done
  
  # Affiche le message de bienvenue
  echo_msgbox "$msg_welcome"

  # Teste si le fichier G_FILE_CFG existe, sinon c'est le premier lancement alors propose check et backup
  if [ ! -f "$G_FILE_CFG" ]; then
    menu_7_inventory
  fi

  # Ecrit les paramètres globaux dans le fichier de config si le fichier n'existe pas et charge si il existe
  config_params_load_write

  # Affiche le menu principal
  menu_0_main_menu

}



##########   FONCTIONS RESEAUX - NETWORK FUNCTIONS   -*******  a internationaliser

# Fonction pour trouver la carte réseau active
# Function to find the active network card
function network_get_active_interface() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_debug="Interface réseau active trouvée :"
    local msg_error="Erreur lors de la récupération de l'interface réseau active."
  else
    local msg_debug="Active network interface found:"
    local msg_error="Error retrieving the active network interface."
  fi

  # Récupère la première route par défaut et extrait le nom de la carte réseau
  local interface
  interface=$(ip route | grep default | awk '{print $5}' | head -n 1)

  # Vérifie si l'interface réseau a été trouvée
  if [ -z "$interface" ]; then
    debug "$msg_error"
    return 1
  fi

  # Affiche et enregistre l'interface réseau active
  echo "$interface"
  
}

# Fonction pour récupérer le DNS actuel
# Function to retrieve current DNS
function network_get_current_dns() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_debug="DNS actuel trouvé :"
    local msg_error="Erreur lors de la récupération du DNS actuel."
  else
    local msg_debug="Current DNS found:"
    local msg_error="Error retrieving the current DNS."
  fi

  # Récupère le premier serveur DNS dans /etc/resolv.conf
  local dns
  dns=$(grep nameserver /etc/resolv.conf | head -n 1 | awk '{print $2}')

  # Vérifie si le DNS a été trouvé
  if [ -z "$dns" ]; then
    debug "$msg_error"
    return 1
  fi

  # Affiche et enregistre le DNS actuel
  echo "$dns"
  
}

# Fonction pour récupérer la passerelle actuelle
# Function to retrieve the current gateway
function network_get_current_gateway() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_debug="Passerelle par défaut trouvée :"
    local msg_error="Erreur lors de la récupération de la passerelle par défaut."
  else
    local msg_debug="Default gateway found:"
    local msg_error="Error retrieving the default gateway."
  fi

  # Récupère la passerelle par défaut à partir de la table de routage
  local gateway
  gateway=$(ip route | grep default | awk '{print $3}' | head -n 1)

  # Vérifie si la passerelle a été trouvée
  if [ -z "$gateway" ]; then
    debug "$msg_error"
    return 1
  fi

  # Affiche et enregistre la passerelle actuelle
  echo "$gateway"
  
}

# Fonction pour récupérer l'IP actuelle  
# Function to retrieve current IP  
function network_get_current_ip() {

  # Définit les textes en fonction de la langue sélectionnée  
  if [ "$G_LANG" = "fr" ]; then  
    local msg_debug="Adresse IP actuelle trouvée :"
    local msg_error_interface="Erreur lors de la récupération de l'interface réseau active."
    local msg_error_ip="Erreur lors de la récupération de l'adresse IP."
  else  
    local msg_debug="Current IP address found:"
    local msg_error_interface="Error retrieving the active network interface."
    local msg_error_ip="Error retrieving the IP address."
  fi

  # Récupère l'interface réseau active  
  local interface  
  interface=$(network_get_active_interface)
  if [ $? -ne 0 ]; then  
    debug "$msg_error_interface"
    return 1  
  fi

  # Récupère l'adresse IP de l'interface réseau active  
  local ip
  ip=$(ip addr show $interface | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
  if [ -z "$ip" ]; then  
    debug "$msg_error_ip"
    return 1  
  fi

  # Affiche et enregistre l'adresse IP actuelle  
  echo "$ip"
  
}

# Fonction pour récupérer le masque de sous-réseau actuel  
# Function to retrieve the current subnet mask  
function network_get_current_netmask() {

  # Définit les textes en fonction de la langue sélectionnée  
  if [ "$G_LANG" = "fr" ]; then  
    local msg_debug="Masque de sous-réseau actuel trouvé :"
    local msg_error_conversion="Erreur lors de la conversion du préfixe en masque de sous-réseau."
    local msg_error_interface="Erreur lors de la récupération de l'interface réseau active."
    local msg_error_prefix="Erreur lors de la récupération du préfixe réseau."
  else  
    local msg_debug="Current subnet mask found:"
    local msg_error_conversion="Error converting prefix to subnet mask."
    local msg_error_interface="Error retrieving the active network interface."
    local msg_error_prefix="Error retrieving the network prefix."
  fi

  # Récupère l'interface réseau active  
  local interface  
  interface=$(network_get_active_interface)
  if [ $? -ne 0 ]; then  
    debug "$msg_error_interface"
    return 1  
  fi

  # Récupère le préfixe réseau  
  local prefix  
  prefix=$(ip addr show $interface | grep 'inet ' | awk '{print $2}' | cut -d/ -f2)
  if [ -z "$prefix" ]; then  
    debug "$msg_error_prefix"
    return 1  
  fi

  # Convertit le préfixe en masque de sous-réseau  
  local mask  
  mask=$(( 0xffffffff ^ ((1 << (32 - $prefix)) - 1) ))

  # Convertit le masque de sous-réseau en notation décimale pointée  
  local netmask  
  netmask=$(printf "%d.%d.%d.%d\n" "$(( (mask >> 24) & 0xff ))" "$(( (mask >> 16) & 0xff ))" "$(( (mask >> 8) & 0xff ))" "$(( mask & 0xff ))")
  if [ -z "$netmask" ]; then  
    debug "$msg_error_conversion"
    return 1  
  fi

  # Affiche et enregistre le masque de sous-réseau actuel  
  echo "$netmask"
  #debug "$msg_debug $netmask"
  
}

# Fonction pour obtenir le DNS de l'interface réseau  
# Function to get the DNS of the network interface  
function network_get_dns() {

  # Définit les textes en fonction de la langue sélectionnée  
  if [ "$G_LANG" = "fr" ]; then  
    local msg_debug="DNS de l'interface réseau trouvé :"
    local msg_error="Erreur lors de la récupération du DNS de l'interface réseau."
  else  
    local msg_debug="DNS of the network interface found:"
    local msg_error="Error retrieving the DNS of the network interface."
  fi

  local interface=$1

  # Récupère le DNS de l'interface réseau  
  local dns  
  dns=$(resolvectl status "$interface" | grep 'Current DNS Server' | grep -oP '(?<=: )\d+(\.\d+){3}')

  # Vérifie si le DNS a été trouvé  
  if [ -z "$dns" ]; then  
    debug "$msg_error"
    return 1  
  fi

  # Affiche et enregistre le DNS de l'interface réseau  
  echo "$dns"
  #debug "$msg_debug $dns"
  
}

# Fonction pour obtenir la passerelle d'une interface réseau passée en paramètre  
# Function to get the gateway of a network interface passed as a parameter  
function network_get_gateway() {

  # Définit les textes en fonction de la langue sélectionnée  
  if [ "$G_LANG" = "fr" ]; then  
    local msg_debug="Passerelle de l'interface réseau trouvée :"
    local msg_error="Erreur lors de la récupération de la passerelle de l'interface réseau."
  else  
    local msg_debug="Gateway of the network interface found:"
    local msg_error="Error retrieving the gateway of the network interface."
  fi

  local interface=$1

  # Récupère la passerelle de l'interface réseau  
  local gateway  
  gateway=$(ip route show dev "$interface" | grep default | grep -oP '(?<=via\s)\d+(\.\d+){3}')

  # Vérifie si la passerelle a été trouvée  
  if [ -z "$gateway" ]; then  
    debug "$msg_error"
    return 1  
  fi

  # Affiche et enregistre la passerelle de l'interface réseau  
  echo "$gateway"
  #debug "$msg_debug $gateway"
  
}

# Fonction pour récupérer la liste triée des ports ouverts  
# Function to retrieve the sorted list of opened ports 
function network_get_port_opened() {

  # Récupère les ports ouverts avec la commande ss  
  local open_ports  
  open_ports=$(ss -tuln | awk '/LISTEN/ {print $5}' | awk -F':' '{print $NF}' | sort -n | uniq)

  # Convertit la liste des ports en une chaîne séparée par des virgules  
  local ports_csv  
  ports_csv=$(echo "$open_ports" | paste -sd ',' -)

  # Retourne la liste des ports ouverts  
  echo "$ports_csv"
  
}

# Fonction pour valider une adresse IP  
# Function to validate an IP address  
function network_validate_ip() {

  # Définit les textes en fonction de la langue sélectionnée
  if [ "$G_LANG" = "fr" ]; then
    local msg_debug="Adresse IP validée : $ip"
    local msg_error="L'adresse IP n'est pas valide : $ip"
  else
    local msg_debug="IP address validated: $ip"
    local msg_error="The IP address is not valid: $ip"
  fi

  local ip=$1
  local stat=1  # Par défaut, l'adresse IP est considérée comme invalide

  # Vérifie si l'adresse IP correspond au format attendu
  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    ip=($ip)
    IFS=$OIFS
    # Vérifie que chaque octet est compris entre 0 et 255
    if [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]; then
      stat=0  # L'adresse IP est valide
    fi
  fi

  # Si l'adresse IP est pas valide, affiche un message de débogage
  if [ $stat -eq 0 ]; then
    echo "debug network_validate_ip : $msg_debug" 
  fi

  return $stat
  
}

# Fonction pour valider une adresse IP avec masque CIDR  
# Function to validate an IP address with CIDR mask  
function network_validate_ip_mask() {

  local ip_mask=$1  
  local cidr_stat=1  
  local ip_stat=1  
  local stat=1

  # Vérifie si l'entrée correspond au format "IP/Masque CIDR"  
  if [[ $ip_mask =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then  
    # Sépare l'adresse IP et le masque CIDR  
    IFS='/' read -r ip cidr <<< "$ip_mask"

    # Valide le masque CIDR (doit être entre 0 et 32)  
    if [[ $cidr =~ ^[0-9]{1,2}$ ]] && [ $cidr -ge 0 ] && [ $cidr -le 32 ]; then  
      cidr_stat=0  
    else  
      cidr_stat=1  
    fi

    # Valide l'adresse IP en tant qu'adresse réseau  
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then  
      OIFS=$IFS  
      IFS='.'  
      ip=($ip)  
      IFS=$OIFS  
      [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]  
      ip_stat=$?  
    else  
      ip_stat=1  
    fi

    # Si l'adresse IP et le masque CIDR sont valides, le statut est 0  
    if [ $ip_stat -eq 0 ] && [ $cidr_stat -eq 0 ]; then  
      stat=0  
    fi  
  fi

  return $stat
  
}

# Fonction pour valider un numéro de port  
# Function to validate a port number  
function network_validate_port() {
  
  # Définit les textes en fonction de la langue sélectionnée  
  if [ "$G_LANG" = "fr" ]; then  
    local msg_debug="Numéro de port validé : $port"
    local msg_error="Le numéro de port n'est pas valide : $port"
  else  
    local msg_debug="Port number validated: $port"
    local msg_error="The port number is not valid: $port"
  fi

  local port=$1

  # Vérifie si le numéro de port est valide  
  if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then  
    # debug "$msg_debug"  
    return 0  
  else  
    debug "debug network_validate_port : $msg_error"
    return 1  
  fi
  
}


######################################################################################
# LE PROGRAMME COMMENCE ICI POUR QUE LES FONCTIONS SOIENT DECLAREES AVANT LEUR APPEL #
# THE PROGRAM STARTS HERE SO THAT FUNCTIONS ARE DECLARED BEFORE THEY ARE CALLED      # 
######################################################################################
function start_main_menu() {
      
  # Ajoute un verrou pour eviter les executions parallèles
  if [ -f "/tmp/nrx-config800.lock" ]; then
    echo "Le script est déjà en cours d'exécution."
    exit 1
  fi
  touch "/tmp/nrx800-config.lock"
  trap 'rm -f /tmp/nrx800-config.lock' EXIT

  # Lance un timeout en arrière-plan pour arrêter automatiquement le script au bout de 30mn
  TIMEOUT=1800  # 30 minutes (corrigé de 10 à 1800 secondes)
  (
      sleep $TIMEOUT
      # Restaurer les sorties standards avant d'afficher le message
      exec 1>&3 2>&4
      clear
      echo "Temps terminé, fin du script...Timeout reached, killing script..."
      clear
      kill -TERM $$
      clear
  ) &
  TIMEOUT_PID=$!

  # Désactiver le timeout quand le script se termine normalement
  cleanup() {
    clear
    exec 1>&3 2>&4
    kill -9 $TIMEOUT_PID 2>/dev/null
  }
  trap cleanup EXIT

  # Efface l'écran
  [ "$G_CLEAR" == "True" ] && clear 
  
  # Active le tracage dans un fichier log
  echo_logging
  
  # supprime les anciens logs en gardant que les 10 derniers
  echo_logs_rotate
  sleep 1
  
  # Verifie si l'OS est Debian
  check_operating_system
  
  # Verifie le country code pour détérminer la langue 
  check_country_code
  
  # Verifie le timezone
  check_timezone

  # Vérifie si le script est exécuté en tant que root
  if [ "$EUID" -ne 0 ]; then
    if [ "$G_LANG" = "fr" ]; then
      local msg_root_error="Veuillez exécuter ce script en tant que root."
    else
      local msg_root_error="Please run this script as root."
    fi
    echo "$msg_root_error"
    exit 1
  fi

  # Verifie si whiptail est installé et l'installe si il ne l'est pas  
  check_whiptail
    
  # Initialisation des tableaux de paramètres
  activate_globals_variables

  # Si pas de paramètres, affiche la barre de progression 
  if [ -z "$1" ]; then 
      # Définit les messages de chargement du script en français/anglais
      local msg_action="Chargement en cours...    /    Loading in progress..."
      local msg_OS="OS      : $G_OS"
      local msg_ip_host="IP      : $G_IP_HOST"
      local msg_langage="Langage : $G_LANG"
      local msg_timezone="Fuseau horaire / timezone : $G_TIMEZONE"
      local msg_directory="Répertoire  / Directory   : $G_USER_DIR"
      local msg_group="Groupe      / Group       : $G_USER_GROUP"
      local msg_name="Utilisateur / User        : $G_USERNAME"
      local msg_permission="Permission  / Permission  : $G_USER_GROUP_ID"
      
      # Affiche une jauge de progression sur 5s
      {
        for ((i = 0; i <= 100; i+=1)); do
          sleep 0.025  # ajusté pour une durée totale d'environ 3s (100*0.05)
          echo $i
        done
      } | whiptail --gauge "\n$msg_action \n \n$msg_OS \n$msg_ip_host \n$msg_langage \n$msg_timezone \n \n$msg_name \n$msg_directory \n$msg_permission \n$msg_group" 20 60 100 --fb --title "$G_TITLE"
  fi

  # Demande la langue, affiche un message de bienvenue et lance le programme principal
  menu_8_language

}

start_main_menu

exit

