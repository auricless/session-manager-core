#!/usr/bin/env bash
set -euo pipefail

core_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

artifact_version=$(python3 - "$core_dir/pom.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET

project = ET.parse(sys.argv[1]).getroot()
print(project.findtext("{http://maven.apache.org/POM/4.0.0}version", default=""))
PY
)
if [[ ! $artifact_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo 'The core POM must declare a fixed semantic release version' >&2
  exit 1
fi
artifact_name=session-manager-core-$artifact_version.jar
consumer_dir=$work_dir/consumer
consumer_cache=$work_dir/consumer-cache
mkdir -p "$consumer_dir/src/main/java" "$consumer_cache"
cp "$core_dir/consumer-check/ConsumerMain.java" "$consumer_dir/src/main/java/ConsumerMain.java"

if [[ -n ${CONSUMER_REPOSITORY_URL:-} ]]; then
  repository_url=$CONSUMER_REPOSITORY_URL
  if [[ -z ${CONSUMER_SETTINGS_PATH:-} ]]; then
    echo 'CONSUMER_SETTINGS_PATH is required with CONSUMER_REPOSITORY_URL' >&2
    exit 1
  fi
  settings_path=$CONSUMER_SETTINGS_PATH
else
  if [[ ! -f $core_dir/target/$artifact_name ]]; then
    echo "Build the core first with mvn verify: target/$artifact_name is missing" >&2
    exit 1
  fi
  repository_url=file://$work_dir/artifact-repository
  settings_path=$work_dir/settings.xml
  cat > "$settings_path" <<'XML'
<settings xmlns="http://maven.apache.org/SETTINGS/1.2.0"/>
XML
  mvn -B --no-transfer-progress \
    -Dmaven.repo.local="$work_dir/deploy-cache" \
    org.apache.maven.plugins:maven-deploy-plugin:3.1.4:deploy-file \
    -Dfile="$core_dir/target/$artifact_name" \
    -DpomFile="$core_dir/pom.xml" \
    -DrepositoryId=consumer-check \
    -Durl="$repository_url"
fi

repository_xml_url=$(python3 - "$repository_url" <<'PY'
import sys
from urllib.parse import urlsplit
from xml.sax.saxutils import escape

url = sys.argv[1]
parsed = urlsplit(url)
valid_https = parsed.scheme == "https" and parsed.hostname is not None
valid_file = (
    parsed.scheme == "file"
    and parsed.netloc in ("", "localhost")
    and parsed.path.startswith("/")
)
if (
    not (valid_https or valid_file)
    or parsed.username is not None
    or parsed.password is not None
    or parsed.query
    or parsed.fragment
):
    raise SystemExit(
        "Consumer repository URL must be HTTPS or an absolute file URL "
        "without embedded credentials or query parameters"
    )
print(escape(url))
PY
)

if [[ ! -f $settings_path ]]; then
  echo 'Consumer settings file does not exist' >&2
  exit 1
fi

cat > "$consumer_dir/pom.xml" <<XML
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>consumer.check</groupId>
  <artifactId>standalone-consumer</artifactId>
  <version>1.0.0</version>
  <properties>
    <maven.compiler.release>17</maven.compiler.release>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
  </properties>
  <repositories>
    <repository>
      <id>consumer-check</id>
      <url>$repository_xml_url</url>
    </repository>
  </repositories>
  <dependencies>
    <dependency>
      <groupId>org.c3cavite</groupId>
      <artifactId>session-manager-core</artifactId>
      <version>$artifact_version</version>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <version>3.16.0</version>
      </plugin>
    </plugins>
  </build>
</project>
XML

mvn -B --no-transfer-progress \
  -f "$consumer_dir/pom.xml" \
  -s "$settings_path" \
  -Dmaven.repo.local="$consumer_cache" \
  compile

resolved_jar=$consumer_cache/org/c3cavite/session-manager-core/$artifact_version/$artifact_name
java -cp "$consumer_dir/target/classes:$resolved_jar" ConsumerMain
