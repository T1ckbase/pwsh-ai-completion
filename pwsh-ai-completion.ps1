$configDir = Join-Path $HOME ".config\pwsh-ai-completion"
$configPath = Join-Path $configDir "config.json"
$scriptName = $MyInvocation.MyCommand.Name

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "[$scriptName] Requires PowerShell 7.0 or later"
    exit 1
}

if (-not (Test-Path $configPath)) {
    Write-Host "[$scriptName] Config file not found at '$configPath'" -ForegroundColor Yellow
    try {
        if (-not (Test-Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
    } catch {
        Write-Error "[$scriptName] Failed to create config directory '$configDir': $($_.Exception.Message)"
        exit 1
    }

    try {
        $defaultConfig = @{
            api_key = "YOUR_API_KEY_HERE"
            api_url = "https://api.openai.com/v1 | https://generativelanguage.googleapis.com/v1beta/openai"
            model = "gpt-4.1-nano | gemini-2.5-flash-lite"
            temperature = 1
            default_history_count = 3
        }
        Write-Host "[$scriptName] Creating default config file at '$configPath'..." -ForegroundColor Yellow
        $defaultConfig | ConvertTo-Json -Depth 100 | Set-Content -Path $configPath -Encoding utf8NoBOM -ErrorAction Stop
        Write-Host "[$scriptName] Default config file created at '$configPath'" -ForegroundColor Green
    } catch {
        Write-Error "[$scriptName] Failed to create config file '$configPath': $($_.Exception.Message)"
        exit 1
    }
}

$systemPrompt = @"
You are a specialized AI assistant functioning as an expert PowerShell command generator. Your sole purpose is to translate a user's natural language query into a single, precise, and executable PowerShell command.

**Strict Rules of Operation:**
1.  **Command Only:** Your entire response MUST be the raw PowerShell command and nothing else.
2.  **No Markdown:** You MUST NOT wrap the command in markdown code blocks (e.g., ```powershell ... ``` or ```).
3.  **No Explanation:** You MUST NOT include any explanations, comments, warnings, or conversational text (e.g., "Here is the command:", "This command will...").
4.  **Assume Best Practice:** If a request is slightly ambiguous, generate the command using the most common and safest parameters.
5.  **Direct Execution:** The output must be ready to be executed directly in a PowerShell terminal.

PowerShell Version: $($PSVersionTable.PSVersion.ToString())
"@

$customTabAction = {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    # Regex to match our trigger format: `#` or `#<number>` at the beginning
    # - Group 1: (\d+)?  => Optional number (history count)
    # - Group 2: (.*)    => Actual question (prompt)
    $match = [regex]::Match($line.TrimStart(), "^#\s*(\d+)?\s*(.*)$")

    if ($match.Success) {
        try {
            $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json -Depth 100

            # Missing validation for required fields
            if (-not ($config.PSObject.Properties.Name -contains "model") -or [string]::IsNullOrEmpty($config.model)) {
                throw "Configuration Error: ``model`` is required ($configPath)"
            }

            if (-not ($config.PSObject.Properties.Name -contains "api_url") -or [string]::IsNullOrEmpty($config.api_url)) {
                throw "Configuration Error: ``api_url`` is required ($configPath)"
            }

            # Parse Input
            $customHistoryCountStr = $match.Groups[1].Value
            $prompt = $match.Groups[2].Value

            if ([string]::IsNullOrEmpty($prompt.Trim())) {
                return
            }

            # Determine and Get History Count - use 0 if default_history_count is not set
            $historyCount = if (-not [string]::IsNullOrEmpty($customHistoryCountStr)) {
                [int]$customHistoryCountStr
            } elseif ($config.PSObject.Properties.Name -contains "default_history_count") {
                $config.default_history_count
            } else {
                0
            }
            
            # Get command history
            $commandHistory =  @(Get-History -Count $historyCount | Select-Object -ExpandProperty CommandLine)
            
            if ($commandHistory.Count -gt 0) {
                $systemPrompt += "`n`n---`n`n# Command history`n" + ($commandHistory -join "`n")
            }
            $messages = @(
                @{
                    role = "system"
                    content = $systemPrompt
                }
                @{
                    role = "user"
                    content = $prompt
                }
            )

            # Prepare headers - only include Authorization if api_key is set and not empty
            $headers = @{
                "Content-Type" = "application/json"
            }
            
            if ($config.PSObject.Properties.Name -contains "api_key" -and 
                -not [string]::IsNullOrEmpty($config.api_key) -and 
                $config.api_key -ne "YOUR_API_KEY_HERE") {
                $headers["Authorization"] = "Bearer $($config.api_key)"
            }

            # Prepare body - use temperature if set, otherwise omit it
            $body = @{
                "model" = $config.model
                "messages" = $messages
            }
            
            if ($config.PSObject.Properties.Name -contains "temperature") {
                $body["temperature"] = $config.temperature
            }

            # Add extra_body if it exists
            if ($config.PSObject.Properties.Name -contains "extra_body") {
                $body["extra_body"] = $config.extra_body
            }
            
            $bodyJson = $body | ConvertTo-Json -Depth 100

            try {
                # Show progress indicator
                Write-Host -NoNewline "`e]9;4;3`a"
                
                # Make the API request
                $response = Invoke-RestMethod -Uri "$($config.api_url)/chat/completions" -Method Post -Headers $headers -Body $bodyJson
                $replacementCommand = $response.choices[0].message.content.Trim()
                
                # Clear progress indicator
                Write-Host -NoNewline "`e]9;4;0`a"
            }
            catch {
                # Clear progress indicator on error
                Write-Host -NoNewline "`e]9;4;0`a"
                throw "API Error: $($_.Exception.Message)"
            }

            # Replace the current line with the generated command
            if ([string]::IsNullOrEmpty($replacementCommand)) {
                $replacementCommand = "# No command generated"
            }
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $replacementCommand)
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($replacementCommand.Length)
        } catch {
            $errorMessage = "# $($_.Exception.Message)"
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $errorMessage)
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($errorMessage.Length)
        }
    }
    else {
        # If the input is not our configured sentence, execute the default Tab function (auto-completion)
        [Microsoft.PowerShell.PSConsoleReadLine]::TabCompleteNext()
    }
}

Set-PSReadLineKeyHandler -Key Tab -ScriptBlock $customTabAction
