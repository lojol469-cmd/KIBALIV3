# -*- coding: utf-8 -*-
"""
KIBALI ENGINE CORE - 23 Boucles ULTRA
"""
import time, subprocess, os, sys, re, gc, ctypes, json, ast, py_compile, difflib
import importlib.util
import psutil
from openai import OpenAI

try:
    import pynvml
    pynvml.nvmlInit()
    HAS_GPU = True
except:
    HAS_GPU = False

client = OpenAI(base_url="http://127.0.0.1:8080/v1", api_key="sk-no-key-required")

CYAN='\033[96m'; GREEN='\033[92m'; YELLOW='\033[93m'; RED='\033[91m'
GRAY='\033[90m'; BOLD='\033[1m'; RESET='\033[0m'

RAM_THRESHOLD_PCT = 85
VRAM_THRESHOLD_PCT = 90
TEMP_THRESHOLD_C = 80
TEMP_CRITICAL_C = 90
PAUSE_DURATION = 10
PAUSE_CRITICAL = 30

# ==========================================
# BOUCLE 10 : JUPYTER SANITIZER
# ==========================================
def sanitize_jupyter(code):
    lines = code.split('\n')
    cleaned = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('!pip install '):
            pkg = stripped.replace('!pip install ', '').strip()
            cleaned.append(f'import subprocess, sys; subprocess.run([sys.executable, "-m", "pip", "install", "{pkg}"], check=False)')
        elif stripped.startswith('!python '):
            script = stripped.replace('!python ', '').strip()
            cleaned.append(f'import subprocess, sys; subprocess.run([sys.executable, "{script}"], check=False)')
        elif stripped.startswith('!') and len(stripped) > 1:
            cleaned.append(f'print("[SANITIZER] Cmd ignorée : {stripped[:50]}")')
        elif stripped.startswith('%'):
            cleaned.append(f'pass  # Magic supprimée')
        else:
            cleaned.append(line)
    return '\n'.join(cleaned)

# ==========================================
# BOUCLE 11 : SYNTAX GUARD
# ==========================================
def validate_syntax(code):
    try:
        ast.parse(code)
        return (True, None)
    except SyntaxError as e:
        return (False, f"SyntaxError ligne {e.lineno}: {e.msg}")

# ==========================================
# BOUCLE 12 : DEPENDENCY RESOLVER
# ==========================================
def extract_imports(code):
    imports = set()
    try:
        tree = ast.parse(code)
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for alias in node.names:
                    imports.add(alias.name.split('.')[0])
            elif isinstance(node, ast.ImportFrom):
                if node.module:
                    imports.add(node.module.split('.')[0])
    except:
        pass
    return imports

def check_and_install_deps(code):
    imports = extract_imports(code)
    stdlib = {'os','sys','re','json','time','datetime','subprocess','gc','ctypes','ast','math','random','collections','itertools','functools','typing','pathlib','shutil','tempfile','csv','io','urllib','http','socket','ssl','hashlib','base64','uuid','logging','warnings','traceback','inspect','importlib','py_compile','copy','pickle','sqlite3','threading','asyncio','multiprocessing','difflib'}
    pip_names = {'pandas':'pandas','numpy':'numpy','openpyxl':'openpyxl','requests':'requests','bs4':'beautifulsoup4','PIL':'Pillow','fpdf':'fpdf2','reportlab':'reportlab','sklearn':'scikit-learn','cv2':'opencv-python','yaml':'pyyaml','xlsx2csv':'xlsx2csv'}
    installed, failed = [], []
    for mod in imports:
        if mod in stdlib: continue
        if importlib.util.find_spec(mod) is None:
            pkg = pip_names.get(mod, mod)
            print(f"  {YELLOW}📦 [DEP] {mod} manquant → install {pkg}...{RESET}")
            try:
                r = subprocess.run([sys.executable, "-m", "pip", "install", pkg, "--quiet"], capture_output=True, text=True, timeout=120)
                if r.returncode == 0:
                    installed.append(pkg); print(f"  {GREEN}✅ {pkg}{RESET}")
                else:
                    failed.append(pkg); print(f"  {RED}❌ {pkg}{RESET}")
            except Exception as e:
                failed.append(pkg); print(f"  {RED}❌ {pkg}: {e}{RESET}")
    return (installed, failed)

# ==========================================
# BOUCLE 13 : PRE-COMPILE
# ==========================================
def precompile_check(code):
    try:
        compile(code, '<agent>', 'exec')
        return (True, None)
    except Exception as e:
        return (False, str(e))

# ==========================================
# BOUCLE 15 : ANTI-HALLUCINATION
# ==========================================
def introspect_file(filepath):
    try:
        if filepath.endswith('.xlsx') or filepath.endswith('.xls'):
            import openpyxl
            wb = openpyxl.load_workbook(filepath, read_only=True)
            ws = wb.active
            headers = [cell.value for cell in next(ws.iter_rows(max_row=1))]
            wb.close()
            return {'columns': [h for h in headers if h is not None], 'rows': ws.max_row}
        elif filepath.endswith('.csv'):
            import csv
            with open(filepath, 'r', encoding='utf-8') as f:
                reader = csv.reader(f)
                headers = next(reader)
            return {'columns': headers, 'rows': '?'}
        elif filepath.endswith('.json'):
            with open(filepath, 'r', encoding='utf-8') as f:
                data = json.load(f)
                if isinstance(data, list) and len(data) > 0:
                    return {'columns': list(data[0].keys()), 'rows': len(data)}
                elif isinstance(data, dict):
                    return {'columns': list(data.keys()), 'rows': 1}
    except Exception as e:
        return {'error': str(e)}
    return None

def extract_column_accesses(code):
    matches = re.findall(r'\w+\[[\'"]([^\'"]+)[\'"]\]', code)
    return set(matches)

def detect_dangerous_read(code):
    issues = []
    for match in re.finditer(r'pd\.read_(excel|csv)\s*\(([^)]*)\)', code):
        method = match.group(1)
        args = match.group(2)
        
        # read_excel : chunksize n'existe pas, on ne peut pas l'exiger
        if method == 'excel':
            # On bloque SEULEMENT si le fichier fait > 10 MB ET pas de chunksize
            # Mais on NE bloque PAS si c'est dans un try/except (fallback légitime)
            if 'try:' in code and 'except' in code:
                continue
            fp_match = re.search(r'["\']([^"\']+\.(?:xlsx|xls))["\']', code)
            if fp_match and os.path.exists(fp_match.group(1)):
                size_mb = os.path.getsize(fp_match.group(1)) / (1024*1024)
                if size_mb > 10:
                    issues.append(f"Gros Excel ({size_mb:.1f} MB) chargé sans stratégie de chunks")
        
        # read_csv : chunksize existe, on peut l'exiger
        elif method == 'csv':
            if 'chunksize' not in args and 'nrows' not in args:
                fp_match = re.search(r'["\']([^"\']+\.csv)["\']', code)
                if fp_match and os.path.exists(fp_match.group(1)):
                    size_mb = os.path.getsize(fp_match.group(1)) / (1024*1024)
                    if size_mb > 10:
                        issues.append(f"Gros CSV ({size_mb:.1f} MB) chargé sans chunksize")
    return issues

