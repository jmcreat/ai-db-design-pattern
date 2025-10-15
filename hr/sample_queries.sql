-- ============================================
-- 인사 관리 시스템 주요 쿼리 예시
-- ============================================

-- ============================================
-- 1. 직원 목록 조회 (현재 소속 부서 포함)
-- ============================================

SELECT 
    e.employee_number AS '사번',
    e.name AS '이름',
    p.position_name AS '직급',
    d.department_name AS '부서',
    e.hire_date AS '입사일',
    TIMESTAMPDIFF(YEAR, e.hire_date, CURDATE()) AS '재직연수',
    e.status AS '상태'
FROM employees e
LEFT JOIN positions p ON e.current_position_id = p.id
LEFT JOIN employee_departments ed ON e.id = ed.employee_id AND ed.release_date IS NULL
LEFT JOIN departments d ON ed.department_id = d.id
WHERE e.deleted_at IS NULL
    AND e.status = 'active'
ORDER BY e.employee_number;


-- ============================================
-- 2. 부서 조직도 (계층 구조)
-- ============================================

WITH RECURSIVE dept_hierarchy AS (
    -- 최상위 부서
    SELECT 
        id,
        department_code,
        department_name,
        parent_id,
        0 AS level,
        CAST(department_name AS CHAR(500)) AS path
    FROM departments
    WHERE parent_id IS NULL
        AND deleted_at IS NULL
    
    UNION ALL
    
    -- 하위 부서
    SELECT 
        d.id,
        d.department_code,
        d.department_name,
        d.parent_id,
        dh.level + 1,
        CONCAT(dh.path, ' > ', d.department_name)
    FROM departments d
    JOIN dept_hierarchy dh ON d.parent_id = dh.id
    WHERE d.deleted_at IS NULL
)
SELECT 
    REPEAT('  ', level) AS '계층',
    department_code AS '부서코드',
    department_name AS '부서명',
    path AS '전체경로'
FROM dept_hierarchy
ORDER BY path;


-- ============================================
-- 3. 부서별 인원 수
-- ============================================

SELECT 
    d.department_name AS '부서',
    COUNT(DISTINCT ed.employee_id) AS '인원수',
    CONCAT(
        COUNT(DISTINCT CASE WHEN e.gender = 'male' THEN ed.employee_id END), '/',
        COUNT(DISTINCT CASE WHEN e.gender = 'female' THEN ed.employee_id END)
    ) AS '남/여',
    ROUND(AVG(TIMESTAMPDIFF(YEAR, e.hire_date, CURDATE())), 1) AS '평균재직연수'
FROM departments d
LEFT JOIN employee_departments ed ON d.id = ed.department_id AND ed.release_date IS NULL
LEFT JOIN employees e ON ed.employee_id = e.id AND e.deleted_at IS NULL AND e.status = 'active'
WHERE d.deleted_at IS NULL
GROUP BY d.id, d.department_name
ORDER BY COUNT(DISTINCT ed.employee_id) DESC;


-- ============================================
-- 4. 개인 급여 이력
-- ============================================

SELECT 
    s.effective_from AS '적용일',
    s.effective_to AS '종료일',
    FORMAT(s.base_salary, 0) AS '기본급',
    FORMAT(s.allowances, 0) AS '수당',
    FORMAT(s.total_salary, 0) AS '총급여',
    s.change_reason AS '변경사유'
FROM salaries s
WHERE s.employee_id = 1  -- 직원 ID
ORDER BY s.effective_from DESC;


-- ============================================
-- 5. 부서별 평균 급여
-- ============================================

SELECT 
    d.department_name AS '부서',
    COUNT(DISTINCT e.id) AS '인원',
    FORMAT(AVG(s.total_salary), 0) AS '평균급여',
    FORMAT(MIN(s.total_salary), 0) AS '최소급여',
    FORMAT(MAX(s.total_salary), 0) AS '최대급여'
FROM departments d
JOIN employee_departments ed ON d.id = ed.department_id AND ed.release_date IS NULL
JOIN employees e ON ed.employee_id = e.id AND e.deleted_at IS NULL AND e.status = 'active'
JOIN salaries s ON e.id = s.employee_id AND s.effective_to IS NULL
WHERE d.deleted_at IS NULL
GROUP BY d.id, d.department_name
ORDER BY AVG(s.total_salary) DESC;


-- ============================================
-- 6. 월별 출근 통계
-- ============================================

