-- Create Detection View
CREATE VIEW IF NOT EXISTS default.v_ddos_detection AS
SELECT
    window_start,
    src_ip,
    
    -- Rates per second (window is 10s)
    sum(total_bytes) / 10.0 as bps,
    sum(total_packets) / 10.0 as pps,
    sum(total_flows) / 10.0 as flows_per_sec,
    
    -- Cardinalities (Merge the states)
    uniqMerge(uniq_dst_ips) as unique_destinations,
    uniqMerge(uniq_dst_ports) as unique_ports
FROM default.flow_metrics_10s
GROUP BY window_start, src_ip;
