# =============================================================================
# agente.ps1 — LogixAI Agent — Logix Brasil Ltda.
# Coleta moderada de dados da estação Windows e envia ao servidor central
# Execucao: 1x/hora via Task Scheduler
# Uso: .\agente.ps1 -ServidorIP "IP_DO_KILLERCODA" -Departamento "financeiro"
# =============================================================================

param(
    [string]$ServidorIP   = "IP_DO_KILLERCODA",   # Substituir pelo IP real do KillerCoda
    [string]$ServidorUser = "root",                # Usuario SSH do KillerCoda
    [string]$Departamento = "financeiro"           # rh | financeiro | ti | operacoes
)

$DataHora = Get-Date -Format "yyyy-MM-dd_HH-mm"
$Estacao  = $env:COMPUTERNAME
$ArqLocal = "$env:TEMP\coleta_${Estacao}_${DataHora}.csv"
$LogLocal = "$env:TEMP\logixai_erros.log"
$DestinoSCP = "${ServidorUser}@${ServidorIP}:/srv/logix/${Departamento}/coletas/"

Write-Host "[$DataHora] Iniciando coleta na estacao: $Estacao" -ForegroundColor Cyan

# =============================================================================
# SECAO 1: COLETA DE DADOS
# =============================================================================

# CPU — percentual de uso atual
$CPU_Pct = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average

# RAM — total e livre em GB
$OS       = Get-CimInstance Win32_OperatingSystem
$CS       = Get-CimInstance Win32_ComputerSystem
$RAM_Total = [math]::Round($CS.TotalPhysicalMemory / 1GB, 2)
$RAM_Livre = [math]::Round($OS.FreePhysicalMemory / 1MB, 2)  # FreePhysicalMemory esta em KB

# Disco — espaco livre em C:
$Disco_Livre = [math]::Round((Get-PSDrive C).Free / 1GB, 2)

# IP local (primeira interface nao-loopback)
$IP_Local = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and
                   $_.InterfaceAlias -notlike "*VPN*" } |
    Select-Object -First 1).IPAddress

# Servicos criticos parados (StartType Automatic que nao estao rodando)
$Servicos_Parados = (Get-Service |
    Where-Object { $_.Status -eq "Stopped" -and
                   $_.StartType -eq "Automatic" }).Count

# Updates instalados (historico de hotfixes como proxy de patches aplicados)
# Nota: Get-HotFix lista patches ja instalados, nao pendentes
$Updates_Instalados = (Get-HotFix | Measure-Object).Count

# Ultimo usuario logado no sistema (LGPD: dado pessoal — segregado por departamento)
$UltimoLogin = try {
    (Get-LocalUser |
        Where-Object { $_.LastLogon -ne $null } |
        Sort-Object LastLogon -Descending |
        Select-Object -First 1).Name
} catch { "N/A" }

# Erros recentes no Event Viewer — Sistema (ultimas 24h)
$Erros_Sistema = try {
    (Get-WinEvent -FilterHashtable @{
        LogName   = 'System'
        Level     = 2          # 2 = Error
        StartTime = (Get-Date).AddHours(-24)
    } -ErrorAction SilentlyContinue | Measure-Object).Count
} catch { 0 }

# Monta objeto de coleta
$Coleta = [PSCustomObject]@{
    DataHora          = $DataHora
    Estacao           = $Estacao
    Departamento      = $Departamento
    CPU_Pct           = $CPU_Pct
    RAM_TotalGB       = $RAM_Total
    RAM_LivreGB       = $RAM_Livre
    Disco_LivreGB     = $Disco_Livre
    IP_Local          = $IP_Local
    Servicos_Parados  = $Servicos_Parados
    Updates_Instalados = $Updates_Instalados
    UltimoLogin       = $UltimoLogin
    Erros_Sistema_24h = $Erros_Sistema
}

# Exporta para CSV
$Coleta | Export-Csv -Path $ArqLocal -NoTypeInformation -Encoding UTF8

Write-Host "  Coleta salva em: $ArqLocal" -ForegroundColor Green
Write-Host "  CPU: $CPU_Pct% | RAM livre: $RAM_Livre GB | Disco livre: $Disco_Livre GB"

# =============================================================================
# SECAO 2: ENVIO VIA SCP COM RETRY
# =============================================================================

$Tentativas = 3
$Sucesso    = $false

Write-Host "[$DataHora] Enviando para $DestinoSCP ..." -ForegroundColor Cyan

for ($i = 1; $i -le $Tentativas; $i++) {
    try {
        # SCP usa cliente OpenSSH nativo do Windows 10/11
        # -o StrictHostKeyChecking=no: aceita host novo automaticamente (OK para POC)
        # -o ConnectTimeout=10: nao trava indefinidamente se servidor offline
        $resultado = scp -o StrictHostKeyChecking=no `
                         -o ConnectTimeout=10 `
                         $ArqLocal `
                         $DestinoSCP 2>&1

        # SCP nao lanca excecao no PowerShell — verificar codigo de saida
        if ($LASTEXITCODE -eq 0) {
            $Sucesso = $true
            Write-Host "  Envio bem-sucedido na tentativa $i" -ForegroundColor Green
            break
        } else {
            throw "SCP retornou codigo $LASTEXITCODE : $resultado"
        }
    } catch {
        $Msg = "[$DataHora] Tentativa $i/$Tentativas falhou: $_"
        Write-Host "  $Msg" -ForegroundColor Yellow
        Add-Content -Path $LogLocal -Value $Msg

        if ($i -lt $Tentativas) {
            $Espera = 15 * $i   # Espera progressiva: 15s, 30s
            Write-Host "  Aguardando ${Espera}s antes da proxima tentativa..." -ForegroundColor Yellow
            Start-Sleep -Seconds $Espera
        }
    }
}

# =============================================================================
# SECAO 3: RESULTADO FINAL
# =============================================================================

if ($Sucesso) {
    $Msg = "[$DataHora] SUCESSO — Coleta enviada: $(Split-Path $ArqLocal -Leaf)"
    Write-Host $Msg -ForegroundColor Green
    Add-Content -Path $LogLocal -Value $Msg
    # Limpa arquivo local apos envio bem-sucedido
    Remove-Item $ArqLocal -ErrorAction SilentlyContinue
} else {
    $Msg = "[$DataHora] FALHA DEFINITIVA — arquivo mantido localmente: $ArqLocal"
    Write-Host $Msg -ForegroundColor Red
    Add-Content -Path $LogLocal -Value $Msg
    Write-Host "  Verifique o log em: $LogLocal" -ForegroundColor Red
}
