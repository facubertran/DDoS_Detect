-- Create flows_raw table
CREATE TABLE IF NOT EXISTS flows_raw (
    date Date,
    time_inserted_ns DateTime64(9),
    time_received_ns DateTime64(9),
    time_flow_start_ns DateTime64(9),
    sequence_num UInt32,
    sampling_rate UInt64,
    sampler_address FixedString(16),
    src_addr FixedString(16),
    dst_addr FixedString(16),
    src_as UInt32,
    dst_as UInt32,
    etype UInt32,
    proto UInt32,
    src_port UInt32,
    dst_port UInt32,
    bytes UInt64,
    packets UInt64
)
ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(date)
ORDER BY (date, time_received_ns)
TTL date + INTERVAL 1 DAY DELETE;
