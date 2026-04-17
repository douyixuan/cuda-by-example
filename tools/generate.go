package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"text/template"

	"github.com/alecthomas/chroma/v2"
	"github.com/alecthomas/chroma/v2/formatters/html"
	"github.com/alecthomas/chroma/v2/lexers"
	"github.com/alecthomas/chroma/v2/styles"

	"github.com/russross/blackfriday/v2"
)

var siteDir = "./public"

func check(err error) {
	if err != nil {
		panic(err)
	}
}

func isDir(path string) bool {
	fileStat, _ := os.Stat(path)
	return fileStat.IsDir()
}

func ensureDir(dir string) {
	err := os.MkdirAll(dir, 0755)
	check(err)
}

func copyFile(src, dst string) {
	dat, err := os.ReadFile(src)
	check(err)
	err = os.WriteFile(dst, dat, 0644)
	check(err)
}

func mustReadFile(path string) string {
	b, err := os.ReadFile(path)
	check(err)
	return string(b)
}

func markdown(src string) string {
	return string(blackfriday.Run([]byte(src)))
}

func readLines(path string) []string {
	src := mustReadFile(path)
	return strings.Split(src, "\n")
}

func mustGlob(glob string) []string {
	paths, err := filepath.Glob(glob)
	check(err)
	return paths
}

// normalizeBlockComments converts standalone /* */ block comment blocks into
// // line comments so the segment parser can handle them uniformly.
//
// Rules:
//  1. A line where /* is the first non-whitespace token starts a block comment.
//     Strip /*, emit as // <content>.
//  2. Lines inside a block comment: strip leading " * " if present, emit as // <content>.
//  3. A line containing only */ (possibly with whitespace) ends the block, emit nothing.
//  4. A line with code followed by /* comment */ inline is left untouched — it stays
//     as a code segment with the inline comment visible in syntax-highlighted output.
func normalizeBlockComments(lines []string) []string {
	out := make([]string, 0, len(lines))
	inBlock := false
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if !inBlock {
			if strings.HasPrefix(trimmed, "/*") {
				// Standalone block comment opener
				inBlock = true
				content := strings.TrimPrefix(trimmed, "/*")
				content = strings.TrimSuffix(content, "*/") // handle single-line /* ... */
				content = strings.TrimSpace(content)
				if content != "" {
					out = append(out, "// "+content)
				}
				// If the line also closes the block on the same line, exit block mode
				if strings.Contains(trimmed[2:], "*/") {
					inBlock = false
				}
			} else {
				out = append(out, line)
			}
		} else {
			// Inside a block comment
			if strings.Contains(trimmed, "*/") {
				// Closing line — strip everything up to and including */
				after := trimmed[strings.Index(trimmed, "*/")+2:]
				after = strings.TrimSpace(after)
				if after != "" {
					// Trailing code after */ — emit as code line
					out = append(out, after)
				}
				inBlock = false
			} else {
				// Interior line — strip leading " * " decoration if present
				content := trimmed
				if strings.HasPrefix(content, "* ") {
					content = content[2:]
				} else if content == "*" {
					content = ""
				}
				if content != "" {
					out = append(out, "// "+content)
				}
			}
		}
	}
	return out
}

var docsPat = regexp.MustCompile(`^(\s*(\/\/|#)\s|\s*\/\/$)`)
var dashPat = regexp.MustCompile(`\-+`)

// Seg is a segment of an example — a paired (docs, code) block.
type Seg struct {
	Docs, DocsRendered string
	Code, CodeRendered string
	CodeEmpty, CodeLeading bool
}

// Example holds all parsed data for one example page.
type Example struct {
	ID, Name    string
	Segs        [][]*Seg
	PrevExample *Example
	NextExample *Example
}

// Chapter groups examples under a named heading on the index page.
type Chapter struct {
	Name     string
	Examples []*Example
}

func parseSegs(sourcePath string) []*Seg {
	rawLines := readLines(sourcePath)
	// Normalize tabs and apply block-comment pre-processing
	var lines []string
	for _, l := range rawLines {
		lines = append(lines, strings.Replace(l, "\t", "    ", -1))
	}
	lines = normalizeBlockComments(lines)

	segs := []*Seg{}
	lastSeen := ""
	for _, line := range lines {
		if line == "" {
			lastSeen = ""
			continue
		}
		matchDocs := docsPat.MatchString(line)
		matchCode := !matchDocs
		newDocs := (lastSeen == "") || (lastSeen != "docs")
		newCode := (lastSeen == "") || ((lastSeen != "code") && (segs[len(segs)-1].Code != ""))
		if matchDocs {
			trimmed := docsPat.ReplaceAllString(line, "")
			if newDocs {
				segs = append(segs, &Seg{Docs: trimmed})
			} else {
				segs[len(segs)-1].Docs += "\n" + trimmed
			}
			lastSeen = "docs"
		} else if matchCode {
			if newCode {
				segs = append(segs, &Seg{Code: line})
			} else {
				last := segs[len(segs)-1]
				if last.Code == "" {
					last.Code = line
				} else {
					last.Code += "\n" + line
				}
			}
			lastSeen = "code"
		}
	}
	for i, seg := range segs {
		seg.CodeEmpty = (seg.Code == "")
		seg.CodeLeading = (i < len(segs)-1)
	}
	return segs
}

