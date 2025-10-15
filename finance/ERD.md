# 은행 시스템 ERD (Entity Relationship Diagram)

## 📊 전체 구조 다이어그램

```mermaid
erDiagram
    customers {
        bigint id PK
        varchar customer_number UK "고객번호"
        varchar name "이름"
        date birth_date "생년월일"
        varchar phone "전화번호"
        varchar email "이메일"
        varchar ci UK "CI (중복가입방지)"
        varchar di "DI"
        boolean kyc_verified "본인인증 여부"
        timestamp kyc_verified_at "본인인증 일시"
        varchar verification_method "인증수단 (PASS, NICE, KAKAO)"
        varchar status "상태 (active, dormant, closed)"
        timestamp created_at
        varchar created_by
        timestamp updated_at
        varchar updated_by
        timestamp deleted_at "Soft Delete"
    }

    accounts {
        bigint id PK
        varchar account_number UK "계좌번호"
        varchar account_type "계좌유형 (savings, checking, deposit)"
        varchar currency "통화"
        varchar status "상태 (active, frozen, closed)"
        decimal interest_rate "이자율"
        timestamp opened_at "개설일"
        timestamp closed_at "해지일"
        timestamp created_at
        varchar created_by
        timestamp updated_at
        varchar updated_by
        timestamp deleted_at "Soft Delete"
    }

    account_holders {
        bigint account_id FK
        bigint customer_id FK
        varchar holder_type "보유자유형 (primary, joint, authorized)"
        varchar relationship "관계 (owner, spouse, representative)"
        date effective_from "유효시작일"
        date effective_to "유효종료일"
    }

    transactions {
        bigint id PK
        varchar transaction_number UK "거래번호"
        bigint from_account_id FK "출금계좌"
        bigint to_account_id FK "입금계좌"
        decimal amount "금액"
        varchar currency "통화"
        varchar transaction_type "거래유형 (deposit, withdrawal, transfer, interest, fee)"
        varchar status "상태 (pending, completed, failed, cancelled, reversed)"
        text description "설명"
        timestamp executed_at "실행일시"
        varchar executed_by "실행자"
        bigint original_transaction_id FK "원거래 ID (취소 시)"
        bigint reversed_transaction_id "취소 거래 ID"
        varchar external_reference "외부 시스템 참조번호"
        timestamp created_at
    }

    transaction_details {
        bigint id PK
        bigint transaction_id FK
        varchar detail_type "상세유형 (fee, tax, exchange, memo)"
        varchar detail_key "키"
        text detail_value "값"
        timestamp created_at
    }

    account_balances {
        bigint account_id PK
        decimal balance "잔액"
        date as_of_date "기준일"
        bigint last_transaction_id FK "마지막 반영 거래 ID"
        timestamp updated_at
    }

    cards {
        bigint id PK
        varchar card_number UK "카드번호 (암호화 필요!)"
        varchar card_type "카드유형 (debit, credit, prepaid)"
        bigint account_id FK "연결 계좌"
        date issue_date "발급일"
        date expiry_date "만료일"
        varchar status "상태 (active, blocked, lost, expired)"
        decimal daily_limit "일일한도"
        timestamp created_at
        timestamp updated_at
        timestamp deleted_at
    }

    loans {
        bigint id PK
        varchar loan_number UK "대출번호"
        bigint account_id FK "대출 지급 계좌"
        varchar loan_type "대출유형 (mortgage, personal, auto)"
        decimal principal_amount "원금"
        decimal interest_rate "이자율"
        date disbursement_date "실행일"
        date maturity_date "만기일"
        varchar status "상태 (active, overdue, completed, defaulted)"
        timestamp created_at
        timestamp updated_at
    }

    loan_schedules {
        bigint id PK
        bigint loan_id FK
        date due_date "납부일"
        decimal principal_amount "원금"
        decimal interest_amount "이자"
        date paid_date "납부완료일"
        decimal paid_amount "납부금액"
        bigint transaction_id FK "실제 납부 거래"
    }

    account_history {
        bigint id PK
        bigint account_id FK
        varchar field_name "변경된 필드명"
        text old_value "이전 값"
        text new_value "새 값"
        timestamp changed_at
        varchar changed_by "변경자"
        text reason "변경 사유"
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
    loans ||--o{ loan_schedules : "loan_id"
    accounts ||--o{ cards : "account_id"
    transactions ||--o{ account_balances : "last_transaction_id"
    accounts ||--o{ account_history : "account_id"
    transactions ||--o{ transactions : "original_transaction_id"
    transactions ||--o{ loan_schedules : "transaction_id"
    customers ||--o{ account_holders : "customer_id"
    accounts ||--o{ transactions : "from_account_id"
    accounts ||--o{ transactions : "to_account_id"
    accounts ||--o{ account_holders : "account_id"
    accounts ||--o{ account_balances : "account_id"
    transactions ||--o{ transaction_details : "transaction_id"
    accounts ||--o{ loans : "account_id"
```

---

## 🎯 핵심 관계 설명

