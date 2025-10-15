# Makefile for DB Design Pattern Project
# ERD 생성 자동화

.PHONY: help erd erd-all erd-finance erd-hr erd-ecommerce erd-healthcare clean

# 기본 명령어 (help)
help:
	@echo "================================"
	@echo "📊 DB Design Pattern - Makefile"
	@echo "================================"
	@echo ""
	@echo "사용 가능한 명령어:"
	@echo "  make erd           - 모든 도메인 ERD 생성"
	@echo "  make erd-all       - 모든 도메인 ERD 생성 (erd와 동일)"
	@echo "  make erd-finance   - finance ERD만 생성"
	@echo "  make erd-hr        - hr ERD만 생성"
	@echo "  make erd-ecommerce - ecommerce ERD만 생성"
	@echo "  make erd-healthcare - healthcare ERD만 생성"
	@echo "  make clean         - 생성된 .mmd 파일 삭제"
	@echo ""

# 모든 도메인 ERD 생성
erd:
	@echo "🔄 Generating ERDs for all domains..."
	python update_erd.py

erd-all: erd

# 개별 도메인 ERD 생성
erd-finance:
	@echo "🔄 Generating ERD for finance..."
	python update_erd.py finance

erd-hr:
	@echo "🔄 Generating ERD for hr..."
	python update_erd.py hr

erd-ecommerce:
	@echo "🔄 Generating ERD for ecommerce..."
	python update_erd.py ecommerce

erd-healthcare:
	@echo "🔄 Generating ERD for healthcare..."
	python update_erd.py healthcare

# 생성된 파일 정리
clean:
	@echo "🧹 Cleaning generated .mmd files..."
	@find . -name "ERD.mmd" -type f -delete
	@echo "✅ Cleaned!"

