package com.meridiantrust.sentinel.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfig {

    @Bean
    SecurityFilterChain filter(HttpSecurity h) throws Exception {
        return h
                .csrf(c -> c.disable())
                .authorizeHttpRequests(a -> a
                        .requestMatchers("/swagger-ui/**", "/v3/api-docs/**", "/actuator/health").permitAll()
                        .requestMatchers("/api/v1/rules/**").hasRole("ADMIN")
                        .requestMatchers("/api/v1/**").hasAnyRole("ANALYST", "ADMIN")
                        .anyRequest().authenticated()
                )
                .httpBasic(x -> {})
                .build();
    }

    @Bean
    UserDetailsService users() {
        return new InMemoryUserDetailsManager(
                User.withUsername("analyst")
                        .password("{noop}ankit")
                        .roles("ADMIN", "ANALYST")
                        .build()
        );
    }
}