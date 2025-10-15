-- ============================================
-- 인사 관리 시스템 데이터베이스 스키마
-- ============================================

-- ============================================
-- Tier 2: 부서 (Departments)
-- ============================================

CREATE TABLE departments (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    department_code VARCHAR(20) UNIQUE NOT NULL COMMENT '부서코드',
    department_name VARCHAR(100) NOT NULL COMMENT '부서명',
    
    -- 계층 구조 (self-reference)
    parent_id BIGINT NULL COMMENT '상위 부서',
    
    -- 부서장
    manager_id BIGINT NULL COMMENT '부서장 직원 ID',
    
    -- 상태
    status VARCHAR(20) DEFAULT 'active' COMMENT '상태 (active, inactive)',
    
    established_date DATE COMMENT '설립일',
    closed_date DATE COMMENT '폐쇄일',
    
    -- 감사 필드
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50),
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    updated_by VARCHAR(50),
    deleted_at TIMESTAMP NULL COMMENT 'Soft Delete',
    
    FOREIGN KEY (parent_id) REFERENCES departments(id),
    
    INDEX idx_parent_id (parent_id),
    INDEX idx_manager_id (manager_id),
    INDEX idx_status (status),
    INDEX idx_deleted_at (deleted_at)
) COMMENT='부서';


-- ============================================
-- Tier 1: 직급/직책 (Positions)
-- ============================================

CREATE TABLE positions (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    position_code VARCHAR(20) UNIQUE NOT NULL COMMENT '직급코드',
    position_name VARCHAR(50) NOT NULL COMMENT '직급명',
    
    level INT COMMENT '직급 레벨 (1=사원, 2=대리, ...)',
    
    -- 급여 범위
    min_salary DECIMAL(12,2) COMMENT '최소 급여',
    max_salary DECIMAL(12,2) COMMENT '최대 급여',
    
    description TEXT COMMENT '직급 설명',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_level (level)
) COMMENT='직급/직책';


-- ============================================
-- Tier 0: 직원 (Employees) - 핵심!
-- ============================================

CREATE TABLE employees (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    employee_number VARCHAR(20) UNIQUE NOT NULL COMMENT '사번',
    
    -- 기본 정보
    name VARCHAR(100) NOT NULL COMMENT '이름',
    name_en VARCHAR(100) COMMENT '영문명',
    
    birth_date DATE COMMENT '생년월일',
    gender VARCHAR(10) COMMENT '성별',
    
    -- 연락처
    email VARCHAR(100) COMMENT '이메일',
    phone VARCHAR(20) COMMENT '전화번호',
    mobile VARCHAR(20) COMMENT '휴대폰',
    
    -- 주소
    address TEXT COMMENT '주소',
    postal_code VARCHAR(10) COMMENT '우편번호',
    
    -- 민감 정보 (암호화 필요!)
    ssn_encrypted VARCHAR(200) COMMENT '주민번호 (암호화)',
    bank_account_encrypted VARCHAR(200) COMMENT '계좌번호 (암호화)',
    
    -- 현재 직급
    current_position_id BIGINT COMMENT '현재 직급',
    
    -- 재직 정보
    hire_date DATE NOT NULL COMMENT '입사일',
    resignation_date DATE COMMENT '퇴사일',
    
    employment_type VARCHAR(20) DEFAULT 'full_time' COMMENT '고용형태 (full_time, contract, part_time)',
    status VARCHAR(20) DEFAULT 'active' COMMENT '재직상태 (active, on_leave, resigned)',
    
    -- 감사 필드
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50),
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    updated_by VARCHAR(50),
    deleted_at TIMESTAMP NULL COMMENT 'Soft Delete (퇴사자 보존)',
    
    FOREIGN KEY (current_position_id) REFERENCES positions(id),
    
    INDEX idx_employee_number (employee_number),
    INDEX idx_name (name),
    INDEX idx_status (status),
    INDEX idx_hire_date (hire_date),
    INDEX idx_deleted_at (deleted_at)
) COMMENT='직원';


-- ============================================
-- Tier 2: 직원-부서 이력 (Employee Departments)
-- ============================================

