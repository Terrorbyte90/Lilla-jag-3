// Lilla_jag_3Tests.swift
// Unit tests for MoodStore, DagbokStore, ForumStore, AchievementsStore, DashboardViewModel

import XCTest
@testable import Lilla_jag_3

// MARK: - Helper: Minimal MoodEntry factory

private func makeMoodEntry(date: Date = .now, mood: Double = 0.7) -> MoodEntry {
    MoodEntry(
        id: UUID(),
        date: date,
        moodQuality: mood,
        anxietyLevel: 0.3,
        sleepQuality: 0.8,
        outdoorQuality: 0.5,
        socialQuality: 0.6,
        routineQuality: 0.7,
        energyLevel: 0.6,
        emotions: ["Lugn"],
        tags: [],
        notes: "Testanteckning",
        sleepHours: 7,
        activities: ["Promenad"],
        socialPeople: [],
        outdoorMinutes: 40,
        trainingType: nil,
        mealsCount: 3,
        habitsDone: [],
        positives: [],
        negatives: [],
        wished: [],
        summary: "",
        insights: [],
        advice: []
    )
}

// MARK: - MoodStore Tests

@MainActor
final class MoodStoreTests: XCTestCase {

    private var testStore: MoodStore!

    override func setUp() {
        super.setUp()
        // Clear the backing file so each test starts clean.
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let prodURL = docDir.appendingPathComponent("mood_entries.json")
        try? FileManager.default.removeItem(at: prodURL)
        testStore = MoodStore()
    }

    override func tearDown() {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        try? FileManager.default.removeItem(at: docDir.appendingPathComponent("mood_entries.json"))
        testStore = nil
        super.tearDown()
    }

    // MARK: Initial state

    func testInitialEntriesIsEmpty() {
        XCTAssertTrue(testStore.entries.isEmpty, "Ny MoodStore bör börja utan poster")
    }

    // MARK: add()

    func testAddEntryIncreasesCount() {
        testStore.add(makeMoodEntry())
        XCTAssertEqual(testStore.entries.count, 1)
    }

    func testAddMultipleEntriesAreAllPresent() {
        for i in 0..<5 {
            testStore.add(makeMoodEntry(mood: Double(i) * 0.2))
        }
        XCTAssertEqual(testStore.entries.count, 5)
    }

    func testAddPreservesEntryData() throws {
        let mood = 0.85
        testStore.add(makeMoodEntry(mood: mood))
        let saved = try XCTUnwrap(testStore.entries.first, "Posten ska finnas")
        XCTAssertEqual(saved.moodQuality, mood, accuracy: 0.001)
    }

    // MARK: last7()

    func testLast7ReturnsOnlyEntriesWithinSevenDays() throws {
        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: .now)!
        testStore.add(makeMoodEntry(date: oldDate, mood: 0.1))
        testStore.add(makeMoodEntry(date: .now, mood: 0.9))

