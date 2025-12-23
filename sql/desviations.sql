WITH stats AS (
    -- Calculamos el promedio y desviación del usuario en la última hora
    SELECT 
        src_ip,
        avg(total_packets/10) as avg_pps,
        stddevPop(total_packets/10) as std_pps
    FROM default.flow_metrics_10s
    WHERE window_start BETWEEN now() - INTERVAL 1 HOUR AND now() - INTERVAL 20 SECOND
    GROUP BY src_ip
)
SELECT
    curr.src_ip,
    (curr.total_packets / 10) as current_pps,
    s.avg_pps,
    -- Z-Score: Cuántas desviaciones estándar por encima de su normalidad está
    (current_pps - s.avg_pps) / nullif(s.std_pps, 0) as z_score
FROM default.flow_metrics_10s as curr
JOIN stats s ON curr.src_ip = s.src_ip
WHERE 
    curr.window_start >= now() - INTERVAL 10 SECOND
    AND current_pps > 1000 -- Ignorar tráfico pequeño
    AND z_score > 3 -- Si el tráfico es 3 veces su desviación estándar usual -> ALERTA
ORDER BY z_score DESC