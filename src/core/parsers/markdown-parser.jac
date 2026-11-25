type Section = any;

glob:priv HEADER: str = "^(#{1,6})\\s+",
          DELTA_OPERATIONS: list[tuple[str, str]] = [
              ("RENAMED", "\\brename(s|d|ing)?\\b|\\brenamed\\s+(to|from)\\b"),
              ("ADDED", "\\badd(s|ed|ing)?\\b|\\bcreate(s|d|ing)?\\b|\\bnew\\b"),
              ("REMOVED", "\\bremove(s|d|ing)?\\b|\\bdelete(s|d|ing)?\\b"),
          ];

def:priv content(section: any) -> any {
    return "" if section is None else section["content"];
}

obj MarkdownParser(globalThis.Object) {
    def init(content: str) {
        super.init();
        self.lines = MarkdownParser.normalizeContent(content).split("\n");
        self.codeFenceLineMask = buildCodeFenceMask(self.lines);
    }

    static def normalizeContent(content: str) -> str {
        return sub(sub(content, "^\\uFEFF", "", ""), "\\r\\n?", "\n");
    }

    def parseSpec(name: str) -> any {
        sections = self.parseSections();
        purpose = content(self.findSection(sections, "Purpose"));
        requirementsSection = self.findSection(sections, "Requirements");
        if not purpose {
            raise new(globalThis.Error, "Spec must have a Purpose section");
        }
        if requirementsSection is None {
            raise new(globalThis.Error, "Spec must have a Requirements section");
        }
        return rec(
            name=name,
            overview=purpose.trim(),
            requirements=self.parseRequirements(requirementsSection),
            metadata=rec(version="1.0.0", format="openspec"),
        );
    }

    def parseChange(name: str) -> any {
        sections = self.parseSections();
        why = content(self.findSection(sections, "Why"));
        whatChanges = content(self.findSection(sections, "What Changes"));
        if not why {
            raise new(globalThis.Error, "Change must have a Why section");
        }
        if not whatChanges {
            raise new(globalThis.Error, "Change must have a What Changes section");
        }
        return rec(
            name=name,
            why=why.trim(),
            whatChanges=whatChanges.trim(),
            deltas=self.parseDeltas(whatChanges),
            metadata=rec(version="1.0.0", format="openspec-change"),
        );
    }

    def parseSections -> any {
        sections = [];
        stack: list[any] = [];
        lines: any = self.lines;
        mask: any = self.codeFenceLineMask;
        for i in range(len(lines)) {
            line: str = lines[i];
            if mask[i] or not line.startswith("#") {
                continue;
            }
            header = matchOf(line, "^(#{1,6})\\s+(.+)$");
            if not header {
                continue;
            }
            level = len(header[1]);
            section = rec(
                level=level,
                title=stripClosingSequence(header[2]),
                content=self.getContentUntilNextHeader(i + 1, level),
                children=[],
            );
            while stack and stack[-1].level >= level {
                stack.pop();
            }
            (stack[-1].children if stack else sections).append(section);
            stack.append(section);
        }
        return sections;
    }

    def getContentUntilNextHeader(startLine: int, currentLevel: int) -> str {
        lines: any = self.lines;
        mask: any = self.codeFenceLineMask;
        count = len(lines);
        end = startLine;
        while end < count {
            line: str = lines[end];
            header = JsNull if mask[end] or not line.startswith("#") else matchOf(line, HEADER);
            if header and len(header[1]) <= currentLevel {
                break;
            }
            end += 1;
        }
        joined: any = "\n".join(lines[startLine:end]);
        return joined.trim();
    }

    def findSection(sections: any, title: str) -> any {
        for section in sections {
            if section.title.lower() == title.lower() {
                return section;
            }
            child = self.findSection(section.children, title);
            if child is not None {
                return child;
            }
        }
        return None;
    }

    def parseRequirements(section: any) -> any {
        return [
            rec(
                name=normalizeRequirementName(sub(child.title, "^Requirement:\\s*", "", "i")),
                text=extractRequirementText(child.title, child.content.split("\n")),
                scenarios=self.parseScenarios(child),
            )
            for child in section.children
        ];
    }

    def parseScenarios(requirementSection: any) -> any {
        return [
            rec(name=scenarioNameFromHeaderText(child.title), rawText=child.content)
            for child in requirementSection.children
            if hasScenarioBody(child.content)
        ];
    }

    def parseDeltas(content: str) -> any {
        deltas = [];
        for line in content.split("\n") {
            m = matchOf(line, "^\\s*-\\s*\\*\\*([^*:]+)(?::\\*\\*|\\*\\*:)\\s*(.+)$");
            if not m {
                continue;
            }
            description: any = m[2].trim();
            lowerDesc = description.toLowerCase();
            operation = "MODIFIED";
            for (op, pattern) in DELTA_OPERATIONS {
                if found(lowerDesc, pattern) {
                    operation = op;
                    break;
                }
            }
            deltas.append(rec(spec=m[1].trim(), operation=operation, description=description));
        }
        return deltas;
    }
}
