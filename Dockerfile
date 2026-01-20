# Dockerfile for CDC Sync Service (used with GoldenGate setup)
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Copy the Spring Boot JAR
COPY build/libs/cdc-sync-service-*.jar app.jar

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]

