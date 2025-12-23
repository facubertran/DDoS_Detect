perfecto, entonces si se corriera un cluster de 3 kafkas hubiera funcionado correctamente?

Thought for 2s




¡Exacto! Si hubieras desplegado un clúster de al menos 3 brokers de Kafka, hubiera funcionado con la configuración por defecto.

La razón es técnica pero sencilla: Kafka tiene un tema interno crítico llamado __consumer_offsets donde guarda qué mensaje ha leído cada consumidor (en este caso, ClickHouse). Por seguridad y alta disponibilidad, este tema viene preconfigurado para copiarse (replicarse) en 3 servidores distintos.

Como tú tenías solo 1 broker, Kafka intentaba crear las 3 copias, se daba cuenta de que le faltaban 2 servidores y fallaba, impidiendo que el tema se creara. Al no existir ese tema, ClickHouse no tenía dónde anotar "ya leí hasta aquí", y por eso daba el error Can't get assignment (no puedo obtener asignación).

Al establecer KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1, le dijimos: "Está bien, confórmate con una sola copia", lo cual es correcto y necesario para entornos de un solo nodo (standalone).



mkdir /mnt/flows

chmod 777 -R /mnt/flows/

volumes:
  clickhouse_data:
    driver: local
    driver_opts:
      type: none
      device: /mnt/flows
      o: bind


    volumes:
      - clickhouse_data:/var/lib/clickhouse



SELECT 
    src_ip, 
    status, 
    current_pps, 
    z_score, 
    formatReadableSize(current_bps) as ancho_banda
FROM default.view_ddos_baseline_optimized
ORDER BY z_score DESC