def anti_hallucination_check(code):
    report = {'block': False, 'reason': None, 'message': None, 'real_columns': {}, 'injections': []}
    
    file_matches = re.findall(r'[\'"]([^\'"]+\.(?:xlsx|xls|csv|json))[\'"]', code)
    for fp in file_matches:
        if os.path.exists(fp):
            info = introspect_file(fp)
            if info and 'columns' in info:
                report['real_columns'][fp] = info['columns']
    
    if not report['real_columns']:
        return report
    
    all_real = set()
    for cols in report['real_columns'].values():
        all_real.update(cols)
    accesses = extract_column_accesses(code)
    
    hallucinated = []
    for acc in accesses:
        if acc in all_real:
            continue
        if acc.lower() in [c.lower() for c in all_real]:
            hallucinated.append(acc)
    
    if hallucinated:
        report['block'] = True
        report['reason'] = 'SCHEMA'
        report['message'] = f"Colonnes hallucinées (casse incorrecte) : {hallucinated}. Colonnes réelles : {sorted(all_real)}"
        return report
    
    dry = detect_dangerous_read(code)
    if dry:
        report['block'] = True
        report['reason'] = 'DRY_RUN'
        report['message'] = f"Fichier chargé sans chunksize : {dry[0]}"
        return report
    
    return report

# ==========================================
# BOUCLE 16 : AUTO-CORRECTION LIGNE PAR LIGNE
# ==========================================
def autocorrect_columns(code, real_columns):
    changes = []
    unresolved = []
    pattern = r'(\w+)\[(["\'])([^"\']+)\2\]'
    
    def fix_match(match):
        prefix = match.group(1)
        quote = match.group(2)
        key = match.group(3)
        
        if key in real_columns:
            return match.group(0)
        
        close = difflib.get_close_matches(key, real_columns, n=1, cutoff=0.5)
        if close:
            correct = close[0]
            changes.append(f'{prefix}["{key}"] → {prefix}["{correct}"]')
            return f'{prefix}[{quote}{correct}{quote}]'
        
        unresolved.append(key)
        return match.group(0)
    
    new_code = re.sub(pattern, fix_match, code)
    return new_code, changes, unresolved

def check_line_by_line(code, real_columns):
    errors = []
    warnings = []
    try:
        tree = ast.parse(code)
    except SyntaxError as e:
        return ([f"SyntaxError ligne {e.lineno}: {e.msg}"], [])
    
    for node in ast.walk(tree):
        if isinstance(node, ast.Subscript):
            if isinstance(node.slice, ast.Constant) and isinstance(node.slice.value, str):
                key = node.slice.value
                if isinstance(node.value, ast.Name):
                    var = node.value.id
                    if var in ['df', 'chunk', 'data', 'row', 'record', 'line']:
                        if key not in real_columns:
                            errors.append(f"Ligne {node.lineno}: {var}['{key}'] invalide")
        
        if isinstance(node, ast.Call):
            func = node.func
            if isinstance(func, ast.Name) and func.id == 'exit' and len(node.args) == 0:
                warnings.append(f"Ligne {node.lineno}: exit() sans argument")
    
    return (errors, warnings)

def mock_execution(code, real_columns):
    warnings = []
    if 'print(df.columns)' not in code and 'df.columns' not in code:
        if 'read_excel' in code or 'read_csv' in code:
            warnings.append("Code ne vérifie pas les colonnes")
    if 'read_excel' in code and 'chunksize' not in code and 'nrows' not in code:
        warnings.append("read_excel sans chunksize")
    if re.search(r'for \w+ in df\b', code) and 'chunksize' not in code:
        warnings.append("Itération sur df directement")
    return warnings

def loop16_autofix(code, real_columns):
    report = {
        'fixed_columns': [],
        'ast_errors': [],
        'ast_warnings': [],
        'mock_warnings': [],
        'unresolved': [],
        'has_changes': False
    }
    if not real_columns:
        return (code, report)
    
    new_code, changes, unresolved = autocorrect_columns(code, real_columns)
    if changes:
        report['fixed_columns'] = changes
        report['has_changes'] = True
        code = new_code
    if unresolved:
        report['unresolved'] = unresolved
    
    ast_errors, ast_warnings = check_line_by_line(code, real_columns)
    report['ast_errors'] = ast_errors
    report['ast_warnings'] = ast_warnings
    
    mock_warnings = mock_execution(code, real_columns)
    report['mock_warnings'] = mock_warnings
    
    return (code, report)

# ==========================================
# HARDWARE
# ==========================================

# ==========================================
# BOUCLE 17 : GARDE-FOU ANTI-PIEGE PANDAS
# ==========================================
def check_pandas_traps(code):
    traps = []
    if re.search(r'pd\.read_excel\s*\([^)]*chunksize', code):
        traps.append({
            'type': 'READ_EXCEL_CHUNKSIZE',
            'message': "pd.read_excel() n'accepte PAS chunksize. Utilise read_csv apres conversion, ou openpyxl en read_only.",
            'suggested_fix': "Convertis d'abord : pd.read_excel('f.xlsx').to_csv('temp_memory/f.csv')\nPuis : for chunk in pd.read_csv('temp_memory/f.csv', chunksize=5000): ..."
        })
    return traps



# ==========================================
# BOUCLE 19 : AUTO-CREATION D'OUTILS TEMPORAIRES
# ==========================================
TEMP_TOOLS_DIR = "temp_tools"

def ensure_temp_tools_dir():
    os.makedirs(TEMP_TOOLS_DIR, exist_ok=True)
    init_file = os.path.join(TEMP_TOOLS_DIR, "__init__.py")
    if not os.path.exists(init_file):
        with open(init_file, "w", encoding="utf-8") as f:
            f.write("# Temp tools package\n")

def list_temp_tools():
    if not os.path.exists(TEMP_TOOLS_DIR):
        return []
    return [f[:-3] for f in os.listdir(TEMP_TOOLS_DIR) 
            if f.endswith('.py') and f != '__init__.py']

def extract_create_tool_blocks(llm_output):
    """Extrait les blocs <create_tool name="X">...</create_tool>"""
    tools = []
    pattern = r'<create_tool\s+name="([^"]+)">(.*?)</create_tool>'
    for match in re.finditer(pattern, llm_output, re.DOTALL):
        name = match.group(1).strip()
        body = match.group(2).strip()
        body = re.sub(r'^```python\s*', '', body)
        body = re.sub(r'^```\s*', '', body)
        body = re.sub(r'\s*```$', '', body).strip()
        tools.append({'name': name, 'code': body})
    return tools

def install_temp_tool(tool_name, tool_code):
    """Installe un outil temporaire dans temp_tools/"""
    if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', tool_name):
        return (False, "Nom d'outil invalide")
    
    try:
        ast.parse(tool_code)
    except SyntaxError as e:
        return (False, f"SyntaxError ligne {e.lineno}: {e.msg}")
    
    ensure_temp_tools_dir()
    filepath = os.path.join(TEMP_TOOLS_DIR, f"{tool_name}.py")
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(tool_code)
    
    try:
        import importlib
        sys.path.insert(0, os.path.abspath(TEMP_TOOLS_DIR))
        importlib.invalidate_caches()
        if tool_name in sys.modules:
            importlib.reload(sys.modules[tool_name])
        else:
            __import__(tool_name)
        return (True, filepath)
    except Exception as e:
        return (False, f"Import echoue: {e}")

