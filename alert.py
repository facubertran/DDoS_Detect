import time
import requests
import json
from datetime import datetime

# ================= CONFIGURACIÓN =================
# 1. Datos de ClickHouse (HTTP Interface)
DB_HOST = 'localhost' # O tu IP
DB_PORT = 8123        # Puerto HTTP
DB_USER = 'default'
DB_PASSWORD = 'flow'      # Tu password

# 2. Datos de Telegram
TG_BOT_TOKEN = '514803369:AAErDsxXMB4FcHSmlJQYdaHVzAUHdXwVQ9Q' 
TG_CHAT_ID = '-1001595461363' 

# 3. Ajustes de Detección
CHECK_INTERVAL = 10     
ALERT_COOLDOWN = 600    
MIN_ROUNDS = 3          

# =================================================

alert_history = {}

def send_telegram_alert(message):
    """Envía mensaje a Telegram usando HTML (Más robusto)"""
    url = f"https://api.telegram.org/bot{TG_BOT_TOKEN}/sendMessage"
    payload = {
        'chat_id': TG_CHAT_ID,
        'text': message,
        'parse_mode': 'HTML'  # <--- CAMBIO IMPORTANTE: Usamos HTML
    }
    try:
        r = requests.post(url, data=payload, timeout=5)
        r.raise_for_status()
        print(f"✅ [TELEGRAM] Mensaje enviado correctamente.")
    except requests.exceptions.HTTPError as err:
        # Imprimimos el error exacto si vuelve a fallar
        print(f"❌ [TELEGRAM API ERROR] {r.text}")
    except Exception as e:
        print(f"❌ [TELEGRAM ERROR CONEXIÓN] {e}")

def ch_query(query, readonly=True):
    """
    Ejecuta consultas a ClickHouse vía HTTP (Puerto 8123).
    Si readonly=True, espera datos de retorno (SELECT).
    Si readonly=False, solo ejecuta (INSERT).
    """
    url = f"http://{DB_HOST}:{DB_PORT}/"
    
    # Si es un SELECT, pedimos formato JSONCompact para parsear fácil en Python
    if readonly:
        query += " FORMAT JSONCompact"
    
    params = {
        'user': DB_USER,
        'password': DB_PASSWORD,
        'query': query
    }
    
    try:
        r = requests.post(url, params=params, timeout=10)
        r.raise_for_status() # Lanza error si HTTP != 200
        
        if readonly:
            return r.json().get('data', [])
        return []
        
    except Exception as e:
        print(f"[ERROR DB] Falló consulta HTTP: {e}")
        # Si hay error en el body (ej. error de sintaxis SQL), lo imprimimos
        if 'r' in locals() and r.text:
             print(f"[DB MESSAGE] {r.text.strip()}")
        raise e

def main():
    print(f"--- INICIANDO MONITOR ANTI-DDOS (Modo HTTP Puerto {DB_PORT}) ---")
    
    while True:
        try:
            start_time = time.time()

            # ---------------------------------------------------------
            # PASO A: REGISTRAR (Insertar estado actual en el Log)
            # ---------------------------------------------------------
            sql_insert = """
                INSERT INTO default.ddos_events_log
                SELECT 
                    now(), src_ip, current_pps, current_bps, z_score, status
                FROM default.view_ddos_baseline_optimized
                WHERE status != 'Normal'
            """
            # Ejecutamos sin esperar retorno
            ch_query(sql_insert, readonly=False)

            # ---------------------------------------------------------
            # PASO B: CONFIRMAR (Buscar persistencia)
            # ---------------------------------------------------------
            sql_check = f"""
                SELECT 
                    src_ip, 
                    count() as apariciones,
                    max(pps) as max_pps,
                    formatReadableSize(max(bps)) as max_bw,
                    argMax(status, pps) as tipo_ataque
                FROM default.ddos_events_log
                WHERE event_time >= now() - INTERVAL 1 MINUTE
                GROUP BY src_ip
                HAVING apariciones >= {MIN_ROUNDS}
            """
            
            # Ejecutamos esperando retorno
            results = ch_query(sql_check, readonly=True)

            # ---------------------------------------------------------
            # PASO C: GESTIÓN DE ALERTAS
            # ---------------------------------------------------------
            current_ts = time.time()
            
            for row in results:
                # En JSONCompact, row es una lista simple: [ip, apariciones, max_pps, ...]
                ip_address = row[0]
                hits = row[1]
                max_pps = row[2]
                max_bw = row[3]
                attack_type = row[4]

                last_alert = alert_history.get(ip_address, 0)

                if (current_ts - last_alert) > ALERT_COOLDOWN:
                    # Construimos el mensaje usando etiquetas HTML <b> y <code>
                    # Esto evita que 'Critical_Anomaly' rompa el formato.
                    msg = (
                        f"🚨 <b>ALERTA DE SEGURIDAD</b> 🚨\n\n"
                        f"<b>IP:</b> <code>{ip_address}</code>\n"
                        f"<b>Tipo:</b> {attack_type}\n"
                        f"<b>Intensidad:</b> {max_pps:,.0f} PPS\n"
                        f"<b>Ancho de Banda:</b> {max_bw}\n"
                        f"<b>Persistencia:</b> {hits} detecciones en 60s\n"
                    )
                    
                    print(f"[ALERTA] Enviando telegram por {ip_address}...")
                    send_telegram_alert(msg)
                    alert_history[ip_address] = current_ts
                else:
                    print(f"[SILENCIO] Cooldown activo para {ip_address}")

            # Limpieza de cache
            for ip in list(alert_history.keys()):
                if (current_ts - alert_history[ip]) > (ALERT_COOLDOWN * 2):
                    del alert_history[ip]

        except Exception as e:
            # Error de conexión o ejecución, esperamos un poco
            pass 

        elapsed = time.time() - start_time
        time.sleep(max(0, CHECK_INTERVAL - elapsed))

if __name__ == '__main__':
    main()