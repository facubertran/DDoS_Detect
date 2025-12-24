CREATE OR REPLACE VIEW default.flows_raw_v4_view AS
WITH
  (a -> IPv4NumToString(reinterpretAsUInt32(reverse(substring(reinterpretAsString(a), 13, 4))))) AS bin16_to_ipv4
SELECT
  date,
  time_inserted_ns,
  time_received_ns,
  time_flow_start_ns,
  sequence_num,
  sampling_rate,
  sampler_address,

  src_addr,
  dst_addr,

  bin16_to_ipv4(src_addr) AS src_ip,
  bin16_to_ipv4(dst_addr) AS dst_ip,

  src_as,
  dst_as,
  etype,
  proto,
  src_port,
  dst_port,
  bytes,
  packets
FROM default.flows_raw_view;
