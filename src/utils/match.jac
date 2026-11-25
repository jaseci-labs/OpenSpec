def nearestMatches(input: str, candidates: list[str], max: int = 5) -> list[str] {
    return sorted(candidates, key=lambda (c: str) -> int { levenshtein(input, c) })[:max];
}

def levenshtein(a: str, b: str) -> int {
    row = list(range(len(b) + 1));
    for (i, ca) in enumerate(a, 1) {
        prev = row;
        row = [i];
        for (j, cb) in enumerate(b, 1) {
            row.append(min(prev[j] + 1, row[j - 1] + 1, prev[j - 1] + (0 if ca == cb else 1)));
        }
    }
    return row[-1];
}