CREATE TABLE employee_departments (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    employee_id BIGINT NOT NULL,
    department_id BIGINT NOT NULL,
    
    -- 발령 정보
    assignment_date DATE NOT NULL COMMENT '발령일',
    release_date DATE NULL COMMENT '해제일',
    
    is_primary BOOLEAN DEFAULT TRUE COMMENT '주부서 여부',
    
    role VARCHAR(50) COMMENT '역할 (member, manager, deputy)',
    
    reason TEXT COMMENT '발령 사유',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50),
    
    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (department_id) REFERENCES departments(id),
    
    INDEX idx_employee_id (employee_id),
    INDEX idx_department_id (department_id),
    INDEX idx_assignment_date (assignment_date),
    INDEX idx_current (release_date)
) COMMENT='직원-부서 발령 이력';


-- ============================================
-- Tier 1: 급여 이력 (Salaries)
-- ============================================

CREATE TABLE salaries (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    employee_id BIGINT NOT NULL,
    
    -- 급여 정보
    base_salary DECIMAL(12,2) NOT NULL COMMENT '기본급',
    allowances DECIMAL(12,2) DEFAULT 0 COMMENT '수당',
    bonus DECIMAL(12,2) DEFAULT 0 COMMENT '상여금',
    
    total_salary DECIMAL(12,2) GENERATED ALWAYS AS (base_salary + allowances + bonus) STORED COMMENT '총 급여',
    
    -- 유효 기간
    effective_from DATE NOT NULL COMMENT '적용 시작일',
    effective_to DATE NULL COMMENT '적용 종료일',
    
    change_reason VARCHAR(100) COMMENT '변경 사유',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50),
    
    FOREIGN KEY (employee_id) REFERENCES employees(id),
    
    INDEX idx_employee_id (employee_id),
    INDEX idx_effective (effective_from, effective_to)
) COMMENT='급여 이력';


-- ============================================
-- Tier 2: 근태 (Attendance)
-- ============================================

CREATE TABLE attendance (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    employee_id BIGINT NOT NULL,
    
    work_date DATE NOT NULL COMMENT '근무일',
    
    -- 출퇴근 시간
    check_in_time TIMESTAMP COMMENT '출근 시간',
    check_out_time TIMESTAMP COMMENT '퇴근 시간',
    
    -- 근무 시간 (분)
    work_minutes INT GENERATED ALWAYS AS (
        TIMESTAMPDIFF(MINUTE, check_in_time, check_out_time)
    ) STORED COMMENT '근무 시간 (분)',
    
    -- 상태
    status VARCHAR(20) COMMENT '상태 (normal, late, early_leave, absent, holiday)',
    
    notes TEXT COMMENT '비고',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (employee_id) REFERENCES employees(id),
    
    UNIQUE KEY unique_employee_date (employee_id, work_date),
    INDEX idx_work_date (work_date),
    INDEX idx_status (status)
) COMMENT='근태 기록';


-- ============================================
-- Tier 2: 휴가 (Leaves)
-- ============================================

CREATE TABLE leaves (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    employee_id BIGINT NOT NULL,
    
    leave_type VARCHAR(20) NOT NULL COMMENT '휴가 유형 (annual, sick, special, unpaid)',
    
    start_date DATE NOT NULL COMMENT '시작일',
    end_date DATE NOT NULL COMMENT '종료일',
    
    days DECIMAL(3,1) NOT NULL COMMENT '일수 (반차 0.5)',
    
    reason TEXT COMMENT '사유',
    
    -- 승인
    status VARCHAR(20) DEFAULT 'pending' COMMENT '상태 (pending, approved, rejected, cancelled)',
    approver_id BIGINT COMMENT '승인자',
    approved_at TIMESTAMP COMMENT '승인 일시',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50),
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (approver_id) REFERENCES employees(id),
    
    INDEX idx_employee_id (employee_id),
    INDEX idx_dates (start_date, end_date),
    INDEX idx_status (status)
) COMMENT='휴가';


-- ============================================
-- Tier 2: 성과평가 (Performance Reviews)
-- ============================================

