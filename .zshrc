# === Zsh-Only Initialization ===
# Only run these if we are actually in Zsh
if [ -n "$ZSH_VERSION" ]; then
    #autoload -Uz compinit && compinit
    autoload -U +X compinit && compinit
    #autoload -Uz bashcompinit && bashcompinit
    autoload -U +X bashcompinit && bashcompinit
    
    # Enable tab completion for gcloud and kubectl (Zsh versions)
    if [ -f "/Users/meillier/google-cloud-sdk/path.zsh.inc" ]; then
        source "/Users/meillier/google-cloud-sdk/path.zsh.inc"
    fi
    if [ -f "/Users/meillier/google-cloud-sdk/completion.zsh.inc" ]; then
        source "/Users/meillier/google-cloud-sdk/completion.zsh.inc"
    fi
    source <(kubectl completion zsh)
fi



# === Environment Variables ===
#Gemini API Keyfor gemini cli auth tied to argolis ai-prototpying project created via ai studio
export GEMINI_API_KEY=""

# for Gemini CLI using vertexAI API key auth option
export GOOGLE_GENAI_USE_VERTEXAI=true
export GOOGLE_CLOUD_PROJECT=ai-prototyping-460721
export GOOGLE_CLOUD_LOCATION=us-central1
export GOOGLE_API_KEY=""


# Settings for Claude Code https://docs.anthropic.com/en/docs/claude-code/google-vertex-ai
export CLAUDE_CODE_USE_VERTEX=1
export CLOUD_ML_REGION=us-central1
export ANTHROPIC_VERTEX_PROJECT_ID=ai-prototyping-460721


export GITHUB_MCP_TOKEN=''
export ARGOLIS_BILLING_ID=''
export TF_VAR_billing_account=$ARGOLIS_BILLING_ID
export HF_TOKEN=""

# === Google Cloud SDK ===
export PATH="$PATH:/Users/meillier/google-cloud-sdk/bin"

# === github cli ====
export PATH="/usr/local/bin:$PATH"




# === pyenv setup (was required during python update gor gcloud sdk install)
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"


# === rbenv (ruby env manager) 
eval "$(rbenv init -)"

# === LS Color Configuration for macOS (Darwin) ===

# 1. Enable CLICOLOR for color output in ls
# Set CLICOLOR=1 to enable colors for 'ls'
export CLICOLOR=1
# Set directories to green foreground (c) with default background (x)
export LSCOLORS=cxfxcxdxbxegedabagacad


# 2. Alias 'ls' to use the -G flag (the macOS/BSD color flag)
alias ls='ls -G'

# 3. Alias 'll' to show long list format with colors
alias ll='ls -lG'


#zsh colored output:
# grep -E coloring instead of having to use --color=always (grep --color=always -E '^|cluster')
alias grep='grep --color=auto'


# === Current folder in prompt colored blue
PROMPT='%n@%m %F{cyan}%1d%f %% ' #cyan


# Obsidian

##alias obsidian='open -a "Obsidian"'
#open -n -a "Obsidian" "$vault_path"


#For permanent vault access or creation.
#Just type obsidian while in your vault directory.IT will either create a new vault or open the existing one.


