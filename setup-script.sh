#!/bin/bash

# Web Scraper with Vector Storage - Setup Script
# This script sets up the complete project structure and installs all dependencies

echo "===== Setting up Web Scraper with Vector Storage ====="

# Create project directory structure
echo "Creating project directory structure..."
mkdir -p web_scraper_app/templates 
mkdir -p web_scraper_app/static/css 
mkdir -p web_scraper_app/static/js 
mkdir -p web_scraper_app/data/raw 
mkdir -p web_scraper_app/data/chroma

# Navigate to project directory
cd web_scraper_app

# Create requirements.txt
echo "Creating requirements.txt..."
cat > requirements.txt << 'EOF'
fastapi==0.103.1
uvicorn==0.23.2
pydantic==2.4.2
requests==2.31.0
beautifulsoup4==4.12.2
sentence-transformers==2.2.2
chromadb==0.4.18
lxml==4.9.3
python-multipart==0.0.6
jinja2==3.1.2
EOF

# Create README.md
echo "Creating README.md..."
cat > README.md << 'EOF'
# Web Scraper with Vector Storage

A web application that allows you to scrape web content, extract structured data, and store both raw content and vector embeddings for future use with LLMs.

## Features

- Web interface with URL input form
- Configurable content extraction (paragraphs, headlines, images, tables)
- Real-time status updates during scraping
- Preview of extracted content before storage
- Storage of both raw content and vector embeddings
- Comprehensive error handling

## Technology Stack

- **Backend**: FastAPI, Python
- **Frontend**: HTML, CSS, JavaScript (Alpine.js)
- **Web Scraping**: BeautifulSoup, Requests
- **Embeddings**: sentence-transformers
- **Vector Storage**: ChromaDB

## Setup

1. Create and activate a virtual environment:
   ```
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. Install dependencies:
   ```
   pip install -r requirements.txt
   ```

3. Run the application:
   ```
   uvicorn app:app --reload
   ```

4. Open your browser and navigate to http://localhost:8000

## Usage

1. Enter a URL in the input field
2. Select content types you want to extract
3. Click "Scrape" to start the process
4. Review the extracted content in the preview tabs
5. Click "Save Content & Embeddings" to store the data

## Project Structure

```
web_scraper_app/
├── app.py                 # Main FastAPI application
├── scraper.py             # Web scraping functionality
├── embeddings.py          # Vector embedding generation
├── storage.py             # Data storage operations
├── data/                  # Data storage directory
│   ├── raw/               # Raw JSON content storage
│   └── chroma/            # ChromaDB vector storage
├── static/                # Static assets
│   ├── css/
│   │   └── styles.css     # CSS styling
│   └── js/
│       └── app.js         # Frontend JavaScript with Alpine.js
└── templates/             # HTML templates
    └── index.html         # Main application template
