# KIBALI MOTEUR V3 FAST - Architecture

- LLM       : Qwen3-8B (port 8080)
- RAG       : FAISS (port 8765, 6834 chunks)
- Embeddings: BGE-M3 (port 8082)

## Principe cle : CONTEXTE PROPRE
Aucun document RAG n'est pre-charge. L'agent consulte via execute Python.
Cela preserve les performances du 8B.

## Boucles
- B15 : Anti-hallucination
- B21 : Consultation outils RAG
- V7  : execute prioritaire sur final
- V14 : Auto-detect libs au demarrage
