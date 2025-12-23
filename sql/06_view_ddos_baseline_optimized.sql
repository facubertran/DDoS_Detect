CREATE VIEW view_ddos_baseline_optimized AS
WITH 
    history_check AS (
        SELECT
            src_ip,
            count() as minutos_activos
        FROM default.flow_stats_1m
        WHERE window_start >= now() - INTERVAL 10 MINUTE
          AND (sum_packets / 60) > 1000 
        GROUP BY src_ip
    ),
    current_traffic AS (
        SELECT
            src_ip,
            window_start,
            total_packets / 10 as current_pps,
            total_bytes * 8 / 10 as current_bps,
            (total_bytes / total_packets) as avg_pkt_size
        FROM default.flow_metrics_10s
        WHERE window_start >= now() - INTERVAL 3 MINUTE
        ORDER BY window_start DESC
        LIMIT 1 BY src_ip 
    )

SELECT
    curr.src_ip,
    curr.current_pps,
    curr.current_bps, -- Columna necesaria para el script Python
    curr.avg_pkt_size as tamano_paquete,
    coalesce(hist.minutos_activos, 0) as persistencia_minutos,

    CASE 
        -- 1. Whitelist de IPs Individuales
        WHEN curr.src_ip IN (SELECT ip FROM default.ddos_whitelist) THEN 'Ignored_Whitelist_IP'
        
        -- 2. Whitelist de REDES (Activa) 🛡️
        -- Verifica si la IP pertenece a algún CIDR del diccionario
        WHEN dictHas('default.dict_whitelist_nets', curr.src_ip) = 1 THEN 'Ignored_Whitelist_Net'
        
        -- 3. Ataques Críticos
        WHEN hist.minutos_activos >= 3 THEN 'Critical_Constant_Attack'
        WHEN curr.avg_pkt_size < 40 AND curr.current_pps > 1000 THEN 'Critical_Null_Packet_Flood'
        WHEN curr.current_pps > 50000 THEN 'Critical_Volumetric_Burst'
        WHEN curr.current_pps > 5000 AND curr.avg_pkt_size < 100 THEN 'Warning_Small_Packet_Flood'
        
        ELSE 'Normal'
    END AS status

FROM current_traffic curr
LEFT JOIN history_check hist ON curr.src_ip = hist.src_ip

WHERE 
    curr.current_pps > 1000
    AND (status LIKE 'Critical%' OR status LIKE 'Warning%')
ORDER BY curr.current_pps DESC;