```
EOF

# Create scraper.py
echo "Creating scraper.py..."
cat > scraper.py << 'EOF'
import re
import requests
from bs4 import BeautifulSoup
from typing import Dict, List, Optional, Any
from urllib.parse import urlparse

class WebScraper:
    def __init__(self):
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
            'Pragma': 'no-cache',
            'Cache-Control': 'no-cache',
        }
    
    def validate_url(self, url: str) -> bool:
        """Validate if the provided URL is properly formatted."""
        try:
            result = urlparse(url)
            return all([result.scheme, result.netloc])
        except Exception:
            return False
    
    async def scrape(self, url: str, content_types: Dict[str, bool]) -> Dict[str, Any]:
        """
        Scrape website content based on specified content types.
        
        Args:
            url: Website URL to scrape
            content_types: Dictionary specifying which content types to extract
            
        Returns:
            Dictionary containing extracted content
        """
        # Validate URL
        if not self.validate_url(url):
            return {"error": "Invalid URL format"}
        
        # Initialize results container
        results = {
            "url": url,
            "title": "",
            "paragraphs": [],
            "headlines": [],
            "images": [],
            "tables": [],
            "metadata": {
                "num_paragraphs": 0,
                "num_headlines": 0,
                "num_images": 0,
                "num_tables": 0
            }
        }
        
        try:
            # Make HTTP request
            response = requests.get(url, headers=self.headers, timeout=10)
            response.raise_for_status()
            
            # Parse HTML content
            soup = BeautifulSoup(response.text, 'lxml')
            
            # Extract page title
            title_tag = soup.find('title')
            results["title"] = title_tag.text.strip() if title_tag else "No title found"
            
            # Extract content based on selected types
            if content_types.get("paragraphs", False):
                paragraphs = soup.find_all('p')
                results["paragraphs"] = [p.text.strip() for p in paragraphs if p.text.strip()]
                results["metadata"]["num_paragraphs"] = len(results["paragraphs"])
            
            if content_types.get("headlines", False):
                headlines = []
                for i in range(1, 7):
                    headlines.extend(soup.find_all(f'h{i}'))
                results["headlines"] = [h.text.strip() for h in headlines if h.text.strip()]
                results["metadata"]["num_headlines"] = len(results["headlines"])
            
            if content_types.get("images", False):
                images = soup.find_all('img')
                results["images"] = [
                    {
                        "alt": img.get('alt', ''),
                        "src": img.get('src', ''),
                        "width": img.get('width', ''),
                        "height": img.get('height', '')
                    }
                    for img in images if img.get('src')
                ]
                results["metadata"]["num_images"] = len(results["images"])
            
            if content_types.get("tables", False):
                tables = soup.find_all('table')
                results["tables"] = []
                
                for table in tables:
                    table_data = {"headers": [], "rows": []}
                    
                    # Extract headers
                    th_tags = table.find_all('th')
                    if th_tags:
                        table_data["headers"] = [th.text.strip() for th in th_tags]
                    
                    # Extract rows
                    rows = table.find_all('tr')
                    for row in rows:
                        cells = row.find_all(['td', 'th'])
                        if cells:
                            row_data = [cell.text.strip() for cell in cells]
                            table_data["rows"].append(row_data)
                    
                    results["tables"].append(table_data)
                
                results["metadata"]["num_tables"] = len(results["tables"])
            
            return results
            
        except requests.exceptions.RequestException as e:
            error_type = type(e).__name__
            if isinstance(e, requests.exceptions.ConnectionError):
                error_msg = "Connection error. Please check the URL and your internet connection."
            elif isinstance(e, requests.exceptions.Timeout):
                error_msg = "Request timed out. The website might be slow or unavailable."
            elif isinstance(e, requests.exceptions.HTTPError):
                if e.response.status_code == 403:
                    error_msg = "Access denied (403). The website might be blocking web scrapers."
                elif e.response.status_code == 404:
                    error_msg = "Page not found (404). The URL might be incorrect."
                else:
                    error_msg = f"HTTP error occurred: {e.response.status_code}"
            else:
                error_msg = str(e)
            
            return {"error": f"{error_type}: {error_msg}"}
            
        except Exception as e:
            return {"error": f"Unexpected error: {str(e)}"}
EOF

# Setup virtual environment and install dependencies
echo "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

echo "Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo "===== Setup Complete ====="
echo "To start the application, run: uvicorn app:app --reload"
echo "Then open http://localhost:8000 in your browser"

# Create embeddings.py
echo "Creating embeddings.py..."
cat > embeddings.py << 'EOF'
from sentence_transformers import SentenceTransformer
from typing import List, Dict, Any, Union
import os
import json

class EmbeddingsGenerator:
    def __init__(self, model_name: str = "all-MiniLM-L6-v2"):
        """
        Initialize the embeddings generator with the specified model.
        
        Args:
            model_name: The name of the sentence-transformers model to use
        """
        self.model_name = model_name
        # Lazy loading of the model to save resources
        self._model = None
    
    @property
    def model(self):
        """Lazy load the model when first needed"""
        if self._model is None:
            self._model = SentenceTransformer(self.model_name)
        return self._model
    
    def generate_embeddings(self, texts: List[str]) -> List[List[float]]:
        """
        Generate embeddings for a list of texts.
        
        Args:
            texts: List of text strings to generate embeddings for
            
        Returns:
            List of embedding vectors
        """
        if not texts:
            return []
        
        # Generate embeddings
        embeddings = self.model.encode(texts, convert_to_tensor=False)
        
        return embeddings.tolist()
    
    def prepare_content_for_embeddings(self, content: Dict[str, Any]) -> Dict[str, List[str]]:
        """
        Prepare the scraped content for embedding generation.
        
        Args:
            content: Dictionary containing the scraped content
            
        Returns:
            Dictionary mapping content types to lists of text to be embedded
        """
        result = {
            "title": [],
            "paragraphs": [],
            "headlines": [],
            "table_data": []
        }
        
        # Add title
        if content.get("title"):
            result["title"].append(content["title"])
        
        # Add paragraphs
        if content.get("paragraphs"):
            result["paragraphs"] = content["paragraphs"]
        
        # Add headlines
        if content.get("headlines"):
            result["headlines"] = content["headlines"]
        
        # Add table data as text
        if content.get("tables"):
            for table in content["tables"]:
                # Convert table headers to text
                if table.get("headers"):
                    table_text = " | ".join(table["headers"])
                    result["table_data"].append(table_text)
                
                # Convert table rows to text
                if table.get("rows"):
                    for row in table["rows"]:
                        row_text = " | ".join(row)
                        result["table_data"].append(row_text)
        
        return result
EOF

# Create storage.py
echo "Creating storage.py..."
cat > storage.py << 'EOF'
import json
import os
import time
import chromadb
from chromadb.config import Settings
from typing import Dict, List, Any, Optional, Union
import uuid

class StorageManager:
    def __init__(self, raw_data_dir: str = "data/raw", chroma_db_dir: str = "data/chroma"):
        """
        Initialize the storage manager with specified directories.
        
        Args:
            raw_data_dir: Directory for storing raw JSON content
            chroma_db_dir: Directory for ChromaDB vector database
        """
        self.raw_data_dir = raw_data_dir
        self.chroma_db_dir = chroma_db_dir
        
        # Ensure directories exist
        os.makedirs(self.raw_data_dir, exist_ok=True)
        os.makedirs(self.chroma_db_dir, exist_ok=True)
        
        # Initialize ChromaDB client
        self.chroma_client = chromadb.PersistentClient(path=self.chroma_db_dir)
        
        # Create or get collections for different content types
        self.collections = {
            "title": self.chroma_client.get_or_create_collection("titles"),
            "paragraphs": self.chroma_client.get_or_create_collection("paragraphs"),
            "headlines": self.chroma_client.get_or_create_collection("headlines"),
            "table_data": self.chroma_client.get_or_create_collection("table_data"),
        }
    
    def store_raw_content(self, content: Dict[str, Any]) -> str:
        """
        Store raw scraped content as JSON.
        
        Args:
            content: Dictionary containing the scraped content
            
        Returns:
            File path where content was stored
        """
        # Generate a unique filename based on title and timestamp
        title_slug = content.get("title", "untitled").lower()
        title_slug = "".join(c if c.isalnum() else "_" for c in title_slug)
        title_slug = title_slug[:50]  # Limit length
        
        timestamp = int(time.time())
        filename = f"{title_slug}_{timestamp}.json"
        filepath = os.path.join(self.raw_data_dir, filename)
        
        # Save content as JSON
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(content, f, ensure_ascii=False, indent=2)
        
        return filepath
    
    def store_embeddings(self, content_id: str, content_texts: Dict[str, List[str]], 
                         embeddings_data: Dict[str, List[List[float]]]) -> Dict[str, int]:
        """
        Store embeddings in ChromaDB.
        
        Args:
            content_id: Unique identifier for the content
            content_texts: Dictionary mapping content types to lists of text
            embeddings_data: Dictionary mapping content types to lists of embedding vectors
            
        Returns:
            Dictionary with number of embeddings stored for each content type
        """
        result = {}
        
        for content_type, texts in content_texts.items():
            if not texts or content_type not in embeddings_data:
                result[content_type] = 0
                continue
            
            embeddings = embeddings_data[content_type]
            if not embeddings:
                result[content_type] = 0
                continue
            
            # Generate unique IDs for each embedding
            ids = [f"{content_id}_{content_type}_{i}" for i in range(len(texts))]
            
            # Store in appropriate collection
            if content_type in self.collections:
                self.collections[content_type].add(
                    documents=texts,
                    embeddings=embeddings,
                    ids=ids,
                    metadatas=[{"source_id": content_id, "index": i} for i in range(len(texts))]
                )
                result[content_type] = len(texts)
        
        return result
    
    def save_content_and_embeddings(self, content: Dict[str, Any], 
                                    prepared_texts: Dict[str, List[str]],
                                    embeddings: Dict[str, List[List[float]]]) -> Dict[str, Any]:
        """
        Save both raw content and embeddings.
        
        Args:
            content: Dictionary containing the scraped content
            prepared_texts: Dictionary mapping content types to lists of text
            embeddings: Dictionary mapping content types to lists of embedding vectors
            
        Returns:
            Dictionary with storage results
        """
        # Generate a unique content ID
        content_id = str(uuid.uuid4())
        
        # Add content ID to the content
        content["content_id"] = content_id
        
        # Store raw content
        raw_filepath = self.store_raw_content(content)
        
        # Store embeddings
        embeddings_result = self.store_embeddings(content_id, prepared_texts, embeddings)
        
        return {
            "content_id": content_id,
            "raw_filepath": raw_filepath,
            "embeddings_stored": embeddings_result,
            "total_embeddings": sum(embeddings_result.values())
        }
EOF

# Create app.py
echo "Creating app.py..."
cat > app.py << 'EOF'
from fastapi import FastAPI, Request, Form, HTTPException
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, JSONResponse
from typing import Dict, List, Optional
import os
import json
import uuid
from pydantic import BaseModel

# Import our custom modules
from scraper import WebScraper
from embeddings import EmbeddingsGenerator
from storage import StorageManager

# Initialize FastAPI app
app = FastAPI(
    title="Web Scraper with Vector Storage",
    description="Scrapes web content and stores it as vectors for LLM retrieval",
    version="1.0.0"
)

# Set up static files and templates
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

# Initialize our modules
scraper = WebScraper()
embeddings_generator = EmbeddingsGenerator()
storage_manager = StorageManager()

# Define request models
class ScrapeRequest(BaseModel):
    url: str
    content_types: Dict[str, bool]

class SaveRequest(BaseModel):
    content: Dict
    content_types: Dict[str, bool]

@app.get("/", response_class=HTMLResponse)
async def get_index(request: Request):
    """Render the main index page"""
    return templates.TemplateResponse("index.html", {"request": request})

@app.post("/api/scrape")
async def scrape_url(scrape_request: ScrapeRequest):
    """
    Scrape content from the provided URL
    """
    # Validate URL
    url = scrape_request.url
    content_types = scrape_request.content_types
    
    # Call scraper
    scraped_content = await scraper.scrape(url, content_types)
    
    # Check for errors
    if "error" in scraped_content:
        return JSONResponse(
            status_code=400,
            content={"success": False, "error": scraped_content["error"]}
        )
    
    return {"success": True, "content": scraped_content}

@app.post("/api/save")
async def save_content(save_request: SaveRequest):
    """
    Save content and generate embeddings
    """
    content = save_request.content
    content_types = save_request.content_types
    
    try:
        # Prepare content for embeddings
        prepared_texts = embeddings_generator.prepare_content_for_embeddings(content)
        
        # Generate embeddings for each content type
        embeddings = {}
        for content_type, texts in prepared_texts.items():
            if texts:
                embeddings[content_type] = embeddings_generator.generate_embeddings(texts)
        
        # Save content and embeddings
        storage_result = storage_manager.save_content_and_embeddings(
            content, prepared_texts, embeddings
        )
        
        return {
            "success": True, 
            "message": "Content and embeddings saved successfully",
            "storage_info": storage_result
        }
        
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "error": f"Failed to save content: {str(e)}"
            }
        )

# Health check endpoint
@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}
EOF

# Create templates/index.html
echo "Creating templates/index.html..."
cat > templates/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Web Scraper with Vector Storage</title>
    <link rel="stylesheet" href="/static/css/styles.css">
    <script defer src="https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js"></script>
</head>
<body x-data="scraper">
    <header>
        <h1>Web Scraper with Vector Storage</h1>
    </header>
    
    <main>
        <section class="scraper-form">
            <h2>Enter URL to Scrape</h2>
            <form @submit.prevent="scrapeUrl">
                <div class="input-group">
                    <label for="url">Website URL</label>
                    <input 
                        type="url" 
                        id="url" 
                        x-model="url" 
                        placeholder="https://example.com" 
                        required
                        :disabled="isLoading"
                    >
                </div>
                
                <div class="content-options">
                    <h3>Content to Extract</h3>
                    <div class="checkbox-group">
                        <label>
                            <input type="checkbox" x-model="contentTypes.paragraphs" :disabled="isLoading">
                            <span>Paragraphs</span>
                        </label>
                        <label>
                            <input type="checkbox" x-model="contentTypes.headlines" :disabled="isLoading">
                            <span>Headlines</span>
                        </label>
                        <label>
                            <input type="checkbox" x-model="contentTypes.images" :disabled="isLoading">
                            <span>Images</span>
                        </label>
                        <label>
                            <input type="checkbox" x-model="contentTypes.tables" :disabled="isLoading">
                            <span>Tables</span>
                        </label>
                    </div>
                </div>
                
                <button type="submit" class="primary-button" :disabled="isLoading || !isFormValid">
                    <span x-show="!isLoading">Scrape</span>
                    <span x-show="isLoading">Scraping...</span>
                </button>
            </form>
        </section>
        
        <section class="status" x-show="status">
            <div :class="statusClass">
                <p x-text="status"></p>
            </div>
        </section>
        
        <section class="content-preview" x-show="hasContent">
            <h2>Content Preview</h2>
            <div class="preview-header">
                <h3 x-text="content.title"></h3>
                <p class="url"><a :href="content.url" target="_blank" x-text="content.url"></a></p>
            </div>
            
            <div class="tabs">
                <div class="tab-links">
                    <button 
                        @click="activeTab = 'paragraphs'"
                        :class="{ active: activeTab === 'paragraphs' }"
                        x-show="content.paragraphs && content.paragraphs.length > 0"
                    >
                        Paragraphs (<span x-text="content.metadata.num_paragraphs"></span>)
                    </button>
                    <button 
                        @click="activeTab = 'headlines'"
                        :class="{ active: activeTab === 'headlines' }"
                        x-show="content.headlines && content.headlines.length > 0"
                    >
                        Headlines (<span x-text="content.metadata.num_headlines"></span>)
                    </button>
                    <button 
                        @click="activeTab = 'images'"
                        :class="{ active: activeTab === 'images' }"
                        x-show="content.images && content.images.length > 0"
                    >
                        Images (<span x-text="content.metadata.num_images"></span>)
                    </button>
                    <button 
                        @click="activeTab = 'tables'"
                        :class="{ active: activeTab === 'tables' }"
                        x-show="content.tables && content.tables.length > 0"
                    >
                        Tables (<span x-text="content.metadata.num_tables"></span>)
                    </button>
                </div>
                
                <div class="tab-content">
                    <!-- Paragraphs Tab -->
                    <div x-show="activeTab === 'paragraphs' && content.paragraphs" class="tab-pane">
                        <div class="paragraphs-list">
                            <template x-for="(paragraph, index) in content.paragraphs" :key="index">
                                <div class="paragraph-item">
                                    <p x-text="paragraph"></p>
                                </div>
                            </template>
                        </div>
                    </div>
                    
                    <!-- Headlines Tab -->
                    <div x-show="activeTab === 'headlines' && content.headlines" class="tab-pane">
                        <div class="headlines-list">
                            <template x-for="(headline, index) in content.headlines" :key="index">
                                <div class="headline-item">
                                    <h4 x-text="headline"></h4>
                                </div>
                            </template>
                        </div>
                    </div>
                    
                    <!-- Images Tab -->
                    <div x-show="activeTab === 'images' && content.images" class="tab-pane">
                        <div class="images-list">
                            <template x-for="(image, index) in content.images" :key="index">
                                <div class="image-item">
                                    <div class="image-preview">
                                        <img :src="getImageSrc(image)" :alt="image.alt || 'Image'">
                                    </div>
                                    <div class="image-info">
                                        <p><strong>Alt text:</strong> <span x-text="image.alt || 'None'"></span></p>
                                        <p><strong>Source:</strong> <span x-text="image.src || 'None'"></span></p>
                                        <p><strong>Dimensions:</strong> <span x-text="getImageDimensions(image)"></span></p>
                                    </div>
                                </div>
                            </template>
                        </div>
                    </div>
                    
                    <!-- Tables Tab -->
                    <div x-show="activeTab === 'tables' && content.tables" class="tab-pane">
                        <div class="tables-list">
                            <template x-for="(table, tableIndex) in content.tables" :key="tableIndex">
                                <div class="table-item">
                                    <h4>Table <span x-text="tableIndex + 1"></span></h4>
                                    <div class="table-wrapper">
                                        <table>
                                            <thead x-show="table.headers && table.headers.length > 0">
                                                <tr>
                                                    <template x-for="(header, headerIndex) in table.headers" :key="headerIndex">
                                                        <th x-text="header"></th>
                                                    </template>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                <template x-for="(row, rowIndex) in table.rows" :key="rowIndex">
                                                    <tr>
                                                        <template x-for="(cell, cellIndex) in row" :key="cellIndex">
                                                            <td x-text="cell"></td>
                                                        </template>
                                                    </tr>
                                                </template>
                                            </tbody>
                                        </table>
                                    </div>
                                </div>
                            </template>
                        </div>
                    </div>
                </div>
            </div>
            
            <div class="actions">
                <button 
                    @click="saveContent" 
                    class="primary-button" 
                    :disabled="isSaving || !hasContent">
                    <span x-show="!isSaving">Save Content & Embeddings</span>
                    <span x-show="isSaving">Saving...</span>
                </button>
            </div>
        </section>
        
        <section class="save-results" x-show="saveResult">
            <div class="success-message">
                <h3>Content Saved Successfully!</h3>
                <div class="storage-info">
                    <p><strong>Content ID:</strong> <span x-text="saveResult.content_id"></span></p>
                    <p><strong>Raw File:</strong> <span x-text="saveResult.raw_filepath"></span></p>
                    <p><strong>Total Embeddings:</strong> <span x-text="saveResult.total_embeddings"></span></p>
                    
                    <div class="embeddings-breakdown">
                        <h4>Embeddings By Type:</h4>
                        <template x-for="(count, type) in saveResult.embeddings_stored" :key="type">
                            <p><strong x-text="type + ':'"></strong> <span x-text="count"></span></p>
                        </template>
                    </div>
                </div>
            </div>
        </section>
    </main>
    
    <footer>
        <p>Web Scraper with Vector Storage | Powered by FastAPI, Alpine.js, and ChromaDB</p>
    </footer>
    
    <script src="/static/js/app.js"></script>
</body>
</html>
EOF

# Create static/js/app.js
echo "Creating static/js/app.js..."
cat > static/js/app.js << 'EOF'
document.addEventListener('alpine:init', () => {
    Alpine.data('scraper', () => ({
        url: '',
        contentTypes: {
            paragraphs: true,
            headlines: true,
            images: false,
            tables: false
        },
        isLoading: false,
        isSaving: false,
        status: '',
        statusClass: '',
        content: null,
        activeTab: 'paragraphs',
        saveResult: null,
        
        init() {
            // Set first available tab as active
            this.$watch('content', (value) => {
                if (value) {
                    if (value.paragraphs && value.paragraphs.length > 0) {
                        this.activeTab = 'paragraphs';
                    } else if (value.headlines && value.headlines.length > 0) {
                        this.activeTab = 'headlines';
                    } else if (value.images && value.images.length > 0) {
                        this.activeTab = 'images';
                    } else if (value.tables && value.tables.length > 0) {
                        this.activeTab = 'tables';
                    }
                }
            });
        },
        
        get isFormValid() {
            // Check if URL is valid and at least one content type is selected
            const urlPattern = /^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$/;
            const validUrl = urlPattern.test(this.url);
            const hasContentType = Object.values(this.contentTypes).some(value => value);
            
            return validUrl && hasContentType;
        },
        
        get hasContent() {
            return this.content !== null;
        },
        
        async scrapeUrl() {
            this.isLoading = true;
            this.status = 'Scraping website content...';
            this.statusClass = 'status-loading';
            this.content = null;
            this.saveResult = null;
            
            try {
                const response = await fetch('/api/scrape', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        url: this.url,
                        content_types: this.contentTypes
                    })
                });
                
                const data = await response.json();
                
                if (!response.ok || !data.success) {
                    throw new Error(data.error || 'Failed to scrape website');
                }
                
                this.content = data.content;
                this.status = 'Content scraped successfully!';
                this.statusClass = 'status-success';
                
            } catch (error) {
                console.error('Scraping error:', error);
                this.status = `Error: ${error.message}`;
                this.statusClass = 'status-error';
            } finally {
                this.isLoading = false;
            }
        },
        
        async saveContent() {
            if (!this.content) return;
            
            this.isSaving = true;
            this.status = 'Generating embeddings and saving content...';
            this.statusClass = 'status-loading';
            this.saveResult = null;
            
            try {
                const response = await fetch('/api/save', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        content: this.content,
                        content_types: this.contentTypes
                    })
                });
                
                const data = await response.json();
                
                if (!response.ok || !data.success) {
                    throw new Error(data.error || 'Failed to save content');
                }
                
                this.saveResult = data.storage_info;
                this.status = data.message;
                this.statusClass = 'status-success';
                
            } catch (error) {
                console.error('Saving error:', error);
                this.status = `Error: ${error.message}`;
                this.statusClass = 'status-error';
            } finally {
                this.isSaving = false;
            }
        },
        
        // Helper functions for images
        getImageSrc(image) {
            if (!image.src) return '';
            
            // Check if the URL is absolute or relative
            if (image.src.startsWith('http://') || image.src.startsWith('https://')) {
                return image.src;
            } else if (image.src.startsWith('//')) {
                return 'https:' + image.src;
            } else if (image.src.startsWith('/')) {
                // Relative to domain root
                const url = new URL(this.content.url);
                return `${url.protocol}//${url.host}${image.src}`;
            } else {
                // Relative to current path
                const url = new URL(this.content.url);
                const path = url.pathname.substring(0, url.pathname.lastIndexOf('/') + 1);
                return `${url.protocol}//${url.host}${path}${image.src}`;
            }
        },
        
        getImageDimensions(image) {
            if (image.width && image.height) {
                return `${image.width} × ${image.height}`;
            } else {
                return 'Dimensions not specified';
            }
        }
    }));
});
EOF

