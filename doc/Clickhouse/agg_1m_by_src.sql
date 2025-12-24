CREATE TABLE IF NOT EXISTS agg_1m_by_src
(
    bucket_1m     DateTime,
    date          Date,
    src_addr      FixedString(16),

    bytes_total   UInt64,
    packets_total UInt64,
    flows_total   UInt32,

    uniq_dst_addr UInt32,
    uniq_dst_port UInt32,
    uniq_src_port UInt32,

    avg_pkt_size  Float64,

    dur_avg_ns    Float64,
    dur_p95_ns    UInt64,
    dur_max_ns    UInt64
)
ENGINE = MergeTree
PARTITION BY date
ORDER BY (bucket_1m, src_addr)
TTL date + INTERVAL 60 DAY;
