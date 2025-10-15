-- ============================================
-- 인사 관리 시스템 데이터베이스 스키마 (PostgreSQL 16)
-- ============================================

-- ============================================
-- Tier 2: 부서 (Departments)
-- ============================================

CREATE TABLE departments (
    id BIGSERIAL PRIMARY KEY,
    department_code VARCHAR(20) UNIQUE NOT NULL,
    department_name VARCHAR(100) NOT NULL,
    
    -- 계층 구조
    parent_id BIGINT,
    manager_id BIGINT,
    
    status VARCHAR(20) DEFAULT 'active',
    
    established_date DATE,
    closed_date DATE,
    
    -- 감사 필드
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by VARCHAR(50),
    deleted_at TIMESTAMPTZ,
    
    FOREIGN KEY (parent_id) REFERENCES departments(id)
);

COMMENT ON TABLE departments IS '부서';
COMMENT ON COLUMN departments.department_code IS '부서코드';
COMMENT ON COLUMN departments.department_name IS '부서명';
COMMENT ON COLUMN departments.parent_id IS '상위 부서';
COMMENT ON COLUMN departments.manager_id IS '부서장 직원 ID';
COMMENT ON COLUMN departments.status IS '상태 (active, inactive)';
COMMENT ON COLUMN departments.established_date IS '설립일';
COMMENT ON COLUMN departments.closed_date IS '폐쇄일';
COMMENT ON COLUMN departments.deleted_at IS 'Soft Delete';

CREATE INDEX idx_departments_parent_id ON departments(parent_id);
CREATE INDEX idx_departments_manager_id ON departments(manager_id);
CREATE INDEX idx_departments_status ON departments(status);
CREATE INDEX idx_departments_deleted_at ON departments(deleted_at);


-- ============================================
-- Tier 1: 직급/직책 (Positions)
-- ============================================