# Create static/css/styles.css
echo "Creating static/css/styles.css..."
cat > static/css/styles.css << 'EOF'
/* Base Styles */
:root {
    --primary-color: #3498db;
    --secondary-color: #2c3e50;
    --accent-color: #e74c3c;
    --bg-color: #f8f9fa;
    --text-color: #333;
    --light-gray: #ddd;
    --success-color: #27ae60;
    --warning-color: #f39c12;
    --error-color: #c0392b;
}

* {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
    line-height: 1.6;
    color: var(--text-color);
    background-color: var(--bg-color);
    padding: 0;
    margin: 0;
}

h1, h2, h3, h4, h5, h6 {
    margin-bottom: 0.5rem;
    color: var(--secondary-color);
}

a {
    color: var(--primary-color);
    text-decoration: none;
}

a:hover {
    text-decoration: underline;
}

/* Layout */
header, footer {
    background-color: var(--secondary-color);
    color: white;
    text-align: center;
    padding: 1rem;
    margin-top: 2rem;
}

main {
    max-width: 1200px;
    margin: 0 auto;
    padding: 2rem;
}

section {
    margin-bottom: 2rem;
    background: white;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    padding: 1.5rem;
}

/* Forms */
.scraper-form h2 {
    margin-bottom: 1rem;
}

