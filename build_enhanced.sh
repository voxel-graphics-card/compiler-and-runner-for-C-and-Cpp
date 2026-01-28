#!/bin/bash

# ===========================================
# C/C++ POWER BUILDER v5.0
# Comprehensive Build System with Incremental Compilation
# Features: Multi-compiler, Animations, LTO, Sanitizers
# ===========================================

# Quick help
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    cat << 'HELP'
C/C++ Power Builder v5.0
=========================

Interactive build system for C/C++ projects with advanced features.

USAGE:
    ./build.sh              Run interactive menu
    ./build.sh --help       Show this help
    ./build.sh --version    Show version

FEATURES:
    • Single file and project compilation
    • Incremental builds (10-100x faster rebuilds)
    • Multi-compiler support (GCC/Clang)
    • Multiple C/C++ standards
    • LTO, sanitizers, optimizations
    • 12 loading animations
    • Compile time tracking
    • Quick rebuild function

REQUIREMENTS:
    • gcc/g++ (or clang/clang++)
    • Standard Unix tools (find, du, tput)
    • Optional: bc (for precise timing)

For more info, run the script and explore the menu!
HELP
    exit 0
fi

if [[ "$1" == "--version" || "$1" == "-v" ]]; then
    echo "C/C++ Power Builder v5.0"
    exit 0
fi

# ===========================================
# SETUP & STYLES (tput)
# ===========================================
CONFIG_FILE="build_config.ini"
LOG_FILE="compilation_log.txt"
TEMP_ERR="compiler_errors.tmp"

# Initialize tput styles
R=$(tput setaf 1) G=$(tput setaf 2) Y=$(tput setaf 3) B=$(tput setaf 4)
M=$(tput setaf 5) C=$(tput setaf 6) N=$(tput sgr0) BOLD=$(tput bold)
UNDERLINE=$(tput smul)

# Tool check - make bc optional for timing
HAS_BC=false
command -v bc &> /dev/null && HAS_BC=true

for tool in g++ gcc find du tput; do
    command -v "$tool" &> /dev/null || { echo "${R}[FATAL] $tool missing.${N}"; exit 1; }
done

# Trap Ctrl+C
trap cleanup SIGINT SIGTERM
cleanup() {
    BLA::stop_loading_animation
    echo -e "\n${Y}[!] Exit detected. Cleaning up...${N}"
    rm -f "$TEMP_ERR"
    tput cnorm
    exit 1
}

