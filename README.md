# KIBALI MOTEUR V3 FAST
Moteur d'orchestration local pour agents LLM autonomes avec RAG temps reel.

## Caracteristiques
- 21 boucles d'orchestration (anti-hallucination, auto-fix, exports)
- LLM principal : Qwen3-8B (local, GPU)
- RAG : FAISS (6834 chunks indexes)
- Contexte LLM propre (RAG consulte a la demande)
- Auto-detection des libs au demarrage (V14)
- Auto-correction sur 20 cycles

## Demarrage

    .\lanceur_boucles_kibali.ps1
    .\environment\python.exe KIBALI_MOTEUR_V3_FAST.py