.input-group {
    margin-bottom: 1rem;
}

label {
    display: block;
    margin-bottom: 0.5rem;
    font-weight: 500;
}

input[type="url"], input[type="text"] {
    width: 100%;
    padding: 0.75rem;
    font-size: 1rem;
    border: 1px solid var(--light-gray);
    border-radius: 4px;
}

.content-options {
    margin: 1.5rem 0;
}

.checkbox-group {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
    gap: 0.75rem;
    margin-top: 0.5rem;
}

.checkbox-group label {
    display: flex;
    align-items: center;
    cursor: pointer;
}

.checkbox-group input[type="checkbox"] {
    margin-right: 0.5rem;
}

button {
    cursor: pointer;
    padding: 0.75rem 1.5rem;
    font-size: 1rem;
    border: none;
    border-radius: 4px;
    background-color: var(--primary-color);
    color: white;
    transition: background-color 0.2s;
}

button:hover {
    background-color: #2980b9;
}

button:disabled {
    background-color: var(--light-gray);
    cursor: not-allowed;
}

.primary-button {
    background-color: var(--primary-color);
    color: white;
    font-weight: 500;
}

/* Status Messages */
.status {
    margin: 1rem 0;
}

.status div {
    padding: 1rem;
    border-radius: 4px;
}

