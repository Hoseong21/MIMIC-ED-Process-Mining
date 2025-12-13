-- =================================================================
-- 1단계: 1_preprocessing.sql (스키마 생성 및 ED ID 추출)
-- =================================================================

-- 1. 결과 스키마 생성
CREATE SCHEMA IF NOT EXISTS "mimic_insights";

/*
Extract three id in ed tables
*/
-- 2. 모든 고유 ED ID (subject_id, hadm_id, stay_id) 추출
DROP TABLE IF EXISTS "mimic_insights"."ed_ids";
SELECT DISTINCT subject_id, hadm_id, stay_id
INTO TABLE "mimic_insights"."ed_ids"
FROM "edstays"; -- 원본: "mimiciv_ed"."edstays" -> "edstays"로 수정