CREATE TABLE performance_reviews (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    employee_id BIGINT NOT NULL,
    
    review_period VARCHAR(20) NOT NULL COMMENT '평가 기간 (2024-Q1, 2024-H1)',
    review_year INT NOT NULL COMMENT '평가 연도',
    
    -- 평가 점수
    score DECIMAL(4,2) COMMENT '종합 점수',
    grade VARCHAR(10) COMMENT '등급 (S, A, B, C, D)',
    
    -- 평가자
    reviewer_id BIGINT COMMENT '평가자',
    
    -- 평가 내용
    strengths TEXT COMMENT '강점',
    weaknesses TEXT COMMENT '약점',
    goals TEXT COMMENT '목표',
    
    comments TEXT COMMENT '종합 의견',
    
    reviewed_at DATE COMMENT '평가일',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (reviewer_id) REFERENCES employees(id),
    
    INDEX idx_employee_id (employee_id),
    INDEX idx_review_period (review_year, review_period)
) COMMENT='성과평가';


-- ============================================
-- Tier 3: 직원 문서 (Employee Documents)
-- ============================================

CREATE TABLE employee_documents (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    employee_id BIGINT NOT NULL,
    
    document_type VARCHAR(50) NOT NULL COMMENT '문서 유형 (contract, certificate, resume)',
    document_name VARCHAR(200) NOT NULL COMMENT '문서명',
    
    file_path VARCHAR(500) COMMENT '파일 경로',
    file_size BIGINT COMMENT '파일 크기 (bytes)',
    
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    uploaded_by VARCHAR(50),
    
    -- 보안
    is_confidential BOOLEAN DEFAULT FALSE COMMENT '기밀 문서 여부',
    
    FOREIGN KEY (employee_id) REFERENCES employees(id),
    
    INDEX idx_employee_id (employee_id),
    INDEX idx_document_type (document_type)
) COMMENT='직원 문서';


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
-- 외래키 제약조건 추가 (departments.manager_id)
-- ============================================

ALTER TABLE departments
ADD CONSTRAINT fk_departments_manager
FOREIGN KEY (manager_id) REFERENCES employees(id);


-- ============================================
-- 샘플 데이터
-- ============================================

-- 직급
INSERT INTO positions (position_code, position_name, level, min_salary, max_salary)
VALUES 
    ('P01', '사원', 1, 2500000, 3500000),
    ('P02', '대리', 2, 3500000, 4500000),
    ('P03', '과장', 3, 4500000, 6000000),
    ('P04', '차장', 4, 6000000, 8000000),
    ('P05', '부장', 5, 8000000, 12000000);

-- 부서
INSERT INTO departments (department_code, department_name, parent_id, status)
VALUES 
    ('D001', '대표이사', NULL, 'active'),
    ('D010', '경영지원본부', 1, 'active'),
    ('D011', '인사팀', 2, 'active'),
    ('D012', '재무팀', 2, 'active'),
    ('D020', '개발본부', 1, 'active'),
    ('D021', 'Backend팀', 5, 'active'),
    ('D022', 'Frontend팀', 5, 'active');

-- 직원
INSERT INTO employees (employee_number, name, email, phone, hire_date, current_position_id, status)
VALUES 
    ('E2024001', '홍길동', 'hong@company.com', '010-1111-1111', '2024-01-01', 5, 'active'),
    ('E2024002', '김철수', 'kim@company.com', '010-2222-2222', '2024-02-01', 3, 'active'),
    ('E2024003', '이영희', 'lee@company.com', '010-3333-3333', '2024-03-01', 2, 'active');

-- 직원-부서 배정
INSERT INTO employee_departments (employee_id, department_id, assignment_date, is_primary, role)
VALUES 
    (1, 1, '2024-01-01', TRUE, 'manager'),  -- 홍길동 - 대표이사
    (2, 3, '2024-02-01', TRUE, 'manager'),  -- 김철수 - 인사팀장
    (3, 6, '2024-03-01', TRUE, 'member');   -- 이영희 - Backend팀

-- 급여
INSERT INTO salaries (employee_id, base_salary, allowances, effective_from)
VALUES 
    (1, 10000000, 500000, '2024-01-01'),
    (2, 5000000, 300000, '2024-02-01'),
    (3, 3500000, 200000, '2024-03-01');