### 1. customers ↔ accounts (N:M)
```
중간 테이블: account_holders

이유:
- 공동명의 계좌 (한 계좌에 여러 고객)
- 한 고객이 여러 계좌 보유
- 권한별 구분 (owner, joint, authorized)
```

**예시:**
```
고객 A + 고객 B → 공동 계좌 #100
고객 A → 개인 계좌 #200
고객 A (대표) + 고객 C (권한자) → 법인 계좌 #300
```

---

### 2. accounts → transactions (1:N)
```
한 계좌에 여러 거래

특징:
- from_account_id (출금)
- to_account_id (입금)
- 둘 다 있으면 이체
- 한쪽만 있으면 입출금
```

**예시:**
```
거래 #1: from=NULL, to=100 → 계좌 #100 입금
거래 #2: from=100, to=NULL → 계좌 #100 출금
거래 #3: from=100, to=200 → 계좌 #100→#200 이체
```

---

### 3. transactions → transactions (자기참조)
```
취소/정정 관계

original_transaction_id: 원래 거래
reversed_transaction_id: 취소 거래
```

**예시:**
```
거래 #100: A → B (10,000원)
거래 #101: B → A (10,000원) + original_transaction_id=100

→ 거래 #100 취소됨
```

---

### 4. accounts → account_balances (1:1)
```
잔액 캐시 (성능 최적화)

실제 잔액: transactions로 계산
캐시 잔액: 빠른 조회용

매일 밤 배치로 동기화
```

---

## 📋 테이블별 역할

### Tier 0 (최고 핵심)
| 테이블 | 역할 | 특징 |
|--------|------|------|
| **accounts** | 계좌 관리 | 돈의 그릇 |
| **transactions** | 거래 기록 | 진실의 원천 |

### Tier 1 (메인)
| 테이블 | 역할 | 특징 |
|--------|------|------|
| **customers** | 고객 정보 | 본인인증 필수 |

### Tier 2 (중요 지원)
| 테이블 | 역할 | 특징 |
|--------|------|------|
| **account_holders** | 계좌-고객 관계 | N:M 처리 |
| **cards** | 카드 관리 | 계좌 연결 |
| **loans** | 대출 관리 | 상환 스케줄 |

### Tier 3 (지원)
| 테이블 | 역할 | 특징 |
|--------|------|------|
| **account_balances** | 잔액 캐시 | 성능 최적화 |
| **transaction_details** | 거래 상세 | 추가 정보 |
| **loan_schedules** | 상환 스케줄 | 대출 세부 |

---

## 🔍 주요 쿼리 패턴

### 1. 계좌 잔액 조회
```sql
SELECT 
    a.account_number,
    COALESCE(SUM(
        CASE 
            WHEN t.to_account_id = a.id THEN t.amount
            WHEN t.from_account_id = a.id THEN -t.amount
        END
    ), 0) as balance
FROM accounts a
LEFT JOIN transactions t 
    ON (t.to_account_id = a.id OR t.from_account_id = a.id)
    AND t.status = 'completed'
WHERE a.id = ?
GROUP BY a.id, a.account_number;
```

### 2. 고객의 모든 계좌 조회
```sql
SELECT 
    c.name,
    a.account_number,
    ah.holder_type
FROM customers c
JOIN account_holders ah ON c.id = ah.customer_id
JOIN accounts a ON ah.account_id = a.id
WHERE c.id = ?
    AND ah.effective_to IS NULL  -- 현재 유효한 것만
    AND a.deleted_at IS NULL;
```

### 3. 거래 내역 (잔액 포함)
```sql
SELECT 
    t.transaction_number,
    t.executed_at,
    CASE 
        WHEN t.from_account_id = ? THEN '출금'
        WHEN t.to_account_id = ? THEN '입금'
    END as type,
    t.amount,
    SUM(
        CASE 
            WHEN t2.to_account_id = ? THEN t2.amount
            WHEN t2.from_account_id = ? THEN -t2.amount
        END
    ) OVER (ORDER BY t2.executed_at) as balance
FROM transactions t
LEFT JOIN transactions t2 
    ON t2.id <= t.id 
    AND t2.status = 'completed'
WHERE (t.from_account_id = ? OR t.to_account_id = ?)
    AND t.status = 'completed'
ORDER BY t.executed_at DESC;
```

---

## 🚨 설계 체크리스트

### 필수 확인사항:
- [ ] 모든 테이블에 created_at, updated_at
- [ ] 모든 테이블에 deleted_at (soft delete)
- [ ] 모든 금액 필드는 DECIMAL(15,2)
- [ ] transactions 테이블 절대 DELETE 금지
- [ ] 잔액은 직접 저장 금지 (계산으로 구함)
- [ ] 모든 거래는 DB 트랜잭션 내에서
- [ ] 취소는 역거래로 처리
- [ ] 감사 필드 (created_by, updated_by) 필수

---

## 💡 핵심 원칙

```
1. 절대 삭제 금지 → Soft Delete
2. 모든 변경 이력 보존 → 감사 추적
3. 잔액은 계산 → 거래가 진실
4. 관계는 분리 → N:M 대비
5. 확장성 < 정확성 → 보수적 설계
```


