# Lightning EMF Simulation Analysis Database

A relational MySQL database project for organizing lightning observations, channel geometry, atmospheric conditions, and electromagnetic field measurements, with applications to scientific data analysis and lightning electromagnetic field (EMF) research.

## 1. Project Overview

Lightning observations involve multiple types of information, including observation-site coordinates, lightning event characteristics, channel geometry, atmospheric conditions, and measured electromagnetic fields. Organizing these data in a consistent structure is important for querying observations and preparing datasets for scientific analysis.

This project implements a relational database named `LIGHTNING` using MySQL. It consists of six interconnected tables designed to store lightning-related information and maintain relationships between records using primary keys and foreign keys.

SQL is used for database creation, data insertion, schema modification, and relationship verification. Python complements the broader scientific workflow through numerical computation, data processing, visualization, and analysis of lightning-related data.

The repository primarily documents the database implementation and its SQL operations. It provides a foundation for organizing scientific observations and supporting further analysis of lightning electromagnetic fields.

## 2. Project Objectives

- Design and implement a relational database for lightning-related scientific data.
- Organize observation stations, lightning events, channel geometry, atmospheric conditions, and electromagnetic field measurements.
- Establish primary-key and foreign-key relationships between related records.
- Use appropriate data types and integrity constraints.
- Populate the database with structured records.
- Develop SQL queries to retrieve information and examine database relationships.
- Document database structure, query results, and verification procedures.
- Support subsequent scientific data processing and analysis using Python.

## 3. Technologies Used

| Technology | Purpose |
|---|---|
| MySQL | Relational database management and data storage |
| SQL | Database definition, record insertion, schema modification, and querying |
| Python | Scientific data processing, numerical computation, analysis, and visualization in the broader research workflow |
| Git and GitHub | Version control, project documentation, and code sharing |

## 4. Database Schema

The `LIGHTNING` database contains six tables.

| Table | Primary key | Description |
|---|---|---|
| `OBSERVATION_STATIONS` | `STATION_ID` | Stores observation station names, geographic coordinates, station elevation, and country. |
| `LIGHTNING_EVENTS` | `EVENT_ID` | Stores event timestamps, lightning classifications, peak current, and duration, along with the associated station ID. |
| `LIGHTNING_CHANNELS` | `CHANNEL_ID` | Stores channel classification, length, propagation velocity, and peak current associated with a lightning event. |
| `CHANNEL_POINTS` | `CHANNEL_POINT_ID` | Stores channel point indices, spatial coordinates, and segment lengths. |
| `LIGHTNING_MEASUREMENTS` | `MEASUREMENT_ID` | Stores observation altitude, electric-field values, magnetic-field values, and frequency associated with an event. |
