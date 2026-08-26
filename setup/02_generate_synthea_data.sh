#!/bin/bash
# ============================================
# STEP 2: Generate Synthea Data (start small, validate, then scale)
# ============================================
set -e

mkdir -p ~/omop-project
cd ~/omop-project

if [ ! -f synthea-with-dependencies.jar ]; then
    echo "Downloading Synthea..."
    curl -L -o synthea-with-dependencies.jar \
        https://github.com/synthetichealth/synthea/releases/download/master-branch-latest/synthea-with-dependencies.jar
fi

# IMPORTANT: force English/US JVM locale explicitly.
# If the machine's system locale is Thai (th-TH), Java's default
# Calendar/date formatting can silently switch to the Buddhist Era
# calendar (year = Gregorian year + 543), which corrupts every date
# Synthea generates (and can produce invalid dates like "2527-02-29",
# since BE/Gregorian leap-year alignment shifts under the +543 offset).
# These flags force standard Gregorian-calendar, English-locale output
# regardless of the machine's system locale.
JAVA_LOCALE_FLAGS="-Duser.language=en -Duser.country=US"

echo "=== Generating VALIDATION batch (500 patients) ==="
java $JAVA_LOCALE_FLAGS -jar synthea-with-dependencies.jar -p 500 \
    --exporter.csv.export true \
    --exporter.baseDirectory ./data_validation/ \
    Massachusetts

echo ""
echo "=== Validation batch complete. Sanity-check the dates: ==="
head -3 ./data_validation/csv/patients.csv | cut -d',' -f2
echo "(BIRTHDATE column above — years should look like 19xx/20xx, not 25xx)"
echo ""
echo "=== Respiratory-related condition records: ==="
grep -i -E "asthma|COPD|emphysema|chronic obstructive|chronic bronchitis" \
    ./data_validation/csv/conditions.csv | wc -l
echo ""
echo "If pipeline (next scripts) runs cleanly on this batch, re-run this script"
echo "with -p 5000 or -p 10000 and a new --exporter.baseDirectory (e.g. ./data_full/)"