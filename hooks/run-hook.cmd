: << 'CMDBLOCK'
@echo off
setlocal enabledelayedexpansion
REM Polyglot wrapper: runs .sh scripts cross-platform.
REM Usage: run-hook.cmd <script-name> [args...]
REM The script must sit in the same directory as this wrapper.
REM
REM Line endings MUST stay LF (pinned in .gitattributes): macOS runs this very
REM same file through /bin/sh, which fails on CR. cmd.exe reads LF-only batch
REM files correctly EXCEPT across parenthesised if/for blocks and `goto` seeks,
REM so every statement below stays on one line and nothing here uses `goto`.

if "%~1"=="" echo run-hook.cmd: missing script name 1>&2 & exit /b 1

set "HOOK_DIR=%~dp0"
set "HOOK_SCRIPT=%~1"
shift

REM Locate git-bash. Deliberately NOT `where bash.exe`: on Windows 10/11 that
REM resolves the WSL stub in System32 first, which cannot run a Windows-path
REM script and may prompt to install a distro. Set PANDAHRMS_BASH to override.
if not defined PANDAHRMS_BASH if exist "%ProgramFiles%\Git\bin\bash.exe" set "PANDAHRMS_BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined PANDAHRMS_BASH if exist "%ProgramW6432%\Git\bin\bash.exe" set "PANDAHRMS_BASH=%ProgramW6432%\Git\bin\bash.exe"
if not defined PANDAHRMS_BASH if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" set "PANDAHRMS_BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
if not defined PANDAHRMS_BASH if exist "%USERPROFILE%\scoop\apps\git\current\bin\bash.exe" set "PANDAHRMS_BASH=%USERPROFILE%\scoop\apps\git\current\bin\bash.exe"
if not defined PANDAHRMS_BASH if exist "C:\Program Files (x86)\Git\bin\bash.exe" set "PANDAHRMS_BASH=C:\Program Files (x86)\Git\bin\bash.exe"
if not defined PANDAHRMS_BASH for /f "delims=" %%G in ('where git.exe 2^>nul') do if not defined PANDAHRMS_BASH if exist "%%~dpG..\bin\bash.exe" set "PANDAHRMS_BASH=%%~dpG..\bin\bash.exe"

if not defined PANDAHRMS_BASH echo run-hook.cmd: bash.exe not found - install Git for Windows, or set PANDAHRMS_BASH to its full path 1>&2 & exit /b 1

REM Forward remaining args individually quoted. An arg containing "!" is not
REM supported (delayed expansion eats it); no hook passes one.
set "HOOK_ARGS="
if not "%~1"=="" set "HOOK_ARGS=!HOOK_ARGS! "%~1""
if not "%~2"=="" set "HOOK_ARGS=!HOOK_ARGS! "%~2""
if not "%~3"=="" set "HOOK_ARGS=!HOOK_ARGS! "%~3""
if not "%~4"=="" set "HOOK_ARGS=!HOOK_ARGS! "%~4""
if not "%~5"=="" set "HOOK_ARGS=!HOOK_ARGS! "%~5""
if not "%~6"=="" set "HOOK_ARGS=!HOOK_ARGS! "%~6""
if not "%~7"=="" set "HOOK_ARGS=!HOOK_ARGS! "%~7""
if not "%~8"=="" set "HOOK_ARGS=!HOOK_ARGS! "%~8""

REM No -l. A login shell sources /etc/profile, /etc/profile.d/* and ~/.bashrc:
REM slow on every session start, and anything they print lands on stdout ahead
REM of the hook's JSON and breaks it. git-bash's /etc/profile also cd's to $HOME
REM unless CHERE_INVOKING is set, which would corrupt the script's $PWD fallback.
"%PANDAHRMS_BASH%" "%HOOK_DIR%%HOOK_SCRIPT%"!HOOK_ARGS!
exit /b %ERRORLEVEL%
CMDBLOCK

# Unix shell runs from here
if [ -z "${1:-}" ]; then
    echo "run-hook.cmd: missing script name" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_NAME="$1"
shift
exec "${SCRIPT_DIR}/${SCRIPT_NAME}" "$@"
