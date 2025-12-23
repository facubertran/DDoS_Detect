# Anti DDoS

## ClickHouse
Username: default
Password: flow

## Kafka
- KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1
Se agrego variable para admitir kafka sin cluster

## Mikrotik
```
/ip traffic-flow
set enabled=yes
/ip traffic-flow target
add dst-address=10.199.0.15 src-address=10.199.15.9 version=ipfix
```

## Exclusiones

```sql
INSERT INTO ddos_whitelist_nets VALUES ('82.97.205.0/24', 'G-Core Labs S.A.');
```

```sql
SELECT * FROM ddos_whitelist;
```

```sql
ALTER TABLE ddos_whitelist DELETE WHERE ip = '172.217.192.0';
```

## Posibles ataques y CDNs
```sql
SELECT 
    src_ip,
    
    -- Para que sepas quién es (puedes hacer whois a la IP)
    max(current_pps) as velocidad_max_pps,
    
    -- Cuántos minutos lleva molestando
    max(persistencia_minutos) as minutos_flaggeado
    
FROM view_ddos_baseline_optimized
WHERE status = 'Critical_Constant_Attack'
GROUP BY src_ip
ORDER BY velocidad_max_pps DESC
```