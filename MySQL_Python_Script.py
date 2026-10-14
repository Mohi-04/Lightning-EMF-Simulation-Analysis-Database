# ============================================================
# INSERTING RECORDS INT TABLE 3 and 4
# ============================================================

import pandas as pd
import mysql.connector as mysql


# ============================================================
# 1. LOAD THE CSV FILE
# ============================================================

df = pd.read_csv("C:\\Users\\modib\\OneDrive\\Desktop\\PRL\\CSVs\\channel_cloud_to_cloud.csv")


# ============================================================
# 2. INSPECT THE CSV DATA
# ============================================================

print("\n========================================")
print("           CSV INFORMATION")
print("========================================")

print("\n----------------------------------------")
print("First 5 rows:")
print("----------------------------------------")
print(df.head())

print("\n----------------------------------------")
print("Column names:")
print("----------------------------------------")
print(df.columns.tolist())

print("\n----------------------------------------")
print("Dataset shape:")
print("----------------------------------------")
print(df.shape)

print("\n----------------------------------------")
print("Data information:")
print("----------------------------------------")
df.info()

print("\n----------------------------------------")
print("Missing values:")
print("----------------------------------------")
print(df.isnull().sum())


# ============================================================
# 3. CHECK REQUIRED COLUMNS
# ============================================================

required_columns = [
    "Point",
    "xp",
    "yp",
    "zp",
    "Length"
]

for column in required_columns:

    if column not in df.columns:

        raise ValueError(
            f"Required column '{column}' is missing from CSV."
        )

print("\nAll required columns are present.")


# ============================================================
# 4. CONVERT CSV COLUMNS TO NUMERIC
# ============================================================

# Point number → integer
df["Point"] = pd.to_numeric(
    df["Point"],
    errors="raise"
).astype(int)


# X coordinate → float
df["xp"] = pd.to_numeric(
    df["xp"],
    errors="raise"
)


# Y coordinate → float
df["yp"] = pd.to_numeric(
    df["yp"],
    errors="raise"
)


# Z coordinate → float
df["zp"] = pd.to_numeric(
    df["zp"],
    errors="raise"
)


# Length
# The first Length value is '-'.
# errors="coerce" converts '-' to NaN.

df["Length"] = pd.to_numeric(
    df["Length"],
    errors="coerce"
)


# ============================================================
# 5. CHANNEL STATISTICS
# ============================================================

total_length = df["Length"].sum()

number_of_points = len(df)

number_of_segments = number_of_points - 1

mean_segment_length = df["Length"].iloc[1:].mean()


print("\n========================================")
print("          CHANNEL STATISTICS")
print("========================================")

print(
    f"Number of channel points = {number_of_points}"
)

print(
    f"Number of channel segments = {number_of_segments}"
)

print(
    f"Total channel length = {total_length:.3f} m"
)

print(
    f"Mean segment length = {mean_segment_length:.3f} m"
)


# ============================================================
# 6. DEFINE CHANNEL INFORMATION
# ============================================================

# This is the ID of the lightning channel we are importing.
CHANNEL_ID = 1


# This CSV represents a tortuous channel.
CHANNEL_TYPE = "TORTUOUS"


# Channel length obtained from the CSV.
CHANNEL_LENGTH = total_length


# Propagation velocity used in the simulation.
PROPAGATION_VELOCITY = 20000000.00


# Peak current used in the simulation.
PEAK_CURRENT = 2.800


# ============================================================
# 7. CONNECT TO MYSQL
# ============================================================

print("\n========================================")
print("           MYSQL CONNECTION")
print("========================================")


connect = mysql.connect(
    host="localhost",
    user="root",
    password="Mohi@SQL_11",
    database="LIGHTNING"
)

cursor = connect.cursor()


# ============================================================
# 8. CHECK MYSQL CONNECTION
# ============================================================

cursor.execute(
    "SELECT DATABASE();"
)

# to get the selected (asked) result
database_result = cursor.fetchone()


print(
    f"Connected database: {database_result[0]}"
)

