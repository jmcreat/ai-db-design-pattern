# 인사 관리 시스템 ERD (Entity Relationship Diagram)

## 📊 전체 구조 다이어그램

```mermaid
erDiagram
    departments {
        bigint id PK
        varchar department_code UK "부서코드"
        varchar department_name "부서명"
        bigint parent_id FK "상위 부서"
        bigint manager_id "부서장 직원 ID"
        varchar status "상태 (active, inactive)"
        date established_date "설립일"
        date closed_date "폐쇄일"
        timestamp created_at
        varchar created_by
        timestamp updated_at
        varchar updated_by
        timestamp deleted_at "Soft Delete"
    }

    positions {
        bigint id PK
        varchar position_code UK "직급코드"
        varchar position_name "직급명"
        int level "직급 레벨 (1=사원, 2=대리, ...)"
        decimal min_salary "최소 급여"
        decimal max_salary "최대 급여"
        text description "직급 설명"
        timestamp created_at
        timestamp updated_at
    }

    employees {
        bigint id PK
        varchar employee_number UK "사번"
        varchar name "이름"
        varchar name_en "영문명"
        date birth_date "생년월일"
        varchar gender "성별"
        varchar email "이메일"
        varchar phone "전화번호"
        varchar mobile "휴대폰"
        text address "주소"
        varchar postal_code "우편번호"
        varchar ssn_encrypted "주민번호 (암호화)"
        varchar bank_account_encrypted "계좌번호 (암호화)"
        bigint current_position_id FK "현재 직급"
        date hire_date "입사일"
        date resignation_date "퇴사일"
        varchar employment_type "고용형태 (full_time, contract, part_time)"
        varchar status "재직상태 (active, on_leave, resigned)"
        timestamp created_at
        varchar created_by
        timestamp updated_at
        varchar updated_by
        timestamp deleted_at "Soft Delete (퇴사자 보존)"
    }

    employee_departments {
        bigint id PK
        bigint employee_id FK
        bigint department_id FK
        date assignment_date "발령일"
        date release_date "해제일"
        boolean is_primary "주부서 여부"
        varchar role "역할 (member, manager, deputy)"
        text reason "발령 사유"
        timestamp created_at
        varchar created_by
    }

    salaries {
        bigint id PK
        bigint employee_id FK
        decimal base_salary "기본급"
        decimal allowances "수당"
        decimal bonus "상여금"
        decimal total_salary "총 급여"
        date effective_from "적용 시작일"
        date effective_to "적용 종료일"
        varchar change_reason "변경 사유"
        timestamp created_at
        varchar created_by
    }

    attendance {
        bigint id PK
        bigint employee_id FK
        date work_date "근무일"
        int work_minutes
        varchar status "상태 (normal, late, early_leave, absent, holiday)"
        text notes "비고"
        timestamp created_at
        timestamp updated_at
    }

    leaves {
        bigint id PK
        bigint employee_id FK
        varchar leave_type "휴가 유형 (annual, sick, special, unpaid)"
        date start_date "시작일"
        date end_date "종료일"
        decimal days "일수 (반차 0.5)"
        text reason "사유"
        varchar status "상태 (pending, approved, rejected, cancelled)"
        bigint approver_id FK "승인자"
        timestamp approved_at "승인 일시"
        timestamp created_at
        varchar created_by
        timestamp updated_at
    }

    performance_reviews {
        bigint id PK
        bigint employee_id FK
        varchar review_period "평가 기간 (2024-Q1, 2024-H1)"
        int review_year "평가 연도"
        decimal score "종합 점수"
        varchar grade "등급 (S, A, B, C, D)"
        bigint reviewer_id FK "평가자"
        text strengths "강점"
        text weaknesses "약점"
        text goals "목표"
        text comments "종합 의견"
        date reviewed_at "평가일"
        timestamp created_at
        timestamp updated_at
    }

    employee_documents {
        bigint id PK
        bigint employee_id FK
        varchar document_type "문서 유형 (contract, certificate, resume)"
        varchar document_name "문서명"
        varchar file_path "파일 경로"
        bigint file_size "파일 크기 (bytes)"
        timestamp uploaded_at
        varchar uploaded_by
        boolean is_confidential "기밀 문서 여부"
    }

    audit_logs {
        bigint id PK
        varchar table_name "테이블명"
        bigint record_id "레코드 ID"
        varchar action "액션 (INSERT, UPDATE, DELETE)"
        text old_data "변경 전 데이터"
        text new_data "변경 후 데이터"
        varchar user_id "사용자 ID"
        varchar ip_address "IP 주소"
        timestamp occurred_at
    }

    %% Relationships
    departments ||--o{ departments : "parent_id"
    employees ||--o{ leaves : "approver_id"
    employees ||--o{ performance_reviews : "employee_id"
    departments ||--o{ employee_departments : "department_id"
    employees ||--o{ salaries : "employee_id"
    employees ||--o{ leaves : "employee_id"
    employees ||--o{ performance_reviews : "reviewer_id"
    employees ||--o{ employee_departments : "employee_id"
    positions ||--o{ employees : "current_position_id"
    employees ||--o{ attendance : "employee_id"
    employees ||--o{ employee_documents : "employee_id"
```

