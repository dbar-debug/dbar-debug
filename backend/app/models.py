from dataclasses import dataclass, field
from typing import List


@dataclass
class CaseMember:
    name: str
    role: str


@dataclass
class CaseJudge:
    name: str
    role: str


@dataclass
class CourtCase:
    case_number: str
    court_name: str
    date: str
    document_type: str
    url: str
    excerpt: str = ""
    status: str = ""
    judge: str = ""
    created_at: str = ""
    updated_at: str = ""
    proceeding_number: str = ""
    members: List[CaseMember] = field(default_factory=list)
    judges: List[CaseJudge] = field(default_factory=list)


@dataclass
class SearchResult:
    query: str
    total_found: int
    cases: List[CourtCase] = field(default_factory=list)