CREATE TABLE positions (
    id BIGSERIAL PRIMARY KEY,
    position_code VARCHAR(20) UNIQUE NOT NULL,
    position_name VARCHAR(50) NOT NULL,
    
    level INT,
    
    min_salary NUMERIC(12,2),
    max_salary NUMERIC(12,2),
    
    description TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE positions IS '직급/직책';
COMMENT ON COLUMN positions.position_code IS '직급코드';
COMMENT ON COLUMN positions.position_name IS '직급명';
COMMENT ON COLUMN positions.level IS '직급 레벨 (1=사원, 2=대리, ...)';
COMMENT ON COLUMN positions.min_salary IS '최소 급여';
COMMENT ON COLUMN positions.max_salary IS '최대 급여';
COMMENT ON COLUMN positions.description IS '직급 설명';

CREATE INDEX idx_positions_level ON positions(level);


-- ============================================
-- Tier 0: 직원 (Employees)
-- ============================================

CREATE TABLE employees (
    id BIGSERIAL PRIMARY KEY,
    employee_number VARCHAR(20) UNIQUE NOT NULL,
    
    -- 기본 정보
    name VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    
    birth_date DATE,
    gender VARCHAR(10),
    
    -- 연락처
    email VARCHAR(100),
    phone VARCHAR(20),
    mobile VARCHAR(20),
    
    -- 주소
    address TEXT,
    postal_code VARCHAR(10),
    
    -- 민감 정보 (암호화 필요!)
    ssn_encrypted VARCHAR(200),
    bank_account_encrypted VARCHAR(200),
    
    -- 현재 직급
    current_position_id BIGINT,
    
    -- 재직 정보
    hire_date DATE NOT NULL,
    resignation_date DATE,
    
    employment_type VARCHAR(20) DEFAULT 'full_time',
    status VARCHAR(20) DEFAULT 'active',
    
    -- 감사 필드
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by VARCHAR(50),
    deleted_at TIMESTAMPTZ,
    
    FOREIGN KEY (current_position_id) REFERENCES positions(id)
);

COMMENT ON TABLE employees IS '직원';
COMMENT ON COLUMN employees.employee_number IS '사번';
COMMENT ON COLUMN employees.name IS '이름';
COMMENT ON COLUMN employees.name_en IS '영문명';
COMMENT ON COLUMN employees.birth_date IS '생년월일';
COMMENT ON COLUMN employees.gender IS '성별';
COMMENT ON COLUMN employees.email IS '이메일';
COMMENT ON COLUMN employees.phone IS '전화번호';
COMMENT ON COLUMN employees.mobile IS '휴대폰';
COMMENT ON COLUMN employees.address IS '주소';
COMMENT ON COLUMN employees.postal_code IS '우편번호';
COMMENT ON COLUMN employees.ssn_encrypted IS '주민번호 (암호화)';
COMMENT ON COLUMN employees.bank_account_encrypted IS '계좌번호 (암호화)';
COMMENT ON COLUMN employees.current_position_id IS '현재 직급';
COMMENT ON COLUMN employees.hire_date IS '입사일';
COMMENT ON COLUMN employees.resignation_date IS '퇴사일';
COMMENT ON COLUMN employees.employment_type IS '고용형태 (full_time, contract, part_time)';
COMMENT ON COLUMN employees.status IS '재직상태 (active, on_leave, resigned)';
COMMENT ON COLUMN employees.deleted_at IS 'Soft Delete (퇴사자 보존)';

CREATE INDEX idx_employees_employee_number ON employees(employee_number);
CREATE INDEX idx_employees_name ON employees(name);
CREATE INDEX idx_employees_status ON employees(status);
CREATE INDEX idx_employees_hire_date ON employees(hire_date);
CREATE INDEX idx_employees_deleted_at ON employees(deleted_at);


-- ============================================
-- Tier 2: 직원-부서 이력 (Employee Departments)
-- ============================================

CREATE TABLE employee_departments (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    department_id BIGINT NOT NULL,
    
    assignment_date DATE NOT NULL,
    release_date DATE,
    
    is_primary BOOLEAN DEFAULT true,
    role VARCHAR(50),
    reason TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(50),
    
    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (department_id) REFERENCES departments(id)
);

COMMENT ON TABLE employee_departments IS '직원-부서 발령 이력';
COMMENT ON COLUMN employee_departments.assignment_date IS '발령일';
COMMENT ON COLUMN employee_departments.release_date IS '해제일';
COMMENT ON COLUMN employee_departments.is_primary IS '주부서 여부';
COMMENT ON COLUMN employee_departments.role IS '역할 (member, manager, deputy)';
COMMENT ON COLUMN employee_departments.reason IS '발령 사유';

CREATE INDEX idx_employee_departments_employee_id ON employee_departments(employee_id);
CREATE INDEX idx_employee_departments_department_id ON employee_departments(department_id);
CREATE INDEX idx_employee_departments_assignment_date ON employee_departments(assignment_date);
CREATE INDEX idx_employee_departments_current ON employee_departments(release_date);


-- ============================================
-- Tier 1: 급여 이력 (Salaries)
-- ============================================

CREATE TABLE salaries (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    
    base_salary NUMERIC(12,2) NOT NULL,
    allowances NUMERIC(12,2) DEFAULT 0,
    bonus NUMERIC(12,2) DEFAULT 0,
    total_salary NUMERIC(12,2) GENERATED ALWAYS AS (base_salary + allowances + bonus) STORED,
    
    effective_from DATE NOT NULL,
    effective_to DATE,
    
    change_reason VARCHAR(100),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(50),
    
    FOREIGN KEY (employee_id) REFERENCES employees(id)
);

COMMENT ON TABLE salaries IS '급여 이력';
COMMENT ON COLUMN salaries.base_salary IS '기본급';
COMMENT ON COLUMN salaries.allowances IS '수당';
COMMENT ON COLUMN salaries.bonus IS '상여금';
COMMENT ON COLUMN salaries.total_salary IS '총 급여';
COMMENT ON COLUMN salaries.effective_from IS '적용 시작일';
COMMENT ON COLUMN salaries.effective_to IS '적용 종료일';
COMMENT ON COLUMN salaries.change_reason IS '변경 사유';

CREATE INDEX idx_salaries_employee_id ON salaries(employee_id);
CREATE INDEX idx_salaries_effective ON salaries(effective_from, effective_to);


-- ============================================
-- Tier 2: 근태 (Attendance)
-- ============================================

CREATE TABLE attendance (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    
    work_date DATE NOT NULL,
    
    check_in_time TIMESTAMPTZ,
    check_out_time TIMESTAMPTZ,
    
    work_minutes INT GENERATED ALWAYS AS (
        EXTRACT(EPOCH FROM (check_out_time - check_in_time)) / 60
    ) STORED,
    
    status VARCHAR(20),
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    FOREIGN KEY (employee_id) REFERENCES employees(id),
    UNIQUE (employee_id, work_date)
);

COMMENT ON TABLE attendance IS '근태 기록';
COMMENT ON COLUMN attendance.work_date IS '근무일';
COMMENT ON COLUMN attendance.check_in_time IS '출근 시간';
COMMENT ON COLUMN attendance.check_out_time IS '퇴근 시간';
COMMENT ON COLUMN attendance.work_minutes IS '근무 시간 (분)';
COMMENT ON COLUMN attendance.status IS '상태 (normal, late, early_leave, absent, holiday)';
COMMENT ON COLUMN attendance.notes IS '비고';

CREATE INDEX idx_attendance_work_date ON attendance(work_date);
CREATE INDEX idx_attendance_status ON attendance(status);


-- ============================================
-- Tier 2: 휴가 (Leaves)
-- ============================================

CREATE TABLE leaves (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    
    leave_type VARCHAR(20) NOT NULL,
    
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    days NUMERIC(3,1) NOT NULL,
    reason TEXT,
    
    status VARCHAR(20) DEFAULT 'pending',
    approver_id BIGINT,
    approved_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (approver_id) REFERENCES employees(id)
);

COMMENT ON TABLE leaves IS '휴가';
COMMENT ON COLUMN leaves.leave_type IS '휴가 유형 (annual, sick, special, unpaid)';
COMMENT ON COLUMN leaves.start_date IS '시작일';
COMMENT ON COLUMN leaves.end_date IS '종료일';
COMMENT ON COLUMN leaves.days IS '일수 (반차 0.5)';
COMMENT ON COLUMN leaves.reason IS '사유';
COMMENT ON COLUMN leaves.status IS '상태 (pending, approved, rejected, cancelled)';
COMMENT ON COLUMN leaves.approver_id IS '승인자';
COMMENT ON COLUMN leaves.approved_at IS '승인 일시';

CREATE INDEX idx_leaves_employee_id ON leaves(employee_id);
CREATE INDEX idx_leaves_dates ON leaves(start_date, end_date);
CREATE INDEX idx_leaves_status ON leaves(status);


-- ============================================
-- Tier 2: 성과평가 (Performance Reviews)
-- ============================================

CREATE TABLE performance_reviews (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    
    review_period VARCHAR(20) NOT NULL,
    review_year INT NOT NULL,
    
    score NUMERIC(4,2),
    grade VARCHAR(10),
    
    reviewer_id BIGINT,
    
    strengths TEXT,
    weaknesses TEXT,
    goals TEXT,
    comments TEXT,
    
    reviewed_at DATE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (reviewer_id) REFERENCES employees(id)
);

COMMENT ON TABLE performance_reviews IS '성과평가';
COMMENT ON COLUMN performance_reviews.review_period IS '평가 기간 (2024-Q1, 2024-H1)';
COMMENT ON COLUMN performance_reviews.review_year IS '평가 연도';
COMMENT ON COLUMN performance_reviews.score IS '종합 점수';
COMMENT ON COLUMN performance_reviews.grade IS '등급 (S, A, B, C, D)';
COMMENT ON COLUMN performance_reviews.reviewer_id IS '평가자';
COMMENT ON COLUMN performance_reviews.strengths IS '강점';
COMMENT ON COLUMN performance_reviews.weaknesses IS '약점';
COMMENT ON COLUMN performance_reviews.goals IS '목표';
COMMENT ON COLUMN performance_reviews.comments IS '종합 의견';
COMMENT ON COLUMN performance_reviews.reviewed_at IS '평가일';

CREATE INDEX idx_performance_reviews_employee_id ON performance_reviews(employee_id);
CREATE INDEX idx_performance_reviews_period ON performance_reviews(review_year, review_period);


-- ============================================
-- Tier 3: 직원 문서 (Employee Documents)
-- ============================================

CREATE TABLE employee_documents (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    
    document_type VARCHAR(50) NOT NULL,
    document_name VARCHAR(200) NOT NULL,
    
    file_path VARCHAR(500),
    file_size BIGINT,
    
    uploaded_at TIMESTAMPTZ DEFAULT NOW(),
    uploaded_by VARCHAR(50),
    
    is_confidential BOOLEAN DEFAULT false,
    
    FOREIGN KEY (employee_id) REFERENCES employees(id)
);

COMMENT ON TABLE employee_documents IS '직원 문서';
COMMENT ON COLUMN employee_documents.document_type IS '문서 유형 (contract, certificate, resume)';
COMMENT ON COLUMN employee_documents.document_name IS '문서명';
COMMENT ON COLUMN employee_documents.file_path IS '파일 경로';
COMMENT ON COLUMN employee_documents.file_size IS '파일 크기 (bytes)';
COMMENT ON COLUMN employee_documents.is_confidential IS '기밀 문서 여부';

CREATE INDEX idx_employee_documents_employee_id ON employee_documents(employee_id);
CREATE INDEX idx_employee_documents_document_type ON employee_documents(document_type);


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
-- 외래키 제약조건 추가 (departments.manager_id)
-- ============================================

ALTER TABLE departments
ADD CONSTRAINT fk_departments_manager
FOREIGN KEY (manager_id) REFERENCES employees(id);


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

CREATE TRIGGER update_departments_updated_at BEFORE UPDATE ON departments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_positions_updated_at BEFORE UPDATE ON positions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_employees_updated_at BEFORE UPDATE ON employees
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_attendance_updated_at BEFORE UPDATE ON attendance
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_leaves_updated_at BEFORE UPDATE ON leaves
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_performance_reviews_updated_at BEFORE UPDATE ON performance_reviews
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


-- ============================================
-- 샘플 데이터
-- ============================================

INSERT INTO positions (position_code, position_name, level, min_salary, max_salary)
VALUES 
    ('P01', '사원', 1, 2500000, 3500000),
    ('P02', '대리', 2, 3500000, 4500000),
    ('P03', '과장', 3, 4500000, 6000000),
    ('P04', '차장', 4, 6000000, 8000000),
    ('P05', '부장', 5, 8000000, 12000000);

INSERT INTO departments (department_code, department_name, parent_id, status)
VALUES 
    ('D001', '대표이사', NULL, 'active'),
    ('D010', '경영지원본부', 1, 'active'),
    ('D011', '인사팀', 2, 'active'),
    ('D012', '재무팀', 2, 'active'),
    ('D020', '개발본부', 1, 'active'),
    ('D021', 'Backend팀', 5, 'active'),
    ('D022', 'Frontend팀', 5, 'active');

INSERT INTO employees (employee_number, name, email, phone, hire_date, current_position_id, status)
VALUES 
    ('E2024001', '홍길동', 'hong@company.com', '010-1111-1111', '2024-01-01', 5, 'active'),
    ('E2024002', '김철수', 'kim@company.com', '010-2222-2222', '2024-02-01', 3, 'active'),
    ('E2024003', '이영희', 'lee@company.com', '010-3333-3333', '2024-03-01', 2, 'active');

INSERT INTO employee_departments (employee_id, department_id, assignment_date, is_primary, role)
VALUES 
    (1, 1, '2024-01-01', true, 'manager'),
    (2, 3, '2024-02-01', true, 'manager'),
    (3, 6, '2024-03-01', true, 'member');

INSERT INTO salaries (employee_id, base_salary, allowances, effective_from)
VALUES 
    (1, 10000000, 500000, '2024-01-01'),
    (2, 5000000, 300000, '2024-02-01'),
    (3, 3500000, 200000, '2024-03-01');

