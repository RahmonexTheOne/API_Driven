.PHONY: install deploy clean

# Crée un environnement virtuel et installe les dépendances DEDANS (pas sur le système)
install:
	python3 -m venv .venv
	.venv/bin/pip install -r requirements.txt
	chmod +x deploy.sh
	sudo apt-get install zip -y

# Lance le déploiement en utilisant l'environnement virtuel
deploy:
	./deploy.sh

# Nettoie tout (supprime l'env virtuel et les zips)
clean:
	rm -rf .venv function.zip