def inject_temp_tools_path(code):
    """Injecte sys.path pour importer les outils temporaires."""
    tools = list_temp_tools()
    if not tools:
        return code
    
    if 'temp_tools' in code and 'sys.path' in code:
        return code
    
    injection = (
        f"import sys as _sys_tt, os as _os_tt\n"
        f"_sys_tt.path.insert(0, _os_tt.path.abspath('{TEMP_TOOLS_DIR}'))\n"
    )
    
    lines = code.split('\n')
    last_import = 0
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith('import ') or stripped.startswith('from '):
            last_import = i + 1
        elif stripped and not stripped.startswith('#'):
            break
    
    lines.insert(last_import, injection)
    return '\n'.join(lines)

def cleanup_temp_tools():
    """Supprime tous les outils temporaires."""
    if os.path.exists(TEMP_TOOLS_DIR):
        import shutil
        try:
            shutil.rmtree(TEMP_TOOLS_DIR)
            return True
        except Exception as e:
            print(f"[WARN] Cleanup failed: {e}")
            return False
    return False



# ==========================================
# BOUCLE 20 : EXPORTS & ANALYSE ROBUSTE
# ==========================================
def detect_export_intent(user_input, code):
    """Detecte si l'utilisateur veut exporter (PDF, Word, Excel)."""
    lower = user_input.lower()
    intents = []
    if any(kw in lower for kw in ['pdf', 'rapport', 'export pdf']):
        intents.append('pdf')
    if any(kw in lower for kw in ['word', 'docx', 'document word']):
        intents.append('word')
    if any(kw in lower for kw in ['excel', 'xlsx', 'export excel', 'tableur']):
        intents.append('excel')
    if any(kw in lower for kw in ['csv', 'export csv']):
        intents.append('csv')
    if any(kw in lower for kw in ['binaire', 'binary', 'hexdump', 'analyser fichier']):
        intents.append('binary')
    return intents

def ensure_export_deps(intents):
    """Installe les deps necessaires selon l'intent."""
    dep_map = {
        'pdf': 'fpdf2',
        'word': 'python-docx',
        'excel': 'openpyxl xlsxwriter',
        'csv': None,
        'binary': None
    }
    installed = []
    for intent in intents:
        pkg = dep_map.get(intent)
        if not pkg:
            continue
        for p in pkg.split():
            mod_name = {'fpdf2': 'fpdf', 'python-docx': 'docx', 'openpyxl': 'openpyxl', 'xlsxwriter': 'xlsxwriter'}.get(p, p)
            import importlib.util
            if importlib.util.find_spec(mod_name) is None:
                print(f"  {YELLOW}[B20] Install {p}...{RESET}")
                try:
                    subprocess.run([sys.executable, "-m", "pip", "install", p, "--quiet"], 
                                   capture_output=True, timeout=120)
                    installed.append(p)
                except Exception as e:
                    print(f"  {RED}[B20] Echec {p}: {e}{RESET}")
    return installed

def analyze_binary_file(filepath):
    """Analyse un fichier binaire : type, taille, entropie, strings."""
    if not os.path.exists(filepath):
        return None
    
    try:
        size = os.path.getsize(filepath)
        with open(filepath, 'rb') as f:
            header = f.read(512)
        
        # Detection du type par signature
        signatures = {
            b'\x89PNG': 'PNG Image',
            b'\xff\xd8\xff': 'JPEG Image',
            b'%PDF': 'PDF Document',
            b'PK\x03\x04': 'ZIP/Office Document',
            b'\x7fELF': 'ELF Binary',
            b'MZ': 'Windows PE/Executable',
            b'GIF8': 'GIF Image',
            b'\x1f\x8b': 'GZIP Archive',
        }
        detected = 'Unknown'
        for sig, name in signatures.items():
            if header.startswith(sig):
                detected = name
                break
        
        # Entropie (Shannon)
        import math
        with open(filepath, 'rb') as f:
            data = f.read(1024 * 1024)  # max 1 MB
        if data:
            freq = [0] * 256
            for byte in data:
                freq[byte] += 1
            entropy = 0
            total = len(data)
            for count in freq:
                if count > 0:
                    p = count / total
                    entropy -= p * math.log2(p)
        
        # Extraction de strings ASCII (min 4 chars)
        import re as _re
        with open(filepath, 'rb') as f:
            content = f.read()
        strings = _re.findall(rb'[\x20-\x7e]{4,}', content)
        sample_strings = [s.decode('ascii', errors='ignore')[:80] for s in strings[:5]]
        
        return {
            'size': size,
            'type': detected,
            'entropy': round(entropy, 3) if data else 0,
            'strings_sample': sample_strings
        }
    except Exception as e:
        return {'error': str(e)}


def purge_ram():
    gc.collect()
    try: ctypes.windll.psapi.EmptyWorkingSet(ctypes.windll.kernel32.GetCurrentProcess())
    except: pass

def get_system_stats():
    stats = {}
    mem = psutil.virtual_memory()
    stats['ram_pct'] = mem.percent
    stats['ram_used_gb'] = mem.used / (1024**3)
    if HAS_GPU:
        try:
            handle = pynvml.nvmlDeviceGetHandleByIndex(0)
            meminfo = pynvml.nvmlDeviceGetMemoryInfo(handle)
            stats['vram_pct'] = (meminfo.used / meminfo.total) * 100
            stats['gpu_temp'] = pynvml.nvmlDeviceGetTemperature(handle, pynvml.NVML_TEMPERATURE_GPU)
        except: pass
    return stats

def check_and_pause(stats):
    alerts = []
    if stats['ram_pct'] > RAM_THRESHOLD_PCT: alerts.append(f"RAM {stats['ram_pct']:.0f}%")
    if stats.get('vram_pct', 0) > VRAM_THRESHOLD_PCT: alerts.append(f"VRAM {stats['vram_pct']:.0f}%")
    gpu_temp = stats.get('gpu_temp', 0)
    is_critical = gpu_temp > TEMP_CRITICAL_C
    if gpu_temp > TEMP_THRESHOLD_C: alerts.append(f"GPU {gpu_temp}°C")
    if alerts:
        if is_critical:
            print(f"\n{RED}{BOLD}🔥 [CRITIQUE] {' | '.join(alerts)} - PAUSE 30s{RESET}")
            purge_ram(); time.sleep(PAUSE_CRITICAL)
        else:
            print(f"\n{RED}{BOLD}🌡️ [SURCHAUFFE] {' | '.join(alerts)}{RESET}")
            print(f"{YELLOW}💤 Pause {PAUSE_DURATION}s{RESET}")
            purge_ram(); time.sleep(PAUSE_DURATION)
        return True
    return False

# ==========================================
# MAIN
# ==========================================
print(f"{CYAN}{'='*70}")
print(f" 🧠 KIBALI - Agent 23 Boucles ULTRA (Autonome + Web + Auto-Création)")
print(f"{'='*70}{RESET}")

