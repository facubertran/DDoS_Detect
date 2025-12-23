import time
import requests
import json
from datetime import datetime

# ================= CONFIGURACIÓN =================
CH_HOST = 'http://localhost:8123'
CH_DB = 'default'
CH_USER = 'default'       # ✏️ Tu usuario
CH_PASSWORD = 'flow'          # ✏️ Tu contraseña

TELEGRAM_TOKEN = '514803369:AAErDsxXMB4FcHSmlJQYdaHVzAUHdXwVQ9Q'
TELEGRAM_CHAT_ID = '-1001595461363'

CHECK_INTERVAL = 5     # Segundos entre lecturas
MAX_DATA_LAG = 300     # Ignorar datos con más de 5 min de lag
REQUIRED_CHECKS = 3    # Cuántas veces debe aumentar la persistencia para confirmar

# Diccionarios de Estado
active_attacks = {}   # Ataques ya notificados
pending_check = {}    # Candidatos bajo vigilancia

def send_telegram(msg):
    try:
        url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
        requests.post(url, data={"chat_id": TELEGRAM_CHAT_ID, "text": msg, "parse_mode": "HTML"}, timeout=5)
    except Exception as e:
        print(f"Error Telegram: {e}")

def get_attacks():
    # Consulta SQL (Mapeo de columnas estricto)
    query = """
    SELECT 
        src_ip, 
        current_pps, 
        current_bps, 
        tamano_paquete, 
        persistencia_minutos, 
        status, 
        lag_segundos, 
        is_internal
    FROM view_ddos_baseline_optimized
    WHERE status LIKE 'Critical%'
    FORMAT JSONCompact
    """
    
    # Preparar autenticación
    auth = (CH_USER, CH_PASSWORD) if CH_PASSWORD else None
    
    try:
        r = requests.post(
            CH_HOST, 
            params={'database': CH_DB, 'query': query}, 
            auth=auth,  # 👈 AQUÍ ESTABA EL FALTANTE
            timeout=10
        )
        
        if r.status_code == 200:
            return r.json().get('data', [])
        else:
            print(f"Error ClickHouse ({r.status_code}): {r.text}")
            return []
            
    except Exception as e:
        print(f"Error de Conexión HTTP: {e}")
        return []

def main():
    print("🛡️  Monitor Anti-DDoS PRO Iniciado...")
    print(f"   Config: Intervalo {CHECK_INTERVAL}s | Checks Requeridos: {REQUIRED_CHECKS}")
    
    while True:
        try:
            rows = get_attacks()
            current_cycle_ips = set()

            for row in rows:
                # Mapeo de columnas (Coincide con el SELECT de arriba)
                ip = row[0]
                pps = float(row[1])
                bps = float(row[2])
                pkt = float(row[3])
                persist = int(row[4])
                status = row[5]
                lag = int(row[6])
                is_internal = int(row[7])

                current_cycle_ips.add(ip)
                
                # Ignorar datos viejos (Lag de ingesta)
                if lag > MAX_DATA_LAG:
                    continue

                # Si ya fue notificado, solo actualizamos timestamp
                if ip in active_attacks:
                    active_attacks[ip]['last_seen'] = time.time()
                    active_attacks[ip]['max_pps'] = max(pps, active_attacks[ip].get('max_pps', 0))
                    continue

                # Etiqueta visual si es interno
                origin_tag = "🏠 <b>ORIGEN INTERNO (CLIENTE/SERVER PROPIO)</b>" if is_internal == 1 else "🌍 <b>ORIGEN EXTERNO</b>"

                # ==================================================
                # CASO 1: NOTIFICACIÓN INMEDIATA (Null Packet / Burst)
                # ==================================================
                if status == 'Critical_Null_Packet_Flood' or status == 'Critical_Volumetric_Burst':
                    
                    msg = (
                        f"<b>🚨 ATAQUE INMEDIATO DETECTADO</b>\n"
                        f"{origin_tag}\n\n"
                        f"<b>Target:</b> {ip}\n"
                        f"<b>Tipo:</b> {status}\n"
                        f"<b>PPS:</b> {int(pps):,}\n"
                        f"<b>Paquete:</b> {int(pkt)} bytes"
                    )
                    send_telegram(msg)
                    print(f"ALERTA INMEDIATA: {ip}")
                    
                    active_attacks[ip] = {'last_seen': time.time(), 'start': time.time(), 'max_pps': pps}
                    # Limpiar de pendientes si estaba ahí
                    if ip in pending_check: del pending_check[ip]

                # ==================================================
                # CASO 2: ATAQUE CONSTANTE (Requiere aumento de persistencia)
                # ==================================================
                elif status == 'Critical_Constant_Attack':
                    
                    # A) Primera vez que lo vemos
                    if ip not in pending_check:
                        pending_check[ip] = {
                            'checks_passed': 0, 
                            'last_pers': persist
                        }
                        print(f"👀 {ip} bajo vigilancia. Persistencia inicial: {persist} min.")
                    
                    # B) Ya lo estábamos vigilando
                    else:
                        saved = pending_check[ip]
                        
                        # CONDICIÓN CLAVE: La persistencia DEBE haber aumentado
                        if persist > saved['last_pers']:
                            saved['checks_passed'] += 1
                            saved['last_pers'] = persist # Actualizamos referencia
                            print(f"⚠️ {ip}: Persistencia subió a {persist} (Validación {saved['checks_passed']}/{REQUIRED_CHECKS})")
                        
                        # Si superamos las validaciones requeridas
                        if saved['checks_passed'] >= REQUIRED_CHECKS:
                            
                            msg = (
                                f"<b>💀 ATAQUE CONFIRMADO (SOSTENIDO)</b>\n"
                                f"{origin_tag}\n\n"
                                f"<b>Target:</b> {ip}\n"
                                f"<b>Tipo:</b> {status}\n"
                                f"<b>Persistencia:</b> {persist} minutos\n"
                                f"<b>PPS Actuales:</b> {int(pps):,}"
                            )
                            send_telegram(msg)
                            print(f"ALERTA CONFIRMADA: {ip}")
                            
                            active_attacks[ip] = {'last_seen': time.time(), 'start': time.time(), 'max_pps': pps}
                            del pending_check[ip]

            # ----------------------------------------------------
            # LIMPIEZA
            # ----------------------------------------------------
            
            # Borrar pendientes que desaparecieron
            for ip in list(pending_check.keys()):
                if ip not in current_cycle_ips:
                    print(f"♻️ {ip} dejó de atacar. Limpiando vigilancia.")
                    del pending_check[ip]

            # Borrar activos que terminaron
            for ip in list(active_attacks.keys()):
                if ip not in current_cycle_ips:
                    # Esperamos 60s de silencio
                    if time.time() - active_attacks[ip]['last_seen'] > 60:
                        
                        max_pps_val = int(active_attacks[ip].get('max_pps', 0))
                        
                        send_telegram(
                            f"<b>✅ FIN DEL ATAQUE</b>\n"
                            f"<b>Target:</b> {ip}\n"
                            f"<b>Pico PPS:</b> {max_pps_val:,}"
                        )
                        del active_attacks[ip]

        except Exception as e:
            print(f"Error Loop Principal: {e}")

        time.sleep(CHECK_INTERVAL)

if __name__ == '__main__':
    main()