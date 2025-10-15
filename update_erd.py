#!/usr/bin/env python3
"""
SQL 스키마에서 Mermaid ERD 자동 생성 스크립트
폴더별로 schema.sql을 읽어서 .mmd 파일과 ERD.md를 업데이트합니다.
"""

import re
import sys
from pathlib import Path
import argparse

def parse_sql_schema(sql_file):
    """SQL 파일에서 테이블 구조 파싱 (MySQL 문법 지원)"""
    tables = {}
    
    with open(sql_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 주석 제거 (-- 스타일)
    content = re.sub(r'--[^\n]*', '', content)
    
    # CREATE TABLE 패턴 찾기 (MySQL 문법 정확히 처리)
    # 패턴: CREATE TABLE table_name ( ... ) [COMMENT='...'];
    table_pattern = r'CREATE TABLE\s+(\w+)\s*\(((?:[^()]|\((?:[^()]|\([^()]*\))*\))*)\)\s*(?:COMMENT\s*=?\s*[\'"][^\'"]*[\'"])?\s*;'
    matches = re.findall(table_pattern, content, re.DOTALL | re.IGNORECASE)
    
    for table_name, table_body in matches:
        columns = []
        
        # FK 컬럼 찾기 (테이블 레벨 FK)
        fk_columns = set()
        fk_pattern = r'FOREIGN KEY\s*\((\w+)\)\s*REFERENCES'
        fk_matches = re.findall(fk_pattern, table_body, re.IGNORECASE)
        for fk_col in fk_matches:
            fk_columns.add(fk_col.strip())
        
        # 컬럼별로 라인 분리
        lines = table_body.split('\n')
        
        for line in lines:
            line = line.strip()
            
            # 빈 줄이나 주석 스킵
            if not line or line.startswith('--'):
                continue
            
            # 제약조건 라인 스킵
            if re.match(r'^\s*(PRIMARY\s+KEY|FOREIGN\s+KEY|UNIQUE|INDEX|KEY|CHECK|CONSTRAINT)', line, re.IGNORECASE):
                continue
            
            # 컬럼 파싱
            # 패턴: column_name data_type [constraints] [COMMENT '...']
            col_match = re.match(r'^(\w+)\s+([A-Z]+(?:\([^)]*\))?)', line, re.IGNORECASE)
            
            if not col_match:
                continue
            
            col_name = col_match.group(1).strip()
            data_type_raw = col_match.group(2).strip().upper()
            
            # 데이터 타입 정규화
            if 'BIGINT' in data_type_raw or 'INT' in data_type_raw or 'SERIAL' in data_type_raw:
                data_type = 'bigint' if 'BIGINT' in data_type_raw else 'int'
            elif 'VARCHAR' in data_type_raw or 'CHAR' in data_type_raw:
                data_type = 'varchar'
            elif 'DECIMAL' in data_type_raw or 'NUMERIC' in data_type_raw:
                data_type = 'decimal'
            elif 'TIMESTAMP' in data_type_raw:
                data_type = 'timestamp'
            elif 'DATETIME' in data_type_raw:
                data_type = 'datetime'
            elif 'DATE' in data_type_raw:
                data_type = 'date'
            elif 'TEXT' in data_type_raw or 'JSON' in data_type_raw:
                data_type = 'text'
            elif 'BOOLEAN' in data_type_raw or 'BOOL' in data_type_raw:
                data_type = 'boolean'
            else:
                data_type = 'varchar'
            
            # 제약조건 추출
            constraint = ''
            if 'PRIMARY KEY' in line.upper() or 'PK' in line.upper():
                constraint = 'PK'
            elif col_name in fk_columns or 'REFERENCES' in line.upper():
                constraint = 'FK'
            elif 'UNIQUE' in line.upper():
                constraint = 'UK'
            
            # COMMENT 추출 (선택적)
            comment_match = re.search(r"COMMENT\s+'([^']*)'", line, re.IGNORECASE)
            comment = ''
            if comment_match:
                comment = f'"{comment_match.group(1)}"'
            
            # 컬럼 문자열 생성
            column_str = f"{data_type} {col_name}"
            if constraint:
                column_str += f" {constraint}"
            if comment:
                column_str += f" {comment}"
            
            columns.append(column_str.strip())
        
        if columns:  # 컬럼이 있는 경우만 추가
            tables[table_name] = columns
    
    return tables

def parse_relationships(sql_file):
    """SQL 파일에서 외래키 관계 파싱 (MySQL 문법 지원)"""
    relationships = []
    
    with open(sql_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 주석 제거
    content = re.sub(r'--[^\n]*', '', content)
    
    # CREATE TABLE 블록별로 분리
    table_pattern = r'CREATE TABLE\s+(\w+)\s*\(((?:[^()]|\((?:[^()]|\([^()]*\))*\))*)\)\s*(?:COMMENT\s*=?\s*[\'"][^\'"]*[\'"])?\s*;'
    table_matches = re.findall(table_pattern, content, re.DOTALL | re.IGNORECASE)
    
    for table_name, table_body in table_matches:
        # FOREIGN KEY (column) REFERENCES ref_table(ref_column)
        fk_pattern = r'FOREIGN KEY\s*\((\w+)\)\s*REFERENCES\s+(\w+)\s*\((\w+)\)'
        fk_matches = re.findall(fk_pattern, table_body, re.IGNORECASE)
        
        for fk_col, ref_table, ref_col in fk_matches:
            relationships.append((table_name, ref_table, fk_col, ref_col))
    
    # 중복 제거
    relationships = list(set(relationships))
    
    return relationships

def generate_mermaid_erd(tables, relationships):
    """Mermaid ERD 코드 생성"""
    mermaid_code = "erDiagram\n"
    
    # 테이블 정의
    for table_name, columns in tables.items():
        mermaid_code += f"    {table_name} {{\n"
        for column in columns:
            mermaid_code += f"        {column}\n"
        mermaid_code += "    }\n\n"
    
    # 관계 정의
    mermaid_code += "    %% Relationships\n"
    for table1, table2, fk_col, ref_col in relationships:
        mermaid_code += f"    {table2} ||--o{{ {table1} : \"{fk_col}\"\n"
    
    return mermaid_code

def update_mermaid_file(mermaid_code, output_file):
    """Mermaid 파일 업데이트"""
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(mermaid_code)

def update_markdown_file(mermaid_code, markdown_file):
    """마크다운 파일의 Mermaid 코드 블록 업데이트"""
    with open(markdown_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Mermaid 코드 블록 찾기 및 교체
    pattern = r'```mermaid\n(.*?)\n```'
    replacement = f'```mermaid\n{mermaid_code}```'
    
    updated_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    
    with open(markdown_file, 'w', encoding='utf-8') as f:
        f.write(updated_content)

def process_folder(folder_path):
    """특정 폴더의 schema.sql을 처리하여 ERD 생성"""
    folder = Path(folder_path)
    
    if not folder.exists() or not folder.is_dir():
        print(f"❌ Error: {folder_path} is not a valid directory")
        return False
    
    sql_file = folder / 'schema.sql'
    mermaid_file = folder / 'ERD.mmd'
    markdown_file = folder / 'ERD.md'
    
    if not sql_file.exists():
        print(f"⚠️  Skipping {folder.name}: schema.sql not found")
        return False
    
    print(f"\n📂 Processing {folder.name}/")
    print(f"   Reading: {sql_file.name}")
    
    try:
        tables = parse_sql_schema(sql_file)
        relationships = parse_relationships(sql_file)
        
        if not tables:
            print(f"   ⚠️  No tables found in {sql_file.name}")
            return False
        
        print(f"   Found: {len(tables)} tables, {len(relationships)} relationships")
        
        mermaid_code = generate_mermaid_erd(tables, relationships)
        
        # .mmd 파일 생성
        update_mermaid_file(mermaid_code, mermaid_file)
        print(f"   ✅ Created: {mermaid_file.name}")
        
        # ERD.md 파일이 있으면 업데이트
        if markdown_file.exists():
            update_markdown_file(mermaid_code, markdown_file)
            print(f"   ✅ Updated: {markdown_file.name}")
        
        return True
        
    except Exception as e:
        print(f"   ❌ Error processing {folder.name}: {e}")
        return False

def find_domain_folders(base_path='.'):
    """도메인 폴더 자동 탐색"""
    base = Path(base_path)
    
    # schema.sql을 포함한 폴더만 선택
    domain_folders = []
    
    for item in base.iterdir():
        if item.is_dir() and not item.name.startswith('.'):
            schema_file = item / 'schema.sql'
            if schema_file.exists():
                domain_folders.append(item)
    
    return sorted(domain_folders)

def main():
    parser = argparse.ArgumentParser(
        description='SQL 스키마에서 Mermaid ERD 자동 생성',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
예시:
  # 모든 도메인 폴더 처리
  python update_erd.py
  
  # 특정 폴더만 처리
  python update_erd.py finance
  python update_erd.py finance ecommerce
        """
    )
    
    parser.add_argument(
        'folders',
        nargs='*',
        help='처리할 폴더 (미지정시 모든 도메인 폴더 자동 처리)'
    )
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("🔄 ERD Generator - SQL to Mermaid")
    print("=" * 60)
    
    if args.folders:
        # 지정된 폴더만 처리
        folders_to_process = [Path(f) for f in args.folders]
    else:
        # 모든 도메인 폴더 자동 탐색
        folders_to_process = find_domain_folders()
        if folders_to_process:
            print(f"\n📁 Found {len(folders_to_process)} domain folders:")
            for folder in folders_to_process:
                print(f"   - {folder.name}/")
        else:
            print("\n⚠️  No domain folders with schema.sql found")
            return
    
    # 처리
    success_count = 0
    for folder in folders_to_process:
        if process_folder(folder):
            success_count += 1
    
    # 결과 요약
    print("\n" + "=" * 60)
    if success_count > 0:
        print(f"✅ Successfully processed {success_count}/{len(folders_to_process)} folders")
    else:
        print("❌ No folders were processed successfully")
    print("=" * 60)

if __name__ == "__main__":
    main()
