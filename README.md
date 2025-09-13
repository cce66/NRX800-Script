# NRX800-Script

## Téléchargement et exécution du script NRX800-config.sh

Ce guide explique comment télécharger le script nrx800-config.sh depuis GitHub, le rendre exécutable et l'exécuter.
Prérequis

    Un système Linux (Ubuntu, Debian, etc.) - de préférence un NRX800 puisqu'il a été écrit spécifiquement pour lui !
    Accès au terminal
    Outil wget installé (généralement préinstallé sur la plupart des distributions)



### 1. Créer le répertoire NRX 📁

Créez le répertoire NRX800-Script dans votre dossier utilisateur (home) s'il n'existe pas déjà :
```bash
mkdir -p ~/NRX800-Script
```


### 2. Télécharger le script

Téléchargez le script nrx800-config.sh depuis GitHub en utilisant wget :
```bash
wget -O ~/NRX800-Script/nrx800-config.sh https://raw.githubusercontent.com/cce66/NRX800-Script/main/nrx800-config.sh
```

💡 Note : Il est important d'utiliser l'URL raw.githubusercontent.com pour obtenir le contenu brut du script, et non la page GitHub standard.


### 3. Rendre le script exécutable 🛠️

Donnez les permissions d'exécution au script :
```bash
chmod +x ~/NRX800-Script/nrx800-config.sh
```


### 4. Exécuter le script

Exécutez le script depuis le répertoire NRX800-Script :
```bash
cd ~/NRX800-Script
```

Le script nécessite des privilèges administrateur, utilisez :
```bash
sudo bash ~/NRX800-Script/nrx800-config.sh
```



📌
📦 Installer wget (si absent)

Si wget n'est pas installé sur votre système, vous pouvez l'installer avec :

```bash
sudo apt update && sudo apt install wget -y
```

Notes importantes

    🔒 Sécurité : Vérifiez toujours le contenu des scripts téléchargés depuis Internet avant de les exécuter.

    📁 Emplacement : Le script sera disponible à l'emplacement ~/NRX800-Script/nrx800-config.sh.

Remarque : Ce script a été spécialement développé pour le NRX800. Son fonctionnement sur d'autres appareils n'est pas garanti.
