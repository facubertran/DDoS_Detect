CREATE DICTIONARY default.dict_whitelist_nets
(
    cidr String,
    description String
)
PRIMARY KEY cidr
SOURCE(CLICKHOUSE(HOST 'localhost' PORT 9000 USER 'default' PASSWORD 'flow' DB 'default' TABLE 'ddos_whitelist_nets'))
LIFETIME(MIN 60 MAX 300) -- Se actualiza cada 1 a 5 minutos
LAYOUT(IP_TRIE);