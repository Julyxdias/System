Passo 1 — Clonar o repositório
apt-get install -y git && git clone https://github.com/Julyxdias/System.git && cd System && git checkout Scripts

Passo 2 — Estrutura de pastas e permissões
sudo bash 01_estrutura_permissoes.sh

Passo 3 — Firewall, Samba e Nginx
sudo bash 02_firewall_samba_nginx.sh

Passo 4 — Copiar e rodar o servidor
sudo cp servidor.sh /srv/logix/servidor.sh
sudo bash /srv/logix/servidor.sh

Passo 5 — Verificar backups
ls -lh /srv/logix/backups/
ls -lh /srv/logix/nuvem_simulada/

Passo 6 — Databricks (análise)
# Cria o script de análise direto no servidor
sudo tee /srv/logix/analise_coletas.py > /dev/null << 'PYEOF'
import os, glob, json
from datetime import datetime
try:
    import pandas as pd
except ImportError:
    os.system("pip install pandas --break-system-packages -q")
    import pandas as pd

BASE_DIR  = "/srv/logix"
RELATORIO = "/var/log/logixai/relatorio_databricks.txt"
DATA_EXEC = datetime.now().strftime("%Y-%m-%d %H:%M")
DEPTS     = ["rh","financeiro","ti","operacoes"]
os.makedirs(os.path.dirname(RELATORIO), exist_ok=True)

print("="*60)
print("  LogixAI Agent — Análise de Dados (simulação Databricks)")
print(f"  Execução: {DATA_EXEC}")
print("="*60)

arquivos = []
for dept in DEPTS:
    encontrados = glob.glob(f"{BASE_DIR}/{dept}/coletas/*.csv")
    arquivos.extend(encontrados)

if len(arquivos) == 0:
    print("\n  [DEMO] Gerando dados simulados...\n")
    import random; random.seed(42)
    estacoes = [
        {"Estacao":"WIN-FIN01","Departamento":"financeiro"},
        {"Estacao":"WIN-FIN02","Departamento":"financeiro"},
        {"Estacao":"WIN-RH01", "Departamento":"rh"},
        {"Estacao":"WIN-TI01", "Departamento":"ti"},
        {"Estacao":"WIN-OP01", "Departamento":"operacoes"},
        {"Estacao":"WIN-OP02", "Departamento":"operacoes"},
    ]
    registros = []
    for hora in range(8):
        for est in estacoes:
            registros.append({
                "DataHora":f"2026-05-20_{8+hora:02d}-00",
                "Estacao":est["Estacao"],"Departamento":est["Departamento"],
                "CPU_Pct":random.randint(10,95),"RAM_TotalGB":16,
                "RAM_LivreGB":round(random.uniform(2,12),2),
                "Disco_LivreGB":round(random.uniform(5,80),2),
                "Servicos_Parados":random.randint(0,6),
                "Erros_Sistema_24h":random.randint(0,20),
            })
    df = pd.DataFrame(registros)
    MODO = "SIMULADO"
else:
    df = pd.concat([pd.read_csv(f) for f in arquivos], ignore_index=True)
    MODO = "REAL"

for col in ["CPU_Pct","RAM_LivreGB","Disco_LivreGB","Servicos_Parados","Erros_Sistema_24h"]:
    if col in df.columns:
        df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0)

print(f"\n  Registros: {len(df)} | Modo: {MODO}")
print(f"  Estações : {df['Estacao'].nunique()}")
print(f"  CPU média: {df['CPU_Pct'].mean():.1f}%")
print(f"  Disco min: {df['Disco_LivreGB'].min():.1f} GB")
print(f"  Erros    : {int(df['Erros_Sistema_24h'].sum())}")

print("\n  --- Análise por departamento ---")
resumo = df.groupby("Departamento").agg(
    CPU_Media=("CPU_Pct","mean"),
    CPU_Max=("CPU_Pct","max"),
    Disco_Min=("Disco_LivreGB","min"),
    Erros=("Erros_Sistema_24h","sum"),
).reset_index()
print(f"  {'Dept':<14}{'CPU Med':>8}{'CPU Max':>8}{'Disco Min':>10}{'Erros':>7}")
print("  "+"-"*48)
for _,r in resumo.iterrows():
    alerta = " ⚠" if (r.CPU_Media>80 or r.Disco_Min<10 or r.Erros>10) else ""
    print(f"  {r['Departamento']:<14}{r.CPU_Media:>7.1f}%{r.CPU_Max:>7.0f}%{r.Disco_Min:>9.1f}GB{int(r.Erros):>7}{alerta}")

print("\n  --- Alertas detectados ---")
alertas = []
for est, grp in df.groupby("Estacao"):
    dept = grp["Departamento"].iloc[0]
    cpu  = grp["CPU_Pct"].mean()
    dsc  = grp["Disco_LivreGB"].min()
    err  = grp["Erros_Sistema_24h"].sum()
    srv  = grp["Servicos_Parados"].max()
    if cpu  > 80:  alertas.append(f"  CRITICO | CPU Alta        | {est} ({dept}) | {cpu:.1f}%")
    if dsc  < 10:  alertas.append(f"  CRITICO | Disco Critico   | {est} ({dept}) | {dsc:.1f} GB")
    if srv  > 3:   alertas.append(f"  ATENCAO | Servicos Parados| {est} ({dept}) | {int(srv)} servicos")
    if err  > 10:  alertas.append(f"  ATENCAO | Erros de Sistema| {est} ({dept}) | {int(err)} erros/24h")

if alertas:
    for a in alertas: print(a)
else:
    print("  Nenhum alerta — ambiente dentro dos parametros.")

rel = {"execucao":DATA_EXEC,"modo":MODO,"registros":len(df),
       "alertas":len(alertas)}
with open(RELATORIO,"w") as f: json.dump(rel,f,indent=2)

print(f"\n  Relatorio salvo: {RELATORIO}")
print("\n  Em producao:")
print("  spark.read.csv('abfss://logixai@storage.dfs.core.windows.net/')")
print("  az storage blob upload --file backup.tar.gz --container logixai")
print("="*60)
PYEOF

python3 /srv/logix/analise_coletas.py

Passo 7 — Verificar log completo
cat /var/log/logixai/servidor.log
cat /var/log/logixai/relatorio_databricks.txt

Passo 8 — Pegar o IP para o agente.ps1
ip addr show enp1s0 | grep 'inet '

Passo 9 — Evidencias
# Confirma tudo que está rodando
sudo systemctl status nginx smbd ufw --no-pager | grep -E "Active|●"
# Estrutura final completa
ls -laR /srv/logix/ | head -60
