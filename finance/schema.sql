-- ============================================
-- 은행 시스템 데이터베이스 스키마
-- ============================================

-- ============================================
-- Tier 1: 고객 (Customers)
-- ============================================

CREATE TABLE customers (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    customer_number VARCHAR(20) UNIQUE NOT NULL COMMENT '고객번호',
    
    -- 기본 정보
    name VARCHAR(100) NOT NULL COMMENT '이름',
    birth_date DATE COMMENT '생년월일',
    phone VARCHAR(20) COMMENT '전화번호',
    email VARCHAR(100) COMMENT '이메일',
    
    -- 본인인증 정보
    ci VARCHAR(200) UNIQUE COMMENT 'CI (중복가입방지)',
    di VARCHAR(200) COMMENT 'DI',
    kyc_verified BOOLEAN DEFAULT FALSE COMMENT '본인인증 여부',
    kyc_verified_at TIMESTAMP NULL COMMENT '본인인증 일시',
    verification_method VARCHAR(20) COMMENT '인증수단 (PASS, NICE, KAKAO)',
    
    -- 상태
    status VARCHAR(20) DEFAULT 'active' COMMENT '상태 (active, dormant, closed)',
    
    -- 감사 필드 (모든 테이블에 필수!)
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50),
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    updated_by VARCHAR(50),
    deleted_at TIMESTAMP NULL COMMENT 'Soft Delete',
    
    INDEX idx_customer_number (customer_number),
    INDEX idx_ci (ci),
    INDEX idx_status (status),
    INDEX idx_deleted_at (deleted_at)
) COMMENT='고객';


-- ============================================
-- Tier 0: 계좌 (Accounts) - 최고 핵심!
-- ============================================

CREATE TABLE accounts (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    account_number VARCHAR(20) UNIQUE NOT NULL COMMENT '계좌번호',
    
    -- 계좌 정보
    account_type VARCHAR(20) NOT NULL COMMENT '계좌유형 (savings, checking, deposit)',
    currency VARCHAR(3) DEFAULT 'KRW' COMMENT '통화',
    
    -- 주의: 잔액은 직접 저장하지 않음! transactions로 계산
    
    status VARCHAR(20) DEFAULT 'active' COMMENT '상태 (active, frozen, closed)',
    
    interest_rate DECIMAL(5,4) COMMENT '이자율',
    
    opened_at TIMESTAMP NOT NULL COMMENT '개설일',
    closed_at TIMESTAMP NULL COMMENT '해지일',
    
    -- 감사 필드
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50),
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    updated_by VARCHAR(50),
    deleted_at TIMESTAMP NULL COMMENT 'Soft Delete',
    
    INDEX idx_account_number (account_number),
    INDEX idx_account_type (account_type),
    INDEX idx_status (status),
    INDEX idx_deleted_at (deleted_at)
) COMMENT='계좌';


-- ============================================
-- Tier 2: 계좌-고객 관계 (Account Holders)
-- ============================================

CREATE TABLE account_holders (
    account_id BIGINT NOT NULL,
    customer_id BIGINT NOT NULL,
    
    -- 보유 유형
    holder_type VARCHAR(20) DEFAULT 'primary' COMMENT '보유자유형 (primary, joint, authorized)',
    relationship VARCHAR(50) COMMENT '관계 (owner, spouse, representative)',
    
    -- 유효 기간 (시간별 권한 관리)
    effective_from DATE NOT NULL COMMENT '유효시작일',
    effective_to DATE NULL COMMENT '유효종료일',
    
    PRIMARY KEY (account_id, customer_id, effective_from),
    FOREIGN KEY (account_id) REFERENCES accounts(id),
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    
    INDEX idx_customer_id (customer_id),
    INDEX idx_effective (effective_from, effective_to)
) COMMENT='계좌-고객 관계 (N:M)';


-- ============================================
-- Tier 0: 거래 (Transactions) - 진실의 원천!
-- ============================================

