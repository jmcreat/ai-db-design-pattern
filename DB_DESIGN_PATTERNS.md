# 데이터베이스 설계 패턴 가이드

## 🎯 핵심 개념

대부분의 데이터베이스 설계는 **"메인 테이블(핵심 엔티티)을 중심으로 관계를 형성"**하는 방식으로 진행됩니다.

---

## 📊 일반적인 DB 설계 프로세스

### 1단계: 핵심 엔티티(메인 테이블) 식별 ⭐
```
"이 시스템이 관리하는 가장 중요한 것은?"
```

**예시:**
- 선박 관리 → `ships`, `voyages`
- 쇼핑몰 → `products`, `orders`, `users`
- 학교 → `students`, `courses`
- 병원 → `patients`, `appointments`

### 2단계: 관계 형성
```
"핵심 엔티티들이 어떻게 연결되는가?"
```

### 3단계: 지원 테이블 추가
```
"핵심 엔티티를 지원하는 부가 정보는?"
```

---

## 🏗️ 주요 설계 패턴

### Pattern 1: 단일 중심형 (Single Hub)

**예시: 블로그**
```
        users (중심)
         │
    ┌────┼────┐
    │    │    │
  posts  likes comments
    │
  ┌─┴─┐
 tags media
```

**특징:**
- ✅ 간단함
- ✅ 쿼리 단순
- ❌ 확장성 제한

**적용 사례:**
- 개인 블로그
- 간단한 CMS
- 소규모 시스템

---

### Pattern 2: 다중 중심형 (Multi Hub) ⭐ 가장 일반적

**예시: 쇼핑몰**
```
    users          products
      │               │
      └──── orders ───┘
              │
         ┌────┼────┐
    payments reviews shipping
```

**특징:**
- ✅ 유연함
- ✅ 확장 가능
- ⚠️ 복잡도 증가

**현재 선박 시스템도 이 패턴:**
```
ships (선박) ←→ voyages (항차)
     │              │
   10개 테이블    5개 테이블
```

**적용 사례:**
- 전자상거래
- ERP 시스템
- 금융 시스템
- 대부분의 중대형 시스템

---

### Pattern 3: 계층형 (Hierarchical)

**예시: 조직도, 카테고리**
```
categories
    │
    ├─ subcategories
    │       │
    │       └─ products
    │
departments
    │
    └─ employees
```

**특징:**
- ✅ 트리 구조 표현
- ❌ 복잡한 쿼리 (재귀)

**적용 사례:**
- 조직도
- 카테고리 시스템
- 파일 시스템

---

### Pattern 4: 이벤트 중심형 (Event-Driven)

**예시: 로그, 감사 시스템**
```
events (중심)
  │
  ├─ event_type
  ├─ event_source
  └─ event_metadata
```

**특징:**
- ✅ 시계열 분석
- ✅ 감사 추적
- ⚠️ 데이터 많음

**적용 사례:**
- 로그 시스템
- 감사 추적
- IoT 데이터
- 이벤트 소싱

---

## 🏢 산업별 설계 패턴

### 1. 전자상거래 (E-commerce)

**3개 메인 엔티티:**
```
users (회원)
├─ addresses
├─ payment_methods
└─ wishlists

products (상품)
├─ categories
├─ inventory
├─ images
└─ specifications

orders (주문) ← users + products
├─ order_items
├─ payments
└─ shipments
```

**특징:**
- 주문이 users와 products를 연결
- 재고 관리 중요
- 결제/배송 분리

---

### 2. 은행 (Banking)

**2개 메인 엔티티:**
```
customers (고객)
├─ kyc_info
├─ addresses
└─ contacts

accounts (계좌) ← customers
├─ transactions
├─ cards
├─ loans
└─ statements
```

**특징:**
- 감사 추적 필수
- 트랜잭션 무결성 중요
- 계좌가 중심

---

### 3. 병원 (Healthcare)

**3개 메인 엔티티:**
```
patients (환자)
├─ medical_history
├─ allergies
└─ insurance

doctors (의사)
├─ specializations
└─ schedules

appointments (진료) ← patients + doctors
├─ prescriptions
├─ lab_results
├─ diagnoses
└─ billing
```

**특징:**
- 개인정보 보호 중요
- 이력 추적 필수
- 다대다 관계 많음

---

### 4. 학교 (Education)

**3개 메인 엔티티:**
```
students (학생)
├─ profiles
└─ guardians

teachers (교사)
├─ certifications
└─ schedules

courses (과목)
├─ materials
└─ schedules

enrollments ← students + courses
├─ grades
└─ attendance
```

**특징:**
- 다대다 관계 (학생-과목)
- 학기별 데이터 관리
- 성적 관리

---

### 5. 소셜 미디어

**2개 메인 엔티티:**
```
users (사용자)
├─ profiles
├─ settings
└─ followers (N:N, self-referencing)

posts (게시물) ← users
├─ comments
├─ likes
├─ shares
└─ media
```

**특징:**
- 셀프 참조 (followers)
- 대용량 데이터
- 실시간성 중요

---