print(
    "---------------- Successfully connected to MySQL ----------------"
)


# ============================================================
# 9. SELECT ALL IC LIGHTNING EVENTS
# ============================================================

cursor.execute("""
    SELECT
        EVENT_ID,
        PEAK_CURRENT_kA,
        DURATION_us
    FROM LIGHTNING_EVENTS
    WHERE LIGHTNING_TYPE = 'IC'
    ORDER BY EVENT_ID
""")

event_results = cursor.fetchall()

if not event_results:
    raise ValueError(
        "No IC lightning events exist in LIGHTNING_EVENTS."
    )

print("\n========================================")
print("       SELECTED IC LIGHTNING EVENTS")
print("========================================")

print(f"Total IC events selected = {len(event_results)}")

for event in event_results:
    print(
        f"EVENT_ID = {event[0]}, "
        f"Peak current = {event[1]} kA, "
        f"Duration = {event[2]} us"
    )


# ============================================================
# 10. FIND THE NEXT AVAILABLE CHANNEL_ID
# ============================================================

cursor.execute("""
    SELECT COALESCE(MAX(CHANNEL_ID), 0) + 1
    FROM LIGHTNING_CHANNELS
""")

next_channel_id = cursor.fetchone()[0]


# ============================================================
# 11. PREPARE THE CHANNEL INSERT STATEMENT
# ============================================================

insert_channel_sql = """
INSERT INTO LIGHTNING_CHANNELS
(
    CHANNEL_ID,
    EVENT_ID,
    CHANNEL_TYPE,
    CHANNEL_LENGTH_m,
    PROPAGATION_VELOCITY_m_s,
    PEAK_CURRENT_kA
)
VALUES (%s, %s, %s, %s, %s, %s)
"""


# ============================================================
# 12. INSERT A CHANNEL RECORD FOR EVERY IC EVENT
# ============================================================

print("\n========================================")
print("     INSERTING IC CHANNEL RECORDS")
print("========================================")

inserted_count = 0
skipped_count = 0

try:

    for event in event_results:

        # Get information for this IC event
        event_id = event[0]
        peak_current = event[1]

        # Check whether this event already has a channel
        cursor.execute("""
            SELECT CHANNEL_ID
            FROM LIGHTNING_CHANNELS
            WHERE EVENT_ID = %s
        """, (event_id,))

        existing_channel = cursor.fetchone()

        if existing_channel is not None:

            print(
                f"Skipped EVENT_ID = {event_id}: "
                f"already has CHANNEL_ID = "
                f"{existing_channel[0]}"
            )

            skipped_count += 1
            continue

        # Prepare channel data for this event
        channel_data = (
            next_channel_id,
            event_id,
            "TORTUOUS",
            CHANNEL_LENGTH,
            PROPAGATION_VELOCITY,
            peak_current
        )

        # Insert the channel record
        cursor.execute(
            insert_channel_sql,
            channel_data
        )

        print(
            f"Inserted CHANNEL_ID = {next_channel_id}, "
            f"EVENT_ID = {event_id}, "
            f"PEAK_CURRENT = {peak_current} kA"
        )

        next_channel_id += 1
        inserted_count += 1

    # Save all successful insertions
    connect.commit()

    print("\n========================================")
    print("          INSERTION SUMMARY")
    print("========================================")

    print(f"IC events selected = {len(event_results)}")
    print(f"Channel records inserted = {inserted_count}")
    print(f"Events skipped = {skipped_count}")

except Exception:
    connect.rollback()
    raise


# ============================================================
# 13. VERIFY THE INSERTED RECORDS
# ============================================================

cursor.execute("""
    SELECT
        C.CHANNEL_ID,
        C.EVENT_ID,
        E.LIGHTNING_TYPE,
        C.CHANNEL_TYPE,
        C.CHANNEL_LENGTH_m,
        C.PROPAGATION_VELOCITY_m_s,
        C.PEAK_CURRENT_kA
    FROM LIGHTNING_CHANNELS AS C
    JOIN LIGHTNING_EVENTS AS E
        ON C.EVENT_ID = E.EVENT_ID
    WHERE E.LIGHTNING_TYPE = 'IC'
    ORDER BY C.EVENT_ID
""")

