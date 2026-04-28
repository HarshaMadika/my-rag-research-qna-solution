import os
import json
import numpy as np
import faiss
from sentence_transformers import SentenceTransformer

# =========================
# CONFIG
# =========================
DATA_PATH = "data/docs/arxiv-metadata-oai-snapshot.json"
INDEX_FILE = "faiss.index"
META_FILE = "metadata.json"

BATCH_SIZE = 512
EMBED_MODEL = "BAAI/bge-small-en"
EMBED_DIM = 384


#LOAD EMBEDDING MODEL
print("Loading embedding model...")
model = SentenceTransformer(EMBED_MODEL)


#INIT FAISS INDEX
print(" Initializing FAISS index...")
index = faiss.IndexFlatL2(EMBED_DIM)

# Metadata storage (for retrieval)
metadata_store = []


# PROCESS BATCH
def process_batch(batch):
    texts = [
        f"{p['title']} {p['abstract']}"
        for p in batch
    ]

    # Convert text → vectors
    embeddings = model.encode(
        texts,
        batch_size=64,
        show_progress_bar=False,
        normalize_embeddings=True
    )

    # Add vectors to FAISS
    index.add(np.array(embeddings))

    # Store metadata
    metadata_store.extend(batch)


# SAVE PROGRESS
def save_progress():
    print("Saving index and metadata...")
    faiss.write_index(index, INDEX_FILE)

    with open(META_FILE, "w") as f:
        json.dump(metadata_store, f)


# INGESTION PIPELINE
def ingest():
    if not os.path.exists(DATA_PATH):
        print("File not found")
        return

    batch = []

    with open(DATA_PATH, "r") as f:
        for i, line in enumerate(f):
            try:
                paper = json.loads(line)

                batch.append({
                    "id": paper.get("id"),
                    "title": paper.get("title", ""),
                    "abstract": paper.get("abstract", ""),
                    "authors": paper.get("authors", "")
                })

                if len(batch) >= BATCH_SIZE:
                    process_batch(batch)
                    batch = []

                    print(f"✅ Processed {i} papers")

                # Save every 10k papers (checkpoint)
                if i > 0 and i % 10000 == 0:
                    save_progress()

            except Exception as e:
                print(f"Skipping bad entry: {e}")

    # Process remaining
    if batch:
        process_batch(batch)

    save_progress()
    print("Ingestion complete!")


# SEARCH FUNCTION
def search(query, top_k=5):
    query_embedding = model.encode(
        [query],
        normalize_embeddings=True
    )

    distances, indices = index.search(
        np.array(query_embedding),
        top_k
    )

    results = []
    for idx in indices[0]:
        if idx < len(metadata_store):
            results.append(metadata_store[idx])

    return results


# MAIN

if __name__ == "__main__":
    ingest()

    # Example query
    print("\n🔍 Sample Search:\n")
    results = search("deep learning in medical imaging", top_k=3)

    for r in results:
        print(f"\nTitle: {r['title']}")
        print(f"Authors: {r['authors']}")
        print(f"Abstract: {r['abstract'][:200]}...")