SELECT 
    DATE_FORMAT(a.work_date, '%Y-%m') AS '년월',
    COUNT(*) AS '총근무일',
    SUM(CASE WHEN a.status = 'normal' THEN 1 ELSE 0 END) AS '정상',
    SUM(CASE WHEN a.status = 'late' THEN 1 ELSE 0 END) AS '지각',
    SUM(CASE WHEN a.status = 'early_leave' THEN 1 ELSE 0 END) AS '조퇴',
    SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END) AS '결근',
    ROUND(AVG(a.work_minutes) / 60, 1) AS '평균근무시간'
FROM attendance a
WHERE a.employee_id = 1  -- 직원 ID
    AND a.work_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
GROUP BY DATE_FORMAT(a.work_date, '%Y-%m')
ORDER BY DATE_FORMAT(a.work_date, '%Y-%m') DESC;


-- ============================================
-- 7. 휴가 사용 현황
-- ============================================

SELECT 
    e.employee_number AS '사번',
    e.name AS '이름',
    SUM(CASE WHEN l.leave_type = 'annual' THEN l.days ELSE 0 END) AS '연차사용',
    SUM(CASE WHEN l.leave_type = 'sick' THEN l.days ELSE 0 END) AS '병가사용',
    SUM(l.days) AS '총휴가일수',
    (
        15 - SUM(CASE WHEN l.leave_type = 'annual' THEN l.days ELSE 0 END)
    ) AS '연차잔여'
FROM employees e
LEFT JOIN leaves l ON e.id = l.employee_id 
    AND l.status = 'approved'
    AND YEAR(l.start_date) = YEAR(CURDATE())
WHERE e.deleted_at IS NULL
    AND e.status = 'active'
GROUP BY e.id, e.employee_number, e.name
ORDER BY e.employee_number;


-- ============================================
-- 8. 부서 이동 이력
-- ============================================

SELECT 
    e.name AS '이름',
    d.department_name AS '부서',
    ed.assignment_date AS '발령일',
    ed.release_date AS '해제일',
    CASE 
        WHEN ed.release_date IS NULL THEN '현재'
        ELSE CONCAT(
            TIMESTAMPDIFF(DAY, ed.assignment_date, ed.release_date), '일'
        )
    END AS '재직기간',
    ed.role AS '역할'
FROM employee_departments ed
JOIN employees e ON ed.employee_id = e.id
JOIN departments d ON ed.department_id = d.id
WHERE e.id = 1  -- 직원 ID
ORDER BY ed.assignment_date DESC;


-- ============================================
-- 9. 성과평가 이력
-- ============================================

SELECT 
    pr.review_period AS '평가기간',
    pr.grade AS '등급',
    pr.score AS '점수',
    reviewer.name AS '평가자',
    pr.reviewed_at AS '평가일',
    pr.comments AS '의견'
FROM performance_reviews pr
JOIN employees reviewer ON pr.reviewer_id = reviewer.id
WHERE pr.employee_id = 1  -- 직원 ID
ORDER BY pr.review_year DESC, pr.review_period DESC;


-- ============================================
-- 10. 입사자/퇴사자 통계 (월별)
-- ============================================

SELECT 
    DATE_FORMAT(month_date, '%Y-%m') AS '년월',
    COALESCE(h.hire_count, 0) AS '입사자수',
    COALESCE(r.resign_count, 0) AS '퇴사자수',
    COALESCE(h.hire_count, 0) - COALESCE(r.resign_count, 0) AS '순증감'
FROM (
    -- 월 기준 데이터 생성
    SELECT DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL n MONTH), '%Y-%m-01') AS month_date
    FROM (
        SELECT 0 AS n UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION 
        SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION 
        SELECT 8 UNION SELECT 9 UNION SELECT 10 UNION SELECT 11
    ) months
) months
LEFT JOIN (
    SELECT DATE_FORMAT(hire_date, '%Y-%m-01') AS month, COUNT(*) AS hire_count
    FROM employees
    GROUP BY DATE_FORMAT(hire_date, '%Y-%m-01')
) h ON months.month_date = h.month
LEFT JOIN (
    SELECT DATE_FORMAT(resignation_date, '%Y-%m-01') AS month, COUNT(*) AS resign_count
    FROM employees
    WHERE resignation_date IS NOT NULL
    GROUP BY DATE_FORMAT(resignation_date, '%Y-%m-01')
) r ON months.month_date = r.month
ORDER BY months.month_date DESC;


-- ============================================
-- 11. 직급별 평균 급여
-- ============================================

