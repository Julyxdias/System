Agente PowerShell (agente.ps1)

# agente.ps1 — LogixAI Agent — Estação Windows
# Coleta moderada: hardware, processos, serviços, rede, segurança, logs
# Execução: 1x/hora via Task Scheduler

param(
    [string]$ServidorIP   = "IP_DO_KILLERCODA",
    [string]$ServidorUser = "usuario_logix",
    [string]$Departamento = "financeiro"
)

$DataHora   = Get-Date -Format "yyyy-MM-dd_HH-mm"
$Estacao    = $env:COMPUTERNAME
$ArqLocal   = "$env:TEMP\coleta_${Estacao}_${DataHora}.csv"
$LogLocal   = "$env:TEMP\logixai_erros.log"
$DestinoSCP = "${ServidorUser}@${ServidorIP}:/srv/logix/${Departamento}/coletas/"

# --- COLETA ---
$Coleta = [PSCustomObject]@{
    DataHora    = $DataHora
    Estacao     = $Estacao
    Departamento= $Departamento
    CPU_Pct     = (Get-CimInstance Win32_Processor).LoadPercentage
    RAM_TotalGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB, 2)
    RAM_LivreGB = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1MB, 2)
    Disco_LivreGB = [math]::Round((Get-PSDrive C).Free/1GB, 2)
    IP_Local    = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" } | Select-Object -First 1).IPAddress
    Servicos_Parados = (Get-Service | Where-Object { $_.Status -eq "Stopped" -and $_.StartType -eq "Automatic" }).Count
    Updates_Pendentes = (Get-HotFix | Measure-Object).Count
    UltimoLogin = (Get-LocalUser | Where-Object { $_.LastLogon } | Sort-Object LastLogon -Descending | Select-Object -First 1).Name
    Erros_Sistema = (Get-EventLog -LogName System -EntryType Error -Newest 50 -ErrorAction SilentlyContinue).Count
}

$Coleta | Export-Csv -Path $ArqLocal -NoTypeInformation -Encoding UTF8

# --- ENVIO com retry 3x ---
$Tentativas = 3
$Sucesso    = $false

for ($i = 1; $i -le $Tentativas; $i++) {
    try {
        scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 `
            $ArqLocal "${DestinoSCP}"
        $Sucesso = $true
        break
    } catch {
        $Msg = "[$DataHora] Tentativa $i falhou: $_"
        Add-Content -Path $LogLocal -Value $Msg
        if ($i -lt $Tentativas) { Start-Sleep -Seconds (15 * $i) }
    }
}

if (-not $Sucesso) {
    Add-Content -Path $LogLocal -Value "[$DataHora] FALHA DEFINITIVA — arquivo mantido localmente: $ArqLocal"
}