# ===========================================
# BASH LOADING ANIMATIONS (BLA) ENGINE
# ===========================================
# ASCII & UTF-8 Frames
declare -a BLA_classic=( 0.25 '-' "\\" '|' '/' )
declare -a BLA_snake=( 0.4 '[=      ]' '[~<     ]' '[~~=    ]' '[~~~<   ]' '[ ~~~= ]' '[  ~~~<]' '[   ~~~]' '[    ~~]' '[     ~]' '[      ]' )
declare -a BLA_earth=( 0.45 🌎 🌍 🌏 )
declare -a BLA_moon=( 0.8 🌑 🌒 🌓 🌔 🌕 🌖 🌗 🌘 )
declare -a BLA_clock=( 0.2 🕛 🕐 🕑 🕒 🕓 🕔 🕕 🕖 🕗 🕘 🕙 🕚 )
declare -a BLA_braille=( 0.2 ⠁ ⠂ ⠄ ⡀ ⢀ ⠠ ⠐ ⠈ )
declare -a BLA_dots=( 0.25 '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
declare -a BLA_box=( 0.2 '◰' '◳' '◲' '◱' )

# --- NEW ANIMATIONS ADDED HERE ---
declare -a BLA_monkey=( 0.4 '🙈' '🙉' '🙊' '🙉' )
declare -a BLA_pong=( 0.2 '▐⠂       ▌' '▐⠈       ▌' '▐ ⠂      ▌' '▐ ⠠      ▌' '▐  ⡀     ▌' '▐  ⠠     ▌' '▐   ⠂    ▌' '▐   ⠈    ▌' '▐    ⠂   ▌' '▐    ⠠   ▌' '▐     ⡀  ▌' '▐     ⠠  ▌' '▐      ⠂ ▌' '▐      ⠈ ▌' '▐       ⠂▌' '▐       ⠠▌' '▐       ⡀▌' '▐       ⠠▌' '▐       ⠂▌' '▐      ⠈ ▌' '▐      ⠂ ▌' '▐     ⠠  ▌' '▐     ⡀  ▌' '▐    ⠠   ▌' '▐    ⠂   ▌' '▐   ⠈    ▌' '▐   ⠂    ▌' '▐  ⠠     ▌' '▐  ⡀     ▌' '▐ ⠠      ▌' )
declare -a BLA_metro=( 0.2 '[    ]' '[=   ]' '[==  ]' '[=== ]' '[ ===]' '[  ==]' '[   =]' '[    ]' )
declare -a BLA_breathe=( 0.6 '  ()  ' ' (  ) ' '(    )' ' (  ) ' )

BLA_loading_animation_pid=""

BLA::play_loading_animation_loop() {
    while true ; do
        for frame in "${BLA_active_loading_animation[@]}" ; do
            printf "\r${C}%s${N} Compiling... " "${frame}"
            sleep "${BLA_loading_animation_frame_interval}"
        done
    done
}

BLA::start_loading_animation() {
    BLA_active_loading_animation=( "${@}" )
    BLA_loading_animation_frame_interval="${BLA_active_loading_animation[0]}"
    unset "BLA_active_loading_animation[0]"
    tput civis 2>/dev/null
    BLA::play_loading_animation_loop &
    BLA_loading_animation_pid="${!}"
}

BLA::stop_loading_animation() {
    if [[ -n "$BLA_loading_animation_pid" ]] && kill -0 "$BLA_loading_animation_pid" 2>/dev/null; then
        kill "$BLA_loading_animation_pid" &> /dev/null
        wait "$BLA_loading_animation_pid" 2>/dev/null
    fi
    printf "\r\033[K"
    tput cnorm 2>/dev/null
    BLA_loading_animation_pid=""
}

# ===========================================
# CONFIGURATION MANAGEMENT
# ===========================================
load_config() {
    BUILD_MODE="DEBUG"; CPP_STD="c++23"; C_STD="c17"
    BUILD_DIR="bin"; USER_FLAGS=""; WARN_MODE="ON"
    OPT_LEVEL="-O3"; LAST_BIN=""; ANIM_STYLE="BLA_classic"
    PARALLEL_JOBS="4"; LTO_ENABLED="OFF"; SANITIZER="NONE"
    LAST_SOURCE=""; LAST_COMP_TYPE=""; COMPILER="GCC"
    INCREMENTAL="ON"

    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS='=' read -r key val; do
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            val=$(echo "$val" | tr -d '\r' | xargs)
            case "$key" in
                BUILD_MODE) BUILD_MODE="$val" ;;
                CPP_STD)    CPP_STD="$val" ;;
                C_STD)      C_STD="$val" ;;
                BUILD_DIR)  BUILD_DIR="$val" ;;
                USER_FLAGS) USER_FLAGS="$val" ;;
                WARN_MODE)  WARN_MODE="$val" ;;
                OPT_LEVEL)  OPT_LEVEL="$val" ;;
                LAST_BIN)   LAST_BIN="$val" ;;
                ANIM_STYLE) ANIM_STYLE="$val" ;;
                PARALLEL_JOBS) PARALLEL_JOBS="$val" ;;
                LTO_ENABLED) LTO_ENABLED="$val" ;;
                SANITIZER) SANITIZER="$val" ;;
                LAST_SOURCE) LAST_SOURCE="$val" ;;
                LAST_COMP_TYPE) LAST_COMP_TYPE="$val" ;;
                COMPILER) COMPILER="$val" ;;
                INCREMENTAL) INCREMENTAL="$val" ;;
            esac
        done < "$CONFIG_FILE"
    fi

    if ! mkdir -p "$BUILD_DIR" 2>/dev/null; then
        echo "${R}[ERROR] Cannot create build directory: $BUILD_DIR${N}"
        BUILD_DIR="bin"
        mkdir -p "$BUILD_DIR" 2>/dev/null || { echo "${R}[FATAL] Cannot create bin directory${N}"; exit 1; }
    fi

    ABS_BUILD_DIR="$(cd "$BUILD_DIR" && pwd)" || {
        echo "${R}[ERROR] Cannot access build directory${N}"
        exit 1
    }
}

save_config() {
    cat <<EOF > "$CONFIG_FILE"
BUILD_MODE=$BUILD_MODE
CPP_STD=$CPP_STD
C_STD=$C_STD
BUILD_DIR=$BUILD_DIR
USER_FLAGS=$USER_FLAGS
WARN_MODE=$WARN_MODE
OPT_LEVEL=$OPT_LEVEL
LAST_BIN=$LAST_BIN
ANIM_STYLE=$ANIM_STYLE
PARALLEL_JOBS=$PARALLEL_JOBS
LTO_ENABLED=$LTO_ENABLED
SANITIZER=$SANITIZER
LAST_SOURCE=$LAST_SOURCE
LAST_COMP_TYPE=$LAST_COMP_TYPE
COMPILER=$COMPILER
INCREMENTAL=$INCREMENTAL
EOF
}

# ===========================================
# LOGGING & EXECUTION ENGINE
# ===========================================
# Safe time calculation with bc fallback
calculate_time() {
    local start=$1
    local end=$2
    if $HAS_BC; then
        echo "$end - $start" | bc 2>/dev/null || echo "0.0"
    else
        # Fallback: simple integer seconds
        printf "%.0f" "$((${end%.*} - ${start%.*}))" 2>/dev/null || echo "0"
    fi
}

# Safe time addition
add_time() {
    local total=$1
    local add=$2
    if $HAS_BC; then
        echo "$total + $add" | bc 2>/dev/null || echo "$total"
    else
        # FALLBACK: integer addition
        echo "$((${total%.*} + ${add%.*}))" 2>/dev/null || echo "$total"
    fi
}

