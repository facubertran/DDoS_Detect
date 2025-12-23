Infraestructura Recomendada: Monitoreo ISP 20Gbps
Esta propuesta describe la arquitectura para procesar flujos de NetFlow/IPFIX de una red ISP con 20Gbps de tráfico, enfocada en detección de anomalías y retención corta (24 horas).

1. Análisis de Carga (Sizing)
Para dimensionar el hardware, debemos convertir el ancho de banda (20 Gbps) a tasa de eventos (eventos por segundo - EPS).

Tráfico Bruto: 20 Gbps.
Paquetes por Segundo (Estimado): Asumiendo un mix de tráfico de internet (~800 bytes/paquete), 20 Gbps ≈ 3.2 Millones de paquetes/segundo (Mpps).
Muestreo (Sampling): Con tu configuración actual de 1/1000.
3,200,000 / 1000 = ~3,200 flujos/segundo.
Conclusión preliminar: Una tasa de ingesta de 3k - 5k eventos/segundo es extremadamente baja para tecnologías Big Data como Kafka y ClickHouse.

ClickHouse puede ingerir millones de filas por segundo en un solo nodo.
Kafka puede manejar millares de mensajes por segundo con mínimas recursos.
El desafío no es el volumen de datos, sino la Alta Disponibilidad (HA) y la resiliencia. No querrás perder visibilidad de la red justo cuando tienes un ataque DDoS.

2. Arquitectura Propuesta (Alta Disponibilidad)
Para un ISP, recomiendo un clúster pequeño pero redundante para garantizar que el sistema siempre esté "on".

IPFIX UDP
Produce
Produce
Consume
Consume
Replication
Query
Router/Mikrotik
Load Balancer / VIP
GoFlow2 A
GoFlow2 B
Kafka Cluster
ClickHouse Node 1
ClickHouse Node 2
Grafana
Componentes
A. Colectores (GoFlow2)
Rol: Recibir UDP, decodificar y enviar a Kafka.
Escalado: Horizontal (Stateless).
Configuración: 2 Instancias detrás de una Virtual IP (usando keepalived) o un balanceador simple (ej. nginx stream module).
Por qué 2?: Si uno cae (mantenimiento o fallo), el otro sigue recibiendo los flujos.
B. Buffer (Kafka)
Rol: Desacople y pico de carga. Si ClickHouse se satura o reinicia, Kafka guarda los datos.
Escalado: Clúster de 3 Nodos.
Configuración: Replication Factor = 2 o 3 (garantiza que si un nodo muere, no pierdes datos).
Nota: Para 20Gbps muestreados, 3 nodos es "overkill" en rendimiento pero estándar para seguridad. Si el presupuesto es ajustado, 1 nodo robusto con RAID bueno puede bastar, pero es un punto único de fallo.
C. Almacenamiento (ClickHouse)
Rol: Guardar datos y permitir consultas rápidas analíticas.
Escalado: 2 Nodos con ReplicatedMergeTree.
Motor: Usar ReplicatedMergeTree sobre ZooKeeper/ClickHouse Keeper para tener los datos copiados en ambos servidores.
Retención: Configurar TTL en las tablas para borrar datos > 24 horas automáticamente.
3. Especificaciones de Hardware (Recomendadas)
Dado el bajo volumen real (por el sampling 1:1000), no necesitas "supercomputadoras".

Opción A: Cluster Robusto (Producción ISP Standard)
Rol	Cantidad	vCPU	RAM	Disco	Notas
GoFlow2	2	2-4	4 GB	50 GB SSD	Muy ligero de CPU.
Kafka + ZooKeeper	3	2-4	8-16 GB	500 GB SSD/NVMe	IOPS es clave.
ClickHouse	2	8-16	32 GB	1 TB NVMe	CPU para consultas rápidas.
Opción B: "All-in-One" Potente (Presupuesto Ajustado / MVP)
Si prefieres simplicidad sobre redundancia total:

Servidor Físico Único (Bare Metal):
CPU: 16-32 Cores.
RAM: 64-128 GB.
Disco: RAID 10 NVMe (Crítico para velocidad).
Ejecutar todo en Docker/Kubernetes.
Riesgo: Si el servidor muere, pierdes visibilidad.
4. Estrategia de Retención (TTL)
Para cumplir con el requisito de "limpiar flows de más de 1 día", configuramos el TTL nativo de ClickHouse al crear la tabla:

CREATE TABLE flows_raw (...)
ENGINE = ReplicatedMergeTree(...)
PARTITION BY toYYYYMMDD(date)
ORDER BY (date, time_received_ns)
TTL date + INTERVAL 1 DAY DELETE;  -- <--- AUTO BORRADO
Esto maneja la limpieza automáticamente en background sin scripts externos.

5. Detección de Anomalías
Para detectar tráfico anómalo (DDoS, barridos de puertos), tienes dos opciones:

Reactivo (Consultas):
Grafana consultando cada 10s: SELECT src_ip, sum(bytes) FROM flows WHERE time > now() - 10s GROUP BY src_ip HAVING sum(bytes) > UMBRAL.
Simple y efectivo.
Proactivo (Materialized Views):
Crear una "Vista Materializada" en ClickHouse que pre-calcule agregados por IP cada segundo.
Mucho más rápido para alertar.
Resumen
Para 20 Gbps con sampling 1:1000, la carga es baja para estas herramientas.

No te preocupes por el rendimiento de inserción.
Preocúpate por la red: Asegura que las interfaces de red de los servidores GoFlow2 sean de 10Gbps si planeas bajar el sampling en el futuro.
Escala horizontalmente Kafka y ClickHouse principalmente por disponibilidad, no por falta de potencia.