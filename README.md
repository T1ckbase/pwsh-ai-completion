# PowerShell AI Completion

A PowerShell module that provides AI-powered command completion using OpenAI-compatible APIs. Simply type `#` followed by your question in natural language, and get an executable PowerShell command.

## Features

- Natural language to PowerShell command conversion
- Support for OpenAI-compatible APIs
- Command history context for more relevant suggestions
- Easy configuration via JSON
- Visual progress indicator during API calls

## Installation

1. Clone this repository or download the files
2. Add this line to your PowerShell profile (`$PROFILE`):

```powershell
. "path/to/your/script.ps1"
```

3. Configure your API settings in `~/.config/pwsh-ai-completion/config.json`

## Configuration

The configuration file is located at `~/.config/pwsh-ai-completion/config.json`. Example configuration:

```json
{
  "api_key": "YOUR_API_KEY_HERE",
  "api_url": "https://api.openai.com/v1",
  "model": "gpt-4.1-nano",
  "temperature": 1,
  "default_history_count": 3
}
```

For Google AI, use:

```json
{
  "api_key": "YOUR_API_KEY_HERE",
  "api_url": "https://generativelanguage.googleapis.com/v1beta/openai",
  "model": "gemini-2.5-flash-lite",
  "temperature": 1,
  "default_history_count": 3
}
```

Enable thinking:

```json
{
  "api_key": "YOUR_API_KEY_HERE",
  "api_url": "https://generativelanguage.googleapis.com/v1beta/openai",
  "model": "gemini-2.5-flash-lite",
  "temperature": 1,
  "default_history_count": 3,
  "extra_body": {
    "google": {
      "thinking_config": {
        "thinking_budget": -1
      }
    }
  }
}
```

## Usage

1. Import the module in your PowerShell profile
2. Type `#` followed by your question in natural language
3. Press `Tab` to generate the command

Examples:

```powershell
# list all files recursively  # Press Tab
Get-ChildItem -Recurse

#3 create new directory called test  # Press Tab (with 3 history items)
New-Item -Path "test" -ItemType Directory
```

## Requirements

- PowerShell 7.0 or later