CREATE TABLE transactions (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    transaction_number VARCHAR(50) UNIQUE NOT NULL COMMENT '거래번호',
    
    -- 이중 기입 (Double Entry)
    from_account_id BIGINT NULL COMMENT '출금계좌',
    to_account_id BIGINT NULL COMMENT '입금계좌',
    
    -- 금액 (항상 양수!)
    amount DECIMAL(15,2) NOT NULL COMMENT '금액',
    currency VARCHAR(3) DEFAULT 'KRW' COMMENT '통화',
    
    -- 거래 유형
    transaction_type VARCHAR(50) NOT NULL COMMENT '거래유형 (deposit, withdrawal, transfer, interest, fee)',
    
    status VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '상태 (pending, completed, failed, cancelled, reversed)',
    
    description TEXT COMMENT '설명',
    
    -- 실행 정보
    executed_at TIMESTAMP NOT NULL COMMENT '실행일시',
    executed_by VARCHAR(50) COMMENT '실행자',
    
    -- 취소/정정 추적
    original_transaction_id BIGINT NULL COMMENT '원거래 ID (취소 시)',
    reversed_transaction_id BIGINT NULL COMMENT '취소 거래 ID',
    
    -- 외부 연동
    external_reference VARCHAR(100) COMMENT '외부 시스템 참조번호',
    
    -- 감사
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (from_account_id) REFERENCES accounts(id),
    FOREIGN KEY (to_account_id) REFERENCES accounts(id),
    FOREIGN KEY (original_transaction_id) REFERENCES transactions(id),
    
    -- 제약: 최소 한쪽 계좌는 있어야 함
    CHECK (from_account_id IS NOT NULL OR to_account_id IS NOT NULL),
    
    INDEX idx_transaction_number (transaction_number),
    INDEX idx_from_account (from_account_id, executed_at),
    INDEX idx_to_account (to_account_id, executed_at),
    INDEX idx_status (status),
    INDEX idx_executed_at (executed_at),
    INDEX idx_original_transaction (original_transaction_id)
) COMMENT='거래 - 절대 DELETE 금지!';


-- ============================================
-- Tier 3: 거래 상세 (Transaction Details)
-- ============================================

CREATE TABLE transaction_details (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    transaction_id BIGINT NOT NULL,
    
    detail_type VARCHAR(50) COMMENT '상세유형 (fee, tax, exchange, memo)',
    detail_key VARCHAR(100) COMMENT '키',
    detail_value TEXT COMMENT '값',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (transaction_id) REFERENCES transactions(id),
    INDEX idx_transaction_id (transaction_id)
) COMMENT='거래 상세 정보';


-- ============================================
-- Tier 3: 계좌 잔액 캐시 (Account Balances)
-- ============================================

CREATE TABLE account_balances (
    account_id BIGINT PRIMARY KEY,
    
    balance DECIMAL(15,2) NOT NULL COMMENT '잔액',
    as_of_date DATE NOT NULL COMMENT '기준일',
    last_transaction_id BIGINT COMMENT '마지막 반영 거래 ID',
    
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (account_id) REFERENCES accounts(id),
    FOREIGN KEY (last_transaction_id) REFERENCES transactions(id),
    
    INDEX idx_as_of_date (as_of_date)
) COMMENT='계좌 잔액 캐시 (성능 최적화용)';


-- ============================================
-- Tier 2: 카드 (Cards)
-- ============================================

CREATE TABLE cards (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    card_number VARCHAR(16) UNIQUE NOT NULL COMMENT '카드번호 (암호화 필요!)',
    card_type VARCHAR(20) COMMENT '카드유형 (debit, credit, prepaid)',
    
    account_id BIGINT NOT NULL COMMENT '연결 계좌',
    
    issue_date DATE NOT NULL COMMENT '발급일',
    expiry_date DATE NOT NULL COMMENT '만료일',
    
    status VARCHAR(20) DEFAULT 'active' COMMENT '상태 (active, blocked, lost, expired)',
    
    daily_limit DECIMAL(15,2) COMMENT '일일한도',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    
    FOREIGN KEY (account_id) REFERENCES accounts(id),
    
    INDEX idx_card_number (card_number),
    INDEX idx_account_id (account_id),
    INDEX idx_status (status)
) COMMENT='카드';


-- ============================================
-- Tier 2: 대출 (Loans)
-- ============================================

CREATE TABLE loans (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    loan_number VARCHAR(20) UNIQUE NOT NULL COMMENT '대출번호',
    
    account_id BIGINT NOT NULL COMMENT '대출 지급 계좌',
    
    loan_type VARCHAR(50) COMMENT '대출유형 (mortgage, personal, auto)',
    
    principal_amount DECIMAL(15,2) NOT NULL COMMENT '원금',
    interest_rate DECIMAL(5,4) NOT NULL COMMENT '이자율',
    
    disbursement_date DATE COMMENT '실행일',
    maturity_date DATE COMMENT '만기일',
    
    status VARCHAR(20) COMMENT '상태 (active, overdue, completed, defaulted)',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (account_id) REFERENCES accounts(id),
    
    INDEX idx_loan_number (loan_number),
    INDEX idx_account_id (account_id),
    INDEX idx_status (status)
) COMMENT='대출';


-- ============================================
-- Tier 3: 대출 상환 스케줄 (Loan Schedules)
-- ============================================

