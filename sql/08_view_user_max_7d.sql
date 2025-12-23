CREATE VIEW view_user_max_7d AS
SELECT 
    src_ip,
    -- Buscamos el minuto más fuerte de TODA la semana
    max(sum_packets) / 60 as max_pps_weekly,
    max(sum_bytes) / 60 as max_bps_weekly
FROM flow_stats_1m
WHERE window_start >= now() - INTERVAL 7 DAY
GROUP BY src_ip;