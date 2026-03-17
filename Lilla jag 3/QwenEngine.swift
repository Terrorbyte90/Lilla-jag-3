// QwenEngine.swift
// Lilla Jag – Qwen3 llama.cpp inferensmotor
//
// ─────────────────────────────────────────────────────────────────
// KRAV:
//   • llama.cpp SPM-paket tillagt i Xcode
//   • Qwen3-1.7B-Q4_K_M.gguf i app-bunten (Bundle Resource)
//
// Modellens ChatML-format med /no_think för att hoppa över
// tankekedjan: <|im_start|>system\n...<|im_end|>\n...
// Faller tillbaka på KBTFallback (i LillaJagAI.swift) om modell saknas.
// ─────────────────────────────────────────────────────────────────

import Foundation
import llama

// MARK: - QwenEngine

actor QwenEngine {
    static let shared = QwenEngine()

    private var model: OpaquePointer?
    private var ctx: OpaquePointer?
    private(set) var isLoaded = false
    private var loadAttempted = false

    private let modelFileName = "Qwen3-1.7B-Q4_K_M"
    private let maxContextSize: Int32 = 2048

    private init() {}

    // MARK: - Loading

    func loadIfNeeded() async {
        guard !isLoaded, !loadAttempted else { return }
        loadAttempted = true

        llama_backend_init()

        guard let modelPath = Bundle.main.path(forResource: modelFileName, ofType: "gguf") else {
            print("[QwenEngine] \(modelFileName).gguf ej hittad i bundle — använder KBTFallback")
            return
        }

        var mparams = llama_model_default_params()
        mparams.n_gpu_layers = 99  // Metal – lägg alla lager på GPU/Neural Engine

        guard let loadedModel = llama_load_model_from_file(modelPath, mparams) else {
            print("[QwenEngine] llama_load_model_from_file misslyckades")
            return
        }
        model = loadedModel

        var cparams = llama_context_default_params()
        cparams.n_ctx    = UInt32(maxContextSize)
        cparams.n_batch  = 512
        cparams.n_threads = Int32(max(2, ProcessInfo.processInfo.processorCount - 2))
        cparams.flash_attn = true

        guard let genCtx = llama_new_context_with_model(loadedModel, cparams) else {
            print("[QwenEngine] llama_new_context_with_model misslyckades")
            llama_free_model(loadedModel)
            model = nil
            return
        }
        ctx = genCtx
        isLoaded = true
        print("[QwenEngine] Qwen3-1.7B laddat ✓ (Metal, flash_attn)")
    }

    // MARK: - Unload

    func unload() {
        if let c = ctx  { llama_free(c);        ctx   = nil }
        if let m = model { llama_free_model(m); model = nil }
        isLoaded     = false
        loadAttempted = false
        print("[QwenEngine] Modell urladdad")
    }

    // MARK: - Text Generation

    func generate(
        systemPrompt: String,
        conversationHistory: [(role: String, content: String)],
        userMessage: String,
        maxNewTokens: Int = 250,
        temperature: Float = 0.75
    ) async -> String {
        // Termisk säkerhetsbrytare
        let thermal = ProcessInfo.processInfo.thermalState
        if thermal == .critical { return "" }

        await loadIfNeeded()
        guard isLoaded, let mdl = model, let genCtx = ctx else { return "" }

        let prompt = buildPrompt(
            systemPrompt: systemPrompt,
            history: conversationHistory,
            userMessage: userMessage
        )

        // Tokenisera
        let tokens = tokenize(model: mdl, text: prompt, addBos: true)
        guard !tokens.isEmpty else { return "" }

        llama_kv_cache_clear(genCtx)

        // Prefill — kör hela prompten i en batch
        var batch = llama_batch_init(Int32(tokens.count), 0, 1)
        for (i, tok) in tokens.enumerated() {
            batchAdd(&batch, id: tok, pos: Int32(i), seqIds: [0], logits: i == tokens.count - 1)
        }
        if llama_decode(genCtx, batch) != 0 {
            llama_batch_free(batch)
            return ""
        }
        llama_batch_free(batch)

        // Sampler-kedja
        let sparams = llama_sampler_chain_default_params()
        let sampler = llama_sampler_chain_init(sparams)
        let nVocabForPenalty = llama_n_vocab(mdl)
        let eosForPenalty = llama_token_eos(mdl)
        let nlForPenalty = llama_token_nl(mdl)
        llama_sampler_chain_add(sampler, llama_sampler_init_penalties(nVocabForPenalty, eosForPenalty, nlForPenalty, 64, 1.1, 0.0, 0.0, false, false))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.9, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(temperature))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(UInt32.random(in: 0..<UInt32.max)))

        // Generera tokens
        var outputTokens: [llama_token] = []
        var nPos = Int32(tokens.count)
        let eosId = llama_token_eos(mdl)
        let nVocab = llama_n_vocab(mdl)

        for _ in 0..<maxNewTokens {
            let newToken = llama_sampler_sample(sampler, genCtx, -1)

            if newToken == eosId || newToken >= nVocab { break }

            // Kolla om det är <|im_end|>
            let piece = tokenToPiece(model: mdl, token: newToken)
            if piece.contains("<|im_end|>") { break }

            outputTokens.append(newToken)

            // Mata in nästa token
            var nextBatch = llama_batch_init(1, 0, 1)
            batchAdd(&nextBatch, id: newToken, pos: nPos, seqIds: [0], logits: true)
            let decodeResult = llama_decode(genCtx, nextBatch)
            llama_batch_free(nextBatch)
            if decodeResult != 0 { break }
            nPos += 1
        }

        llama_sampler_free(sampler)

        // Detokenisera
        let rawOutput = outputTokens.map { tokenToPiece(model: mdl, token: $0) }.joined()
        return cleanOutput(rawOutput)
    }

    // MARK: - Prompt Builder

    private func buildPrompt(
        systemPrompt: String,
        history: [(role: String, content: String)],
        userMessage: String
    ) -> String {
        var p = "<|im_start|>system\n\(systemPrompt) /no_think<|im_end|>\n"
        for turn in history.suffix(6) {
            p += "<|im_start|>\(turn.role)\n\(turn.content)<|im_end|>\n"
        }
        p += "<|im_start|>user\n\(userMessage)<|im_end|>\n<|im_start|>assistant\n"
        return p
    }

    // MARK: - llama.cpp Helpers

    private func tokenize(model: OpaquePointer, text: String, addBos: Bool) -> [llama_token] {
        let utf8 = text.utf8
        let maxTokens = utf8.count + (addBos ? 1 : 0) + 16
        var buf = [llama_token](repeating: 0, count: maxTokens)
        let n = llama_tokenize(model, text, Int32(utf8.count), &buf, Int32(maxTokens), addBos, false)
        guard n > 0 else { return [] }
        return Array(buf.prefix(Int(n)))
    }

    private func tokenToPiece(model: OpaquePointer, token: llama_token) -> String {
        var buf = [CChar](repeating: 0, count: 32)
        let n = llama_token_to_piece(model, token, &buf, 32, 0, false)
        guard n > 0 else { return "" }
        return String(bytes: buf.prefix(Int(n)).map { UInt8(bitPattern: $0) }, encoding: .utf8) ?? ""
    }

    private func batchAdd(
        _ batch: inout llama_batch,
        id: llama_token,
        pos: llama_pos,
        seqIds: [llama_seq_id],
        logits: Bool
    ) {
        let i = Int(batch.n_tokens)
        batch.token[i]    = id
        batch.pos[i]      = pos
        batch.n_seq_id[i] = Int32(seqIds.count)
        for (j, seqId) in seqIds.enumerated() {
            batch.seq_id[i]![j] = seqId
        }
        batch.logits[i] = logits ? 1 : 0
        batch.n_tokens += 1
    }

    // MARK: - Output Cleaning

    private func cleanOutput(_ raw: String) -> String {
        var text = raw

        // Ta bort <think>...</think> block (Qwen3 tankekedja)
        while let start = text.range(of: "<think>"), let end = text.range(of: "</think>") {
            if start.lowerBound <= end.upperBound {
                text.removeSubrange(start.lowerBound...end.upperBound)
            } else { break }
        }
        // Ta bort lösa taggar
        text = text.replacingOccurrences(of: "<think>", with: "")
        text = text.replacingOccurrences(of: "</think>", with: "")
        text = text.replacingOccurrences(of: "<|im_end|>", with: "")
        text = text.replacingOccurrences(of: "<|im_start|>", with: "")

        // Ta bort upprepade meningar
        text = deduplicateSentences(text)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func deduplicateSentences(_ text: String) -> String {
        var seen = Set<String>()
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
        var result: [String] = []
        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard trimmed.count > 8 else {
                result.append(sentence)
                continue
            }
            if !seen.contains(trimmed) {
                seen.insert(trimmed)
                result.append(sentence)
            }
        }
        return result.joined(separator: ". ")
            .replacingOccurrences(of: ".. ", with: ". ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
