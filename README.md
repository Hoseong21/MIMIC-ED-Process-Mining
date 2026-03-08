# MIMIC-ED Process Mining
### Reproducing & Extending MIMICEL: Event Log-based Process Analysis of Emergency Department Patient Flow

MIMIC-IV-ED 데이터를 기반으로 응급실 환자 여정을 이벤트 로그로 재구성하고, 프로세스 마이닝 기법으로 진료 흐름과 병목 구간을 분석한 프로젝트입니다.

<br>

## 📌 Project Info

| **Period** | 2025.10.01 – 2025.11.30 |
|---|---|
| **Type** | 데이터애널리틱스 개인과제 |
| **Data** | MIMIC-IV-ED v2.2 |
| **Reference** | Wei et al., *MIMICEL* (arXiv:2505.19389, 2025) |

<br>

## 📖 Overview

본 프로젝트는 **MIMIC-IV-ED 데이터셋**을 활용하여 응급실 환자 여정을 이벤트 로그로 재구성하고, 프로세스 마이닝 기법으로 실제 진료 흐름·병목·혼잡 패턴을 분석한 개인 프로젝트입니다.

응급실 과부하(ED Overcrowding)는 전 세계적으로 심각한 문제이며, 국내에서도 중증 환자가 여러 병원을 전전하는 이른바 '응급실 뺑뺑이' 현상이 빈번히 발생하고 있습니다. 기존 머신러닝 기반 예측 모델과 달리, 본 프로젝트는 응급실 내부 과정 자체를 프로세스 마이닝 기법으로 해석하여 실제 진료 흐름과 병목 구간을 데이터 기반으로 규명하고자 하였습니다.

원 논문(MIMICEL)의 이벤트 로그 생성 절차를 PostgreSQL로 직접 재현하고, 원 논문이 수행하지 않은 **Process Discovery(Alpha / Heuristic / Inductive Miner)** 와 **Conformance Checking** 을 추가로 적용하여 프로세스 모델의 구조적 타당성을 검증하였습니다.

<br>

## ✨ Key Contributions

- MIMIC-IV-ED 6개 테이블을 PostgreSQL로 직접 파이프라이닝하여 **425,028 케이스 / 7,164,612 이벤트** 규모의 이벤트 로그를 재현하였습니다.
- 원 논문에서 다루지 않은 **Alpha / Heuristic / Inductive Miner** 세 가지 Process Discovery 알고리즘을 순차 적용하여 ED 프로세스 모델을 도출하였습니다.
- **Token Replay 및 Alignment 기반 Conformance Checking** 을 수행하여 Inductive Miner가 Fitness 1.0을 달성함을 확인하였습니다.
- Acuity / LoS / Crowdedness 기반의 코호트 분할 분석을 재현하고, Disco 툴을 활용한 프로세스 맵 시각화를 통해 원 논문 결과를 정량적으로 검증하였습니다.

<br>

## 🗂 Dataset

**Database** : MIMIC-IV-ED (v2.2)

**Population Criteria**
- ED 방문 케이스(stay_id) 전체 포함
- 유효하지 않은 케이스 제거 (intime ≥ outtime)
- ED 도착 이전 발생 이벤트 제외

**Tables Used**

| Table | Description |
|---|---|
| `edstays` | ED 방문 정보 (입퇴실 시각, 환자 정보) |
| `triage` | 중증도 분류 기록 |
| `vitalsign` | 생체 신호 측정 기록 |
| `medrecon` | 약물 조정 기록 |
| `pyxis` | 약물 투여 기록 |
| `diagnosis` | 진단 기록 |

**Final Cohort : 205,466 patients / 425,028 cases / 7,164,612 events**

<br>

## ⚙️ Event Log Construction Pipeline

원 논문의 9단계 이벤트 로그 구축 가이드라인(Jans et al., 2019)을 따라 아래 4단계로 파이프라인을 구성하였습니다.

| Step | Script | Description |
|---|---|---|
| 1 | `1_preprocessing.sql` | 스키마 생성 및 고유 ED ID 추출 |
| 2 | `2_to_activity.sql` | 6개 Activity 테이블 변환 및 1차 필터링 |
| 3 | `3_to_event_log.sql` | 전체 Activity 결합 및 이벤트 로그 생성 |
| 4 | `4_clean.sql` | 유효하지 않은 케이스 최종 제거 |

**Activity Definitions**