function reset_folder_icon() {
    local folder_path="$1"

    if [[ -z "$folder_path" ]]; then
        echo "Usage: reset_folder_icon <path_to_folder>"
        return 1
    fi

    # Check if folder exists
    if [[ ! -d "$folder_path" ]]; then
        echo "❌ Error: Folder '$folder_path' not found."
        return 1
    fi

    # Convert to absolute path
    local abs_path=$(realpath "$folder_path")

    # Use AppleScript to set the icon to 'missing value' (null)
    osascript -e "
    use framework \"AppKit\"
    (current application's NSWorkspace's sharedWorkspace()'s setIcon:(missing value) forFile:\"$abs_path\" options:0)
    "

    # Secondary cleanup: Remove the hidden 'Icon\r' file if it lingers
    # This ensures any 'Custom Icon' bits are truly gone
    rm -f "$abs_path/Icon"$'\r' 2>/dev/null
    
    # Touch the folder to force Finder to notice the change
    touch "$abs_path"

    echo "✅ Icon reset to default for: $folder_path"
}


# Custom completion function for 'obsidian' scripts
_obsidian_funcs()
{
    local cur="${COMP_WORDS[COMP_CWORD]}"
    # Find all functions starting with 'obsidian' and filter results
    COMPREPLY=( $(compgen -A function "obsidian" | grep "^${cur}") )
}
# Register the custom function to be used when the user types 'obsidian'
# -o nospace often helps with display clarity for custom completions.
complete -F _obsidian_funcs -o nospace obsidian



function set_folder_icon() {
    local image_path="$1"
    local folder_path="$2"

    if [[ -z "$image_path" || -z "$folder_path" ]]; then
        echo "Usage: set_folder_icon <path_to_image> <path_to_folder>"
        return 1
    fi

    # Using AppleScript via Terminal to set the icon cleanly
    osascript -e "
    use framework \"AppKit\"
    set imageData to (current application's NSImage's alloc()'s initWithContentsOfFile:\"$(realpath $image_path)\")
    (current application's NSWorkspace's sharedWorkspace()'s setIcon:imageData forFile:\"$(realpath $folder_path)\" options:0)
    "
    echo "✅ Icon updated for $folder_path"
}

function obsidian() {
    # --- Dependencies Check ---
    if ! command -v jq &> /dev/null; then
        echo "Error: 'jq' is required for JSON manipulation. Aborting."
        return 1
    fi

    # --- Configuration ---
    local vault_path="$PWD"
    local config_file="$HOME/Library/Application Support/obsidian/obsidian.json"
    local TEMPLATE_CONFIG_PATH="/Users/meillier/Documents/00-Template/.obsidian"

    # Check registration (Idempotence)
    local registered_vault_id=$(jq -r --arg path "$vault_path" \
        '.vaults | to_entries[] | select(.value.path == $path) | .key' \
        "$config_file" 2>/dev/null)

    # 1. Registration Block
    if [[ -z "$registered_vault_id" ]]; then

        echo "A new permanent vault must be registered. This requires closing all open Obsidian windows."
        # ZSH specific read syntax
        read -r "response?Is it OK to close all existing Obsidian windows? (y/N) "

        if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo "❌ CANCELED: Please create the new vault manually."
            return 1
        fi

        osascript -e 'quit app "Obsidian"' 2>/dev/null
        echo "Closing running Obsidian instances..."
        sleep 2

        read "vault_name?Enter a name for the new permanent vault: "
        if [[ -z "$vault_name" ]]; then
            echo "Vault name cannot be empty. Aborting."
            return 1
        fi

        local vault_id=$(openssl rand -hex 8)
        local timestamp_ms=$(perl -MTime::HiRes -e 'printf "%.0f\n", Time::HiRes::time * 1000')

        # 3. Copy Template Configuration
        if [ ! -d "$vault_path/.obsidian" ]; then
            if [ -d "$TEMPLATE_CONFIG_PATH" ]; then
                cp -r "$TEMPLATE_CONFIG_PATH" "$vault_path/"
                echo "✅ Copied template configuration to new vault."
            else
                mkdir -p "$vault_path/.obsidian"
                echo "⚠️ Template configuration not found. Created empty .obsidian folder."
            fi
        fi

        # 4. Update Global Config JSON
        if [ ! -f "$config_file" ]; then
            mkdir -p "$(dirname "$config_file")"
            echo '{"vaults":{}}' > "$config_file"
        fi

        local jq_script='.vaults += {
            ($id): {
                "path": $path,
                "ts": ($ts | tonumber),
                "open": true
            }
        } | .lastOpenVault = $id'

        jq --arg id "$vault_id" \
           --arg path "$vault_path" \
           --arg ts "$timestamp_ms" \
           "$jq_script" \
           "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"


        set_folder_icon /Applications/Obsidian.app/Contents/Resources/icon.icns $vault_path



    else
        echo "Vault already registered (ID: $registered_vault_id). Launching directly..."
        vault_id="$registered_vault_id" 
    fi

    # 5. Launch
    local encoded_id=$(perl -MURI::Escape -e 'print uri_escape($ARGV[0])' "$vault_id")
    echo "Launching permanent vault..."
    open "obsidian://open?vault=$encoded_id"
}



#function obsidian() {
#    # --- Dependencies Check ---
#    if ! command -v jq &> /dev/null; then
#        echo "Error: 'jq' is required for JSON manipulation. Aborting."
#        return 1
#    fi
#
#    # --- Configuration ---
#    local vault_path="$PWD"
#    local config_file="$HOME/Library/Application Support/obsidian/obsidian.json"
#    # Define your template source path
#    #local TEMPLATE_CONFIG_PATH="/Users/meillier/Documents/Obsidian/00-Template/.obsidian"
#    local TEMPLATE_CONFIG_PATH="/Users/meillier/Documents/00-Template/.obsidian"
#    
#    # Check registration (Idempotence)
#    local registered_vault_id=$(jq -r --arg path "$vault_path" \
#        '.vaults | to_entries[] | select(.value.path == $path) | .key' \
#        "$config_file" 2>/dev/null)
#
#    # 1. Registration Block
#    if [[ -z "$registered_vault_id" ]]; then
#        
#        # --- Prompt and Quit Check ---
#        echo "A new permanent vault must be registered. This requires closing all open Obsidian windows."
#        #read -r -p "Is it OK to close all existing Obsidian windows? (y/N) " response
#        read -r "response?Is it OK to close all existing Obsidian windows? (y/N) "
#        
#        if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
#            echo "❌ CANCELED: Please create the new vault manually using the Vault Switcher."
#            return 1
#        fi
#        
#        # Quit Obsidian (Crucial for forcing config reload) 🛑
#        osascript -e 'quit app "Obsidian"' 2>/dev/null
#        echo "Closing running Obsidian instances..."
#        sleep 2
#        
#        # 2. Prompt for Vault Name and Generate Metadata
#        #read -p "Enter a name for the new permanent vault: " vault_name
#        read "vault_name?Enter a name for the new permanent vault: "
#
#        if [[ -z "$vault_name" ]]; then
#            echo "Vault name cannot be empty. Aborting."
#            return 1
#        fi
#        
#        # Generate ID and Timestamp
#        local vault_id=$(openssl rand -hex 8)
#        local timestamp_ms=$(perl -MTime::HiRes -e 'printf "%.0f\n", Time::HiRes::time * 1000')
#
#        # 3. CRITICAL FIX: Copy Template Configuration 
#        if [ ! -d "$vault_path/.obsidian" ]; then
#            if [ -d "$TEMPLATE_CONFIG_PATH" ]; then
#                # Copy the entire .obsidian contents from the template
#                cp -r "$TEMPLATE_CONFIG_PATH" "$vault_path/"
#                echo "✅ Copied template configuration to new vault."
#            else
#                # Fallback: create an empty directory if the template is not found
#                mkdir -p "$vault_path/.obsidian"
#                echo "⚠️ Template configuration not found. Created empty .obsidian folder."
#            fi
#        fi
#
#        # 4. Update Global Config JSON
#        if [ ! -f "$config_file" ]; then
#            mkdir -p "$(dirname "$config_file")"
#            echo '{"vaults":{}}' > "$config_file"
#        fi
#        
#        local jq_script='.vaults += {
#            ($id): {
#                "path": $path,
#                "ts": ($ts | tonumber),
#                "open": true
#            }
#        } | .lastOpenVault = $id'
#
#        jq --arg id "$vault_id" \
#           --arg path "$vault_path" \
#           --arg ts "$timestamp_ms" \
#           "$jq_script" \
#           "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
#
#    else
#        echo "Vault already registered (ID: $registered_vault_id). Launching directly..."
#        vault_id="$registered_vault_id" # Use existing ID for launch
#    fi
#    
#    # 5. Launch Obsidian using the Vault ID in the URI
#    
#    local encoded_id=$(perl -MURI::Escape -e 'print uri_escape($ARGV[0])' "$vault_id")
#    
#    echo "Launching permanent vault..."
#    open "obsidian://open?vault=$encoded_id"
#}
#








#Function for opening a current folder as a temp vault that always get overwritten for each new ephemeral inspection.

#Type: md_open ./file.md 
# to open a new temp vault for viewing/editing the readme file. 
# Run md_cleanup $PWD to remove references of this vault registration (so that don't have a larege number of registered temp vaults)


function obsidian_tmp() {
    
    # 1. Determine Source and Vault Directory (Use PWD)
    local vault_dir="$(pwd)" 
    
    # Look for the first markdown file to open
    local source_file=""
    if [ -f "README.md" ]; then
        source_file="$(realpath "README.md")"
    else
        local first_md_file=$(find "$vault_dir" -maxdepth 1 -type f -name "*.md" | head -n 1)
        if [ -n "$first_md_file" ]; then
            source_file="$(realpath "$first_md_file")"
        fi
    fi

    # 1b. Check Dependencies
    local config_file="$HOME/Library/Application Support/obsidian/obsidian.json"
    #local TEMPLATE_CONFIG_PATH="/Users/meillier/Documents/Obsidian/00-Template/.obsidian"
    local TEMPLATE_CONFIG_PATH="/Users/meillier/Documents/00-Template/.obsidian"
    
    if ! command -v jq &> /dev/null; then echo "Error: 'jq' required. Aborting."; return 1; fi
    if ! perl -MURI::Escape -e '1' 2>/dev/null; then echo "Error: perl module URI::Escape required. Aborting."; return 1; fi

    echo "--- Initiating Temporary Obsidian Vault for Current Directory: $vault_dir ---"

    # 2. Check if the directory is registered in Obsidian's global config
    local vault_id=$(jq -r --arg path "$vault_dir" \
        '.vaults | to_entries[] | select(.value.path == $path) | .key' \
        "$config_file" 2>/dev/null)

    # 3. Registration & Configuration Logic
    # We trigger setup if the ID is missing OR if the physical .obsidian folder is gone
    if [[ -z "$vault_id" ]] || [ ! -d "$vault_dir/.obsidian" ]; then
        
        # If the directory is not a persistent vault, set up the template
        if [ ! -d "$vault_dir/.obsidian" ]; then
            echo "No .obsidian folder found. Initializing from template..."
            
            if [ -d "$TEMPLATE_CONFIG_PATH" ]; then
                cp -r "$TEMPLATE_CONFIG_PATH" "$vault_dir/"
                echo "✅ Copied template configuration to: $vault_dir"
            else
                mkdir -p "$vault_dir/.obsidian"
                echo "⚠️ Template configuration not found. Created empty .obsidian folder."
            fi
        else
            echo "Vault config folder exists on disk. Ensuring registration..."
        fi
            
        # Generate/Refresh metadata if needed
        # We reuse the vault_id if it exists, otherwise create a new "TEMP" one
        if [[ -z "$vault_id" ]]; then
            local random_suffix=$(openssl rand -hex 1)
            vault_id="99999999999999${random_suffix}" 
        fi
        
        local timestamp_ms=$(perl -MTime::HiRes -e 'printf "%.0f\n", Time::HiRes::time * 1000')
        
        # Ensure global config file exists
        if [ ! -f "$config_file" ]; then 
            mkdir -p "$(dirname "$config_file")"
            echo '{"vaults":{}}' > "$config_file"
        fi
        
        # Register/Update in obsidian.json
        local jq_script='.vaults += { ($id): { "path": $path, "ts": ($ts | tonumber), "open": true } } | .lastOpenVault = $id'
        jq --arg id "$vault_id" --arg path "$vault_dir" --arg ts "$timestamp_ms" "$jq_script" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"

        # Quit Obsidian (Required for config change to take effect)
        osascript -e 'quit app "Obsidian"' 2>/dev/null
        echo "Closing Obsidian to finalize registration..."
        sleep 2
    else
        echo "Vault already registered and .obsidian folder present. Launching directly."
    fi

    set_folder_icon /Applications/Obsidian.app/Contents/Resources/icon.icns $vault_dir

    # 4. Launch the vault
    local launch_url=""
    local encoded_id=$(perl -MURI::Escape -e 'print uri_escape($ARGV[0])' "$vault_id")

    if [ -n "$source_file" ]; then
        local file_name="$(basename "$source_file")"
        local encoded_file=$(perl -MURI::Escape -e 'print uri_escape($ARGV[0])' "$file_name")
        launch_url="obsidian://open?vault=$encoded_id&file=$encoded_file"
        echo "Launching: $file_name in vault: $vault_dir"
    else
        launch_url="obsidian://open?vault=$encoded_id"
        echo "Launching vault: $vault_dir"
    fi
    
    open "$launch_url"
    
    echo ""
    echo "🚨 ACTION REQUIRED: When done, remember to run your cleanup function."
}








function obsidian_cleanup_pwd() {
    # No argument check needed, as the directory is determined by PWD.
    
    # Set vault_dir to the current working directory (PWD)
    # Using 'pwd' is equivalent to the original 'realpath "$1"' if run from the target dir.
    local vault_dir="$(pwd)" 
    local config_file="$HOME/Library/Application Support/obsidian/obsidian.json"
    
    # Ensure jq is installed
    if ! command -v jq &> /dev/null; then
        echo "Error: 'jq' is required for JSON manipulation. Aborting."
        return 1
    fi
    
    echo "--- Starting Cleanup for Vault in Current Directory: $vault_dir ---"
    
    # 1. Look up the Vault ID based on the directory path
    local vault_id_to_remove=$(jq -r --arg path "$vault_dir" \
        '.vaults | to_entries[] | select(.value.path == $path) | .key' \
        "$config_file" 2>/dev/null)

    # 2. File System Cleanup (Removes the marker)
    if [ -d "$vault_dir/.obsidian" ]; then
        rm -rf "$vault_dir/.obsidian"
        echo "✅ File system clean: Removed temporary .obsidian folder from $vault_dir"
    else
        echo "ℹ️ Note: .obsidian folder not found, skipping file system cleanup."
    fi
    
    # 3. JSON Configuration Cleanup (Removes the reference)
    if [[ -n "$vault_id_to_remove" ]]; then
        # Use jq to delete the key associated with the vault ID
        jq "del(.vaults[\"$vault_id_to_remove\"])" \
            "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
            
        echo "✅ Config clean: Removed vault ID ($vault_id_to_remove) from obsidian.json."
        
        # 4. Quit Obsidian (To force immediate config reload and cleanup of the open window)
        osascript -e 'quit app "Obsidian"' 2>/dev/null
        echo "ℹ️ Obsidian closed to finalize cleanup."
    else
        echo "ℹ️ Vault entry not found in obsidian.json. No config cleanup needed."
    fi

    reset_folder_icon $vault_dir
    
    echo "--- Cleanup Complete. ---"
}









function obsidian_cleanup_alltmp() {
    local config_file="$HOME/Library/Application Support/obsidian/obsidian.json"
    local TEMP_ID_PREFIX="99999999999999"

    if ! command -v jq &> /dev/null; then
        echo "Error: 'jq' is required for JSON manipulation. Aborting."
        return 1
    fi

    echo "--- Initiating Cleanup of Ephemeral Vaults ($TEMP_ID_PREFIX*) ---"
    
    # Use jq to select only the vaults whose keys match the temporary prefix
    local temp_vault_data=$(jq -r --arg prefix "$TEMP_ID_PREFIX" \
        '.vaults | to_entries[] | select(.key | startswith($prefix)) | "\(.value.path),\(.key)"' \
        "$config_file" 2>/dev/null)

    if [ -z "$temp_vault_data" ]; then
        echo "✅ No ephemeral vaults found requiring cleanup."
        return 0
    fi

    echo "$temp_vault_data" | while IFS=, read -r vault_dir vault_id_to_remove; do
        
        echo "Processing Vault: $(basename "$vault_dir") (ID: $vault_id_to_remove)"
        
        # 1. File System Cleanup (Removes the marker)
        if [ -d "$vault_dir/.obsidian" ]; then
            rm -rf "$vault_dir/.obsidian"
            echo "  - ✅ Removed temporary .obsidian folder."
        else
            echo "  - ℹ️ .obsidian folder not found (already cleaned)."
        fi
        
        # 2. JSON Configuration Cleanup (Deletes the entry by ID)
        jq "del(.vaults[\"$vault_id_to_remove\"])" \
            "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
            
        echo "  - ✅ Removed ID from obsidian.json."
    done

    reset_folder_icon $vault_dir

    # 3. Quit Obsidian (To force immediate config reload)
    osascript -e 'quit app "Obsidian"' 2>/dev/null
    echo ""
    echo "✨ Complete. All identified ephemeral vaults have been cleaned up and Obsidian closed."
}















## Function to list vaults

function obsidian_vaults() {
    local config_file="$HOME/Library/Application Support/obsidian/obsidian.json"
    local sort_by_path=0

    # 1. Check for the -s flag
    if [[ "$1" == "-s" ]]; then
        sort_by_path=1
        echo "Sorting by Path..."
    fi
    
    # Check dependencies
    if [ ! -f "$config_file" ]; then
        echo "Error: Obsidian configuration file not found at $config_file"
        return 1
    fi
    if ! command -v jq &> /dev/null; then
        echo "Error: 'jq' command not found. Please ensure it is installed."
        return 1
    fi

    echo "--- Obsidian Vaults ---"
    
    # --- Corrected jq logic ---
    local jq_query='
        .vaults | to_entries | 
        # 1. Map to create a simpler, more sortable structure
        map({
            id: .key,
            path: .value.path,
            ts_raw: .value.ts,
            ts_formatted: (.value.ts / 1000 | todate),
            open: (.value.open // false)
        })
    '

    # 2. Conditional Sorting Step
    if [[ $sort_by_path -eq 1 ]]; then
        # If sorting, apply sort_by to the array of objects
        jq_query+=' | sort_by(.path)'
    fi
    
    # 3. Final Output Formatting (Applied to each element in the array)
    jq_query+=' | .[] | 
        "ID: \( .id ) | Path: \( .path ) | Last Opened: \( .ts_formatted ) | Open: \( .open )"
    '
    
    # 4. Execute jq and format with column
    jq -r "$jq_query" "$config_file" | column -t -s '|'
}


function obsidian_cleanup_id() {
    # 1. Input Validation
    if [ -z "$1" ]; then
        echo "Error: Vault ID is required as the first argument."
        echo "Usage: md_cleanup_specific <Vault_ID>"
        return 1
    fi

    local vault_id_to_remove="$1"
    local config_file="$HOME/Library/Application Support/obsidian/obsidian.json"

    if ! command -v jq &> /dev/null; then
        echo "Error: 'jq' is required for JSON manipulation. Aborting."
        return 1
    fi

    echo "--- Initiating Cleanup for Specific Vault ID: $vault_id_to_remove ---"
    
    # 2. Extract Vault Path from JSON
    # Use jq to get the path of the specific vault ID
    local vault_dir=$(jq -r --arg id "$vault_id_to_remove" \
        '.vaults[$id].path' \
        "$config_file" 2>/dev/null)

    # Check if the vault ID exists in the configuration
    if [ -z "$vault_dir" ] || [ "$vault_dir" = "null" ]; then
        echo "❌ Vault ID '$vault_id_to_remove' not found in $config_file."
        return 2
    fi
    
    # 3. Perform Cleanup Actions
    echo "Processing Vault Path: $vault_dir"
    
    # 3a. File System Cleanup (Removes the .obsidian folder)
    if [ -d "$vault_dir/.obsidian" ]; then
        #read -r -p "⚠️ Confirm removal of the **.obsidian folder** at '$vault_dir/.obsidian' (y/N)? " confirmation
        read "confirmation?⚠️ Confirm removal of the **.obsidian folder** at '$vault_dir/.obsidian' (y/N)? "
        if [[ "$confirmation" =~ ^[Yy]$ ]]; then
            rm -rf "$vault_dir/.obsidian"
            echo " - ✅ Removed .obsidian folder."
        else
            echo " - ⏭️ Skipped removal of .obsidian folder."
        fi
    else
        echo " - ℹ️ .obsidian folder not found at path (already cleaned or never existed)."
    fi
    
    # 3b. JSON Configuration Cleanup (Deletes the entry by ID)
    #read -r -p "⚠️ Confirm removal of Vault ID **'$vault_id_to_remove'** from $config_file (y/N)? " confirmation_json
    read "confirmation_json?⚠️ Confirm removal of Vault ID **'$vault_id_to_remove'** from $config_file (y/N)? "
    if [[ "$confirmation_json" =~ ^[Yy]$ ]]; then
        jq "del(.vaults[\"$vault_id_to_remove\"])" \
            "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
        echo " - ✅ Removed ID from obsidian.json."
    else
        echo " - ⏭️ Skipped removal of Vault ID from obsidian.json."
    fi

    reset_folder_icon $vault_dir

    # 4. Quit Obsidian (To force immediate config reload)
    osascript -e 'quit app "Obsidian"' 2>/dev/null
    echo ""
    echo "✨ Complete. Cleanup for Vault ID '$vault_id_to_remove' finished and Obsidian closed."
}













# Function to initialize a new Git repository, commit files, 
# and create a corresponding public GitHub repository.
# Usage: gitinitpub

gitinitpub() {
    local REPO_NAME="$1"
    local VISIBILITY_FLAG=""
    local CHOICE=""

    # --- 1. FETCH GITHUB USERNAME ---
    local GH_USER
    GH_USER=$(gh api user --jq .login 2>/dev/null)

    if [ -z "$GH_USER" ]; then
        echo "🚨 Error: Could not determine GitHub username. Run 'gh auth login'."
        return 1
    fi

    # --- 2. REPOSITORY NAME CHECK & PROMPT ---
    if [ -z "$REPO_NAME" ]; then
        echo "------------------------------------------------------"
        echo "Listing your 10 most recent GitHub repos for reference:"
        gh repo list --limit 10
        echo "------------------------------------------------------"

        # Zsh-friendly prompt logic
        while [ -z "$REPO_NAME" ]; do
            printf "❓ Enter the name for your new repository: "
            read REPO_NAME
            if [ -z "$REPO_NAME" ]; then
                echo "❌ Error: Repository name cannot be empty."
            fi
        done
    fi

    # --- 3. ASK FOR VISIBILITY ---
    while true; do
        printf "❓ Create as Public or Private? [pub/priv]: "
        read CHOICE
        case "$CHOICE" in
            [Pp]ub* ) VISIBILITY_FLAG="--public"; break;;
            [Pp]riv* ) VISIBILITY_FLAG="--private"; break;;
            * ) echo "Please answer 'pub' or 'priv'.";;
        esac
    done

    echo "🚀 Starting initialization for '$REPO_NAME'..."

    # --- 4. LOCAL GIT INIT ---
    git init
    if [ $? -ne 0 ]; then
        echo "Error: git init failed."
        return 1
    fi

    # --- 5. .GITIGNORE LOGIC ---
    if [ ! -f .gitignore ]; then
        echo ".obsidian/" > .gitignore
        echo "📝 Created .gitignore with .obsidian/."
    elif ! grep -q ".obsidian/" .gitignore; then
        echo ".obsidian/" >> .gitignore
        echo "📝 Added .obsidian/ to existing .gitignore."
    fi

    # --- 6. INITIAL COMMIT ---
    git add .
    git commit -m "Initial commit"

    # --- 7. CREATE REMOTE AND PUSH ---
    echo "📦 Creating $VISIBILITY_FLAG GitHub repository..."
    gh repo create "$REPO_NAME" $VISIBILITY_FLAG --source=. --remote=origin --push

    if [ $? -eq 0 ]; then
        local REPO_URL="https://github.com/$GH_USER/$REPO_NAME"
        local ICON="🔓"
        [[ "$VISIBILITY_FLAG" == "--private" ]] && ICON="🔒"

        echo -e "\n$ICON **Success!** '$REPO_NAME' is live."
        echo "🔗 URL: $REPO_URL"
    else
        echo "❌ Error: GitHub repository creation/push failed."
    fi
} 




