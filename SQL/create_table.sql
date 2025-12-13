/* diagnosis */
CREATE TABLE diagnosis (
    subject_id    INTEGER,
    stay_id       INTEGER,
    seq_num       INTEGER,
    icd_code      TEXT,
    icd_version   INTEGER,
    icd_title     TEXT
);

/* edstays */
CREATE TABLE edstays (
    subject_id         INTEGER,
    hadm_id            REAL,
    stay_id            INTEGER,
    intime             TEXT,
    outtime            TEXT,
    gender             TEXT,
    race               TEXT,
    arrival_transport  TEXT,
    disposition        TEXT
);

/* medrecon */
CREATE TABLE medrecon (
    subject_id      INTEGER,
    stay_id         INTEGER,
    charttime       TEXT,
    name            TEXT,
    gsn             TEXT,
    ndc             TEXT,
    etc_rn          INTEGER,
    etccode         REAL,
    etcdescription  TEXT
);

/* pyxis */
CREATE TABLE pyxis (
    subject_id  INTEGER,
    stay_id     INTEGER,
    charttime   TEXT,
    med_rn      INTEGER,
    name        TEXT,
    gsn_rn      INTEGER,
    gsn         REAL
);

/* triage */
CREATE TABLE triage (
    subject_id      INTEGER,
    stay_id         INTEGER,
    temperature     REAL,
    heartrate       REAL,
    resprate        REAL,
    o2sat           REAL,
    sbp             REAL,
    dbp             REAL,
    pain            TEXT,
    acuity          REAL,
    chiefcomplaint  TEXT
);

/* vitalsign */
CREATE TABLE vitalsign (
    subject_id   INTEGER,
    stay_id      INTEGER,
    charttime    TEXT,
    temperature  REAL,
    heartrate    REAL,
    resprate     REAL,
    o2sat        REAL,
    sbp          REAL,
    dbp          REAL,
    rhythm       TEXT,
    pain         TEXT
);