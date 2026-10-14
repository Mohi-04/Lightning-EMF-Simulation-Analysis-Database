USE LIGHTNING;

-- ============================================================
-- QUERY - 1: STATION WISE MEAUREMENT SUMMARY
-- Station coverage: which stations have the most recorded lightning events.
-- Lightning type: whether the database contains intracloud (IC), cloud-to-ground (CG), or cloud-to-cloud (CC) events.
-- Electric-field availability: which stations have non-null EF measurements.
-- Magnetic-field availability: which stations have non-null MF measurements.
-- Geographical context: the location and site elevation of each station.
-- ============================================================

SELECT
os.STATION_ID,
os.STATION_NAME,
os.COUNTRY,
os.LATITUDE,
os.LONGITUDE,
os.ALTITUDE_m AS SITE_ELEVATION_m,

GROUP_CONCAT(
    DISTINCT le.EVENT_ID
    ORDER BY le.EVENT_ID
    SEPARATOR ', '
) AS EVENT_IDS,

COUNT(DISTINCT le.EVENT_ID) AS TOTAL_EVENTS,

COUNT(DISTINCT CASE
    WHEN le.LIGHTNING_TYPE = 'IC' THEN le.EVENT_ID
END) AS IC_EVENTS,

COUNT(DISTINCT CASE
    WHEN le.LIGHTNING_TYPE = 'CG' THEN le.EVENT_ID
END) AS CG_EVENTS,

COUNT(DISTINCT CASE
    WHEN le.LIGHTNING_TYPE = 'CC' THEN le.EVENT_ID
END) AS CC_EVENTS,

COUNT(DISTINCT lm.MEASUREMENT_ID) AS TOTAL_MEASUREMENTS,

COUNT(DISTINCT CASE
    WHEN lm.E_FIELD_V_m IS NOT NULL
    THEN lm.MEASUREMENT_ID
END) AS EF_MEASUREMENTS,

COUNT(DISTINCT CASE
    WHEN lm.H_FIELD_A_m IS NOT NULL
    THEN lm.MEASUREMENT_ID
END) AS MF_MEASUREMENTS

FROM observation_stations os

LEFT JOIN lightning_events le
ON os.STATION_ID = le.STATION_ID

LEFT JOIN lightning_measurements lm
ON le.EVENT_ID = lm.EVENT_ID

GROUP BY
os.STATION_ID,
os.STATION_NAME,
os.COUNTRY,
os.LATITUDE,
os.LONGITUDE,
os.ALTITUDE_m

ORDER BY TOTAL_EVENTS DESC;

SELECT
    EVENT_ID,
    COUNT(*) AS MEASUREMENT_COUNT
FROM lightning_measurements
GROUP BY EVENT_ID
ORDER BY EVENT_ID;


-- ============================================================
-- QUERY 2: EVENT-WISE MEASUREMENT DISTRIBUTION
-- Purpose:
-- Determine the number of measurement records associated
-- with each lightning event and its observation station.
-- Also inspect the time range covered by the measurements.
-- ============================================================

SELECT
    os.STATION_NAME,
    le.EVENT_ID,
    le.LIGHTNING_TYPE,
    le.EVENT_DATE_TIME,

    COUNT(lm.MEASUREMENT_ID) AS TOTAL_MEASUREMENTS,
    COUNT(lm.E_FIELD_V_m) AS EF_DATA_POINTS,
    COUNT(lm.H_FIELD_A_m) AS MF_DATA_POINTS,

    MIN(lm.TIME_us) AS START_TIME_us,
    MAX(lm.TIME_us) AS END_TIME_us

FROM lightning_events le

JOIN observation_stations os
    ON le.STATION_ID = os.STATION_ID

LEFT JOIN lightning_measurements lm
    ON le.EVENT_ID = lm.EVENT_ID

GROUP BY
    os.STATION_NAME,
    le.EVENT_ID,
    le.LIGHTNING_TYPE,
    le.EVENT_DATE_TIME

ORDER BY
    os.STATION_NAME,
    le.EVENT_ID;
    


-- ============================================================
-- QUERY 3: LIGHTNING CHANNEL AND EVENT OVERVIEW
-- Purpose:
-- Inspect channel geometry and physical parameters associated
-- with each event and observation station.
-- ============================================================

SELECT
    os.STATION_NAME,
    le.EVENT_ID,
    le.LIGHTNING_TYPE,
    lc.CHANNEL_ID,
    lc.CHANNEL_TYPE,
    lc.CHANNEL_LENGTH_m,
    lc.PROPAGATION_VELOCITY_m_s,
    lc.PEAK_CURRENT_kA
FROM lightning_channels lc
JOIN lightning_events le
    ON lc.EVENT_ID = le.EVENT_ID
JOIN observation_stations os
    ON le.STATION_ID = os.STATION_ID
ORDER BY
    os.STATION_NAME,
    le.EVENT_ID,
    lc.CHANNEL_ID;    
    
    
    
-- ============================================================
-- QUERY 4: CHANNEL GEOMETRY SUMMARY
-- Purpose:
-- Summarize the number of points, segment lengths, and
-- coordinate ranges for each lightning channel.
-- ============================================================

SELECT
    os.STATION_NAME,
    le.EVENT_ID,
    lc.CHANNEL_ID,
    lc.CHANNEL_TYPE,
    lc.CHANNEL_LENGTH_m AS STORED_LENGTH_m,

    COUNT(cp.CHANNEL_POINT_ID) AS TOTAL_POINTS,

    MIN(cp.X_m) AS MIN_X_m,
    MAX(cp.X_m) AS MAX_X_m,

    MIN(cp.Y_m) AS MIN_Y_m,
    MAX(cp.Y_m) AS MAX_Y_m,

    MIN(cp.Z_m) AS MIN_Z_m,
    MAX(cp.Z_m) AS MAX_Z_m,

    SUM(cp.SEGMENT_LENGTH_m) AS SUM_SEGMENT_LENGTHS_m

FROM lightning_channels lc

JOIN lightning_events le
    ON lc.EVENT_ID = le.EVENT_ID

JOIN observation_stations os
    ON le.STATION_ID = os.STATION_ID

LEFT JOIN channel_points cp
    ON lc.CHANNEL_ID = cp.CHANNEL_ID

GROUP BY
    os.STATION_NAME,
    le.EVENT_ID,
    lc.CHANNEL_ID,
    lc.CHANNEL_TYPE,
    lc.CHANNEL_LENGTH_m

ORDER BY
    os.STATION_NAME,
    le.EVENT_ID;
    
-- ============================================================
-- QUERY 5: ATMOSPHERIC CONDITIONS BY LIGHTNING EVENT
-- Purpose:
-- Retrieve the atmospheric conditions recorded for each event
-- and identify missing environmental data.
-- ============================================================

SELECT
    os.STATION_NAME,
    le.EVENT_ID,
    le.LIGHTNING_TYPE,
    le.EVENT_DATE_TIME,

    ac.TEMP_C,
    ac.PRESSURE_hPa,
    ac.HUMIDITY_PERCENT,
    ac.WIND_SPEED_m_s,

    CASE
        WHEN ac.COND_ID IS NULL THEN 'NOT RECORDED'
        ELSE 'RECORD EXISTS'
    END AS ATMOSPHERIC_DATA_STATUS

FROM lightning_events le

JOIN observation_stations os
    ON le.STATION_ID = os.STATION_ID

LEFT JOIN atmospheric_conds ac
    ON le.EVENT_ID = ac.EVENT_ID

ORDER BY
    os.STATION_NAME,
    le.EVENT_ID;
    
    
-- ============================================================
-- QUERY 6: MEASUREMENT DATA QUALITY AND TIME COVERAGE
--
-- Purpose:
-- 1. Count total measurement records for each event.
-- 2. Count valid electric-field and magnetic-field values.
-- 3. Find the time range covered by the measurements.
-- 4. Identify events that have no measurement data.
-- ============================================================

SELECT
    le.EVENT_ID,
    le.LIGHTNING_TYPE,
    os.STATION_NAME,

    COUNT(lm.MEASUREMENT_ID) AS TOTAL_RECORDS,

    COUNT(lm.E_FIELD_V_m) AS VALID_E_FIELD_RECORDS,
    COUNT(lm.H_FIELD_A_m) AS VALID_H_FIELD_RECORDS,

    MIN(lm.TIME_us) AS START_TIME_us,
    MAX(lm.TIME_us) AS END_TIME_us,

    CASE
        WHEN COUNT(lm.MEASUREMENT_ID) = 0
            THEN 'NO MEASUREMENTS'
        WHEN COUNT(lm.E_FIELD_V_m) = 0
             AND COUNT(lm.H_FIELD_A_m) = 0
            THEN 'NO VALID FIELD VALUES'
        WHEN COUNT(lm.E_FIELD_V_m) = 0
            THEN 'E-FIELD MISSING'
        WHEN COUNT(lm.H_FIELD_A_m) = 0
            THEN 'H-FIELD MISSING'
        ELSE 'FIELD DATA AVAILABLE'
    END AS DATA_STATUS

FROM lightning_events le

JOIN observation_stations os
    ON le.STATION_ID = os.STATION_ID

LEFT JOIN lightning_measurements lm
    ON le.EVENT_ID = lm.EVENT_ID

GROUP BY
    le.EVENT_ID,
    le.LIGHTNING_TYPE,
    os.STATION_NAME

ORDER BY
    le.EVENT_ID;
    
    

