-- =================================================================
-- 2단계: 2_to_activity.sql (활동 테이블로 분리 및 필터링)
-- =================================================================

/*
Split edstays to Activity 
- Enter the ED
- Discharge from the ED
*/

DROP TABLE IF EXISTS "mimic_insights"."ed_edstays_activity_enter";
SELECT subject_id, stay_id, hadm_id, intime AS timestamps, 'Enter the ED' AS activity, gender, race, arrival_transport,  NULL AS disposition
INTO TABLE "mimic_insights"."ed_edstays_activity_enter"
FROM "edstays" -- 원본: "mimiciv_ed"."edstays" -> "edstays"로 수정
ORDER BY stay_id;

DROP TABLE IF EXISTS "mimic_insights"."ed_edstays_activity_discharge";
SELECT subject_id, stay_id, hadm_id, outtime AS timestamps, 'Discharge from the ED' AS activity, NULL AS gender, NULL AS race, NULL AS arrival_transport, disposition
INTO TABLE "mimic_insights"."ed_edstays_activity_discharge"
FROM "edstays" -- 원본: "mimiciv_ed"."edstays" -> "edstays"로 수정
ORDER BY stay_id;


/*
Add diagnosis table to discharge
*/

DROP TABLE IF EXISTS "mimic_insights"."ed_edstays_activity_with_diagnosis";

-- Enter the ED 이벤트 (Diagnosis 속성 NULL)
SELECT *, NULL AS seq_num, NULL AS icd_code, NULL AS icd_version, NULL AS icd_title
INTO TABLE "mimic_insights"."ed_edstays_activity_with_diagnosis"
FROM "mimic_insights"."ed_edstays_activity_enter"

UNION ALL

-- Discharge from the ED 이벤트 (Diagnosis 속성은 seq_num=1인 대표 정보만 JOIN)
SELECT dis.*, CAST(dia.seq_num AS text), dia.icd_code, CAST(dia.icd_version AS text), dia.icd_title
FROM "mimic_insights"."ed_edstays_activity_discharge" dis
LEFT JOIN "diagnosis" dia -- 스키마 경로 제거
    ON dis.stay_id = dia.stay_id
WHERE dia.seq_num = 1 OR dia.seq_num IS NULL -- <<< 핵심 수정: seq_num=1 이거나, 진단 정보가 없는 경우(NULL)만 선택

ORDER BY stay_id, timestamps, seq_num;

/*
Add activity to triage (Triage in the ED)
*/

DROP TABLE IF EXISTS "mimic_insights"."ed_triage_activity";
SELECT 
    e.stay_id, 
    e.subject_id, 
    -- intime 컬럼을 timestamp 타입으로 명시적 형 변환 후 interval을 더함
    (e.intime::timestamp + interval '1' second) AS timestamps, 
    'Triage in the ED' AS activity, 
    temperature, 
    heartrate, 
    resprate, 
    o2sat, 
    sbp, 
    dbp, 
    pain, 
    acuity, 
    chiefcomplaint
INTO TABLE "mimic_insights"."ed_triage_activity"
FROM "triage" t
INNER JOIN "edstays" e
    ON e.stay_id = t.stay_id;


/*
Add activity to vitalsign (Vital sign check)
*/

DROP TABLE IF EXISTS "mimic_insights"."ed_vitalsign_activity";
SELECT e.stay_id, e.subject_id, charttime AS timestamps, 'Vital sign check' AS activity, 
    temperature, heartrate, resprate, o2sat, sbp, dbp, pain, rhythm
INTO TABLE "mimic_insights"."ed_vitalsign_activity"
FROM "vitalsign" v -- 원본: "mimiciv_ed"."vitalsign" -> "vitalsign"로 수정
INNER JOIN "edstays" e -- 원본: "mimiciv_ed"."edstays" -> "edstays"로 수정
    ON e.stay_id = v.stay_id;

-- Delete any activity along with or after discharge 
DELETE FROM "mimic_insights"."ed_vitalsign_activity" v
WHERE EXISTS
    (SELECT 1 FROM "mimic_insights"."ed_edstays_activity_discharge" d
    WHERE v.stay_id = d.stay_id AND v.timestamps >= d.timestamps);

/*
Add activity to medrecon (Medicine reconciliation)
*/

DROP TABLE IF EXISTS "mimic_insights"."ed_medrecon_activity";
SELECT e.stay_id, e.subject_id, charttime AS timestamps, 'Medicine reconciliation' AS activity,
    name, gsn, ndc, etc_rn, etccode, etcdescription
INTO TABLE "mimic_insights"."ed_medrecon_activity"
FROM "medrecon" m -- 원본: "mimiciv_ed"."medrecon" -> "medrecon"로 수정
INNER JOIN "edstays" e -- 원본: "mimiciv_ed"."edstays" -> "edstays"로 수정
    ON e.stay_id = m.stay_id;

-- Delete any activity along with or after discharge 
DELETE FROM "mimic_insights"."ed_medrecon_activity" m
WHERE EXISTS
    (SELECT 1 FROM "mimic_insights"."ed_edstays_activity_discharge" d
    WHERE m.stay_id = d.stay_id AND m.timestamps >= d.timestamps);

/*
Add activity to pyxis (Medicine dispensations)
*/

DROP TABLE IF EXISTS "mimic_insights"."ed_pyxis_activity";
SELECT e.stay_id, e.subject_id, charttime AS timestamps, 'Medicine dispensations' AS activity,
    name, gsn, med_rn, gsn_rn
INTO TABLE "mimic_insights"."ed_pyxis_activity"
FROM "pyxis" p -- 원본: "mimiciv_ed"."pyxis" -> "pyxis"로 수정
INNER JOIN "edstays" e -- 원본: "mimiciv_ed"."edstays" -> "edstays"로 수정
    ON e.stay_id = p.stay_id;

-- Delete any activity along with or after discharge 
DELETE FROM "mimic_insights"."ed_pyxis_activity" p
WHERE EXISTS
    (SELECT 1 FROM "mimic_insights"."ed_edstays_activity_discharge" d
    WHERE p.stay_id = d.stay_id AND p.timestamps >= d.timestamps);