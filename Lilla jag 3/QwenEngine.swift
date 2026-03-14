// QwenEngine.swift
// Lilla Jag – Qwen CoreML inferensmotor
//
// ─────────────────────────────────────────────────────────────────
// AKTIVERING:
//   1. Konvertera Qwen GGUF → CoreML mlpackage:
//      python3 -m coremltools.converters.gguf qwen2.5-1.5b-instruct.gguf -o Qwen25_1_5B_Instruct.mlpackage
//   2. Lägg till Qwen25_1_5B_Instruct.mlpackage i Xcode (Target → Build Phases → Bundle Resources)
//   3. Lägg till QwenTokenizer.json i Bundle Resources
//   Modellens ChatML-format: <|im_start|>system\n...<|im_end|>\n<|im_start|>user\n...<|im_end|>\n<|im_start|>assistant\n
//
// Faller tillbaka på KBTFallback (i LillaJagAI.swift) om modell saknas.
// ─────────────────────────────────────────────────────────────────

import Foundation
import CoreML

// MARK: - QwenEngine

actor QwenEngine {
    static let shared = QwenEngine()

    private var model: MLModel?
    private var tokenizer: QwenTokenizer?
    private(set) var isLoaded = false

    // Qwen ChatML special tokens
    private let imStart = "<|im_start|>"
    private let imEnd = "<|im_end|>"

    private init() {}

    // MARK: - Loading

    func loadIfNeeded() async {
        guard !isLoaded else { return }

        // Load tokenizer
        tokenizer = QwenTokenizer()
        await tokenizer?.load()

        // Load CoreML model
        let modelNames = [
            "Qwen25_1_5B_Instruct",
            "qwen2.5-1.5b-instruct-q4_k_m",
            "Qwen2_5_1_5B",
            Config.qwenModelFilename.replacingOccurrences(of: ".gguf", with: "")
        ]

        for name in modelNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "mlpackage") {
                let cfg = MLModelConfiguration()
                cfg.computeUnits = .cpuAndNeuralEngine
                cfg.allowLowPrecisionAccumulationOnGPU = true
                if let loaded = try? MLModel(contentsOf: url, configuration: cfg) {
                    model = loaded
                    isLoaded = true
                    print("[Qwen] Modell laddad: \(name) ✓")
                    return
                }
            }
        }
        print("[Qwen] Ingen modell hittad i bundle — använder KBTFallback")
    }

    // MARK: - Text generation

    /// Generera svar (streaming). Returnerar hela svaret, anropar onToken för varje nytt ord.
    func generate(
        systemPrompt: String,
        conversationHistory: [(role: String, content: String)],
        userMessage: String,
        maxNewTokens: Int = 300,
        temperature: Float = 0.75,
        onToken: ((String) -> Void)? = nil
    ) async -> String {
        await loadIfNeeded()

        guard let model = model, let tokenizer = tokenizer, isLoaded else {
            return "" // Signal to caller to use KBTFallback
        }

        // Build ChatML prompt
        var prompt = "\(imStart)system\n\(systemPrompt)\(imEnd)\n"
        for msg in conversationHistory.suffix(8) { // Keep last 8 turns for context
            prompt += "\(imStart)\(msg.role)\n\(msg.content)\(imEnd)\n"
        }
        prompt += "\(imStart)user\n\(userMessage)\(imEnd)\n\(imStart)assistant\n"

        // Tokenize
        var inputIds = await tokenizer.encode(prompt)
        guard !inputIds.isEmpty else { return "" }

        var generated: [Int] = []
        var resultText = ""

        for _ in 0..<maxNewTokens {
            let context = Array(inputIds.suffix(512))
            guard let nextId = await predictNextToken(model: model, inputIds: context, temperature: temperature) else {
                break
            }

            // Stop on EOS tokens
            if await tokenizer.isEOS(nextId) { break }

            // Stop on <|im_end|>
            let decoded = await tokenizer.decode([nextId])
            if decoded.contains(imEnd) { break }

            generated.append(nextId)
            inputIds.append(nextId)
            resultText += decoded

            onToken?(decoded)

            // Small delay for smoother streaming UX
            try? await Task.sleep(nanoseconds: 15_000_000)
        }

        return resultText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Token prediction

    private func predictNextToken(model: MLModel, inputIds: [Int], temperature: Float) async -> Int? {
        do {
            let seqLen = inputIds.count
            let shape: [NSNumber] = [1, NSNumber(value: seqLen)]
            let inputArr = try MLMultiArray(shape: shape, dataType: .int32)
            let maskArr = try MLMultiArray(shape: shape, dataType: .int32)
            for (i, id) in inputIds.enumerated() {
                inputArr[i] = NSNumber(value: id)
                maskArr[i] = NSNumber(value: 1)
            }
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "input_ids": inputArr,
                "attention_mask": maskArr
            ])
            let output = try await model.prediction(from: input)
            guard let logits = output.featureValue(for: "logits")?.multiArrayValue else { return nil }
            let vocabSize = logits.shape.last?.intValue ?? 32768
            let offset = (seqLen - 1) * vocabSize
            var la = [Float](repeating: 0, count: vocabSize)
            for i in 0..<vocabSize { la[i] = logits[offset + i].floatValue }
            return sampleFromLogits(la, temperature: temperature)
        } catch {
            return nil
        }
    }

    private func sampleFromLogits(_ logits: [Float], temperature: Float) -> Int {
        let scaled = logits.map { $0 / max(temperature, 0.01) }
        let maxVal = scaled.max() ?? 0
        let exps = scaled.map { Foundation.exp($0 - maxVal) }
        let sum = exps.reduce(0, +)
        let probs = exps.map { $0 / sum }
        var cum: Float = 0
        let r = Float.random(in: 0..<1)
        for (i, p) in probs.enumerated() {
            cum += p
            if cum >= r { return i }
        }
        return probs.indices.max(by: { probs[$0] < probs[$1] }) ?? 0
    }
}

