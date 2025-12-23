CREATE MATERIALIZED VIEW default.mv_flow_metrics_10s TO default.flow_metrics_10s AS
SELECT
    toStartOfInterval(time_received_ns, INTERVAL 10 SECOND) as window_start,
    
    -- CONVERSIÓN CON REVERSE
    IPv4NumToString(reinterpretAsUInt32(reverse(reinterpretAsString(src_addr)))) AS src_ip,

    sum(bytes * if(sampling_rate > 0, sampling_rate, 1)) as total_bytes,
    sum(packets * if(sampling_rate > 0, sampling_rate, 1)) as total_packets,
    count() as total_flows,
    
    -- Destino Con Reverse
    uniqState(toIPv4(reinterpretAsUInt32(reverse(substring(reinterpretAsString(dst_addr), 1, 4))))) as uniq_dst_ips,
    uniqState(toUInt16(dst_port)) as uniq_dst_ports

FROM default.flows_raw
WHERE length(reinterpretAsString(src_addr)) >= 4
GROUP BY window_start, src_ip