        let last7 = testStore.last7()
        XCTAssertEqual(last7.count, 1)
        XCTAssertEqual(last7.first?.moodQuality ?? 0, 0.9, accuracy: 0.001)
    }

    func testLast7IsChronologicallySorted() throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        testStore.add(makeMoodEntry(date: .now, mood: 0.8))
        testStore.add(makeMoodEntry(date: yesterday, mood: 0.3))

        let last7 = testStore.last7()
        XCTAssertEqual(last7.count, 2)
        XCTAssertLessThan(last7[0].date, last7[1].date, "last7 ska returnera poster i kronologisk ordning")
    }

    func testLast7ReturnsEmptyWhenNoEntries() {
        XCTAssertTrue(testStore.last7().isEmpty)
    }

    func testLast7ExcludesEntryExactlyEightDaysAgo() {
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: .now)!
        testStore.add(makeMoodEntry(date: eightDaysAgo))
        XCTAssertTrue(testStore.last7().isEmpty, "Post 8 dagar gammal ska inte ingå i last7")
    }

    // MARK: replace()

    func testReplaceUpdatesExistingEntry() throws {
        var entry = makeMoodEntry(mood: 0.4)
        testStore.add(entry)
        entry.moodQuality = 0.9
        testStore.replace(entry)
        let updated = try XCTUnwrap(testStore.entries.first)
        XCTAssertEqual(updated.moodQuality, 0.9, accuracy: 0.001)
    }

    func testReplaceDoesNothingForUnknownId() {
        testStore.add(makeMoodEntry(mood: 0.5))
        let unrelated = makeMoodEntry(mood: 0.99)
        testStore.replace(unrelated)
        XCTAssertEqual(testStore.entries.count, 1, "replace() ska inte lägga till ny post")
    }

    // MARK: Averages

    func testAvgMoodIsDefaultWhenEmpty() {
        XCTAssertEqual(testStore.avgMood, 0.5, accuracy: 0.001, "avgMood default ska vara 0.5")
    }

    func testAvgMoodReflectsEntries() {
        testStore.add(makeMoodEntry(date: .now, mood: 0.6))
        testStore.add(makeMoodEntry(date: .now, mood: 0.8))
        XCTAssertEqual(testStore.avgMood, 0.7, accuracy: 0.01)
    }

    // MARK: currentStreak

    func testCurrentStreakIsZeroWhenEmpty() {
        XCTAssertEqual(testStore.currentStreak, 0)
    }

    func testCurrentStreakIsOneAfterSingleTodayEntry() {
        testStore.add(makeMoodEntry(date: .now))
        XCTAssertEqual(testStore.currentStreak, 1)
    }

    func testCurrentStreakCountsConsecutiveDays() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        testStore.add(makeMoodEntry(date: today))
        testStore.add(makeMoodEntry(date: yesterday))
        testStore.add(makeMoodEntry(date: twoDaysAgo))
        XCTAssertEqual(testStore.currentStreak, 3)
    }

    func testCurrentStreakBreaksOnGap() {
        let today = Date()
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: today)!
        testStore.add(makeMoodEntry(date: today))
        testStore.add(makeMoodEntry(date: threeDaysAgo))
        XCTAssertEqual(testStore.currentStreak, 1)
    }

    // MARK: Persistence

    func testEntriesPersistedToAndLoadedFromDisk() throws {
        testStore.add(makeMoodEntry(mood: 0.77))
        let freshStore = MoodStore()
        XCTAssertFalse(freshStore.entries.isEmpty, "Poster ska läsas från disk vid ny instans")
        let loaded = try XCTUnwrap(freshStore.entries.first)
        XCTAssertEqual(loaded.moodQuality, 0.77, accuracy: 0.01)
    }
}

// MARK: - DagbokStore Tests

@MainActor
final class DagbokStoreTests: XCTestCase {

    private var store: DagbokStore!

    override func setUp() {
        super.setUp()
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        try? FileManager.default.removeItem(at: docDir.appendingPathComponent("dagbok_entries.json"))
        UserDefaults.standard.removeObject(forKey: "lj_dagbok_examples_shown")
        store = DagbokStore()
    }

    override func tearDown() {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        try? FileManager.default.removeItem(at: docDir.appendingPathComponent("dagbok_entries.json"))
        UserDefaults.standard.removeObject(forKey: "lj_dagbok_examples_shown")
        store = nil
        super.tearDown()
    }

    // MARK: Example data logic

    func testExampleDataLoadedOnFirstLaunch() {
        XCTAssertFalse(store.entries.isEmpty, "Exempeldata ska laddas vid första start")
    }

    func testExampleDataMarkedAsExamples() {
        XCTAssertTrue(store.entries.allSatisfy { $0.isExample }, "Alla initiala poster ska vara exempeldata")
    }

    func testExampleDataNotReloadedOnSecondLaunch() {
        // setUp skapar en DagbokStore() som:
        //   1. Hittar ingen fil → laddar mock i minnet (men sparar INTE till disk)
        //   2. Sätter flaggan "lj_dagbok_examples_shown" = true
        //
        // En andra DagbokStore-instans:
        //   1. Försöker ladda från disk → hittar inget (mock skrevs aldrig)
        //   2. Kollar flaggan → true → hoppar över mock-laddning
        // Resultat: entries ska vara tomma (ingen dubbel-laddning)
        let secondStore = DagbokStore()
        XCTAssertTrue(secondStore.entries.isEmpty,
                      "En andra DagbokStore-instans ska inte ladda exempeldata igen när flaggan är satt")
    }

