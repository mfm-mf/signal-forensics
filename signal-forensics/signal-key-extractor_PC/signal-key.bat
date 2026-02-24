@echo off
setlocal EnableDelayedExpansion

set OUTPUT_DIR=output
set OUTPUT_FILE=%OUTPUT_DIR%\signal-keychain.txt

mkdir "%OUTPUT_DIR%" 2>nul

:: Check if Node.js is available; install if not
where node >nul 2>&1
if errorlevel 1 (
    echo Node.js not found. Installing via winget...
    winget install OpenJS.NodeJS --scope user --silent --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo ERROR: winget failed to install Node.js.
        exit /b 1
    )

    echo Node.js installed. Relaunching script...
    cmd /c "%~f0"
    exit /b
) else (
    echo Node.js found:
    node --version
)

:: Install dependencies
echo Installing dependencies...
call npm install
if errorlevel 1 (
    echo ERROR: npm install failed.
    exit /b 1
)

:: Build
echo Building...
call npm run build
if errorlevel 1 (
    echo ERROR: Build failed.
    exit /b 1
)

:: Run
echo Running...
call npm start -- -o "%OUTPUT_FILE%"
if errorlevel 1 (
    echo ERROR: npm start failed.
    exit /b 1
)

:: Verify output was actually created
if not exist "%OUTPUT_FILE%" (
    echo ERROR: Process completed but output file was not created: %OUTPUT_FILE%
    exit /b 1
)

echo.
echo Key successfully extracted to: %OUTPUT_FILE%
exit /b 0