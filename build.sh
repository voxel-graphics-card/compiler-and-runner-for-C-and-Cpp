#!/bin/bash

# ===========================================
# INITIALIZATION & DEFAULTS
# ===========================================
CONFIG_FILE="build_config.ini"
LOG_FILE="compilation_log.txt"
TEMP_ERR="compiler_errors.tmp"
DIVIDER="------------------------------------------------------------"

# Check for compiler
if ! command -v g++ &> /dev/null; then
    echo -e "\e[31m[ERROR] G++/GCC not found. Please install build-essential.\e[0m"
    exit 1
fi

load_config() {
    # Default values
    BUILD_MODE="DEBUG"
    CPP_STD="c++23"
    C_STD="c17"
    BUILD_DIR="bin"
    USER_FLAGS=" "
    WARN_MODE="ON"
    OPT_LEVEL="-O3"

    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS='=' read -r key val; do
            # removal of carriage returns if file came from Windows ts so ass
            val=$(echo "$val" | tr -d '\r')
            case "$key" in
                BUILD_MODE) BUILD_MODE="$val" ;;
                CPP_STD)    CPP_STD="$val" ;;
                C_STD)      C_STD="$val" ;;
                BUILD_DIR)  BUILD_DIR="$val" ;;
                USER_FLAGS) USER_FLAGS="$val" ;;
                WARN_MODE)  WARN_MODE="$val" ;;
                OPT_LEVEL)  OPT_LEVEL="$val" ;;
            esac
        done < "$CONFIG_FILE"
    fi
    mkdir -p "$BUILD_DIR"
    ABS_BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"
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
EOF
}

set_flags() {
    if [[ "$WARN_MODE" == "ON" ]]; then BASE_FLAGS="-Wall -Wextra"; else BASE_FLAGS="-w"; fi
    if [[ "$BUILD_MODE" == "DEBUG" ]]; then BASE_FLAGS="$BASE_FLAGS -g"; else BASE_FLAGS="$BASE_FLAGS -s"; fi
}

finish_build() {
    local status=$1
    local target=$2
    local command=$3
    
    if [[ $status -eq 0 ]]; then
        echo -e "\e[32m[SUCCESS]\e[0m"
        stat_text="SUCCESS"
    else
        echo -e "\e[31m[FAILED]\e[0m"
        cat "$TEMP_ERR"
        stat_text="FAILED "
    fi

    {
        echo "$DIVIDER"
        echo "TIMESTAMP: [$(date '+%Y-%m-%d %H:%M:%S')]"
        echo "TARGET:    $target | OPT: $OPT_LEVEL"
        echo "RESULT:    $stat_text"
        echo "MODE:      $BUILD_MODE | STD: $CPP_STD/$C_STD"
        echo "COMMAND:   $command"
        if [[ $status -ne 0 ]]; then
            echo -e "\nERROR LOG:"
            cat "$TEMP_ERR"
        fi
        echo "$DIVIDER"
        echo ""
    } >> "$LOG_FILE"
    
    rm -f "$TEMP_ERR"
    return $status
}

# ===========================================
# MAIN MENU LOOP
# ===========================================
load_config

