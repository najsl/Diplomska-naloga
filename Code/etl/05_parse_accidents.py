#!/usr/bin/env python3
"""
Parse staging_raw.pn2009_2023 → staging.accident_person
Uses csv module for proper handling of quoted fields (e.g. alcohol ",77").
Reads from DB, parses, inserts back.
"""
import csv
import io
import os
import sys

try:
    import psycopg2
    from psycopg2.extras import execute_values
except ImportError:
    print("Install psycopg2: pip install psycopg2-binary")
    sys.exit(1)


def main():
    conn = psycopg2.connect(
        host=os.environ.get("DB_HOST", "127.0.0.1"),
        port=os.environ.get("DB_PORT", "5432"),
        dbname=os.environ.get("DB_NAME", "diplomska"),
        user=os.environ.get("DB_USER", "diplomska"),
        password=os.environ.get("DB_PASSWORD", "diplomska"),
    )

    cur = conn.cursor()

    # Fetch raw lines (skip id=1 = header row)
    cur.execute(
        "SELECT id, raw_line FROM staging_raw.pn2009_2023 WHERE id > 1 ORDER BY id"
    )
    rows = cur.fetchall()

    # Parse with csv.reader
    def safe_int(x):
        try:
            return int(x) if x and str(x).strip() else None
        except (ValueError, TypeError):
            return None

    def safe_float(x):
        try:
            return float(str(x).replace(',', '.')) if x and str(x).strip() and str(x).strip() not in ('-', '...') else None
        except (ValueError, TypeError):
            return None

    parsed = []
    for row_id, raw in rows:
        if not raw or not raw.strip():
            continue
        try:
            reader = csv.reader(io.StringIO(raw))
            cells = next(reader)
        except Exception:
            continue

        if len(cells) < 36:
            continue
        # Skip header row (DatumPN in column 4)
        if len(cells) > 3 and cells[3] == 'DatumPN':
            continue

        parsed.append((
            safe_int(cells[0]),   # accident_id_source
            cells[1].strip() if len(cells) > 1 else None,   # classification
            cells[2].strip() if len(cells) > 2 else None,   # admin_unit_name
            cells[3].strip() if len(cells) > 3 else None,   # accident_date_raw
            cells[4].strip() if len(cells) > 4 else None,   # accident_time_raw
            cells[5].strip() if len(cells) > 5 else None,   # in_settlement_flag_raw
            cells[6].strip() if len(cells) > 6 else None,   # location
            cells[7].strip() if len(cells) > 7 else None,   # road_type
            cells[8].strip() if len(cells) > 8 else None,   # road_code
            cells[9].strip() if len(cells) > 9 else None,   # road_name
            cells[10].strip() if len(cells) > 10 else None,  # road_section_code
            cells[11].strip() if len(cells) > 11 else None,  # road_section_name
            cells[12].strip() if len(cells) > 12 else None,  # stationing_raw
            cells[13].strip() if len(cells) > 13 else None,  # place_description
            cells[14].strip() if len(cells) > 14 else None,   # cause_raw
            cells[15].strip() if len(cells) > 15 else None,   # type_raw
            cells[16].strip() if len(cells) > 16 else None,   # weather_raw
            cells[17].strip() if len(cells) > 17 else None,   # traffic_flow_raw
            cells[18].strip() if len(cells) > 18 else None,   # road_surface_condition_raw
            cells[19].strip() if len(cells) > 19 else None,   # road_surface_type_raw
            safe_float(cells[20]) if len(cells) > 20 else None,  # x_coord_raw
            safe_float(cells[21]) if len(cells) > 21 else None,  # y_coord_raw
            safe_int(cells[22]) if len(cells) > 22 else None,   # person_seq_source
            cells[23].strip() if len(cells) > 23 else None,  # role_in_event_raw
            safe_int(cells[24]) if len(cells) > 24 else None,  # age_years
            cells[25].strip() if len(cells) > 25 else None,  # sex_raw
            cells[26].strip() if len(cells) > 26 else None,  # residence_admin_unit
            cells[27].strip() if len(cells) > 27 else None,  # nationality
            cells[28].strip() if len(cells) > 28 else None,  # injury_severity_raw
            cells[29].strip() if len(cells) > 29 else None,  # participant_type_raw
            cells[30].strip() if len(cells) > 30 else None,  # seat_belt_used_raw
            safe_int(cells[31]) if len(cells) > 31 else None,  # driving_experience_years
            safe_int(cells[32]) if len(cells) > 32 else None,  # driving_experience_months
            cells[33].strip() if len(cells) > 33 else None,   # breath_test_raw (keep raw)
            cells[34].strip() if len(cells) > 34 else None,   # blood_alcohol_raw (keep raw)
            safe_int(cells[35]) if len(cells) > 35 else None,   # year_raw
        ))

    # Truncate and insert
    cur.execute("TRUNCATE staging.accident_person")

    execute_values(
        cur,
        """
        INSERT INTO staging.accident_person (
            accident_id_source, classification, admin_unit_name, accident_date_raw,
            accident_time_raw, in_settlement_flag_raw, location, road_type, road_code,
            road_name, road_section_code, road_section_name, stationing_raw, place_description,
            cause_raw, type_raw, weather_raw, traffic_flow_raw, road_surface_condition_raw,
            road_surface_type_raw, x_coord_raw, y_coord_raw, person_seq_source,
            role_in_event_raw, age_years, sex_raw, residence_admin_unit, nationality,
            injury_severity_raw, participant_type_raw, seat_belt_used_raw,
            driving_experience_years, driving_experience_months, breath_test_raw, blood_alcohol_raw,
            year_raw
        ) VALUES %s
        """,
        parsed,
        template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
        page_size=5000,
    )

    conn.commit()
    print(f"Inserted {len(parsed)} rows into staging.accident_person")
    cur.close()
    conn.close()


if __name__ == "__main__":
    main()
