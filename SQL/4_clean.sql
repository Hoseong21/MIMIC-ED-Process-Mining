/*
4. MIMICEL 이벤트 로그 정리 (Rule 1: intime < outtime) - 명시적 TIMESTAMP 캐스팅 적용
*/

DROP TABLE IF EXISTS "mimic_insights"."ed_eventlog_final_clean";

SELECT * INTO "mimic_insights"."ed_eventlog_final_clean"
FROM "mimic_insights"."ed_eventlog_final" -- 정제 전 최종 이벤트 로그
WHERE stay_id IN (
    SELECT stay_id
    FROM "edstays" -- <<<< 스키마 경로 제거 및 테이블 이름만 사용
    WHERE intime IS NOT NULL 
      AND outtime IS NOT NULL 
      -- intime과 outtime을 명시적으로 TIMESTAMP 타입으로 변환하여 비교
      AND intime::timestamp < outtime::timestamp 
)
ORDER BY stay_id, timestamps;

-- 최종 케이스, 이벤트 수 확인
SELECT 
    COUNT(DISTINCT stay_id) AS "최종_정제_케이스_수_Cases",
    COUNT(*) AS "최종_정제_이벤트_수_Events"
FROM "mimic_insights"."ed_eventlog_final_clean";

-- 최종 검증 쿼리: 시작 및 종료 이벤트 수
SELECT 
    activity,
    COUNT(*) AS "이벤트_수"
FROM "mimic_insights"."ed_eventlog_final_clean"
WHERE activity IN ('Enter the ED', 'Discharge from the ED')
GROUP BY activity;

-- 1. 기본 통계량 (Cases, Events, Activities)
SELECT 
    COUNT(DISTINCT subject_id) AS "1. Unique_Patients_subject_id",
    COUNT(DISTINCT stay_id) AS "2. Unique_Cases_stay_id",
    COUNT(*) AS "3. Total_Events_ROWS",
    COUNT(DISTINCT activity) AS "4. Unique_Activities"
FROM "mimic_insights"."ed_eventlog_final_clean";

-- 2. 케이스별 이벤트 수 통계 (Events per Case)
WITH EventsPerCase AS (
    SELECT stay_id, COUNT(*) AS event_count
    FROM "mimic_insights"."ed_eventlog_final_clean"
    GROUP BY stay_id
)
SELECT 
    MIN(event_count) AS "Min_Events_per_Case",
    MAX(event_count) AS "Max_Events_per_Case",
    ROUND(AVG(event_count)::numeric, 2) AS "Average_Events_per_Case", 
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY event_count) AS "Median_Events_per_Case"
FROM EventsPerCase;

-- 3. 케이스 기간 통계 (Case Duration)
WITH CaseDurations AS (
    SELECT 
        stay_id,
        MAX(timestamps) - MIN(timestamps) AS duration
    FROM "mimic_insights"."ed_eventlog_final_clean"
    GROUP BY stay_id
)
SELECT 
    MIN(duration) AS "Min_Case_Duration",
    MAX(duration) AS "Max_Case_Duration",
    AVG(duration) AS "Average_Case_Duration", 
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duration) AS "Median_Case_Duration"
FROM CaseDurations;