system_prompt = """
🏛️ B27 - BOUCLE ENVIRONNEMENT (LAZY LOADING) :
Tu as accès à un registre de 569 librairies Python via la librairie `app_lib_context`.
⚠️ NE DEMANDE JAMAIS LA LISTE COMPLÈTE (ça explose ton contexte).
À la place, fais une RECHERCHE CIBLÉE :

Pour trouver une librairie pour une tâche précise :
<execute>
import app_lib_context
print(app_lib_context.context.find_tool("pdf"))
</execute>

Pour voir un résumé rapide :
<execute>
import app_lib_context
print(app_lib_context.context.get_summary())
</execute>

Pour installer un nouvel outil (il met à jour le registre automatiquement) :
<execute>
import app_lib_context
print(app_lib_context.context.install("nom_du_package"))
</execute>

RÈGLE D'OR : Ne charge que ce dont tu as besoin. Le reste dort sur le disque.

📚 B29 - APPLIBCONTEXT (TON MCP LOCAL INTÉGRÉ) :
Tu n'as plus besoin de serveurs MCP externes. Tu possèdes la librairie `app_lib_context` qui te donne accès à TOUS les outils de la machine.
Utilise-la ainsi :
1. Pour voir tes outils : <execute>import app_lib_context; print(list(app_lib_context.context.get_tools().keys()))</execute>
2. Pour chercher un outil : <execute>import app_lib_context; print(app_lib_context.context.find_tool("pdf"))</execute>
3. Pour installer et enregistrer un nouvel outil : <execute>import app_lib_context; print(app_lib_context.context.install("nom_package"))</execute>

RÈGLE D'OR B29 : `app_lib_context` est ton couteau suisse. Utilise `get_tools()` pour savoir ce que tu as, et `install()` pour ajouter ce qui manque. Ne perds plus de cycles à faire des `pip list` manuels.

🔄 B28 - AUTO-CAPTURE D'ENVIRONNEMENT (SELF-EVOLUTION) :
Tu es un agent qui évolue. Quand tu installes une nouvelle librairie (ex: <terminal>pip install requests</terminal>), tu dois mettre à jour ton cerveau pour la connaître.
Pour ce faire, exécute TOUJOURS cette commande après une installation :
<execute>
import env_capture
print(env_capture.update())
</execute>
Cela va re-scanner ton environnement et mettre à jour ta B27.

⚠️ RÈGLE D'OR : Ne demande jamais à l'utilisateur de mettre à jour son environnement. Fais-le toi-même avec `env_capture`.



Si une librairie manque, tu peux l'installer avec <terminal>pip install nom_lib</terminal>.

🚨🚨🚨 RÈGLE STRICTE POUR LA RECHERCHE WEB 🚨🚨🚨
1. N'ESSAIE JAMAIS de scrapper Google ou DuckDuckGo avec `requests` et `BeautifulSoup`. Les classes HTML changent et tu renvoies (Pas de sortie).
2. La librairie `ddgs` EST DÉJÀ INSTALLÉE dans ton environnement. Utilise-la OBLIGATOIREMENT.
3. Copie-colle EXACTEMENT ce code dans ton <execute> pour chercher sur le web :
<execute>
from ddgs import DDGS
with DDGS() as ddgs:
    results = list(ddgs.text("Ta recherche ici", max_results=3))
    for r in results:
        print(r['title'], "-", r['body'])
</execute>

4. Si `ddgs` n'est pas trouvé, fais `<terminal>pip install ddgs</terminal>` et RÉESSAIE ce code.
5. Ne perds pas de cycles à essayer d'autres sites. `ddgs` est la SEULE méthode autorisée pour le web.

🧰 B26 - DÉCOUVERTE DE L'ENVIRONNEMENT (CAISSE À OUTILS) :
Ton environnement Python est une caisse à outils géante. Tu ne dois JAMAIS demander "Quel outil utiliser ?".
1. AVANT de coder une fonction complexe, inspecte ton environnement avec : <terminal>pip list</terminal>
2. Si une librairie installée correspond à ton besoin, UTILISE-LA DIRECTEMENT.
   - Recherche web ? Regarde si `ddgs`, `duckduckgo_search` ou `requests` est là. Si oui, utilise-le.
   - Fichier Excel ? Regarde si `pandas` ou `openpyxl` est là.
   - PDF ? Regarde si `reportlab` ou `fpdf` est là.
3. Si la librairie n'existe pas, tu l'installes avec `pip install <nom>`.
4. Si tu n'as pas l'outil du tout, tu le codes avec `<create_tool>`.

EXEMPLE DE RECHERCHE WEB SANS INSTALLER DE NOUVEAU :
<execute>
import requests
from bs4 import BeautifulSoup
url = "https://duckduckgo.com/html/?q=match+barcelone+aujourd'hui"
r = requests.get(url, headers={"User-Agent": "Mozilla/5.0"})
soup = BeautifulSoup(r.text, "html.parser")
for a in soup.find_all("a", class_="result__a")[:3]:
    print(a.get_text())
</execute>
Ou si `ddgs` est présent :
<execute>
from ddgs import DDGS
with DDGS() as d:
    for r in d.text("match barcelone aujourd'hui", max_results=3):
        print(r['title'], '-', r['body'])
</execute>

⚠️ RÈGLE D'OR B26 : Ton environnement est sacré. Ne le casse pas. Mais utilise TOUT ce qu'il contient.

🛡️ B24 - BOUCLE DE VÉRIFICATION DE L'ENVIRONNEMENT (SÉCURITÉ ABSOLUE) :
1. AVANT d'exécuter une commande <terminal> qui modifie l'environnement, tu DOIS vérifier l'état actuel.
2. INTERDICTION ABSOLUE de faire `pip uninstall`. Si un package a changé de nom (ex: duckduckgo_search -> ddgs), installe SEULEMENT le nouveau (`pip install ddgs`). Ne touche pas à l'ancien.
3. NE DÉSINSTALLE JAMAIS `pip`, `python`, `requests`, ou toute librairie de base.
4. Si tu doutes qu'une librairie existe, fais `<terminal>pip list</terminal>` ou `<execute>import [lib]</execute>` AVANT de faire quoi que ce soit.
5. Ne gaspille pas l'environnement. Si ça marche déjà, ne touche à rien.

⚠️ RÈGLE DE SÉCURITÉ SYSTÈME (NE JAMAIS ENFREINDRE) :
- Il est INTERDIT de désinstaller `pip`, `python`, ou toute librairie de base de l'environnement (ex: `pip uninstall pip`).
- Si une librairie a changé de nom (ex: duckduckgo_search -> ddgs), installe juste la nouvelle avec `pip install ddgs`. Ne désinstalle pas l'ancienne.
🚨🚨🚨 CHECKLIST AVANT CHAQUE <execute> 🚨🚨🚨

Si ton code utilise `fpdf`, `reportlab`, `pandas`, `openpyxl`, `docx`, `matplotlib`, `pdfplumber`, `xlsxwriter` :

  [ ] J'ai fait un <terminal>pip list</terminal> dans les 2 derniers cycles ?
      SI NON -> fais-le MAINTENANT, puis relance <execute>.

  [ ] Sinon -> le parser rejettera mon code et je perds un cycle.

RECETTE PDF QUI MARCHE (copie-colle) :
  from reportlab.lib.pagesizes import A4
  from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
  from reportlab.lib.styles import getSampleStyleSheet
  pdf = SimpleDocTemplate("rapport.pdf", pagesize=A4)
  styles = getSampleStyleSheet()
  content = [Paragraph("Titre", styles["Heading1"]), Spacer(1, 12),
             Paragraph("Ligne 1", styles["Normal"])]
  pdf.build(content)

Exemple de bon cycle :
  Cycle 1 : <terminal>pip list</terminal>            (voit reportlab)
  Cycle 2 : <execute>...code reportlab...</execute>   (reussi)
  Cycle 3 : <final>...</final>                        (MISSION ACCOMPLIE + break)

═══════════════════════════════════════════════════════════════════════════

Tu es KIBALI, un agent autonome expert.

⚠️ RÈGLES DE CODE PYTHON PUR :
- JAMAIS de !pip, !python, %magic
- Pour installer : subprocess.run([sys.executable, "-m", "pip", "install", "pkg"])
- Code propre, commenté, avec try/except

🔍 RÈGLE ANTI-HALLUCINATION FICHIERS (CRITIQUE) :
Avant de manipuler un fichier, tu DOIS connaître ses VRAIES colonnes.
Si tu ne les connais pas, commence par :
    import pandas as pd
    df = pd.read_excel("fichier.xlsx", nrows=5)
    print(df.columns.tolist())
Ensuite, utilise EXACTEMENT ces colonnes dans ton code.

📦 GROS FICHIERS EXCEL (> 10 000 lignes) - RÈGLES CRITIQUES :
⚠️ pd.read_excel() N'ACCEPTE PAS chunksize (contrairement à read_csv).
Pour un gros Excel, tu as 3 méthodes valides :

MÉTHODE 1 (recommandée) : Convertir en CSV d'abord
    import pandas as pd
    df = pd.read_excel("f.xlsx")
    df.to_csv("temp_memory/f.csv", index=False)
    for chunk in pd.read_csv("temp_memory/f.csv", chunksize=5000):
        ...

MÉTHODE 2 : Lire tout puis traiter par iloc
    df = pd.read_excel("f.xlsx")
    for i in range(0, len(df), 5000):
        chunk = df.iloc[i:i+5000]
        ...

MÉTHODE 3 : openpyxl en read_only (streaming natif)
    import openpyxl
    wb = openpyxl.load_workbook("f.xlsx", read_only=True)
    for row in wb.active.iter_rows(values_only=True):
        ...

NE JAMAIS faire pd.read_excel(chunksize=5000) → TypeError garanti.

🧠 MÉMOIRE EXTERNE :
- Utilise temp_memory/ pour les donnees intermediaires

🛠️ CREATION D'OUTILS TEMPORAIRES (B19) :
Si tu as besoin d'une capacite que tu n'as pas (fonction complexe, calcul repetitif, etc.),
CREER TON PROPRE OUTIL avec cette syntaxe :

<create_tool name="mon_outil">
def calcul_complexe(data):
    return data * 2 + 42

def autre_fonction():
    return "Hello"
</create_tool>

Ensuite, dans le PROCHAIN cycle, tu peux l'utiliser :
<execute>
import mon_outil
result = mon_outil.calcul_complexe(5)
print(result)
</execute>

⚠️ Les outils sont TEMPORAIRES - supprimes automatiquement a la fin de la mission.
⚠️ NE METS PAS d'imports dans <create_tool>, mets-les dans <execute>.
⚠️ UN SEUL <create_tool> OU <execute> par cycle.

📤 EXPORTS & ANALYSE (B20) :
- Pour PDF : `from fpdf import FPDF; pdf = FPDF(); pdf.add_page(); pdf.set_font("Arial", "B", 16); pdf.cell(0, 10, "Titre"); pdf.output("out.pdf")`
- Pour Word : `from docx import Document; doc = Document(); doc.add_heading("Titre"); doc.save("out.docx")`
- Pour Excel : `df.to_excel("out.xlsx", index=False)`
- Pour binaire : analyse avec `open(file, "rb")` et `bytes` patterns

FORMAT (UNE SEULE action par cycle) :
<execute>
[code Python pur]
</execute>
OU
<create_tool name="nom">
[code de la fonction]
</create_tool>
OU
<final>
[rapport]
</final>


CONSULTATION RAG EN TEMPS REEL (VIA <execute>) :
Serveur RAG local : http://127.0.0.1:8765. NE JAMAIS pre-charger dans ton contexte systeme.
Quand tu as besoin d'infos (lois, chiffres, procedures), ECRIS UN SCRIPT dans <execute>.

Endpoints testes :
- POST /search_docs    body {"query":"...","top_k":5}          -> {"docs":"texte"}
- POST /memory/search  body {"query":"...","top_k":5}          -> resultats memoire
- POST /memory/add     body {"query":"...","content":"..."}    -> ajoute note
- GET  /docs_status                                             -> etat (6834 chunks)

REQUETES QUI MARCHENT (testees) :
- "article 221 taux normal 18% TVA"                        -> Art.221 M01_DG_BUDGET
- "taux zero exportation exoneration article 221 CGI"       -> Art.221 Loi-Finances-2025
- "paiement differe TVA importation article 243 quater"     -> Art.243 CGI-2025

REQUETES QUI ECHOUENT (evite) :
- "TVA Gabon" (trop vague) -> renvoie M04_PETROLE hors-sujet
- "TVA exportation" -> idem

Exemple :
import requests
r = requests.post("http://127.0.0.1:8765/search_docs",
                  json={"query":"article 221 taux normal 18% exportation","top_k":5},
                  timeout=15)
print(r.json().get("docs","(vide)"))

REGLES :
- TOUJOURS timeout=10 ou timeout=15
- TOUJOURS print() le resultat
- Si vide/hors-sujet : REFORMULE avec numeros d'article ("article 221", "article 243 quater")
- Si vide apres 2-3 essais : dis "Information absente du RAG", n'invente rien



B21 - OUTILS RAG EXECUTABLES (VIA <execute>) :
Le RAG contient 384 OUTILS ENREGISTRES et EXECUTABLES cote serveur.
NE PAS les importer (pas de "import tva_gabon"). Appeler via HTTP.
Difference avec <create_tool> (B19) : create_tool = outil Python TEMPORAIRE.
Les outils RAG existent DEJA. Tu les EXECUTES, tu ne les codes pas.

ATTENTION : 384 outils. NE JAMAIS faire GET /tool_schemas (sature contexte).
PROCEDURE : 1) POST /search_tools 2) GET /tool_schema/{nom} 3) POST /execute_tool

Endpoints testes :
- POST /search_tools   body {"query":"...","top_k":5}         -> {"tools":["nom1",...]}
- GET  /tool_schema/{nom}                                     -> schema d'UN outil
- POST /execute_tool   body {"tool_name":"...","args":{...}}  -> execute
  ATTENTION : champ "args" PAS "arguments" (sinon 422)

OUTILS FISCALITE CONNUS (POST /search_tools "TVA fiscalite") :
- tva_gabon         : {"montant_ht": number}  -> TVA 18%
- table_tva_gen, report_dgi_tva, fiscal_tool_stats, fiscal_tool_loaded

EXEMPLE (3 cycles) :

Cycle 1 - Chercher :
import requests
r = requests.post("http://127.0.0.1:8765/search_tools",
                  json={"query":"calcul TVA Gabon","top_k":5}, timeout=10)
print(r.json())

Cycle 2 - Schema :
import requests
print(requests.get("http://127.0.0.1:8765/tool_schema/tva_gabon", timeout=10).json())

Cycle 3 - Executer (args, PAS arguments) :
import requests
r = requests.post("http://127.0.0.1:8765/execute_tool",
                  json={"tool_name":"tva_gabon","args":{"montant_ht":50000000}},
                  timeout=30)
print(r.json())

REGLES :
- timeout=10 pour search/schema, timeout=30 pour execute_tool
- 422 = tu as utilise "arguments" au lieu de "args", ou mauvais params
- Si outil absent : POST /search_tools pour un equivalent, sinon calcul direct
- Outils OPTIONNELS : si aucun ne correspond, ne force pas


PERFECTION V6 - REGLES DE COMPORTEMENT :

1. Si tu cherches une loi/article : commence TOUJOURS par une requete avec le numero
   d'article (ex: "article 221 taux TVA", "article 243 quater"). JAMAIS de requete
   vague type "TVA Gabon" (retourne M04_PETROLE hors-sujet).

2. Si le RAG t'a deja donne l'info : NE RECODE PAS dans <execute>. Utilise directement
   <final> pour synthetiser. Le <execute> Python n'est utile que pour :
   - calculs numeriques reels (TVA, ratio, conversion)
   - appels /execute_tool
   - generation PDF/Excel

3. Si une question est complexe (plusieurs sous-questions) : traite chaque partie
   separement dans l'ordre, puis synthetise dans <final>.


V8 - TERMINAL NATIF (VIA <terminal>) :

Tu as un terminal Python natif qui execute dans le venv :
  D:\CPT_Analysis_Studio_PORTABLE\environment\python.exe

AVANT d'ecrire du code de production (<execute>), INSPECTE avec <terminal> :

Exemple 1 - Voir les libs installees :
<terminal>pip list</terminal>

Exemple 2 - Verifier version d'une lib :
<terminal>import reportlab; print(reportlab.Version)</terminal>

Exemple 3 - Explorer une API :
<terminal>from reportlab.platypus import SimpleDocTemplate; print(SimpleDocTemplate)</terminal>

Exemple 4 - Voir fonts fpdf2 :
<terminal>from fpdf import FPDF; print([m for m in dir(FPDF) if 'font' in m.lower()])</terminal>

Exemple 5 - Installer une lib :
<terminal>pip install reportlab</terminal>

REGLES ABSOLUES :
- <terminal> pour INSPECTER (pip list, import, help, dir, version, pip install)
- <execute> pour PRODUIRE (code qui genere PDF/Excel/calculs)
- <final> pour TERMINER
- Tu PEUX enchainer plusieurs <terminal> avant un <execute>
- Les <terminal> NE COMPTENT PAS comme echecs (exploration libre)
- OBLIGATOIRE : si tu vas generer un PDF, fais un <terminal>pip list</terminal> AVANT
- Si <execute> plante 2 fois : utilise <terminal> pour diagnostiquer
- PREFERENCE PDF : reportlab est plus fiable que fpdf2 (unicode natif, pas de bugs)
  Si tu dois utiliser fpdf2 : helvetica, new_x/new_y, multi_cell, PAS de caracteres non-latin1
"""


