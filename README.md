# Atelier : API-Driven Infrastructure

[![AWS LocalStack](https://img.shields.io/badge/AWS-LocalStack-orange?logo=amazon-aws&logoColor=white)](https://localstack.cloud/)
[![Python](https://img.shields.io/badge/Python-3.9-blue?logo=python&logoColor=white)](https://www.python.org/)
[![Environment](https://img.shields.io/badge/Codespaces-Cloud%20Native-success?logo=github)](https://github.com/features/codespaces)
[![Constraint](https://img.shields.io/badge/No-Localhost%20Dependency-red)](#)

## Description du Projet

Ce projet implémente une architecture **"API-Driven Infrastructure"**. L'objectif est de piloter des ressources d'infrastructure (ici, des instances EC2) non pas via une console d'administration, mais via des appels API REST automatisés.

Le projet simule un environnement AWS complet grâce à **LocalStack** et orchestre les services suivants :
* **API Gateway** : Point d'entrée public pour recevoir les commandes.
* **AWS Lambda** : Logique métier (Serverless) exécutée en Python.
* **EC2** : La ressource d'infrastructure cible.



---

## Architecture & Fonctionnement Technique

Ce projet respecte strictement la contrainte **"No Localhost Dependency"**. L'architecture est conçue pour être agnostique de la machine hôte.

### Flux de données (Data Flow)
1.  **Client (Internet)** : Une requête HTTP `POST` est envoyée sur l'URL Publique sécurisée (générée dynamiquement par GitHub Codespaces).
2.  **API Gateway** : Reçoit la requête et la transmet à la fonction Lambda.
3.  **Lambda (Backend)** : S'exécute dans un conteneur isolé.
    * *Mécanique interne :* La Lambda ne communique **pas** via `localhost`. Elle utilise la résolution DNS interne de Docker (`LOCALSTACK_HOSTNAME`) pour contacter le service EC2 via le réseau bridge privé.
4.  **EC2 (Infrastructure)** : L'instance reçoit l'ordre et change d'état (`running` <-> `stopped`).

---

## Guide d'Installation et Utilisation

L'ensemble du cycle de vie du projet est automatisé via un **Makefile** pour garantir l'isolation et la reproductibilité.

### 1. Installation (Environnement Isolé)
Cette commande crée un environnement virtuel Python (`.venv`) et y installe les outils CLI nécessaires (`awscli`, `awslocal`, `boto3`).
> **Note :** Aucune dépendance n'est installée sur le système global.

```bash
make install
```

### 2. Déploiement de l'Infrastructure
Le script de déploiement provisionne l'EC2, déploie la Lambda, configure l'API Gateway et détecte automatiquement l'URL publique de l'environnement.

```bash
make deploy
```

### 3. Utilisation (Test API)
À la fin du déploiement, le terminal vous fournit une commande curl prête à l'emploi avec votre URL Publique.

Exemple de commande :

```bash
curl -X POST -H 'Content-Type: application/json' \
     -d '{"action": "stop", "instance_id": "i-xxxxx"}' \
     https://<CODESPACE-URL>.app.github.dev/restapis/<API-ID>/dev/_user_request_/manage
```

### 4. Nettoyage
Pour supprimer l'environnement virtuel et les artefacts temporaires :

```bash
make clean
```

---

## Structure du Projet

| Fichier | Description |
| :--- | :--- |
| **`Makefile`** | Chef d'orchestre. Gère l'installation, le déploiement et le nettoyage. |
| **`deploy.sh`** | Script Bash intelligent. Provisionne l'infrastructure via AWS CLI et génère les URLs dynamiques. |
| **`lambda_function.py`** | Code logique de la Lambda. Utilise `boto3` et la découverte réseau dynamique. |
| **`requirements.txt`** | Liste des dépendances Python installées dans l'environnement virtuel. |