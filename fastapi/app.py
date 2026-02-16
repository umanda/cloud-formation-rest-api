from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
import os

app = FastAPI(
    title="CRUD API on Fargate",
    description="Simple CRUD API running on AWS ECS Fargate",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

items_db = {}
item_counter = 0

class Item(BaseModel):
    name: str
    description: Optional[str] = None
    price: float
    quantity: int = 0

class ItemResponse(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    price: float
    quantity: int
    created_at: str
    updated_at: str

@app.get("/")
def read_root():
    return {
        "message": "Welcome to CRUD API on ECS Fargate!",
        "status": "running",
        "environment": os.getenv("ENVIRONMENT", "production"),
        "platform": "AWS ECS Fargate",
        "endpoints": {
            "docs": "/docs",
            "items": "/items",
            "health": "/health"
        }
    }

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "total_items": len(items_db),
        "platform": "ECS Fargate"
    }

@app.post("/items", response_model=ItemResponse, status_code=201)
def create_item(item: Item):
    global item_counter
    item_counter += 1
    now = datetime.utcnow().isoformat()
    new_item = {
        "id": item_counter,
        "name": item.name,
        "description": item.description,
        "price": item.price,
        "quantity": item.quantity,
        "created_at": now,
        "updated_at": now
    }
    items_db[item_counter] = new_item
    return new_item

@app.get("/items", response_model=List[ItemResponse])
def get_items():
    return list(items_db.values())

@app.get("/items/{item_id}", response_model=ItemResponse)
def get_item(item_id: int):
    if item_id not in items_db:
        raise HTTPException(status_code=404, detail="Item not found")
    return items_db[item_id]

@app.put("/items/{item_id}", response_model=ItemResponse)
def update_item(item_id: int, item: Item):
    if item_id not in items_db:
        raise HTTPException(status_code=404, detail="Item not found")
    updated_item = {
        **items_db[item_id],
        "name": item.name,
        "description": item.description,
        "price": item.price,
        "quantity": item.quantity,
        "updated_at": datetime.utcnow().isoformat()
    }
    items_db[item_id] = updated_item
    return updated_item

@app.delete("/items/{item_id}")
def delete_item(item_id: int):
    if item_id not in items_db:
        raise HTTPException(status_code=404, detail="Item not found")
    deleted_item = items_db.pop(item_id)
    return {
        "message": "Item deleted successfully",
        "deleted_item": deleted_item
    }

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run(app, host="0.0.0.0", port=port)
