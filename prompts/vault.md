---
description: "Obsidian vault 노트 관리 — 전략 로딩 후 검색, 생성, 편집을 수행합니다."
argument-hint: "<action> [args] (예: search 'query', create 'title', read 'note')"
---

# /vault — Obsidian Vault Assistant

obsctl을 통해 Obsidian vault의 노트를 관리합니다.
**반드시 전략 문서를 먼저 로딩**하고, 그 규칙에 따라 작업합니다.

## Step 1: 전략 로딩

먼저 vault 운영 전략을 context로 가져옵니다:

```bash
obsctl strategy
```

성공하면 그 전략의 모든 규칙(영역 구분, 타입 체계, frontmatter 규칙, 작성 규칙)을 이후 작업에 적용합니다.

**Fallback (strategy가 설정되지 않았거나 파일이 없을 때):**

`obsctl strategy`가 비어 있거나 stderr에 warning을 출력하면, vault 루트의 `AGENTS.md`를 대신 읽어 운영 지침으로 사용합니다:

```bash
obsctl read AGENTS.md
```

`AGENTS.md`도 없으면 사용자에게 다음을 안내합니다:
- vault에 전략 문서를 만들 것
- `~/.config/obsctl/config.json`의 `"strategy"` 필드에 파일명 등록
- 또는 vault 루트에 `AGENTS.md`를 둬서 fallback으로 사용

## Step 2: 사용자 요청 분석

사용자가 입력한 인자를 분석하여 작업을 결정합니다:

| 패턴 | 작업 |
|------|------|
| `search <query>` | `obsctl search <query>`로 검색 |
| `read <note>` | `obsctl read <note>`로 읽기 |
| `create <title>` | 전략의 타입/frontmatter 규칙에 따라 노트 생성 |
| `today` | `obsctl today`로 일간 노트 읽기 |
| `today:add <text>` | `obsctl today:add <text>`로 일간 노트에 추가 |
| `ls [folder]` | `obsctl ls [folder]`로 파일 목록 |
| `tags` | `obsctl tags`로 태그 목록 |
| 인자 없음 | 무엇을 하고 싶은지 질문 |

## Step 3: 작업 수행

### 검색 시
```bash
obsctl search '<query>'
```
결과를 요약하고 관련 노트를 제안합니다.

### 노트 생성 시

1. 전략의 **영역 구분**에 따라 적절한 폴더를 결정:
   - 업무 → `sonatus/` 하위
   - 블로그 → `blogs/` 하위 (개인정보 금지 확인)
   - 개인 지식 → 루트 또는 `Wiki/`

2. 전략의 **노트 타입**에 따라 frontmatter를 구성:
   - concept, guide, reference, issue, task 중 적합한 타입 선택
   - 해당 템플릿의 frontmatter 양식 적용
   - categories에 관련 MoC 이름 기입

3. 노트 생성:
```bash
obsctl create name="<title>" content="<frontmatter + content>"
```

### 노트 편집 시

1. 기존 노트를 먼저 읽음:
```bash
obsctl read <note>
```

2. 전략의 "기존 노트와 중복되면 새로 만들지 않고 추가" 규칙 적용

3. 수정 내용 추가:
```bash
obsctl append path="<path>" content="<추가 내용>"
```

## 규칙 (전략에서 파생)

- 노트 생성 전 `obsctl search`로 중복 확인
- frontmatter 없는 노트를 만들지 않음
- blogs 폴더에 개인정보 절대 포함 금지
- Atomic 원칙: 하나의 노트에 하나의 주제
- 일간 노트의 내용이 충분히 쌓이면 atomic note 분리를 제안
