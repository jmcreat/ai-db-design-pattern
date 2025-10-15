# 은행 시스템 데이터베이스 설계

## 📦 데이터베이스 버전

이 스키마는 **MySQL**과 **PostgreSQL 16** 두 가지 버전으로 제공됩니다:

- **`schema.sql`** - MySQL 8.0+ 버전
- **`schema_postgres.sql`** - PostgreSQL 16 버전 (PostGIS 지원)

## 📊 핵심 개념

```
Tier 0 (최고 핵심):
├─ accounts (계좌) ⭐⭐⭐
└─ transactions (거래) ⭐⭐⭐

Tier 1 (메인):
└─ customers (고객) ⭐⭐

Tier 2 (지원):
├─ account_holders (계좌-고객 관계)
├─ cards (카드)
└─ loans (대출)
```

## 🎯 설계 원칙

### 1. 절대 DELETE 금지 ❌
```sql
-- ❌ 절대 안됨
DELETE FROM transactions;
DELETE FROM accounts;

-- ✅ Soft Delete만
UPDATE customers SET deleted_at = NOW();
UPDATE accounts SET status = 'closed';
```

### 2. 모든 변경 이력 보존 📝
- 모든 거래는 영구 보존
- 취소는 역거래로 처리
- 감사 추적 필수

### 3. 트랜잭션 무결성 🔒
- 모든 거래는 DB 트랜잭션 내에서
- SERIALIZABLE 격리 수준
- 1원도 틀리면 안됨

### 4. 이중 기입 (Double Entry) 💰
```
모든 거래는 from/to 명확
잔액은 직접 저장하지 않고 계산
```

---

## 📋 파일 구조

```
finance/
├─ README.md          (이 파일)
├─ ERD.md             (ERD 다이어그램)
├─ schema.sql         (테이블 정의)
└─ sample_queries.sql (주요 쿼리)
```

---

## 🔑 주요 테이블 설명

### customers (고객)
- 고객 기본 정보
- KYC(본인인증) 정보
- Soft delete 사용

### accounts (계좌)
- 계좌 정보
- 계좌 유형 (적금, 예금, 당좌 등)
- **잔액은 직접 저장하지 않음!**

### account_holders (계좌-고객 관계) ⭐
- N:M 관계 처리
- 공동명의, 법인 대리인 대응
- 권한별 구분 (owner, joint, authorized)

### transactions (거래) ⭐⭐⭐
- 모든 거래 기록
- 진실의 원천 (Source of Truth)
- 절대 삭제/수정 금지
- 취소는 역거래로

### cards (카드)
- 계좌 연결 체크/신용카드
- 한도, 상태 관리

### loans (대출)
- 대출 정보
- 상환 스케줄 관리

---

## 🚨 주의사항

1. **DELETE 절대 금지**
2. **모든 테이블에 감사 필드 필수**
   - created_at, created_by
   - updated_at, updated_by
   - deleted_at (soft delete)
3. **잔액은 계산으로 구함**
4. **모든 금액은 DECIMAL(15,2)**
5. **트랜잭션 격리 수준: SERIALIZABLE**


