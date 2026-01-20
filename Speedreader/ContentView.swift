import SwiftUI
import Combine
import AppKit

enum SkipMode {
    case tenWords
    case sentence
}

struct ContentView: View {
    // MARK: - State Properties
    @State private var inputText = ""
    @State private var displayedWord = ""
    @State private var isRunning = false
    @State private var isPaused = false
    @State private var currentWordIndex = 0
    @State private var words: [String] = []
    @State private var paragraphStarts: [Int] = []
    @State private var pageStarts: [Int] = []
    @State private var lastAdvance = Date.now
    @State private var wpmIndex = 3
    @State private var sliderProgress = 0.0
    @State private var isInteractingWithSlider = false
    @State private var hasStartedSliding = false
    @State private var detectedTitle = ""
    @State private var detectedChapter = ""
    @State private var textEditorHeight: CGFloat = 44
    @FocusState private var isEditingInput: Bool
    @State private var leftSkipAmount = 10
    @State private var rightSkipAmount = 10
    @State private var skipModeBack = SkipMode.tenWords
    @State private var skipModeForward = SkipMode.tenWords
    @State private var currentPlaceholder = ""
    
    // MARK: - Constants
    private let wpmOptions = [150, 300, 450, 600, 750, 900, 1200, 1500]
    private let skipOptions = [5, 10, 15, 20]
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let lineWidth: CGFloat = 2
    private let backgroundColor = Color.black
    private let outlineColor = Color.gray.opacity(0.5)
    private let normalSpeedPhrases = [
        "Buckle up",
        "Don't Blink"
    ]
    private let highSpeedPhrases = [
        "12 Parsec",
        "Afterburners",
    ]
    
    // MARK: - UI State
    private var maxIndex: Int {
        max(0, words.count - 1)
    }
    
