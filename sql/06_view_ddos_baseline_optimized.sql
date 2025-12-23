CREATE VIEW view_ddos_baseline_optimized AS
WITH 
    -- 1. BASELINE CORTO (1 Hora)
    short_term AS (
        SELECT 
            src_ip,
            avg(sum_packets) / 60 as avg_pps,
            stddevPop(sum_packets / 60) as std_pps
        FROM flow_stats_1m
        WHERE window_start BETWEEN (now() - INTERVAL 1 HOUR) AND (now() - INTERVAL 1 MINUTE)
        GROUP BY src_ip
    ),
    
    -- 2. BASELINE LARGO (7 Días - Percentil 99)
    long_term AS (
        SELECT 
            src_ip,
            quantile(0.99)(sum_packets) / 60 as p99_pps_weekly
        FROM flow_stats_1m
        WHERE window_start >= now() - INTERVAL 7 DAY
        GROUP BY src_ip
    ),

    -- 3. TRÁFICO ACTUAL
    current_traffic AS (
        SELECT
            src_ip,
            window_start,
            total_packets / 10 as current_pps,
            total_bytes * 8 / 10 as current_bps,
            (total_bytes / total_packets) as avg_pkt_size
        FROM flow_metrics_10s
        WHERE window_start >= now() - INTERVAL 20 SECOND
    )

SELECT
    -- AQUI ESTÁ EL CAMBIO: Usamos "AS nombre" explícitamente
    curr.src_ip AS src_ip,
    curr.current_pps AS current_pps,
    short.avg_pps AS avg_pps,
    curr.current_bps AS current_bps,
    
    round(long.p99_pps_weekly) AS techo_semanal_limpio,
    
    (curr.current_pps - short.avg_pps) / NULLIF(short.std_pps + 1, 0) AS z_score,
    
    CASE 
        WHEN curr.current_pps > 50000 THEN 'Critical_Volumetric_Flood'
        WHEN curr.avg_pkt_size < 85 THEN 'Ignored_Small_Packet_ACK'
        WHEN curr.current_pps < (long.p99_pps_weekly * 1.5) THEN 'Ignored_Inside_Weekly_Range'
        WHEN z_score > 6 THEN 'Critical_Anomaly'
        WHEN z_score > 4 THEN 'Warning_Anomaly'
        ELSE 'Normal'
    END AS status

FROM current_traffic curr
INNER JOIN short_term short ON curr.src_ip = short.src_ip
LEFT JOIN long_term long ON curr.src_ip = long.src_ip

WHERE 
    curr.current_pps > 30000 
    AND status IN ('Critical_Anomaly', 'Warning_Anomaly', 'Critical_Volumetric_Flood')
ORDER BY z_score DESC;