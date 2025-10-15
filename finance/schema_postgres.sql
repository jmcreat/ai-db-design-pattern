-- ============================================
-- 은행 시스템 데이터베이스 스키마 (PostgreSQL 16)
-- ============================================

-- PostGIS 확장 활성화 (필요시)
-- CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================
-- Tier 1: 고객 (Customers)
-- ============================================

CREATE TABLE customers (
    id BIGSERIAL PRIMARY KEY,
    customer_number VARCHAR(20) UNIQUE NOT NULL,
    
    -- 기본 정보
    name VARCHAR(100) NOT NULL,
    birth_date DATE,
    phone VARCHAR(20),
    email VARCHAR(100),
    
    -- 본인인증 정보
    ci VARCHAR(200) UNIQUE,
    di VARCHAR(200),
    kyc_verified BOOLEAN DEFAULT false,
    kyc_verified_at TIMESTAMPTZ,
    verification_method VARCHAR(20),
    
    -- 상태
    status VARCHAR(20) DEFAULT 'active',
    
    -- 감사 필드
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by VARCHAR(50),
    deleted_at TIMESTAMPTZ
);

-- 주석
COMMENT ON TABLE customers IS '고객';
COMMENT ON COLUMN customers.customer_number IS '고객번호';
COMMENT ON COLUMN customers.name IS '이름';
COMMENT ON COLUMN customers.birth_date IS '생년월일';
COMMENT ON COLUMN customers.phone IS '전화번호';
COMMENT ON COLUMN customers.email IS '이메일';
COMMENT ON COLUMN customers.ci IS 'CI (중복가입방지)';
COMMENT ON COLUMN customers.di IS 'DI';
COMMENT ON COLUMN customers.kyc_verified IS '본인인증 여부';
COMMENT ON COLUMN customers.kyc_verified_at IS '본인인증 일시';
COMMENT ON COLUMN customers.verification_method IS '인증수단 (PASS, NICE, KAKAO)';
COMMENT ON COLUMN customers.status IS '상태 (active, dormant, closed)';
COMMENT ON COLUMN customers.deleted_at IS 'Soft Delete';

-- 인덱스
CREATE INDEX idx_customers_customer_number ON customers(customer_number);
CREATE INDEX idx_customers_ci ON customers(ci);
CREATE INDEX idx_customers_status ON customers(status);
CREATE INDEX idx_customers_deleted_at ON customers(deleted_at);


-- ============================================
-- Tier 0: 계좌 (Accounts)
-- ============================================

CREATE TABLE accounts (
    id BIGSERIAL PRIMARY KEY,
    account_number VARCHAR(20) UNIQUE NOT NULL,
    
    -- 계좌 정보
    account_type VARCHAR(20) NOT NULL,
    currency VARCHAR(3) DEFAULT 'KRW',
    
    -- 주의: 잔액은 직접 저장하지 않음! transactions로 계산
    
    status VARCHAR(20) DEFAULT 'active',
    interest_rate NUMERIC(5,4),
    
    opened_at TIMESTAMPTZ NOT NULL,
    closed_at TIMESTAMPTZ,
    
    -- 감사 필드
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by VARCHAR(50),
    deleted_at TIMESTAMPTZ
);

COMMENT ON TABLE accounts IS '계좌';
COMMENT ON COLUMN accounts.account_number IS '계좌번호';
COMMENT ON COLUMN accounts.account_type IS '계좌유형 (savings, checking, deposit)';
COMMENT ON COLUMN accounts.currency IS '통화';
COMMENT ON COLUMN accounts.status IS '상태 (active, frozen, closed)';
COMMENT ON COLUMN accounts.interest_rate IS '이자율';
COMMENT ON COLUMN accounts.opened_at IS '개설일';
COMMENT ON COLUMN accounts.closed_at IS '해지일';
COMMENT ON COLUMN accounts.deleted_at IS 'Soft Delete';

CREATE INDEX idx_accounts_account_number ON accounts(account_number);
CREATE INDEX idx_accounts_account_type ON accounts(account_type);
CREATE INDEX idx_accounts_status ON accounts(status);
CREATE INDEX idx_accounts_deleted_at ON accounts(deleted_at);


-- ============================================
-- Tier 2: 계좌-고객 관계 (Account Holders)
-- ============================================

CREATE TABLE account_holders (
    account_id BIGINT NOT NULL,
    customer_id BIGINT NOT NULL,
    
    holder_type VARCHAR(20) DEFAULT 'primary',
    relationship VARCHAR(50),
    
    effective_from DATE NOT NULL,
    effective_to DATE,
    
    PRIMARY KEY (account_id, customer_id, effective_from),
    FOREIGN KEY (account_id) REFERENCES accounts(id),
    FOREIGN KEY (customer_id) REFERENCES customers(id)
);

