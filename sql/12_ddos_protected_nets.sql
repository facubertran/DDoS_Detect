-- 1. Tabla para tus Redes Propias (Clientes / Infraestructura)
CREATE TABLE ddos_protected_nets (
    cidr String,
    description String
) ENGINE = MergeTree()
ORDER BY cidr;

-- 2. Carga tus redes (Ejemplo)
INSERT INTO ddos_protected_nets VALUES ('10.0.0.0/8', 'Clientes');

-- 3. Diccionario en Memoria (IP_TRIE)
CREATE DICTIONARY dict_protected_nets
(
    cidr String,
    description String
)
PRIMARY KEY cidr
SOURCE(CLICKHOUSE(HOST 'localhost' PORT 9000 USER 'default' PASSWORD '' DB 'default' TABLE 'ddos_protected_nets'))
LIFETIME(MIN 60 MAX 300)
LAYOUT(IP_TRIE);