CREATE TABLE loan_schedules (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    loan_id BIGINT NOT NULL,
    
    due_date DATE NOT NULL COMMENT '납부일',
    principal_amount DECIMAL(15,2) COMMENT '원금',
    interest_amount DECIMAL(15,2) COMMENT '이자',
    
    paid_date DATE NULL COMMENT '납부완료일',
    paid_amount DECIMAL(15,2) NULL COMMENT '납부금액',
    
    transaction_id BIGINT NULL COMMENT '실제 납부 거래',
    
    FOREIGN KEY (loan_id) REFERENCES loans(id),
    FOREIGN KEY (transaction_id) REFERENCES transactions(id),
    
    INDEX idx_loan_id (loan_id),
    INDEX idx_due_date (due_date)
) COMMENT='대출 상환 스케줄';


-- ============================================
-- Tier 3: 계좌 변경 이력 (Account History)
-- ============================================

CREATE TABLE account_history (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    account_id BIGINT NOT NULL,
    
    field_name VARCHAR(50) COMMENT '변경된 필드명',
    old_value TEXT COMMENT '이전 값',
    new_value TEXT COMMENT '새 값',
    
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(50) COMMENT '변경자',
    reason TEXT COMMENT '변경 사유',
    
    FOREIGN KEY (account_id) REFERENCES accounts(id),
    INDEX idx_account_id (account_id),
    INDEX idx_changed_at (changed_at)
) COMMENT='계좌 변경 이력';


-- ============================================
-- Tier 3: 감사 로그 (Audit Logs)
-- ============================================

CREATE TABLE audit_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    
    table_name VARCHAR(50) NOT NULL COMMENT '테이블명',
    record_id BIGINT NOT NULL COMMENT '레코드 ID',
    action VARCHAR(20) NOT NULL COMMENT '액션 (INSERT, UPDATE, DELETE)',
    
    old_data JSON COMMENT '변경 전 데이터',
    new_data JSON COMMENT '변경 후 데이터',
    
    user_id VARCHAR(50) COMMENT '사용자 ID',
    ip_address VARCHAR(50) COMMENT 'IP 주소',
    
    occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_table_record (table_name, record_id),
    INDEX idx_occurred_at (occurred_at),
    INDEX idx_user_id (user_id)
) COMMENT='감사 로그';


-- ============================================
-- 트리거: 계좌 변경 시 자동으로 이력 기록
-- ============================================

DELIMITER //

CREATE TRIGGER account_changes_trigger
AFTER UPDATE ON accounts
FOR EACH ROW
BEGIN
    IF OLD.status != NEW.status THEN
        INSERT INTO account_history (account_id, field_name, old_value, new_value, changed_by)
        VALUES (NEW.id, 'status', OLD.status, NEW.status, NEW.updated_by);
    END IF;
    
    IF OLD.interest_rate != NEW.interest_rate THEN
        INSERT INTO account_history (account_id, field_name, old_value, new_value, changed_by)
        VALUES (NEW.id, 'interest_rate', OLD.interest_rate, NEW.interest_rate, NEW.updated_by);
    END IF;
END//

DELIMITER ;


-- ============================================
-- 샘플 데이터
-- ============================================

-- 고객
INSERT INTO customers (customer_number, name, birth_date, phone, ci, kyc_verified, status)
VALUES 
    ('C0001', '홍길동', '1990-01-01', '010-1111-1111', 'CI_HONG', TRUE, 'active'),
    ('C0002', '김철수', '1985-05-15', '010-2222-2222', 'CI_KIM', TRUE, 'active'),
    ('C0003', '이영희', '1992-08-20', '010-3333-3333', 'CI_LEE', TRUE, 'active');

-- 계좌
INSERT INTO accounts (account_number, account_type, currency, status, interest_rate, opened_at)
VALUES 
    ('111-222-333', 'savings', 'KRW', 'active', 0.0200, NOW()),
    ('444-555-666', 'checking', 'KRW', 'active', 0.0100, NOW()),
    ('777-888-999', 'deposit', 'KRW', 'active', 0.0350, NOW());

-- 계좌-고객 관계
INSERT INTO account_holders (account_id, customer_id, holder_type, relationship, effective_from)
VALUES 
    (1, 1, 'primary', 'owner', '2024-01-01'),  -- 홍길동 개인계좌
    (2, 1, 'primary', 'owner', '2024-01-01'),  -- 공동명의 (주)
    (2, 2, 'joint', 'spouse', '2024-01-01'),   -- 공동명의 (부)
    (3, 1, 'representative', 'ceo', '2024-01-01'),  -- 법인 대표
    (3, 3, 'authorized', 'manager', '2024-01-01');  -- 법인 권한자

-- 거래
INSERT INTO transactions (transaction_number, from_account_id, to_account_id, amount, transaction_type, status, executed_at)
VALUES 
    ('T0001', NULL, 1, 1000000.00, 'deposit', 'completed', NOW()),  -- 입금
    ('T0002', 1, NULL, 50000.00, 'withdrawal', 'completed', NOW()), -- 출금
    ('T0003', 1, 2, 100000.00, 'transfer', 'completed', NOW());     -- 이체