stored_records = cursor.fetchall()

print("\nIC channel records currently in LIGHTNING_CHANNELS:")

for record in stored_records:
    print(record)

# ============================================================
# 13. INSERT CSV POINTS INTO CHANNEL_POINTS
# ============================================================

print("\n========================================")
print("       INSERTING CHANNEL POINTS")
print("========================================")


# ------------------------------------------------------------
# SQL statement for inserting channel points
# ------------------------------------------------------------

insert_point_sql = """
INSERT INTO CHANNEL_POINTS
(
    CHANNEL_POINT_ID,
    CHANNEL_ID,
    POINT_INDEX,
    X_m,
    Y_m,
    Z_m,
    SEGMENT_LENGTH_m
)
VALUES
(
    %s,
    %s,
    %s,
    %s,
    %s,
    %s,
    %s
)
"""


# ------------------------------------------------------------
# Insert every point from the CSV
# ------------------------------------------------------------

for index, row in df.iterrows():

    # --------------------------------------------------------
    # Generate CHANNEL_POINT_ID
    # --------------------------------------------------------

    channel_point_id = index + 1


    # --------------------------------------------------------
    # Get POINT_INDEX from CSV
    # --------------------------------------------------------

    point_index = int(
        row["Point"]
    )


    # --------------------------------------------------------
    # Get coordinates from CSV
    # --------------------------------------------------------

    x = float(
        row["xp"]
    )

    y = float(
        row["yp"]
    )

    z = float(
        row["zp"]
    )


    # --------------------------------------------------------
    # Get segment length
    # --------------------------------------------------------
    #
    # The first CSV row contains '-'.
    #
    # During Section 4, '-' was converted to NaN.
    #
    # MySQL connector cannot directly store pandas NaN
    # in the intended way, so convert NaN to Python None.
    #
    # Python None -> MySQL NULL
    # --------------------------------------------------------

    if pd.isna(row["Length"]):

        segment_length = None

    else:

        segment_length = float(
            row["Length"]
        )


    # --------------------------------------------------------
    # Prepare values for SQL INSERT
    # --------------------------------------------------------

    point_data = (
        channel_point_id,
        CHANNEL_ID,
        point_index,
        x,
        y,
        z,
        segment_length
    )


    # --------------------------------------------------------
    # Insert the point into CHANNEL_POINTS
    # --------------------------------------------------------

    cursor.execute(
        insert_point_sql,
        point_data
    )


print(
    f"\nSuccessfully inserted "
    f"{number_of_points} channel points."
)

# ============================================================
# 14. COMMIT EVERYTHING
# ============================================================

connect.commit()


print(
    "\nAll changes successfully committed to MySQL."
)


# ============================================================
# 15. VERIFY LIGHTNING_CHANNELS
# ============================================================

print("\n========================================")
print("      VERIFYING LIGHTNING_CHANNELS")
print("========================================")


verify_channel_sql = """
SELECT
    CHANNEL_ID,
    EVENT_ID,
    CHANNEL_TYPE,
    CHANNEL_LENGTH_m,
    PROPAGATION_VELOCITY_m_s,
    PEAK_CURRENT_kA
FROM LIGHTNING_CHANNELS
WHERE CHANNEL_ID = %s
"""


cursor.execute(
    verify_channel_sql,
    (CHANNEL_ID,)
)


channel_result = cursor.fetchone()


if channel_result is not None:

    print("\nChannel record found:")

    print(
        f"CHANNEL_ID = {channel_result[0]}"
    )

    print(
        f"EVENT_ID = {channel_result[1]}"
    )

    print(
        f"CHANNEL_TYPE = {channel_result[2]}"
    )

    print(
        f"CHANNEL_LENGTH_m = {channel_result[3]}"
    )

    print(
        f"PROPAGATION_VELOCITY_m_s = {channel_result[4]}"
    )

    print(
        f"PEAK_CURRENT_kA = {channel_result[5]}"
    )

