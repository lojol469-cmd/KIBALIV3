# -*- coding: utf-8 -*-
import subprocess, sys, json, os

class AppLibContext:
    def __init__(self, json_path="env_knowledge.json"):
        self.json_path = os.path.join(r"D:\CPT_Analysis_Studio_PORTABLE", json_path)
        self.update()

    def update(self):
        try:
            result = subprocess.run([sys.executable, "-m", "pip", "list", "--format=json"], capture_output=True, text=True)
            packages = json.loads(result.stdout)
            registry = {pkg["name"].lower(): {"version": pkg["version"], "description": "Librairie Python"} for pkg in packages}
            
            # Fusion avec anciennes descriptions
            if os.path.exists(self.json_path):
                try:
                    with open(self.json_path, "r", encoding="utf-8") as f:
                        old = json.load(f)
                        for k, v in old.items():
                            if k in registry and v.get("description") != "Librairie Python":
                                registry[k]["description"] = v["description"]
                except: pass

            with open(self.json_path, "w", encoding="utf-8") as f:
                json.dump(registry, f, indent=2, ensure_ascii=False)
            return len(registry)
        except Exception as e:
            return f"Erreur: {e}"

    def install(self, package_name):
        subprocess.run([sys.executable, "-m", "pip", "install", package_name], capture_output=True, text=True)
        count = self.update()
        return f"Package {package_name} installé. Registre mis à jour : {count} librairies."

    def get_summary(self):
        """Retourne un résumé LÉGER (utilisable dans le prompt)."""
        with open(self.json_path, "r", encoding="utf-8") as f:
            tools = json.load(f)
        return f"Tu as {len(tools)} librairies installées. Pour en trouver une, utilise find_tool('mot_clé')."

    def find_tool(self, keyword):
        """Cherche un outil par mot-clé (Lazy Loading)."""
        with open(self.json_path, "r", encoding="utf-8") as f:
            tools = json.load(f)
        results = {k: v for k, v in tools.items() if keyword.lower() in k.lower() or keyword.lower() in v.get("description", "").lower()}
        if not results:
            return f"Aucun outil trouvé pour '{keyword}'."
        lines = [f"- {k} (v{v['version']}) : {v['description']}" for k, v in results.items()]
        return "\n".join(lines[:10])  # Limite à 10 résultats max

    def get_tools(self):
        with open(self.json_path, "r", encoding="utf-8") as f:
            return json.load(f)

context = AppLibContext()