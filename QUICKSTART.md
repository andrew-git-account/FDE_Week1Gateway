# Quick Start Guide - FNOL Agent Development

Get the FNOL Claims Processing Agent running in 15 minutes.

## Prerequisites Checklist

- [ ] Python 3.11+ installed (`python --version`)
- [ ] MySQL 8.0+ installed and running
- [ ] Git installed
- [ ] OpenAI API key (or plan to use mock NLP)

## Step-by-Step Setup

### 1. Create Python Virtual Environment

```bash
# Navigate to project directory
cd C:\Users\Andrzej_Bihun\Projects\FDE_Week1Gateway

# Create virtual environment
python -m venv venv

# Activate it
# Windows (Command Prompt):
venv\Scripts\activate.bat

# Windows (PowerShell):
venv\Scripts\Activate.ps1

# Windows (Git Bash):
source venv/Scripts/activate

# Verify activation (should show (venv) prefix in prompt)
```

### 2. Install Python Dependencies

```bash
pip install --upgrade pip
pip install -r requirements.txt

# This will take 2-3 minutes
# You should see packages like fastapi, sqlalchemy, pymysql, openai installing
```

### 3. Setup MySQL Database

```bash
# Option A: Command line MySQL
mysql -u root -p
# Enter your MySQL root password

# Then run these commands:
```

```sql
CREATE DATABASE fnol_claims CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'fnol_user'@'localhost' IDENTIFIED BY 'fnol_password_123';
GRANT ALL PRIVILEGES ON fnol_claims.* TO 'fnol_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

```bash
# Option B: Using the schema file directly
mysql -u root -p < database_schema.sql
```

### 4. Create .env Configuration File

```bash
# Copy the template
cp .env.example .env

# Edit .env with your favorite text editor
# At minimum, update these lines:
```

Open `.env` and set:
```bash
DB_PASSWORD=fnol_password_123

# If using real OpenAI for NLP extraction:
OPENAI_API_KEY=sk-your-key-here

# OR use mock NLP (no API key needed):
NLP_PROVIDER=mock
ENABLE_MOCK_INTEGRATIONS=true
```

### 5. Verify Database Setup

```bash
# Test connection
mysql -u fnol_user -p fnol_claims
# Password: fnol_password_123

# Should connect successfully
# Check tables exist:
SHOW TABLES;

# Should see: adjusters, audit_log, claimants, claims, extraction_results, policies, severity_overrides
EXIT;
```

### 6. Start the Agent Service

```bash
# Navigate to src directory
cd src

# Run with auto-reload (development mode)
python main.py

# You should see:
# INFO:     Uvicorn running on http://0.0.0.0:8000
# INFO:     Application startup complete.
```

### 7. Test the API

**Open a new terminal/browser:**

```bash
# Health check
curl http://localhost:8000/health

# Should return:
# {"status":"healthy","environment":"development","mock_integrations":true}
```

**Or open browser:** `http://localhost:8000/docs`

You should see Swagger UI with API documentation.

---

## What You Just Built

✅ **FastAPI web server** running on port 8000  
✅ **MySQL database** with schema for claims, policies, adjusters  
✅ **Configuration system** loading from .env  
✅ **Health check endpoint** at /health  
✅ **API documentation** at /docs  

---

## Next Steps for Development

### Using Claude Code to Build Features

The specification documents in `Specification/` contain all the requirements.

**Approach 1: Ask Claude Code to Build a Service**

```
Open Claude Code chat and say:

"Read the agent specification in Specification/03_Agent_specification.md,
specifically the Extraction Service section (Step 1: Data Extraction).

Build the extraction service in src/services/extraction_service.py that:
1. Takes unstructured FNOL text as input
2. Uses NLP (OpenAI GPT-4) to extract structured fields
3. Returns ExtractionResult with confidence scores
4. Handles mock mode (ENABLE_MOCK_INTEGRATIONS=true)

Use the database model from database_schema.sql (extraction_results table).
Follow the extraction logic from the spec."
```

**Approach 2: Build Incrementally**

Start with smallest vertical slice:

1. **Week 1**: Extraction service + triage service (no integrations)
   - Input: Raw FNOL text
   - Output: Severity classification
   - Tests: Unit tests for extraction and triage logic

2. **Week 2**: Add database persistence
   - Save claims to MySQL
   - Save extraction_results
   - Add audit_log entries

