# Claudia Cooks

Claudia Cooks is a native macOS recipe builder that turns ingredient selections and free-form prompts into printable recipe PDFs **on device**. There is no cloud API for generation: recipes are produced by **harnessed local inference** through [MLX](https://github.com/ml-explore/mlx) and the [`mlx-swift-lm`](https://github.com/ml-explore/mlx-swift-lm) stack, then laid out into PDF pages that update in the preview pane as the model streams its response.

## What “harnessed local inference” means here

The app does not treat the language model as an open-ended chat endpoint. It wraps MLX in a narrow, recipe-specific pipeline:

1. **Model lifecycle** — Quantized Qwen3 models from the `mlx-community` Hugging Face repos are downloaded once, cached on disk, and loaded through a shared `MLXModelCache`. The user picks a tier (1.7B default vs. 0.6B fastest) or the app auto-selects the smaller model when physical or available RAM is low (`MLXSystemLoad`).

2. **Constrained generation** — `MLXClient` opens a `ChatSession` with a fixed system prompt (home-cook tone, pantry-staple rules, JSON-only output) and conservative sampling (`temperature` 0.1, capped token budget). Thinking/reasoning modes are disabled so tokens go straight into structured recipe content.

3. **Structured output contract** — The model must return a single JSON object with `title`, `summary`, `ingredients`, `steps`, and `tips`. `GeneratedRecipe+Decoding` tolerates incomplete streams: it repairs truncated JSON, strips markdown fences and thinking tags, and extracts fields from partial text so the UI can render before generation finishes.

4. **Availability gating** — `RecipeGenerationService` checks that weights are present locally (`HubClient` snapshot, `localFilesOnly`) before running inference. Until then, the PDF preview shows the user’s selections and setup guidance instead of calling the model.

Inference runs entirely on the Mac; selections and prompts never leave the machine for generation.

## Real-time PDF generation

PDF is both the **export format** and the **live canvas**. The preview is not a separate SwiftUI mock-up of the final document—it is a `PDFDocument` built with `PDFPageWriter` (AppKit + PDFKit) and displayed through `PDFRecipePreview` / `InteractivePDFView`.

## UI architecture (high level)

| Layer | Role |
|--------|------|
| **Views** (`FrameworkDetailView`, `IngredientBentoGrid`, `StackedPaperPreview`) | Split builder: pick framework and ingredients on the left, PDF “paper” on the right. |
| **View models** (`RecipeBuilderViewModel`, `MLXSetupViewModel`) | Debounced generation, streaming PDF updates, model download UX. |
| **Services** | `RecipeGenerationService` → `MLXClient`; `RecipePDFRenderer` + `PDFPageWriter`; `RecipeLibraryStore` for saved recipes. |
| **MLX** | Configuration, model cache, tokenizer, tier preferences, system load heuristics. |

The app entry point is `ClaudiasCookingApp` → `ContentView`: framework picker, then a navigation stack into the builder for the chosen cooking framework (e.g. skillet, sheet pan).

## Models and dependencies

- **Default:** `mlx-community/Qwen3-1.7B-4bit`
- **Low memory / fastest tier:** `mlx-community/Qwen3-0.6B-4bit`
- **Swift packages:** `MLXLLM`, `MLXLMCommon` (via `mlx-swift-lm`), Hugging Face Hub for downloads

Apple Silicon is assumed for MLX; generation quality and latency depend on the chosen tier and available unified memory.

## Building

Open `claudia-cooks.xcodeproj` in Xcode, resolve Swift package dependencies (`mlx-swift-lm`), and run the **claudia-cooks** target on macOS. On first use, download an MLX model tier from the in-app setup sheet; after weights are local, edits to ingredients or prompts trigger debounced generation and live PDF updates.
