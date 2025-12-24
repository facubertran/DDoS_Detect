CREATE MATERIALIZED VIEW IF NOT EXISTS mv_agg_1m_by_src
TO agg_1m_by_src
AS
SELECT
    toStartOfInterval(bucket_10s, INTERVAL 1 MINUTE) AS bucket_1m,
    toDate(bucket_10s) AS date,
    src_addr,

    sum(bytes_total)   AS bytes_total,
    sum(packets_total) AS packets_total,
    sum(flows_total)   AS flows_total,

    -- rollup: tomá max (porque no es aditivo)
    max(uniq_dst_addr) AS uniq_dst_addr,
    max(uniq_dst_port) AS uniq_dst_port,
    max(uniq_src_port) AS uniq_src_port,

    if(sum(packets_total)=0, 0.0, sum(bytes_total)/sum(packets_total)) AS avg_pkt_size,

    avg(dur_avg_ns) AS dur_avg_ns,
    max(dur_p95_ns) AS dur_p95_ns,
    max(dur_max_ns) AS dur_max_ns
FROM agg_10s_by_src
GROUP BY bucket_1m, date, src_addr;