// MARK: - QwenTokenizer
// Enkel BPE-tokenizer för Qwen. Laddar tokenizer.json om tillgänglig.
// Utan fil: ord-baserad tokenisering (fungerar men ger suboptimala resultat).

actor QwenTokenizer {
    private var vocab: [String: Int] = [:]
    private var reverseVocab: [Int: String] = [:]
    private let eosIds: Set<Int> = [151643, 151645] // Qwen EOS tokens

    func load() async {
        guard let url = Bundle.main.url(forResource: "QwenTokenizer", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let vocabDict = json["vocab"] as? [String: Int] else {
            print("[QwenTokenizer] tokenizer.json ej hittad — använder ord-tokenisering")
            return
        }
        vocab = vocabDict
        reverseVocab = Dictionary(uniqueKeysWithValues: vocabDict.map { ($1, $0) })
        print("[QwenTokenizer] \(vocab.count) tokens laddade")
    }

    func encode(_ text: String) -> [Int] {
        guard !vocab.isEmpty else {
            // Ord-baserad fallback: varje ord → hash-baserat id
            return text.split(separator: " ").map { abs($0.hashValue) % 32000 }
        }
        // Greedy longest-match tokenization
        var ids: [Int] = []
        var remaining = text
        while !remaining.isEmpty {
            var matched = false
            for len in stride(from: min(remaining.count, 20), through: 1, by: -1) {
                let prefix = String(remaining.prefix(len))
                if let id = vocab[prefix] {
                    ids.append(id)
                    remaining = String(remaining.dropFirst(len))
                    matched = true
                    break
                }
            }
            if !matched {
                ids.append(vocab["<unk>"] ?? 0)
                remaining = String(remaining.dropFirst())
            }
        }
        return ids
    }

    func decode(_ ids: [Int]) -> String {
        guard !reverseVocab.isEmpty else {
            return ids.map { String(UnicodeScalar(max(32, min(126, $0)))!) }.joined(separator: " ")
        }
        return ids.compactMap { reverseVocab[$0] }.joined()
            .replacingOccurrences(of: "Ġ", with: " ")  // GPT-style space token
            .replacingOccurrences(of: "▁", with: " ")  // SentencePiece space token
    }

    func isEOS(_ id: Int) -> Bool {
        eosIds.contains(id)
    }
}
