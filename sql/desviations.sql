WITH 
    target_ip AS (SELECT toIPv4('10.199.0.17') as ip), 

    -- 1. Promedio Reciente (1 Hora)
    short_term AS (
        SELECT 
            src_ip, 
            avg(sum_packets)/60 as avg_pps,
            stddevPop(sum_packets/60) as std_pps
        FROM flow_stats_1m 
        WHERE src_ip IN (SELECT ip FROM target_ip)
          AND window_start >= now() - INTERVAL 1 HOUR
        GROUP BY src_ip
    ),

    -- 2. Techo Histórico (7 Días)
    long_term AS (
        SELECT 
            src_ip, 
            quantile(0.99)(sum_packets)/60 as p99_pps_weekly
        FROM flow_stats_1m
        WHERE src_ip IN (SELECT ip FROM target_ip)
          AND window_start >= now() - INTERVAL 7 DAY
        GROUP BY src_ip
    ),

    -- 3. Tráfico AHORA (Últimos 20 segundos)
    current_traffic AS (
        SELECT
            src_ip,
            total_packets / 10 as current_pps,
            (total_bytes / total_packets) as avg_pkt_size
        FROM flow_metrics_10s
        WHERE src_ip IN (SELECT ip FROM target_ip)
          AND window_start >= now() - INTERVAL 30 SECOND
        ORDER BY window_start DESC
        LIMIT 1 -- Tomamos la muestra más reciente
    )

SELECT 
    curr.src_ip,
    
    -- DATOS EN VIVO
    round(curr.current_pps) as pps_ahora,
    round(curr.avg_pkt_size) as tamano_paquete,

    -- DATOS HISTÓRICOS
    round(coalesce(short.avg_pps, 0)) as promedio_1h,
    round(coalesce(long.p99_pps_weekly, 0)) as maximo_semanal,

    -- EL FAMOSO Z-SCORE (Puntaje de anomalía)
    -- Si es > 6, es alerta. Si es 0, es normal.
    round(
        if(short.std_pps > 0, 
           (curr.current_pps - short.avg_pps) / short.std_pps, 
           0
        ), 2
    ) as z_score,

    -- VEREDICTO DEL SISTEMA
    CASE 
        WHEN curr.current_pps > 50000 THEN 'ATAQUE VOLUMETRICO (Hard Cap)'
        WHEN curr.avg_pkt_size < 85 AND curr.current_pps < 30000 THEN 'IGNORADO (ACK Pequeño)'
        WHEN long.p99_pps_weekly > 0 AND curr.current_pps < (long.p99_pps_weekly * 1.5) THEN 'IGNORADO (Dentro de su rango habitual)'
        WHEN (curr.current_pps - short.avg_pps) / NULLIF(short.std_pps, 0) > 6 THEN 'ATAQUE DETECTADO (Z-Score Alto)'
        ELSE 'NORMAL'
    END as estado_calculado

FROM current_traffic curr
LEFT JOIN short_term short ON curr.src_ip = short.src_ip
LEFT JOIN long_term long ON curr.src_ip = long.src_ip