-- ============================================================
-- QUERY 7: INSPECT MEASURED ELECTRIC AND MAGNETIC FIELDS
--
-- Purpose:
-- 1. Retrieve measurements for Event 103.
-- 2. Inspect the time, electric-field, and magnetic-field values.
-- 3. Check the recorded data before further waveform analysis.
-- ============================================================

SELECT
    MEASUREMENT_ID,
    EVENT_ID,
    TIME_us,
    E_FIELD_V_m,
    H_FIELD_A_m
FROM lightning_measurements
WHERE EVENT_ID = 103
ORDER BY TIME_us ASC
LIMIT 20;



-- ============================================================
-- QUERY 8: CHECK CHANNEL DATA FOR EACH LIGHTNING EVENT
--
-- Purpose:
-- 1. List every recorded lightning event.
-- 2. Check whether a channel record exists for that event.
-- 3. Display the available channel parameters.
-- 4. Identify events with missing channel information.
-- ============================================================

SELECT
    os.STATION_NAME,
    le.EVENT_ID,
    le.LIGHTNING_TYPE,
    lc.CHANNEL_ID,
    lc.CHANNEL_TYPE,
    lc.CHANNEL_LENGTH_m,
    lc.PROPAGATION_VELOCITY_m_s,
    lc.PEAK_CURRENT_kA,

    CASE
        WHEN lc.CHANNEL_ID IS NULL
            THEN 'NO CHANNEL DATA'
        ELSE 'CHANNEL DATA AVAILABLE'
    END AS CHANNEL_STATUS

FROM lightning_events le

JOIN observation_stations os
    ON le.STATION_ID = os.STATION_ID

LEFT JOIN lightning_channels lc
    ON le.EVENT_ID = lc.EVENT_ID

ORDER BY
    le.EVENT_ID,
    lc.CHANNEL_ID;



-- ============================================================
-- QUERY 9: VERIFY CHANNEL GEOMETRY
--
-- Purpose:
-- 1. Count the geometry points stored for each channel.
-- 2. Compare the stored channel length with summed segment lengths.
-- 3. Identify channels with missing geometry or length discrepancies.
-- ============================================================

SELECT
    os.STATION_NAME,
    le.EVENT_ID,
    lc.CHANNEL_ID,
    lc.CHANNEL_TYPE,
    lc.CHANNEL_LENGTH_m AS STORED_LENGTH_m,

    COUNT(cp.CHANNEL_POINT_ID) AS TOTAL_POINTS,

    SUM(cp.SEGMENT_LENGTH_m) AS SUM_SEGMENT_LENGTHS_m,

    CASE
        WHEN COUNT(cp.CHANNEL_POINT_ID) = 0
            THEN 'NO GEOMETRY'
        WHEN SUM(cp.SEGMENT_LENGTH_m) IS NULL
            THEN 'SEGMENT LENGTHS MISSING'
        WHEN ABS(
            lc.CHANNEL_LENGTH_m - SUM(cp.SEGMENT_LENGTH_m)
        ) > 1.0
            THEN 'LENGTH MISMATCH'
        ELSE 'LENGTHS CONSISTENT'
    END AS GEOMETRY_STATUS

FROM lightning_channels lc

JOIN lightning_events le
    ON lc.EVENT_ID = le.EVENT_ID

JOIN observation_stations os
    ON le.STATION_ID = os.STATION_ID

LEFT JOIN channel_points cp
    ON lc.CHANNEL_ID = cp.CHANNEL_ID

GROUP BY
    os.STATION_NAME,
    le.EVENT_ID,
    lc.CHANNEL_ID,
    lc.CHANNEL_TYPE,
    lc.CHANNEL_LENGTH_m

ORDER BY
    lc.CHANNEL_ID;




-- ============================================================
-- QUERY 10: CHECK ATMOSPHERIC DATA COVERAGE
--
-- Purpose:
-- 1. List every lightning event and its station.
-- 2. Display available temperature, pressure, humidity and wind.
-- 3. Identify missing atmospheric-condition records.
-- ============================================================

SELECT
    os.STATION_NAME,
    le.EVENT_ID,
    le.LIGHTNING_TYPE,
    le.EVENT_DATE_TIME,

    ac.TEMP_C,
    ac.PRESSURE_hPa,
    ac.HUMIDITY_PERCENT,
    ac.WIND_SPEED_m_s,

    CASE
        WHEN ac.COND_ID IS NULL
            THEN 'NO ATMOSPHERIC RECORD'
        ELSE 'ATMOSPHERIC RECORD EXISTS'
    END AS ATMOSPHERIC_STATUS

FROM lightning_events le

JOIN observation_stations os
    ON le.STATION_ID = os.STATION_ID

LEFT JOIN atmospheric_conds ac
    ON le.EVENT_ID = ac.EVENT_ID

ORDER BY
    le.EVENT_ID;
    


-- ============================================================
-- QUERY 11: ATMOSPHERIC DATA COMPLETENESS
--
-- Purpose:
-- 1. Count atmospheric records for each event.
-- 2. Identify missing temperature, pressure, humidity and wind.
-- 3. Summarize completeness across all events.
-- ============================================================

SELECT
    COUNT(*) AS TOTAL_ATMOSPHERIC_RECORDS,

    SUM(TEMP_C IS NOT NULL) AS TEMPERATURE_AVAILABLE,
    SUM(TEMP_C IS NULL) AS TEMPERATURE_MISSING,

    SUM(PRESSURE_hPa IS NOT NULL) AS PRESSURE_AVAILABLE,
    SUM(PRESSURE_hPa IS NULL) AS PRESSURE_MISSING,

    SUM(HUMIDITY_PERCENT IS NOT NULL) AS HUMIDITY_AVAILABLE,
    SUM(HUMIDITY_PERCENT IS NULL) AS HUMIDITY_MISSING,

    SUM(WIND_SPEED_m_s IS NOT NULL) AS WIND_AVAILABLE,
    SUM(WIND_SPEED_m_s IS NULL) AS WIND_MISSING

FROM atmospheric_conds;




-- ============================================================
-- QUERY 12: OVERALL DATA COVERAGE BY STATION
--
-- Purpose:
-- 1. Count recorded lightning events at each station.
-- 2. Count IC, CG and CC events.
-- 3. Count associated channel records.
-- 4. Count available EF/MF measurement records.
-- ============================================================

SELECT
    os.STATION_NAME,

    COUNT(DISTINCT le.EVENT_ID) AS TOTAL_EVENTS,

    COUNT(DISTINCT CASE
        WHEN le.LIGHTNING_TYPE = 'IC' THEN le.EVENT_ID
    END) AS IC_EVENTS,

    COUNT(DISTINCT CASE
        WHEN le.LIGHTNING_TYPE = 'CG' THEN le.EVENT_ID
    END) AS CG_EVENTS,

    COUNT(DISTINCT CASE
        WHEN le.LIGHTNING_TYPE = 'CC' THEN le.EVENT_ID
    END) AS CC_EVENTS,

    COUNT(DISTINCT lc.CHANNEL_ID) AS CHANNEL_RECORDS,

    COUNT(DISTINCT lm.MEASUREMENT_ID) AS MEASUREMENT_RECORDS

FROM observation_stations os

LEFT JOIN lightning_events le
    ON os.STATION_ID = le.STATION_ID

LEFT JOIN lightning_channels lc
    ON le.EVENT_ID = lc.EVENT_ID

LEFT JOIN lightning_measurements lm
    ON le.EVENT_ID = lm.EVENT_ID

GROUP BY
    os.STATION_ID,
    os.STATION_NAME

ORDER BY
    os.STATION_NAME;




-- ============================================================
-- QUERY 13: VERIFY MEASUREMENT RECORD COUNTS
--
-- Purpose:
-- 1. Count all measurement rows for Event 103.
-- 2. Count distinct measurement IDs.
-- 3. Count missing measurement IDs.
-- 4. Check the time range of the records.
-- ============================================================

SELECT
    EVENT_ID,

    COUNT(*) AS TOTAL_ROWS,

    COUNT(DISTINCT MEASUREMENT_ID) AS DISTINCT_MEASUREMENT_IDS,

    SUM(MEASUREMENT_ID IS NULL) AS NULL_MEASUREMENT_IDS,

    MIN(MEASUREMENT_ID) AS MIN_MEASUREMENT_ID,
    MAX(MEASUREMENT_ID) AS MAX_MEASUREMENT_ID,

    MIN(TIME_us) AS START_TIME_us,
    MAX(TIME_us) AS END_TIME_us

FROM lightning_measurements
WHERE EVENT_ID = 103
GROUP BY EVENT_ID;



-- ============================================================
-- QUERY 14: CURRENT MEASUREMENT COVERAGE BY EVENT
--
-- Purpose:
-- 1. Find events that currently have measurement records.
-- 2. Count rows and distinct measurement IDs.
-- 3. Check the available time range for each event.
-- ============================================================

SELECT
    EVENT_ID,
    COUNT(*) AS TOTAL_ROWS,
    COUNT(DISTINCT MEASUREMENT_ID) AS DISTINCT_MEASUREMENT_IDS,
    MIN(TIME_us) AS START_TIME_us,
    MAX(TIME_us) AS END_TIME_us
FROM lightning_measurements
GROUP BY EVENT_ID
ORDER BY EVENT_ID;




-- ============================================================
-- QUERY 15: CHECK DUPLICATE TIMESTAMPS
--
-- Purpose:
-- 1. Group measurements by event and timestamp.
-- 2. Identify timestamps appearing more than once.
-- 3. Count how many records share each repeated timestamp.
--
-- Note:
-- Repeated timestamps are not automatically errors.
-- They may represent multiple measurements at the same time.
-- ============================================================