func chromaFormat(code, filePath string) string {
	lexer := lexers.Get(filePath)
	if lexer == nil {
		lexer = lexers.Fallback
	}
	lexer = chroma.Coalesce(lexer)
	style := styles.Get("swapoff")
	if style == nil {
		style = styles.Fallback
	}
	formatter := html.New(html.WithClasses(true))
	iterator, err := lexer.Tokenise(nil, code)
	check(err)
	buf := new(bytes.Buffer)
	err = formatter.Format(buf, style, iterator)
	check(err)
	return buf.String()
}

func parseAndRenderSegs(sourcePath string) []*Seg {
	segs := parseSegs(sourcePath)
	for _, seg := range segs {
		if seg.Docs != "" {
			seg.DocsRendered = markdown(seg.Docs)
		}
		if seg.Code != "" {
			seg.CodeRendered = chromaFormat(seg.Code, sourcePath)
		}
	}
	return segs
}

func parseExamplesFrom(txtPath, examplesDir string) ([]*Example, []*Chapter) {
	var chapters []*Chapter
	var curChapter *Chapter
	hasChapters := false

	examples := make([]*Example, 0)
	for _, line := range readLines(txtPath) {
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, "# ") {
			hasChapters = true
			curChapter = &Chapter{Name: strings.TrimPrefix(line, "# ")}
			chapters = append(chapters, curChapter)
			continue
		}
		if strings.HasPrefix(line, "#") {
			continue
		}

		ex := &Example{Name: line}
		id := strings.ToLower(line)
		id = strings.ReplaceAll(id, " ", "-")
		id = strings.ReplaceAll(id, "/", "-")
		id = strings.ReplaceAll(id, "'", "")
		id = dashPat.ReplaceAllString(id, "-")
		ex.ID = id
		ex.Segs = make([][]*Seg, 0)
		sourcePaths := mustGlob(examplesDir + "/" + id + "/*")
		for _, sp := range sourcePaths {
			if !isDir(sp) && strings.HasSuffix(sp, ".cu") {
				segs := parseAndRenderSegs(sp)
				ex.Segs = append(ex.Segs, segs)
			}
		}
		examples = append(examples, ex)
		if curChapter != nil {
			curChapter.Examples = append(curChapter.Examples, ex)
		}
	}
	for i, ex := range examples {
		if i > 0 {
			ex.PrevExample = examples[i-1]
		}
		if i < len(examples)-1 {
			ex.NextExample = examples[i+1]
		}
	}
	if !hasChapters {
		chapters = nil
	}
	return examples, chapters
}

func parseExamples() ([]*Example, []*Chapter) {
	return parseExamplesFrom("examples/examples.txt", "examples")
}

type indexData struct {
	Examples []*Example
	Chapters []*Chapter
}

func renderIndex(examples []*Example, chapters []*Chapter) {
	tmpl := template.New("index")
	template.Must(tmpl.Parse(mustReadFile("templates/footer.tmpl")))
	template.Must(tmpl.Parse(mustReadFile("templates/index.tmpl")))
	f, err := os.Create(siteDir + "/index.html")
	check(err)
	defer f.Close()
	check(tmpl.Execute(f, indexData{Examples: examples, Chapters: chapters}))
}

func renderExamples(examples []*Example) {
	tmpl := template.New("example")
	template.Must(tmpl.Parse(mustReadFile("templates/footer.tmpl")))
	template.Must(tmpl.Parse(mustReadFile("templates/example.tmpl")))
	for _, ex := range examples {
		dir := siteDir + "/" + ex.ID
		ensureDir(dir)
		f, err := os.Create(dir + "/index.html")
		check(err)
		defer f.Close()
		check(tmpl.Execute(f, ex))
	}
}

func writeSearchIndex(examples []*Example) {
	type entry struct {
		ID   string `json:"id"`
		Name string `json:"name"`
		Text string `json:"text"`
	}
	entries := make([]entry, 0, len(examples))
	for _, ex := range examples {
		var sb strings.Builder
		for _, segs := range ex.Segs {
			for _, seg := range segs {
				sb.WriteString(seg.Docs)
				sb.WriteString(" ")
				sb.WriteString(seg.Code)
				sb.WriteString(" ")
			}
		}
		entries = append(entries, entry{
			ID:   ex.ID,
			Name: ex.Name,
			Text: strings.ToLower(sb.String()),
		})
	}
	data, err := json.Marshal(entries)
	check(err)
	check(os.WriteFile(siteDir+"/search-index.json", data, 0644))
}

func render404() {
	tmpl := template.New("404")
	template.Must(tmpl.Parse(mustReadFile("templates/footer.tmpl")))
	template.Must(tmpl.Parse(mustReadFile("templates/404.tmpl")))
	f, err := os.Create(siteDir + "/404.html")
	check(err)
	defer f.Close()
	check(tmpl.Execute(f, ""))
}

func main() {
	if len(os.Args) > 1 {
		siteDir = os.Args[1]
	}
	ensureDir(siteDir)
	copyFile("templates/site.css", siteDir+"/site.css")
	copyFile("templates/site.js", siteDir+"/site.js")
	copyFile("templates/favicon.ico", siteDir+"/favicon.ico")
	examples, chapters := parseExamples()
	fmt.Printf("Generating %d examples...\n", len(examples))
	renderIndex(examples, chapters)
	renderExamples(examples)
	render404()
	writeSearchIndex(examples)
	fmt.Println("Done →", siteDir)
}
