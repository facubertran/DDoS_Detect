-- Create aggregated metrics table for 10s windows
CREATE TABLE IF NOT EXISTS default.flow_metrics_10s (
    window_start DateTime,
    src_ip IPv4,
    
    -- Simple Metrics (SummingMergeTree/AggregatingMergeTree logic)
    total_bytes SimpleAggregateFunction(sum, UInt64),
    total_packets SimpleAggregateFunction(sum, UInt64),
    total_flows SimpleAggregateFunction(sum, UInt64),
    
    -- Cardinality (using uniqState for accurate cardinality over time)
    uniq_dst_ips AggregateFunction(uniq, IPv4),
    uniq_dst_ports AggregateFunction(uniq, UInt16)
)
ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMMDD(window_start)
ORDER BY (window_start, src_ip)
TTL window_start + INTERVAL 1 WEEK;