while true; do
    clear
    echo "==========================================="
    echo "       C/C++ POWER BUILDER (v11.3 Bash)"
    echo "==========================================="
    echo " CUR DIR: $(pwd)"
    echo " OUT DIR: $BUILD_DIR"
    echo " MODE:    $BUILD_MODE | OPT: $OPT_LEVEL"
    echo " STD:     $CPP_STD/$C_STD | WARN: $WARN_MODE"
    echo " FLAGS:   $USER_FLAGS"
    echo "-------------------------------------------"
    echo " 1. Compile Single File       6. Generate New Template"
    echo " 2. Compile Project (Multi)   7. Browse / Enter Folder"
    echo " 3. Toggle DEBUG/RELEASE      8. Edit User Flags (Libs)"
    echo " 4. Change Standards          9. CLEAN BUILD FOLDER"
    echo " 5. Change Output Folder      10. TOGGLE WARNINGS (ON/OFF)"
    echo " 11. VIEW BUILD LOG           12. CLEAR BUILD LOG"
    echo " 13. TOGGLE OPTIMIZATION ($OPT_LEVEL)"
    echo " 0. EXIT"
    echo "==========================================="
    read -p "Select (0-13): " choice

    case $choice in
        1)
            read -p "File Path: " source
            if [[ ! -f "$source" ]]; then echo "[!] Not found."; sleep 1; continue; fi
            set_flags
            filename=$(basename -- "$source")
            extension="${filename##*.}"
            fname_no_ext="${filename%.*}"
            
            if [[ "$extension" == "c" ]]; then
                comp="gcc"; std_f="-std=$C_STD"
            else
                comp="g++"; std_f="-std=$CPP_STD"
            fi
            
            outfile="$ABS_BUILD_DIR/$fname_no_ext"
            cmd="$comp $BASE_FLAGS $OPT_LEVEL $std_f $source -Llib -o $outfile $USER_FLAGS"
            echo "[CMD] $cmd"
            $cmd 2> "$TEMP_ERR"
            finish_build $? "$fname_no_ext" "$cmd"
            [[ $? -eq 0 ]] && { read -p "Args: " args; echo "--- OUTPUT ---"; "$outfile" $args; echo ""; }
            read -p "Press Enter to continue..."
            ;;

        2)
            read -p "[1] C [2] C++: " ptype
            read -p "Binary Name: " outname
            set_flags
            
            if [[ "$ptype" == "1" ]]; then
                comp="gcc"; std_f="-std=$C_STD"; ext="c"
            else
                comp="g++"; std_f="-std=$CPP_STD"; ext="cpp"
            fi

            if [[ ! -d "src" ]]; then echo "[ERROR] 'src' folder missing."; sleep 1; continue; fi
            
            # 1. Gather files and includes (Cleanly separated by spaces)
            file_list=$(find src -name "*.$ext" | paste -sd " " -)
            dir_list=$(find src -type d | sed 's/^/-I/' | paste -sd " " -)
            inc_list="-I. -Iinclude -Isrc $dir_list"
            
            if [[ -z "$(echo $file_list | xargs)" ]]; then 
                echo "[ERROR] No files found in 'src'."; sleep 1; continue; 
            fi
            
            # FIXED: join path WITHOUT spaces. 
            # we use cygpath -w to ensure MinGW understands the absolute Windows path
            raw_outfile="${ABS_BUILD_DIR}/${outname}"
            outfile=$(cygpath -w "$raw_outfile" 2>/dev/null || echo "$raw_outfile")
            
            # The Command
            cmd="$comp $BASE_FLAGS $OPT_LEVEL $std_f $inc_list $file_list -Llib -o \"$outfile\" $USER_FLAGS"
            
            echo "[CMD] Compiling..."
            eval "$cmd" 2> "$TEMP_ERR"
            finish_build $? "$outname" "$cmd"
            
            if [[ $? -eq 0 ]]; then
                read -p "Args: " args
                echo -e "\n--- PROGRAM OUTPUT ---"
                # Call the absolute path using double quotes to handle any potential spaces
                "$raw_outfile" $args
                echo ""
            fi
            read -p "Press Enter to continue..."
            ;;

        3) [[ "$BUILD_MODE" == "DEBUG" ]] && BUILD_MODE="RELEASE" || BUILD_MODE="DEBUG"; save_config ;;
        
        4) 
            echo "[1] C++ ($CPP_STD) [2] C ($C_STD)"
            read -p "> " stype
            if [[ "$stype" == "1" ]]; then
                echo "1. c++11 2. c++17 3. c++20 4. c++23"; read -p ": " sc
                case $sc in 1) CPP_STD="c++11";; 2) CPP_STD="c++17";; 3) CPP_STD="c++20";; 4) CPP_STD="c++23";; esac
            else
                echo "1. c89 2. c99 3. c11 4. c17 5. c23"; read -p ": " sc
                case $sc in 1) C_STD="c89";; 2) C_STD="c99";; 3) C_STD="c11";; 4) C_STD="c17";; 5) C_STD="c23";; esac
            fi
            save_config ;;

        5) read -p "Folder: " BUILD_DIR; save_config; load_config ;;
        
        6)
            read -p "Project Name: " projname
            mkdir -p "$projname/src" "$projname/include" "$projname/bin" "$projname/lib"
            cat <<EOF > "$projname/$CONFIG_FILE"
BUILD_MODE=DEBUG
CPP_STD=$CPP_STD
C_STD=$C_STD
BUILD_DIR=bin
USER_FLAGS=
WARN_MODE=ON
OPT_LEVEL=-O3
EOF
            echo -e "#include <iostream>\nint main() { std::cout << \"Ready\\n\"; return 0; }" > "$projname/src/main.cpp"
            cd "$projname" && load_config ;;

        7) ls -d */ 2>/dev/null; read -p "Enter Folder: " target; [[ -d "$target" ]] && cd "$target" && load_config ;;

        8) read -p "Enter Flags: " USER_FLAGS; save_config ;;

        9) rm -rf "$ABS_BUILD_DIR"/*; echo "Done."; sleep 1 ;;

        10) [[ "$WARN_MODE" == "ON" ]] && WARN_MODE="OFF" || WARN_MODE="ON"; save_config ;;

        11) [[ -f "$LOG_FILE" ]] && less "$LOG_FILE" || echo "No log.";;

        12) rm -f "$LOG_FILE"; echo "Log cleared."; sleep 1 ;;

        13)
            case $OPT_LEVEL in
                "-O0") OPT_LEVEL="-O1" ;;
                "-O1") OPT_LEVEL="-O2" ;;
                "-O2") OPT_LEVEL="-O3" ;;
                "-O3") OPT_LEVEL="-O0" ;;
            esac
            save_config ;;

        0) echo -e "Thanks for using my built system\n \t \t~Debargha Bose" && sleep 3 && exit 0 ;;
    esac
done