else:

    print(
        "Channel record was not found."
    )


# ============================================================
# 16. VERIFY CHANNEL_POINTS
# ============================================================

print("\n========================================")
print("        VERIFYING CHANNEL_POINTS")
print("========================================")


cursor.execute(
    """
    SELECT COUNT(*)
    FROM CHANNEL_POINTS
    WHERE CHANNEL_ID = %s
    """,
    (CHANNEL_ID,)
)


point_count = cursor.fetchone()[0]


print(
    f"Number of channel points stored = {point_count}"
)


# ============================================================
# 17. DISPLAY FIRST 5 INSERTED POINTS
# ============================================================

cursor.execute(
    """
    SELECT
        CHANNEL_POINT_ID,
        CHANNEL_ID,
        POINT_INDEX,
        X_m,
        Y_m,
        Z_m,
        SEGMENT_LENGTH_m
    FROM CHANNEL_POINTS
    WHERE CHANNEL_ID = %s
    ORDER BY POINT_INDEX
    LIMIT 5
    """,
    (CHANNEL_ID,)
)


points = cursor.fetchall()


print("\nFirst 5 stored channel points:")

for point in points:

    print(point)



# ============================================================
# 18. CLOSE MYSQL CONNECTION
# ============================================================

cursor.close()

connect.close()


print("\n========================================")
print("             IMPORT COMPLETE")
print("========================================")

print(
    "MySQL connection closed."
)

print(
    "Program finished successfully."
)
















































































































































































































# ============================================================
# INSERTING RECORDS IN TABLE 5
# ============================================================

import pandas as pd
import mysql.connector as mysql


# ============================================================
# 1. LOAD THE CSV FILE
# ============================================================

df = pd.read_csv(
    r"C:\Users\modib\OneDrive\Desktop\PRL\CSVs\MySQL\tortuous_field_data_125001.csv"
)


# ============================================================
# 2. INSPECT THE CSV DATA
# ============================================================

print("\n========================================")
print("           CSV INFORMATION")
print("========================================")


print("\n----------------------------------------")
print("First 5 rows:")
print("----------------------------------------")

print(df.head())


print("\n----------------------------------------")
print("Column names:")
print("----------------------------------------")

print(df.columns.tolist())


print("\n----------------------------------------")
print("Dataset shape:")
print("----------------------------------------")

print(df.shape)


print("\n----------------------------------------")
print("Data information:")
print("----------------------------------------")

df.info()


print("\n----------------------------------------")
print("Missing values:")
print("----------------------------------------")

print(df.isnull().sum())


# ============================================================
# 3. CHECK REQUIRED COLUMNS
# ============================================================

required_columns = [
    "OBSERVATION_POINT",
    "TIME_us",
    "EF_V_m",
    "MF_A_m"
]


for column in required_columns:

    if column not in df.columns:

        raise ValueError(
            f"Required column '{column}' is missing from CSV."
        )


print(
    "\nAll required columns are present."
)


# ============================================================
# 4. CHECK OBSERVATION POINTS
# ============================================================

print("\n========================================")
print("       OBSERVATION POINTS")
print("========================================")


print(
    df["OBSERVATION_POINT"].unique()
)


# ============================================================
# 5. CHECK NUMBER OF RECORDS
# ============================================================

print("\n========================================")
print("          DATASET STATISTICS")
print("========================================")


print(
    f"\nTotal number of records = {len(df)}"
)


print(
    "\nRecords per observation point:"
)


print(
    df.groupby(
        "OBSERVATION_POINT"
    ).size()
)


# ============================================================
# 6. CONVERT DATA TYPES
# ============================================================

df["TIME_us"] = pd.to_numeric(
    df["TIME_us"],
    errors="coerce"
)


df["EF_V_m"] = pd.to_numeric(
    df["EF_V_m"],
    errors="coerce"
)


df["MF_A_m"] = pd.to_numeric(
    df["MF_A_m"],
    errors="coerce"
)


# ============================================================
# 7. CHECK FOR INVALID / MISSING VALUES
# ============================================================

