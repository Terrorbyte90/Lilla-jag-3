// LillaJagMLEngine.swift
// Lilla Jag – Lokal CoreML-inferensmotor
//
// Tre modeller (alla kräver KB-BERT-embedding som input):
//   1. EmotionMultiLabel  → 8 Plutchik-emotioner (glädje, sorg, ilska, rädsla, förvåning, äckel, förtroende, förväntan)
//   2. SentimentScorer    → sentiment [-1, +1]
//   3. TopicClassifier    → 14 ämnen (psychology, health m.fl.)
//
// KBBertSwedish.mlpackage genererar 768-dim CLS-vektorer.
// NLEmbedding (svenska/engelska) används som fallback om BERT saknas.

import Foundation
import CoreML
import NaturalLanguage
import SwiftUI

// MARK: - Emotion model

struct EmotionResult: Equatable {
    let glädje: Float
    let sorg: Float
    let ilska: Float
    let rädsla: Float
    let förvåning: Float
    let äckel: Float
    let förtroende: Float
    let förväntan: Float

    var dominant: (name: String, value: Float) {
        let all: [(String, Float)] = [
            ("glädje", glädje), ("sorg", sorg), ("ilska", ilska),
            ("rädsla", rädsla), ("förvåning", förvåning), ("äckel", äckel),
            ("förtroende", förtroende), ("förväntan", förväntan)
        ]
        return all.max(by: { $0.1 < $1.1 }) ?? ("okänd", 0)
    }

    var top3: [(name: String, value: Float)] {
        let all: [(String, Float)] = [
            ("glädje", glädje), ("sorg", sorg), ("ilska", ilska),
            ("rädsla", rädsla), ("förvåning", förvåning), ("äckel", äckel),
            ("förtroende", förtroende), ("förväntan", förväntan)
        ]
        return all.sorted { $0.1 > $1.1 }.prefix(3).map { $0 }
    }

    var color: Color {
        switch dominant.name {
        case "glädje":    return Color.warmGold
        case "sorg":      return Color(hex: 0x6B8DD6)
        case "ilska":     return Color(hex: 0xFF5B5B)
        case "rädsla":    return Color.warmLavender
        case "förvåning": return Color.warmSage
        case "äckel":     return Color(hex: 0x8B6F47)
        case "förtroende": return Color.warmRose
        case "förväntan": return Color.warmCoral
        default:          return Color.warmLavender
        }
    }

    var icon: String {
        switch dominant.name {
        case "glädje":    return "sun.max.fill"
        case "sorg":      return "cloud.rain.fill"
        case "ilska":     return "bolt.fill"
        case "rädsla":    return "wind"
        case "förvåning": return "sparkles"
        case "äckel":     return "xmark.circle"
        case "förtroende": return "heart.fill"
        case "förväntan": return "star.fill"
        default:          return "circle"
        }
    }
}

// MARK: - LillaJagMLEngine (singleton)

@MainActor
final class LillaJagMLEngine: ObservableObject {
    static let shared = LillaJagMLEngine()

    @Published private(set) var isReady = false

    // CoreML-modeller
    private var bertModel: MLModel?
    private var emotionModel: MLModel?
    private var sentimentModel: MLModel?
    private var topicModel: MLModel?

    // BERT tokenizer (WordPiece, laddas från bert_vocab.txt)
    private var bertVocab: [String: Int] = [:]

    // NLEmbedding-fallback
    private let nlSwedish = NLEmbedding.wordEmbedding(for: .swedish)

    private init() {
        Task { await loadModels() }
    }

    // MARK: - Model loading

