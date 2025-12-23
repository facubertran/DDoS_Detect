CREATE TABLE default.flow_stats_1m (
    window_start DateTime,
    src_ip IPv4,                 -- AHORA SÍ: Tipo correcto
    sum_packets SimpleAggregateFunction(sum, UInt64),
    sum_bytes SimpleAggregateFunction(sum, UInt64)
) 
ENGINE = AggregatingMergeTree()
ORDER BY (window_start, src_ip)
TTL window_start + INTERVAL 7 DAY;