print("\n========================================")
print("         DATA VALIDATION")
print("========================================")


print("\nMissing values after conversion:")


print(
    df[
        [
            "TIME_us",
            "EF_V_m",
            "MF_A_m"
        ]
    ].isnull().sum()
)


# ------------------------------------------------------------
# Stop if invalid values are present
# ------------------------------------------------------------

if df[
    [
        "TIME_us",
        "EF_V_m",
        "MF_A_m"
    ]
].isnull().any().any():

    raise ValueError(
        "CSV contains missing or invalid numerical values."
    )


print(
    "\nAll numerical values are valid."
)


# ============================================================
# 8. DEFINE OBSERVATION ALTITUDES
# ============================================================

# These values come from the observation-point
# definitions in the lightning simulation.
#
# P1 = [0, 1000, 0]    -> 0 km
# P2 = [0, 1000, 3000] -> 3 km


observation_altitude = {

    "P1": 0.00,

    "P2": 3.00

}


# ============================================================
# 9. CHECK THAT ALL CSV POINTS HAVE ALTITUDES
# ============================================================

for point_name in df["OBSERVATION_POINT"].unique():

    if point_name not in observation_altitude:

        raise ValueError(
            f"No altitude defined for observation point "
            f"'{point_name}'."
        )


print("\nObservation-point altitude mapping:")


for point_name, altitude in observation_altitude.items():

    print(
        f"{point_name} -> {altitude} km"
    )


# ============================================================
# 10. CONNECT TO MYSQL
# ============================================================

print("\n========================================")
print("           MYSQL CONNECTION")
print("========================================")


connect = mysql.connect(
    host="localhost",
    user="root",
    password="Mohi@SQL_11",
    database="LIGHTNING"
)


cursor = connect.cursor(buffered = True)


# ============================================================
# 11. CHECK MYSQL CONNECTION
# ============================================================

cursor.execute(
    "SELECT DATABASE();"
)


database_result = cursor.fetchone()


print(
    f"Connected database: {database_result[0]}"
)


print(
    "---------------- Successfully connected to MySQL ----------------"
)


# ============================================================
# 12. SELECT THE TORTUOUS CHANNEL
# ============================================================

cursor.execute(
    """
    SELECT
        CHANNEL_ID,
        EVENT_ID,
        CHANNEL_TYPE,
        CHANNEL_LENGTH_m,
        PROPAGATION_VELOCITY_m_s,
        PEAK_CURRENT_kA
    FROM LIGHTNING_CHANNELS
    WHERE CHANNEL_TYPE = 'TORTUOUS'
    ORDER BY CHANNEL_ID
    LIMIT 1
    """
)

channel_result = cursor.fetchone()

# ------------------------------------------------------------
# Check whether a Tortuous channel exists
# ------------------------------------------------------------

if channel_result is None:
    raise ValueError(
        "No TORTUOUS channel exists in LIGHTNING_CHANNELS."
    )

# ------------------------------------------------------------
# Get channel information
# ------------------------------------------------------------

CHANNEL_ID = channel_result[0]
EVENT_ID = channel_result[1]
CHANNEL_TYPE = channel_result[2]
CHANNEL_LENGTH = channel_result[3]
PROPAGATION_VELOCITY = channel_result[4]
PEAK_CURRENT = channel_result[5]


# ============================================================
# 13. DISPLAY CHANNEL INFORMATION
# ============================================================

print("\n========================================")
print("        TORTUOUS CHANNEL")
print("========================================")


print(
    f"\nCHANNEL_ID = {CHANNEL_ID}"
)


print(
    f"EVENT_ID = {EVENT_ID}"
)


print(
    f"CHANNEL_TYPE = {CHANNEL_TYPE}"
)


print(
    f"CHANNEL_LENGTH = {CHANNEL_LENGTH} m"
)


print(
    f"PROPAGATION_VELOCITY = "
    f"{PROPAGATION_VELOCITY} m/s"
)


print(
    f"PEAK_CURRENT = {PEAK_CURRENT} kA"
)