SELECT
    EVENT_ID,
    TIME_us,
    COUNT(*) AS RECORDS_AT_TIMESTAMP
FROM lightning_measurements
GROUP BY
    EVENT_ID,
    TIME_us
HAVING COUNT(*) > 1
ORDER BY
    EVENT_ID,
    TIME_us
LIMIT 50;


-- ============================================================
-- QUERY 16: INSPECT REPEATED-TIMESTAMP RECORDS
--
-- Purpose:
-- 1. Find timestamps that occur more than once.
-- 2. Display the associated measurement IDs and field values.
-- 3. Inspect the first 20 matching records.
-- ============================================================

SELECT
    MEASUREMENT_ID,
    EVENT_ID,
    TIME_us,
    E_FIELD_V_m,
    H_FIELD_A_m
FROM lightning_measurements
WHERE EVENT_ID = 103
  AND TIME_us IN (
      SELECT TIME_us
      FROM (
          SELECT TIME_us
          FROM lightning_measurements
          WHERE EVENT_ID = 103
          GROUP BY TIME_us
          HAVING COUNT(*) > 1
          ORDER BY TIME_us
          LIMIT 10
      ) AS duplicate_times
  )
ORDER BY
    TIME_us,
    MEASUREMENT_ID
LIMIT 20;




-- ============================================================
-- QUERY 17: VERIFY EVENT 103 MEASUREMENT RECORDS
--
-- Purpose:
-- 1. Count the current measurement records.
-- 2. Check the available time range.
-- 3. Confirm whether EF and MF values are present.
-- ============================================================

SELECT
    COUNT(*) AS TOTAL_RECORDS,
    MIN(TIME_us) AS FIRST_TIME_us,
    MAX(TIME_us) AS LAST_TIME_us,
    COUNT(E_FIELD_V_m) AS VALID_E_FIELD_RECORDS,
    COUNT(H_FIELD_A_m) AS VALID_H_FIELD_RECORDS
FROM lightning_measurements
WHERE EVENT_ID = 103;




-- ============================================================
-- QUERY 18: CHECK WHETHER REPEATED-TIMESTAMP VALUES MATCH
--
-- Purpose:
-- 1. Group records by timestamp for Event 103.
-- 2. Count timestamps with exactly two records.
-- 3. Check whether the EF and MF values are identical
--    within each repeated timestamp.
-- 4. Summarize matching and differing pairs.
--
-- No data are modified or deleted.
-- ============================================================

SELECT
    COUNT(*) AS REPEATED_TIMESTAMPS,

    SUM(RECORD_COUNT = 2) AS TIMESTAMPS_WITH_TWO_RECORDS,

    SUM(
        RECORD_COUNT = 2
        AND DISTINCT_FIELD_PAIRS = 1
    ) AS PAIRS_WITH_IDENTICAL_FIELDS,

    SUM(
        RECORD_COUNT = 2
        AND DISTINCT_FIELD_PAIRS > 1
    ) AS PAIRS_WITH_DIFFERENT_FIELDS

FROM (
    SELECT
        TIME_us,
        COUNT(*) AS RECORD_COUNT,
        COUNT(DISTINCT CONCAT(
            COALESCE(CAST(E_FIELD_V_m AS CHAR), 'NULL'),
            '|',
            COALESCE(CAST(H_FIELD_A_m AS CHAR), 'NULL')
        )) AS DISTINCT_FIELD_PAIRS

    FROM lightning_measurements
    WHERE EVENT_ID = 103
    GROUP BY TIME_us
    HAVING COUNT(*) > 1
) AS timestamp_groups;



-- ============================================================
-- QUERY 19: INSPECT REPEATED MEASUREMENTS
--
-- Purpose:
-- Display timestamps where two records have different EF/MF
-- values, so we can determine whether the repeated records
-- represent separate data streams or a data-import issue.
--
-- Only reads data; nothing is modified.
-- ============================================================

SELECT
    TIME_us,
    COUNT(*) AS RECORD_COUNT,
    MIN(E_FIELD_V_m) AS MIN_E_FIELD,
    MAX(E_FIELD_V_m) AS MAX_E_FIELD,
    MIN(H_FIELD_A_m) AS MIN_H_FIELD,
    MAX(H_FIELD_A_m) AS MAX_H_FIELD
FROM lightning_measurements
WHERE EVENT_ID = 103
GROUP BY TIME_us
HAVING COUNT(*) = 2
   AND (
       MIN(E_FIELD_V_m) <> MAX(E_FIELD_V_m)
       OR MIN(H_FIELD_A_m) <> MAX(H_FIELD_A_m)
       OR MIN(E_FIELD_V_m) IS NULL
       OR MAX(E_FIELD_V_m) IS NULL
       OR MIN(H_FIELD_A_m) IS NULL
       OR MAX(H_FIELD_A_m) IS NULL
   )
ORDER BY TIME_us
LIMIT 20;



-- ============================================================
-- QUERY 20: VIEW BOTH RECORDS AT REPEATED TIMESTAMPS
--
-- Purpose:
-- Inspect the original rows to identify how the duplicate
-- timestamp records differ.
--
-- No data are modified or deleted.
-- ============================================================

SELECT
    MEASUREMENT_ID,
    EVENT_ID,
    TIME_us,
    E_FIELD_V_m,
    H_FIELD_A_m
FROM lightning_measurements
WHERE EVENT_ID = 103
  AND TIME_us IN (
      SELECT TIME_us
      FROM (
          SELECT TIME_us
          FROM lightning_measurements
          WHERE EVENT_ID = 103
          GROUP BY TIME_us
          HAVING COUNT(*) = 2
             AND (
                 MIN(E_FIELD_V_m) <> MAX(E_FIELD_V_m)
                 OR MIN(H_FIELD_A_m) <> MAX(H_FIELD_A_m)
             )
          ORDER BY TIME_us
          LIMIT 10
      ) AS differing_times
  )
ORDER BY TIME_us, MEASUREMENT_ID;



-- ============================================================
-- QUERY 21: CHECK THE TWO INTERLEAVED MEASUREMENT SERIES
--
-- Purpose:
-- Determine whether one measurement-ID series contains
-- only zero-valued EF/MF records.
--
-- No data are modified or deleted.
-- ============================================================

SELECT
    CASE
        WHEN MEASUREMENT_ID BETWEEN 2800000 AND 2925000
            THEN 'Series 1: lower measurement IDs'
        ELSE 'Series 2: higher measurement IDs'
    END AS MEASUREMENT_SERIES,

    COUNT(*) AS TOTAL_RECORDS,

    SUM(
        COALESCE(E_FIELD_V_m, 0) = 0
        AND COALESCE(H_FIELD_A_m, 0) = 0
    ) AS BOTH_FIELDS_ZERO,

    SUM(
        COALESCE(E_FIELD_V_m, 0) <> 0
        OR COALESCE(H_FIELD_A_m, 0) <> 0
    ) AS AT_LEAST_ONE_FIELD_NONZERO,

    MIN(TIME_us) AS FIRST_TIME_us,
    MAX(TIME_us) AS LAST_TIME_us

FROM lightning_measurements
WHERE EVENT_ID = 103
GROUP BY
    CASE
        WHEN MEASUREMENT_ID BETWEEN 2800000 AND 2925000
            THEN 'Series 1: lower measurement IDs'
        ELSE 'Series 2: higher measurement IDs'
    END;
    


-- ============================================================
-- QUERY 22: COMPARE TIMESTAMP COVERAGE BETWEEN ID GROUPS
--
-- Purpose:
-- Count timestamps present in both measurement-ID groups,
-- and timestamps present in only one group.
--
-- No data are modified.
-- ============================================================

SELECT
    COUNT(*) AS TOTAL_UNIQUE_TIMESTAMPS,

    SUM(SERIES_1_COUNT > 0 AND SERIES_2_COUNT > 0)
        AS TIMESTAMPS_IN_BOTH_SERIES,

    SUM(SERIES_1_COUNT > 0 AND SERIES_2_COUNT = 0)
        AS TIMESTAMPS_ONLY_IN_SERIES_1,

    SUM(SERIES_1_COUNT = 0 AND SERIES_2_COUNT > 0)
        AS TIMESTAMPS_ONLY_IN_SERIES_2

FROM (
    SELECT
        TIME_us,

        SUM(
            MEASUREMENT_ID BETWEEN 2800000 AND 2925000
        ) AS SERIES_1_COUNT,

        SUM(
            MEASUREMENT_ID NOT BETWEEN 2800000 AND 2925000
        ) AS SERIES_2_COUNT

    FROM lightning_measurements
    WHERE EVENT_ID = 103
    GROUP BY TIME_us
) AS timestamp_comparison;



-- ============================================================
-- QUERY 23: FIND TIMESTAMPS PRESENT ONLY IN SERIES 2
--
-- Purpose:
-- List the timestamps that do not have a corresponding
-- record in Series 1, using the provisional ID boundary.
--
-- No data are modified.
-- ============================================================

SELECT
    TIME_us,
    COUNT(*) AS RECORDS_AT_TIMESTAMP,
    MIN(MEASUREMENT_ID) AS MIN_MEASUREMENT_ID,
    MAX(MEASUREMENT_ID) AS MAX_MEASUREMENT_ID,
    MIN(E_FIELD_V_m) AS MIN_E_FIELD,
    MAX(E_FIELD_V_m) AS MAX_E_FIELD,
    MIN(H_FIELD_A_m) AS MIN_H_FIELD,
    MAX(H_FIELD_A_m) AS MAX_H_FIELD