    private func loadModels() async {
        await loadBertVocab()

        // KB-BERT för embeddings
        if let url = Bundle.main.url(forResource: "KBBertSwedish", withExtension: "mlpackage") {
            let cfg = MLModelConfiguration()
            cfg.computeUnits = .cpuAndNeuralEngine
            bertModel = try? MLModel(contentsOf: url, configuration: cfg)
        }

        // EmotionMultiLabel
        if let url = Bundle.main.url(forResource: "EmotionMultiLabel", withExtension: "mlpackage") {
            let cfg = MLModelConfiguration()
            cfg.computeUnits = .cpuAndNeuralEngine
            emotionModel = try? MLModel(contentsOf: url, configuration: cfg)
        }

        // SentimentScorer
        if let url = Bundle.main.url(forResource: "SentimentScorer", withExtension: "mlpackage") {
            let cfg = MLModelConfiguration()
            cfg.computeUnits = .cpuAndNeuralEngine
            sentimentModel = try? MLModel(contentsOf: url, configuration: cfg)
        }

        // TopicClassifier
        if let url = Bundle.main.url(forResource: "TopicClassifier", withExtension: "mlpackage") {
            let cfg = MLModelConfiguration()
            cfg.computeUnits = .cpuAndNeuralEngine
            topicModel = try? MLModel(contentsOf: url, configuration: cfg)
        }

        isReady = true
    }

    private func loadBertVocab() async {
        guard let url = Bundle.main.url(forResource: "bert_vocab", withExtension: "txt"),
              let content = try? String(contentsOf: url) else { return }
        var vocab: [String: Int] = [:]
        for (i, line) in content.components(separatedBy: "\n").enumerated() {
            let token = line.trimmingCharacters(in: .whitespaces)
            if !token.isEmpty { vocab[token] = i }
        }
        bertVocab = vocab
    }

    // MARK: - Public API

    /// Analysera text → EmotionResult (asynkron, <20ms på ANE)
    func analyzeEmotion(_ text: String) async -> EmotionResult {
        let embedding = await embed(text)
        guard let model = emotionModel else {
            return fallbackEmotion(text)
        }
        do {
            let input = try mlInput(from: embedding)
            let output = try await model.prediction(from: input)
            if let scores = output.featureValue(for: "sigmoid_0")?.multiArrayValue {
                return EmotionResult(
                    glädje:     scores.count > 0 ? scores[0].floatValue : 0,
                    sorg:       scores.count > 1 ? scores[1].floatValue : 0,
                    ilska:      scores.count > 2 ? scores[2].floatValue : 0,
                    rädsla:     scores.count > 3 ? scores[3].floatValue : 0,
                    förvåning:  scores.count > 4 ? scores[4].floatValue : 0,
                    äckel:      scores.count > 5 ? scores[5].floatValue : 0,
                    förtroende: scores.count > 6 ? scores[6].floatValue : 0,
                    förväntan:  scores.count > 7 ? scores[7].floatValue : 0
                )
            }
        } catch {
            // Silent fallback
        }
        return fallbackEmotion(text)
    }

    /// Analysera sentiment → [-1, +1] (negativt → positivt)
    func analyzeSentiment(_ text: String) async -> Float {
        let embedding = await embed(text)
        guard let model = sentimentModel else {
            return nlSentiment(text)
        }
        do {
            let input = try mlInput(from: embedding)
            let output = try await model.prediction(from: input)
            if let score = output.featureValue(for: "tanh_0")?.multiArrayValue {
                return score[0].floatValue
            }
        } catch {}
        return nlSentiment(text)
    }

    /// Detektera psykologi-relevans [0,1]
    func psychologyRelevance(_ text: String) async -> Float {
        let embedding = await embed(text)
        guard let model = topicModel else { return 0.5 }
        do {
            let input = try mlInput(from: embedding)
            let output = try await model.prediction(from: input)
            if let logits = output.featureValue(for: "linear_1")?.multiArrayValue {
                // psychology är kategori index 13 (psychology, futureScience = 13, 14)
                // Kategorier: technology(0),science(1),society(2),health(3),environment(4),
                //             culture(5),economy(6),geopolitics(7),space(8),language(9),
                //             coding(10),humanity(11),psychology(12),futureScience(13)
                if logits.count > 12 {
                    let psychScore = logits[12].floatValue
                    let healthScore = logits.count > 3 ? logits[3].floatValue : 0
                    return Float(max(0, min(1, (psychScore + healthScore) / 2.0)))
                }
            }
        } catch {}
        return 0.5
    }

    // MARK: - Embedding

