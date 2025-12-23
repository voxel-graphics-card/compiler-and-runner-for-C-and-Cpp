@echo off
setlocal enabledelayedexpansion

:: ===========================================
:: 1. DIAGNOSTIC & INITIALIZATION
:: ===========================================
set "CONFIG_FILE=build_config.ini"
set "LOG_FILE=compilation_log.txt"
set "TEMP_ERR=compiler_errors.tmp"
set "DIVIDER=------------------------------------------------------------"

where g++ >nul 2>nul
if %errorlevel% neq 0 (
    color 0C
    echo [ERROR] G++/GCC not found in PATH.
    pause & exit /b
)

:LOAD_CONFIG
set "BUILD_MODE=" & set "CPP_STD=" & set "C_STD=" & set "BUILD_DIR=" & set "PROJ_TYPE=" & set "USER_FLAGS=" & set "WARN_MODE=" & set "OPT_LEVEL="

if exist "%CONFIG_FILE%" (
    for /f "usebackq tokens=1,2 delims==" %%a in ("%CONFIG_FILE%") do (
        set "key=%%a"
        set "val=%%b"
        if "!key!"=="USER_FLAGS" (set "USER_FLAGS=!val!") else (
            for /f "tokens=1" %%g in ("!val!") do set "!key!=%%g"
        )
    )
) 

:: Safety defaults
if "!BUILD_MODE!"=="" set "BUILD_MODE=DEBUG"
if "!CPP_STD!"=="" set "CPP_STD=c++23"
if "!C_STD!"=="" set "C_STD=c17"
if "!BUILD_DIR!"=="" set "BUILD_DIR=bin"
if "!USER_FLAGS!"=="" set "USER_FLAGS= "
if "!WARN_MODE!"=="" set "WARN_MODE=ON"
if "!OPT_LEVEL!"=="" set "OPT_LEVEL=-O3"

:: RESOLVE ABSOLUTE PATH FOR OUTPUT
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
for /f "delims=" %%i in ("%BUILD_DIR%") do set "ABS_BUILD_DIR=%%~fi"

:MENU
color 07
cls
echo ===========================================
echo       C/C++ POWER BUILDER (v11.3)
echo ===========================================
echo  CUR DIR: %CD%
echo  OUT DIR: %BUILD_DIR%
echo  MODE:    %BUILD_MODE% ^| OPT: %OPT_LEVEL%
echo  STD:     %CPP_STD%^/%C_STD% ^| WARN: %WARN_MODE%
echo  FLAGS:   !USER_FLAGS!
echo -------------------------------------------
echo  1. Compile Single File       6. Generate New Template
echo  2. Compile Project (Multi)   7. Browse / Enter Folder
echo  3. Toggle DEBUG/RELEASE      8. Edit User Flags (Libs)
echo  4. Change Standards          9. CLEAN BUILD FOLDER
echo  5. Change Output Folder      10. TOGGLE WARNINGS (ON/OFF)
echo  11. VIEW BUILD LOG           12. CLEAR BUILD LOG
echo  13. TOGGLE OPTIMIZATION (!OPT_LEVEL!)
echo  0. EXIT
echo ===========================================
set /p choice="Select (0-13): "

if "%choice%"=="1" goto SINGLE
if "%choice%"=="2" goto MULTI
if "%choice%"=="3" goto TOGGLE
if "%choice%"=="4" goto STANDARDS
if "%choice%"=="5" goto SET_OUT
if "%choice%"=="6" goto TEMPLATE
if "%choice%"=="7" goto BROWSE
if "%choice%"=="8" goto SET_USER_FLAGS
if "%choice%"=="9" goto CLEAN
if "%choice%"=="10" goto TOGGLE_WARN
if "%choice%"=="11" if exist "%LOG_FILE%" (start notepad "%LOG_FILE%") else (echo No log yet. & pause) & goto MENU
if "%choice%"=="12" (del "%LOG_FILE%" 2>nul & echo Log cleared. & pause) & goto MENU
if "%choice%"=="13" goto TOGGLE_OPT
if "%choice%"=="0" echo Thanks for using my built system & echo                   ~Debargha Bose & TIMEOUT /T 3 /NOBREAK>nul & exit ::bruh ts a'int unix 
goto MENU