FROM lightning_measurements
WHERE EVENT_ID = 103
  AND MEASUREMENT_ID NOT BETWEEN 2800000 AND 2925000
  AND TIME_us NOT IN (
      SELECT TIME_us
      FROM lightning_measurements
      WHERE EVENT_ID = 103
        AND MEASUREMENT_ID BETWEEN 2800000 AND 2925000
  )
GROUP BY TIME_us
ORDER BY TIME_us;



-- ============================================================
-- QUERY 24: INSPECT MEASUREMENT-ID RANGES FOR EVENT 103
--
-- Purpose:
-- Summarize the complete ID ranges, record counts, and
-- time coverage to identify the separate imported sequences.
--
-- No data are modified.
-- ============================================================

SELECT
    MIN(MEASUREMENT_ID) AS FIRST_MEASUREMENT_ID,
    MAX(MEASUREMENT_ID) AS LAST_MEASUREMENT_ID,
    COUNT(*) AS TOTAL_RECORDS,
    COUNT(DISTINCT TIME_us) AS UNIQUE_TIMESTAMPS,
    MIN(TIME_us) AS FIRST_TIME_us,
    MAX(TIME_us) AS LAST_TIME_us,
    SUM(E_FIELD_V_m = 0 AND H_FIELD_A_m = 0)
        AS BOTH_FIELDS_ZERO,
    SUM(E_FIELD_V_m <> 0 OR H_FIELD_A_m <> 0)
        AS AT_LEAST_ONE_FIELD_NONZERO
FROM lightning_measurements
WHERE EVENT_ID = 103;



-- ============================================================
-- QUERY 25: CHECK ID SEPARATION FOR REPEATED TIMESTAMPS
--
-- Purpose:
-- Calculate the difference between the two measurement IDs
-- at each timestamp to test whether the records form
-- consistently separated sequences.
--
-- No data are modified.
-- ============================================================

SELECT
    COUNT(*) AS TIMESTAMPS_WITH_TWO_RECORDS,
    MIN(ID_DIFFERENCE) AS MIN_ID_DIFFERENCE,
    MAX(ID_DIFFERENCE) AS MAX_ID_DIFFERENCE,
    AVG(ID_DIFFERENCE) AS AVG_ID_DIFFERENCE
FROM (
    SELECT
        TIME_us,
        MAX(MEASUREMENT_ID) - MIN(MEASUREMENT_ID)
            AS ID_DIFFERENCE
    FROM lightning_measurements
    WHERE EVENT_ID = 103
    GROUP BY TIME_us
    HAVING COUNT(*) = 2
) AS paired_records;



-- ============================================================
-- QUERY 26: COMPARE PAIRED EF/MF VALUES
--
-- Purpose:
-- Show the two records at selected timestamps, side by side,
-- using the verified measurement-ID offset of 125001.
--
-- No data are modified.
-- ============================================================

SELECT
    a.TIME_us,

    a.MEASUREMENT_ID AS ID_SERIES_1,
    a.E_FIELD_V_m AS EF_SERIES_1,
    a.H_FIELD_A_m AS MF_SERIES_1,

    b.MEASUREMENT_ID AS ID_SERIES_2,
    b.E_FIELD_V_m AS EF_SERIES_2,
    b.H_FIELD_A_m AS MF_SERIES_2

FROM lightning_measurements AS a
JOIN lightning_measurements AS b
    ON a.EVENT_ID = b.EVENT_ID
   AND a.TIME_us = b.TIME_us
   AND b.MEASUREMENT_ID = a.MEASUREMENT_ID + 125001

WHERE a.EVENT_ID = 103
  AND a.MEASUREMENT_ID BETWEEN 2800013 AND 2925013
  AND MOD(a.MEASUREMENT_ID - 2800013, 12500) = 0

ORDER BY a.TIME_us
LIMIT 20;



-- ============================================================
-- QUERY 27: SUMMARIZE BOTH MEASUREMENT SEQUENCES
--
-- Purpose:
-- Compare the field ranges and time coverage of the two
-- sequences associated with Event 103.
--
-- The sequence split is based on the verified ID offset.
-- No data are modified.
-- ============================================================

SELECT
    CASE
        WHEN MEASUREMENT_ID <= 2925013
            THEN 'Series 1'
        ELSE 'Series 2'
    END AS SERIES,

    COUNT(*) AS TOTAL_RECORDS,
    MIN(TIME_us) AS FIRST_TIME_us,
    MAX(TIME_us) AS LAST_TIME_us,

    MIN(E_FIELD_V_m) AS MIN_E_FIELD_V_m,
    MAX(E_FIELD_V_m) AS MAX_E_FIELD_V_m,

    MIN(H_FIELD_A_m) AS MIN_H_FIELD_A_m,
    MAX(H_FIELD_A_m) AS MAX_H_FIELD_A_m,

    SUM(E_FIELD_V_m = 0 AND H_FIELD_A_m = 0)
        AS BOTH_FIELDS_ZERO

FROM lightning_measurements
WHERE EVENT_ID = 103
GROUP BY
    CASE
        WHEN MEASUREMENT_ID <= 2925013
            THEN 'Series 1'
        ELSE 'Series 2'
    END
ORDER BY SERIES;



-- ============================================================
-- QUERY 28: CALCULATE PEARSON CORRELATION MANUALLY
--
-- Purpose:
-- Compare the waveform shapes of the two measurement
-- sequences without relying on the unsupported CORR() function.
--
-- Pearson correlation ranges from -1 to +1:
--  +1 = perfect positive linear correlation
--   0 = no linear correlation
--  -1 = perfect negative linear correlation
--
-- No data are modified.
-- ============================================================

SELECT
    COUNT(*) AS MATCHED_SAMPLES,

    (
        AVG(a.E_FIELD_V_m * b.E_FIELD_V_m)
        - AVG(a.E_FIELD_V_m) * AVG(b.E_FIELD_V_m)
    ) /
    NULLIF(
        SQRT(
            (
                AVG(a.E_FIELD_V_m * a.E_FIELD_V_m)
                - POW(AVG(a.E_FIELD_V_m), 2)
            )
            *
            (
                AVG(b.E_FIELD_V_m * b.E_FIELD_V_m)
                - POW(AVG(b.E_FIELD_V_m), 2)
            )
        ),
        0
    ) AS EF_CORRELATION,

    (
        AVG(a.H_FIELD_A_m * b.H_FIELD_A_m)
        - AVG(a.H_FIELD_A_m) * AVG(b.H_FIELD_A_m)
    ) /
    NULLIF(
        SQRT(
            (
                AVG(a.H_FIELD_A_m * a.H_FIELD_A_m)
                - POW(AVG(a.H_FIELD_A_m), 2)
            )
            *
            (
                AVG(b.H_FIELD_A_m * b.H_FIELD_A_m)
                - POW(AVG(b.H_FIELD_A_m), 2)
            )
        ),
        0
    ) AS MF_CORRELATION

FROM lightning_measurements AS a

JOIN lightning_measurements AS b
    ON b.EVENT_ID = a.EVENT_ID
   AND b.TIME_us = a.TIME_us
   AND b.MEASUREMENT_ID = a.MEASUREMENT_ID + 125001

WHERE a.EVENT_ID = 103
  AND a.MEASUREMENT_ID BETWEEN 2800013 AND 2925013;
  
  
  
-- ============================================================
-- QUERY 29: COMPARE EF/MF AMPLITUDES BETWEEN SEQUENCES
--
-- Purpose:
-- Calculate average absolute differences and ratios between
-- the two sequences at matching timestamps.
--
-- Ratios are calculated only when the Series 1 field is nonzero.
-- No data are modified.
-- ============================================================

SELECT
    COUNT(*) AS MATCHED_SAMPLES,

    AVG(ABS(a.E_FIELD_V_m - b.E_FIELD_V_m))
        AS MEAN_ABS_EF_DIFFERENCE_V_m,

    AVG(ABS(a.H_FIELD_A_m - b.H_FIELD_A_m))
        AS MEAN_ABS_MF_DIFFERENCE_A_m,

    AVG(
        CASE
            WHEN a.E_FIELD_V_m <> 0
            THEN b.E_FIELD_V_m / a.E_FIELD_V_m
        END
    ) AS MEAN_EF_RATIO,

    AVG(
        CASE
            WHEN a.H_FIELD_A_m <> 0
            THEN b.H_FIELD_A_m / a.H_FIELD_A_m
        END
    ) AS MEAN_MF_RATIO

FROM lightning_measurements AS a

JOIN lightning_measurements AS b
    ON b.EVENT_ID = a.EVENT_ID
   AND b.TIME_us = a.TIME_us
   AND b.MEASUREMENT_ID = a.MEASUREMENT_ID + 125001

WHERE a.EVENT_ID = 103
  AND a.MEASUREMENT_ID BETWEEN 2800013 AND 2925013;
  
  

-- ============================================================
-- QUERY 30: INSPECT MEASUREMENT-ID ORDER
--
-- Purpose:
-- Examine the beginning and end of Event 103's stored rows
-- to understand how the two sequences were inserted.
--
-- No data are modified.
-- ============================================================

(
    SELECT
        'FIRST 10 IDS' AS SECTION,
        MEASUREMENT_ID,
        TIME_us,
        E_FIELD_V_m,
        H_FIELD_A_m
    FROM lightning_measurements
    WHERE EVENT_ID = 103
    ORDER BY MEASUREMENT_ID
    LIMIT 10
)

UNION ALL