#function to open vscode using the template extensions.json and settings .json from my template vscode /Users/meillier/Documents/06-vscode/00-Template.
vscode() {
  # --- CUSTOMIZE THIS PATH ---
  # Define the path to your template .vscode folder
  #TEMPLATE_DIR="/Users/meillier/Documents/06-vscode/00-Template/.vscode"  
  #TEMPLATE_DIR="/Users/meillier/Documents/Obsidian/00-Template/.vscode" 
  TEMPLATE_DIR="/Users/meillier/Documents/00-Template/.vscode" 
  # Define the target directory inside the current project
  TARGET_DIR=".vscode"

  # Check if the template directory exists
  if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "Error: Template directory not found at $TEMPLATE_DIR"
    echo "Please create the template directory and files first."
    return 1
  fi

  # Check if the .vscode directory already exists in the current location
  if [ -d "$TARGET_DIR" ]; then
    echo "Warning: .vscode directory already exists in the current project."
  else
    # Copy the entire template .vscode directory to the current project
    cp -r "$TEMPLATE_DIR" "$TARGET_DIR"
    echo "Copied VS Code template configuration to: $PWD/$TARGET_DIR"
  fi

  # Launch VS Code in the current directory
  code .
}










# xmind function top open
xmind() {
  local xmind_files=($(find . -maxdepth 1 -type f -name "*.xmind"))
  local num_files=${#xmind_files[@]}

  if [ "$num_files" -eq 0 ]; then
    echo "No .xmind files found in the current directory."
  elif [ "$num_files" -eq 1 ]; then
    echo "Opening ${xmind_files[0]}..."
    open "${xmind_files[0]}"
  else
    echo "Multiple .xmind files found:"
    for i in "${!xmind_files[@]}"; do
      echo "$((i+1))) ${xmind_files[$i]}"
    done

    local choice
    while true; do
      read -p "Enter the number of the file to open: " choice
      if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$num_files" ]; then
        echo "Opening ${xmind_files[$((choice-1))]}..."
        open "${xmind_files[$((choice-1))]}"
        break
      else
        echo "Invalid choice. Please enter a number between 1 and $num_files."
      fi
    done
  fi
}



#Antigravity
agy() {
    # Opens Antigravity.app found in /Applications
    open -a "Antigravity" .
}
antigravity() {
    # Opens Antigravity.app found in /Applications
    open -a "Antigravity" .
}




# Function to automate add, commit, and push
gitpush() {
    git add .
    git commit -m "gitpush"
    git push origin main
}


gkebaselab() {
    # Ask for confirmation
    echo -n "https://github.com/ymeillier/00-prototpying-templates "
    echo -n "Are you sure you want to initialize a new lab in $(pwd)? (y/n): "
    read confirmation
    

    # Check the response (accepts y, Y, yes, or Yes)
    if [[ "$confirmation" =~ ^[Yy](es)?$ ]]; then
        echo "Proceeding with setup..."
        
        # 1. Clone the template repository
        git clone git@github.com:ymeillier/00-prototpying-templates.git .

        # 2. Remove the existing git history (corrected from -tf to -rf)
        rm -rf .git

        # 3. Refresh the README
        rm README.md
        touch README.md

        # 4. Move the specific directories up to the root
        mv gke/01-base-setup/gcloud .
        mv gke/01-base-setup/tf .
        mv .antigravity/* .
        mv .vscode .

        # 5. Clean up the now-empty/unneeded gke directory
        rm -rf gke/

        # 6. Open the current directory in VS Code
        code .
        
        echo "Setup complete!"
    else
        echo "Operation cancelled. No changes were made."
        return 1
    fi
}

gitaddcommitpush() {
    git status -s
    
    # 1. Cross-shell prompt logic
    if [ -n "$ZSH_VERSION" ]; then
        # Zsh specific read
        read -q "choice?Do you want to proceed? (y/n) "
    else
        # Bash specific read
        read -r -n 1 -p "Do you want to proceed? (y/n) " choice
    fi
    
    echo "" # New line for cleanliness

    # 2. Check the response
    # In Zsh, 'read -q' sets the exit status directly
    # In Bash, we check the 'choice' variable
    if [[ "$choice" == "y" || "$choice" == "Y" ]] || [ $? -eq 0 ]; then
        git add . && \
        git commit -m 'lazy commit message from gitaddcommitpush()' && \
        git push origin main
    else
        echo "Operation aborted."
        return 1
    fi
}
