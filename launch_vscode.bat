@echo off
setlocal enabledelayedexpansion

REM Check if .venv exists
if not exist ".venv\" (
    echo Creating virtual environment...
    python -m venv .venv
    if errorlevel 1 (
        echo ERROR: Failed to create virtual environment!
        pause
        exit /b 1
    )
)

REM Activate .venv
call .venv\Scripts\activate.bat

REM Upgrade pip (silent)
python -m pip install --upgrade pip --quiet >nul 2>&1

REM Install requirements if file exists (silent)
if exist "requirements.txt" (
    pip install -r requirements.txt --quiet >nul 2>&1
)

REM Create .vscode settings if not exists
if not exist ".vscode\" mkdir .vscode
if not exist ".vscode\settings.json" (
    (
        echo {
        echo     "python.defaultInterpreterPath": "${workspaceFolder}/.venv/Scripts/python.exe",
        echo     "python.terminal.activateEnvironment": true,
        echo     "terminal.integrated.defaultProfile.windows": "Command Prompt",
        echo     "files.exclude": {
        echo         "**/__pycache__": true,
        echo         "**/*.pyc": true
        echo     }
        echo }
    ) > .vscode\settings.json
)

REM Create .gitignore if not exists
if not exist ".gitignore" (
    (
        echo # Virtual Environment
        echo .venv/
        echo venv/
        echo env/
        echo.
        echo # Python
        echo __pycache__/
        echo *.py[cod]
        echo *$py.class
        echo *.so
        echo .Python
        echo.
        echo # IDE
        echo .vscode/
        echo .idea/
        echo *.swp
        echo *.swo
        echo *~
        echo.
        echo # OS
        echo .DS_Store
        echo Thumbs.db
    ) > .gitignore
)

REM Launch VS Code (without waiting)
start "" code .

REM Exit immediately (closes CMD window)
exit
