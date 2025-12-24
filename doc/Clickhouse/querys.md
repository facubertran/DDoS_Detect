## Top destinos por paquetes/bytes (en ese bucket 10s)

```sql
SELECT
  dst_addr,
  sum(packets) AS p,
  sum(bytes) AS b
FROM flows_raw
WHERE src_addr = {src:FixedString(16)}
  AND time_received_ns >= {t0:DateTime64(9)}
  AND time_received_ns <  {t1:DateTime64(9)}
GROUP BY dst_addr
ORDER BY p DESC
LIMIT 20;
```

## Top puertos destino + proto (firma de flood/reflexión/scan)

```sql
SELECT
  proto,
  dst_port,
  sum(packets) AS p,
  sum(bytes) AS b
FROM flows_raw
WHERE src_addr = {src:FixedString(16)}
  AND time_received_ns >= {t0:DateTime64(9)}
  AND time_received_ns <  {t1:DateTime64(9)}
GROUP BY proto, dst_port
ORDER BY p DESC
LIMIT 50;
```