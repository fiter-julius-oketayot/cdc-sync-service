package com.accessbank.cdc.service;

import com.accessbank.cdc.model.Customer;
import com.accessbank.cdc.repository.CustomerRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

@Service
public class CdcEventHandler {

    private static final Logger log = LoggerFactory.getLogger(CdcEventHandler.class);

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final CustomerRepository customerRepository;
    private final JdbcTemplate oracleJdbcTemplate;

    public CdcEventHandler(CustomerRepository customerRepository,
                           @Qualifier("oracleJdbcTemplate") JdbcTemplate oracleJdbcTemplate) {
        this.customerRepository = customerRepository;
        this.oracleJdbcTemplate = oracleJdbcTemplate;
    }

    /**
     * Listens to Debezium events coming from Oracle (source-of-truth) and
     * applies them into Postgres via JPA.
     * Topic format: {topic.prefix}.{SCHEMA}.{TABLE} = oracle.DBZUSER.CUSTOMERS
     */
    @KafkaListener(topics = "oracle.DBZUSER.CUSTOMERS", groupId = "cdc-sync-oracle")
    public void handleOracleChange(ConsumerRecord<String, String> record) {
        try {
            log.debug("Received Oracle CDC event: key={}, value={}", record.key(), record.value());

            JsonNode root = objectMapper.readTree(record.value());

            // Check if event has 'op' field (Debezium format: op, before, after are at root level)
            if (!root.has("op")) {
                log.warn("No 'op' field in event, skipping: {}", record.value());
                return;
            }

            String op = root.get("op").asText();
            JsonNode after = root.get("after");
            JsonNode before = root.get("before");

            log.info("Processing Oracle CDC event: op={}, key={}", op, record.key());

            if ("c".equals(op) || "u".equals(op) || "r".equals(op)) {
                if (after == null || after.isNull()) {
                    log.warn("No 'after' state for op={}, skipping", op);
                    return;
                }
                Customer c = new Customer();
                // Oracle column names are uppercase
                c.setId(after.get("ID").asLong());
                c.setFirstName(after.get("FIRST_NAME").asText(null));
                c.setLastName(after.get("LAST_NAME").asText(null));
                c.setEmail(after.get("EMAIL").asText(null));
                customerRepository.save(c);
                log.info("Saved customer to PostgreSQL: id={}", c.getId());
            } else if ("d".equals(op)) {
                if (before != null && !before.isNull() && before.has("ID")) {
                    Long id = before.get("ID").asLong();
                    customerRepository.deleteById(id);
                    log.info("Deleted customer from PostgreSQL: id={}", id);
                }
            } else {
                log.warn("Unknown op type: {}", op);
            }
        } catch (Exception e) {
            log.error("Failed to handle Oracle CDC event", e);
        }
    }

    /**
     * Listens to Debezium events coming from Postgres and applies them back into Oracle.
     * This gives you bi-directional sync for the demo.
     *
     * NOTE: The SQL here is simplified and assumes a compatible 'customers' table
     * exists in Oracle. In a real project you would likely call stored procedures
     * or use a more robust upsert strategy.
     */
    @KafkaListener(topics = "postgres.public.customers", groupId = "cdc-sync-postgres")
    public void handlePostgresChange(ConsumerRecord<String, String> record) {
        try {
            log.debug("Received Postgres CDC event: key={}, value={}", record.key(), record.value());

            JsonNode root = objectMapper.readTree(record.value());

            // Check if event has 'op' field (Debezium format: op, before, after are at root level)
            if (!root.has("op")) {
                log.warn("No 'op' field in event, skipping: {}", record.value());
                return;
            }

            String op = root.get("op").asText();
            JsonNode after = root.get("after");
            JsonNode before = root.get("before");

            log.info("Processing Postgres CDC event: op={}, key={}", op, record.key());

            if ("c".equals(op) || "u".equals(op) || "r".equals(op)) {
                if (after == null || after.isNull()) {
                    log.warn("No 'after' state for op={}, skipping", op);
                    return;
                }
                Long id = after.get("id").asLong();
                String firstName = after.get("first_name").asText(null);
                String lastName = after.get("last_name").asText(null);
                String email = after.get("email").asText(null);

                // Simple upsert example using MERGE (Oracle 11g+). Uses DBZUSER.CUSTOMERS table
                String sql = "MERGE INTO DBZUSER.CUSTOMERS c USING (SELECT ? AS ID, ? AS FIRST_NAME, ? AS LAST_NAME, ? AS EMAIL FROM dual) s " +
                        "ON (c.ID = s.ID) " +
                        "WHEN MATCHED THEN UPDATE SET c.FIRST_NAME = s.FIRST_NAME, c.LAST_NAME = s.LAST_NAME, c.EMAIL = s.EMAIL " +
                        "WHEN NOT MATCHED THEN INSERT (ID, FIRST_NAME, LAST_NAME, EMAIL) VALUES (s.ID, s.FIRST_NAME, s.LAST_NAME, s.EMAIL)";

                oracleJdbcTemplate.update(sql, id, firstName, lastName, email);
                log.info("Upserted customer to Oracle: id={}", id);

            } else if ("d".equals(op)) {
                if (before != null && !before.isNull() && before.has("id")) {
                    Long id = before.get("id").asLong();
                    oracleJdbcTemplate.update("DELETE FROM DBZUSER.CUSTOMERS WHERE ID = ?", id);
                    log.info("Deleted customer from Oracle: id={}", id);
                }
            } else {
                log.warn("Unknown op type: {}", op);
            }
        } catch (Exception e) {
            log.error("Failed to handle Postgres CDC event", e);
        }
    }
}
