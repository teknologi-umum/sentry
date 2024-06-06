echo "${_group}Creating additional Kafka topics ..."

$dc up -d --no-build --no-recreate kafka

while [ true ]; do
  kafka_healthy=$($dc ps kafka | grep 'healthy')
  if [ ! -z "$kafka_healthy" ]; then
    break
  fi

  echo "Kafka container is not healthy, waiting for 30 seconds. If this took too long, abort the installation process, and check your Kafka configuration"
  sleep 30s
done

$dc exec kafka rpk cluster config set log_retention_ms 86400000
$dc exec kafka rpk cluster config set kafka_batch_max_bytes 52428800

NEEDED_KAFKA_TOPICS="ingest-attachments ingest-transactions ingest-events ingest-replay-recordings profiles ingest-occurrences ingest-metrics ingest-performance-metrics ingest-monitors monitors-clock-tasks"
EXISTING_KAFKA_TOPICS=$($dc exec kafka rpk -X brokers=kafka:9092 topic list)
for topic in $NEEDED_KAFKA_TOPICS; do
  if ! echo "$EXISTING_KAFKA_TOPICS" | grep -qE "(^| )$topic( |$)"; then
    $dc exec kafka rpk -X brokers=kafka:9092 topic create $topic
    echo ""
  fi
done

# This topic must have only a single partition for the consumer to work correctly
# https://github.com/getsentry/ops/blob/7dbc26f39c584ec924c8fef2ad5c532d6a158be3/k8s/clusters/us/_topicctl.yaml#L288-L295

if ! echo "$EXISTING_KAFKA_TOPICS" | grep -qE "(^| )monitors-clock-tick( |$)"; then
  $dc exec kafka kafka-topics --create --topic monitors-clock-tick --bootstrap-server kafka:9092 --partitions 1
fi

echo "${_endgroup}"