3. **Week 3**: Add mock integrations
   - Mock CRM API (claims ingestion)
   - Mock Policy SOAP (validation)
   - Mock Notification service (acknowledgment)

4. **Week 4**: Add real integrations (when you have credentials)

### Project Structure You'll Build

```
src/
├── main.py                 ✅ Done (FastAPI app)
├── config.py              ✅ Done (settings from .env)
├── models/                📝 Next: SQLAlchemy models
│   ├── claim.py
│   ├── claimant.py
│   ├── policy.py
│   └── adjuster.py
├── services/              📝 Next: Business logic
│   ├── extraction_service.py
│   ├── triage_service.py
│   ├── validation_service.py
│   ├── routing_service.py
│   └── notification_service.py
├── integrations/          📝 Later: External APIs
│   ├── crm_client.py
│   ├── policy_soap_client.py
│   └── notification_client.py
└── api/                   📝 Later: API routes
    └── claims.py
```

### Testing Your Work

```bash
# Create a test file
# tests/unit/test_extraction.py

import pytest
from src.services.extraction_service import ExtractionService

def test_extract_from_structured_web_form():
    service = ExtractionService()
    result = service.extract(
        raw_text="Policy: POL-12345678, Windshield crack, $450",
        source_channel="WEB_FORM"
    )
    assert result.policy_number == "POL-12345678"
    assert result.estimated_value == 450
    assert result.confidence >= 0.9

# Run test
pytest tests/unit/test_extraction.py -v
```

---

## Troubleshooting

### Python venv activation not working on Windows PowerShell

**Error:** "cannot be loaded because running scripts is disabled"

**Fix:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Then try activating again: `venv\Scripts\Activate.ps1`

### MySQL Connection Refused

**Error:** "Can't connect to MySQL server on 'localhost'"

**Fix:**
```bash
# Check if MySQL is running
# Windows: Open Services, look for MySQL80, start it
# Or from command line:
net start MySQL80
```

### Port 8000 Already in Use

**Error:** "Address already in use"

**Fix:**
```bash
# Windows: Find what's using port 8000
netstat -ano | findstr :8000

# Kill the process (replace PID with actual process ID)
taskkill /PID <PID> /F

# Or use a different port
uvicorn main:app --port 8001
```

### Module Not Found Error

**Error:** "ModuleNotFoundError: No module named 'fastapi'"

**Fix:**
```bash
# Make sure venv is activated (you should see (venv) in prompt)
# Re-install dependencies
pip install -r requirements.txt
```

### OpenAI API Key Invalid

**Error:** "Invalid API key"

**Fix:**
```bash
# Option 1: Use mock NLP (no API key needed)
# In .env, set:
NLP_PROVIDER=mock

# Option 2: Get valid OpenAI API key from https://platform.openai.com/api-keys
# Update .env with real key
```

---

## Development Workflow

### Daily Workflow

```bash
# 1. Activate venv
source venv/Scripts/activate  # or venv\Scripts\activate.bat

# 2. Pull latest changes
git pull origin main

# 3. Start dev server
cd src
python main.py

# 4. In another terminal, run tests while developing
pytest --watch

# 5. Before committing
black src/  # Format code
flake8 src/  # Lint
pytest  # Run all tests

# 6. Commit and push
git add .
git commit -m "Add extraction service"
git push origin main
```

### Using Claude Code Effectively

**Good prompts:**
- "Implement the severity triage logic from Specification/03_Agent_specification.md, Decision 2: Severity Classification. Create src/services/triage_service.py with a TrigageService class."
- "Write unit tests for triage_service.py covering LOW, MEDIUM, HIGH, and boundary cases ($4999, $5000, $5001)."
- "Create SQLAlchemy model for Claim entity based on database_schema.sql claims table."

**Less effective prompts:**
- "Make it better" (too vague)
- "Add AI" (already in the spec, be specific)
- "Fix the bug" (describe what's wrong)

---

## Resources

- **API Docs:** http://localhost:8000/docs (once server is running)
- **Specifications:** `Specification/` directory
- **Database Schema:** `database_schema.sql`
- **Configuration:** `.env` (your secrets) and `src/config.py` (loader)

---

## Success Criteria

You're ready to develop when:
- [x] Virtual environment activated
- [x] Dependencies installed (no errors)
- [x] MySQL running with fnol_claims database
- [x] Server starts successfully on port 8000
- [x] Health check returns {"status": "healthy"}
- [x] API docs accessible at /docs

**Next:** Start building services! Begin with extraction_service.py.