    // MARK: add()

    func testAddInsertsAtFront() {
        store.add(DagbokEntry(title: "Testinlägg"))
        XCTAssertEqual(store.entries.first?.title, "Testinlägg")
    }

    func testAddSetsDateToNow() throws {
        let before = Date()
        store.add(DagbokEntry(title: "Datum-test"))
        let after = Date()
        let added = try XCTUnwrap(store.entries.first(where: { $0.title == "Datum-test" }))
        XCTAssertGreaterThanOrEqual(added.date, before)
        XCTAssertLessThanOrEqual(added.date, after)
    }

    func testAddIncreasesCount() {
        let initial = store.entries.count
        store.add(DagbokEntry(title: "Ny post"))
        XCTAssertEqual(store.entries.count, initial + 1)
    }

    // MARK: update()

    func testUpdateModifiesExistingEntry() throws {
        store.add(DagbokEntry(title: "Original"))
        var entry = try XCTUnwrap(store.entries.first(where: { $0.title == "Original" }))
        entry.title = "Uppdaterad"
        store.update(entry)
        XCTAssertNotNil(store.entries.first(where: { $0.title == "Uppdaterad" }))
    }

    // MARK: delete()

    func testDeleteRemovesEntry() throws {
        store.add(DagbokEntry(title: "Ta bort mig"))
        let entry = try XCTUnwrap(store.entries.first(where: { $0.title == "Ta bort mig" }))
        store.delete(entry)
        XCTAssertFalse(store.entries.contains { $0.id == entry.id })
    }

    // MARK: deleteExamples()

    func testDeleteExamplesRemovesOnlyExampleEntries() {
        store.add(DagbokEntry(title: "Riktig post", isExample: false))
        let realCountBefore = store.entries.filter { !$0.isExample }.count
        store.deleteExamples()
        XCTAssertEqual(store.entries.filter { $0.isExample }.count, 0)
        XCTAssertEqual(store.entries.filter { !$0.isExample }.count, realCountBefore)
    }

    // MARK: Persistence

    func testEntriesPersistedToDisk() {
        store.add(DagbokEntry(title: "Persistens-test", belief: "Tro"))
        let freshStore = DagbokStore()
        XCTAssertTrue(freshStore.entries.contains { $0.title == "Persistens-test" })
    }
}

// MARK: - ForumStore Tests

@MainActor
final class ForumStoreTests: XCTestCase {

    private var store: ForumStore!

    override func setUp() {
        super.setUp()
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        try? FileManager.default.removeItem(at: docDir.appendingPathComponent("forum_posts.json"))
        store = ForumStore()
    }

    override func tearDown() {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        try? FileManager.default.removeItem(at: docDir.appendingPathComponent("forum_posts.json"))
        store = nil
        super.tearDown()
    }

    // MARK: Sample posts

    func testSamplePostsLoadedWhenEmpty() {
        XCTAssertFalse(store.posts.isEmpty, "Exempelposter ska finnas från start")
    }

    // MARK: add()

    func testAddInsertsAtFront() {
        let post = ForumPost(
            author: "Testare",
            title: "Nytt inlägg",
            content: "Innehåll",
            timeAgo: "3 timmar",
            tag: "Tips",
            tagColorHex: 0x7EC8A4,
            likes: 0,
            comments: 0
        )
        store.add(post)
        XCTAssertEqual(store.posts.first?.title, "Nytt inlägg")
    }

    func testAddSetsTimeAgoToJustNow() {
        let post = ForumPost(
            author: "X",
            title: "Rubrik",
            content: "Innehåll",
            timeAgo: "5 dagar",
            tag: "Tips",
            tagColorHex: 0x7EC8A4,
            likes: 0,
            comments: 0
        )
        store.add(post)
        XCTAssertEqual(store.posts.first?.timeAgo, "Just nu")
    }

