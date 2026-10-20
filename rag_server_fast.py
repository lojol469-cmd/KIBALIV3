# -*- coding: utf-8 -*-
import os
import sys

# ============ ACTIVATION CUDA POUR PYTORCH ============
# Windows ne trouve pas les DLLs CUDA par défaut. On les ajoute au PATH.
_torch_lib = os.path.join(os.path.dirname(sys.executable), 'Lib', 'site-packages', 'torch', 'lib')
if os.path.exists(_torch_lib):
    # 1. Ajout au PATH
    os.environ['PATH'] = _torch_lib + os.pathsep + os.environ.get('PATH', '')
    # 2. Ajout explicite au DLL search path (Python 3.8+)
    try:
        os.add_dll_directory(_torch_lib)
    except Exception:
        pass
    print(f"[CUDA] DLL search path ajouté : {_torch_lib}", flush=True)
# =======================================================

# -*- coding: utf-8 -*-
import os
os.environ["CUDA_VISIBLE_DEVICES"] = ""
os.environ["OMP_NUM_THREADS"] = "2"
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

import sys
sys.path.insert(0, r"D:\CPT_Analysis_Studio_PORTABLE\copilot")

print("[RAG] Chargement de FAISS (ONNX)...", flush=True)
from tool_rag_faiss import FaissToolRetriever
from doc_rag_faiss import DocFaissRetriever
from memory_rag_faiss import MemoryFaissRetriever

print("[RAG] Chargement des outils (PyTorch)...", flush=True)
import tools_native
REGISTRY = getattr(tools_native, '_REGISTRY', {})
print(f"[RAG] {len(REGISTRY)} outils chargés.", flush=True)

import uvicorn
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="KIBALI RAG Server")

print("[RAG] Initialisation du RAG Outils...", flush=True)
TOOL_RETRIEVER = FaissToolRetriever(REGISTRY)
print("[RAG] Index FAISS Outils pret.", flush=True)

# --- LE DOC RAG SANS PYTORCH ---
print("[RAG] Initialisation du RAG Documents (FastEmbed)...", flush=True)
DOC_RETRIEVER = DocFaissRetriever()
MEMORY_RETRIEVER = MemoryFaissRetriever()
print('[RAG] Index FAISS Memoire pret (async).', flush=True)

class QueryRequest(BaseModel):
    query: str
    top_k: int = 15

class MemoryAddRequest(BaseModel):
    user: str
    assistant: str
    topic: str = ""


class MemorySearchRequest(BaseModel):
    query: str
    top_k: int = 3
    threshold: float = 0.4


class ExecRequest(BaseModel):
    tool_name: str
    args: dict


@app.get("/docs_status")
def docs_status():
    if hasattr(DOC_RETRIEVER, "ready") and DOC_RETRIEVER.ready.is_set():
        return {
            "status": "ready", 
            "chunks": len(DOC_RETRIEVER.documents),
            "message": "Les documents sont chargés et indexés."
        }
    else:
        return {
            "status": "loading", 
            "chunks": 0,
            "message": "Indexation des PDFs en cours (ou bloquée)..."
        }


@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/tools")
def list_tools():
    tools_data = []
    for name, data in REGISTRY.items():
        tools_data.append({
            "name": name, 
            "category": data.get('category', 'misc')
        })
    return {"tools": tools_data}

@app.get("/tool_schema/{tool_name}")
def get_tool_schema(tool_name: str):
    if tool_name not in REGISTRY:
        return {"error": "introuvable"}
    data = REGISTRY[tool_name]
    props, req = {}, []
    for p_name, p_info in data.get('inputs', {}).items():
        props[p_name] = {"type": p_info.get("type", "string"), "description": p_info.get("description", "")}
        if not p_info.get("nullable", True): req.append(p_name)
    return {
        "type": "function",
        "function": {"name": tool_name, "description": data.get('description', ''), "parameters": {"type": "object", "properties": props, "required": req}}
    }


@app.get("/tool_schemas")
def list_tool_schemas():
    """Retourne TOUS les outils au format OpenAI (type: function)."""
    schemas = []
    for name, data in REGISTRY.items():
        props, req = {}, []
        for p_name, p_info in data.get("inputs", {}).items():
            props[p_name] = {
                "type": p_info.get("type", "string"),
                "description": p_info.get("description", "")
            }
            if not p_info.get("nullable", True):
                req.append(p_name)
        schemas.append({
            "type": "function",
            "function": {
                "name": name,
                "description": data.get("description", "") or name,
                "parameters": {
                    "type": "object",
                    "properties": props,
                    "required": req
                }
            }
        })
    return {"tools": schemas, "count": len(schemas)}



@app.post("/search_tools")
def search_tools(req: QueryRequest):
    return {"tools": TOOL_RETRIEVER.get_top_tools(req.query, top_k=req.top_k)}

