# -*- coding: utf-8 -*-
import subprocess
import json
import sys

def update():
    """Scanne l'environnement et met à jour env_knowledge.json"""
    try:
        result = subprocess.run([sys.executable, "-m", "pip", "list", "--format=json"], capture_output=True, text=True)
        packages = json.loads(result.stdout)
        
        KNOWN_LIBS = {
            "pandas": "Traitement de données", "numpy": "Calculs mathématiques",
            "requests": "Requêtes HTTP", "beautifulsoup4": "Parsing HTML/XML",
            "ddgs": "Recherche web DuckDuckGo", "reportlab": "Génération PDF",
            "openpyxl": "Excel", "python-docx": "Word", "matplotlib": "Graphiques"
        }
        
        registry = {}
        for pkg in packages:
            name = pkg["name"].lower()
            version = pkg["version"]
            desc = KNOWN_LIBS.get(name, "Librairie disponible")
            registry[name] = {"version": version, "description": desc}
            
        with open("env_knowledge.json", "w", encoding="utf-8") as f:
            json.dump(registry, f, indent=2, ensure_ascii=False)
            
        return f"✅ Environnement capturé : {len(registry)} librairies enregistrées."
    except Exception as e:
        return f"❌ Erreur de capture : {str(e)}"