log_verbose() {
    local status=$1; local target=$2; local cmd_str=$3; local compile_time=$4
    local res="FAILED"; [[ $status -eq 0 ]] && res="SUCCESS"
    {
        echo "============================================================"
        echo "SESSION : $(date '+%Y-%m-%d %H:%M:%S') | RESULT: $res"
        echo "TARGET  : $target"
        echo "TIME    : ${compile_time}s"
        echo "COMMAND : $cmd_str"
        [[ -s "$TEMP_ERR" ]] && { echo "--- COMPILER OUTPUT ---"; cat "$TEMP_ERR"; }
        echo "============================================================"
    } >> "$LOG_FILE"
    if [[ $status -eq 0 ]]; then
        local size=$(du -h "$target" 2>/dev/null | cut -f1)
        echo "${G}[SUCCESS]${N} Binary: $target (${size:-?}) ${C}[${compile_time}s]${N}"
    else
        echo "${R}[FAILED]${N} See $LOG_FILE for details ${C}[${compile_time}s]${N}"
        [[ -s "$TEMP_ERR" ]] && head -20 "$TEMP_ERR"
    fi
    rm -f "$TEMP_ERR"
    return $status
}

run_program() {
    if [[ -f "$1" && -x "$1" ]]; then
        echo "${G}[RUNNING]${N} $(basename "$1")"
        read -e -r -p "Arguments: " r_args
        echo "${Y}--- OUTPUT START ---${N}"
        "$1" $r_args
        local exit_code=$?
        echo -e "${Y}--- OUTPUT END (exit code: $exit_code) ---${N}"
        read -p "Press Enter to return..."
    else
        echo "${R}[!] Binary not found or not executable: $1${N}"
        sleep 1
    fi
}

# ===========================================
# ENHANCED BUILD FLAGS
# ===========================================
get_compiler_names() {
    local lang=$1  # "c" or "cpp"
    if [[ "$COMPILER" == "CLANG" ]]; then
        [[ "$lang" == "c" ]] && echo "clang" || echo "clang++"
    else
        [[ "$lang" == "c" ]] && echo "gcc" || echo "g++"
    fi
}

get_compiler_flags() {
    local flags=()

    # Warning flags (FIXED: Actually respect WARN_MODE)
    if [[ "$WARN_MODE" == "ON" ]]; then
        flags+=("-Wall" "-Wextra" "-Wpedantic")
    else
        flags+=("-w")  # Suppress all warnings
    fi

    # Optimization
    flags+=("$OPT_LEVEL")

    # LTO (Link-Time Optimization)
    [[ "$LTO_ENABLED" == "ON" ]] && flags+=("-flto")

    # Sanitizers
    case "$SANITIZER" in
        ADDRESS) flags+=("-fsanitize=address" "-fno-omit-frame-pointer") ;;
        THREAD)  flags+=("-fsanitize=thread") ;;
        UB)      flags+=("-fsanitize=undefined") ;;
        MEMORY)  flags+=("-fsanitize=memory") ;;
    esac

    # Build mode
    if [[ "$BUILD_MODE" == "DEBUG" ]]; then
        flags+=("-g" "-DDEBUG")
    else
        flags+=("-s" "-DNDEBUG")
    fi

    echo "${flags[@]}"
}

# ===========================================
# BUILD ACTIONS
# ===========================================
build_single_file() {
    read -e -r -p "File Path: " source

    # Input validation
    if [[ -z "$source" ]]; then
        echo "${Y}[!] No file specified.${N}"; sleep 1; return
    fi
    if [[ ! -f "$source" ]]; then
        echo "${R}[!] File not found: $source${N}"; sleep 1; return
    fi

    local ext="${source##*.}"
    local comp=$(get_compiler_names "cpp")
    local std="-std=$CPP_STD"

    [[ "$ext" == "c" ]] && { comp=$(get_compiler_names "c"); std="-std=$C_STD"; }

    local outfile="$ABS_BUILD_DIR/$(basename "${source%.*}")"

    # Build flags array
    local flags=()
    flags+=($(get_compiler_flags))
    flags+=("$std" "$source" "-Llib" "-o" "$outfile")
    flags+=("-Iinclude" "-Isrc")

    # Add user flags
    [[ -n "$USER_FLAGS" ]] && read -ra U_FLAGS <<< "$USER_FLAGS" && flags+=("${U_FLAGS[@]}")

    # Compilation with animation
    local anim_cmd="${ANIM_STYLE}[@]"
    BLA::start_loading_animation "${!anim_cmd}"
    local start_time=$(date +%s.%N)
    "$comp" "${flags[@]}" 2> "$TEMP_ERR"
    local status=$?
    local end_time=$(date +%s.%N)
    BLA::stop_loading_animation
    local compile_time=$(calculate_time "$start_time" "$end_time")

    if log_verbose $status "$outfile" "$comp ${flags[*]}" "$compile_time"; then
        LAST_BIN="$outfile"
        LAST_SOURCE="$source"
        LAST_COMP_TYPE="file"
        save_config
        read -p "${G}Run now? [Y/n]:${N} " run_choice
        [[ "$run_choice" != "n" && "$run_choice" != "N" ]] && run_program "$outfile"
    fi
}