## 💡 메인 테이블 식별 기준

### ✅ 메인 테이블의 특징:

#### 1. 독립적 존재
```sql
-- ships는 voyages 없어도 존재 가능 ✅
-- voyage_legs는 voyages 없으면 의미 없음 ❌
```

#### 2. 핵심 비즈니스 개체
```
질문: "우리 회사의 핵심 자산/활동은?"
답변: = 메인 테이블
```

#### 3. 여러 곳에서 참조됨
```
ships → 10개 테이블에서 참조 ✅
voyage_events → voyages만 참조 ❌
```

#### 4. 라이프사이클이 긺
```
ships: 수십년 ✅
voyage_events: 몇 시간 ❌
```

#### 5. DELETE 영향도
```sql
DELETE FROM ships WHERE id = 1;
-- CASCADE로 많은 데이터 삭제됨 → 메인!

DELETE FROM voyage_events WHERE id = 1;
-- 영향 최소 → 지원 테이블
```

---

## 🎓 설계 방법론

### 방법 1: Top-Down (하향식) ⭐ 가장 일반적

```
1. 비즈니스 요구사항 분석
   "무엇을 관리할 것인가?"
   
2. 핵심 엔티티 식별
   "가장 중요한 명사는?"
   
3. 관계 정의
   "어떻게 연결되는가?"
   
4. 속성 추가
   "각각 무슨 정보가 필요한가?"
   
5. 정규화
   "중복을 제거하자"
```

**예시: 도서관 시스템**
```
1. 요구사항: "책을 대여하는 시스템"
2. 핵심 엔티티: books, members
3. 관계: loans (books ↔ members)
4. 속성: ISBN, title, name, phone
5. 정규화: authors, publishers 분리
```

---

### 방법 2: Bottom-Up (상향식)

```
1. 모든 데이터 나열
2. 그룹핑
3. 테이블화
4. 관계 찾기
```

**단점:**
- 전체 구조 파악 어려움
- 중복 발생 가능
- **실무에서는 잘 안 씀** ❌

---

### 방법 3: 도메인 주도 설계 (DDD)

```
1. 도메인 분석
   Bounded Context 식별
   
2. Aggregate Root 찾기
   = 메인 엔티티
   
3. Entity/Value Object 구분
   
4. 관계 정의
```

**적용 사례:**
- 대규모 시스템
- 마이크로서비스
- 복잡한 비즈니스 로직

---

## 🔍 실제 설계 과정 예시

### 시나리오: "음식 배달 앱"

#### Step 1: 핵심 엔티티 브레인스토밍
```
사용자? ✅
음식? ✅
식당? ✅
배달? ✅
결제? → 지원
리뷰? → 지원
```

#### Step 2: 우선순위 정하기
```
Tier 1 (메인):
- users (고객)
- restaurants (식당)
- orders (주문) ← 핵심 트랜잭션

Tier 2 (지원):
- menus (메뉴)
- reviews (리뷰)
- deliveries (배달)
- payments (결제)
```

#### Step 3: 관계 정의
```
users
  └─ orders ──┐
               ├─ order_items → menus → restaurants
  deliveries ─┘

users → reviews → restaurants
users → payments → orders
```

#### Step 4: 최종 SQL
```sql
-- 메인 3개
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20)
);

CREATE TABLE restaurants (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    address TEXT,
    rating DECIMAL(3,2)
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    restaurant_id INT REFERENCES restaurants(id),
    status VARCHAR(20),
    total_amount DECIMAL(10,2)
);

-- 지원 테이블들
CREATE TABLE menus (
    id SERIAL PRIMARY KEY,
    restaurant_id INT REFERENCES restaurants(id),
    name VARCHAR(100),
    price DECIMAL(10,2)
);

CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id),
    menu_id INT REFERENCES menus(id),
    quantity INT,
    price DECIMAL(10,2)
);

CREATE TABLE deliveries (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id),
    driver_name VARCHAR(100),
    status VARCHAR(20),
    delivered_at TIMESTAMP
);
```

---

## 📈 복잡도별 권장 구조

### 소규모 (테이블 < 10개)
```
메인: 1-2개
지원: 5-8개

예시:
- 블로그
- 간단한 CMS
- To-Do 앱
```

### 중규모 (테이블 10-50개)
```
메인: 2-4개
지원: 10-40개

예시:
- 쇼핑몰
- 사내 시스템
- 예약 시스템

🚢 현재 선박 시스템이 여기 해당 (21개 테이블)
```

### 대규모 (테이블 50개+)
```
도메인별 분리
각 도메인:
  메인: 2-3개
  지원: 10-20개

예시:
- ERP
- 금융 시스템
- 대형 포털
```

---

## 🎯 선박 관리 시스템 분석 (현재 프로젝트)