    func testAddIncreasesCount() {
        let initial = store.posts.count
        let post = ForumPost(
            author: "X",
            title: "Titel",
            content: "Innehåll",
            timeAgo: "",
            tag: "Ångest",
            tagColorHex: 0xBB86FC,
            likes: 0,
            comments: 0
        )
        store.add(post)
        XCTAssertEqual(store.posts.count, initial + 1)
    }

    // MARK: toggleLike()

    func testToggleLikeIncreasesLikes() throws {
        let first = try XCTUnwrap(store.posts.first, "Inga poster")
        let initialLikes = first.likes
        store.toggleLike(id: first.id)
        let updated = try XCTUnwrap(store.posts.first(where: { $0.id == first.id }))
        XCTAssertEqual(updated.likes, initialLikes + 1)
    }

    func testToggleLikeDecreasesLikesOnSecondTap() throws {
        let first = try XCTUnwrap(store.posts.first, "Inga poster")
        let initialLikes = first.likes
        store.toggleLike(id: first.id)
        store.toggleLike(id: first.id)
        let updated = try XCTUnwrap(store.posts.first(where: { $0.id == first.id }))
        XCTAssertEqual(updated.likes, initialLikes)
    }

    func testToggleLikeSetsIsLikedTrue() throws {
        let first = try XCTUnwrap(store.posts.first)
        store.toggleLike(id: first.id)
        let updated = try XCTUnwrap(store.posts.first(where: { $0.id == first.id }))
        XCTAssertTrue(updated.isLiked)
    }

    func testToggleLikeSetsIsLikedFalseOnSecondTap() throws {
        let first = try XCTUnwrap(store.posts.first)
        store.toggleLike(id: first.id)
        store.toggleLike(id: first.id)
        let updated = try XCTUnwrap(store.posts.first(where: { $0.id == first.id }))
        XCTAssertFalse(updated.isLiked)
    }

    func testToggleLikeWithUnknownIdDoesNothing() {
        let countBefore = store.posts.count
        store.toggleLike(id: UUID())
        XCTAssertEqual(store.posts.count, countBefore)
    }

    // MARK: Persistence

    func testPostsPersistedToDisk() {
        let post = ForumPost(
            author: "Persist",
            title: "Lagrat inlägg",
            content: "Lagrat innehåll",
            timeAgo: "Just nu",
            tag: "Tips",
            tagColorHex: 0x7EC8A4,
            likes: 0,
            comments: 0
        )
        store.add(post)
        let freshStore = ForumStore()
        XCTAssertTrue(freshStore.posts.contains { $0.title == "Lagrat inlägg" })
    }
}

// MARK: - AchievementsStore Tests
// AchievementsStore.init är private, vi testar via .shared och återställer
// achievements-arrayen manuellt till defaultAchievements inför varje test.

@MainActor
final class AchievementsStoreTests: XCTestCase {

    private let udKey = "lj_achievements"

    /// Återställer shared-instansen till ett rent utgångstillstånd.
    private func resetStore() {
        UserDefaults.standard.removeObject(forKey: udKey)
        AchievementsStore.shared.achievements = AchievementsStore.defaultAchievements
        AchievementsStore.shared.newlyUnlocked = nil
    }

    override func setUp() {
        super.setUp()
        resetStore()
    }

    override func tearDown() {
        resetStore()
        super.tearDown()
    }

    // MARK: Initial state

    func testAllAchievementsStartLocked() {
        XCTAssertTrue(AchievementsStore.shared.achievements.allSatisfy { !$0.isUnlocked })
    }

    func testDefaultAchievementCountIsCorrect() {
        XCTAssertEqual(AchievementsStore.shared.achievements.count,
                       AchievementsStore.defaultAchievements.count)
    }

    func testUnlockedCountIsZeroInitially() {
        XCTAssertEqual(AchievementsStore.shared.unlockedCount, 0)
    }