@app.post("/search_docs")
def search_docs(req: QueryRequest):
    # Recherche dans les PDFs/Lois via ONNX (sans PyTorch)
    docs = DOC_RETRIEVER.search(req.query, top_k=3)
    return {"docs": docs}

@app.post("/memory/add")
def memory_add(req: MemoryAddRequest):
    return MEMORY_RETRIEVER.add(req.user, req.assistant, req.topic or None)


@app.post("/memory/search")
def memory_search(req: MemorySearchRequest):
    results = MEMORY_RETRIEVER.search(req.query, top_k=req.top_k, threshold=req.threshold)
    return {"ok": True, "count": len(results), "results": results}


@app.post("/memory/clear")
def memory_clear():
    return MEMORY_RETRIEVER.clear()


@app.get("/memory/stats")
def memory_stats():
    return MEMORY_RETRIEVER.stats()


@app.post("/execute_tool")
def execute_tool(req: ExecRequest):
    """Execute un outil en cherchant d'abord dans le registre, puis dynamiquement dans tools_native."""
    import tools_native
    import inspect
    
    tool_name = req.tool_name
    args = req.args
    
    # 1. Chercher dans le registre local
    tool_entry = REGISTRY.get(tool_name)
    
    if not tool_entry:
        # 2. Fallback : chercher directement l'attribut dans le module tools_native
        if hasattr(tools_native, tool_name):
            print(f"[EXEC-TOOL] Fallback dynamique : {tool_name} trouvé dans tools_native", flush=True)
            func = getattr(tools_native, tool_name)
            try:
                # Si la fonction attend un seul argument dict (ex: args)
                sig = inspect.signature(func)
                params = list(sig.parameters.keys())
                if len(params) == 1 and params[0] in ('args', 'kwargs', 'params', 'input'):
                    result = func(args)
                else:
                    result = func(**args)
                return {"ok": True, "result": str(result)}
            except Exception as e:
                return {"ok": False, "error": f"Erreur d'execution : {e}"}
        else:
            print(f"[EXEC-TOOL] Outil {tool_name} vraiment introuvable.", flush=True)
            return {"ok": False, "error": f"Outil introuvable : {tool_name}"}
    
    # 3. Si trouvé dans le registre, exécuter normalement
    try:
        # Le REGISTRY contient soit une fonction directe, soit un dict avec 'fn'
        if callable(tool_entry):
            result = tool_entry(**args)
        elif isinstance(tool_entry, dict) and callable(tool_entry.get('fn')):
            result = tool_entry['fn'](**args)
        else:
            return {"ok": False, "error": "Format d'outil inconnu dans le registre"}
        
        return {"ok": True, "result": str(result)}
    except Exception as e:
        return {"ok": False, "error": str(e)}

@app.post("/execute_tool_legacy")
def execute_tool_legacy(req: ExecRequest):
    # (Ancienne route au cas ou)
    pass

@app.get("/api/tools")
async def api_get_tools():
    """Retourne la liste des outils pour que le Terminal puisse les utiliser."""
    from fastapi import HTTPException
    try:
        # On renvoie la variable globale qui contient les outils
        return tools_list
    except Exception as e:
        return {"error": str(e)}



def tool_list_python_libs(args):
    """Liste les bibliotheques Python installees."""
    import subprocess, json
    try:
        py_exe = r"D:\CPT_Analysis_Studio_PORTABLE\environment\python.exe"
        result = subprocess.run([py_exe, "-m", "pip", "list", "--format=json"], capture_output=True, text=True, check=True, timeout=15)
        packages = json.loads(result.stdout)
        keyword = args.get("filter_keyword", "")
        if keyword:
            packages = [p for p in packages if keyword.lower() in p["name"].lower()]
        if not packages:
            return f"Aucune bibliotheque trouvee pour : {keyword}"
        if len(packages) > 60 and not keyword:
            names = ", ".join([p["name"] for p in packages[:60]])
            return f"{len(packages)} packages. Echantillon : {names}..."
        return "\n".join([f"{p['name']}=={p['version']}" for p in packages])
    except Exception as e:
        return f"Erreur : {e}"



@app.post("/memory/forget")
def memory_forget_topic(req: dict):
    """Permet a l'agent d'oublier un souvenir specifique lie a un mot-cle."""
    try:
        keyword = req.get("keyword", "").lower()
        if not keyword:
            return {"ok": False, "error": "keyword requis"}
        
        # On demande au retriever d'effacer les souvenirs correspondants
        if hasattr(MEMORY_RETRIEVER, 'forget'):
            return MEMORY_RETRIEVER.forget(keyword)
        else:
            return {"ok": False, "error": "La fonction forget n'existe pas encore."}
    except Exception as e:
        return {"ok": False, "error": str(e)}


if __name__ == "__main__":
    print("[RAG] Serveur RAG sur le port 8765", flush=True)
    uvicorn.run(app, host="127.0.0.1", port=8765)