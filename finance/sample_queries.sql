-- ============================================
-- 은행 시스템 주요 쿼리 예시
-- ============================================

-- ============================================
-- 1. 계좌 잔액 조회
-- ============================================

-- 실시간 잔액 (transactions로부터 계산)
SELECT 
    a.account_number AS '계좌번호',
    a.account_type AS '계좌유형',
    COALESCE(SUM(
        CASE 
            WHEN t.to_account_id = a.id THEN t.amount
            WHEN t.from_account_id = a.id THEN -t.amount
            ELSE 0
        END
    ), 0) AS balance
FROM accounts a
LEFT JOIN transactions t ON (
    t.to_account_id = a.id OR t.from_account_id = a.id
)
WHERE a.id = 1  -- 계좌 ID
    AND (t.status = 'completed' OR t.status IS NULL)
GROUP BY a.id, a.account_number, a.account_type;


-- 캐시된 잔액 조회 (빠름)
SELECT 
    a.account_number AS '계좌번호',
    ab.balance AS '잔액',
    ab.as_of_date AS '기준일'
FROM accounts a
JOIN account_balances ab ON a.id = ab.account_id
WHERE a.id = 1;


-- ============================================
-- 2. 고객의 모든 계좌 조회
-- ============================================

SELECT 
    c.customer_number AS '고객번호',
    c.name AS '고객명',
    a.account_number AS '계좌번호',
    a.account_type AS '계좌유형',
    ah.holder_type AS '보유유형',
    ah.relationship AS '관계'
FROM customers c
JOIN account_holders ah ON c.id = ah.customer_id
JOIN accounts a ON ah.account_id = a.id
WHERE c.id = 1  -- 고객 ID
    AND ah.effective_to IS NULL  -- 현재 유효한 것만
    AND a.deleted_at IS NULL
    AND c.deleted_at IS NULL;


-- ============================================
-- 3. 거래 내역 조회 (잔액 포함)
-- ============================================

SELECT 
    t.transaction_number AS '거래번호',
    t.executed_at AS '거래일시',
    CASE 
        WHEN t.from_account_id = 1 THEN '출금'
        WHEN t.to_account_id = 1 THEN '입금'
    END AS '구분',
    CASE 
        WHEN t.from_account_id = 1 THEN other_acc.account_number
        WHEN t.to_account_id = 1 THEN other_acc.account_number
    END AS '상대계좌',
    t.amount AS '금액',
    t.description AS '적요',
    -- 누적 잔액 계산 (Window Function)
    SUM(
        CASE 
            WHEN t2.to_account_id = 1 THEN t2.amount
            WHEN t2.from_account_id = 1 THEN -t2.amount
        END
    ) OVER (ORDER BY t2.executed_at, t2.id) AS '잔액'
FROM transactions t
-- 거래 누적을 위한 self join
LEFT JOIN transactions t2 ON (
    (t2.from_account_id = 1 OR t2.to_account_id = 1)
    AND t2.status = 'completed'
    AND t2.id <= t.id
)
-- 상대 계좌 정보
LEFT JOIN accounts other_acc ON (
    CASE 
        WHEN t.from_account_id = 1 THEN t.to_account_id
        WHEN t.to_account_id = 1 THEN t.from_account_id
    END = other_acc.id
)
WHERE (t.from_account_id = 1 OR t.to_account_id = 1)
    AND t.status = 'completed'
ORDER BY t.executed_at DESC, t.id DESC
LIMIT 20;


-- ============================================
-- 4. 공동명의 계좌 조회
-- ============================================

SELECT 
    a.account_number AS '계좌번호',
    c.name AS '고객명',
    ah.holder_type AS '보유유형',
    ah.relationship AS '관계'
FROM accounts a
JOIN account_holders ah ON a.id = ah.account_id
JOIN customers c ON ah.customer_id = c.id
WHERE a.id = 2  -- 계좌 ID
    AND ah.effective_to IS NULL
ORDER BY 
    CASE ah.holder_type
        WHEN 'primary' THEN 1
        WHEN 'joint' THEN 2
        ELSE 3
    END;


