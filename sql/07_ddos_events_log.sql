CREATE TABLE ddos_events_log (
    event_time DateTime,
    src_ip IPv4,
    pps UInt64,
    bps UInt64,
    z_score Float64,
    status String
) ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(event_time)
ORDER BY (event_time, src_ip)
TTL event_time + INTERVAL 3 DAY; -- Borrar logs viejos automáticamente