| Activity | Source | Timestamp |
|---|---|---|
| Enter the ED | edstays | `intime` |
| Triage in the ED | triage (via edstays) | `intime + 1 sec` |
| Vital sign check | vitalsign | `charttime` |
| Medicine reconciliation | medrecon | `charttime` |
| Medicine dispensations | pyxis | `charttime` |
| Discharge from the ED | edstays + diagnosis | `outtime` |

> triage 테이블에 독립적인 타임스탬프가 없어, 원 논문 방식에 따라 `intime + 1초`를 인위적으로 부여하였습니다.

<br>

## 📊 Results

### 1. 이벤트 로그 재현 결과

| Metric | 재현 결과 | 원 논문 |
|---|---|---|
| Patients (subject_id) | 205,466 | 205,466 ✅ |
| Cases (stay_id) | 425,028 | 425,028 ✅ |
| Events | 7,164,612 | 7,568,824 |
| Activity Types | 6 | 6 ✅ |

> 이벤트 수 약 40만 건 차이는 MIMIC-IV-ED 데이터셋 버전 차이(v2.2)에 기인한 것으로 추정됩니다.

<br>

### 2. Process Discovery & Conformance Checking

| Miner | Token Replay Fitness | Alignment Fitness |
|---|---|---|
| Alpha Miner | 0.33 | 0.33 |
| Heuristic Miner | 0.92 | 0.91 |
| **Inductive Miner** | **1.00** | **1.00** |

- **Alpha Miner** : Enter → Triage → Discharge 핵심 경로를 포착하나 반복·병렬 패턴 처리에 한계
- **Heuristic Miner** : 스파게티 모델 형태로 실제 응급실 프로세스의 높은 경로 변동성을 반영
- **Inductive Miner** : Fitness 1.0 달성, Enter → Triage → 병렬 처치 → Discharge의 표준 흐름을 계층적으로 표현

<br>

### 3. 주요 분석 인사이트

**Acuity 기반 분석**
- 고중증(Acuity 1) 환자는 Vital sign check 연속 발생 비율 73.5%, 체크 간격 중앙값 30분 / 저중증(Acuity 5)은 17.6%가 Triage 직후 바로 퇴원
- 중증도가 높을수록 약물 투여와 활력징후 모니터링이 짧은 간격으로 반복되는 집중 처치 사이클이 형성됨
- → **의료진이 핵심 진료 흐름(Enter → Triage → Discharge)을 안정적으로 유지하면서, 환자 상태에 따라 병렬 처치를 유연하게 병행하고 있음을 확인**

**LoS 기반 분석**
- 전체 케이스의 75%는 LoS 500분 이하 / 장기체류(Q4) 환자는 정상체류(Q1) 대비 Vital sign check 자가 루프 비율이 30%p 높음
- 귀가 코호트는 입원 코호트보다 활동 간 전환이 느리고 모니터링 간격이 길게 나타남
- → **응급실 체류 지연의 병목 구간은 처치 자체의 복잡도보다, 퇴원 가능 여부를 확인하기 위한 반복적 관찰 과정에서 발생함을 규명**

**혼잡도(Crowdedness) 분석**
- 혼잡 ED(동시 치료 환자 ≥12명)에서 입원 코호트 비율이 비혼잡 대비 유의미하게 높음
- 혼잡 상황에서도 고위험 환자의 Vital sign check 간격은 저위험 환자 대비 짧게 유지됨
- → **자원이 제한된 혼잡 환경에서도 환자 안전을 우선시하는 임상 판단이 실제 프로세스에 반영되고 있으며, 이는 응급실 운영의 구조적 탄력성을 시사**

<br>

## 🗃 Project Structure

```
MIMIC-ED-Process-Mining/
├── SQL/
│   ├── create_table.sql
│   ├── copy_table.sql
│   ├── 1_preprocessing.sql
│   ├── 2_to_activity.sql
│   ├── 3_to_event_log.sql
│   └── 4_clean.sql
├── python code/
│   ├── individual_project_DA.ipynb
│   └── process_discovery_and_conformance_checking_DA.ipynb
├── requirements_local.txt
├── requirements_colab.txt
├── report.pdf
└── README.md
```

<br>

## 🛠 Tech Stack

**Database** : PostgreSQL

**Core** : Python · pandas · PM4Py

**Process Mining** : PM4Py (Alpha / Heuristic / Inductive Miner, Token Replay, Alignment)

**Visualization** : Graphviz · Disco (Fluxicon)