-- ============================================
-- 5. 이체 실행 (트랜잭션)
-- ============================================

-- 시작
START TRANSACTION;

-- 잔액 확인
SET @from_balance = (
    SELECT COALESCE(SUM(
        CASE 
            WHEN to_account_id = 1 THEN amount
            WHEN from_account_id = 1 THEN -amount
        END
    ), 0)
    FROM transactions
    WHERE (from_account_id = 1 OR to_account_id = 1)
        AND status = 'completed'
    FOR UPDATE  -- 락 걸기
);

-- 잔액 충분한지 확인
SELECT @from_balance >= 100000 AS can_transfer;

-- 이체 실행 (잔액이 충분하면)
INSERT INTO transactions (
    transaction_number, 
    from_account_id, 
    to_account_id, 
    amount, 
    transaction_type, 
    status, 
    description,
    executed_at
)
VALUES (
    CONCAT('T', LPAD(LAST_INSERT_ID() + 1, 10, '0')),
    1,  -- 출금 계좌
    2,  -- 입금 계좌
    100000.00,  -- 금액
    'transfer',
    'completed',
    '이체',
    NOW()
);

-- 커밋 또는 롤백
COMMIT;
-- ROLLBACK;


-- ============================================
-- 6. 거래 취소 (역거래)
-- ============================================

-- 원거래 정보 조회
SELECT * FROM transactions WHERE id = 3;

-- 역거래 생성
START TRANSACTION;

INSERT INTO transactions (
    transaction_number,
    from_account_id,
    to_account_id,  -- 원거래와 반대!
    amount,
    transaction_type,
    status,
    description,
    original_transaction_id,  -- 원거래 참조
    executed_at
)
SELECT 
    CONCAT('TR', LPAD(LAST_INSERT_ID() + 1, 10, '0')),
    to_account_id,    -- 반대로
    from_account_id,  -- 반대로
    amount,
    transaction_type,
    'completed',
    CONCAT('거래취소: ', description),
    id,  -- 원거래 ID
    NOW()
FROM transactions
WHERE id = 3;

-- 원거래에 취소 표시
UPDATE transactions
SET reversed_transaction_id = LAST_INSERT_ID()
WHERE id = 3;

COMMIT;


-- ============================================
-- 7. 일별 거래 집계
-- ============================================

SELECT 
    DATE(executed_at) AS '날짜',
    transaction_type AS '거래유형',
    COUNT(*) AS '건수',
    SUM(amount) AS '총금액',
    AVG(amount) AS '평균금액',
    MIN(amount) AS '최소금액',
    MAX(amount) AS '최대금액'
FROM transactions
WHERE status = 'completed'
    AND executed_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY DATE(executed_at), transaction_type
ORDER BY DATE(executed_at) DESC, transaction_type;


-- ============================================
-- 8. 대출 상환 내역
-- ============================================

SELECT 
    l.loan_number AS '대출번호',
    l.principal_amount AS '원금',
    l.interest_rate AS '이자율',
    ls.due_date AS '납부일',
    ls.principal_amount AS '원금상환액',
    ls.interest_amount AS '이자',
    ls.paid_date AS '납부완료일',
    CASE 
        WHEN ls.paid_date IS NULL THEN '미납'
        WHEN ls.paid_date > ls.due_date THEN '연체'
        ELSE '정상'
    END AS '상태'
FROM loans l
JOIN loan_schedules ls ON l.id = ls.loan_id
WHERE l.id = 1  -- 대출 ID
ORDER BY ls.due_date;


-- ============================================
-- 9. 카드 사용 내역 (거래 연결)
-- ============================================

SELECT 
    c.card_number AS '카드번호',
    t.executed_at AS '사용일시',
    t.amount AS '금액',
    t.description AS '사용처'
FROM cards c
JOIN accounts a ON c.account_id = a.id
JOIN transactions t ON t.from_account_id = a.id
WHERE c.id = 1  -- 카드 ID
    AND t.transaction_type = 'card_payment'
    AND t.status = 'completed'