(
    SELECT
        'LAST 10 IDS' AS SECTION,
        MEASUREMENT_ID,
        TIME_us,
        E_FIELD_V_m,
        H_FIELD_A_m
    FROM lightning_measurements
    WHERE EVENT_ID = 103
    ORDER BY MEASUREMENT_ID DESC
    LIMIT 10
)

ORDER BY SECTION, MEASUREMENT_ID;



-- ============================================================
-- QUERY 31: FIND THE FIRST NONZERO SAMPLE IN SERIES 1
--
-- Purpose:
-- Identify when the lower-ID measurement sequence first
-- contains a nonzero EF or MF value.
--
-- No data are modified.
-- ============================================================

SELECT
    MEASUREMENT_ID,
    TIME_us,
    E_FIELD_V_m,
    H_FIELD_A_m
FROM lightning_measurements
WHERE EVENT_ID = 103
  AND MEASUREMENT_ID BETWEEN 2800013 AND 2925013
  AND (
      E_FIELD_V_m <> 0
      OR H_FIELD_A_m <> 0
  )
ORDER BY MEASUREMENT_ID
LIMIT 1;



-- ============================================================
-- QUERY 32: FIND THE FIRST NONZERO SAMPLE IN SERIES 2
--
-- Purpose:
-- Identify the earliest nonzero EF or MF value in the
-- higher-ID measurement sequence.
--
-- No data are modified.
-- ============================================================

SELECT
    MEASUREMENT_ID,
    TIME_us,
    E_FIELD_V_m,
    H_FIELD_A_m
FROM lightning_measurements
WHERE EVENT_ID = 103
  AND MEASUREMENT_ID BETWEEN 2925014 AND 3050014
  AND (
      E_FIELD_V_m <> 0
      OR H_FIELD_A_m <> 0
  )
ORDER BY MEASUREMENT_ID
LIMIT 1;



-- ============================================================
-- QUERY 33: COUNT INITIAL ZERO-VALUED SAMPLES
--
-- Purpose:
-- Quantify how many consecutive samples at the beginning
-- of each sequence have both EF and MF equal to zero.
--
-- No data are modified.
-- ============================================================

SELECT
    'Series 1' AS SERIES,
    COUNT(*) AS INITIAL_ZERO_SAMPLES
FROM lightning_measurements
WHERE EVENT_ID = 103
  AND MEASUREMENT_ID BETWEEN 2800013 AND 2925013
  AND MEASUREMENT_ID < 2806890
  AND E_FIELD_V_m = 0
  AND H_FIELD_A_m = 0

UNION ALL

SELECT
    'Series 2' AS SERIES,
    COUNT(*) AS INITIAL_ZERO_SAMPLES
FROM lightning_measurements
WHERE EVENT_ID = 103
  AND MEASUREMENT_ID BETWEEN 2925014 AND 3050014
  AND MEASUREMENT_ID < 2927373
  AND E_FIELD_V_m = 0
  AND H_FIELD_A_m = 0;
  
  
  
-- ============================================================
-- QUERY 34: COUNT ZERO-VALUED SAMPLES AFTER ONSET
--
-- Purpose:
-- Count samples where both EF and MF are zero after the
-- first nonzero sample in each sequence.
--
-- No data are modified.
-- ============================================================

SELECT
    'Series 1' AS SERIES,
    COUNT(*) AS ZERO_SAMPLES_AFTER_ONSET
FROM lightning_measurements
WHERE EVENT_ID = 103
  AND MEASUREMENT_ID BETWEEN 2806890 AND 2925013
  AND E_FIELD_V_m = 0
  AND H_FIELD_A_m = 0

UNION ALL

SELECT
    'Series 2' AS SERIES,
    COUNT(*) AS ZERO_SAMPLES_AFTER_ONSET
FROM lightning_measurements
WHERE EVENT_ID = 103
  AND MEASUREMENT_ID BETWEEN 2927373 AND 3050014
  AND E_FIELD_V_m = 0
  AND H_FIELD_A_m = 0;
  
  
  
-- ============================================================
-- QUERY 35: VERIFY EACH SEQUENCE'S ONSET TRANSITION
--
-- Purpose:
-- Show the last zero-valued sample and first nonzero sample
-- for both sequences.
--
-- No data are modified.
-- ============================================================

SELECT
    'Series 1: last zero' AS CHECK_POINT,
    MEASUREMENT_ID,
    TIME_us,
    E_FIELD_V_m,
    H_FIELD_A_m
FROM lightning_measurements
WHERE EVENT_ID = 103
  AND MEASUREMENT_ID = 2806889

UNION ALL

SELECT
    'Series 1: first nonzero',
    MEASUREMENT_ID,
    TIME_us,
    E_FIELD_V_m,
    H_FIELD_A_m
FROM lightning_measurements
WHERE EVENT_ID = 103
  AND MEASUREMENT_ID = 2806890

UNION ALL

SELECT
    'Series 2: last zero',
    MEASUREMENT_ID,
    TIME_us,
    E_FIELD_V_m,
    H_FIELD_A_m
FROM lightning_measurements
WHERE EVENT_ID = 103
  AND MEASUREMENT_ID = 2927372

UNION ALL

SELECT
    'Series 2: first nonzero',
    MEASUREMENT_ID,
    TIME_us,
    E_FIELD_V_m,
    H_FIELD_A_m
FROM lightning_measurements
WHERE EVENT_ID = 103
  AND MEASUREMENT_ID = 2927373

ORDER BY MEASUREMENT_ID;



-- ============================================================
-- QUERY 36: VERIFY SERIES 1 TRANSITION IDS
--
-- Purpose:
-- Check whether the two measurement IDs surrounding
-- Series 1's reported onset exist in the table.
--
-- No data are modified.
-- ============================================================

SELECT
    MEASUREMENT_ID,
    EVENT_ID,
    TIME_us,
    E_FIELD_V_m,
    H_FIELD_A_m
FROM lightning_measurements
WHERE EVENT_ID = 103
  AND MEASUREMENT_ID IN (2806889, 2806890)
ORDER BY MEASUREMENT_ID;



-- ============================================================
-- QUERY 37: VERIFY TIMESTAMP ALIGNMENT BETWEEN BOTH SERIES
--
-- Purpose:
-- Compare corresponding timestamps in the two sequences.
-- The expected ID offset is 125001.
--
-- No data are modified.
-- ============================================================

SELECT
    COUNT(*) AS MATCHED_TIMESTAMP_COUNT,

    SUM(
        CASE
            WHEN s2.TIME_us IS NULL THEN 1
            ELSE 0
        END
    ) AS MISSING_SERIES_2_TIMESTAMPS,

    SUM(
        CASE
            WHEN s2.MEASUREMENT_ID - s1.MEASUREMENT_ID <> 125001
            THEN 1
            ELSE 0
        END
    ) AS ID_OFFSET_MISMATCHES

FROM lightning_measurements AS s1

LEFT JOIN lightning_measurements AS s2
    ON s2.EVENT_ID = s1.EVENT_ID
    AND s2.TIME_us = s1.TIME_us
    AND s2.MEASUREMENT_ID = s1.MEASUREMENT_ID + 125001

WHERE s1.EVENT_ID = 103
  AND s1.MEASUREMENT_ID BETWEEN 2800013 AND 2925013;
  
  

-- ============================================================
-- QUERY 38: COMPARE BOTH SERIES AT SELECTED TIMESTAMPS
--
-- Purpose:
-- Display corresponding EF and MF values at regular
-- intervals, along with their absolute differences.
--
-- No data are modified.
-- ============================================================

SELECT
    s1.TIME_us,

    s1.E_FIELD_V_m AS EF_SERIES_1,
    s2.E_FIELD_V_m AS EF_SERIES_2,
    ABS(s2.E_FIELD_V_m - s1.E_FIELD_V_m) AS EF_ABS_DIFFERENCE,

    s1.H_FIELD_A_m AS MF_SERIES_1,
    s2.H_FIELD_A_m AS MF_SERIES_2,
    ABS(s2.H_FIELD_A_m - s1.H_FIELD_A_m) AS MF_ABS_DIFFERENCE

FROM lightning_measurements AS s1

JOIN lightning_measurements AS s2
    ON s2.EVENT_ID = s1.EVENT_ID
    AND s2.TIME_us = s1.TIME_us
    AND s2.MEASUREMENT_ID = s1.MEASUREMENT_ID + 125001

WHERE s1.EVENT_ID = 103
  AND s1.MEASUREMENT_ID BETWEEN 2800013 AND 2925013
  AND MOD(ROUND(s1.TIME_us * 1000), 10000) = 0

ORDER BY s1.TIME_us;



-- ============================================================
-- QUERY 39: INSPECT LIGHTNING MEASUREMENT TABLE COLUMNS
--
-- Purpose:
-- Identify available columns that may distinguish the
-- two aligned waveform sequences.
--
-- No data are modified.
-- ============================================================

DESCRIBE lightning_measurements;




-- ============================================================
-- QUERY 40: CHECK ALTITUDES FOR BOTH MEASUREMENT SERIES
--
-- Purpose:
-- Determine whether Series 1 and Series 2 represent
-- measurements at different observation altitudes.
--
-- No data are modified.
-- ============================================================

SELECT
    CASE
        WHEN MEASUREMENT_ID BETWEEN 2800013 AND 2925013
            THEN 'Series 1'
        WHEN MEASUREMENT_ID BETWEEN 2925014 AND 3050014
            THEN 'Series 2'
    END AS SERIES,

    COUNT(*) AS RECORD_COUNT,
    COUNT(DISTINCT OBSERVATION_ALTITUDE_km) AS DISTINCT_ALTITUDES,
    MIN(OBSERVATION_ALTITUDE_km) AS MIN_ALTITUDE_km,
    MAX(OBSERVATION_ALTITUDE_km) AS MAX_ALTITUDE_km

