## Análisis de DDoS

Estoy intentando armar un sistema anti ddos con goflow2 que usa kafka y clickhouse.

Necesito detectar DDoS con combinaciones de métricas (pps/bps/flows/s, cardinalidades, entropía).

objetivo real es detectar clientes residenciales que EMITEN DDoS (outbound), por lo que la agregación correcta es por src_ip (abonado).

Definimos una arquitectura sin servicio externo: ClickHouse con Materialized Views para generar tablas agregadas por ventana (10s) y vistas para baseline/detección.

## Nombre de la bd clickhouse
default

## Estructura de tablas

flows
flows_5m
flows_5m_view
flows_raw
flows_raw_view

### Estructura tabla flows_raw
date Date 
time_inserted_ns DateTime64(9) 
time_received_ns DateTime64(9) 
time_flow_start_ns DateTime64(9) 
sequence_num UInt32 
sampling_rate UInt64 
sampler_address FixedString(16) 
src_addr FixedString(16) 
dst_addr FixedString(16) 
src_as UInt32 
dst_as UInt32 
etype UInt32 
proto UInt32 
src_port UInt32 
dst_port UInt32 
bytes UInt64 
packets UInt64

## SQL ejemplo de conversion correcta de IP
```sql
SELECT 
  time_inserted_ns,
  IPv4NumToString(reinterpretAsUInt32(reverse(reinterpretAsString(src_addr)))) AS src_ip,
  IPv4NumToString(reinterpretAsUInt32(reverse(reinterpretAsString(dst_addr)))) AS dst_ip,
  src_port,
  dst_port,
  proto,
  packets
FROM default.flows_raw_view
WHERE time_inserted_ns > now() - INTERVAL 5 MINUTE
ORDER BY time_inserted_ns DESC
LIMIT 100
```