    var body: some View {
        VStack(spacing: 28) {
            topGuideLine
            wordDisplayArea
            bottomGuideLine
            
            // Show detected title during playback
            if isRunning && !detectedTitle.isEmpty {
                HStack(spacing: 4) {
                    Text("you're currently reading")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.7))
                    Text(detectedTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.85))
                    if !detectedChapter.isEmpty {
                        Text(":")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.7))
                        Text(detectedChapter)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.85))
                    }
                }
                .italic()
            }
            
            inputOrProgressArea
            wpmSliderSection
            controlsSection
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
        .edgesIgnoringSafeArea(.all)
        .onReceive(timer) { _ in
            guard isRunning, !isPaused else { return }
            advanceWord()
        }
        .onAppear {
            pickRandomPlaceholder()
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                handleKeyPress(event)
                return event
            }
        }
        .onChange(of: currentWordIndex) {
            updateSliderProgress()
        }
    }
    
    // MARK: - View Components
    
    private var placeholderVerticalPadding: CGFloat {
        // Match the TextEditor padding so placeholder aligns perfectly
        textEditorHeight > 44 ? 12 : 12
    }

    private var textEditorVerticalPadding: CGFloat {
        // Slightly smaller when collapsed to single-line
        textEditorHeight > 44 ? 8 : 12
    }
    
    private var topGuideLine: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: lineWidth, height: 20)
            Spacer()
        }
    }
    
    private var wordDisplayArea: some View {
        ZStack {
            Rectangle()
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(outlineColor, lineWidth: lineWidth)
                )

            if !isRunning && displayedWord.isEmpty {
                Text(currentPlaceholder)
                    .foregroundColor(.gray.opacity(0.4))
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
            } else {
                centeredWordView(displayedWord)
            }
        }
        .frame(height: 160)
        .cornerRadius(18)
    }
    
    private var bottomGuideLine: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: lineWidth, height: 20)
            Spacer()
        }
    }
    
    private var inputOrProgressArea: some View {
        ZStack {
            if !isRunning {
                textInputSection
            } else {
                progressSliderSection
            }
        }
        .frame(minHeight: 44)
    }
    
    private var textInputSection: some View {
        HStack(spacing: 8) {
            textInputField
            
            Button("Clear") {
                inputText = ""
                isEditingInput = false
                textEditorHeight = 44
            }
            .buttonStyle(.bordered)

            Button("Paste") {
                if let str = NSPasteboard.general.string(forType: .string) {
                    inputText = str
                    isEditingInput = true
                    updateTextEditorHeight()
                }
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var textInputField: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .stroke(outlineColor, lineWidth: lineWidth)
                .background(backgroundColor)

            ZStack(alignment: .topLeading) {
                // Placeholder
                if inputText.isEmpty {
                    Text("enter or paste text...")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                        .padding(.horizontal, 17)
                        .padding(.vertical, self.placeholderVerticalPadding)
                        .allowsHitTesting(false)
                }
                
                // Text editor with conditional masking
                TextEditor(text: $inputText)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, self.textEditorVerticalPadding)
                    .background(Color.clear)
                    .focused($isEditingInput)
                    .mask(
                        Group {
                            if !isEditingInput && textEditorHeight <= 44 {
                                // Apply fade mask when not editing and single line
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .white, location: 0.0),
                                        .init(color: .white, location: 0.85),
                                        .init(color: .clear, location: 1.0)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            } else {
                                // No mask when editing or multiline
                                Rectangle().fill(Color.white)
                            }
                        }
                    )
                    .onChange(of: inputText) {
                        updateTextEditorHeight()
                    }
                    .onChange(of: isEditingInput) {
                        updateTextEditorHeight()
                    }
            }
        }
        .frame(height: textEditorHeight)
        .animation(.easeInOut(duration: 0.2), value: textEditorHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            isEditingInput = true
        }
    }
    
    private var progressSliderSection: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { sliderProgress },
                    set: { newValue in
                        sliderProgress = newValue
                        updateWordIndexFromSlider(newValue)
                    }
                ),
                in: 0...1
            )
            .onHover { hovering in
                isInteractingWithSlider = hovering
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        isInteractingWithSlider = true
                        hasStartedSliding = true
                        if !isPaused {
                            isPaused = true
                        }
                    }
                    .onEnded { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isInteractingWithSlider = false
                        }
                    }
            )
            
            paragraphMarkers
        }
    }
    
    private var paragraphMarkers: some View {
        GeometryReader { geometry in
            let horizontalInset: CGFloat = 14   // matches native Slider padding
            let usableWidth = geometry.size.width - horizontalInset * 2

            ZStack {
                // Page markers (double height)
                ForEach(Array(pageStarts), id: \.self) { wordIndex in
                    let position = CGFloat(wordIndex) / CGFloat(max(words.count - 1, 1))
                    RoundedRectangle(cornerRadius: lineWidth / 2)
                        .fill(Color.gray.opacity(0.8))
                        .frame(width: lineWidth, height: 24)
                        .position(
                            x: horizontalInset + position * usableWidth,
                            y: geometry.size.height / 2
                        )
                }

                // Paragraph markers
                ForEach(Array(paragraphStarts), id: \.self) { wordIndex in
                    let position = CGFloat(wordIndex) / CGFloat(max(words.count - 1, 1))
                    RoundedRectangle(cornerRadius: lineWidth / 2)
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: lineWidth, height: 12)
                        .position(
                            x: horizontalInset + position * usableWidth,
                            y: geometry.size.height / 2
                        )
                }
            }
            .opacity(hasStartedSliding ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.2), value: hasStartedSliding)
        }
        .frame(height: 24)
    }
    
    private var wpmSliderSection: some View {
        HStack(spacing: 16) {
            Slider(
                value: Binding(
                    get: { Double(wpmIndex) },
                    set: { wpmIndex = Int($0.rounded()) }
                ),
                in: 0...Double(wpmOptions.count - 1),
                step: 1
            )
            .frame(width: 260)

            Text("\(wpmOptions[wpmIndex]) wpm")
                .foregroundColor(.white)
                .font(.headline)
        }
    }
    
    private var controlsSection: some View {
        VStack(spacing: 28) {
            if !isRunning {
                startButtonWithHints
            } else {
                playbackControls
            }
        }
    }
    
    private var startButtonWithHints: some View {
        VStack(spacing: 28) {
            Button(action: start) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Start")
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            
            keyboardShortcutsDisplay
        }
    }
    
    private var keyboardShortcutsDisplay: some View {
        HStack {
            Spacer()

            HStack(spacing: 24) {
                spacebarHint
                arrowKeysHint
            }

            Spacer()
        }
        .padding(.top, 4)
    }
    
    private var spacebarHint: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(outlineColor, lineWidth: 1.5)
                .frame(width: 140, height: 30)
                .overlay(
                    Text("space")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                )
            Text("play/pause")
                .font(.system(size: 9))
                .foregroundColor(.gray)
        }
        .padding(.top, 55)
    }
    
    private var arrowKeysHint: some View {
        VStack(spacing: 8) {
            Text("previous")
                .font(.system(size: 9))
                .foregroundColor(.gray)

            HStack(alignment: .center, spacing: 0) {
                arrowKey("↑")
            }

            HStack(alignment: .center, spacing: 6) {
                Text("-10").font(.system(size: 9)).foregroundColor(.gray)
                arrowKey("←")
                arrowKey("↓")
                arrowKey("→")
                Text("+10").font(.system(size: 9)).foregroundColor(.gray)
            }

            Text("next")
                .font(.system(size: 9))
                .foregroundColor(.gray)
        }
    }
    
    private var playbackControls: some View {
        HStack(spacing: 40) {
            backNavigationControl
            playPauseButton
            stopButton
            forwardNavigationControl
        }
        .frame(height: 78)
    }
    

    private var backNavigationControl: some View {
        VStack(spacing: 4) {
            Spacer()
            
            Button(action: skipBackward) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 22, weight: .semibold))
            }
            .buttonStyle(.plain)

            Menu {
                // Numeric skips
                ForEach(skipOptions, id: \.self) { value in
                    Button {
                        leftSkipAmount = value
                        skipModeBack = .tenWords
                    } label: {
                        Text("\(value) words")
                        if skipModeBack == .tenWords && leftSkipAmount == value {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                // Skip by sentence
                Button {
                    skipModeBack = .sentence
                } label: {
                    Text("Skip sentence")
                    if skipModeBack == .sentence {
                        Image(systemName: "checkmark")
                    }
                }

            } label: {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 14, height: 14)
            }
            .menuStyle(.borderlessButton)
            
            Spacer()
        }
        .frame(height: 78) // match play/pause/stop button height
    }

    private var forwardNavigationControl: some View {
        VStack(spacing: 4) {
            Spacer()
            
            Button(action: skipForward) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 22, weight: .semibold))
            }
            .buttonStyle(.plain)

            Menu {
                // Numeric skips
                ForEach(skipOptions, id: \.self) { value in
                    Button {
                        rightSkipAmount = value
                        skipModeForward = .tenWords
                    } label: {
                        Text("\(value) words")
                        if skipModeForward == .tenWords && rightSkipAmount == value {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                // Skip by sentence
                Button {
                    skipModeForward = .sentence
                } label: {
                    Text("Skip sentence")
                    if skipModeForward == .sentence {
                        Image(systemName: "checkmark")
                    }
                }

            } label: {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 14, height: 14)
            }
            .menuStyle(.borderlessButton)
            
            Spacer()
        }
        .frame(height: 78) // match play/pause/stop button height
    }
    
    private var playPauseButton: some View {
        Button(action: togglePause) {
            HStack(spacing: 8) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                Text(isPaused ? "Resume" : "Pause")
            }
            .font(.headline)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }
    
    private var stopButton: some View {
        Button(action: stop) {
            HStack(spacing: 8) {
                Image(systemName: "stop.fill")
                Text("Stop")
            }
            .font(.headline)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }
    
    func arrowKey(_ symbol: String) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(outlineColor, lineWidth: 1.5)
            .frame(width: 30, height: 30)
            .overlay(
                Text(symbol)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            )
    }
    
    func handleKeyPress(_ event: NSEvent) {
        switch event.keyCode {
        case 123: // Left arrow - always skip back 10 words
            if isRunning {
                skipBackwardByTen()
            }
        case 124: // Right arrow - always skip forward 10 words
            if isRunning {
                skipForwardByTen()
            }
        case 126: // Up arrow - always go to previous sentence
            if isRunning {
                skipToPreviousSentence()
            }
        case 125: // Down arrow - always go to next sentence
            if isRunning {
                skipToNextSentence()
            }
        case 49: // Space - start/pause/resume
            if !isRunning {
                start()
            } else {
                togglePause()
            }
        default:
            break
        }
    }
    
    func pickRandomPlaceholder() {
        let phrases = wpmOptions[wpmIndex] >= 900 ? highSpeedPhrases : normalSpeedPhrases
        currentPlaceholder = phrases.randomElement() ?? phrases[0]
    }
    
    func updateSliderProgress() {
        if !isInteractingWithSlider && words.count > 0 {
            sliderProgress = Double(currentWordIndex) / Double(max(words.count - 1, 1))
        }
    }
    
    func updateWordIndexFromSlider(_ value: Double) {
        let maxIndex = max(words.count - 1, 1)
        let targetIndex = Int(value * Double(maxIndex))

        // Determine snap distances based on page count
        let pageCount = pageStarts.count
        let paragraphSnapDistance: Int
        let pageSnapDistance: Int
        
        if pageCount > 30 {
            // Too many pages - disable snapping
            paragraphSnapDistance = 0
            pageSnapDistance = 0
        } else if pageCount > 0 {
            // We have pages - prioritize page snapping
            paragraphSnapDistance = 4
            pageSnapDistance = 8
        } else {
            // No pages - use standard paragraph snapping
            paragraphSnapDistance = 8
            pageSnapDistance = 0
        }

        var snappedIndex: Int? = nil
        var closestDistance = Int.max
        
        // Try snapping to pages first (higher priority when pages exist)
        if pageSnapDistance > 0 {
            for pageIndex in pageStarts {
                let distance = abs(pageIndex - targetIndex)
                if distance < closestDistance && distance <= pageSnapDistance {
                    closestDistance = distance
                    snappedIndex = pageIndex
                }
            }
        }
        
        // Try snapping to paragraphs (lower priority or only option if no pages)
        if paragraphSnapDistance > 0 && (snappedIndex == nil || closestDistance > paragraphSnapDistance) {
            for paragraphIndex in paragraphStarts {
                let distance = abs(paragraphIndex - targetIndex)
                if distance < closestDistance && distance <= paragraphSnapDistance {
                    closestDistance = distance
                    snappedIndex = paragraphIndex
                }
            }
        }

        if let snap = snappedIndex {
            currentWordIndex = snap
            // Physically snap the slider thumb to the exact position
            sliderProgress = Double(snap) / Double(maxIndex)
        } else {
            currentWordIndex = targetIndex
        }

        currentWordIndex = max(0, min(currentWordIndex, maxIndex))
        displayedWord = words[currentWordIndex]
        lastAdvance = .now
    }

    func updateTextEditorHeight() {
        let lineHeight: CGFloat = 22
        let padding: CGFloat = 16
        let maxLines = 5
        
        // Count lines in the text
        let lines = inputText.split(separator: "\n", omittingEmptySubsequences: false).count
        let clampedLines = max(1, min(lines, maxLines))
        
        // Calculate height based on lines when editing, stay at 44 when not editing
        if isEditingInput && lines > 1 {
            textEditorHeight = CGFloat(clampedLines) * lineHeight + padding
        } else {
            textEditorHeight = 44
        }
    }

    // MARK: - Word Rendering

    func centeredWordView(_ word: String) -> some View {
        let chars = Array(word)
        guard !chars.isEmpty else {
            return AnyView(EmptyView())
        }
        
        let centerIndex = max(0, (chars.count - 1) / 2)
        let charWidth: CGFloat = 33.6
        
        return AnyView(
            GeometryReader { geometry in
                let windowCenter = geometry.size.width / 2
                let redLetterCenter = CGFloat(centerIndex) * charWidth + (charWidth / 2)
                let wordStartX = windowCenter - redLetterCenter
                
                HStack(spacing: 0) {
                    ForEach(chars.indices, id: \.self) { index in
                        Text(String(chars[index]))
                            .foregroundColor(index == centerIndex ? .red : .white)
                            .font(.system(size: 56, weight: .bold, design: .monospaced))
                            .frame(width: charWidth)
                    }
                }
                .position(x: wordStartX + (CGFloat(chars.count) * charWidth / 2), y: geometry.size.height / 2)
            }
        )
    }

    // MARK: - Logic

    func start() {
        let normalized = inputText.replacingOccurrences(of: "\r\n", with: "\n")
                                   .replacingOccurrences(of: "\r", with: "\n")
        
        let (cleanedText, title, chapter, pageNumbers) =
            cleanAndDetectTitleChapterPages(normalized)

        detectedTitle = formatTitle(title)
        detectedChapter = formatTitle(chapter)

        let paragraphs = detectParagraphs(cleanedText)

        let detectedPages = detectSequentialPages(
            pageNumbers,
            paragraphCount: paragraphs.count)

        var wordIndex = 0
        paragraphStarts = []
        pageStarts = []
        words = []

        for (idx, paragraph) in paragraphs.enumerated() {

            if idx > 0 {
                paragraphStarts.append(wordIndex)
            }

            if detectedPages.contains(idx) {
                pageStarts.append(wordIndex)
            }

            let paragraphWords = paragraph
                .split(whereSeparator: { $0.isWhitespace })
                .map(String.init)

            words.append(contentsOf: paragraphWords)
            wordIndex += paragraphWords.count
        }

        guard !words.isEmpty else { return }

        currentWordIndex = 0
        displayedWord = words[0]
        isRunning = true
        isPaused = false
        isEditingInput = false
        lastAdvance = .now
        sliderProgress = 0.0
        hasStartedSliding = false
        textEditorHeight = 44
    }
    
    func cleanAndDetectTitleChapterPages(_ text: String) -> (String, String, String, [Int]) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var cleanedLines: [String] = []
        var pageNumbers: [Int] = []
        
        // Track candidates with their occurrence positions
        struct HeaderCandidate {
            var text: String
            var occurrences: [Int] = []
            var count: Int { occurrences.count }
        }
        
        var headerCandidates: [String: HeaderCandidate] = [:]
        var lineIndex = 0
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            guard !trimmed.isEmpty else {
                cleanedLines.append("")
                lineIndex += 1
                continue
            }
            
            // Fix spaced-out text (like "t h e t w o t o w e r s" -> "the two towers")
            let fixedLine = fixSpacedText(trimmed)
            
            var isHeader = false
            var headerText = ""
            var extractedPageNumber: Int? = nil
            
            // Check for page number + header pattern (e.g., "538 the two towers")
            if fixedLine.range(of: "^(\\d+)\\s+(.+)$", options: .regularExpression) != nil {
                let components = fixedLine.split(separator: " ", maxSplits: 1)
                if components.count == 2, let pageNum = Int(components[0]) {
                    headerText = String(components[1])
                    extractedPageNumber = pageNum
                    isHeader = true
                }
            }
            // Check for header + page number pattern (e.g., "the departure of boromir 539")
            else if fixedLine.range(of: "^(.+)\\s+(\\d+)$", options: .regularExpression) != nil {
                let components = fixedLine.split(separator: " ")
                if let lastComponent = components.last, let pageNum = Int(lastComponent) {
                    headerText = components.dropLast().joined(separator: " ")
                    extractedPageNumber = pageNum
                    isHeader = true
                }
            }
            // Check for isolated page numbers
            else if let pageNum = Int(fixedLine) {
                extractedPageNumber = pageNum
                lineIndex += 1
                pageNumbers.append(pageNum)
                continue
            }
            else if fixedLine.range(of: "^Page \\d+$", options: [.regularExpression, .caseInsensitive]) != nil {
                lineIndex += 1
                continue
            }
            // Check for footnote markers
            else if fixedLine.range(of: "^[\\[\\(]?\\d+[\\]\\)]?$", options: .regularExpression) != nil ||
                    fixedLine.range(of: "^[*†‡§¶]+$", options: .regularExpression) != nil {
                lineIndex += 1
                continue
            }
            // Check for standalone short lines that look like titles
            else if fixedLine.count > 3 && fixedLine.count < 80 &&
                    (fixedLine == fixedLine.uppercased() || isLikelyTitle(fixedLine)) {
                headerText = fixedLine
                isHeader = true
            }
            
            if let pageNum = extractedPageNumber {
                pageNumbers.append(pageNum)
            }
            
            if isHeader && !headerText.isEmpty {
                if headerCandidates[headerText] != nil {
                    headerCandidates[headerText]?.occurrences.append(lineIndex)
                } else {
                    headerCandidates[headerText] = HeaderCandidate(text: headerText, occurrences: [lineIndex])
                }
                lineIndex += 1
                continue
            }
            
            cleanedLines.append(line)
            lineIndex += 1
        }
        
        // Detect if page numbers are sequential (page breaks)
        _ = detectSequentialPages(
            pageNumbers,
            paragraphCount: cleanedLines.count
        )
        
        // Filter candidates that appear at least twice
        let validCandidates = headerCandidates.filter { $0.value.count >= 2 }
        
        // If we have 2 candidates, analyze their alternating pattern
        var bookTitle = ""
        var chapterTitle = ""
        
        if validCandidates.count >= 2 {
            // Sort by frequency
            let sorted = validCandidates.sorted { $0.value.count > $1.value.count }
            let first = sorted[0].value
            let second = sorted[1].value
            
            // The one with more occurrences is likely the book title
            if first.count > second.count {
                bookTitle = first.text
                chapterTitle = second.text
            } else {
                bookTitle = second.text
                chapterTitle = first.text
            }
        } else if validCandidates.count == 1 {
            // Only one repeated header - assume it's the book title
            bookTitle = validCandidates.first?.value.text ?? ""
        }
        
        return (
            cleanedLines.joined(separator: "\n"),
            bookTitle,
            chapterTitle,
            pageNumbers
        )
    }
    
    func detectSequentialPages(
        _ pageNumbers: [Int],
        paragraphCount: Int
    ) -> Set<Int> {

        guard pageNumbers.count >= 3 else { return [] }

        let sorted = pageNumbers.sorted()
        var validSteps = 0

        for i in 1..<sorted.count {
            let diff = sorted[i] - sorted[i - 1]
            if diff == 1 || diff == 2 {
                validSteps += 1
            }
        }

        let ratio = Double(validSteps) / Double(sorted.count - 1)
        guard ratio > 0.7 else { return [] }

        let uniquePages = Array(Set(sorted)).sorted()
        guard uniquePages.count > 0 else { return [] }

        let paragraphsPerPage = max(1, paragraphCount / uniquePages.count)

        var pageParagraphIndices: Set<Int> = []

        for i in 0..<uniquePages.count {
            let paragraphIndex = i * paragraphsPerPage
            if paragraphIndex > 0 && paragraphIndex < paragraphCount {
                pageParagraphIndices.insert(paragraphIndex)
            }
        }

        return pageParagraphIndices
    }
    
    func formatTitle(_ title: String) -> String {
        guard !title.isEmpty else { return "" }

        let lower = title.lowercased()

        let dictionary = [
            "the", "two", "towers",
            "return", "king", "rings",
            "departure", "boromir",
            "of", "and"
        ].sorted { $0.count > $1.count }

        var result: [String] = []
        var index = lower.startIndex

        while index < lower.endIndex {
            var matched: String? = nil

            for word in dictionary {
                if lower[index...].hasPrefix(word) {
                    matched = word
                    break
                }
            }

            if let match = matched {
                let capitalized =
                    match.prefix(1).uppercased() +
                    match.dropFirst()
                result.append(capitalized)
                index = lower.index(index, offsetBy: match.count)
            } else {
                index = lower.index(after: index)
            }
        }

        return result.joined(separator: " ")
    }
    
    func fixSpacedText(_ text: String) -> String {
        // Detect patterns like "t h e  w o r d" (single letters with spaces)
        // Match 3+ consecutive single letters separated by spaces
        let pattern = "\\b([a-z])\\s+([a-z])(\\s+[a-z])+\\b"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return text
        }
        
        var result = text
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        // Process matches in reverse to maintain string indices
        for match in matches.reversed() {
            if let range = Range(match.range, in: text) {
                let spacedText = String(text[range])
                // Remove spaces between single letters
                let fixed = spacedText.replacingOccurrences(of: " ", with: "")
                result.replaceSubrange(range, with: fixed)
            }
        }
        
        return result
    }
    
    func isLikelyTitle(_ text: String) -> Bool {
        // Check if text looks like a title (first letter of most words capitalized)
        let words = text.split(separator: " ")
        let capitalizedWords = words.filter { word in
            guard let first = word.first else { return false }
            return first.isUppercase
        }
        return Double(capitalizedWords.count) / Double(words.count) > 0.5
    }
    
    func detectParagraphs(_ text: String) -> [String] {
        // First try standard double line break method
        let standardParagraphs = text
            .split(separator: "\n\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // If we found paragraphs with double breaks, use them
        if standardParagraphs.count > 1 {
            return standardParagraphs
        }
        
        // Otherwise, try smart paragraph detection
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var paragraphs: [String] = []
        var currentParagraph: [String] = []
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Empty line marks paragraph break
            if trimmed.isEmpty {
                if !currentParagraph.isEmpty {
                    paragraphs.append(currentParagraph.joined(separator: " "))
                    currentParagraph = []
                }
                continue
            }
            
            // Check for indentation (new paragraph) - common in books
            let hasIndentation = line.hasPrefix("    ") || line.hasPrefix("\t") ||
                                 (line.first == " " && line.prefix(2).filter({ $0 == " " }).count >= 2)
            
            // Check if previous line ended with sentence-ending punctuation
            let previousLineEndedWithPeriod = index > 0 &&
                (lines[index - 1].trimmingCharacters(in: .whitespaces).hasSuffix(".") ||
                 lines[index - 1].trimmingCharacters(in: .whitespaces).hasSuffix("!") ||
                 lines[index - 1].trimmingCharacters(in: .whitespaces).hasSuffix("?") ||
                 lines[index - 1].trimmingCharacters(in: .whitespaces).hasSuffix(".'") ||
                 lines[index - 1].trimmingCharacters(in: .whitespaces).hasSuffix("!'") ||
                 lines[index - 1].trimmingCharacters(in: .whitespaces).hasSuffix("?'"))
            
            // Check if current line starts with capital letter
            let startsWithCapital = trimmed.first?.isUppercase ?? false
            
            // Check if previous line was significantly shorter (might indicate paragraph end)
            let previousLineWasShort = index > 0 &&
                lines[index - 1].trimmingCharacters(in: .whitespaces).count < 60
            
            // Start new paragraph if: indented, or (previous ended with period AND starts with capital AND previous was short)
            if hasIndentation ||
               (previousLineEndedWithPeriod && startsWithCapital && previousLineWasShort && !currentParagraph.isEmpty) {
                if !currentParagraph.isEmpty {
                    paragraphs.append(currentParagraph.joined(separator: " "))
                    currentParagraph = []
                }
            }
            
            currentParagraph.append(trimmed)
        }
        
        // Add final paragraph
        if !currentParagraph.isEmpty {
            paragraphs.append(currentParagraph.joined(separator: " "))
        }
        
        return paragraphs.filter { !$0.isEmpty }
    }
    
    func stop() {
        isRunning = false
        isPaused = false
        displayedWord = ""
        currentWordIndex = 0
        sliderProgress = 0.0
        hasStartedSliding = false
        textEditorHeight = 44
        detectedTitle = ""
        detectedChapter = ""
        pageStarts = []
        pickRandomPlaceholder()
    }

    func togglePause() {
        isPaused.toggle()
        if !isPaused {
            lastAdvance = .now
        }
    }

    func skipBackward() {
        if !isPaused { isPaused = true }

        switch skipModeBack {
        case .tenWords:
            currentWordIndex = max(0, currentWordIndex - leftSkipAmount)
        case .sentence:
            skipToPreviousSentence()
            return
        }

        displayedWord = words[currentWordIndex]
        lastAdvance = .now
    }

    func skipForward() {
        if !isPaused { isPaused = true }

        switch skipModeForward {
        case .tenWords:
            currentWordIndex = min(words.count - 1, currentWordIndex + rightSkipAmount)
        case .sentence:
            skipToNextSentence()
            return
        }

        displayedWord = words[currentWordIndex]
        lastAdvance = .now
    }
    
    func skipBackwardByTen() {
        currentWordIndex = max(0, currentWordIndex - 10)
        displayedWord = words[currentWordIndex]
        lastAdvance = .now
        if !isPaused {
            isPaused = true
        }
    }
    
    func skipForwardByTen() {
        currentWordIndex = min(words.count - 1, currentWordIndex + 10)
        displayedWord = words[currentWordIndex]
        lastAdvance = .now
        if !isPaused {
            isPaused = true
        }
    }

    func skipToPreviousSentence() {
        if currentWordIndex > 0 {
            let prevWord = words[currentWordIndex - 1]
            if prevWord.hasSuffix(".") || prevWord.hasSuffix("!") || prevWord.hasSuffix("?") {
                var index = currentWordIndex - 2
                while index >= 0 {
                    let word = words[index]
                    if word.hasSuffix(".") || word.hasSuffix("!") || word.hasSuffix("?") {
                        currentWordIndex = index + 1
                        displayedWord = words[currentWordIndex]
                        lastAdvance = .now
                        if !isPaused {
                            isPaused = true
                        }
                        return
                    }
                    index -= 1
                }
            }
        }
        
        var index = currentWordIndex - 1
        while index >= 0 {
            let word = words[index]
            if word.hasSuffix(".") || word.hasSuffix("!") || word.hasSuffix("?") {
                currentWordIndex = index + 1
                displayedWord = words[currentWordIndex]
                lastAdvance = .now
                if !isPaused {
                    isPaused = true
                }
                return
            }
            index -= 1
        }
        currentWordIndex = 0
        displayedWord = words[0]
        lastAdvance = .now
        if !isPaused {
            isPaused = true
        }
    }

    func skipToNextSentence() {
        var index = currentWordIndex
        while index < words.count {
            let word = words[index]
            if word.hasSuffix(".") || word.hasSuffix("!") || word.hasSuffix("?") {
                currentWordIndex = min(words.count - 1, index + 1)
                displayedWord = words[currentWordIndex]
                lastAdvance = .now
                if !isPaused {
                    isPaused = true
                }
                return
            }
            index += 1
        }
        lastAdvance = .now
        if !isPaused {
            isPaused = true
        }
    }

    func advanceWord() {
        let wpm = wpmOptions[wpmIndex]
        var interval = 60.0 / Double(wpm)

        let word = words[currentWordIndex]

        if word.hasSuffix(".") || word.hasSuffix("!") || word.hasSuffix("?") {
            interval *= 1.8
        } else if word.hasSuffix(",") || word.hasSuffix(";") || word.hasSuffix(":") {
            interval *= 1.4
        }
        
        if paragraphStarts.contains(currentWordIndex) {
            interval *= 2.5
        }

        let now = Date()
        if now.timeIntervalSince(lastAdvance) >= interval {
            currentWordIndex += 1
            
            guard currentWordIndex < words.count else {
                stop()
                return
            }
            
            displayedWord = words[currentWordIndex]
            lastAdvance = now
        }
    }
}
