from dataclasses import dataclass, field
from typing import List


@dataclass
class CourtCase:
    case_number: str
    court_name: str
    date: str
    document_type: str
    url: str
    excerpt: str = ""
    status: str = ""


@dataclass
class SearchResult:
    query: str
    total_found: int
    cases: List[CourtCase] = field(default_factory=list)