---

## 🎯 핵심 관계 설명

### 1. employees ↔ departments (N:M)
```
중간 테이블: employee_departments

이유:
- 부서 이동 이력 추적
- 겸직 가능 (주부서 + 겸직 부서)
- 시점별 소속 부서 관리
```

**예시:**
```
직원 A:
├─ 2024-01-01 ~ 2024-06-30: 개발팀
└─ 2024-07-01 ~ 현재: 기획팀 (부서 이동)

직원 B:
├─ 주부서: 개발팀
└─ 겸직: 품질관리팀
```

---

### 2. employees → salaries (1:N)
```
급여 변경 이력 추적

한 직원의 여러 급여 이력:
- 입사 시: 3,000,000원
- 1년 후: 3,500,000원 (인상)
- 2년 후: 4,000,000원 (인상)
```

---

### 3. departments → departments (Self Reference)
```
부서 계층 구조

예시:
본사
├─ 경영지원본부
│   ├─ 인사팀
│   └─ 재무팀
└─ 개발본부
    ├─ Backend팀
    └─ Frontend팀
```

---

### 4. employees → attendance (1:N)
```
일별 근태 기록

한 직원의 여러 출근 기록:
- 2024-10-01: 09:00 ~ 18:00
- 2024-10-02: 09:30 ~ 18:00 (지각)
- 2024-10-03: 휴가
```

---

## 📋 테이블별 역할

### Tier 0 (최고 핵심)
| 테이블 | 역할 | 특징 |
|--------|------|------|
| **employees** | 직원 정보 | 모든 것의 중심 |
| **departments** | 부서 정보 | 조직 구조 |

### Tier 1 (메인)
| 테이블 | 역할 | 특징 |
|--------|------|------|
| **positions** | 직급 체계 | 급여 범위 포함 |
| **salaries** | 급여 이력 | 변경 추적 |
| **employee_departments** | 소속 이력 | N:M 관계 |

### Tier 2 (지원)
| 테이블 | 역할 | 특징 |
|--------|------|------|
| **attendance** | 근태 기록 | 일별 출퇴근 |
| **leaves** | 휴가 관리 | 승인 프로세스 |
| **performance_reviews** | 성과평가 | 정기 평가 |

### Tier 3 (부가)
| 테이블 | 역할 | 특징 |
|--------|------|------|
| **employee_documents** | 문서 관리 | 파일 보관 |
| **audit_logs** | 감사 로그 | 변경 추적 |

---

## 🔍 주요 쿼리 패턴

### 1. 현재 소속 부서 조회
```sql
SELECT 
    e.name,
    d.department_name,
    ed.assignment_date
FROM employees e
JOIN employee_departments ed ON e.id = ed.employee_id
JOIN departments d ON ed.department_id = d.id
WHERE ed.release_date IS NULL  -- 현재 소속
    AND e.status = 'active';
```

### 2. 부서 조직도 (계층)
```sql
WITH RECURSIVE dept_tree AS (
    -- 루트 부서
    SELECT id, department_name, parent_id, 0 as level
    FROM departments
    WHERE parent_id IS NULL
    
    UNION ALL
    
    -- 하위 부서
    SELECT d.id, d.department_name, d.parent_id, dt.level + 1
    FROM departments d
    JOIN dept_tree dt ON d.parent_id = dt.id
)
SELECT * FROM dept_tree ORDER BY level, id;
```

### 3. 급여 이력
```sql
SELECT 
    e.name,
    s.base_salary,
    s.effective_from,
    s.change_reason
FROM employees e
JOIN salaries s ON e.id = s.employee_id
WHERE e.id = 1
ORDER BY s.effective_from DESC;
```

---

## 🚨 설계 체크리스트

### 필수 확인사항:
- [x] 모든 테이블에 created_at, updated_at
- [x] employees, departments에 deleted_at (soft delete)
- [x] 민감 정보 암호화 컬럼 (_encrypted 접미사)
- [x] 이력 테이블 (salaries, employee_departments)
- [x] 외래키 제약조건
- [x] 감사 필드 (created_by, updated_by)
- [x] 적절한 인덱스

---

## 💡 핵심 원칙

```
1. 이력 보존 → salaries, employee_departments
2. Soft Delete → employees, departments
3. 암호화 → ssn, bank_account
4. 감사 로그 → 모든 변경 추적
5. 계층 구조 → departments self-reference
```

---

## 🔗 관계 요약

```
employees (직원) ⭐⭐⭐
    ↓
├─ employee_departments → departments (부서)
├─ salaries (급여 이력)
├─ attendance (근태)
├─ leaves (휴가)
├─ performance_reviews (평가)
└─ employee_documents (문서)

departments (부서) ⭐⭐
    ↓ self-reference
departments (상위 부서)
```

---

**ERD는 `make erd-hr` 또는 `python update_erd.py hr` 명령으로 자동 생성됩니다.**