:TOGGLE_OPT
if "!OPT_LEVEL!"=="-O0" (set "OPT_LEVEL=-O1") else (
    if "!OPT_LEVEL!"=="-O1" (set "OPT_LEVEL=-O2") else (
        if "!OPT_LEVEL!"=="-O2" (set "OPT_LEVEL=-O3") else (
            set "OPT_LEVEL=-O0"
        )
    )
)
call :SAVE_CONFIG & goto MENU

:MULTI
set /p ptype="[1] C  [2] C++: "
set /p outname="EXE Name: "
call :SET_FLAGS

if "%ptype%"=="1" (set "comp=gcc" & set "std_f=-std=%C_STD%" & set "target_ext=*.c") else (set "comp=g++" & set "std_f=-std=%CPP_STD%" & set "target_ext=*.cpp")

set "file_list="
set "inc_list=-I. -Iinclude -Isrc"

if not exist "src" (color 0C & echo [ERROR] 'src' folder missing. & pause & goto MENU)

echo [SEARCH] Scanning 'src'...
pushd "src"
for /r %%f in (!target_ext!) do (
    set "file_list=!file_list! "%%~ff""
    set "inc_path=%%~dpf"
    if "!inc_path:~-1!"=="\" set "inc_path=!inc_path:~0,-1!"
    echo !inc_list! | findstr /C:"-I"!inc_path!"" >nul
    if errorlevel 1 set "inc_list=!inc_list! -I"!inc_path!""
)
popd

if "!file_list!"=="" (color 0C & echo [ERROR] No files found. & pause & goto MENU)

set "outfile=!ABS_BUILD_DIR!\!outname!.exe"
:: Added -Llib here
set "cmd=!comp! %BASE_FLAGS% %OPT_LEVEL% !std_f! !inc_list! !file_list! -Llib -o "!outfile!" !USER_FLAGS!"

echo [CMD] Compiling...
!cmd! 2> "%TEMP_ERR%"
call :FINISH %errorlevel% "!outname!" "!cmd!"

if %errorlevel% equ 0 (
    set /p args="Arguments: "
    echo. & echo --- PROGRAM OUTPUT ---
    "!outfile!" !args!
    echo.
)
pause & goto MENU

:SINGLE
set /p source="File Path: "
if not exist "!source!" (echo [!] Not found. & pause & goto MENU)
for %%f in ("!source!") do set "fname=%%~nf" & set "fext=%%~xf"
call :SET_FLAGS
if /I "!fext!"==".c" (set "comp=gcc" & set "ops=%FCFLAGS%") else (set "comp=g++" & set "ops=%FCPPFLAGS%")
set "outfile=!ABS_BUILD_DIR!\!fname!.exe"
:: Added -Llib here
set "cmd=!comp! %ops% "!source!" -Llib -o "!outfile!" !USER_FLAGS!"
echo [CMD] !cmd!
!cmd! 2> "%TEMP_ERR%"
call :FINISH %errorlevel% "!fname!" "!cmd!"
if %errorlevel% equ 0 (
    set /p args="Arguments: "
    echo. & echo --- PROGRAM OUTPUT ---
    "!outfile!" !args!
    echo.
)
pause & goto MENU

:SET_FLAGS
if "%WARN_MODE%"=="ON" (set "BASE_FLAGS=-Wall -Wextra") else (set "BASE_FLAGS=-w")
if "%BUILD_MODE%"=="DEBUG" (set "BASE_FLAGS=%BASE_FLAGS% -g") else (set "BASE_FLAGS=%BASE_FLAGS% -s")
set "FCFLAGS=%BASE_FLAGS% %OPT_LEVEL% -std=%C_STD%"
set "FCPPFLAGS=%BASE_FLAGS% %OPT_LEVEL% -std=%CPP_STD%"
exit /b