    // MARK: checkAndUnlock() - threshold tests

    func testFirstStepUnlockedAfterOneMoodLog() {
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 0, moodLogCount: 1, journalCount: 0, breathingCount: 0, chatCount: 0)
        XCTAssertTrue(achievement("first_step").isUnlocked)
    }

    func testFirstStepNotUnlockedWithZeroLogs() {
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 0, moodLogCount: 0, journalCount: 0, breathingCount: 0, chatCount: 0)
        XCTAssertFalse(achievement("first_step").isUnlocked)
    }

    func testStreak3Unlocked() {
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 3, moodLogCount: 3, journalCount: 0, breathingCount: 0, chatCount: 0)
        XCTAssertTrue(achievement("streak_3").isUnlocked)
    }

    func testStreak3NotUnlockedAt2Days() {
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 2, moodLogCount: 2, journalCount: 0, breathingCount: 0, chatCount: 0)
        XCTAssertFalse(achievement("streak_3").isUnlocked)
    }

    func testStreak7Unlocked() {
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 7, moodLogCount: 7, journalCount: 0, breathingCount: 0, chatCount: 0)
        XCTAssertTrue(achievement("streak_7").isUnlocked)
    }

    func testStreak30Unlocked() {
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 30, moodLogCount: 30, journalCount: 0, breathingCount: 0, chatCount: 0)
        XCTAssertTrue(achievement("streak_30").isUnlocked)
    }

    func testJournal5Unlocked() {
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 0, moodLogCount: 0, journalCount: 5, breathingCount: 0, chatCount: 0)
        XCTAssertTrue(achievement("journal_5").isUnlocked)
    }

    func testJournal5NotUnlockedAt4Entries() {
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 0, moodLogCount: 0, journalCount: 4, breathingCount: 0, chatCount: 0)
        XCTAssertFalse(achievement("journal_5").isUnlocked)
    }

    func testBreathing10Unlocked() {
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 0, moodLogCount: 0, journalCount: 0, breathingCount: 10, chatCount: 0)
        XCTAssertTrue(achievement("breathing_10").isUnlocked)
    }

    func testMood10Unlocked() {
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 0, moodLogCount: 10, journalCount: 0, breathingCount: 0, chatCount: 0)
        XCTAssertTrue(achievement("mood_10").isUnlocked)
    }

    func testChat5Unlocked() {
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 0, moodLogCount: 0, journalCount: 0, breathingCount: 0, chatCount: 5)
        XCTAssertTrue(achievement("chat_5").isUnlocked)
    }

    func testMood30Unlocked() {
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 0, moodLogCount: 30, journalCount: 0, breathingCount: 0, chatCount: 0)
        XCTAssertTrue(achievement("mood_30").isUnlocked)
    }

    func testPioneerUnlockedAfterFiveOtherAchievements() {
        // Lås upp first_step, streak_3, streak_7, journal_5, breathing_10 → 5 st → pioneer
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 7, moodLogCount: 10, journalCount: 5, breathingCount: 10, chatCount: 5)
        XCTAssertTrue(achievement("pioneer").isUnlocked,
                      "Pioneer ska låsas upp när 5 andra prestationer är upplåsta")
    }

    func testNoUnlockWhenAllCountsAreZero() {
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 0, moodLogCount: 0, journalCount: 0, breathingCount: 0, chatCount: 0)
        XCTAssertEqual(AchievementsStore.shared.unlockedCount, 0)
    }

    func testAlreadyUnlockedAchievementNotDuplicated() {
        // Unlock once
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 0, moodLogCount: 1, journalCount: 0, breathingCount: 0, chatCount: 0)
        let countAfterFirst = AchievementsStore.shared.achievements.filter { $0.id == "first_step" && $0.isUnlocked }.count
        // Unlock again
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 0, moodLogCount: 5, journalCount: 0, breathingCount: 0, chatCount: 0)
        let countAfterSecond = AchievementsStore.shared.achievements.filter { $0.id == "first_step" && $0.isUnlocked }.count
        XCTAssertEqual(countAfterFirst, 1)
        XCTAssertEqual(countAfterSecond, 1, "Achievement ska inte låsas upp dubbelt")
    }

    func testNewlyUnlockedSetAfterUnlock() {
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 0, moodLogCount: 1, journalCount: 0, breathingCount: 0, chatCount: 0)
        XCTAssertNotNil(AchievementsStore.shared.newlyUnlocked)
    }

    func testUnlockSetsUnlockedDate() {
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 0, moodLogCount: 1, journalCount: 0, breathingCount: 0, chatCount: 0)
        XCTAssertNotNil(achievement("first_step").unlockedDate)
    }

    // MARK: markUnlocked()

    func testMarkUnlockedReturnsTrueForNewUnlock() {
        let result = AchievementsStore.shared.markUnlocked("first_step")
        XCTAssertTrue(result)
    }

    func testMarkUnlockedReturnsFalseForAlreadyUnlocked() {
        AchievementsStore.shared.markUnlocked("first_step")
        let result = AchievementsStore.shared.markUnlocked("first_step")
        XCTAssertFalse(result)
    }

    func testMarkUnlockedReturnsFalseForUnknownId() {
        XCTAssertFalse(AchievementsStore.shared.markUnlocked("nonexistent_id_xyz"))
    }

    func testMarkUnlockedActuallyUnlocksAchievement() {
        AchievementsStore.shared.markUnlocked("mood_10")
        XCTAssertTrue(achievement("mood_10").isUnlocked)
    }

    // MARK: Persistence

    func testUnlockedStatePersistedToUserDefaults() {
        AchievementsStore.shared.checkAndUnlock(
            streakDays: 0, moodLogCount: 1, journalCount: 0, breathingCount: 0, chatCount: 0)
        UserDefaults.standard.synchronize()
        // Verifiera att UserDefaults faktiskt innehåller data
        XCTAssertNotNil(UserDefaults.standard.data(forKey: udKey),
                        "Achievements ska sparas till UserDefaults")
    }

    // MARK: - Hjälpmetod

    private func achievement(_ id: String) -> Achievement {
        AchievementsStore.shared.achievements.first(where: { $0.id == id })
            ?? Achievement(id: id, title: "", description: "", icon: "", colorHex: 0, isUnlocked: false)
    }
}

