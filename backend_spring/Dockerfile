FROM eclipse-temurin:17-jdk-alpine AS build

WORKDIR /workspace
COPY backend_spring/gradlew backend_spring/settings.gradle backend_spring/build.gradle ./
COPY backend_spring/gradle ./gradle
RUN sed -i 's/\r$//' gradlew && chmod +x gradlew
RUN ./gradlew --version --no-daemon
COPY backend_spring/src ./src
RUN ./gradlew bootJar --no-daemon \
    && cp "$(find build/libs -name '*.jar' ! -name '*-plain.jar' | head -n 1)" build/app.jar

FROM eclipse-temurin:17-jre-alpine

RUN apk add --no-cache curl \
    && addgroup -S popq \
    && adduser -S popq -G popq
WORKDIR /app
RUN mkdir -p /app/uploads && chown -R popq:popq /app
COPY --from=build --chown=popq:popq /workspace/build/app.jar /app/app.jar

USER popq
EXPOSE 8082
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "/app/app.jar"]
