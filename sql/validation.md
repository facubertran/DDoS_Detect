# Validation Guide

Run the following validation steps to verify the ClickHouse schemas are correctly set up.

## 1. Create Tables and Views
Execute the generated SQL files in order:
```bash
clickhouse-client --multiquery < flows_raw.sql
clickhouse-client --multiquery < flow_metrics_10s.sql
clickhouse-client --multiquery < mv_flow_metrics_10s.sql
clickhouse-client --multiquery < detection_view.sql
```

## 2. Verify Schema Existence
Check if the tables and views exist:
```sql
SHOW TABLES;
```
Expected output should include:
- `flows_raw`
- `flow_metrics_10s`
- `mv_flow_metrics_10s`
- `v_ddos_detection`

## 3. Describe Tables
Verify the table structures match expectations:
```sql
DESCRIBE TABLE flows_raw;
DESCRIBE TABLE flow_metrics_10s;
```

## 4. Test Data Insertion (Optional)
Insert dummy data to test the Materialized View flow:
```sql
INSERT INTO flows_raw (
    date, time_inserted_ns, time_received_ns, src_addr, dst_addr, bytes, packets
) VALUES (
    today(), 
    now64(9), 
    now64(9), 
    -- 192.168.1.1 (Example byte representation for FixedString(16))
    unhex('00000000000000000000FFFFC0A80101'), 
    -- 8.8.8.8
    unhex('00000000000000000000FFFF08080808'),
    1000, 
    10
);
```

## 5. Verify Aggregation
Check if data appeared in the metrics table:
```sql
SELECT * FROM flow_metrics_10s;
```

## 6. Verify Detection View
Check the calculated rates:
```sql
SELECT * FROM v_ddos_detection;
```

## 7. Verify Attakers
```sql
SELECT 
    src_ip, 
    status, 
    
    -- Comparativa visual
    current_pps, 
    round(avg_pps) as pps_promedio,
    
    z_score, 
    formatReadableSize(current_bps) as ancho_banda
FROM default.view_ddos_baseline_optimized
ORDER BY z_score DESC
```

## 10s
```sql
SELECT * FROM default.flow_metrics_10s 
WHERE src_ip = '99.99.99.99' 
LIMIT 100
```