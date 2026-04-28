import os
import json
import faiss
import numpy as np
import time
from sentence_transformers import SentenceTransformer
from google import genai


#Setting up GEMINI API Key
API_KEY = os.environ.get("GOOGLE_API_KEY")
client = genai.Client(api_key=API_KEY)

#embedding model
model = SentenceTransformer("BAAI/bge-small-en")

#FAISS index
index = faiss.read_index("faiss.index")

# Load metadata
with open("metadata.json", "r") as f:
    metadata_store = json.load(f)


#CACHE
cache = {}


#SEARCH FUNCTION
def get_relevant_papers(query, top_k=5):  #k= the now of papers to retrieve
    query_embedding = model.encode([query], normalize_embeddings=True)
    distances, indices = index.search(np.array(query_embedding), top_k)

    results = []
    for idx in indices[0]:
        if idx < len(metadata_store):
            results.append(metadata_store[idx])

    return results

#GEMINI FUNCTION (OPTIMIZED)
def ask_gemini(query):
    if query in cache:
        print("⚡ Using cached response\n")
        return cache[query]

    context_papers = get_relevant_papers(query)

    if not context_papers:
        return "No relevant papers found.", []

    context_text = ""
    for p in context_papers:
        abstract = p['abstract'][:300] 

        context_text += (
            f"ID: {p['id']}\n"
            f"Title: {p['title']}\n"
            f"Abstract: {abstract}\n---\n"
        )

    prompt = f"""
Answer using ONLY the context.
Cite paper IDs like [ID: xxxx].
Be concise and structured.
Add brief reasoning.

Context:
{context_text}

Question: {query}
"""
    max_retries = 3
    for attempt in range(max_retries):
        try:
            response = client.models.generate_content(
                model="gemini-3-flash-preview",
                contents=[prompt]
            )

            result = (response.text, context_papers)

            cache[query] = result

            return result

        except Exception as e:
            if "429" in str(e) and attempt < max_retries - 1:
                wait_time = 2 ** attempt
                print(f"⏳ Rate limit hit. Retrying in {wait_time}s...")
                time.sleep(wait_time)
            else:
                raise e

# DISPLAY FUNCTION
def display_sources(sources):
    print("\n📚 SOURCES USED:\n")
    for i, p in enumerate(sources):
        print(f"{i+1}. {p['title']}")
        print(f"   ID: {p['id']}")
        print(f"   Authors: {p['authors']}")
        print("-" * 50)

# MAIN (APP)
def run_app():
    print("\nAsk anything about research papers (type 'exit' to quit)\n")

    while True:
        user_query = input("Your Question: ")

        if user_query.lower() in ["exit", "quit"]:
            print("Exiting...")
            break

        if not user_query.strip():
            print("Please enter a question\n")
            continue

        print("\nThinking...\n")

        try:
            answer, sources = ask_gemini(user_query)

            print("=" * 60)
            print("Summary:\n")
            print(answer)
            print("=" * 60)

            display_sources(sources)

        except Exception as e:
            print(f"Error: {e}")

        print("\n" + "="*60 + "\n")

# RUN
if __name__ == "__main__":
    run_app()