import time
import requests
import json
from datetime import datetime

# ==========================================
# ⚙️ CONFIGURACIÓN
# ==========================================

# 1. ClickHouse HTTP API
CH_HOST = 'http://localhost:8123'
CH_USER = 'default'
CH_PASSWORD = 'flow'
CH_DB = 'default'

# 2. Telegram Bot
TELEGRAM_TOKEN = '514803369:AAErDsxXMB4FcHSmlJQYdaHVzAUHdXwVQ9Q'
TELEGRAM_CHAT_ID = '-1001595461363'

# 3. Ajustes del Monitor
CHECK_INTERVAL = 5       # Segundos entre cada consulta
COOLDOWN_SECONDS = 60    # Tiempo para declarar fin del ataque
MIN_STREAK = 3           # 🟢 NUEVO: Veces consecutivas requeridas para alertar

# ==========================================
# 🧠 LÓGICA DEL SISTEMA
# ==========================================

# Diccionario para ataques confirmados (ya alertados)
active_attacks = {}

# 🟢 NUEVO: Diccionario para candidatos (IPs en observación)
# Estructura: { 'IP': count }
pending_attacks = {}

def send_telegram_msg(message):
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    data = {"chat_id": TELEGRAM_CHAT_ID, "text": message, "parse_mode": "HTML"}
    try:
        requests.post(url, data=data, timeout=5)
    except Exception as e:
        print(f"Error Telegram: {e}")

def format_bps(size):
    power = 2**10
    n = size
    power_labels = {0 : '', 1: 'K', 2: 'M', 3: 'G', 4: 'T'}
    count = 0
    while n > power:
        n /= power
        count += 1
    return f"{n:.1f} {power_labels[count]}bps"

def get_current_attacks_http():
    # Mantenemos tus filtros estrictos del paso anterior
    query = """
    SELECT 
        src_ip, 
        current_pps, 
        current_bps, 
        tamano_paquete, 
        persistencia_minutos, 
        status 
    FROM view_ddos_baseline_optimized
    WHERE 
        (status = 'Critical_Constant_Attack' OR status = 'Critical_Null_Packet_Flood')
        AND current_pps > 20000
        AND persistencia_minutos > 3
    FORMAT JSONCompact
    """
    
    params = {'database': CH_DB, 'query': query}
    auth = (CH_USER, CH_PASSWORD) if CH_PASSWORD else None

    try:
        response = requests.post(CH_HOST, params=params, auth=auth, timeout=10)
        if response.status_code == 200:
            return response.json().get('data', [])
        else:
            print(f"Error ClickHouse: {response.text}")
            return []
    except Exception as e:
        print(f"Error Conexión: {e}")
        return []

def main():
    print(f"🛡️  Monitor Anti-DDoS Iniciado (Requiere {MIN_STREAK} detecciones consecutivas)...")

    while True:
        try:
            rows = get_current_attacks_http()
            
            # Conjunto de IPs detectadas en ESTA vuelta específica
            current_cycle_ips = set()

            for row in rows:
                ip = row[0]
                pps = float(row[1])
                bps = float(row[2])
                pkt_size = float(row[3])
                persistence = int(row[4])
                status = row[5]

                current_cycle_ips.add(ip)
                pps_formated = f"{int(pps):,}"
                bps_formated = format_bps(bps)

                # -------------------------------------------------------
                # CASO 1: YA ES UN ATAQUE ACTIVO (Confirmado previamente)
                # -------------------------------------------------------
                if ip in active_attacks:
                    # Solo actualizamos datos
                    active_attacks[ip]['last_seen'] = time.time()
                    if pps > active_attacks[ip]['max_pps']:
                        active_attacks[ip]['max_pps'] = pps

                # -------------------------------------------------------
                # CASO 2: ES UN CANDIDATO (Verificando racha)
                # -------------------------------------------------------
                else:
                    # Si no estaba en pendientes, lo agregamos con contador 1
                    if ip not in pending_attacks:
                        pending_attacks[ip] = 1
                        print(f"👀 Ojo puesto en {ip} (Racha: 1/{MIN_STREAK})")
                    else:
                        # Si ya estaba, sumamos 1
                        pending_attacks[ip] += 1
                        print(f"👀 Verificando {ip} (Racha: {pending_attacks[ip]}/{MIN_STREAK})")

                    # ¿Llegamos a la meta de 3 veces?
                    if pending_attacks[ip] >= MIN_STREAK:
                        # ¡CONFIRMADO! Promover a Activo y Alertar
                        active_attacks[ip] = {
                            'start_time': time.time(),
                            'last_seen': time.time(),
                            'max_pps': pps,
                            'status': status
                        }
                        
                        # Borramos de pendientes porque ya es oficial
                        del pending_attacks[ip]
                        
                        msg = (
                            f"<b>💀 ATAQUE CONFIRMADO (Verificado {MIN_STREAK}x)</b>\n\n"
                            f"<b>Target:</b> {ip}\n"
                            f"<b>Estado:</b> {status}\n"
                            f"<b>PPS:</b> {pps_formated}\n"
                            f"<b>Tráfico:</b> {bps_formated}\n"
                            f"<b>Persistencia:</b> {persistence} min"
                        )
                        print(f"🚨 ALERT SENT: {ip}")
                        send_telegram_msg(msg)

            # -------------------------------------------------------
            # LIMPIEZA DE PENDIENTES (Romper la racha)
            # -------------------------------------------------------
            # Si una IP estaba pendiente pero NO apareció en esta vuelta, reseteamos su contador
            pending_ips_to_remove = []
            for ip in pending_attacks:
                if ip not in current_cycle_ips:
                    print(f"♻️ Racha rota para {ip}. Reseteando.")
                    pending_ips_to_remove.append(ip)
            
            for ip in pending_ips_to_remove:
                del pending_attacks[ip]

            # -------------------------------------------------------
            # LIMPIEZA DE ACTIVOS (Fin del ataque)
            # -------------------------------------------------------
            active_ips_to_remove = []
            for ip, data in active_attacks.items():
                if ip not in current_cycle_ips:
                    if time.time() - data['last_seen'] > COOLDOWN_SECONDS:
                        
                        duration = int(time.time() - data['start_time'] - COOLDOWN_SECONDS + 300)
                        if duration < 0: duration = 0
                        
                        msg = (
                            f"<b>✅ FIN DEL ATAQUE</b>\n\n"
                            f"<b>Target:</b> {ip}\n"
                            f"<b>Duración Aprox:</b> {duration} seg\n"
                            f"<b>Pico PPS:</b> {int(data['max_pps']):,}"
                        )
                        send_telegram_msg(msg)
                        active_ips_to_remove.append(ip)

            for ip in active_ips_to_remove:
                del active_attacks[ip]

        except Exception as e:
            print(f"Error loop: {e}")

        time.sleep(CHECK_INTERVAL)

if __name__ == '__main__':
    main()