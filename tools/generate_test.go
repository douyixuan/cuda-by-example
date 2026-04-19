package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCUFilesUseCppLexer(t *testing.T) {
	lexer := cudaLexer()
	cfg := lexer.Config()
	if cfg.Name != "C++" {
		t.Errorf("expected C++ lexer for .cu files, got %q", cfg.Name)
	}
}

func TestCUDAKeywordsHighlighted(t *testing.T) {
	code := `__global__ void hello() {}`
	rendered := chromaFormat(code, "test.cu")

	wantClasses := []string{"kr", "kt", "nf"}
	for _, cls := range wantClasses {
		needle := `class="` + cls + `"`
		if !strings.Contains(rendered, needle) {
			t.Errorf("chromaFormat output missing %s token class\nGot: %s", cls, rendered)
		}
	}
}

func TestCUDAKeywordsAreKeywordReserved(t *testing.T) {
	cudaKeywords := []string{
		"__global__", "__device__", "__host__",
		"__shared__", "__constant__",
	}
	for _, kw := range cudaKeywords {
		rendered := chromaFormat(kw+" void f() {}", "test.cu")
		if !strings.Contains(rendered, `class="kr"`) {
			t.Errorf("%s not tokenized as KeywordReserved (kr)\nGot: %s", kw, rendered)
		}
	}
}

func TestChromaFormatProducesSemanticTokens(t *testing.T) {
	code := `#include <stdio.h>
__global__ void hello() {
    printf("Hello from the GPU!\n");
}
int main() {
    hello<<<1, 1>>>();
    cudaDeviceSynchronize();
    return 0;
}`
	rendered := chromaFormat(code, "test.cu")

	semanticClasses := []string{"k", "nf", "s", "mi", "cp"}
	found := 0
	for _, cls := range semanticClasses {
		if strings.Contains(rendered, `class="`+cls+`"`) {
			found++
		}
	}
	if found < 3 {
		t.Errorf("expected at least 3 semantic token classes, found %d in output:\n%s", found, rendered)
	}
}

func TestParseExamplesWithChapters(t *testing.T) {
	tmpDir := t.TempDir()
	exDir := filepath.Join(tmpDir, "examples")
	os.MkdirAll(exDir, 0755)

	// Create a minimal .cu file for each example
	for _, id := range []string{"hello-world", "vector-add", "shared-memory", "atomics"} {
		dir := filepath.Join(exDir, id)
		os.MkdirAll(dir, 0755)
		os.WriteFile(filepath.Join(dir, id+".cu"), []byte("// test\nint main() { return 0; }\n"), 0644)
	}

	content := `# Basics
Hello World
Vector Add

# Memory
Shared Memory

# Sync
Atomics`

	os.WriteFile(filepath.Join(exDir, "examples.txt"), []byte(content), 0644)

	examples, chapters := parseExamplesFrom(filepath.Join(exDir, "examples.txt"), exDir)

	if len(examples) != 4 {
		t.Fatalf("expected 4 examples, got %d", len(examples))
	}

	if len(chapters) != 3 {
		t.Fatalf("expected 3 chapters, got %d", len(chapters))
	}

	// Check chapter names
	wantNames := []string{"Basics", "Memory", "Sync"}
	for i, ch := range chapters {
		if ch.Name != wantNames[i] {
			t.Errorf("chapter %d: want name %q, got %q", i, wantNames[i], ch.Name)
		}
	}

	// Check chapter example counts
	wantCounts := []int{2, 1, 1}
	for i, ch := range chapters {
		if len(ch.Examples) != wantCounts[i] {
			t.Errorf("chapter %d (%s): want %d examples, got %d", i, ch.Name, wantCounts[i], len(ch.Examples))
		}
	}

	// Check linear linking across chapters
	if examples[0].PrevExample != nil {
		t.Error("first example should have no PrevExample")
	}
	if examples[0].NextExample != examples[1] {
		t.Error("first example NextExample should be second example")
	}
	if examples[3].NextExample != nil {
		t.Error("last example should have no NextExample")
	}
	if examples[3].PrevExample != examples[2] {
		t.Error("last example PrevExample should be third example")
	}
}

func TestParseExamplesWithoutChapters(t *testing.T) {
	tmpDir := t.TempDir()
	exDir := filepath.Join(tmpDir, "examples")
	os.MkdirAll(exDir, 0755)

	for _, id := range []string{"hello-world", "vector-add"} {
		dir := filepath.Join(exDir, id)
		os.MkdirAll(dir, 0755)
		os.WriteFile(filepath.Join(dir, id+".cu"), []byte("// test\nint main() { return 0; }\n"), 0644)
	}

	content := `Hello World
Vector Add`

	os.WriteFile(filepath.Join(exDir, "examples.txt"), []byte(content), 0644)

	examples, chapters := parseExamplesFrom(filepath.Join(exDir, "examples.txt"), exDir)

	if len(examples) != 2 {
		t.Fatalf("expected 2 examples, got %d", len(examples))
	}

	// No chapter headers → 0 chapters (all examples in implicit default)
	if len(chapters) != 0 {
		t.Fatalf("expected 0 chapters for headerless file, got %d", len(chapters))
	}
}

