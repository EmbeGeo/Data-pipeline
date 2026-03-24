-- ============================================================
--  산업 장비 계기판 OCR 데이터 스키마
--  DB      : MySQL 8.0+ / MariaDB 10.5+
--  수집 주기: 실시간 (초 단위 이하)
--  생성일  : 2026-03-24
-- ============================================================

-- 파티셔닝을 위해 recorded_at을 PK에 포함시킵니다
-- AUTO_INCREMENT와 파티셔닝을 함께 쓰려면 PK가 파티션 키를 포함해야 합니다

CREATE TABLE gauge_readings (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    recorded_at     DATETIME(3)     NOT NULL,               -- 밀리초 단위까지 저장

    -- ISO 원액
    iso_temp_pv     DECIMAL(5,1)    NULL,                   -- °C  계기판 위쪽
    iso_temp_sv     DECIMAL(5,1)    NULL,                   -- °C  계기판 아래쪽
    iso_pump_speed  INT             NULL,                   -- RPM/Hz
    iso_press       DECIMAL(5,2)    NULL,                   -- bar

    -- POL1 원액
    pol1_temp_pv    DECIMAL(5,1)    NULL,
    pol1_temp_sv    DECIMAL(5,1)    NULL,
    pol1_pump_speed INT             NULL,
    pol1_press      DECIMAL(5,2)    NULL,

    -- POL2 원액
    pol2_temp_pv    DECIMAL(5,1)    NULL,
    pol2_temp_sv    DECIMAL(5,1)    NULL,
    pol2_pump_speed INT             NULL,
    pol2_press      DECIMAL(5,2)    NULL,

    -- 온수
    hot_water_temp_pv DECIMAL(5,1)  NULL,
    hot_water_temp_sv DECIMAL(5,1)  NULL,

    PRIMARY KEY (id, recorded_at)   -- 파티셔닝을 위해 recorded_at 포함
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
-- -------------------------------------------------------
--  파티셔닝: 월 단위로 자동 분할
--  초 단위 수집 시 하루 86,400행 → 월 ~260만 행
--  파티션 없이 운영하면 1년 후 조회 성능 급락
-- -------------------------------------------------------
PARTITION BY RANGE (TO_DAYS(recorded_at)) (
    PARTITION p2026_01 VALUES LESS THAN (TO_DAYS('2026-02-01')),
    PARTITION p2026_02 VALUES LESS THAN (TO_DAYS('2026-03-01')),
    PARTITION p2026_03 VALUES LESS THAN (TO_DAYS('2026-04-01')),
    PARTITION p2026_04 VALUES LESS THAN (TO_DAYS('2026-05-01')),
    PARTITION p2026_05 VALUES LESS THAN (TO_DAYS('2026-06-01')),
    PARTITION p2026_06 VALUES LESS THAN (TO_DAYS('2026-07-01')),
    PARTITION p2026_07 VALUES LESS THAN (TO_DAYS('2026-08-01')),
    PARTITION p2026_08 VALUES LESS THAN (TO_DAYS('2026-09-01')),
    PARTITION p2026_09 VALUES LESS THAN (TO_DAYS('2026-10-01')),
    PARTITION p2026_10 VALUES LESS THAN (TO_DAYS('2026-11-01')),
    PARTITION p2026_11 VALUES LESS THAN (TO_DAYS('2026-12-01')),
    PARTITION p2026_12 VALUES LESS THAN (TO_DAYS('2027-01-01')),
    PARTITION p_future  VALUES LESS THAN MAXVALUE
);

-- -------------------------------------------------------
--  인덱스: 시간 범위 조회 최적화
--  PK에 recorded_at이 포함되어 있어 별도 인덱스 최소화
-- -------------------------------------------------------
CREATE INDEX idx_recorded_at ON gauge_readings (recorded_at DESC);


-- ============================================================
--  OCR 오류 레코드 테이블
--  OCR 필터링에서 폐기된 데이터 보관 (재학습 데이터 확보)
-- ============================================================
CREATE TABLE ocr_errors (
    id           BIGINT          NOT NULL AUTO_INCREMENT,
    logged_at    DATETIME(3)     NOT NULL,
    field        VARCHAR(50)     NOT NULL,                  -- 컬럼명 (예: iso_temp_pv)
    raw_text     VARCHAR(100),                              -- OCR 원본 문자열
    error_type   ENUM(
                   'PARSE_FAIL',
                   'LOW_CONFIDENCE',
                   'OUT_OF_RANGE',
                   'ANOMALY'
                 ) NOT NULL,
    error_detail VARCHAR(255),
    confidence   FLOAT,

    PRIMARY KEY (id, logged_at)
)
ENGINE = InnoDB
DEFAULT CHARSET = utf8mb4
PARTITION BY RANGE (TO_DAYS(logged_at)) (
    PARTITION pe2026_01 VALUES LESS THAN (TO_DAYS('2026-02-01')),
    PARTITION pe2026_02 VALUES LESS THAN (TO_DAYS('2026-03-01')),
    PARTITION pe2026_03 VALUES LESS THAN (TO_DAYS('2026-04-01')),
    PARTITION pe2026_04 VALUES LESS THAN (TO_DAYS('2026-05-01')),
    PARTITION pe2026_05 VALUES LESS THAN (TO_DAYS('2026-06-01')),
    PARTITION pe2026_06 VALUES LESS THAN (TO_DAYS('2026-07-01')),
    PARTITION pe2026_07 VALUES LESS THAN (TO_DAYS('2026-08-01')),
    PARTITION pe2026_08 VALUES LESS THAN (TO_DAYS('2026-09-01')),
    PARTITION pe2026_09 VALUES LESS THAN (TO_DAYS('2026-10-01')),
    PARTITION pe2026_10 VALUES LESS THAN (TO_DAYS('2026-11-01')),
    PARTITION pe2026_11 VALUES LESS THAN (TO_DAYS('2026-12-01')),
    PARTITION pe2026_12 VALUES LESS THAN (TO_DAYS('2027-01-01')),
    PARTITION pe_future  VALUES LESS THAN MAXVALUE
);


-- ============================================================
--  파티션 월별 추가 프로시저 (매월 말 실행)
--  예: CALL add_monthly_partition('2027', '02');
-- ============================================================
DELIMITER $$
CREATE PROCEDURE add_monthly_partition(IN yr CHAR(4), IN mo CHAR(2))
BEGIN
    SET @next_month = DATE_ADD(CONCAT(yr, '-', mo, '-01'), INTERVAL 1 MONTH);
    SET @pname      = CONCAT('p', yr, '_', mo);
    SET @pname_e    = CONCAT('pe', yr, '_', mo);
    SET @sql = CONCAT(
        'ALTER TABLE gauge_readings REORGANIZE PARTITION p_future INTO (',
        'PARTITION ', @pname, ' VALUES LESS THAN (TO_DAYS(''', @next_month, ''')),',
        'PARTITION p_future VALUES LESS THAN MAXVALUE)'
    );
    PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

    SET @sql2 = CONCAT(
        'ALTER TABLE ocr_errors REORGANIZE PARTITION pe_future INTO (',
        'PARTITION ', @pname_e, ' VALUES LESS THAN (TO_DAYS(''', @next_month, ''')),',
        'PARTITION pe_future VALUES LESS THAN MAXVALUE)'
    );
    PREPARE stmt FROM @sql2; EXECUTE stmt; DEALLOCATE PREPARE stmt;
END$$
DELIMITER ;


-- ============================================================
--  데이터 삽입 예시
-- ============================================================

-- 정상 데이터 삽입
INSERT INTO gauge_readings (
    recorded_at,
    iso_temp_pv, iso_temp_sv, iso_pump_speed, iso_press,
    pol1_temp_pv, pol1_temp_sv, pol1_pump_speed, pol1_press,
    pol2_temp_pv, pol2_temp_sv, pol2_pump_speed, pol2_press,
    hot_water_temp_pv, hot_water_temp_sv
) VALUES (
    '2026-03-24 09:31:00.000',
    87.3, 85.0, 1450, 2.45,
    72.1, 70.0, 1200, 1.80,
    71.8, 70.0, 1210, 1.82,
    65.0, 63.0
);

-- OCR 오류 삽입 예시
INSERT INTO ocr_errors (logged_at, field, raw_text, error_type, error_detail, confidence)
VALUES ('2026-03-24 09:31:00.500', 'iso_temp_pv', '8?.3', 'PARSE_FAIL', '숫자 추출 실패 — ? 문자 포함', 0.42);


-- ============================================================
--  조회 예시
-- ============================================================

-- 최근 1분간 전체 측정값
SELECT *
FROM gauge_readings
WHERE recorded_at >= NOW() - INTERVAL 1 MINUTE
ORDER BY recorded_at DESC;

-- ISO 온도 PV 최근 1시간 평균 (1분 단위 집계)
SELECT
    DATE_FORMAT(recorded_at, '%Y-%m-%d %H:%i:00') AS minute_bucket,
    AVG(iso_temp_pv)   AS avg_iso_temp_pv,
    MIN(iso_temp_pv)   AS min_iso_temp_pv,
    MAX(iso_temp_pv)   AS max_iso_temp_pv
FROM gauge_readings
WHERE recorded_at >= NOW() - INTERVAL 1 HOUR
GROUP BY minute_bucket
ORDER BY minute_bucket;




-- 오늘 OCR 오류 유형별 집계
SELECT error_type, COUNT(*) AS cnt
FROM ocr_errors
WHERE logged_at >= CURDATE()
GROUP BY error_type
ORDER BY cnt DESC;
