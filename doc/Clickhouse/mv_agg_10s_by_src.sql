CREATE MATERIALIZED VIEW IF NOT EXISTS mv_agg_10s_by_src
TO agg_10s_by_src
AS
SELECT
    toStartOfInterval(time_received_ns, INTERVAL 10 SECOND) AS bucket_10s,
    toDate(time_received_ns) AS date,
    src_addr,

    sum(bytes)   AS bytes_total,
    sum(packets) AS packets_total,
    count()      AS flows_total,

    -- Exacto (preciso). Si en algún ISP grande esto te pega, luego lo cambiás por uniqCombined64.
    uniqExact(dst_addr) AS uniq_dst_addr,
    uniqExact(dst_port) AS uniq_dst_port,
    uniqExact(src_port) AS uniq_src_port,

    if(packets_total = 0, 0.0, bytes_total / packets_total) AS avg_pkt_size,

    avg(toUInt64(greatest(0, time_received_ns - time_flow_start_ns))) AS dur_avg_ns,
    quantileExact(0.50)(toUInt64(greatest(0, time_received_ns - time_flow_start_ns))) AS dur_p50_ns,
    quantileExact(0.95)(toUInt64(greatest(0, time_received_ns - time_flow_start_ns))) AS dur_p95_ns,
    max(toUInt64(greatest(0, time_received_ns - time_flow_start_ns))) AS dur_max_ns
FROM flows_raw
GROUP BY
    bucket_10s, date, src_addr;
