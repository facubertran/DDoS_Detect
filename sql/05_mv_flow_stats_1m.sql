CREATE MATERIALIZED VIEW default.mv_flow_stats_1m TO default.flow_stats_1m AS
SELECT
    toStartOfMinute(window_start) as window_start,
    src_ip,
    sum(total_packets) as sum_packets,
    sum(total_bytes) as sum_bytes
FROM default.flow_metrics_10s
GROUP BY window_start, src_ip;