FROM lightning_measurements

WHERE EVENT_ID = 103
  AND MEASUREMENT_ID BETWEEN 2800013 AND 3050014

GROUP BY SERIES
ORDER BY SERIES;



-- ============================================================
-- QUERY 41: SUMMARIZE MEASUREMENT COVERAGE BY EVENT AND ALTITUDE
--
-- Purpose:
-- Count records and identify observation altitudes for
-- every event in the measurement table.
--
-- No data are modified.
-- ============================================================

SELECT
    EVENT_ID,
    OBSERVATION_ALTITUDE_km,
    COUNT(*) AS RECORD_COUNT,
    MIN(TIME_us) AS START_TIME_us,
    MAX(TIME_us) AS END_TIME_us,
    COUNT(DISTINCT TIME_us) AS UNIQUE_TIMESTAMPS

FROM lightning_measurements

GROUP BY EVENT_ID, OBSERVATION_ALTITUDE_km

ORDER BY EVENT_ID, OBSERVATION_ALTITUDE_km;



-- ============================================================
-- QUERY 42: COUNT MEASUREMENT RECORDS FOR EACH EVENT
--
-- Purpose:
-- List every event represented in the measurement table
-- and count its total records.
--
-- No data are modified.
-- ============================================================

SELECT
    EVENT_ID,
    COUNT(*) AS TOTAL_RECORDS,
    COUNT(DISTINCT OBSERVATION_ALTITUDE_km) AS ALTITUDE_COUNT,
    MIN(OBSERVATION_ALTITUDE_km) AS MIN_ALTITUDE_km,
    MAX(OBSERVATION_ALTITUDE_km) AS MAX_ALTITUDE_km

FROM lightning_measurements

GROUP BY EVENT_ID

ORDER BY EVENT_ID;



-- ============================================================
-- QUERY 43: RETRIEVE EVENT 103 AND ITS STATION DETAILS
--
-- Purpose:
-- Identify the event type, date/time, station, and
-- associated event-level parameters.
--
-- No data are modified.
-- ============================================================

SELECT
    e.EVENT_ID,
    e.EVENT_DATE_TIME,
    e.LIGHTNING_TYPE,
    e.PEAK_CURRENT_kA,
    e.DURATION_us,
    s.STATION_ID,
    s.STATION_NAME,
    s.LATITUDE,
    s.LONGITUDE,
    s.ALTITUDE_m,
    s.COUNTRY

FROM lightning_events AS e

JOIN observation_stations AS s
    ON s.STATION_ID = e.STATION_ID

WHERE e.EVENT_ID = 103;



-- ============================================================
-- QUERY 44: CHECK CHANNEL METADATA FOR EVENT 103
--
-- Purpose:
-- Compare the event-level metadata with the associated
-- channel lengths, propagation velocities, and peak currents.
--
-- No data are modified.
-- ============================================================

SELECT
    CHANNEL_ID,
    EVENT_ID,
    CHANNEL_TYPE,
    CHANNEL_LENGTH_m,
    PROPAGATION_VELOCITY_m_s,
    PEAK_CURRENT_kA

FROM lightning_channels

WHERE EVENT_ID = 103

ORDER BY CHANNEL_ID;



-- ============================================================
-- QUERY 45: SUMMARIZE CHANNEL GEOMETRY FOR EVENT 103
--
-- Purpose:
-- Verify how many channel points and segments are stored
-- for the event's tortuous channel.
--
-- No data are modified.
-- ============================================================

SELECT
    c.CHANNEL_ID,
    c.CHANNEL_TYPE,
    COUNT(p.CHANNEL_POINT_ID) AS TOTAL_POINTS,
    MIN(p.POINT_INDEX) AS FIRST_POINT_INDEX,
    MAX(p.POINT_INDEX) AS LAST_POINT_INDEX,
    SUM(p.SEGMENT_LENGTH_m) AS SUM_SEGMENT_LENGTH_m

FROM lightning_channels AS c

LEFT JOIN channel_points AS p
    ON p.CHANNEL_ID = c.CHANNEL_ID

WHERE c.EVENT_ID = 103

GROUP BY
    c.CHANNEL_ID,
    c.CHANNEL_TYPE

ORDER BY c.CHANNEL_ID;



-- ============================================================
-- QUERY 47: CHECK RECORD COUNTS IN ALL SIX TABLES
--
-- Purpose:
-- Get an overview of the data available for analysis.
-- No data are modified.
-- ============================================================

SELECT 'observation_stations' AS TABLE_NAME, COUNT(*) AS TOTAL_RECORDS
FROM observation_stations

UNION ALL

SELECT 'lightning_events', COUNT(*)
FROM lightning_events

UNION ALL

SELECT 'lightning_channels', COUNT(*)
FROM lightning_channels

UNION ALL

SELECT 'channel_points', COUNT(*)
FROM channel_points

UNION ALL

SELECT 'atmospheric_conds', COUNT(*)
FROM atmospheric_conds

UNION ALL

SELECT 'lightning_measurements', COUNT(*)
FROM lightning_measurements;



-- ============================================================
-- QUERY 48: LIGHTNING EVENT TYPE DISTRIBUTION
--
-- Objective:
-- Analyze the distribution of Intracloud (IC), Cloud-to-Ground
-- (CG), and Cloud-to-Cloud (CC) lightning events recorded
-- in the database.
--
-- Operations:
-- 1. Count the events belonging to each lightning type.
-- 2. Calculate each type's percentage of all recorded events.
-- 3. Arrange the results from the most frequent type to
--    the least frequent type.
--
-- Purpose:
-- Understand the composition of the lightning event dataset
-- and identify which lightning types are most represented.
--
-- Note:
-- Percentages describe the records in this database only;
-- they do not represent the global frequency of lightning.
-- ============================================================

SELECT
    LIGHTNING_TYPE,
    COUNT(*) AS TOTAL_EVENTS,
    ROUND(
        100.0 * COUNT(*) /
        (SELECT COUNT(*) FROM lightning_events),
        2
    ) AS PERCENTAGE
FROM lightning_events
GROUP BY LIGHTNING_TYPE
ORDER BY TOTAL_EVENTS DESC;



-- ============================================================
-- QUERY 49: CHANNEL LENGTH ANALYSIS BY CHANNEL TYPE
--
-- Objective:
-- Examine how channel lengths vary across the channel types
-- represented in the database.
--
-- Operations:
-- 1. Count the channels in each channel category.
-- 2. Calculate the average channel length.
-- 3. Identify the minimum and maximum channel lengths.
-- 4. Sort the results by average length, from highest to lowest.
--
-- Purpose:
-- Explore channel geometry and compare the lengths of
-- horizontal, tortuous, and vertical channels.
--
-- Note:
-- Results describe the available database records only.
-- ============================================================

SELECT
    CHANNEL_TYPE,
    COUNT(*) AS TOTAL_CHANNELS,
    ROUND(AVG(CHANNEL_LENGTH_m), 2) AS AVG_LENGTH_m,
    ROUND(MIN(CHANNEL_LENGTH_m), 2) AS MIN_LENGTH_m,
    ROUND(MAX(CHANNEL_LENGTH_m), 2) AS MAX_LENGTH_m
FROM lightning_channels
GROUP BY CHANNEL_TYPE
ORDER BY AVG_LENGTH_m DESC;



-- ============================================================
-- QUERY 50: CHANNEL PROPAGATION VELOCITY ANALYSIS
--
-- Objective:
-- Examine the propagation velocities recorded for lightning
-- channels in the database.
--
-- Operations:
-- 1. Count channels with recorded propagation velocities.
-- 2. Calculate the average, minimum, and maximum velocities.
-- 3. Express the results in metres per second.
--
-- Purpose:
-- Summarize the propagation parameters available for
-- subsequent exploration of lightning-generated EM fields.
--
-- Note:
-- These are database-recorded values, not independently
-- verified measurements of propagation velocity.
-- ============================================================

SELECT
    COUNT(*) AS TOTAL_CHANNELS,
    COUNT(PROPAGATION_VELOCITY_m_s) AS CHANNELS_WITH_VELOCITY,
    ROUND(AVG(PROPAGATION_VELOCITY_m_s), 2) AS AVG_VELOCITY_m_s,
    ROUND(MIN(PROPAGATION_VELOCITY_m_s), 2) AS MIN_VELOCITY_m_s,
    ROUND(MAX(PROPAGATION_VELOCITY_m_s), 2) AS MAX_VELOCITY_m_s
FROM lightning_channels;




-- ============================================================
-- QUERY 51: PEAK CURRENT ANALYSIS BY LIGHTNING TYPE
--
-- Objective:
-- Compare the peak-current values recorded for different
-- types of lightning events.
--
-- Operations:
-- 1. Join lightning events with their associated channels.
-- 2. Group the records by lightning type.
-- 3. Calculate the average, minimum, and maximum peak current.
--
-- Purpose:
-- Explore how the recorded peak-current values are distributed
-- across IC, CG, and CC lightning events.
--
-- Note:
-- Event-level and channel-level peak currents may represent
-- the same underlying value. Interpret the results accordingly.
-- ============================================================

SELECT
    e.LIGHTNING_TYPE,
    COUNT(DISTINCT e.EVENT_ID) AS TOTAL_EVENTS,
    ROUND(AVG(e.PEAK_CURRENT_kA), 3) AS AVG_PEAK_CURRENT_kA,
    ROUND(MIN(e.PEAK_CURRENT_kA), 3) AS MIN_PEAK_CURRENT_kA,
    ROUND(MAX(e.PEAK_CURRENT_kA), 3) AS MAX_PEAK_CURRENT_kA
