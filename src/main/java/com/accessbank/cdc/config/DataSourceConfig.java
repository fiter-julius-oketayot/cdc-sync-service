package com.accessbank.cdc.config;

import java.util.HashMap;
import java.util.Map;

import javax.sql.DataSource;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.jdbc.DataSourceBuilder;
import org.springframework.boot.orm.jpa.EntityManagerFactoryBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean;
import org.springframework.transaction.PlatformTransactionManager;

import jakarta.persistence.EntityManagerFactory;

@Configuration
@EnableJpaRepositories(
    basePackages = "com.accessbank.cdc.repository",
    entityManagerFactoryRef = "postgresEntityManagerFactory",
    transactionManagerRef = "postgresTransactionManager"
)
public class DataSourceConfig {

    /**
     * Primary PostgreSQL DataSource - used by JPA/Hibernate for CustomerRepository
     */
    @Primary
    @Bean(name = "postgresDataSource")
    @ConfigurationProperties(prefix = "spring.datasource")
    public DataSource postgresDataSource() {
        return DataSourceBuilder.create().build();
    }

    /**
     * EntityManagerFactory configured for PostgreSQL
     */
    @Primary
    @Bean(name = "postgresEntityManagerFactory")
    public LocalContainerEntityManagerFactoryBean postgresEntityManagerFactory(
            EntityManagerFactoryBuilder builder,
            @Qualifier("postgresDataSource") DataSource dataSource) {

        Map<String, Object> properties = new HashMap<>();
        properties.put("hibernate.dialect", "org.hibernate.dialect.PostgreSQLDialect");
        properties.put("hibernate.hbm2ddl.auto", "none");
        properties.put("hibernate.show_sql", "true");

        return builder
                .dataSource(dataSource)
                .packages("com.accessbank.cdc.model")
                .persistenceUnit("postgres")
                .properties(properties)
                .build();
    }

    /**
     * TransactionManager for PostgreSQL
     */
    @Primary
    @Bean(name = "postgresTransactionManager")
    public PlatformTransactionManager postgresTransactionManager(
            @Qualifier("postgresEntityManagerFactory") EntityManagerFactory entityManagerFactory) {
        return new JpaTransactionManager(entityManagerFactory);
    }

    /**
     * Secondary Oracle DataSource - used only by JdbcTemplate for direct Oracle queries
     */
    @Bean(name = "oracleDataSource")
    @ConfigurationProperties(prefix = "oracle.datasource")
    public DataSource oracleDataSource() {
        return DataSourceBuilder.create().build();
    }

    @Bean(name = "oracleJdbcTemplate")
    public JdbcTemplate oracleJdbcTemplate(@Qualifier("oracleDataSource") DataSource oracleDataSource) {
        return new JdbcTemplate(oracleDataSource);
    }
}