    private func embed(_ text: String) async -> [Float] {
        guard !bertVocab.isEmpty, let model = bertModel else {
            return nlEmbedFallback(text)
        }
        do {
            let tokens = bertTokenize(text, maxLength: 128)
            let seqLen = tokens.count
            let inputIds = try MLMultiArray(shape: [1, NSNumber(value: seqLen)], dataType: .int32)
            let attnMask = try MLMultiArray(shape: [1, NSNumber(value: seqLen)], dataType: .int32)
            for (i, id) in tokens.enumerated() {
                inputIds[i] = NSNumber(value: id)
                attnMask[i] = NSNumber(value: 1)
            }
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "input_ids": inputIds,
                "attention_mask": attnMask,
                "token_type_ids": try { let t = try MLMultiArray(shape: [1, NSNumber(value: seqLen)], dataType: .int32); return t }()
            ])
            let output = try await model.prediction(from: input)
            if let pooled = output.featureValue(for: "embedding")?.multiArrayValue {
                return (0..<min(768, pooled.count)).map { pooled[$0].floatValue }
            }
        } catch {}
        return nlEmbedFallback(text)
    }

    private func mlInput(from embedding: [Float]) throws -> MLDictionaryFeatureProvider {
        let arr = try MLMultiArray(shape: [1, 768], dataType: .float16)
        for (i, v) in embedding.prefix(768).enumerated() {
            arr[i] = NSNumber(value: v)
        }
        return try MLDictionaryFeatureProvider(dictionary: ["BERT embedding [1,768] float16": arr])
    }

    // MARK: - BERT tokenizer

    private func bertTokenize(_ text: String, maxLength: Int) -> [Int] {
        let cls = bertVocab["[CLS]"] ?? 101
        let sep = bertVocab["[SEP]"] ?? 102
        let unk = bertVocab["[UNK]"] ?? 100
        var ids = [cls]
        for word in text.lowercased().components(separatedBy: .whitespaces) {
            if ids.count >= maxLength - 1 { break }
            if let id = bertVocab[word] {
                ids.append(id)
            } else {
                ids.append(unk)
            }
        }
        ids.append(sep)
        return Array(ids.prefix(maxLength))
    }

    // MARK: - NLEmbedding fallback

    private func nlEmbedFallback(_ text: String) -> [Float] {
        if let emb = NLEmbedding.sentenceEmbedding(for: .swedish),
           let vec = emb.vector(for: text) {
            let f = vec.prefix(768).map { Float($0) }
            return f + [Float](repeating: 0, count: max(0, 768 - f.count))
        }
        if let emb = nlSwedish {
            var result = [Float](repeating: 0, count: 768)
            var count = 0
            for word in text.split(separator: " ").prefix(20) {
                if let vec = emb.vector(for: String(word)) {
                    for (i, v) in vec.prefix(768).enumerated() { result[i] += Float(v) }
                    count += 1
                }
            }
            if count > 0 { return result.map { $0 / Float(count) } }
        }
        return [Float](repeating: 0, count: 768)
    }

    // MARK: - NL sentiment fallback

    private func nlSentiment(_ text: String) -> Float {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        var score: Float = 0
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .paragraph, scheme: .sentimentScore) { tag, _ in
            if let raw = tag.flatMap({ Double($0.rawValue) }) { score = Float(raw) }
            return false
        }
        return score
    }

    // MARK: - Keyword fallback for emotions

    private func fallbackEmotion(_ text: String) -> EmotionResult {
        let lower = text.lowercased()
        func has(_ kw: [String]) -> Float { kw.contains { lower.contains($0) } ? 0.7 : 0.1 }
        return EmotionResult(
            glädje:     has(["glad", "lycklig", "kul", "roligt", "underbart", "bra", "fantastisk"]),
            sorg:       has(["ledsen", "sorg", "gråter", "depression", "saknar", "trist", "tom"]),
            ilska:      has(["arg", "ilsken", "frustrerad", "irriterad", "rasande", "förbannad"]),
            rädsla:     has(["rädd", "rädsla", "ångest", "orolig", "skrämd", "panik", "nervös"]),
            förvåning:  has(["förvånad", "chockad", "oväntat", "plötsligt", "konstigt"]),
            äckel:      has(["äckel", "äcklig", "vidrigt", "hemskt", "otäckt"]),
            förtroende: has(["trygg", "förtroende", "säker", "lita", "stöd", "hjälp"]),
            förväntan:  has(["hoppas", "ser fram", "spänning", "nyfiken", "väntar"])
        )
    }
}