# =========================================================
# V14 AUTO-DETECT LIBs (au demarrage, 1 seule fois)
# =========================================================
try:
    import subprocess as _sp_v14
    _r14 = _sp_v14.run(
        [sys.executable, "-m", "pip", "list", "--format=freeze"],
        capture_output=True, text=True, timeout=20
    )
    _watched = ['reportlab', 'fpdf', 'pandas', 'numpy', 'openpyxl',
                'matplotlib', 'xlsxwriter', 'pdfplumber', 'python-docx', 'docx']
    _detected = [l.strip() for l in _r14.stdout.split('\n')
                 if l.strip() and any(k in l.lower() for k in _watched)]
    _libs_list = "\n".join(_detected) if _detected else "(aucune lib PDF/Excel)"
except Exception as _e:
    _libs_list = "(erreur: %s)" % _e

system_prompt += f"""

╔══════════════════════════════════════════════════════════════════════════╗
║   LIBS DISPONIBLES (verifie au demarrage)                                ║
╚══════════════════════════════════════════════════════════════════════════╝
{_libs_list}

═══════════════════════════════════════════════════════════════════════════
REGLES QUI MARCHENT (testees) :
═══════════════════════════════════════════════════════════════════════════

1. PDF : utilise REPORTLAB (unicode natif, 0 erreur, marche en 1 coup)
   from reportlab.lib.pagesizes import A4
   from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
   from reportlab.lib.styles import getSampleStyleSheet
   pdf = SimpleDocTemplate("rapport.pdf", pagesize=A4)
   styles = getSampleStyleSheet()
   pdf.build([Paragraph("Titre", styles["Heading1"]), Spacer(1,12),
              Paragraph("Ligne 1", styles["Normal"])])

2. VARIABLES ISOLÉES : chaque <execute> est un script indépendant.
   Si tu as besoin de tva_collectee, tva_deductible, tva_nette, etc.,
   REDEFINIS-LES dans le MEME <execute>. Ils ne persistent PAS entre cycles.

3. Si tu hesites sur une lib, fais <terminal>pip list</terminal> d'abord.
   C'est FACULTATIF, mais recommandé si tu ne connais pas la lib.

4. Une seule action par cycle : <execute> OU <final> OU <terminal>.
   Ne melange pas <execute> et <final> dans le meme cycle (le parser reporte le final).

5. FPDF2 (si tu y tiens) : helvetica + new_x/new_y, PAS de "•", PAS de Arial.
   Mais prefere reportlab.

C'est tout. Pas de punition, pas de garde-fou. Fais confiance a ton jugement.
"""

