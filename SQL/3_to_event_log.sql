-- =================================================================
-- 3단계: 3_to_eventlog.sql (모든 활동 결합 및 CSV로 내보내기)
-- =================================================================

/*
Combine all activity tables into one event log
*/

-- 1. 이전 테이블이 있다면 삭제
DROP TABLE IF EXISTS "mimic_insights"."ed_tables";

-- 2. 첫 번째 활동 테이블(edstay)을 사용하여 최종 테이블을 생성하고 스키마를 확정합니다.
-- 이 과정에서 모든 컬럼 타입을 명시적으로 지정합니다.
SELECT 
    fc.stay_id, st.subject_id, fc.hadm_id, 
    st.timestamps::timestamp AS timestamps, 
    st.activity, 
    st.gender, st.race, st.arrival_transport, st.disposition,
    st.seq_num::text AS seq_num, st.icd_code, st.icd_version::text AS icd_version, st.icd_title,
    NULL::text AS temperature, NULL::text AS heartrate, NULL::text AS resprate, NULL::text AS o2sat, NULL::text AS sbp, NULL::text AS dbp, NULL::text AS pain, NULL::text AS acuity, 
    NULL::text AS chiefcomplaint, 
    NULL::text AS rhythm,        
    NULL::text AS name, NULL::text AS gsn, NULL::text AS ndc, NULL::text AS etc_rn, NULL::text AS etccode, NULL::text AS etcdescription,
    NULL::text AS med_rn, NULL::text AS gsn_rn
INTO "mimic_insights"."ed_tables" -- INTO로 테이블 생성 및 스키마 고정
FROM "mimic_insights"."ed_ids" fc
INNER JOIN "mimic_insights"."ed_edstays_activity_with_diagnosis" st
    ON fc.stay_id = st.stay_id
ORDER BY stay_id, timestamps; -- 생성 시 정렬은 필수 아님 (후에 삽입하므로)


-- 3. 나머지 활동 테이블의 데이터를 생성된 "ed_tables"에 안전하게 삽입합니다.

-- Triage 데이터 삽입
INSERT INTO "mimic_insights"."ed_tables"
SELECT 
    fc.stay_id, tr.subject_id, fc.hadm_id, 
    tr.timestamps::timestamp, 
    tr.activity, 
    NULL, NULL, NULL, NULL, -- gender, race, transport, disposition
    NULL, NULL, NULL, NULL, -- seq_num, icd_code, icd_version, icd_title
    CAST(tr.temperature AS text), CAST(tr.heartrate AS text), CAST(tr.resprate AS text), CAST(tr.o2sat AS text), CAST(tr.sbp AS text), CAST(tr.dbp AS text), CAST(tr.pain AS text), CAST(tr.acuity AS text), 
    tr.chiefcomplaint::text,
    NULL, -- rhythm
    NULL, NULL, NULL, NULL, NULL, NULL, -- name, gsn, ndc, etc_rn, etccode, etcdescription
    NULL, NULL -- med_rn, gsn_rn
FROM "mimic_insights"."ed_ids" fc
INNER JOIN "mimic_insights"."ed_triage_activity" tr
    ON fc.stay_id = tr.stay_id;

-- Vitalsign 데이터 삽입
INSERT INTO "mimic_insights"."ed_tables"
SELECT 
    fc.stay_id, vt.subject_id, fc.hadm_id, 
    vt.timestamps::timestamp, 
    vt.activity, 
    NULL, NULL, NULL, NULL, 
    NULL, NULL, NULL, NULL, 
    CAST(vt.temperature AS text), CAST(vt.heartrate AS text), CAST(vt.resprate AS text), CAST(vt.o2sat AS text), CAST(vt.sbp AS text), CAST(vt.dbp AS text), CAST(vt.pain AS text), 
    NULL, NULL, -- acuity, chiefcomplaint
    vt.rhythm::text,
    NULL, NULL, NULL, NULL, NULL, NULL, 
    NULL, NULL
FROM "mimic_insights"."ed_ids" fc
INNER JOIN "mimic_insights"."ed_vitalsign_activity" vt
    ON fc.stay_id = vt.stay_id;

-- Medrecon 데이터 삽입
INSERT INTO "mimic_insights"."ed_tables"
SELECT 
    fc.stay_id, med.subject_id, fc.hadm_id, 
    med.timestamps::timestamp, 
    med.activity, 
    NULL, NULL, NULL, NULL, 
    NULL, NULL, NULL, NULL, 
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, -- temperature to acuity + chiefcomplaint
    NULL, -- rhythm
    med.name, med.gsn, med.ndc, med.etc_rn::text, med.etccode, med.etcdescription,
    NULL, NULL