FROM lightning_events AS e
JOIN lightning_channels AS c
    ON e.EVENT_ID = c.EVENT_ID
GROUP BY e.LIGHTNING_TYPE
ORDER BY AVG_PEAK_CURRENT_kA DESC;



-- ============================================================
-- QUERY 52: EVENT-TO-CHANNEL COVERAGE
--
-- Objective:
-- Identify which lightning events have associated channel
-- records and which events do not.
--
-- Operations:
-- 1. Join all events to their channels using a LEFT JOIN.
-- 2. Count the channels associated with each event.
-- 3. Group the results by lightning type and channel coverage.
--
-- Purpose:
-- Check whether the channel table represents all event types
-- before comparing channel-related parameters across events.
--
-- Note:
-- Events without channels remain in the results.
-- ============================================================

SELECT
    e.LIGHTNING_TYPE,
    CASE
        WHEN COUNT(c.CHANNEL_ID) = 0 THEN 'No channel record'
        ELSE 'Has channel record'
    END AS CHANNEL_STATUS,
    COUNT(*) AS TOTAL_EVENTS
FROM lightning_events AS e
LEFT JOIN lightning_channels AS c
    ON e.EVENT_ID = c.EVENT_ID
GROUP BY
    e.LIGHTNING_TYPE,
    CASE
        WHEN c.CHANNEL_ID IS NULL THEN 'No channel record'
        ELSE 'Has channel record'
    END
ORDER BY e.LIGHTNING_TYPE, CHANNEL_STATUS;



-- ============================================================
-- QUERY 53: ATMOSPHERIC CONDITIONS BY LIGHTNING TYPE
--
-- Objective:
-- Summarize the atmospheric conditions associated with
-- the recorded IC, CG, and CC lightning events.
--
-- Operations:
-- 1. Join lightning events with their atmospheric records.
-- 2. Group the results by lightning type.
-- 3. Calculate average temperature, pressure, humidity,
--    and wind speed for each type.
--
-- Purpose:
-- Explore the atmospheric data available for each lightning
-- category and identify differences in the stored records.
--
-- Note:
-- These summaries describe the database records only.
-- They do not establish that atmospheric conditions cause
-- differences between lightning types.
-- ============================================================

SELECT
    e.LIGHTNING_TYPE,
    COUNT(*) AS TOTAL_RECORDS,
    ROUND(AVG(a.TEMP_C), 2) AS AVG_TEMP_C,
    ROUND(AVG(a.PRESSURE_hPa), 2) AS AVG_PRESSURE_hPa,
    ROUND(AVG(a.HUMIDITY_PERCENT), 2) AS AVG_HUMIDITY_PERCENT,
    ROUND(AVG(a.WIND_SPEED_m_s), 2) AS AVG_WIND_SPEED_m_s
FROM lightning_events AS e
JOIN atmospheric_conds AS a
    ON e.EVENT_ID = a.EVENT_ID
GROUP BY e.LIGHTNING_TYPE
ORDER BY e.LIGHTNING_TYPE;



-- ============================================================
-- QUERY 54: ELECTRIC AND MAGNETIC FIELDS BY ALTITUDE
--
-- Objective:
-- Summarize the stored electric-field and magnetic-field
-- measurements at each observation altitude.
--
-- Operations:
-- 1. Group measurements by event and observation altitude.
-- 2. Count the available samples.
-- 3. Calculate the maximum absolute electric and magnetic
--    field values.
--
-- Purpose:
-- Explore how recorded field magnitudes differ between
-- observation altitudes for each event.
--
-- Note:
-- These statistics describe stored records. Interpret them
-- as physical comparisons only when their data sources and
-- measurement or simulation conditions are understood.
-- ============================================================

SELECT
    EVENT_ID,
    OBSERVATION_ALTITUDE_km,
    COUNT(*) AS TOTAL_SAMPLES,
    ROUND(MAX(ABS(E_FIELD_V_m)), 6) AS MAX_ABS_E_FIELD_V_m,
    ROUND(MAX(ABS(H_FIELD_A_m)), 6) AS MAX_ABS_H_FIELD_A_m
FROM lightning_measurements
GROUP BY EVENT_ID, OBSERVATION_ALTITUDE_km
ORDER BY EVENT_ID, OBSERVATION_ALTITUDE_km;



-- ============================================================
-- QUERY 55: CHECK COMPLETENESS OF EVENT-RELATED RECORDS
--
-- Objective:
-- Identify events that lack atmospheric-condition records
-- or associated channel records.
--
-- Operations:
-- 1. Link every lightning event to its atmospheric conditions.
-- 2. Link every lightning event to its channel records.
-- 3. Count the associated records for each event.
--
-- Purpose:
-- Identify gaps in the database and determine which event
-- categories have sufficient related information for further
-- exploratory analysis.
--
-- Note:
-- Missing channel records do not necessarily mean the event
-- itself is invalid; they indicate that channel information
-- is not currently stored for that event.
-- ============================================================

SELECT
    e.EVENT_ID,
    e.LIGHTNING_TYPE,
    COUNT(DISTINCT a.COND_ID) AS ATMOSPHERIC_RECORDS,
    COUNT(DISTINCT c.CHANNEL_ID) AS CHANNEL_RECORDS
FROM lightning_events AS e
LEFT JOIN atmospheric_conds AS a
    ON e.EVENT_ID = a.EVENT_ID
LEFT JOIN lightning_channels AS c
    ON e.EVENT_ID = c.EVENT_ID
GROUP BY e.EVENT_ID, e.LIGHTNING_TYPE
HAVING COUNT(DISTINCT a.COND_ID) = 0
    OR COUNT(DISTINCT c.CHANNEL_ID) = 0
ORDER BY e.EVENT_ID;



-- ============================================================
-- QUERY 56: VERIFY EVENT–STATION RELATIONSHIPS
--
-- Objective:
-- Identify any lightning events whose station IDs do not
-- match an existing observation station.
--
-- Operations:
-- 1. Join lightning events to observation stations.
-- 2. Use a LEFT JOIN to retain events without a matching station.
-- 3. Return only events with missing station references.
--
-- Purpose:
-- Check the consistency of the event–station relationship
-- before presenting the database as a completed project.
--
-- Expected result:
-- Zero rows if every event references an existing station.
-- ============================================================

SELECT
    e.EVENT_ID,
    e.STATION_ID
FROM lightning_events AS e
LEFT JOIN observation_stations AS s
    ON e.STATION_ID = s.STATION_ID
WHERE s.STATION_ID IS NULL;



-- ============================================================
-- QUERY 57: VERIFY CHANNEL–EVENT RELATIONSHIPS
--
-- Objective:
-- Identify channel records that reference a nonexistent
-- lightning event.
--
-- Operations:
-- 1. Match each channel to its lightning event.
-- 2. Return channels without a matching event.
--
-- Purpose:
-- Verify the consistency of the channel–event relationship.
--
-- Expected result:
-- Zero rows if every channel references an existing event.
-- ============================================================

SELECT
    c.CHANNEL_ID,
    c.EVENT_ID
FROM lightning_channels AS c
LEFT JOIN lightning_events AS e
    ON c.EVENT_ID = e.EVENT_ID
WHERE e.EVENT_ID IS NULL;



-- ============================================================
-- QUERY 58: VERIFY CHANNEL–POINT RELATIONSHIPS
--
-- Objective:
-- Identify channel-point records that reference a nonexistent
-- lightning channel.
--
-- Operations:
-- 1. Match each channel point to its parent channel.
-- 2. Return points without a matching channel.
--
-- Purpose:
-- Check the integrity of the stored lightning-channel geometry.
--
-- Expected result:
-- Zero rows if every channel point references an existing channel.
-- ============================================================

SELECT
    p.CHANNEL_POINT_ID,
    p.CHANNEL_ID
FROM channel_points AS p
LEFT JOIN lightning_channels AS c
    ON p.CHANNEL_ID = c.CHANNEL_ID
WHERE c.CHANNEL_ID IS NULL;



-- ============================================================
-- QUERY 59: VERIFY MEASUREMENT–EVENT RELATIONSHIPS
--
-- Objective:
-- Identify field-measurement records that reference a
-- nonexistent lightning event.
--
-- Operations:
-- 1. Match each measurement to its lightning event.
-- 2. Return measurements without a matching event.
--
-- Purpose:
-- Check the integrity of the relationship between recorded
-- electric/magnetic field data and lightning events.
--
-- Expected result:
-- Zero rows if every measurement references an existing event.
-- ============================================================

SELECT
    m.MEASUREMENT_ID,
    m.EVENT_ID,
    m.OBSERVATION_ALTITUDE_km
FROM lightning_measurements AS m
LEFT JOIN lightning_events AS e
    ON m.EVENT_ID = e.EVENT_ID
WHERE e.EVENT_ID IS NULL;



-- ============================================================
-- QUERY 60: LIGHTNING EVENT AND CHANNEL SUMMARY
--
-- Objective:
-- Summarize the number of lightning events and the availability
-- of channel data for each lightning type.
--
-- Operations:
-- 1. Group events by lightning type.
-- 2. Count the total events in each category.
-- 3. Count the events with and without channel records.
--
-- Purpose:
-- Understand which lightning types are represented in the
-- channel-geometry dataset and identify coverage limitations.
-- ============================================================