.status-loading {
    background-color: #eee;
    border-left: 4px solid var(--primary-color);
}

.status-success {
    background-color: #d4edda;
    border-left: 4px solid var(--success-color);
}

.status-error {
    background-color: #f8d7da;
    border-left: 4px solid var(--error-color);
}

/* Content Preview */
.preview-header {
    margin-bottom: 1.5rem;
    padding-bottom: 1rem;
    border-bottom: 1px solid var(--light-gray);
}

.url {
    color: #666;
    word-break: break-all;
}

/* Tabs */
.tabs {
    margin-top: 1.5rem;
}

.tab-links {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin-bottom: 1rem;
    border-bottom: 1px solid var(--light-gray);
    padding-bottom: 0.5rem;
}

.tab-links button {
    background: none;
    color: var(--text-color);
    border: 1px solid var(--light-gray);
    padding: 0.5rem 1rem;
}

.tab-links button.active {
    background-color: var(--primary-color);
    color: white;
    border-color: var(--primary-color);
}

.tab-content {
    padding: 1rem 0;
}

/* Content display styles */
.paragraphs-list, .headlines-list {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

.paragraph-item, .headline-item {
    padding: 0.75rem;
    background: #f9f9f9;
    border-radius: 4px;
    border-left: 3px solid var(--primary-color);
}

.images-list {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 1.5rem;
}

.image-item {
    border: 1px solid var(--light-gray);
    border-radius: 4px;
    overflow: hidden;
}

.image-preview {
    height: 200px;
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #f1f1f1;
}

.image-preview img {
    max-width: 100%;
    max-height: 100%;
    object-fit: contain;
}

.image-info {
    padding: 1rem;
    font-size: 0.9rem;
}

.tables-list {
    display: flex;
    flex-direction: column;
    gap: 2rem;
}

.table-wrapper {
    overflow-x: auto;
    margin-top: 0.5rem;
}

table {
    width: 100%;
    border-collapse: collapse;
}

th, td {
    padding: 0.75rem;
    text-align: left;
    border: 1px solid var(--light-gray);
}

th {
    background-color: #f2f2f2;
    font-weight: 600;
}

/* Save Results */
.save-results {
    background-color: #d4edda;
    border-left: 4px solid var(--success-color);
}

.success-message {
    padding: 1rem;
}

.storage-info {
    margin-top: 1rem;
    background: white;
    border-radius: 4px;
    padding: 1rem;
}

.embeddings-breakdown {
    margin-top: 1rem;
    padding-top: 1rem;
    border-top: 1px solid var(--light-gray);
}

/* Responsive adjustments */
@media (max-width: 768px) {
    main {
        padding: 1rem;
    }
    
    .checkbox-group {
        grid-template-columns: 1fr 1fr;
    }
    
    .tab-links {
        flex-direction: column;
    }
    
    .images-list {
        grid-template-columns: 1fr;
    }
}