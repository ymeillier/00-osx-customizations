
# Applications
## iTerm2

To replace OSX default terminal which does not support split panes but only tabs.

```
brew install --cask iterm2
```


| **Split Direction**  | **Menu Path**                                        | **Keyboard Shortcut**                                     |
| -------------------- | ---------------------------------------------------- | --------------------------------------------------------- |
| **Horizontal Split** | Shell > New Split Pane > **Split Pane Horizontally** | **Command** ($\text{⌘}$) + **D**                          |
| **Vertical Split**   | Shell > New Split Pane > **Split Pane Vertically**   | **Command** ($\text{⌘}$) + **Shift** ($\text{⇧}$) + **D** |

# zshrc
This page shows the zshrc customization i use on my mac a number of workflow optimizations for obsidian, vscode, and github 


# Current (10/14/2025)


```bash
export GEMINI_API_KEY=""
export GITHUB_MCP_TOKEN=''


# === LS Color Configuration for macOS (Darwin) ===

# 1. Enable CLICOLOR for color output in ls
export CLICOLOR=1

# 2. Alias 'ls' to use the -G flag (the macOS/BSD color flag)
alias ls='ls -G'

# 3. Alias 'll' to show long list format with colors
alias ll='ls -lG'


# Obsidian

##alias obsidian='open -a "Obsidian"'
#open -n -a "Obsidian" "$vault_path"


#For permanent vault access or creation.
#Just type obsidian while in your vault directory.IT will either create a new vault or open the existing one.




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



function obsidian() {
    # --- Dependencies Check ---
    if ! command -v jq &> /dev/null; then
        echo "Error: 'jq' is required for JSON manipulation. Aborting."
        return 1
    fi

    # --- Configuration ---
    local vault_path="$PWD"
    local config_file="$HOME/Library/Application Support/obsidian/obsidian.json"
    # Define your template source path
    local TEMPLATE_CONFIG_PATH="/Users/meillier/Documents/Obsidian/00-Template/.obsidian"
    
    # Check registration (Idempotence)
    local registered_vault_id=$(jq -r --arg path "$vault_path" \
        '.vaults | to_entries[] | select(.value.path == $path) | .key' \
        "$config_file" 2>/dev/null)

    # 1. Registration Block
    if [[ -z "$registered_vault_id" ]]; then
        
        # --- Prompt and Quit Check ---
        echo "A new permanent vault must be registered. This requires closing all open Obsidian windows."
        read -r -p "Is it OK to close all existing Obsidian windows? (y/N) " response
        
        if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo "❌ CANCELED: Please create the new vault manually using the Vault Switcher."
            return 1
        fi
        
        # Quit Obsidian (Crucial for forcing config reload) 🛑
        osascript -e 'quit app "Obsidian"' 2>/dev/null
        echo "Closing running Obsidian instances..."
        sleep 2
        
        # 2. Prompt for Vault Name and Generate Metadata
        read -p "Enter a name for the new permanent vault: " vault_name
        if [[ -z "$vault_name" ]]; then
            echo "Vault name cannot be empty. Aborting."
            return 1
        fi
        
        # Generate ID and Timestamp
        local vault_id=$(openssl rand -hex 8)
        local timestamp_ms=$(perl -MTime::HiRes -e 'printf "%.0f\n", Time::HiRes::time * 1000')

        # 3. CRITICAL FIX: Copy Template Configuration 
        if [ ! -d "$vault_path/.obsidian" ]; then
            if [ -d "$TEMPLATE_CONFIG_PATH" ]; then
                # Copy the entire .obsidian contents from the template
                cp -r "$TEMPLATE_CONFIG_PATH" "$vault_path/"
                echo "✅ Copied template configuration to new vault."
            else
                # Fallback: create an empty directory if the template is not found
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

    else
        echo "Vault already registered (ID: $registered_vault_id). Launching directly..."
        vault_id="$registered_vault_id" # Use existing ID for launch
    fi
    
    # 5. Launch Obsidian using the Vault ID in the URI
    
    local encoded_id=$(perl -MURI::Escape -e 'print uri_escape($ARGV[0])' "$vault_id")
    
    echo "Launching permanent vault..."
    open "obsidian://open?vault=$encoded_id"
}









#Function for opening a current folder as a temp vault that always get overwritten for each new ephemeral inspection.

#Type: md_open ./file.md 
# to open a new temp vault for viewing/editing the readme file. 
# Run md_cleanup $PWD to remove references of this vault registration (so that don't have a larege number of registered temp vaults)


function obsidian_tmp() {
    
    # 1. Determine Source and Vault Directory (Use PWD)
    # The 'vault_dir' is the current working directory.
    local vault_dir="$(pwd)" 
    
    # The 'source_file' is now derived from the first .md file found,
    # or you can simply target the vault_dir for launching.
    # We will look for the first markdown file to open, defaulting to a common one.
    local source_file=""
    if [ -f "README.md" ]; then
        source_file="$(realpath "README.md")"
    else
        # Find the first .md file, if any
        local first_md_file=$(find "$vault_dir" -maxdepth 1 -type f -name "*.md" | head -n 1)
        if [ -n "$first_md_file" ]; then
            source_file="$(realpath "$first_md_file")"
        fi
    fi

    # 1b. Check Dependencies
    local config_file="$HOME/Library/Application Support/obsidian/obsidian.json"
    local TEMPLATE_CONFIG_PATH="/Users/meillier/Documents/Obsidian/00-Template/.obsidian"
    
    if ! command -v jq &> /dev/null; then echo "Error: 'jq' required. Aborting."; return 1; fi
    if ! perl -MURI::Escape -e '1' 2>/dev/null; then echo "Error: perl module URI::Escape required. Aborting."; return 1; fi

    echo "--- Initiating Temporary Obsidian Vault for Current Directory: $vault_dir ---"

    # 2. Check if the directory is already registered (Idempotence)
    local vault_id=$(jq -r --arg path "$vault_dir" \
        '.vaults | to_entries[] | select(.value.path == $path) | .key' \
        "$config_file" 2>/dev/null)

    # 3. Registration (Modified to use the fixed ID prefix)
    if [[ -z "$vault_id" ]]; then
        # Check for existing .obsidian folder (don't overwrite a persistent vault)
        if [ -d "$vault_dir/.obsidian" ]; then
             echo "Vault config already exists in the repo. Launching directly."
        else
            echo "Creating temporary vault configuration in: $vault_dir"
            
            # --- CRITICAL CHANGE FOR TEMPLATE COPY ---
            if [ -d "$TEMPLATE_CONFIG_PATH" ]; then
                # Copy the entire .obsidian contents from the template
                cp -r "$TEMPLATE_CONFIG_PATH" "$vault_dir/"
                echo "✅ Copied template configuration to new vault."
            else
                # Fallback: create an empty directory if the template is not found
                mkdir -p "$vault_dir/.obsidian"
                echo "⚠️ Template configuration not found. Created empty .obsidian folder."
            fi
            # --- END CRITICAL CHANGE ---
            
            # Generate new metadata
            local vault_name="$(basename "$vault_dir")-TEMP"
            local random_suffix=$(openssl rand -hex 1) # Gets 2 hex characters
            vault_id="99999999999999${random_suffix}" # Unique ID with cleanup marker
            local timestamp_ms=$(perl -MTime::HiRes -e 'printf "%.0f\n", Time::HiRes::time * 1000')
            
            # Ensure config file exists
            if [ ! -f "$config_file" ]; then mkdir -p "$(dirname "$config_file")"; echo '{"vaults":{}}' > "$config_file"; fi
            
            # Register in obsidian.json
            local jq_script='.vaults += { ($id): { "path": $path, "ts": ($ts | tonumber), "open": true } } | .lastOpenVault = $id'
            jq --arg id "$vault_id" --arg path "$vault_dir" --arg ts "$timestamp_ms" "$jq_script" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"

            # Quit Obsidian (Required for config change)
            osascript -e 'quit app "Obsidian"' 2>/dev/null
            echo "Closing running Obsidian instances to finalize registration..."
            sleep 2
        fi
    fi

    # 4. Launch the vault, and optionally a specific file
    local launch_url=""
    local encoded_id=$(perl -MURI::Escape -e 'print uri_escape($ARGV[0])' "$vault_id")

    if [ -n "$source_file" ]; then
        local file_name="$(basename "$source_file")"
        local encoded_file=$(perl -MURI::Escape -e 'print uri_escape($ARGV[0])' "$file_name")
        launch_url="obsidian://open?vault=$encoded_id&file=$encoded_file"
        echo "Launching specific file: $file_name in ephemeral vault: $vault_dir"
    else
        launch_url="obsidian://open?vault=$encoded_id"
        echo "Launching ephemeral vault: $vault_dir"
    fi
    
    open "$launch_url"
    
    echo ""
    echo "🚨 ACTION REQUIRED: When done, manually run a cleanup function like: obsidian_cleanup_pwd(), obsidian_cleanup_id() or obsidian_cleanup_alltmp()"
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
        read -r -p "⚠️ Confirm removal of the **.obsidian folder** at '$vault_dir/.obsidian' (y/N)? " confirmation
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
    read -r -p "⚠️ Confirm removal of Vault ID **'$vault_id_to_remove'** from $config_file (y/N)? " confirmation_json
    if [[ "$confirmation_json" =~ ^[Yy]$ ]]; then
        jq "del(.vaults[\"$vault_id_to_remove\"])" \
            "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
        echo " - ✅ Removed ID from obsidian.json."
    else
        echo " - ⏭️ Skipped removal of Vault ID from obsidian.json."
    fi

    # 4. Quit Obsidian (To force immediate config reload)
    osascript -e 'quit app "Obsidian"' 2>/dev/null
    echo ""
    echo "✨ Complete. Cleanup for Vault ID '$vault_id_to_remove' finished and Obsidian closed."
}













# Function to initialize a new Git repository, commit files, 
# and create a corresponding public GitHub repository.
# Usage: gitinitpub <REPO-NAME>


gitinitpub() {
    local REPO_NAME="$1"
    
    # --- FETCH GITHUB USERNAME (ROBUST FIX) ---
    local GH_USER
    # Use 'gh api user' to reliably get the username in JSON format
    GH_USER=$(gh api user --jq .login 2>/dev/null)

    if [ -z "$GH_USER" ]; then
        echo "🚨 Error: Could not determine GitHub username."
        echo "Please ensure you are authenticated with 'gh auth login' and the 'gh api' command is working."
        return 1
    fi
    # -----------------------------

    # ... (Rest of your script remains the same) ...

    # Check if a repository name was provided
    if [ -z "$REPO_NAME" ]; then
        echo "🚨 Repository name not provided.**"
        echo "------------------------------------------------------"
        echo "Listing your top 1000 remote GitHub repositories for reference:"
        
        gh repo list --limit 1000
        
        echo "------------------------------------------------------"
        read -p "Please enter the repository name you wish to use: " REPO_NAME
        
        if [ -z "$REPO_NAME" ]; then
            echo "Operation canceled: No repository name provided."
            return 1
        fi
    fi
    
    echo "Starting git initialization for '$REPO_NAME'..."

    git init
    if [ $? -ne 0 ]; then 
        echo "Error: git init failed."
        return 1
    fi

    git add .
    git commit -m "Initial commit of project files"
    
    echo "Creating public GitHub repository and pushing initial commit..."
    gh repo create "$REPO_NAME" --public --source=. --push

    if [ $? -eq 0 ]; then
        local REPO_URL="https://github.com/$GH_USER/$REPO_NAME"
        
        echo " "
        echo "🎉 **Success!** Repository '$REPO_NAME' initialized, committed, and pushed to GitHub."
        echo "🔗 **Repository URL:** $REPO_URL"
        echo " "
    else
        echo "Error: GitHub repository creation/push failed. Check 'gh' CLI authentication and permissions."
    fi
}









#function to open vscode using the template extensions.json and settings .json from my template vscode /Users/meillier/Documents/06-vscode/00-Template.
vscode() {
  # --- CUSTOMIZE THIS PATH ---
  # Define the path to your template .vscode folder
  TEMPLATE_DIR="/Users/meillier/Documents/06-vscode/00-Template/.vscode"  
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
```

