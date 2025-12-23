CREATE MATERIALIZED VIEW default.mv_flow_stats_1m TO default.flow_stats_1m AS
SELECT
    toStartOfInterval(window_start, INTERVAL 1 MINUTE) as window_start,
    src_ip,
    
    sum(total_packets) as sum_packets,
    sum(total_bytes) as sum_bytes,
    count() as count_intervals
FROM default.flow_metrics_10s
GROUP BY
    window_start,
    src_ip;