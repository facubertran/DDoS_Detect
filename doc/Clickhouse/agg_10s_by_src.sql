CREATE TABLE IF NOT EXISTS agg_10s_by_src
(
    bucket_10s   DateTime,
    date         Date,
    src_addr     FixedString(16),

    bytes_total   UInt64,
    packets_total UInt64,
    flows_total   UInt32,

    uniq_dst_addr  UInt32,
    uniq_dst_port  UInt32,
    uniq_src_port  UInt32,

    avg_pkt_size  Float64,

    -- Duraciones (ns) a partir de tus campos
    dur_avg_ns    Float64,
    dur_p50_ns    UInt64,
    dur_p95_ns    UInt64,
    dur_max_ns    UInt64
)
ENGINE = MergeTree
PARTITION BY date
ORDER BY (bucket_10s, src_addr)
TTL date + INTERVAL 30 DAY
SETTINGS index_granularity = 8192;