FROM "mimic_insights"."ed_ids" fc
INNER JOIN "mimic_insights"."ed_medrecon_activity" med
    ON fc.stay_id = med.stay_id;

-- Pyxis 데이터 삽입
INSERT INTO "mimic_insights"."ed_tables"
SELECT 
    fc.stay_id, py.subject_id, fc.hadm_id, 
    py.timestamps::timestamp, 
    py.activity, 
    NULL, NULL, NULL, NULL, 
    NULL, NULL, NULL, NULL, 
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, -- temperature to acuity + chiefcomplaint
    NULL, -- rhythm
    py.name, py.gsn, NULL, NULL, NULL, NULL, -- ndc, etc_rn, etccode, etcdescription
    py.med_rn::text, py.gsn_rn::text
FROM "mimic_insights"."ed_ids" fc
INNER JOIN "mimic_insights"."ed_pyxis_activity" py
    ON fc.stay_id = py.stay_id;


-- 4. 최종적으로 stay_id와 timestamps 기준으로 정렬하여 이벤트 로그 완성
-- (INSERT 후 정렬을 보장하려면 CLUSTER 또는 최종 SELECT 사용)
-- 간단한 ORDER BY로 결과를 볼 때는 문제가 없으나, 최종 로그를 확정하려면 아래 명령을 사용합니다.
DROP TABLE IF EXISTS "mimic_insights"."ed_eventlog_final";
CREATE TABLE "mimic_insights"."ed_eventlog_final" AS
SELECT *
FROM "mimic_insights"."ed_tables"
ORDER BY stay_id, timestamps;

-- 생성된 테이블의 통계 확인
SELECT 
    COUNT(DISTINCT stay_id) AS "최종_케이스_수_Cases",
    COUNT(*) AS "최종_이벤트_수_Events"
FROM "mimic_insights"."ed_eventlog_final";

-- 기본 통계량 확인
SELECT 
    -- 1. 케이스 수 (stay_id의 고유값 수)
    COUNT(DISTINCT stay_id) AS "1. Number of Cases (STAY ID)",
    
    -- 2. 이벤트 수 (전체 행 수)
    COUNT(*) AS "2. Number of Events (ROWS)",
    
    -- 3. 고유 활동 수 (activity의 고유값 수)
    COUNT(DISTINCT activity) AS "3. Number of Unique Activities"
FROM "mimic_insights"."ed_eventlog_final";

--고유한 환자(subject_id)의 총 수
SELECT 
    COUNT(DISTINCT subject_id) AS "Total Number of Unique Patients (subject_id)"
FROM "mimic_insights"."ed_ids";

-- 케이스별 이벤트 수 통계
WITH EventsPerCase AS (
    -- 각 stay_id별 이벤트 수 계산
    SELECT stay_id, COUNT(*) AS event_count
    FROM "mimic_insights"."ed_eventlog_final"
    GROUP BY stay_id
)
SELECT 
    MIN(event_count) AS "Min Events per Case",
    MAX(event_count) AS "Max Events per Case",
    -- 평균 이벤트 수 (소수점 둘째 자리까지 반올림)
    ROUND(AVG(event_count)::numeric, 2) AS "Average Events per Case", 
    -- 중앙값 (Median)
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY event_count) AS "Median Events per Case"
FROM EventsPerCase;

-- 케이스 기간 통계
WITH CaseDurations AS (
    -- 각 stay_id별 (최대 타임스탬프 - 최소 타임스탬프)로 기간 계산
    SELECT 
        stay_id,
        MAX(timestamps) - MIN(timestamps) AS duration
    FROM "mimic_insights"."ed_eventlog_final"
    GROUP BY stay_id
)
SELECT 
    MIN(duration) AS "Min Case Duration (INTERVAL)",
    MAX(duration) AS "Max Case Duration (INTERVAL)",
    -- PostgreSQL의 INTERVAL 타입은 AVG 계산 시 복잡하므로, 결과를 INTERVAL 타입 그대로 출력합니다.
    AVG(duration) AS "Average Case Duration (INTERVAL)", 
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duration) AS "Median Case Duration (INTERVAL)"
FROM CaseDurations;