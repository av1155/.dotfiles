# <======================== .ZPROFILE FILE ========================>

# <------------------- SYSTEM DETECTION ------------------->
case "$(uname -s)" in
Darwin) # macOS

    # <============ HOMEBREW PATH + DYNAMIC PATH DETECTION ============>
    eval "$(/opt/homebrew/bin/brew shellenv)"

    # Ensure Homebrew Ruby is prioritized over system Ruby
    export PATH="/opt/homebrew/opt/ruby/bin:$PATH"

    if command -v brew &>/dev/null; then
        HOMEBREW_PATH=$(brew --prefix)
    fi

    # <================== DYNAMIC PATH CONFIGURATION ==================>
    if command -v brew &>/dev/null; then
        path+=("$(brew --prefix)/bin")
        path+=("$(brew --prefix git)/bin")
        path+=("$(brew --prefix dotnet)/bin")
        path+=("$(brew --prefix ruby)/bin")
        path+=("$(brew --prefix go)/bin")
        path+=("$(brew --prefix julia)/bin")
        path+=("$(brew --prefix coursier)/bin")
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
    export JAVA_HOME=$(/usr/libexec/java_home)
    export PATH=$JAVA_HOME/bin:$PATH

    # For compilers to find OpenJDK you may need to set:
    export CPPFLAGS="-I/opt/homebrew/opt/openjdk/include"

    # Added by Toolbox App
    path+=("$HOME/Library/Application Support/JetBrains/Toolbox/scripts")

    # DOTNET
    export DOTNET_ROOT="$HOMEBREW_PATH/opt/dotnet/libexec"

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

    # Dynamically get the user gem bin directory
    user_gem_bin=$(ruby -e 'puts Gem.user_dir')/bin

    # Dynamically get the Homebrew gem bin directory
    homebrew_gem_bin=$(ruby -e 'puts Gem.bindir')

    # Check if the directories exist and add them to PATH
    if [ -d "$user_gem_bin" ]; then
        export PATH="$user_gem_bin:$PATH"
    fi
    if [ -d "$homebrew_gem_bin" ]; then
        export PATH="$homebrew_gem_bin:$PATH"
    fi
    # <<< END RUBY INITIALIZATION

    PATH=~/.console-ninja/.bin:$PATH
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