# ============================================================
# 14. CHECK EVENT
# ============================================================

cursor.execute(
    """
    SELECT
        EVENT_ID,
        LIGHTNING_TYPE,
        PEAK_CURRENT_kA,
        DURATION_us
    FROM LIGHTNING_EVENTS
    WHERE EVENT_ID = %s
    """,
    (EVENT_ID,)
)


event_result = cursor.fetchone()


if event_result is None:

    raise ValueError(
        f"EVENT_ID {EVENT_ID} does not exist "
        "in LIGHTNING_EVENTS."
    )


print("\n========================================")
print("          EVENT INFORMATION")
print("========================================")


print(
    f"\nEVENT_ID = {event_result[0]}"
)


print(
    f"LIGHTNING_TYPE = {event_result[1]}"
)


print(
    f"PEAK_CURRENT = {event_result[2]} kA"
)


print(
    f"DURATION = {event_result[3]} us"
)


# # ============================================================
# # 15. GET NEXT MEASUREMENT_ID
# # ============================================================
#
# cursor.execute(
#     """
#     SELECT
#         COALESCE(MAX(MEASUREMENT_ID), 0)
#     FROM LIGHTNING_MEASUREMENTS
#     """
# )
#
#
# last_measurement_id = cursor.fetchone()[0]
#
#
# measurement_id = last_measurement_id + 1
#
#
# print("\n========================================")
# print("        MEASUREMENT ID")
# print("========================================")
#
#
# print(
#     f"\nLast MEASUREMENT_ID = "
#     f"{last_measurement_id}"
# )
#
#
# print(
#     f"First new MEASUREMENT_ID = "
#     f"{measurement_id}"
# )



# ============================================================
# 16. PREPARE INSERT / UPDATE STATEMENT
# ============================================================

insert_measurement_sql = """
INSERT INTO LIGHTNING_MEASUREMENTS
(
    EVENT_ID,
    OBSERVATION_ALTITUDE_km,
    TIME_us,
    E_FIELD_V_m,
    H_FIELD_A_m
)
VALUES
    (
        %s,
        %s,
        %s,
        %s,
        %s
    )
AS new
ON DUPLICATE KEY UPDATE
    E_FIELD_V_m = new.E_FIELD_V_m,
    H_FIELD_A_m = new.H_FIELD_A_m
"""



# ============================================================
# 17. PREPARE MEASUREMENT DATA
# ============================================================

print("\n========================================")
print("       PREPARING MEASUREMENTS")
print("========================================")

# Map each observation point to its altitude
df["OBSERVATION_ALTITUDE_km"] = (
    df["OBSERVATION_POINT"].map(observation_altitude)
)

# Match the precision of the MySQL TIME_us column
df["TIME_us"] = df["TIME_us"].round(6)

# Check for repeated logical measurement keys within the CSV
duplicate_rows = df.duplicated(
    subset=["OBSERVATION_ALTITUDE_km", "TIME_us"],
    keep=False
)

if duplicate_rows.any():
    raise ValueError(
        "CSV contains duplicate altitude/time combinations. "
        "Resolve these before importing."
    )

# Prepare tuples in the same order as the SQL placeholders
measurement_data = list(
    df[
        [
            "OBSERVATION_ALTITUDE_km",
            "TIME_us",
            "EF_V_m",
            "MF_A_m"
        ]
    ].itertuples(index=False, name=None)
)

measurement_data = [
    (
        EVENT_ID,
        float(altitude),
        float(time_us),
        float(e_field),
        float(h_field)
    )
    for altitude, time_us, e_field, h_field in measurement_data
]

print(
    f"\nPrepared {len(measurement_data):,} "
    "measurement records."
)



# ============================================================
# 18. INSERT OR UPDATE MEASUREMENTS IN BATCHES
# ============================================================

print("\n========================================")
print("   SYNCHRONIZING MEASUREMENTS")
print("========================================")

batch_size = 5000
total_records = len(measurement_data)

