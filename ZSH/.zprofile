# <======================== .ZPROFILE FILE ========================>

# <------------------- SYSTEM DETECTION ------------------->
case "$(uname -s)" in
Darwin) # macOS

    # <============ HOMEBREW PATH + DYNAMIC PATH DETECTION ============>
    if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        
        # Ensure Homebrew Ruby is prioritized over system Ruby
        export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
    fi

    if command -v brew &>/dev/null; then
        HOMEBREW_PATH=$(brew --prefix)
        
        # <================== DYNAMIC PATH CONFIGURATION ==================>
        path+=("$HOMEBREW_PATH/bin")
        path+=("$HOMEBREW_PATH/opt/git/bin")
        path+=("$HOMEBREW_PATH/opt/dotnet/bin")
        path+=("$HOMEBREW_PATH/opt/ruby/bin")
        path+=("$HOMEBREW_PATH/opt/go/bin")
        path+=("$HOMEBREW_PATH/opt/julia/bin")
        path+=("$HOMEBREW_PATH/opt/coursier/bin")
    fi

    # Set GOBIN environment variable
    export GOBIN="$HOME/go/bin"

    # Add GOBIN to PATH
    export PATH="$GOBIN:$PATH"

    # Create GOBIN directory if it doesn't exist
    if [ ! -d "$GOBIN" ]; then
        mkdir -p "$GOBIN"
    fi

    # JAVA
    if /usr/libexec/java_home &>/dev/null; then
        export JAVA_HOME=$(/usr/libexec/java_home)
        export PATH=$JAVA_HOME/bin:$PATH
        
        # For compilers to find OpenJDK you may need to set:
        if [ -n "$HOMEBREW_PATH" ]; then
            export CPPFLAGS="-I$HOMEBREW_PATH/opt/openjdk/include"
        fi
    fi

    # Added by Toolbox App
    path+=("$HOME/Library/Application Support/JetBrains/Toolbox/scripts")

    # DOTNET
    if [ -n "$HOMEBREW_PATH" ]; then
        export DOTNET_ROOT="$HOMEBREW_PATH/opt/dotnet/libexec"
    fi

    # <================== PERL & RUBY INITIALIZATION ==================>

    # Initialize Perl local::lib environment ------------------------------------>
    # To set this up on a new machine:
    # 1. Install Perl via Homebrew: `brew install perl`
    # 2. Install local::lib, run this command on the terminal: `PERL_MM_OPT="INSTALL_BASE=$HOME/perl5" cpan local::lib`
    # 3. Add the following line to the shell profile to configure the environment
    if [ -d "$HOME/perl5/lib/perl5" ] && command -v perl &>/dev/null; then
        eval "$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib=$HOME/perl5)"
    fi
    # <<< END OF PERL INITIALIZATION

    # Add Ruby gem user install directory to PATH --------------------------------->
    # To set this up on a new machine:
    # 1. Install Ruby gems in the user directory: `gem install neovim`
    # 2. Find the user gem bin directory, run on the terminal: `gem env gemdir`
    # 3. Add the user gem bin directory to PATH in the shell profile

    if command -v ruby &>/dev/null; then
        # Dynamically get the user gem bin directory
        user_gem_bin=$(ruby -e 'puts Gem.user_dir' 2>/dev/null)/bin

        # Dynamically get the Homebrew gem bin directory
        homebrew_gem_bin=$(ruby -e 'puts Gem.bindir' 2>/dev/null)

        # Check if the directories exist and add them to PATH
        if [ -d "$user_gem_bin" ]; then
            export PATH="$user_gem_bin:$PATH"
        fi
        if [ -d "$homebrew_gem_bin" ]; then
            export PATH="$homebrew_gem_bin:$PATH"
        fi
    fi
    # <<< END RUBY INITIALIZATION

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

