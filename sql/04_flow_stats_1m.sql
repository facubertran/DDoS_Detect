CREATE TABLE default.flow_stats_1m (
    window_start DateTime,
    src_ip IPv4,
    
    sum_packets UInt64,
    sum_bytes UInt64,
    count_intervals UInt16 -- Cuántas ventanas de 10s componen este minuto
)
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMMDD(window_start)
ORDER BY (window_start, src_ip)
ALTER TABLE flow_stats_1m MODIFY TTL window_start + INTERVAL 30 DAY;