for start in range(0, total_records, batch_size):

    end = min(start + batch_size, total_records)
    batch = measurement_data[start:end]

    try:

        # print("SQL statement:")
        # print(repr(insert_measurement_sql))
        #
        # print("Placeholder count:", insert_measurement_sql.count("%s"))
        # print("First batch row:", repr(batch[0]))
        # print("First row value count:", len(batch[0]))
        # print("Batch size:", len(batch))

        # Stop before executing SQL so we can inspect the mismatch
        # raise SystemExit("Diagnostic stop: SQL was not executed.")

        cursor.executemany(
            insert_measurement_sql,
            batch
        )
        connect.commit()

    except Exception:
        connect.rollback()
        raise

    # print(
    #     f"Processed {end:,} / {total_records:,} records"
    # )

print("\nCSV synchronization pass completed.")


# ============================================================
# 19. VERIFY NUMBER OF INSERTED RECORDS
# ============================================================

print("\n========================================")
print("       VERIFYING MEASUREMENTS")
print("========================================")


cursor.execute(
    """
    SELECT COUNT(*)
    FROM LIGHTNING_MEASUREMENTS
    WHERE EVENT_ID = %s
    """,
    (EVENT_ID,)
)


measurement_count = cursor.fetchone()[0]


print(
    f"\nNumber of measurements for "
    f"EVENT_ID {EVENT_ID} = "
    f"{measurement_count:,}"
)


# ============================================================
# 20. VERIFY OBSERVATION ALTITUDES
# ============================================================

cursor.execute(
    """
    SELECT
        OBSERVATION_ALTITUDE_km,
        COUNT(*) AS NUMBER_OF_SAMPLES
    FROM LIGHTNING_MEASUREMENTS
    WHERE EVENT_ID = %s
    GROUP BY OBSERVATION_ALTITUDE_km
    ORDER BY OBSERVATION_ALTITUDE_km
    """,
    (EVENT_ID,)
)


altitude_results = cursor.fetchall()


print("\nSamples by observation altitude:")


for altitude_result in altitude_results:

    print(
        f"Altitude = "
        f"{altitude_result[0]} km, "
        f"Samples = "
        f"{altitude_result[1]:,}"
    )


# ============================================================
# 21. DISPLAY FIRST 5 MEASUREMENTS
# ============================================================

cursor.execute(
    """
    SELECT
        MEASUREMENT_ID,
        EVENT_ID,
        OBSERVATION_ALTITUDE_km,
        TIME_us,
        E_FIELD_V_m,
        H_FIELD_A_m
    FROM LIGHTNING_MEASUREMENTS
    WHERE EVENT_ID = %s
    ORDER BY MEASUREMENT_ID
    LIMIT 5
    """,
    (EVENT_ID,)
)


measurement_results = cursor.fetchall()


print("\n========================================")
print("       FIRST 5 MEASUREMENTS")
print("========================================")


for measurement in measurement_results:

    print(measurement)


# ============================================================
# 22. DISPLAY LAST 5 MEASUREMENTS
# ============================================================

cursor.execute(
    """
    SELECT
        MEASUREMENT_ID,
        EVENT_ID,
        OBSERVATION_ALTITUDE_km,
        TIME_us,
        E_FIELD_V_m,
        H_FIELD_A_m
    FROM LIGHTNING_MEASUREMENTS
    WHERE EVENT_ID = %s
    ORDER BY MEASUREMENT_ID DESC
    LIMIT 5
    """
    ,
    (EVENT_ID,)
)


last_measurements = cursor.fetchall()


print("\n========================================")
print("       LAST 5 MEASUREMENTS")
print("========================================")


for measurement in last_measurements:

    print(measurement)


# ============================================================
# 23. CLOSE MYSQL CONNECTION
# ============================================================

cursor.close()

connect.close()



print("\n========================================")
print("       SYNCHRONIZATION COMPLETE")
print("========================================")

print(
    f"\nTotal CSV records processed = {total_records:,}"
)

print(f"EVENT_ID = {EVENT_ID}")
print(f"CHANNEL_ID = {CHANNEL_ID}")

print("MySQL connection closed.")
print("Program finished successfully.")