func TestCUBChapterExistsInExamplesTxt(t *testing.T) {
	exDir := filepath.Join("..", "examples")
	examplesFile := filepath.Join(exDir, "examples.txt")

	examples, chapters := parseExamplesFrom(examplesFile, exDir)
	_ = examples

	var cubChapter *Chapter
	for _, ch := range chapters {
		if ch.Name == "CUB Library" {
			cubChapter = ch
			break
		}
	}
	if cubChapter == nil {
		t.Fatal("CUB Library chapter not found in examples.txt")
	}
	if len(cubChapter.Examples) != 5 {
		t.Errorf("CUB Library chapter: want 5 examples, got %d", len(cubChapter.Examples))
	}

	wantIDs := []string{"cub-warp-reduce", "cub-block-reduce", "cub-device-reduce", "cub-device-scan", "cub-device-sort"}
	for i, ex := range cubChapter.Examples {
		if ex.ID != wantIDs[i] {
			t.Errorf("CUB example %d: want ID %q, got %q", i, wantIDs[i], ex.ID)
		}
	}
}

func TestTexturesChapterMovedToEnd(t *testing.T) {
	exDir := filepath.Join("..", "examples")
	examplesFile := filepath.Join(exDir, "examples.txt")

	_, chapters := parseExamplesFrom(examplesFile, exDir)

	if len(chapters) == 0 {
		t.Fatal("no chapters found")
	}
	last := chapters[len(chapters)-1]
	if last.Name != "Textures and Surfaces" {
		t.Errorf("last chapter should be Textures and Surfaces, got %q", last.Name)
	}
}

func TestLLMOperatorsChapterExistsInExamplesTxt(t *testing.T) {
	exDir := filepath.Join("..", "examples")
	examplesFile := filepath.Join(exDir, "examples.txt")

	_, chapters := parseExamplesFrom(examplesFile, exDir)

	var llmChapter *Chapter
	for _, ch := range chapters {
		if ch.Name == "LLM Operators" {
			llmChapter = ch
			break
		}
	}
	if llmChapter == nil {
		t.Fatal("LLM Operators chapter not found in examples.txt")
	}
	if len(llmChapter.Examples) != 8 {
		t.Errorf("LLM Operators chapter: want 8 examples, got %d", len(llmChapter.Examples))
	}

	wantIDs := []string{
		"online-softmax", "layer-norm", "rms-norm", "gelu-activation",
		"rope-embedding", "int8-quantization", "naive-attention", "flash-attention-tiling",
	}
	for i, ex := range llmChapter.Examples {
		if ex.ID != wantIDs[i] {
			t.Errorf("LLM example %d: want ID %q, got %q", i, wantIDs[i], ex.ID)
		}
	}
}

func TestAdvancedKernelTechniquesHasKernelFusion(t *testing.T) {
	exDir := filepath.Join("..", "examples")
	examplesFile := filepath.Join(exDir, "examples.txt")

	_, chapters := parseExamplesFrom(examplesFile, exDir)

	var ch *Chapter
	for _, c := range chapters {
		if c.Name == "Advanced Kernel Techniques" {
			ch = c
			break
		}
	}
	if ch == nil {
		t.Fatal("Advanced Kernel Techniques chapter not found")
	}
	if len(ch.Examples) != 6 {
		t.Errorf("Advanced Kernel Techniques: want 6 examples, got %d", len(ch.Examples))
	}
	last := ch.Examples[len(ch.Examples)-1]
	if last.ID != "kernel-fusion" {
		t.Errorf("last Advanced Kernel Techniques example: want kernel-fusion, got %q", last.ID)
	}
}

func TestLibrariesHasCublasBatchedGemm(t *testing.T) {
	exDir := filepath.Join("..", "examples")
	examplesFile := filepath.Join(exDir, "examples.txt")

	_, chapters := parseExamplesFrom(examplesFile, exDir)

	var ch *Chapter
	for _, c := range chapters {
		if c.Name == "Libraries" {
			ch = c
			break
		}
	}
	if ch == nil {
		t.Fatal("Libraries chapter not found")
	}
	if len(ch.Examples) != 4 {
		t.Errorf("Libraries: want 4 examples, got %d", len(ch.Examples))
	}
	found := false
	for _, ex := range ch.Examples {
		if ex.ID == "cublas-batched-gemm" {
			found = true
			break
		}
	}
	if !found {
		t.Error("cublas-batched-gemm not found in Libraries chapter")
	}
}

func TestParseExamplesChapterPointers(t *testing.T) {
	tmpDir := t.TempDir()
	exDir := filepath.Join(tmpDir, "examples")
	os.MkdirAll(exDir, 0755)

	for _, id := range []string{"hello-world", "shared-memory"} {
		dir := filepath.Join(exDir, id)
		os.MkdirAll(dir, 0755)
		os.WriteFile(filepath.Join(dir, id+".cu"), []byte("// test\nint main() { return 0; }\n"), 0644)
	}

	content := `# Basics
Hello World

# Memory
Shared Memory`

	os.WriteFile(filepath.Join(exDir, "examples.txt"), []byte(content), 0644)

	_, chapters := parseExamplesFrom(filepath.Join(exDir, "examples.txt"), exDir)

	if chapters[0].Examples[0].Name != "Hello World" {
		t.Errorf("chapter 0 example 0: want Hello World, got %s", chapters[0].Examples[0].Name)
	}
	if chapters[1].Examples[0].Name != "Shared Memory" {
		t.Errorf("chapter 1 example 0: want Shared Memory, got %s", chapters[1].Examples[0].Name)
	}
}
