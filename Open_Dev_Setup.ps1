# ========================================================================
# ENTWICKLUNGS-SETUP STARTEN (CHROME, VS CODE, SPOTIFY)
# by XERUS | Version 4
# WICHTIG: Dieses Skript muss als Administrator ausgeführt werden!
# ========================================================================

# Definiert die C# Methoden, um Fenster zu steuern (verschieben, Status ändern).
# Dies ist nötig, um die Windows API direkt anzusprechen.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -Name Win32 -Namespace WinAPI -MemberDefinition @"
[DllImport("user32.dll")]
public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

// Konstante, um ein Fenster in den "normalen" (nicht maximierten) Zustand zu versetzen
public const int SW_RESTORE = 9;
"@

# --- Konfiguration (Hier kannst du einfach URLs etc. anpassen) ---
$vsCodePath = "$env:USERPROFILE\AppData\Local\Programs\Microsoft VS Code\Code.exe"
$githubUrl = "https://github.com/X3RVUS?tab=repositories"
$geminiUrl = "https://gemini.google.com/"


# --- Funktion zum Warten auf ein Fenster ---
function Wait-For-Window {
    param(
        [string]$WindowTitle,
        [int]$Timeout = 15 # Sekunden
    )
    
    Write-Host "Suche nach Fenster: '$WindowTitle'..." -ForegroundColor Gray
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    while ($timer.Elapsed.TotalSeconds -lt $Timeout) {
        # Get-Process ist zuverlässiger als Get-WmiObject für Fenstertitel
        $process = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -like "*$WindowTitle*" } | Select-Object -First 1
        if ($process) {
            Write-Host " → Gefunden: $($process.MainWindowTitle)" -ForegroundColor Green
            return $process
        }
        Start-Sleep -Milliseconds 250
    }
    
    Write-Warning " → Fenster '$WindowTitle' wurde nach $Timeout Sekunden nicht gefunden."
    return $null
}


# --- 1. Anwendungen starten ---
Write-Host "Starte Anwendungen..." -ForegroundColor Cyan

# Chrome mit ZWEI Tabs in EINEM neuen Fenster starten
Start-Process "chrome.exe" -ArgumentList @("--new-window", $githubUrl, $geminiUrl)

# VS Code starten
if (Test-Path $vsCodePath) { Start-Process $vsCodePath } else { Write-Warning "VS Code Pfad nicht gefunden: $vsCodePath" }

# Spotify starten
Start-Process "spotify.exe" "--new-window"


# --- 2. Fenster finden (mit der Warte-Funktion) ---
Write-Host "`nWarte auf das Laden der Fenster..." -ForegroundColor Cyan
# Chrome wird nach dem zuletzt geöffneten Tab benannt sein
$chromeWindow = Wait-For-Window -WindowTitle "Chrome" 
$vsCodeWindow = Wait-For-Window -WindowTitle "Visual Studio Code"
$spotifyWindow = Wait-For-Window -WindowTitle "Spotify"


# --- 3. Fenster anordnen ---
if ($chromeWindow -and $vsCodeWindow -and $spotifyWindow) {
    Write-Host "`nOrdne Fenster an..." -ForegroundColor Cyan

    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $W = $screen.Width
    $H = $screen.Height
    
    # Aufteilung: Links (25%), Mitte (50%), Rechts (25%)
    $W1 = [int]($W * 0.25)
    $W2 = [int]($W * 0.50)
    $W3 = $W - $W1 - $W2

    # Array mit den zu positionierenden Fenstern
    $windowsToPosition = @(
        @{ Proc = $chromeWindow;  X = 0;         W = $W1; Title = "Chrome" },
        @{ Proc = $vsCodeWindow;  X = $W1;       W = $W2; Title = "VS Code" },
        @{ Proc = $spotifyWindow; X = $W1 + $W2; W = $W3; Title = "Spotify" }
    )

    foreach ($win in $windowsToPosition) {
        # Fenster erst in den "Normal"-Zustand versetzen (wichtig!)
        [WinAPI.Win32]::ShowWindow($win.Proc.MainWindowHandle, [WinAPI.Win32]::SW_RESTORE) | Out-Null
        
        # Fenster verschieben und Größe anpassen
        [WinAPI.Win32]::MoveWindow($win.Proc.MainWindowHandle, $win.X, 0, $win.W, $H, $true) | Out-Null
        Write-Host " → $($win.Title) positioniert."
    }
    
    Write-Host "`n✅ Setup erfolgreich angeordnet!" -ForegroundColor Green
} else {
    Write-Warning "`n❌ Mindestens ein Fenster wurde nicht gefunden. Anordnung abgebrochen."
}
