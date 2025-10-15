# 데이터베이스 설계 패턴 가이드

도메인별 데이터베이스 설계 패턴과 ERD 자동 생성 도구

---

## 📂 프로젝트 구조

```
ai-db-design-pattern/
├── README.md                   (이 파일)
├── DB_DESIGN_PATTERNS.md       (설계 패턴 가이드)
├── update_erd.py               (ERD 자동 생성 스크립트)
├── Makefile                    (편의 명령어)
│
├── finance/                    (금융 시스템)
│   ├── README.md
│   ├── ERD.md
│   ├── ERD.mmd                 (자동 생성)
│   ├── schema.sql              (MySQL)
│   ├── schema_postgres.sql     (PostgreSQL 16)
│   └── sample_queries.sql
│
├── hr/                         (인사 관리)
│   ├── README.md
│   ├── ERD.md
│   ├── ERD.mmd                 (자동 생성)
│   ├── schema.sql              (MySQL)
│   ├── schema_postgres.sql     (PostgreSQL 16)
│   └── sample_queries.sql
│
├── ecommerce/                  (전자상거래)
│   ├── README.md
│   ├── ERD.md
│   ├── schema.sql
│   └── ...
│
└── healthcare/                 (의료 시스템)
    └── ...
```

## 🗄️ 지원 데이터베이스

각 도메인은 다음 데이터베이스를 지원합니다:

- **MySQL 8.0+** (`schema.sql`)
- **PostgreSQL 16** (`schema_postgres.sql`)
  - PostGIS 확장 지원 (지리 데이터 필요 시)

---

## 🚀 빠른 시작

### 1. ERD 생성

#### 방법 1: Make 사용 (추천)
```bash
# 도움말
make help

# 모든 도메인 ERD 생성
make erd

# 특정 도메인만 생성
make erd-finance
make erd-ecommerce
make erd-healthcare
```

#### 방법 2: Python 직접 실행
```bash
# 모든 도메인
python update_erd.py

# 특정 도메인
python update_erd.py finance
python update_erd.py finance ecommerce
```

### 2. 새 도메인 추가

```bash
# 1. 폴더 생성
mkdir my-domain

# 2. schema.sql 작성
# my-domain/schema.sql 파일 생성

# 3. ERD 자동 생성
make erd-my-domain
# 또는
python update_erd.py my-domain
```

---

## 📚 도메인별 가이드

### 🏦 Finance (금융 시스템)
- **핵심 테이블:** customers, accounts, transactions
- **특징:** 
  - 절대 DELETE 금지
  - 모든 변경 이력 보존
  - 트랜잭션 무결성 최우선
- **문서:** [finance/README.md](finance/README.md)

### 🛒 E-commerce (전자상거래)
- **핵심 테이블:** users, products, orders
- **특징:**
  - 재고 관리
  - 주문-상품 N:M 관계
  - 결제/배송 분리
- **문서:** (준비 중)

### 🏥 Healthcare (의료 시스템)
- **핵심 테이블:** patients, doctors, appointments
- **특징:**
  - 개인정보 보호 중요
  - 이력 추적 필수
  - 다대다 관계 많음
- **문서:** (준비 중)

---

## 🛠️ 도구 사용법

### update_erd.py

SQL 스키마 파일(`schema.sql`)에서 자동으로 Mermaid ERD를 생성합니다.

**기능:**
- ✅ SQL 파싱 (MySQL, PostgreSQL 지원)
- ✅ 테이블 구조 추출
- ✅ 외래키 관계 자동 탐지
- ✅ `.mmd` 파일 생성
- ✅ `ERD.md` 파일 업데이트

**사용법:**
```bash
# 전체 도움말
python update_erd.py --help

# 자동 탐색 (schema.sql 있는 폴더 자동 처리)
python update_erd.py

# 특정 폴더
python update_erd.py finance

# 여러 폴더
python update_erd.py finance ecommerce healthcare
```

**출력:**
- `{domain}/ERD.mmd` - Mermaid 다이어그램 파일
- `{domain}/ERD.md` - 마크다운 내의 mermaid 블록 업데이트