:FINISH
type "%TEMP_ERR%"
if %1 equ 0 (set "STAT=SUCCESS" & color 0A) else (set "STAT=FAILED " & color 0C)
(
    echo %DIVIDER%
    echo TIMESTAMP: [%DATE% %TIME%]
    echo TARGET:    %~2 ^| OPT: %OPT_LEVEL%
    echo RESULT:    !STAT!
    echo MODE:      %BUILD_MODE% ^| STD: %CPP_STD%/%C_STD%
    echo COMMAND:   %~3
    if %1 neq 0 (echo. & echo ERROR LOG: & type "%TEMP_ERR%")
    echo %DIVIDER%
    echo.
) >> "%LOG_FILE%"
rundll32 user32.dll,MessageBeep
if exist "%TEMP_ERR%" del "%TEMP_ERR%"
exit /b

:SAVE_CONFIG
(echo BUILD_MODE=%BUILD_MODE% & echo CPP_STD=%CPP_STD% & echo C_STD=%C_STD% & echo BUILD_DIR=%BUILD_DIR% & echo USER_FLAGS=%USER_FLAGS% & echo WARN_MODE=%WARN_MODE% & echo OPT_LEVEL=%OPT_LEVEL%) > "%CONFIG_FILE%"
exit /b

:TOGGLE_WARN
if "%WARN_MODE%"=="ON" (set "WARN_MODE=OFF") else (set "WARN_MODE=ON")
call :SAVE_CONFIG & goto MENU

:CLEAN
if exist "!ABS_BUILD_DIR!" rd /s /q "!ABS_BUILD_DIR!"
mkdir "!ABS_BUILD_DIR!"
echo Done. & pause & goto MENU

:TOGGLE
if "%BUILD_MODE%"=="DEBUG" (set "BUILD_MODE=RELEASE") else (set "BUILD_MODE=DEBUG")
call :SAVE_CONFIG & goto MENU

:STANDARDS
echo [1] C++ (%CPP_STD%)  [2] C (%C_STD%)
set /p stype="> "
if "%stype%"=="1" (
    echo [1] c++11 [2] c++17 [3] c++20 [4] c++23
    set /p sc="Select: "
    if "!sc!"=="1" set "CPP_STD=c++11"
    if "!sc!"=="2" set "CPP_STD=c++17"
    if "!sc!"=="3" set "CPP_STD=c++20"
    if "!sc!"=="4" set "CPP_STD=c++23"
) else (
    echo [1] c89 [2] c99 [3] c11 [4] c17 [5] c23
    set /p sc="Select: "
    if "!sc!"=="1" set "C_STD=c89"
    if "!sc!"=="2" set "C_STD=c99"
    if "!sc!"=="3" set "C_STD=c11"
    if "!sc!"=="4" set "C_STD=c17"
    if "!sc!"=="5" set "C_STD=c23"
)
call :SAVE_CONFIG & goto MENU

:SET_OUT
set /p input="Folder: "
for /f "tokens=1" %%a in ("%input%") do set "BUILD_DIR=%%a"
call :SAVE_CONFIG & goto LOAD_CONFIG

:SET_USER_FLAGS
set /p USER_FLAGS="Enter Flags: "
call :SAVE_CONFIG & goto MENU

:TEMPLATE
set /p projname="Name: "kp
mkdir "%projname%" & mkdir "%projname%\src" & mkdir "%projname%\include" & mkdir "%projname%\bin" & mkdir "%projname%\lib"
(echo BUILD_MODE=DEBUG & echo CPP_STD=%CPP_STD% & echo C_STD=%C_STD% & echo BUILD_DIR=bin & echo USER_FLAGS= & echo WARN_MODE=ON & echo OPT_LEVEL=-O3) > "%projname%\%CONFIG_FILE%"
echo #include ^<iostream^> > "%projname%\src\main.cpp"
echo int main(){ std::cout ^<^< "Ready\n"; return 0; } >> "%projname%\src\main.cpp"
echo [SUCCESS] Folder "%projname%" created.
cd /d "%projname%"
goto LOAD_CONFIG

:BROWSE
dir /ad /b
set /p target="Folder: "
if defined target (cd /d "%target%" & goto LOAD_CONFIG)
goto MENU