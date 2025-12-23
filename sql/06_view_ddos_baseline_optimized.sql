CREATE VIEW view_ddos_baseline_optimized AS
WITH 
    history_check AS (
        SELECT
            src_ip,
            count() as minutos_activos
        FROM (
            SELECT src_ip, window_start, sum(sum_packets) as total_packets_minuto
            FROM flow_stats_1m
            WHERE window_start >= now() - INTERVAL 30 MINUTE
            GROUP BY src_ip, window_start
            HAVING (total_packets_minuto / 60) > 1000
        )
        GROUP BY src_ip
    ),
    current_traffic AS (
        SELECT
            src_ip,
            window_start,
            total_packets / 10 as current_pps,
            total_bytes * 8 / 10 as current_bps,
            (total_bytes / total_packets) as avg_pkt_size
        FROM flow_metrics_10s
        WHERE window_start >= now() - INTERVAL 60 MINUTE
        ORDER BY window_start DESC
        LIMIT 1 BY src_ip 
    )

SELECT
    curr.src_ip,
    curr.current_pps,
    curr.current_bps,
    curr.avg_pkt_size as tamano_paquete,
    coalesce(hist.minutos_activos, 0) as persistencia_minutos,
    dateDiff('second', curr.window_start, now()) as lag_segundos,
    
    -- 🚩 Bandera para saber si la IP es nuestra (1) o externa (0)
    dictHas('dict_protected_nets', curr.src_ip) as is_internal,

    CASE 
        -- Solo ignoramos Whitelist EXPLICITA (Google, DNS, etc)
        WHEN curr.src_ip IN (SELECT ip FROM ddos_whitelist) THEN 'Ignored_Whitelist_IP'
        WHEN dictHas('dict_whitelist_nets', curr.src_ip) = 1 THEN 'Ignored_Whitelist_Net'
        
        -- YA NO IGNORAMOS REDES INTERNAS. Si es interna y ataca, caerá aquí abajo 👇
        
        WHEN hist.minutos_activos >= 3 THEN 'Critical_Constant_Attack'
        WHEN curr.avg_pkt_size < 40 AND curr.current_pps > 1000 THEN 'Critical_Null_Packet_Flood'
        WHEN curr.current_pps > 50000 THEN 'Critical_Volumetric_Burst'
        
        ELSE 'Normal'
    END AS status

FROM current_traffic curr
LEFT JOIN history_check hist ON curr.src_ip = hist.src_ip

WHERE 
    curr.current_pps > 1000
    AND (status LIKE 'Critical%' OR status LIKE 'Warning%')
ORDER BY curr.current_pps DESC;