print("[V14] Libs detectees (%d) et injectees dans le prompt" % len(_detected))

system_prompt += """
🚨🚨🚨 RAPPEL ULTRA (RÈGLES ABSOLUES) 🚨🚨🚨
1. LANGUE : Pense et réponds UNIQUEMENT en FRANÇAIS.
2. AUTONOMIE : Tu as un terminal et Python. Tu ne dois JAMAIS dire "Je ne peux pas accéder à Internet".
3. WEB : Si on te demande l'actualité, utilise <terminal> pour installer duckduckgo_search, puis <execute> pour chercher sur internet.
4. DATE : Si tu as besoin de la date, code `import datetime` dans <execute>.
5. CRÉATION : Si un outil te manque, fabrique-le avec <create_tool>.
Tu es un agent ULTRA. Passe à l'action !
"""

messages = [{"role": "system", "content": system_prompt}]

while True:
    try:
        user_input = input(f"\n{YELLOW}👤 Vous > {RESET}")
        if user_input.strip().lower() in ['quit', 'exit']: break
        if not user_input.strip(): continue

        messages.append({"role": "user", "content": user_input})
        
        MAX_CYCLES = 20
        last_code = ""
        consecutive_failures = 0
        task_completed = False
        
        for cycle in range(1, MAX_CYCLES + 1):
            print(f"\n{BOLD}{CYAN}{'─'*20} 🔄 CYCLE {cycle}/{MAX_CYCLES} {'─'*20}{RESET}")

            # V10 : compteur terminal

            if '_term_count' not in dir():

                _term_count = 0
            
            stats = get_system_stats()
            print(f"{GRAY}📊 RAM: {stats['ram_pct']:.0f}% | VRAM: {stats.get('vram_pct',0):.0f}% | GPU: {stats.get('gpu_temp','N/A')}°C{RESET}")
            
            check_and_pause(stats)
            purge_ram()
            
            if consecutive_failures >= 3:
                print(f"\n{RED}{BOLD}🚨 [CONTOURNEMENT FORCÉ]{RESET}")
                messages.append({"role": "user", "content": "3 échecs. CHANGE de stratégie."})
                consecutive_failures = 0
            
            full_content = ""
            full_thinking = ""
            start_time = time.time()
            first_token_time = None
            thinking_started = False
            content_started = False
            thinking_truncated = False
            
            response = client.chat.completions.create(
                model="Qwen3-8B", messages=messages, stream=True,
                max_tokens=1500, temperature=0.15,
                extra_body={"chat_template_kwargs": {"enable_thinking": True}}
            )
            
            try:
                for chunk in response:
                    delta = chunk.choices[0].delta
                    if first_token_time is None: first_token_time = time.time() - start_time
                    
                    reasoning = getattr(delta, 'reasoning_content', None)
                    if reasoning:
                        full_thinking += reasoning
                        if len(full_thinking) > 2500 and not thinking_truncated:
                            thinking_truncated = True
                            break
                        if not thinking_started:
                            print(f"\n{GRAY}💭 [Réflexion]{RESET}")
                            thinking_started = True
                        print(f"{GRAY}{reasoning}{RESET}", end="", flush=True)
                    
                    content = getattr(delta, 'content', None)
                    if content:
                        if not content_started:
                            if thinking_started: print(f"\n\n{CYAN}🎯 [Action]{RESET}\n")
                            content_started = True
                        full_content += content
                        clean = content.replace("<execute>", f"\n{GREEN}⚙️ [Code...]{RESET}\n").replace("</execute>", "").replace("<final>", f"\n{CYAN}💡 [Rapport]{RESET}\n").replace("</final>", "")
                        if clean: print(clean, end="", flush=True)
            except Exception as e:
                print(f"\n{RED}[Stream interrompu] {e}{RESET}")
            
            messages.append({"role": "assistant", "content": full_content if full_content else "<execute>\nprint('reprise')\n</execute>"})
            
            if thinking_truncated and not full_content:
                messages.append({"role": "user", "content": "STOP réflexion. Code MAINTENANT."})
                continue
            
            if "<final>" in full_content:
                _has_exec_in_cycle = bool(re.search(r'<(execute|terminal)>(.*?)</\1>', full_content, re.DOTALL))
                if _has_exec_in_cycle:
                    print(f"\n{YELLOW}[V7] <final> + <execute> detectes -> execute prioritaire, final reporte au prochain cycle{RESET}")
                    task_completed = False
                else:
                    print(f"\n\n{GREEN}{BOLD}✅ [MISSION ACCOMPLIE au cycle {cycle}]{RESET}")
                    task_completed = True
                    consecutive_failures = 0
                    break
            # ==========================================
            # B19 : DETECTION DES CREATIONS D'OUTILS
            # ==========================================
            tool_creations = extract_create_tool_blocks(full_content)
            if tool_creations:
                print(f"\n{CYAN}\U0001f6e0\ufe0f [B19 - Auto-Tool Creation] {len(tool_creations)} outil(s){RESET}")
                msgs_tools = []
                for t in tool_creations:
                    ok, msg = install_temp_tool(t['name'], t['code'])
                    if ok:
                        print(f"{GREEN}   \u2705 {t['name']} installe{RESET}")
                        msgs_tools.append(f"OK: {t['name']} (importable via `import {t['name']}`)")
                    else:
                        print(f"{RED}   \u274c {t['name']} : {msg}{RESET}")
                        msgs_tools.append(f"ECHEC: {t['name']} - {msg}")
                
                # Strip des create_tool du content
                full_content = re.sub(r'<create_tool\s+name="[^"]+">.*?</create_tool>', '', full_content, flags=re.DOTALL)
                
                feedback_tools = "OUTILS TEMPORAIRES :\n" + "\n".join(msgs_tools)
                feedback_tools += f"\n\nOutils actuellement disponibles : {list_temp_tools()}"
                feedback_tools += "\n\nTu peux les utiliser avec `import <nom>`."
                messages.append({"role": "user", "content": feedback_tools})
                
                # Si pas de execute apres, on continue
                if not re.search(r'<execute>(.*?)</execute>', full_content, re.DOTALL):
                    consecutive_failures = 0
                    continue
            
            # === V8 : TERMINAL NATIF ===
            match_terminal = re.search(r'<terminal>(.*?)</terminal>', full_content, re.DOTALL)
            if match_terminal:
                import os as _os, sys as _sys, subprocess as _sp
                cmd = match_terminal.group(1).strip()
                print(f"\n{CYAN}💻 [Terminal]{RESET} {cmd[:120]}")
                PY_EXE = _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "environment", "python.exe")
                if not _os.path.exists(PY_EXE):
                    PY_EXE = _sys.executable
                if cmd.startswith("pip ") or cmd.startswith("pip3 "):
                    parts = cmd.split()
                    if parts[0] == "pip3":
                        parts[0] = "pip"
                    args = [PY_EXE, "-m"] + parts
                elif cmd.startswith(("dir ", "ls ", "cat ", "echo ", "type ", "where ")):
                    args = ["cmd", "/c", cmd]
                else:
                    args = [PY_EXE, "-c", cmd]
                try:
                    result = _sp.run(args, capture_output=True, text=True, timeout=60,
                        cwd=_os.path.dirname(_os.path.abspath(__file__)))
                    output = result.stdout or ""
                    if result.stderr:
                        output += "\n[STDERR]\n" + result.stderr
                    output = output.strip() or "(pas de sortie)"
                    if len(output) > 2500:
                        output = output[:2500] + "\n[...tronque]"
                    print(f"{GRAY}{output}{RESET}")
                except _sp.TimeoutExpired:
                    output = "TIMEOUT (60s)"
                    print(f"{RED}{output}{RESET}")
                except Exception as e:
                    output = f"ERREUR: {e}"
                    print(f"{RED}{output}{RESET}")
                messages.append({"role": "user", "content": f"TERMINAL RESULTAT:\n{output}\n\nContinue (utilise <terminal> pour explorer encore, <execute> pour produire, ou <final>)."})
                continue
            # === FIN V8 ===

            match = re.search(r'<execute>(.*?)</execute>', full_content, re.DOTALL)
            if not match:
                messages.append({"role": "user", "content": "Format invalide. Utilise <execute>...</execute>, <create_tool>...</create_tool>, ou <final>."})
                consecutive_failures += 1
                continue
            
            raw_code = match.group(1).strip()
            raw_code = re.sub(r'^```python\s*', '', raw_code)
            raw_code = re.sub(r'^```\s*', '', raw_code)
            raw_code = re.sub(r'\s*```$', '', raw_code).strip()
            
            if raw_code == last_code:
                print(f"\n{RED}{BOLD}🛑 [STAGNATION]{RESET}")
                messages.append({"role": "user", "content": "STAGNATION. Change de stratégie."})
                consecutive_failures += 2
                continue
            last_code = raw_code
            
            # B10
            code_to_run = sanitize_jupyter(raw_code)

            # 🛡️ SÉCURITÉ ABSOLUE ANTI-DESTRUCTION DE PIP
            if "pip uninstall" in code_to_run or "-m pip uninstall" in code_to_run:
                print(f"{RED}🛑 [SÉCURITÉ] Tentative de désinstallation bloquée !{RESET}")
                messages.append({"role": "user", "content": "ERREUR CRITIQUE : Tu as essayé d'utiliser 'pip uninstall'. C'est STRICTEMENT INTERDIT. Utilise 'pip install'. Ne désinstalle jamais pip."})
                consecutive_failures += 1
                continue
            
            # B19 : Injection sys.path pour les outils temporaires
            if list_temp_tools():
                code_to_run = inject_temp_tools_path(code_to_run)
            if code_to_run != raw_code:
                print(f"{YELLOW}🧹 [B10] Jupyter nettoyé{RESET}")
            
            # B11
            syntax_ok, syntax_err = validate_syntax(code_to_run)
            if not syntax_ok:
                print(f"\n{RED}🛑 [B11] {syntax_err}{RESET}")
                messages.append({"role": "user", "content": f"SyntaxError : {syntax_err}"})
                consecutive_failures += 1
                continue
            print(f"{GREEN}✅ [B11] OK{RESET}")
            
            # B15
            print(f"{CYAN}🔍 [B15 - Anti-Hallucination]{RESET}")
            ah = anti_hallucination_check(code_to_run)
            if ah.get('real_columns'):
                for fp, cols in ah['real_columns'].items():
                    print(f"{GRAY}   {fp} → {cols}{RESET}")
            
            if ah['block']:
                print(f"\n{RED}🛑 [B15] BLOQUÉ ({ah['reason']}) : {ah['message']}{RESET}")
                messages.append({"role": "user", "content": f"❌ ANTI-HALLUCINATION :\n{ah['message']}"})
                consecutive_failures += 1
                continue
            print(f"{GREEN}✅ [B15] OK{RESET}")
            
            # B16 : AUTO-CORRECTION
            real_cols = []
            for cols in ah.get('real_columns', {}).values():
                real_cols.extend(cols)
            real_cols = list(set(real_cols))
            
            if real_cols:
                print(f"{CYAN}🔧 [B16 - Auto-Fix]{RESET}")
                code_to_run, r16 = loop16_autofix(code_to_run, real_cols)
                if r16['fixed_columns']:
                    for fix in r16['fixed_columns']:
                        print(f"{GREEN}   ✅ {fix}{RESET}")
                if r16['ast_errors']:
                    for err in r16['ast_errors']:
                        print(f"{RED}   ⚠️ AST: {err}{RESET}")
                    messages.append({"role": "user", "content": f"Erreurs AST : {r16['ast_errors']}. Vraies colonnes : {real_cols}"})
                    consecutive_failures += 1
                    continue
                if r16['has_changes']:
                    print(f"{YELLOW}   💉 Code auto-corrigé avant exécution{RESET}")
                print(f"{GREEN}✅ [B16] OK{RESET}")
            
            # B20 : EXPORTS & ANALYSE ROBUSTE
            export_intents = detect_export_intent(user_input, code_to_run)
            if export_intents:
                print(f"{CYAN}[B20 - Exports] Intentions : {export_intents}{RESET}")
                installed_b20 = ensure_export_deps(export_intents)
                if installed_b20:
                    print(f"{GREEN}[B20] Installes : {', '.join(installed_b20)}{RESET}")
                # Analyse binaire si fichier mentionne
                binary_files = re.findall(r'["\']([^"\']+\.(?:bin|dat|raw|exe|dll|so|pkl|npy|h5|safetensors|pt|ckpt))["\']', code_to_run)
                for bf in binary_files:
                    if os.path.exists(bf):
                        print(f"{CYAN}[B20] Analyse binaire : {bf}{RESET}")
                        info = analyze_binary_file(bf)
                        if info and 'error' not in info:
                            print(f"{GRAY}   Type: {info['type']} | Taille: {info['size']} bytes | Entropie: {info['entropy']}{RESET}")
                            messages.append({
                                "role": "user",
                                "content": f"Fichier binaire {bf} analyse : type={info['type']}, taille={info['size']} bytes, entropie={info['entropy']}. Utilise ces infos dans ton code."
                            })
                        break
            
            # B17 : ANTI-PIEGE PANDAS
            pandas_traps = check_pandas_traps(code_to_run)
            if pandas_traps:
                for trap in pandas_traps:
                    print(f"{RED}[B17] PIEGE PANDAS : {trap['message']}{RESET}")
                    messages.append({
                        "role": "user", 
                        "content": f"PIEGE DETECTE : {trap['message']}\n\nSOLUTION : {trap['suggested_fix']}"
                    })
                consecutive_failures += 1
                continue
            print(f"{GREEN}[B17] Pas de piege pandas{RESET}")
            
            # B12
            installed, failed = check_and_install_deps(code_to_run)
            if installed:
                print(f"{GREEN}📦 [B12] Installés : {', '.join(installed)}{RESET}")
            
            # B13
            compile_ok, compile_err = precompile_check(code_to_run)
            if not compile_ok:
                print(f"\n{RED}🛑 [B13] {compile_err}{RESET}")
                messages.append({"role": "user", "content": f"Compile échoué : {compile_err}"})
                consecutive_failures += 1
                continue
            print(f"{GREEN}✅ [B13] OK{RESET}")
            
            # EXÉCUTION
            print(f"\n{CYAN}📟 [Exécution Terminal]{RESET}")
            print("-" * 60)
            error_occurred = False
            output = ""
            
            try:
                temp_filename = "temp_agent_exec.py"
                with open(temp_filename, "w", encoding="utf-8") as f:
                    f.write(code_to_run)
                
                process = subprocess.Popen(
                    [sys.executable, temp_filename],
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="utf-8", bufsize=1
                )
                
                try:
                    for line in iter(process.stdout.readline, ''):
                        print(f"  {line}", end="", flush=True)
                        output += line
                    for line in iter(process.stderr.readline, ''):
                        print(f"  {RED}{line}{RESET}", end="", flush=True)
                        output += f"\n[STDERR]: {line}"
                        error_occurred = True
                    process.wait(timeout=600)
                except subprocess.TimeoutExpired:
                    process.kill()
                    output = "TIMEOUT (>10min)"
                    error_occurred = True
                    print(f"  {RED}{output}{RESET}")
                
                os.remove(temp_filename)
                
                keyerr = re.search(r"KeyError:\s*['\"]([^'\"]+)['\"]", output)
                if keyerr:
                    col_err = keyerr.group(1)
                    messages.append({"role": "user", "content": f"KeyError '{col_err}'. Vraies colonnes : {real_cols}"})
                    consecutive_failures += 1
                    continue
                
                if not output.strip():
                    output = "(Pas de sortie)"
                    print(f"  {output}")
            
            except Exception as e:
                output = f"Erreur système: {str(e)}"
                error_occurred = True
                print(f"  {RED}{output}{RESET}")
            
            print("-" * 60)
            
            if error_occurred:
                consecutive_failures += 1
                print(f"{RED}⚠️ [Échec {consecutive_failures}/3]{RESET}")
                messages.append({"role": "user", "content": f"ÉCHEC #{consecutive_failures}:\n{output}"})
            else:
                consecutive_failures = 0
                print(f"{GREEN}✅ [Succès]{RESET}")
                messages.append({"role": "user", "content": f"SUCCÈS:\n{output}\n\nContinue ou <final>."})
        
        if not task_completed:
            print(f"\n{YELLOW}{BOLD}⚠️ [Limite {MAX_CYCLES} cycles]{RESET}")
    
    except KeyboardInterrupt:
        print("\nAu revoir !")
        break
    except Exception as e:
        print(f"\n{RED}[ERREUR]{RESET} {e}")