-- Create Materialized View to populate flow_metrics_10s
CREATE MATERIALIZED VIEW IF NOT EXISTS default.mv_flow_metrics_10s TO default.flow_metrics_10s AS
SELECT
    -- Normalize time to 10-second windows
    toStartOfInterval(time_received_ns, INTERVAL 10 SECOND) as window_start,
    -- Convert FixedString(16) IPv6/IPv4 to IPv4 (Assuming IPv4 focus as per requirements)
    -- This handles the common case where IPv4 is mapped in IPv6 or just plain bytes.
    -- Adjust IPv4NumToString/reinterpret logic if strictly IPv4-only column is needed, 
    -- but for FixedString(16) source, we usually interpret specific bytes.
    -- For simplicity and standard GoFlow2 format (usually IPv4-mapped IPv6):
    toIPv4(IPv4NumToString(reinterpretAsUInt32(reverse(reinterpretAsString(src_addr))))) as src_ip,
    
    -- Volume
    sum(bytes) as total_bytes,
    sum(packets) as total_packets,
    count() as total_flows,
    
    -- Aggregation states for cardinality
    uniqState(toIPv4(IPv4NumToString(reinterpretAsUInt32(reverse(reinterpretAsString(dst_addr)))))) as uniq_dst_ips,
    uniqState(toUInt16(dst_port)) as uniq_dst_ports
FROM default.flows_raw
GROUP BY
    window_start,
    src_ip;