# github

## gitinitpub() "repo"

See the git repo [https://github.com/ymeillier/00-NewRepo](https://github.com/ymeillier/00-NewRepo)

I have created bash functions to easily initialize the current directory as a local git repository, create a remote repo on github and commit to it.

```bash
gitinitpub() {
    local REPO_NAME="$1"
    
    # --- FETCH GITHUB USERNAME (ROBUST FIX) ---
    local GH_USER
    # Use 'gh api user' to reliably get the username in JSON format
    GH_USER=$(gh api user --jq .login 2>/dev/null)

    if [ -z "$GH_USER" ]; then
        echo "🚨 Error: Could not determine GitHub username."
        echo "Please ensure you are authenticated with 'gh auth login' and the 'gh api' command is working."
        return 1
    fi
    # -----------------------------

    # ... (Rest of your script remains the same) ...

    # Check if a repository name was provided
    if [ -z "$REPO_NAME" ]; then
        echo "🚨 Repository name not provided.**"
        echo "------------------------------------------------------"
        echo "Listing your top 1000 remote GitHub repositories for reference:"
        
        gh repo list --limit 1000
        
        echo "------------------------------------------------------"
        read -p "Please enter the repository name you wish to use: " REPO_NAME
        
        if [ -z "$REPO_NAME" ]; then
            echo "Operation canceled: No repository name provided."
            return 1
        fi
    fi
    
    echo "Starting git initialization for '$REPO_NAME'..."

    git init
    if [ $? -ne 0 ]; then 
        echo "Error: git init failed."
        return 1
    fi

    git add .
    git commit -m "Initial commit of project files"
    
    echo "Creating public GitHub repository and pushing initial commit..."
    gh repo create "$REPO_NAME" --public --source=. --push

    if [ $? -eq 0 ]; then
        local REPO_URL="https://github.com/$GH_USER/$REPO_NAME"
        
        echo " "
        echo "🎉 **Success!** Repository '$REPO_NAME' initialized, committed, and pushed to GitHub."
        echo "🔗 **Repository URL:** $REPO_URL"
        echo " "
    else
        echo "Error: GitHub repository creation/push failed. Check 'gh' CLI authentication and permissions."
    fi
}
```



# obsidian
See [https://github.com/ymeillier/00-obsidian-template/blob/main/Template.md](https://github.com/ymeillier/00-obsidian-template/blob/main/Template.md)



## obsidian()
```bash
function obsidian() {
    # --- Dependencies Check ---
    if ! command -v jq &> /dev/null; then
        echo "Error: 'jq' is required for JSON manipulation. Aborting."
        return 1
    fi

    # --- Configuration ---
    local vault_path="$PWD"
    local config_file="$HOME/Library/Application Support/obsidian/obsidian.json"
    # Define your template source path
    local TEMPLATE_CONFIG_PATH="/Users/meillier/Documents/Obsidian/00-Template/.obsidian"
    
    # Check registration (Idempotence)
    local registered_vault_id=$(jq -r --arg path "$vault_path" \
        '.vaults | to_entries[] | select(.value.path == $path) | .key' \
        "$config_file" 2>/dev/null)

    # 1. Registration Block
    if [[ -z "$registered_vault_id" ]]; then
        
        # --- Prompt and Quit Check ---
        echo "A new permanent vault must be registered. This requires closing all open Obsidian windows."
        read -r -p "Is it OK to close all existing Obsidian windows? (y/N) " response
        
        if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo "❌ CANCELED: Please create the new vault manually using the Vault Switcher."
            return 1
        fi
        
        # Quit Obsidian (Crucial for forcing config reload) 🛑
        osascript -e 'quit app "Obsidian"' 2>/dev/null
        echo "Closing running Obsidian instances..."
        sleep 2
        
        # 2. Prompt for Vault Name and Generate Metadata
        read -p "Enter a name for the new permanent vault: " vault_name
        if [[ -z "$vault_name" ]]; then
            echo "Vault name cannot be empty. Aborting."
            return 1
        fi
        
        # Generate ID and Timestamp
        local vault_id=$(openssl rand -hex 8)
        local timestamp_ms=$(perl -MTime::HiRes -e 'printf "%.0f\n", Time::HiRes::time * 1000')

        # 3. CRITICAL FIX: Copy Template Configuration 
        if [ ! -d "$vault_path/.obsidian" ]; then
            if [ -d "$TEMPLATE_CONFIG_PATH" ]; then
                # Copy the entire .obsidian contents from the template
                cp -r "$TEMPLATE_CONFIG_PATH" "$vault_path/"
                echo "✅ Copied template configuration to new vault."
            else
                # Fallback: create an empty directory if the template is not found
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

    else
        echo "Vault already registered (ID: $registered_vault_id). Launching directly..."
        vault_id="$registered_vault_id" # Use existing ID for launch
    fi
    
    # 5. Launch Obsidian using the Vault ID in the URI
    
    local encoded_id=$(perl -MURI::Escape -e 'print uri_escape($ARGV[0])' "$vault_id")
    
    echo "Launching permanent vault..."
    open "obsidian://open?vault=$encoded_id"
}


```

## obsidian_cleanup_alltmp()
```bash
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

    # 3. Quit Obsidian (To force immediate config reload)
    osascript -e 'quit app "Obsidian"' 2>/dev/null
    echo ""
    echo "✨ Complete. All identified ephemeral vaults have been cleaned up and Obsidian closed."
}

```

## obsidian_cleanup_id()

```bash
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
        read -r -p "⚠️ Confirm removal of the **.obsidian folder** at '$vault_dir/.obsidian' (y/N)? " confirmation
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
    read -r -p "⚠️ Confirm removal of Vault ID **'$vault_id_to_remove'** from $config_file (y/N)? " confirmation_json
    if [[ "$confirmation_json" =~ ^[Yy]$ ]]; then
        jq "del(.vaults[\"$vault_id_to_remove\"])" \
            "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
        echo " - ✅ Removed ID from obsidian.json."
    else
        echo " - ⏭️ Skipped removal of Vault ID from obsidian.json."
    fi

    # 4. Quit Obsidian (To force immediate config reload)
    osascript -e 'quit app "Obsidian"' 2>/dev/null
    echo ""
    echo "✨ Complete. Cleanup for Vault ID '$vault_id_to_remove' finished and Obsidian closed."
}
```

## obsidian_cleanup_pwd()

```bash

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
    
    echo "--- Cleanup Complete. ---"
}


```


## obsidian_tmp()

```bash
#Function for opening a current folder as a temp vault that always get overwritten for each new ephemeral inspection.

#Type: md_open ./file.md 
# to open a new temp vault for viewing/editing the readme file. 
# Run md_cleanup $PWD to remove references of this vault registration (so that don't have a larege number of registered temp vaults)


function obsidian_tmp() {
    
    # 1. Determine Source and Vault Directory (Use PWD)
    # The 'vault_dir' is the current working directory.
    local vault_dir="$(pwd)" 
    
    # The 'source_file' is now derived from the first .md file found,
    # or you can simply target the vault_dir for launching.
    # We will look for the first markdown file to open, defaulting to a common one.
    local source_file=""
    if [ -f "README.md" ]; then
        source_file="$(realpath "README.md")"
    else
        # Find the first .md file, if any
        local first_md_file=$(find "$vault_dir" -maxdepth 1 -type f -name "*.md" | head -n 1)
        if [ -n "$first_md_file" ]; then
            source_file="$(realpath "$first_md_file")"
        fi
    fi

    # 1b. Check Dependencies
    local config_file="$HOME/Library/Application Support/obsidian/obsidian.json"
    local TEMPLATE_CONFIG_PATH="/Users/meillier/Documents/Obsidian/00-Template/.obsidian"
    
    if ! command -v jq &> /dev/null; then echo "Error: 'jq' required. Aborting."; return 1; fi
    if ! perl -MURI::Escape -e '1' 2>/dev/null; then echo "Error: perl module URI::Escape required. Aborting."; return 1; fi

    echo "--- Initiating Temporary Obsidian Vault for Current Directory: $vault_dir ---"

    # 2. Check if the directory is already registered (Idempotence)
    local vault_id=$(jq -r --arg path "$vault_dir" \
        '.vaults | to_entries[] | select(.value.path == $path) | .key' \
        "$config_file" 2>/dev/null)

    # 3. Registration (Modified to use the fixed ID prefix)
    if [[ -z "$vault_id" ]]; then
        # Check for existing .obsidian folder (don't overwrite a persistent vault)
        if [ -d "$vault_dir/.obsidian" ]; then
             echo "Vault config already exists in the repo. Launching directly."
        else
            echo "Creating temporary vault configuration in: $vault_dir"
            
            # --- CRITICAL CHANGE FOR TEMPLATE COPY ---
            if [ -d "$TEMPLATE_CONFIG_PATH" ]; then
                # Copy the entire .obsidian contents from the template
                cp -r "$TEMPLATE_CONFIG_PATH" "$vault_dir/"
                echo "✅ Copied template configuration to new vault."
            else
                # Fallback: create an empty directory if the template is not found
                mkdir -p "$vault_dir/.obsidian"
                echo "⚠️ Template configuration not found. Created empty .obsidian folder."
            fi
            # --- END CRITICAL CHANGE ---
            
            # Generate new metadata
            local vault_name="$(basename "$vault_dir")-TEMP"
            local random_suffix=$(openssl rand -hex 1) # Gets 2 hex characters
            vault_id="99999999999999${random_suffix}" # Unique ID with cleanup marker
            local timestamp_ms=$(perl -MTime::HiRes -e 'printf "%.0f\n", Time::HiRes::time * 1000')
            
            # Ensure config file exists
            if [ ! -f "$config_file" ]; then mkdir -p "$(dirname "$config_file")"; echo '{"vaults":{}}' > "$config_file"; fi
            
            # Register in obsidian.json
            local jq_script='.vaults += { ($id): { "path": $path, "ts": ($ts | tonumber), "open": true } } | .lastOpenVault = $id'
            jq --arg id "$vault_id" --arg path "$vault_dir" --arg ts "$timestamp_ms" "$jq_script" "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"

            # Quit Obsidian (Required for config change)
            osascript -e 'quit app "Obsidian"' 2>/dev/null
            echo "Closing running Obsidian instances to finalize registration..."
            sleep 2
        fi
    fi

    # 4. Launch the vault, and optionally a specific file
    local launch_url=""
    local encoded_id=$(perl -MURI::Escape -e 'print uri_escape($ARGV[0])' "$vault_id")

    if [ -n "$source_file" ]; then
        local file_name="$(basename "$source_file")"
        local encoded_file=$(perl -MURI::Escape -e 'print uri_escape($ARGV[0])' "$file_name")
        launch_url="obsidian://open?vault=$encoded_id&file=$encoded_file"
        echo "Launching specific file: $file_name in ephemeral vault: $vault_dir"
    else
        launch_url="obsidian://open?vault=$encoded_id"
        echo "Launching ephemeral vault: $vault_dir"
    fi
    
    open "$launch_url"
    
    echo ""
    echo "🚨 ACTION REQUIRED: When done, manually run a cleanup function like: md_cleanup_all"
}

```

## obsidian_vaults() (-s)

```bash
#!/bin/bash

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



```







# tab complete

[https://github.com/ymeillier/043-obsidian-template/blob/main/scripts/tab-complete.md](https://github.com/ymeillier/043-obsidian-template/blob/main/scripts/tab-complete.md)

Tab complete for obsidian commands:

```bash
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


```