SELECT
    e.LIGHTNING_TYPE,
    COUNT(DISTINCT e.EVENT_ID) AS TOTAL_EVENTS,
    COUNT(DISTINCT c.EVENT_ID) AS EVENTS_WITH_CHANNELS,
    COUNT(DISTINCT e.EVENT_ID)
        - COUNT(DISTINCT c.EVENT_ID) AS EVENTS_WITHOUT_CHANNELS
FROM lightning_events AS e
LEFT JOIN lightning_channels AS c
    ON e.EVENT_ID = c.EVENT_ID
GROUP BY e.LIGHTNING_TYPE
ORDER BY TOTAL_EVENTS DESC;



-- ============================================================
-- QUERY 61: PEAK CURRENT SUMMARY BY LIGHTNING TYPE
--
-- Objective:
-- Compare the recorded peak currents across IC, CG, and CC events.
--
-- Operations:
-- 1. Group lightning events by their type.
-- 2. Calculate the number of events and average peak current.
-- 3. Identify the minimum and maximum peak current in each group.
--
-- Purpose:
-- Explore how peak-current values are distributed among the
-- lightning events stored in the database.
--
-- Note:
-- These statistics describe this dataset only and should not
-- be interpreted as universal characteristics of each type.
-- ============================================================

SELECT
    LIGHTNING_TYPE,
    COUNT(*) AS TOTAL_EVENTS,
    ROUND(AVG(PEAK_CURRENT_kA), 3) AS AVG_PEAK_CURRENT_kA,
    ROUND(MIN(PEAK_CURRENT_kA), 3) AS MIN_PEAK_CURRENT_kA,
    ROUND(MAX(PEAK_CURRENT_kA), 3) AS MAX_PEAK_CURRENT_kA
FROM lightning_events
GROUP BY LIGHTNING_TYPE
ORDER BY AVG_PEAK_CURRENT_kA DESC;



-- ============================================================
-- QUERY 62: ELECTRIC AND MAGNETIC FIELD SUMMARY BY ALTITUDE
--
-- Objective:
-- Summarize the field strengths recorded at each observation
-- altitude in the measurement dataset.
--
-- Operations:
-- 1. Group measurements by event and observation altitude.
-- 2. Count the available samples.
-- 3. Calculate the maximum absolute electric and magnetic fields.
-- 4. Calculate the mean absolute field values.
--
-- Purpose:
-- Explore how the stored field values differ between
-- observation altitudes.
--
-- Note:
-- These are descriptive statistics for the available data,
-- not proof of a physical altitude-dependent relationship.
-- ============================================================

SELECT
    EVENT_ID,
    OBSERVATION_ALTITUDE_km,
    COUNT(*) AS TOTAL_SAMPLES,
    ROUND(MAX(ABS(E_FIELD_V_m)), 3) AS MAX_ABS_E_FIELD_V_m,
    ROUND(AVG(ABS(E_FIELD_V_m)), 3) AS MEAN_ABS_E_FIELD_V_m,
    ROUND(MAX(ABS(H_FIELD_A_m)), 6) AS MAX_ABS_H_FIELD_A_m,
    ROUND(AVG(ABS(H_FIELD_A_m)), 6) AS MEAN_ABS_H_FIELD_A_m
FROM lightning_measurements
GROUP BY
    EVENT_ID,
    OBSERVATION_ALTITUDE_km
ORDER BY
    EVENT_ID,
    OBSERVATION_ALTITUDE_km;
    
    
    
-- ============================================================
-- QUERY 63: FIELD WAVEFORM AT SELECTED TIMES
--
-- Objective:
-- Inspect electric and magnetic field values at selected
-- time points for each observation altitude.
--
-- Operations:
-- 1. Select measurements for Event 103.
-- 2. Retain samples at selected times.
-- 3. Display both field components alongside altitude and time.
--
-- Purpose:
-- Provide a compact view of the stored waveform data for
-- comparison and possible plotting.
--
-- Note:
-- This query samples the existing data; it does not interpolate
-- or validate the underlying electromagnetic-field model.
-- ============================================================

SELECT
    EVENT_ID,
    OBSERVATION_ALTITUDE_km,
    TIME_us,
    E_FIELD_V_m,
    H_FIELD_A_m
FROM lightning_measurements
WHERE EVENT_ID = 103
  AND TIME_us IN (0, 10, 25, 50, 100, 150, 200, 250)
ORDER BY
    OBSERVATION_ALTITUDE_km,
    TIME_us;
    
    

-- ============================================================
-- QUERY 64: EVENT DATA-COMPLETENESS SUMMARY
--
-- Objective:
-- Summarize the availability of supporting data for each
-- lightning event.
--
-- Operations:
-- 1. Count channel records associated with each event.
-- 2. Count atmospheric-condition records.
-- 3. Count field-measurement samples.
--
-- Purpose:
-- Identify which events have the supporting data required
-- for different types of analysis.
--
-- Note:
-- Record availability does not guarantee scientific accuracy
-- or completeness of the underlying measurements.
-- ============================================================

SELECT
    e.EVENT_ID,
    e.LIGHTNING_TYPE,
    COUNT(DISTINCT c.CHANNEL_ID) AS CHANNEL_RECORDS,
    COUNT(DISTINCT a.COND_ID) AS ATMOSPHERIC_RECORDS,
    COUNT(DISTINCT m.MEASUREMENT_ID) AS FIELD_MEASUREMENT_SAMPLES
FROM lightning_events AS e
LEFT JOIN lightning_channels AS c
    ON e.EVENT_ID = c.EVENT_ID
LEFT JOIN atmospheric_conds AS a
    ON e.EVENT_ID = a.EVENT_ID
LEFT JOIN lightning_measurements AS m
    ON e.EVENT_ID = m.EVENT_ID
GROUP BY
    e.EVENT_ID,
    e.LIGHTNING_TYPE
ORDER BY e.EVENT_ID;



-- ============================================================
-- QUERY 65: FILTER LIGHTNING TYPES USING HAVING
--
-- Objective:
-- Identify lightning types whose average recorded peak current
-- exceeds 20 kA.
--
-- Concepts demonstrated:
-- 1. GROUP BY groups events by lightning type.
-- 2. AVG() calculates the mean peak current for each group.
-- 3. HAVING filters groups based on their aggregate values.
--
-- Interview concept:
-- WHERE filters individual rows before grouping, whereas
-- HAVING filters groups after aggregation.
--
-- Note:
-- The threshold is an exploratory choice, not a physical limit.
-- ============================================================

SELECT
    LIGHTNING_TYPE,
    COUNT(*) AS TOTAL_EVENTS,
    ROUND(AVG(PEAK_CURRENT_kA), 3) AS AVG_PEAK_CURRENT_kA
FROM lightning_events
GROUP BY LIGHTNING_TYPE
HAVING AVG(PEAK_CURRENT_kA) > 20
ORDER BY AVG_PEAK_CURRENT_kA DESC;



-- ============================================================
-- QUERY 66: CLASSIFY LIGHTNING EVENTS BY PEAK CURRENT
--
-- Objective:
-- Assign each event to a peak-current category using CASE.
--
-- Concepts demonstrated:
-- 1. CASE evaluates conditions in sequence.
-- 2. WHEN specifies a condition.
-- 3. THEN specifies the resulting category.
-- 4. ELSE handles values not covered by earlier conditions.
-- ============================================================

SELECT
    EVENT_ID,
    LIGHTNING_TYPE,
    PEAK_CURRENT_kA,
    CASE
        WHEN PEAK_CURRENT_kA < 10 THEN 'LOW'
        WHEN PEAK_CURRENT_kA < 30 THEN 'MODERATE'
        ELSE 'HIGH'
    END AS CURRENT_CATEGORY
FROM lightning_events
ORDER BY PEAK_CURRENT_kA DESC;



-- ============================================================
-- QUERY 67: FIND EVENTS ABOVE THE OVERALL AVERAGE CURRENT
--
-- Objective:
-- Identify events whose peak current exceeds the average
-- peak current across all lightning events.
--
-- Concepts demonstrated:
-- 1. The inner query calculates the overall average.
-- 2. The outer query selects events above that average.
-- 3. A subquery supplies a value to the main query.
-- ============================================================

SELECT
    EVENT_ID,
    LIGHTNING_TYPE,
    PEAK_CURRENT_kA
FROM lightning_events
WHERE PEAK_CURRENT_kA > (
    SELECT AVG(PEAK_CURRENT_kA)
    FROM lightning_events
)
ORDER BY PEAK_CURRENT_kA DESC;



-- ============================================================
-- QUERY 68: USE A CTE TO SUMMARIZE LIGHTNING CURRENT
--
-- Objective:
-- Calculate the average peak current for each lightning type
-- and display only types whose average exceeds 20 kA.
--
-- Concepts demonstrated:
-- 1. WITH defines a Common Table Expression (CTE).
-- 2. The CTE stores a named intermediate query result.
-- 3. The main query filters and sorts that result.
-- ============================================================

WITH CurrentSummary AS (
    SELECT
        LIGHTNING_TYPE,
        COUNT(*) AS TOTAL_EVENTS,
        AVG(PEAK_CURRENT_kA) AS AVG_CURRENT_kA
    FROM lightning_events
    GROUP BY LIGHTNING_TYPE
)
SELECT
    LIGHTNING_TYPE,
    TOTAL_EVENTS,
    ROUND(AVG_CURRENT_kA, 3) AS AVG_CURRENT_kA
FROM CurrentSummary
WHERE AVG_CURRENT_kA > 20
ORDER BY AVG_CURRENT_kA DESC;