---

## 📖 설계 패턴 가이드

[DB_DESIGN_PATTERNS.md](DB_DESIGN_PATTERNS.md)에서 다음 내용을 확인하세요:

### 핵심 개념
- 메인 테이블 식별 기준
- 관계 형성 방법
- 지원 테이블 추가

### 주요 패턴
1. 단일 중심형 (Single Hub)
2. 다중 중심형 (Multi Hub) ⭐ 가장 일반적
3. 계층형 (Hierarchical)
4. 이벤트 중심형 (Event-Driven)

### 산업별 패턴
- 전자상거래
- 은행
- 병원
- 학교
- 소셜 미디어

---

## 🎯 설계 원칙

### 1. 핵심은 유연하게
```sql
-- N:M 가능성이 있으면 중간 테이블
CREATE TABLE order_users (
    order_id INT,
    user_id INT,
    role VARCHAR(20)
);
```

### 2. 이력은 복사해서 저장
```sql
-- 변할 수 있는 데이터는 스냅샷
CREATE TABLE order_items (
    menu_id INT,        -- FK (참조용)
    menu_name VARCHAR,  -- 복사 (이력 보존)
    price DECIMAL       -- 복사 (주문 당시 가격)
);
```

### 3. 확장 여지 남기기
```sql
CREATE TABLE orders (
    type VARCHAR(20),  -- 타입별 확장
    metadata JSONB     -- 유연한 데이터
);
```

---

## 🤝 기여하기

### 새 도메인 추가

1. **폴더 구조 생성**
   ```bash
   mkdir {domain}
   cd {domain}
   ```

2. **필수 파일 작성**
   - `README.md` - 도메인 개요
   - `schema.sql` - 테이블 정의
   - `ERD.md` - ERD 설명 (템플릿 사용)
   - `sample_queries.sql` - 주요 쿼리 예시

3. **ERD 생성**
   ```bash
   python update_erd.py {domain}
   ```

4. **문서화**
   - README.md에 도메인 설명 추가
   - 핵심 테이블 설명
   - 주요 쿼리 패턴

---

## 📋 체크리스트

### 설계 시
- [ ] 핵심 엔티티 식별
- [ ] N:M 관계 중간 테이블 사용
- [ ] 이력 데이터 복사 저장
- [ ] 확장 여지 (type, metadata)
- [ ] 인덱스 고려

### 구현 시
- [ ] 외래키 제약조건
- [ ] 적절한 인덱스
- [ ] 감사 필드 (created_at, updated_at)
- [ ] Soft delete (deleted_at)
- [ ] 주석/문서

### 검증 시
- [ ] ERD 생성 확인
- [ ] 샘플 쿼리 실행
- [ ] 성능 테스트
- [ ] 데이터 무결성 확인

---

## 🔗 관련 링크

- **원본 프로젝트:** https://github.com/jmcreat/ai-erd-uipa
- **Mermaid 문서:** https://mermaid.js.org/syntax/entityRelationshipDiagram.html
- **DB 설계 Best Practices:** [DB_DESIGN_PATTERNS.md](DB_DESIGN_PATTERNS.md)

---

## 📝 라이선스

이 프로젝트는 학습 및 참고 목적으로 작성되었습니다.

---

## 🙋 FAQ

### Q: ERD가 생성되지 않아요
A: `schema.sql` 파일이 올바른 위치에 있는지 확인하세요.
```bash
# 구조 확인
ls -la {domain}/schema.sql
```

### Q: 관계가 잘못 표시돼요
A: `FOREIGN KEY` 제약조건이 명시적으로 선언되어 있는지 확인하세요.

### Q: 새 도메인을 추가했는데 자동으로 안 돼요
A: `schema.sql` 파일이 있으면 자동으로 탐지됩니다.
```bash
python update_erd.py  # 자동 탐색
```

### Q: Makefile이 없다고 나와요
A: Make가 설치되어 있는지 확인하세요.
```bash
# Mac/Linux
which make

# Windows
# Git Bash나 WSL 사용 권장
```

---

**Happy Database Designing! 🎨**