### 구조
```
메인 엔티티: 2개
  - ships (선박) - 1차 메인
  - voyages (항차) - 2차 메인

참조 데이터: 4개
  - ship_types
  - ports
  - shipping_companies
  - ship_groups

선박 중심 테이블: 10개
  - ship_specifications
  - ship_capex
  - ship_opex
  - maintenance_records
  - fuel_specifications
  - yearly_cii_summary
  - ship_group_memberships
  - ship_positions (공유)
  - fuel_tank_levels (공유)
  - voyages (연결)

항차 중심 테이블: 5개
  - voyage_legs
  - voyage_events
  - weather_data
  - ship_positions (공유)
  - fuel_tank_levels (공유)

기타: 2개
  - users
  - routes
```

### 특징
- **Asset-Operation 2-Tier 패턴**
- ships (자산) + voyages (운영)
- 정적 정보 + 동적 정보
- 장기 데이터 + 단기 데이터

---

## 🚫 안티패턴 (피해야 할 것)

### ❌ 1. 메인 엔티티 없음
```
모든 테이블이 평등 → 구조 불명확
쿼리 경로 복잡 → 유지보수 어려움
```

### ❌ 2. 메인이 너무 많음
```
10개가 모두 메인이라고 주장 → 실제론 구분 없음
우선순위 없음 → 설계 방향성 상실
```

### ❌ 3. 순환 참조
```sql
-- A → B → C → A (무한 루프)
CREATE TABLE A (b_id INT REFERENCES B(id));
CREATE TABLE B (c_id INT REFERENCES C(id));
CREATE TABLE C (a_id INT REFERENCES A(id));
-- ❌ 삭제/업데이트 불가능
```

### ❌ 4. God Table (만능 테이블)
```sql
CREATE TABLE users (
    id INT,
    name VARCHAR(100),
    email VARCHAR(100),
    -- ...100개 컬럼...
    last_login TIMESTAMP,
    preference_json TEXT
);
-- ❌ 정규화 필요!
```

### ❌ 5. 관계 없는 테이블
```sql
CREATE TABLE orphan_table (
    id INT,
    data TEXT
);
-- 아무도 참조 안함, 아무것도 참조 안함
-- ❌ 왜 존재하는가?
```

---

## ✅ 좋은 설계 체크리스트

### 설계 단계
```
□ 핵심 엔티티가 명확한가?
□ 엔티티 간 관계가 직관적인가?
□ 비즈니스 로직과 일치하는가?
□ 확장 가능한 구조인가?
□ 정규화가 적절한가?
```

### 구현 단계
```
□ 외래키 제약조건이 있는가?
□ 인덱스가 적절한가?
□ 네이밍이 일관성 있는가?
□ 주석/문서가 충분한가?
□ 성능을 고려했는가?
```

### 운영 단계
```
□ 쿼리가 효율적인가?
□ 백업/복구 계획이 있는가?
□ 데이터 무결성이 보장되는가?
□ 확장성을 고려했는가?
□ 모니터링이 가능한가?
```

---

## 🎓 설계 원칙 (SOLID의 DB 버전)

### 1. Single Responsibility (단일 책임)
```
각 테이블은 하나의 엔티티만 표현
users ≠ users + orders + payments
```

### 2. Open-Closed (개방-폐쇄)
```
확장에는 열려있고, 수정에는 닫혀있어야 함
새 테이블 추가는 쉽게, 기존 테이블 변경은 최소화
```

### 3. Dependency Inversion (의존성 역전)
```
구체적인 것이 추상적인 것에 의존
상세 테이블 → 메인 테이블 (FK)
메인 테이블 ↛ 상세 테이블
```

---

## 📚 추가 학습 자료

### 책
- "Database Design for Mere Mortals" - Michael J. Hernandez
- "SQL Performance Explained" - Markus Winand
- "Designing Data-Intensive Applications" - Martin Kleppmann

### 온라인
- DB-Engines Ranking
- Use The Index, Luke
- PostgreSQL Documentation

### 실습
- draw.io (ERD 도구)
- dbdiagram.io
- MySQL Workbench
- pgAdmin

---

## 💡 핵심 요약

### 설계의 골든 룰
```
1. 핵심(Core) 먼저 식별
2. 관계(Relationship) 정의
3. 지원(Supporting) 추가
4. 정규화(Normalize)
5. 최적화(Optimize)
```

### 보편적 패턴
```
90% 이상의 시스템:
  메인 엔티티 (1-4개)
    └─ 지원 테이블 (n개)
```

### 산업 무관
```
쇼핑몰이든, 병원이든, 선박이든
→ 같은 원칙 적용
→ 메인 중심 설계
```

---

## 🎯 실전 적용

### 새 프로젝트 시작 시:

1. **첫 질문:** "무엇을 관리하는가?"
2. **둘째 질문:** "핵심 엔티티는 무엇인가?"
3. **셋째 질문:** "어떻게 연결되는가?"
4. **넷째 질문:** "무슨 정보가 필요한가?"

### 기존 프로젝트 분석 시:

1. **ERD 보기**
2. **가장 많이 참조되는 테이블 찾기** → 메인
3. **관계 추적**
4. **패턴 파악**

---

**이 가이드는 선박 관리 시스템 설계 과정에서 발견한 보편적 원칙들을 정리한 것입니다.**

**프로젝트:** https://github.com/jmcreat/ai-erd-uipa

