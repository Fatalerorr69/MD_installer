Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ===============================================================
#  MD SUPER INSTALLER 5.0 – WINDOWS EDITION (GUI + AI)
# ===============================================================

# ------------------------------
# Helper – AI Poradce (okno)
# ------------------------------
function Show-AI($message) {
    [System.Windows.Forms.MessageBox]::Show($message, "AI Poradce – MD Installer", "OK", "Information")
}

# ------------------------------
# Hlavní okno GUI
# ------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "MD SUPER INSTALLER 5.0 – Windows"
$form.Size = New-Object System.Drawing.Size(520, 340)
$form.StartPosition = "CenterScreen"

# Popis
$label = New-Object System.Windows.Forms.Label
$label.Text = "MD Toolkit Installer 5.0 – vyber cílovou složku a spusť instalaci."
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(20,20)
$form.Controls.Add($label)

# Výběr složky
$folderBox = New-Object System.Windows.Forms.TextBox
$folderBox.Size = New-Object System.Drawing.Size(350,20)
$folderBox.Location = New-Object System.Drawing.Point(20,60)
$form.Controls.Add($folderBox)

$browse = New-Object System.Windows.Forms.Button
$browse.Text = "Procházet..."
$browse.Location = New-Object System.Drawing.Point(380,58)
$browse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dialog.ShowDialog() -eq "OK") {
        $folderBox.Text = $dialog.SelectedPath
    }
})
$form.Controls.Add($browse)

# Progress bar
$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(20,110)
$progress.Size = New-Object System.Drawing.Size(440,25)
$form.Controls.Add($progress)

# Log okno
$log = New-Object System.Windows.Forms.TextBox
$log.Location = New-Object System.Drawing.Point(20,150)
$log.Size = New-Object System.Drawing.Size(450,110)
$log.Multiline = $true
$log.ScrollBars = "Vertical"
$form.Controls.Add($log)

# Instalace
$installButton = New-Object System.Windows.Forms.Button
$installButton.Text = "Spustit instalaci"
$installButton.Location = New-Object System.Drawing.Point(20,270)

$form.Controls.Add($installButton)

# ===============================================================
#  Hlavní logika instalátoru
# ===============================================================
$installButton.Add_Click({

    if (-not (Test-Path $folderBox.Text)) {
        Show-AI "Neplatná složka. Vyber správnou cestu."
        return
    }

    $root = Join-Path $folderBox.Text "MD-Toolkit-Generator"
    $tools = Join-Path $root "tools"

    $progress.Value = 10
    $log.AppendText("Vytvářím složky...`r`n")

    New-Item -ItemType Directory -Force -Path $root | Out-Null
    New-Item -ItemType Directory -Force -Path $tools | Out-Null

    Show-AI "Struktura vytvořena. Pokračuji generátorem..."

    # GENERATOR
    $progress.Value = 30
    $generator = @"
#!/usr/bin/env bash
set -euo pipefail

if [ \$# -lt 1 ]; then
    echo "Použití: \$0 <nazev_projektu>"
    exit 1
fi

PROJECT="\$1"
VERSION="2.0.0"

mkdir -p "\$PROJECT"/{SRC,docs,FILES,modules,tools,tests,config}

echo "# Projekt: \$PROJECT" > "\$PROJECT/README.md"
echo "TODO" > "\$PROJECT/TODO.md"

echo "#!/usr/bin/env bash" > "\$PROJECT/SRC/run.sh"
echo "echo 'Running bash...'" >> "\$PROJECT/SRC/run.sh"
chmod +x "\$PROJECT/SRC/run.sh"

echo "print('running python')" > "\$PROJECT/SRC/run.py"
echo "Write-Host 'PowerShell running'" > "\$PROJECT/SRC/run.ps1"

(cd "\$PROJECT"; git init -q; git add .; git commit -m "Init" -q)
"@

    Set-Content -Path "$tools/generator.sh" -Value $generator -Encoding UTF8

    $progress.Value = 50
    $log.AppendText("Generátor vytvořen.`r`n")

    # Dokumentace
    Set-Content -Path "$root/README.md" -Value "# MD Toolkit Generator 5.0 – Windows" -Encoding UTF8

    $progress.Value = 70
    $log.AppendText("Dokumentace hotová.`r`n")

    Show-AI "Instalace dokončena! Generátor najdeš ve: $root/tools/generator.sh"
    $progress.Value = 100
})

$form.ShowDialog()
