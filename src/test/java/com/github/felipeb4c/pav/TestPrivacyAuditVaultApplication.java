package com.github.felipeb4c.pav;

import org.springframework.boot.SpringApplication;

public class TestPrivacyAuditVaultApplication {

	public static void main(String[] args) {
		SpringApplication.from(PrivacyAuditVaultApplication::main).with(TestcontainersConfiguration.class).run(args);
	}

}
