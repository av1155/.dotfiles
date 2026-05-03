# <======================== .ZPROFILE FILE ========================>

# <------------------- SYSTEM DETECTION ------------------->
case "$(uname -s)" in
Darwin) # macOS

    # <============ HOMEBREW PATH + DYNAMIC PATH DETECTION ============>
    if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    if command -v brew &>/dev/null; then
        HOMEBREW_PATH=$(brew --prefix)

        # <================== DYNAMIC PATH CONFIGURATION ==================>
        path+=("$HOMEBREW_PATH/bin")
        path+=("$HOMEBREW_PATH/opt/git/bin")
        path+=("$HOMEBREW_PATH/opt/dotnet/bin")
        path+=("$HOMEBREW_PATH/opt/go/bin")
        path+=("$HOMEBREW_PATH/opt/julia/bin")
        path+=("$HOMEBREW_PATH/opt/openjdk/bin")
    fi

    # Set GOBIN environment variable
    export GOBIN="$HOME/go/bin"

    # Add GOBIN to PATH
    export PATH="$GOBIN:$PATH"

    # Create GOBIN directory if it doesn't exist
    if [ ! -d "$GOBIN" ]; then
        mkdir -p "$GOBIN"
    fi

    # JAVA: brew openjdk (keg-only). Point JAVA_HOME at it directly.
    if [ -n "$HOMEBREW_PATH" ] && [ -d "$HOMEBREW_PATH/opt/openjdk/libexec/openjdk.jdk/Contents/Home" ]; then
        export JAVA_HOME="$HOMEBREW_PATH/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
        export CPPFLAGS="-I$HOMEBREW_PATH/opt/openjdk/include"
    fi

    # Added by Toolbox App
    path+=("$HOME/Library/Application Support/JetBrains/Toolbox/scripts")

    # DOTNET
    if [ -n "$HOMEBREW_PATH" ]; then
        export DOTNET_ROOT="$HOMEBREW_PATH/opt/dotnet/libexec"
    fi

    export PATH="$HOME/.console-ninja/.bin:$PATH"
    ;;

Linux)
    # Set paths and configurations for Linux
    case "$(uname -m)" in
    x86_64) # 64-bit
        ;;
    aarch64) # ARM 64-bit (Raspberry Pi 5 or similar)
        # Add /snap/bin to the path for Raspberry Pi
        PATH+=:/snap/bin
        export PATH
        ;;
    esac

    ;;

CYGWIN* | MINGW32* | MSYS* | MINGW*) # Windows (WSL or native)
    # Set paths and configurations for Windows
    ;;

*)
    # Unknown OS
    ;;
esac

# <==================== END OF .ZPROFILE FILE =====================>