// MARK: - DashboardViewModel Tests

@MainActor
final class DashboardViewModelTests: XCTestCase {

    private var vm: DashboardViewModel!
    private let streakKey = "lj_streak_dates"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: streakKey)
        vm = DashboardViewModel()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: streakKey)
        vm = nil
        super.tearDown()
    }

    // MARK: Initial state

    func testInitialStreakIsZero() {
        XCTAssertEqual(vm.currentStreak, 0)
    }

    func testInitialHasCheckedInTodayIsFalse() {
        XCTAssertFalse(vm.hasCheckedInToday)
    }

    func testAffirmationIsNotEmpty() {
        XCTAssertFalse(vm.affirmation.isEmpty, "Affirmation ska inte vara tom")
    }

    // MARK: recordCheckIn()

    func testRecordCheckInSetsHasCheckedInToday() {
        vm.recordCheckIn()
        XCTAssertTrue(vm.hasCheckedInToday)
    }

    func testRecordCheckInIncreasesStreakByOne() {
        vm.recordCheckIn()
        XCTAssertEqual(vm.currentStreak, 1)
    }

    func testRecordCheckInTwiceOnSameDayDoesNotDoubleStreak() {
        vm.recordCheckIn()
        vm.recordCheckIn()
        XCTAssertEqual(vm.currentStreak, 1, "Dubbel incheckning samma dag ska ge streak = 1")
    }

    // MARK: checkAchievements()

    func testCheckAchievementsDoesNotCrash() {
        XCTAssertNoThrow(vm.checkAchievements())
    }

    func testCheckAchievementsCanBeCalledMultipleTimes() {
        for _ in 0..<5 {
            vm.checkAchievements()
        }
        // Om vi kommer hit utan krasch är testet grönt
        XCTAssertTrue(true)
    }

    // MARK: Streak persistence

    func testStreakRestoredAfterReinit() {
        vm.recordCheckIn()
        let vm2 = DashboardViewModel()
        XCTAssertEqual(vm2.currentStreak, 1, "Streak ska återställas från UserDefaults")
        XCTAssertTrue(vm2.hasCheckedInToday)
    }
}