ORDER BY t.executed_at DESC
LIMIT 20;


-- ============================================
-- 10. 의심 거래 탐지
-- ============================================

-- 단시간 내 여러 출금
SELECT 
    a.account_number AS '계좌번호',
    COUNT(*) AS '거래건수',
    SUM(t.amount) AS '총금액',
    MIN(t.executed_at) AS '시작시간',
    MAX(t.executed_at) AS '종료시간'
FROM transactions t
JOIN accounts a ON t.from_account_id = a.id
WHERE t.status = 'completed'
    AND t.transaction_type IN ('withdrawal', 'transfer')
    AND t.executed_at >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
GROUP BY t.from_account_id, a.account_number
HAVING COUNT(*) >= 5  -- 1시간 내 5건 이상
    OR SUM(t.amount) >= 10000000;  -- 또는 총 1천만원 이상


-- ============================================
-- 11. 계좌 변경 이력 조회
-- ============================================

SELECT 
    ah.changed_at AS '변경일시',
    ah.field_name AS '변경항목',
    ah.old_value AS '이전값',
    ah.new_value AS '새값',
    ah.changed_by AS '변경자',
    ah.reason AS '변경사유'
FROM account_history ah
WHERE ah.account_id = 1  -- 계좌 ID
ORDER BY ah.changed_at DESC;


-- ============================================
-- 12. 고객별 총 자산 조회
-- ============================================

SELECT 
    c.customer_number AS '고객번호',
    c.name AS '고객명',
    COUNT(DISTINCT a.id) AS '계좌수',
    SUM(
        COALESCE((
            SELECT SUM(
                CASE 
                    WHEN t.to_account_id = a.id THEN t.amount
                    WHEN t.from_account_id = a.id THEN -t.amount
                END
            )
            FROM transactions t
            WHERE (t.from_account_id = a.id OR t.to_account_id = a.id)
                AND t.status = 'completed'
        ), 0)
    ) AS '총자산'
FROM customers c
JOIN account_holders ah ON c.id = ah.customer_id
JOIN accounts a ON ah.account_id = a.id
WHERE c.id = 1  -- 고객 ID
    AND ah.effective_to IS NULL
    AND a.deleted_at IS NULL
GROUP BY c.id, c.customer_number, c.name;


-- ============================================
-- 13. 월별 이자 지급
-- ============================================

-- 이자 계산 및 지급
INSERT INTO transactions (
    transaction_number,
    from_account_id,
    to_account_id,
    amount,
    transaction_type,
    status,
    description,
    executed_at
)
SELECT 
    CONCAT('INT', DATE_FORMAT(NOW(), '%Y%m'), LPAD(a.id, 6, '0')),
    NULL,
    a.id,
    -- 잔액 * 이자율 / 12
    (
        SELECT COALESCE(SUM(
            CASE 
                WHEN t.to_account_id = a.id THEN t.amount
                WHEN t.from_account_id = a.id THEN -t.amount
            END
        ), 0)
        FROM transactions t
        WHERE (t.from_account_id = a.id OR t.to_account_id = a.id)
            AND t.status = 'completed'
    ) * a.interest_rate / 12,
    'interest',
    'completed',
    CONCAT(DATE_FORMAT(NOW(), '%Y년 %m월'), ' 이자'),
    NOW()
FROM accounts a
WHERE a.status = 'active'
    AND a.account_type IN ('savings', 'deposit')
    AND a.interest_rate > 0;


-- ============================================
-- 14. 성능 통계 (인덱스 활용 확인)
-- ============================================

-- 계좌별 거래 통계
EXPLAIN SELECT 
    a.account_number,
    COUNT(*) as tx_count,
    SUM(t.amount) as total_amount
FROM accounts a
JOIN transactions t ON (t.from_account_id = a.id OR t.to_account_id = a.id)
WHERE t.executed_at >= DATE_SUB(NOW(), INTERVAL 1 MONTH)
    AND t.status = 'completed'
GROUP BY a.id, a.account_number;

