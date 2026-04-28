from fastapi import FastAPI
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
# import your existing functions
from app import ask_gemini 

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # for dev only
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class QueryRequest(BaseModel):
    query: str


@app.post("/ask")
def ask_question(req: QueryRequest):
    answer, sources = ask_gemini(req.query)

    return {
        "answer": answer,
        "sources": sources
    }