COMMENT ON TABLE account_holders IS '계좌-고객 관계 (N:M)';
COMMENT ON COLUMN account_holders.holder_type IS '보유자유형 (primary, joint, authorized)';
COMMENT ON COLUMN account_holders.relationship IS '관계 (owner, spouse, representative)';
COMMENT ON COLUMN account_holders.effective_from IS '유효시작일';
COMMENT ON COLUMN account_holders.effective_to IS '유효종료일';

CREATE INDEX idx_account_holders_customer_id ON account_holders(customer_id);
CREATE INDEX idx_account_holders_effective ON account_holders(effective_from, effective_to);


-- ============================================
-- Tier 0: 거래 (Transactions)
-- ============================================

CREATE TABLE transactions (
    id BIGSERIAL PRIMARY KEY,
    transaction_number VARCHAR(50) UNIQUE NOT NULL,
    
    -- 이중 기입
    from_account_id BIGINT,
    to_account_id BIGINT,
    
    amount NUMERIC(15,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'KRW',
    
    transaction_type VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    description TEXT,
    
    executed_at TIMESTAMPTZ NOT NULL,
    executed_by VARCHAR(50),
    
    -- 취소/정정 추적
    original_transaction_id BIGINT,
    reversed_transaction_id BIGINT,
    
    external_reference VARCHAR(100),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    FOREIGN KEY (from_account_id) REFERENCES accounts(id),
    FOREIGN KEY (to_account_id) REFERENCES accounts(id),
    FOREIGN KEY (original_transaction_id) REFERENCES transactions(id),
    
    CONSTRAINT chk_transactions_accounts CHECK (
        from_account_id IS NOT NULL OR to_account_id IS NOT NULL
    )
);

COMMENT ON TABLE transactions IS '거래 - 절대 DELETE 금지!';
COMMENT ON COLUMN transactions.transaction_number IS '거래번호';
COMMENT ON COLUMN transactions.from_account_id IS '출금계좌';
COMMENT ON COLUMN transactions.to_account_id IS '입금계좌';
COMMENT ON COLUMN transactions.amount IS '금액';
COMMENT ON COLUMN transactions.currency IS '통화';
COMMENT ON COLUMN transactions.transaction_type IS '거래유형 (deposit, withdrawal, transfer, interest, fee)';
COMMENT ON COLUMN transactions.status IS '상태 (pending, completed, failed, cancelled, reversed)';
COMMENT ON COLUMN transactions.description IS '설명';
COMMENT ON COLUMN transactions.executed_at IS '실행일시';
COMMENT ON COLUMN transactions.executed_by IS '실행자';
COMMENT ON COLUMN transactions.original_transaction_id IS '원거래 ID (취소 시)';
COMMENT ON COLUMN transactions.reversed_transaction_id IS '취소 거래 ID';
COMMENT ON COLUMN transactions.external_reference IS '외부 시스템 참조번호';

CREATE INDEX idx_transactions_transaction_number ON transactions(transaction_number);
CREATE INDEX idx_transactions_from_account ON transactions(from_account_id, executed_at);
CREATE INDEX idx_transactions_to_account ON transactions(to_account_id, executed_at);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_executed_at ON transactions(executed_at);
CREATE INDEX idx_transactions_original ON transactions(original_transaction_id);


-- ============================================
-- Tier 3: 거래 상세 (Transaction Details)
-- ============================================

CREATE TABLE transaction_details (
    id BIGSERIAL PRIMARY KEY,
    transaction_id BIGINT NOT NULL,
    
    detail_type VARCHAR(50),
    detail_key VARCHAR(100),
    detail_value TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    FOREIGN KEY (transaction_id) REFERENCES transactions(id)
);

COMMENT ON TABLE transaction_details IS '거래 상세 정보';
COMMENT ON COLUMN transaction_details.detail_type IS '상세유형 (fee, tax, exchange, memo)';
COMMENT ON COLUMN transaction_details.detail_key IS '키';
COMMENT ON COLUMN transaction_details.detail_value IS '값';

CREATE INDEX idx_transaction_details_transaction_id ON transaction_details(transaction_id);


-- ============================================
-- Tier 3: 계좌 잔액 캐시 (Account Balances)
-- ============================================

CREATE TABLE account_balances (
    account_id BIGINT PRIMARY KEY,
    
    balance NUMERIC(15,2) NOT NULL,
    as_of_date DATE NOT NULL,
    last_transaction_id BIGINT,
    
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    FOREIGN KEY (account_id) REFERENCES accounts(id),
    FOREIGN KEY (last_transaction_id) REFERENCES transactions(id)
);

COMMENT ON TABLE account_balances IS '계좌 잔액 캐시 (성능 최적화용)';
COMMENT ON COLUMN account_balances.balance IS '잔액';
COMMENT ON COLUMN account_balances.as_of_date IS '기준일';
COMMENT ON COLUMN account_balances.last_transaction_id IS '마지막 반영 거래 ID';

CREATE INDEX idx_account_balances_as_of_date ON account_balances(as_of_date);


-- ============================================
-- Tier 2: 카드 (Cards)
-- ============================================

CREATE TABLE cards (
    id BIGSERIAL PRIMARY KEY,
    card_number VARCHAR(16) UNIQUE NOT NULL,
    card_type VARCHAR(20),
    
    account_id BIGINT NOT NULL,
    
    issue_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    
    status VARCHAR(20) DEFAULT 'active',
    daily_limit NUMERIC(15,2),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    
    FOREIGN KEY (account_id) REFERENCES accounts(id)
);

COMMENT ON TABLE cards IS '카드';
COMMENT ON COLUMN cards.card_number IS '카드번호 (암호화 필요!)';
COMMENT ON COLUMN cards.card_type IS '카드유형 (debit, credit, prepaid)';
COMMENT ON COLUMN cards.account_id IS '연결 계좌';
COMMENT ON COLUMN cards.issue_date IS '발급일';
COMMENT ON COLUMN cards.expiry_date IS '만료일';
COMMENT ON COLUMN cards.status IS '상태 (active, blocked, lost, expired)';
COMMENT ON COLUMN cards.daily_limit IS '일일한도';

CREATE INDEX idx_cards_card_number ON cards(card_number);
CREATE INDEX idx_cards_account_id ON cards(account_id);
CREATE INDEX idx_cards_status ON cards(status);


-- ============================================
-- Tier 2: 대출 (Loans)
-- ============================================

CREATE TABLE loans (
    id BIGSERIAL PRIMARY KEY,
    loan_number VARCHAR(20) UNIQUE NOT NULL,
    
    account_id BIGINT NOT NULL,
    loan_type VARCHAR(50),
    
    principal_amount NUMERIC(15,2) NOT NULL,
    interest_rate NUMERIC(5,4) NOT NULL,
    
    disbursement_date DATE,
    maturity_date DATE,
    
    status VARCHAR(20),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    FOREIGN KEY (account_id) REFERENCES accounts(id)
);

COMMENT ON TABLE loans IS '대출';
COMMENT ON COLUMN loans.loan_number IS '대출번호';
COMMENT ON COLUMN loans.account_id IS '대출 지급 계좌';
COMMENT ON COLUMN loans.loan_type IS '대출유형 (mortgage, personal, auto)';
COMMENT ON COLUMN loans.principal_amount IS '원금';
COMMENT ON COLUMN loans.interest_rate IS '이자율';
COMMENT ON COLUMN loans.disbursement_date IS '실행일';
COMMENT ON COLUMN loans.maturity_date IS '만기일';
COMMENT ON COLUMN loans.status IS '상태 (active, overdue, completed, defaulted)';

CREATE INDEX idx_loans_loan_number ON loans(loan_number);
CREATE INDEX idx_loans_account_id ON loans(account_id);
CREATE INDEX idx_loans_status ON loans(status);


-- ============================================
-- Tier 3: 대출 상환 스케줄 (Loan Schedules)
-- ============================================

CREATE TABLE loan_schedules (
    id BIGSERIAL PRIMARY KEY,
    loan_id BIGINT NOT NULL,
    
    due_date DATE NOT NULL,
    principal_amount NUMERIC(15,2),
    interest_amount NUMERIC(15,2),
    
    paid_date DATE,
    paid_amount NUMERIC(15,2),
    
    transaction_id BIGINT,
    
    FOREIGN KEY (loan_id) REFERENCES loans(id),
    FOREIGN KEY (transaction_id) REFERENCES transactions(id)
);

COMMENT ON TABLE loan_schedules IS '대출 상환 스케줄';
COMMENT ON COLUMN loan_schedules.due_date IS '납부일';
COMMENT ON COLUMN loan_schedules.principal_amount IS '원금';
COMMENT ON COLUMN loan_schedules.interest_amount IS '이자';
COMMENT ON COLUMN loan_schedules.paid_date IS '납부완료일';
COMMENT ON COLUMN loan_schedules.paid_amount IS '납부금액';
COMMENT ON COLUMN loan_schedules.transaction_id IS '실제 납부 거래';

CREATE INDEX idx_loan_schedules_loan_id ON loan_schedules(loan_id);
CREATE INDEX idx_loan_schedules_due_date ON loan_schedules(due_date);


-- ============================================
-- Tier 3: 계좌 변경 이력 (Account History)
-- ============================================

CREATE TABLE account_history (
    id BIGSERIAL PRIMARY KEY,
    account_id BIGINT NOT NULL,
    
    field_name VARCHAR(50),
    old_value TEXT,
    new_value TEXT,
    
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by VARCHAR(50),
    reason TEXT,
    
    FOREIGN KEY (account_id) REFERENCES accounts(id)
);

COMMENT ON TABLE account_history IS '계좌 변경 이력';
COMMENT ON COLUMN account_history.field_name IS '변경된 필드명';
COMMENT ON COLUMN account_history.old_value IS '이전 값';
COMMENT ON COLUMN account_history.new_value IS '새 값';
COMMENT ON COLUMN account_history.changed_by IS '변경자';
COMMENT ON COLUMN account_history.reason IS '변경 사유';

CREATE INDEX idx_account_history_account_id ON account_history(account_id);
CREATE INDEX idx_account_history_changed_at ON account_history(changed_at);


-- ============================================
-- Tier 3: 감사 로그 (Audit Logs)
-- ============================================

CREATE TABLE audit_logs (
    id BIGSERIAL PRIMARY KEY,
    
    table_name VARCHAR(50) NOT NULL,
    record_id BIGINT NOT NULL,
    action VARCHAR(20) NOT NULL,
    
    old_data JSONB,
    new_data JSONB,
    
    user_id VARCHAR(50),
    ip_address VARCHAR(50),
    
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE audit_logs IS '감사 로그';
COMMENT ON COLUMN audit_logs.table_name IS '테이블명';
COMMENT ON COLUMN audit_logs.record_id IS '레코드 ID';
COMMENT ON COLUMN audit_logs.action IS '액션 (INSERT, UPDATE, DELETE)';
COMMENT ON COLUMN audit_logs.old_data IS '변경 전 데이터';
COMMENT ON COLUMN audit_logs.new_data IS '변경 후 데이터';
COMMENT ON COLUMN audit_logs.user_id IS '사용자 ID';
COMMENT ON COLUMN audit_logs.ip_address IS 'IP 주소';

CREATE INDEX idx_audit_logs_table_record ON audit_logs(table_name, record_id);
CREATE INDEX idx_audit_logs_occurred_at ON audit_logs(occurred_at);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);


-- ============================================
-- 트리거: updated_at 자동 업데이트
-- ============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 각 테이블에 트리거 적용
CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_accounts_updated_at BEFORE UPDATE ON accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cards_updated_at BEFORE UPDATE ON cards
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_loans_updated_at BEFORE UPDATE ON loans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


-- ============================================
-- 트리거: 계좌 변경 시 이력 기록
-- ============================================

CREATE OR REPLACE FUNCTION log_account_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO account_history (account_id, field_name, old_value, new_value, changed_by)
        VALUES (NEW.id, 'status', OLD.status, NEW.status, NEW.updated_by);
    END IF;
    
    IF OLD.interest_rate IS DISTINCT FROM NEW.interest_rate THEN
        INSERT INTO account_history (account_id, field_name, old_value, new_value, changed_by)
        VALUES (NEW.id, 'interest_rate', OLD.interest_rate::TEXT, NEW.interest_rate::TEXT, NEW.updated_by);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER account_changes_trigger
AFTER UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION log_account_changes();


-- ============================================
-- 샘플 데이터
-- ============================================

INSERT INTO customers (customer_number, name, birth_date, phone, ci, kyc_verified, status)
VALUES 
    ('C0001', '홍길동', '1990-01-01', '010-1111-1111', 'CI_HONG', true, 'active'),
    ('C0002', '김철수', '1985-05-15', '010-2222-2222', 'CI_KIM', true, 'active'),
    ('C0003', '이영희', '1992-08-20', '010-3333-3333', 'CI_LEE', true, 'active');

INSERT INTO accounts (account_number, account_type, currency, status, interest_rate, opened_at)
VALUES 
    ('111-222-333', 'savings', 'KRW', 'active', 0.0200, NOW()),
    ('444-555-666', 'checking', 'KRW', 'active', 0.0100, NOW()),
    ('777-888-999', 'deposit', 'KRW', 'active', 0.0350, NOW());

INSERT INTO account_holders (account_id, customer_id, holder_type, relationship, effective_from)
VALUES 
    (1, 1, 'primary', 'owner', '2024-01-01'),
    (2, 1, 'primary', 'owner', '2024-01-01'),
    (2, 2, 'joint', 'spouse', '2024-01-01'),
    (3, 1, 'representative', 'ceo', '2024-01-01'),
    (3, 3, 'authorized', 'manager', '2024-01-01');

INSERT INTO transactions (transaction_number, from_account_id, to_account_id, amount, transaction_type, status, executed_at)
VALUES 
    ('T0001', NULL, 1, 1000000.00, 'deposit', 'completed', NOW()),
    ('T0002', 1, NULL, 50000.00, 'withdrawal', 'completed', NOW()),
    ('T0003', 1, 2, 100000.00, 'transfer', 'completed', NOW());