SELECT 
    p.position_name AS '직급',
    p.level AS '레벨',
    COUNT(DISTINCT e.id) AS '인원',
    FORMAT(AVG(s.total_salary), 0) AS '평균급여',
    FORMAT(MIN(s.total_salary), 0) AS '최소',
    FORMAT(MAX(s.total_salary), 0) AS '최대',
    FORMAT(p.min_salary, 0) AS '범위최소',
    FORMAT(p.max_salary, 0) AS '범위최대'
FROM positions p
LEFT JOIN employees e ON p.id = e.current_position_id 
    AND e.deleted_at IS NULL 
    AND e.status = 'active'
LEFT JOIN salaries s ON e.id = s.employee_id AND s.effective_to IS NULL
GROUP BY p.id, p.position_name, p.level, p.min_salary, p.max_salary
ORDER BY p.level;


-- ============================================
-- 12. 장기 미사용 연차자 조회
-- ============================================

SELECT 
    e.employee_number AS '사번',
    e.name AS '이름',
    d.department_name AS '부서',
    15 - COALESCE(SUM(l.days), 0) AS '미사용연차',
    MAX(l.start_date) AS '마지막휴가일',
    DATEDIFF(CURDATE(), MAX(l.start_date)) AS '경과일수'
FROM employees e
LEFT JOIN employee_departments ed ON e.id = ed.employee_id AND ed.release_date IS NULL
LEFT JOIN departments d ON ed.department_id = d.id
LEFT JOIN leaves l ON e.id = l.employee_id 
    AND l.leave_type = 'annual'
    AND l.status = 'approved'
    AND YEAR(l.start_date) = YEAR(CURDATE())
WHERE e.deleted_at IS NULL
    AND e.status = 'active'
    AND e.hire_date < DATE_SUB(CURDATE(), INTERVAL 1 YEAR)  -- 1년 이상 재직
GROUP BY e.id, e.employee_number, e.name, d.department_name
HAVING (15 - COALESCE(SUM(l.days), 0)) >= 10  -- 10일 이상 미사용
ORDER BY (15 - COALESCE(SUM(l.days), 0)) DESC;


-- ============================================
-- 13. 급여 인상률 분석
-- ============================================

SELECT 
    e.employee_number AS '사번',
    e.name AS '이름',
    s1.effective_from AS '이전적용일',
    FORMAT(s1.total_salary, 0) AS '이전급여',
    s2.effective_from AS '현재적용일',
    FORMAT(s2.total_salary, 0) AS '현재급여',
    FORMAT(s2.total_salary - s1.total_salary, 0) AS '인상액',
    CONCAT(
        ROUND(((s2.total_salary - s1.total_salary) / s1.total_salary * 100), 1), 
        '%'
    ) AS '인상률'
FROM employees e
JOIN salaries s1 ON e.id = s1.employee_id
JOIN salaries s2 ON e.id = s2.employee_id 
    AND s2.effective_from > s1.effective_from
    AND s2.effective_from = (
        SELECT MAX(effective_from) 
        FROM salaries 
        WHERE employee_id = e.id
    )
    AND s1.effective_from = (
        SELECT MAX(effective_from) 
        FROM salaries 
        WHERE employee_id = e.id 
            AND effective_from < s2.effective_from
    )
WHERE e.deleted_at IS NULL
ORDER BY ((s2.total_salary - s1.total_salary) / s1.total_salary) DESC;


-- ============================================
-- 14. 재직 기간별 인원 분포
-- ============================================

SELECT 
    CASE 
        WHEN tenure < 1 THEN '1년 미만'
        WHEN tenure < 3 THEN '1-3년'
        WHEN tenure < 5 THEN '3-5년'
        WHEN tenure < 10 THEN '5-10년'
        ELSE '10년 이상'
    END AS '재직기간',
    COUNT(*) AS '인원',
    CONCAT(ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1), '%') AS '비율'
FROM (
    SELECT 
        e.id,
        TIMESTAMPDIFF(YEAR, e.hire_date, CURDATE()) AS tenure
    FROM employees e
    WHERE e.deleted_at IS NULL
        AND e.status = 'active'
) tenure_data
GROUP BY 
    CASE 
        WHEN tenure < 1 THEN '1년 미만'
        WHEN tenure < 3 THEN '1-3년'
        WHEN tenure < 5 THEN '3-5년'
        WHEN tenure < 10 THEN '5-10년'
        ELSE '10년 이상'
    END
ORDER BY MIN(tenure);

