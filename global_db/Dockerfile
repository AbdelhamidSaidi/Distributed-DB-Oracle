FROM gvenzl/oracle-free:latest

ENV ORACLE_PASSWORD=oracle123
ENV ORACLE_CHARACTERSET=AL32UTF8

# Default scenario — override at build time:
#   SCENARIO=1 docker compose up --build
ARG SCENARIO=2

# Copy all init scripts into the image
COPY init/ /container-entrypoint-initdb.d/

# Keep only the trigger file matching the chosen scenario,
# rename it so Oracle picks it up in order as 03_triggers.sql
RUN if [ "$SCENARIO" = "1" ]; then \
        mv /container-entrypoint-initdb.d/03_triggers_scenario1.sql \
           /container-entrypoint-initdb.d/03_triggers.sql; \
    else \
        mv /container-entrypoint-initdb.d/03_triggers_scenario2.sql \
           /container-entrypoint-initdb.d/03_triggers.sql; \
    fi && \
    rm -f /container-entrypoint-initdb.d/03_triggers_scenario1.sql \
          /container-entrypoint-initdb.d/03_triggers_scenario2.sql

EXPOSE 1521 5500

