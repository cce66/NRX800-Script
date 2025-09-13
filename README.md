# NRX800-Script

# Téléchargement et exécution du script NRX800-config.sh

Ce guide explique comment télécharger le script `nrx800-config.sh` depuis GitHub, le rendre exécutable et l'exécuter.

## Prérequis
- Un système Linux (Ubuntu, Debian, etc.) de préférence un NRX800 puisqu'il a été écrit pour lui !
- Accès au terminal
- Outils `wget` installé (généralement préinstallé)

    
### 1. Créer le répertoire NRX 📁
Créez le répertoire `NRX-Script` dans votre dossier utilisateur (home) s'il n'existe pas déjà :

```bash
mkdir -p ~/NRX800-Script


### 2. Télécharger le script
Téléchargez le script nrx800-config.sh depuis GitHub en utilisant wget :

```bash
wget -O ~/NRX800-Script/nrx800-config.sh https://raw.githubusercontent.com/cce66/NRX800-Script/main/nrx800-config.sh

💡 Note : Il faut Utiliser l'URL raw.githubusercontent.com pour obtenir le contenu brut du script, et non la page GitHub


### 3. Rendre le script exécutable 🛠️
Donnez les permissions d'exécution au script :
```
chmod +x ~/NRX800-Script/nrx800-config.sh


### 4. Exécuter le script
Exécutez le script depuis le répertoire NRX800-Script

```bash
cd ~/NRX800-Script
./nrx800-config.sh
sudo bash ~/NRX800-Script/nrx800-config.sh