build_project() {
    read -p "[1] C [2] C++: " ptype
    local comp=$(get_compiler_names "cpp")
    local std="-std=$CPP_STD"
    local ext="cpp"

    [[ "$ptype" == "1" ]] && { comp=$(get_compiler_names "c"); std="-std=$C_STD"; ext="c"; }

    read -e -r -p "Binary Name: " outname
    [[ -z "$outname" ]] && { echo "${Y}[!] No name provided.${N}"; sleep 1; return; }

    if [[ ! -d "src" ]]; then
        echo "${R}[!] /src directory missing.${N}"
        sleep 1
        return
    fi

    mapfile -t src_files < <(find src -name "*.$ext")

    if [[ ${#src_files[@]} -eq 0 ]]; then
        echo "${R}[!] No .$ext files found in src/${N}"
        sleep 1
        return
    fi

    echo "${C}Found ${#src_files[@]} source files${N}"

    local outfile="$ABS_BUILD_DIR/$outname"

    # Check if incremental compilation is enabled
    if [[ "$INCREMENTAL" == "ON" ]]; then
        build_project_incremental "$comp" "$std" "$ext" "$outfile" "$outname"
    else
        build_project_full "$comp" "$std" "$ext" "$outfile" "$outname"
    fi
}

# Full rebuild (original method)
build_project_full() {
    local comp=$1; local std=$2; local ext=$3; local outfile=$4; local outname=$5

    mapfile -t src_files < <(find src -name "*.$ext")

    # Build flags
    local flags=()
    flags+=($(get_compiler_flags))
    flags+=("$std" "${src_files[@]}" "-Llib" "-o" "$outfile")
    flags+=("-Iinclude" "-Isrc")

    # Add user flags
    [[ -n "$USER_FLAGS" ]] && read -ra U_FLAGS <<< "$USER_FLAGS" && flags+=("${U_FLAGS[@]}")

    # Compilation with animation
    local anim_cmd="${ANIM_STYLE}[@]"
    BLA::start_loading_animation "${!anim_cmd}"
    local start_time=$(date +%s.%N)
    "$comp" "${flags[@]}" 2> "$TEMP_ERR"
    local status=$?
    local end_time=$(date +%s.%N)
    BLA::stop_loading_animation
    local compile_time=$(calculate_time "$start_time" "$end_time")

    if log_verbose $status "$outfile" "Project: $outname" "$compile_time"; then
        LAST_BIN="$outfile"
        LAST_SOURCE="$outname"
        LAST_COMP_TYPE="project"
        save_config
        read -p "${G}Run now? [Y/n]:${N} " run_choice
        [[ "$run_choice" != "n" && "$run_choice" != "N" ]] && run_program "$outfile"
    fi
}

# Incremental compilation with object files
build_project_incremental() {
    local comp=$1; local std=$2; local ext=$3; local outfile=$4; local outname=$5

    # Create obj directory for object files
    local obj_dir="$ABS_BUILD_DIR/obj"
    if ! mkdir -p "$obj_dir" 2>/dev/null; then
        echo "${R}[ERROR] Cannot create object directory. Falling back to full build.${N}"
        sleep 1
        build_project_full "$comp" "$std" "$ext" "$outfile" "$outname"
        return $?
    fi

    mapfile -t src_files < <(find src -name "*.$ext")

    local compile_flags=()
    compile_flags+=($(get_compiler_flags))
    compile_flags+=("$std" "-c")
    compile_flags+=("-Iinclude" "-Isrc")
    [[ -n "$USER_FLAGS" ]] && read -ra U_FLAGS <<< "$USER_FLAGS" && compile_flags+=("${U_FLAGS[@]}")

    local obj_files=()
    local files_to_compile=()
    local recompiled=0
    local skipped=0
    local total_compile_time=0

    # Check each source file
    echo "${C}Checking ${#src_files[@]} source files...${N}"
    for src in "${src_files[@]}"; do
        # Generate object file path
        local obj_name="${src//\//_}"  # Replace / with _
        obj_name="${obj_name%.*}.o"
        local obj_path="$obj_dir/$obj_name"
        obj_files+=("$obj_path")

        # Check if recompilation is needed
        if [[ ! -f "$obj_path" ]] || [[ "$src" -nt "$obj_path" ]]; then
            files_to_compile+=("$src:$obj_path")
        else
            ((skipped++))
        fi
    done

    # Report what needs compilation
    if [[ ${#files_to_compile[@]} -eq 0 ]]; then
        echo "${G}[UP-TO-DATE]${N} All object files current. Linking only..."
    else
        echo "${Y}Compiling ${#files_to_compile[@]} changed file(s), skipping $skipped...${N}"
    fi

    # Compile changed files
    local compilation_failed=0
    for entry in "${files_to_compile[@]}"; do
        local src="${entry%%:*}"
        local obj="${entry##*:}"

        echo "${C}  → $(basename "$src")${N}"

        local start_time=$(date +%s.%N)
        "$comp" "${compile_flags[@]}" "$src" -o "$obj" 2> "$TEMP_ERR"
        local status=$?
        local end_time=$(date +%s.%N)
        local compile_time=$(calculate_time "$start_time" "$end_time")
        total_compile_time=$(add_time "$total_compile_time" "$compile_time")

        if [[ $status -ne 0 ]]; then
            echo "${R}[FAILED]${N} Compilation of $(basename "$src") failed"
            [[ -s "$TEMP_ERR" ]] && head -20 "$TEMP_ERR"
            compilation_failed=1
            break
        fi
        ((recompiled++))
    done

    if [[ $compilation_failed -eq 1 ]]; then
        rm -f "$TEMP_ERR"
        return 1
    fi

    # Linking stage
    echo "${C}Linking ${#obj_files[@]} object files...${N}"

    local link_flags=()
    link_flags+=($(get_compiler_flags))
    link_flags+=("${obj_files[@]}" "-Llib" "-o" "$outfile")
    [[ -n "$USER_FLAGS" ]] && read -ra U_FLAGS <<< "$USER_FLAGS" && link_flags+=("${U_FLAGS[@]}")

    local anim_cmd="${ANIM_STYLE}[@]"
    BLA::start_loading_animation "${!anim_cmd}"
    local start_time=$(date +%s.%N)
    "$comp" "${link_flags[@]}" 2> "$TEMP_ERR"
    local status=$?
    local end_time=$(date +%s.%N)
    BLA::stop_loading_animation
    local link_time=$(calculate_time "$start_time" "$end_time")
    total_compile_time=$(add_time "$total_compile_time" "$link_time")

    if [[ $status -eq 0 ]]; then
        local size=$(du -h "$outfile" 2>/dev/null | cut -f1)
        echo "${G}[SUCCESS]${N} Binary: $outfile (${size:-?}) ${C}[${total_compile_time}s]${N}"
        echo "${Y}  Stats: $recompiled compiled, $skipped cached, ${link_time}s linking${N}"

        # Log to file
        {
            echo "============================================================"
            echo "SESSION : $(date '+%Y-%m-%d %H:%M:%S') | RESULT: SUCCESS"
            echo "TARGET  : $outfile"
            echo "TIME    : ${total_compile_time}s (${recompiled} files, ${link_time}s link)"
            echo "MODE    : Incremental Build"
            echo "COMMAND : $comp [incremental compilation]"
            echo "============================================================"
        } >> "$LOG_FILE"

        LAST_BIN="$outfile"
        LAST_SOURCE="$outname"
        LAST_COMP_TYPE="project"
        save_config

        read -p "${G}Run now? [Y/n]:${N} " run_choice
        [[ "$run_choice" != "n" && "$run_choice" != "N" ]] && run_program "$outfile"
    else
        echo "${R}[FAILED]${N} Linking failed ${C}[${total_compile_time}s]${N}"
        [[ -s "$TEMP_ERR" ]] && head -20 "$TEMP_ERR"
        {
            echo "============================================================"
            echo "SESSION : $(date '+%Y-%m-%d %H:%M:%S') | RESULT: FAILED"
            echo "TARGET  : $outfile"
            echo "TIME    : ${total_compile_time}s"
            echo "MODE    : Incremental Build (linking failed)"
            echo "--- COMPILER OUTPUT ---"
            cat "$TEMP_ERR"
            echo "============================================================"
        } >> "$LOG_FILE"
    fi

    rm -f "$TEMP_ERR"
    return $status
}

# ===========================================
# QUICK REBUILD
# ===========================================
quick_rebuild() {
    if [[ -z "$LAST_BIN" || -z "$LAST_COMP_TYPE" ]]; then
        echo "${Y}[!] No previous build found.${N}"
        sleep 1
        return
    fi

    echo "${C}${BOLD}REBUILDING LAST BUILD:${N}"
    echo "  Type: ${Y}$LAST_COMP_TYPE${N}"
    echo "  Target: ${Y}$LAST_BIN${N}"
    [[ "$LAST_COMP_TYPE" == "file" ]] && echo "  Source: ${Y}$LAST_SOURCE${N}"
    [[ "$LAST_COMP_TYPE" == "project" ]] && echo "  Project: ${Y}$LAST_SOURCE${N}"
    echo ""
    read -p "Continue? [Y/n]: " confirm
    [[ "$confirm" == "n" || "$confirm" == "N" ]] && return

    if [[ "$LAST_COMP_TYPE" == "file" ]]; then
        local source="$LAST_SOURCE"

        if [[ ! -f "$source" ]]; then
            echo "${R}[!] Source file not found: $source${N}"
            sleep 1
            return
        fi

        local ext="${source##*.}"
        local comp=$(get_compiler_names "cpp")
        local std="-std=$CPP_STD"

        [[ "$ext" == "c" ]] && { comp=$(get_compiler_names "c"); std="-std=$C_STD"; }

        local outfile="$LAST_BIN"

        local flags=()
        flags+=($(get_compiler_flags))
        flags+=("$std" "$source" "-Llib" "-o" "$outfile")
        flags+=("-Iinclude" "-Isrc")

        [[ -n "$USER_FLAGS" ]] && read -ra U_FLAGS <<< "$USER_FLAGS" && flags+=("${U_FLAGS[@]}")

        local anim_cmd="${ANIM_STYLE}[@]"
        BLA::start_loading_animation "${!anim_cmd}"
        local start_time=$(date +%s.%N)
        "$comp" "${flags[@]}" 2> "$TEMP_ERR"
        local status=$?
        local end_time=$(date +%s.%N)
        BLA::stop_loading_animation
        local compile_time=$(calculate_time "$start_time" "$end_time")

        if log_verbose $status "$outfile" "$comp ${flags[*]}" "$compile_time"; then
            read -p "${G}Run now? [Y/n]:${N} " run_choice
            [[ "$run_choice" != "n" && "$run_choice" != "N" ]] && run_program "$outfile"
        fi

    elif [[ "$LAST_COMP_TYPE" == "project" ]]; then
        local outname="$LAST_SOURCE"

        if [[ ! -d "src" ]]; then
            echo "${R}[!] /src directory missing.${N}"
            sleep 1
            return
        fi

        # Detect language from last binary or ask
        local ext="cpp"
        local comp=$(get_compiler_names "cpp")
        local std="-std=$CPP_STD"

        mapfile -t cpp_files < <(find src -name "*.cpp" 2>/dev/null)
        mapfile -t c_files < <(find src -name "*.c" 2>/dev/null)

        if [[ ${#cpp_files[@]} -gt 0 && ${#c_files[@]} -eq 0 ]]; then
            ext="cpp"
        elif [[ ${#c_files[@]} -gt 0 && ${#cpp_files[@]} -eq 0 ]]; then
            ext="c"
            comp=$(get_compiler_names "c")
            std="-std=$C_STD"
        else
            read -p "[1] C [2] C++: " ptype
            [[ "$ptype" == "1" ]] && { comp=$(get_compiler_names "c"); std="-std=$C_STD"; ext="c"; }
        fi

        mapfile -t src_files < <(find src -name "*.$ext")

        if [[ ${#src_files[@]} -eq 0 ]]; then
            echo "${R}[!] No .$ext files found in src/${N}"
            sleep 1
            return
        fi

        echo "${C}Found ${#src_files[@]} source files${N}"

        local outfile="$LAST_BIN"

        # Use incremental or full build based on setting
        if [[ "$INCREMENTAL" == "ON" ]]; then
            build_project_incremental "$comp" "$std" "$ext" "$outfile" "$outname (REBUILD)"
        else
            # Full rebuild
            local flags=()
            flags+=($(get_compiler_flags))
            flags+=("$std" "${src_files[@]}" "-Llib" "-o" "$outfile")
            flags+=("-Iinclude" "-Isrc")

            [[ -n "$USER_FLAGS" ]] && read -ra U_FLAGS <<< "$USER_FLAGS" && flags+=("${U_FLAGS[@]}")

            local anim_cmd="${ANIM_STYLE}[@]"
            BLA::start_loading_animation "${!anim_cmd}"
            local start_time=$(date +%s.%N)
            "$comp" "${flags[@]}" 2> "$TEMP_ERR"
            local status=$?
            local end_time=$(date +%s.%N)
            BLA::stop_loading_animation
            local compile_time=$(calculate_time "$start_time" "$end_time")

            if log_verbose $status "$outfile" "Project: $outname (REBUILD)" "$compile_time"; then
                read -p "${G}Run now? [Y/n]:${N} " run_choice
                [[ "$run_choice" != "n" && "$run_choice" != "N" ]] && run_program "$outfile"
            fi
        fi
    fi
}

# ===========================================
# VERBOSE DASHBOARD MENU
# ===========================================
draw_header() {
    local comp_name=$(get_compiler_names "cpp")
    local ver=$($comp_name --version 2>/dev/null | head -n 1 | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+\.[0-9]+/) print $i; exit}')
    local cnt=$(find src -name "*.cpp" -o -name "*.c" 2>/dev/null | wc -l)
    local log_sz=$(du -sh "$LOG_FILE" 2>/dev/null | cut -f1)

    clear
    echo "${B}${BOLD}================================================================${N}"
    echo "${B}                C/C++ POWER BUILDER (v5.2)                      ${N}"
    echo "${B}================================================================${N}"
    echo "${C}${BOLD}ENVIRONMENT:${N}"
    echo "  ${UNDERLINE}OS:${N} $(uname -s)  |  ${UNDERLINE}COMPILER:${N} $COMPILER ($comp_name $ver)"
    echo "  ${UNDERLINE}PWD:${N} $(pwd)"
    echo ""
    echo "${C}${BOLD}PROJECT STATISTICS:${N}"
    echo "  Found ${M}$cnt${N} source files in /src  |  ${G}${BOLD}Log Size:${N} ${M}${log_sz:-0B}${N}"
    echo "  Last Output: ${G}${LAST_BIN:-NONE}${N}"
    echo ""
    echo "${C}${BOLD}ACTIVE COMPILER CONFIGURATION:${N}"
    echo "  Optimization: [ ${Y}$OPT_LEVEL${N} ]   Build Mode: [ ${Y}$BUILD_MODE${N} ]   LTO: [ ${Y}$LTO_ENABLED${N} ]"
    echo "  C Standard:   [ ${Y}$C_STD${N} ]      CPP Standard: [ ${Y}$CPP_STD${N} ]"
    echo "  Warnings:     [ ${Y}$WARN_MODE${N} ]       Sanitizer:   [ ${Y}$SANITIZER${N} ]"
    echo "  Incremental:  [ ${Y}$INCREMENTAL${N} ]     User Flags:  [ ${Y}${USER_FLAGS:-NONE}${N} ]"
    echo "  Libraries:    [ ${Y}-Llib${N} ]        Animation:   [ ${Y}${ANIM_STYLE#BLA_}${N} ]"
    echo "${B}----------------------------------------------------------------${N}"
}

load_config
while true; do
    draw_header
    printf "  %-32s  %-32s\n" "1. ${BOLD}COMPILE${N} FILE"          "11. ${BOLD}TOGGLE${N} LTO"
    printf "  %-32s  %-32s\n" "2. ${BOLD}COMPILE${N} PROJECT"       "12. ${BOLD}SET${N} SANITIZER"
    printf "  %-32s  %-32s\n" "3. ${BOLD}TOGGLE${N} DEBUG/RELEASE"  "13. ${BOLD}VIEW${N} LOG"
    printf "  %-32s  %-32s\n" "4. ${BOLD}CHANGE${N} STANDARDS"      "14. ${BOLD}CLEAR${N} LOG"
    printf "  %-32s  %-32s\n" "5. ${BOLD}SET${N} OUTPUT DIR"        "15. ${Y}${BOLD}CYCLE${N} OPTIMIZATION"
    printf "  %-32s  %-32s\n" "6. ${BOLD}NEW${N} TEMPLATE"          "16. ${G}${BOLD}RUN LAST BINARY${N}"
    printf "  %-32s  %-32s\n" "7. ${BOLD}CHANGE${N} ANIMATION"      "17. ${C}${BOLD}REBUILD LAST${N}"
    printf "  %-32s  %-32s\n" "8. ${BOLD}EDIT${N} FLAGS/LIBS"       "18. ${M}${BOLD}TOGGLE COMPILER${N}"
    printf "  %-32s  %-32s\n" "9. ${R}${BOLD}CLEAN${N} BINARIES"    "19. ${C}${BOLD}TOGGLE INCREMENTAL${N}"
    printf "  %-32s  %-32s\n" "10. ${BOLD}TOGGLE${N} WARNINGS"      ""
    echo -e "\n  0. ${R}${BOLD}EXIT SYSTEM${N}"
    echo "${B}================================================================${N}"

    read -p "Selection: " choice
    case $choice in
        1) build_single_file ;;
        2) build_project ;;
        3)
            [[ "$BUILD_MODE" == "DEBUG" ]] && BUILD_MODE="RELEASE" || BUILD_MODE="DEBUG"
            save_config
            echo "${G}Build mode: $BUILD_MODE${N}"
            sleep 0.5
            ;;
        4)
            read -p "[1]CPP [2]C: " t
            if [[ "$t" == "1" ]]; then
            read -p "Ver [1-4]: " v
                case $v in
                    1) CPP_STD="c++11";;
                    2) CPP_STD="c++17";;
                    3) CPP_STD="c++20";;
                    *) CPP_STD="c++23";;
                esac
            else
            read -p "Ver [1-5]: " v
                case $v in
                    1) C_STD="c89";;
                    2) C_STD="c99";;
                    3) C_STD="c11";;
                    4) C_STD="c17";;
                    *) C_STD="c23";;
                esac
            fi
            save_config
            ;;
        5)
            read -e -p "Folder: " new_dir
            [[ -n "$new_dir" ]] && BUILD_DIR="$new_dir" && save_config && load_config
            ;;
        6)
            read -p "Name: " p
            [[ -z "$p" ]] && continue
            if ! mkdir -p "$p"/{src,include,bin,lib} 2>/dev/null; then
                echo "${R}[ERROR] Cannot create project directories${N}"
                sleep 1
                continue
            fi
            cp "$0" "$p/build.sh" 2>/dev/null || {
                echo "${R}[ERROR] Cannot copy build script${N}"
                sleep 1
                continue
            }
            chmod +x "$p/build.sh"
            echo "${G}Template created: $p/${N}"
            read -p "Change to directory? [Y/n]: " cd_choice
            if [[ "$cd_choice" != "n" && "$cd_choice" != "N" ]]; then
                if cd "$p" 2>/dev/null; then
                    load_config
                else
                    echo "${R}[ERROR] Cannot change to directory${N}"
                    sleep 1
                fi
            fi
            ;;
        7)
            echo "1)Classic 2)Snake 3)Earth 4)Moon 5)Clock 6)Braille 7)Dots 8)Box 9)Monkey 10)Pong 11)Metro 12)Breathe"
            read -p "Pick: " ap
            case $ap in
                1) ANIM_STYLE="BLA_classic";;
                2) ANIM_STYLE="BLA_snake";;
                3) ANIM_STYLE="BLA_earth";;
                4) ANIM_STYLE="BLA_moon";;
                5) ANIM_STYLE="BLA_clock";;
                6) ANIM_STYLE="BLA_braille";;
                7) ANIM_STYLE="BLA_dots";;
                8) ANIM_STYLE="BLA_box";;
                9) ANIM_STYLE="BLA_monkey";;
                10) ANIM_STYLE="BLA_pong";;
                11) ANIM_STYLE="BLA_metro";;
                12) ANIM_STYLE="BLA_breathe";;
            esac
            save_config
            ;;
        8)
            read -e -i "$USER_FLAGS" -p "Flags: " USER_FLAGS
            save_config
            ;;
        9)
            read -p "${R}Delete all binaries? [y/N]:${N} " confirm
            [[ "$confirm" == "y" || "$confirm" == "Y" ]] && {
                rm -rf "$ABS_BUILD_DIR"/*
                echo "${G}Cleaned binaries and object files.${N}"
                LAST_BIN=""
                save_config
            }
            sleep 0.5
            ;;
        10)
            [[ "$WARN_MODE" == "ON" ]] && WARN_MODE="OFF" || WARN_MODE="ON"
            save_config
            echo "${G}Warnings: $WARN_MODE${N}"
            sleep 0.5
            ;;
        11)
            [[ "$LTO_ENABLED" == "ON" ]] && LTO_ENABLED="OFF" || LTO_ENABLED="ON"
            save_config
            echo "${G}LTO: $LTO_ENABLED${N}"
            sleep 0.5
            ;;
        12)
            echo "1) NONE  2) Address  3) Thread  4) Undefined Behavior  5) Memory"
            read -p "Pick: " san
            case $san in
                2) SANITIZER="ADDRESS";;
                3) SANITIZER="THREAD";;
                4) SANITIZER="UB";;
                5) SANITIZER="MEMORY";;
                *) SANITIZER="NONE";;
            esac
            save_config
            echo "${G}Sanitizer: $SANITIZER${N}"
            sleep 0.5
            ;;
        13)
            [[ -f "$LOG_FILE" ]] && less "$LOG_FILE" || echo "${Y}No log file.${N}"
            ;;
        14)
            read -p "${R}Clear log file? [y/N]:${N} " confirm
            [[ "$confirm" == "y" || "$confirm" == "Y" ]] && {
                rm -f "$LOG_FILE"
                echo "${G}Cleared.${N}"
            }
            sleep 0.5
            ;;
        15)
            case $OPT_LEVEL in
                "-O0") OPT_LEVEL="-O1" ;;
                "-O1") OPT_LEVEL="-O2" ;;
                "-O2") OPT_LEVEL="-O3" ;;
                "-O3") OPT_LEVEL="-Ofast" ;;
                "-Ofast") OPT_LEVEL="-Os" ;;
                *) OPT_LEVEL="-O0" ;;
            esac
            save_config
            echo "${G}Optimization: $OPT_LEVEL${N}"
            sleep 0.5
            ;;
        16) run_program "$LAST_BIN" ;;
        17) quick_rebuild ;;
        18)
            if [[ "$COMPILER" == "GCC" ]]; then
                # Check if clang is available
                if command -v clang++ &> /dev/null && command -v clang &> /dev/null; then
                    COMPILER="CLANG"
                    echo "${G}Switched to Clang (clang/clang++)${N}"
                else
                    echo "${R}[!] Clang not found. Install clang and clang++ first.${N}"
                fi
            else
                COMPILER="GCC"
                echo "${G}Switched to GCC (gcc/g++)${N}"
            fi
            save_config
            sleep 0.5
            ;;
        19)
            [[ "$INCREMENTAL" == "ON" ]] && INCREMENTAL="OFF" || INCREMENTAL="ON"
            save_config
            if [[ "$INCREMENTAL" == "ON" ]]; then
                echo "${G}Incremental builds: ENABLED${N}"
                echo "${C}  → Only changed files will be recompiled${N}"
            else
                echo "${Y}Incremental builds: DISABLED${N}"
                echo "${C}  → Full rebuild every time${N}"
            fi
            sleep 1
            ;;
        0)
            tput cnorm
            echo "${G}Goodbye!${N}"
            exit 0
            ;;
        *)
            echo "${Y}Invalid choice.${N}"
            sleep 0.5
            ;;
    esac
done