// MARK: - Calendar Extension Tests

final class CalendarExtensionTests: XCTestCase {

    func testIsDateInSameDayAsOrAfterWithSameDay() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        XCTAssertTrue(cal.isDate(today, inSameDayAsOrAfter: today))
    }

    func testIsDateInSameDayAsOrAfterWithFutureDate() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        XCTAssertTrue(cal.isDate(today, inSameDayAsOrAfter: yesterday))
    }

    func testIsDateInSameDayAsOrAfterWithPastDate() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        XCTAssertFalse(cal.isDate(today, inSameDayAsOrAfter: tomorrow))
    }

    func testIsDateInSameDayAsOrAfterWithOneDayDifference() {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!
        let today = cal.startOfDay(for: Date())
        XCTAssertFalse(cal.isDate(yesterday, inSameDayAsOrAfter: today),
                       "Igår är inte inSameDayAsOrAfter idag")
    }
}

// MARK: - Collection Average Extension Tests

final class CollectionAverageTests: XCTestCase {

    func testAverageOfEmptyArrayUsesDefault() {
        let empty: [Double] = []
        XCTAssertEqual(empty.average(default: 99.0), 99.0, accuracy: 0.001)
    }

    func testAverageOfSingleElement() {
        let arr: [Double] = [0.6]
        XCTAssertEqual(arr.average(default: 0), 0.6, accuracy: 0.001)
    }

    func testAverageOfMultipleElements() {
        let arr: [Double] = [0.2, 0.4, 0.6, 0.8]
        XCTAssertEqual(arr.average(default: 0), 0.5, accuracy: 0.001)
    }

    func testAverageOfAllZeros() {
        let arr: [Double] = [0.0, 0.0, 0.0]
        XCTAssertEqual(arr.average(default: 0.5), 0.0, accuracy: 0.001)
    }

    func testAverageOfAllOnes() {
        let arr: [Double] = [1.0, 1.0, 1.0]
        XCTAssertEqual(arr.average(default: 0), 1.0, accuracy: 0.001)
    }
}

// MARK: - DailyLog MonsterState Tests

final class DailyLogMonsterStateTests: XCTestCase {

    private func makeLog(sleep: Int = 4, meals: Int = 4, outdoor: Int = 4,
                         exercise: Int = 4, social: Int = 4) -> DailyLog {
        DailyLog(date: .now, sleep: sleep, meals: meals,
                 outdoor: outdoor, exercise: exercise, social: social)
    }

    func testSuperHappyWhenAllGood() {
        XCTAssertEqual(makeLog().monsterState, .superHappy)
    }

    func testSleepyWhenSleepLow() {
        XCTAssertEqual(makeLog(sleep: 2).monsterState, .sleepy)
    }

    func testHungryWhenMealsLow() {
        XCTAssertEqual(makeLog(meals: 2).monsterState, .hungry)
    }

    func testPaleWhenOutdoorLow() {
        XCTAssertEqual(makeLog(outdoor: 2).monsterState, .pale)
    }

    func testStiffWhenExerciseLow() {
        XCTAssertEqual(makeLog(exercise: 2).monsterState, .stiff)
    }

    func testMuteWhenSocialLow() {
        XCTAssertEqual(makeLog(social: 2).monsterState, .mute)
    }

    func testSleepTakesPriorityOverMeals() {
        XCTAssertEqual(makeLog(sleep: 2, meals: 2).monsterState, .sleepy)
    }

    func testAllAtBorderValue3IsSuperHappy() {
        XCTAssertEqual(makeLog(sleep: 3, meals: 3, outdoor: 3, exercise: 3, social: 3).monsterState, .superHappy)
    }
}
