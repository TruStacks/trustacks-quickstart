package com.trustacks.hello;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Minimal Spring Boot hello-world for the TruStacks workshop quickstart.
 * The Code Reviewer agent fingerprints this repo as a Java / Spring Boot
 * service; the DevOps Engineer emits CI + Helm + ArgoCD against it on /plan.
 */
@SpringBootApplication
@RestController
public class HelloApplication {

    public static void main(String[] args) {
        SpringApplication.run(HelloApplication.class, args);
    }

    @GetMapping("/")
    public String root() {
        return "hello from TruStacks quickstart";
    }

    @GetMapping("/healthz")
    public String healthz() {
        return "ok";
    }
}
