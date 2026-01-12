package com.accessbank.cdc.repository;

import com.accessbank.cdc.model.Customer;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CustomerRepository extends JpaRepository<Customer, Long> {
}
