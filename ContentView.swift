import SwiftUI

// MARK: - MODELS (UNCHANGED)

struct PeriodRecord: Identifiable, Codable {
    var id = UUID()
    var start: Date
    var end: Date?
}

struct NoteEntry: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var text: String
}

// MARK: - DATA MANAGER (UNCHANGED)

class AppData: ObservableObject {
    
    @Published var periods: [PeriodRecord] = []
    @Published var notes: [NoteEntry] = []
    
    init() { load() }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(periods) {
            UserDefaults.standard.set(encoded, forKey: "periods")
        }
        if let encoded = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(encoded, forKey: "notes")
        }
    }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: "periods"),
           let decoded = try? JSONDecoder().decode([PeriodRecord].self, from: data) {
            periods = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: "notes"),
           let decoded = try? JSONDecoder().decode([NoteEntry].self, from: data) {
            notes = decoded
        }
    }
}

// MARK: ENTRY

struct ContentView: View {
    
    @StateObject var data = AppData()
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            
            // Switch between screens
            Group {
                switch selectedTab {
                case 0:
                    CalendarView().environmentObject(data)
                case 1:
                    NotesView().environmentObject(data)
                case 2:
                    HistoryView().environmentObject(data)
                default:
                    RecipeHubView()
                }
            }
            
            // Custom Floating Navigation Bar
            VStack {
                Spacer()
                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 25)
            }
        }
    }
}

// MARK: SHARED HEADER STYLE

struct PremiumBackground<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.pink.opacity(0.18), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            content
        }
    }
}
// MARK: CALENDAR VIEW

struct CalendarView: View {
    
    @EnvironmentObject var data: AppData
    
    @State private var currentDate = Date()
    @State private var selectedDate: Date?
    @State private var showSheet = false
    
    let calendar = Calendar.current
    
    var body: some View {
        
        ZStack {
            
            LinearGradient(
                colors: [
                    Color.pink.opacity(0.25),
                    Color.pink.opacity(0.08),
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                
                headerCard
                
                cycleSummaryCard
                
                calendarContainer
                
                Spacer()
            }
            .padding(.horizontal, 60)
            .padding(.top, 40)
        }
        .sheet(isPresented: $showSheet) {
            periodSheet
        }
    }
}
// MARK: CALENDAR EXTENSION 

extension CalendarView {
    
    var headerCard: some View {
        VStack(spacing: 6) {
            Text("OVA")
                .font(.system(size: 34, weight: .bold))
            
            Text(String(calendar.component(.year, from: currentDate)))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
        )
    }
    
    var cycleSummaryCard: some View {
        
        let lastPeriod = data.periods.last
        let openPeriod = data.periods.first(where: { $0.end == nil })
        
        return HStack(spacing: 50) {
            
            VStack {
                Text("Tracked")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(data.periods.count)")
                    .font(.title3.bold())
                    .foregroundColor(.pink)
            }
            
            VStack {
                Text("Last Logged")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let last = lastPeriod {
                    Text(last.start.formatted(date: .abbreviated, time: .omitted))
                        .font(.title3.bold())
                        .foregroundColor(.pink)
                } else {
                    Text("—")
                        .font(.title3.bold())
                        .foregroundColor(.pink.opacity(0.6))
                }
            }
            
            VStack {
                Text("Current Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if openPeriod != nil {
                    Text("Active")
                        .font(.title3.bold())
                        .foregroundColor(.pink)
                } else {
                    Text("Inactive")
                        .font(.title3.bold())
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(25)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
        )
    }
    
    var calendarContainer: some View {
        VStack(spacing: 20) {
            monthBar
            weekdayHeader
            calendarGrid
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 34)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 15, y: 8)
        )
    }
    
    var monthBar: some View {
        HStack {
            Button { changeMonth(-1) } label: {
                Image(systemName: "chevron.left")
            }
            
            Spacer()
            
            Text(monthName)
                .font(.title2.weight(.semibold))
            
            Spacer()
            
            Button { changeMonth(1) } label: {
                Image(systemName: "chevron.right")
            }
        }
    }
    
    var monthName: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL"
        return f.string(from: currentDate)
    }
    
    func changeMonth(_ value: Int) {
        currentDate = calendar.date(byAdding: .month, value: value, to: currentDate)!
    }
    
    var weekdayHeader: some View {
        HStack {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    var calendarGrid: some View {
        let days = generateDays()
        
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 7),
            spacing: 16
        ) {
            ForEach(days, id: \.self) { date in
                if let date = date {
                    dayCell(date)
                } else {
                    Color.clear.frame(height: 56)
                }
            }
        }
    }
    
    func generateDays() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else { return [] }
        
        let start = monthFirstWeek.start
        let end = calendar.date(byAdding: .day, value: 41, to: start)!
        
        return stride(from: start, to: end, by: 86400).map {
            calendar.isDate($0, equalTo: currentDate, toGranularity: .month) ? $0 : nil
        }
    }
    
    func dayCell(_ date: Date) -> some View {
        
        let isToday = calendar.isDateInToday(date)
        
        let isPeriod = data.periods.contains {
            if let end = $0.end {
                return date >= $0.start && date <= end
            }
            return calendar.isDate(date, inSameDayAs: $0.start)
        }
        
        return Button {
            selectedDate = date
            showSheet = true
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 16, weight: .medium))
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(isPeriod ? Color.pink : Color.pink.opacity(0.15))
                )
                .foregroundColor(isPeriod ? .white : .primary)
                .overlay(
                    Circle()
                        .stroke(isToday ? Color.pink : Color.clear, lineWidth: 3)
                )
        }
    }
    
    var periodSheet: some View {
        VStack(spacing: 18) {
            
            Text(selectedDate?.formatted(date: .abbreviated, time: .omitted) ?? "")
                .font(.headline)
            
            Button("Start Period") {
                if let date = selectedDate {
                    data.periods.append(PeriodRecord(start: date))
                    data.save()
                }
                showSheet = false
            }
            .buttonStyle(PrimaryButton())
            
            Button("End Period") {
                if let openIndex = data.periods.lastIndex(where: { $0.end == nil }),
                   let date = selectedDate {
                    data.periods[openIndex].end = date
                    data.save()
                }
                showSheet = false
            }
            .buttonStyle(OutlineButton())
            
            Button("Delete Record") {
                if let date = selectedDate {
                    data.periods.removeAll {
                        if let end = $0.end {
                            return date >= $0.start && date <= end
                        }
                        return calendar.isDate(date, inSameDayAs: $0.start)
                    }
                    data.save()
                }
                showSheet = false
            }
            .foregroundColor(.red)
            
            Button("Cancel") {
                showSheet = false
            }
        }
        .padding()
    }
}
// MARK: NOTES VIEW
struct NotesView: View {
    
    @EnvironmentObject var data: AppData
    
    @State private var showAddPopup = false
    @State private var showDetailPopup = false
    @State private var selectedNote: NoteEntry?
    @State private var noteText = ""
    @State private var isEditing = false
    
    var body: some View {
        
        ZStack {
            
            PremiumBackground {
                ScrollView {
                    VStack(spacing: 24) {
                        
                        headerCard
                        
                        if data.notes.isEmpty {
                            Button {
                                showAddPopup = true
                            } label: {
                                Text("No notes added.\nClick to add notes.")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 80)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        ForEach(data.notes.sorted(by: { $0.date > $1.date })) { note in
                            
                            Button {
                                selectedNote = note
                                showDetailPopup = true
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    
                                    Text(note.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(note.text)
                                        .lineLimit(2)
                                        .foregroundColor(.primary)
                                }
                                .padding(24)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 28)
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: .black.opacity(0.06), radius: 15, y: 8)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 60)
                        }
                        
                        Spacer(minLength: 140)
                    }
                    .padding(.top, 40)
                }
            }
            
            
            // Floating + Button
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    Button {
                        isEditing = false
                        noteText = ""
                        showAddPopup = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(Color.pink)
                            .clipShape(Circle())
                            .shadow(color: .pink.opacity(0.4), radius: 20, y: 10)
                    }
                    .padding(.trailing, 70)
                    .padding(.bottom, 120)
                }
            }
            
            
            // Add / Edit Popup
            
            if showAddPopup {
                
                popupBackground
                
                VStack(spacing: 24) {
                    
                    Text(isEditing ? "Edit Note" : "Tell me what you feel…")
                        .font(.title2.bold())
                    
                    TextEditor(text: $noteText)
                        .padding()
                        .frame(height: 200)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                        )
                    
                    Button("Save") {
                        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        guard !trimmed.isEmpty else { return }
                        
                        if isEditing, let selected = selectedNote,
                           let index = data.notes.firstIndex(where: { $0.id == selected.id }) {
                            
                            data.notes[index].text = trimmed
                            data.notes[index].date = Date()   // update timestamp on edit
                            data.save()
                            
                        } else {
                            let newNote = NoteEntry(date: Date(), text: trimmed)
                            data.notes.append(newNote)
                            data.save()
                        }
                        
                        noteText = ""
                        selectedNote = nil
                        isEditing = false
                        showAddPopup = false
                    }
                    .buttonStyle(PrimaryButton())
                    
                    Button("Cancel") {
                        showAddPopup = false
                    }
                    .foregroundColor(.secondary)
                }
                .padding(40)
                .frame(width: 520)
                .background(
                    RoundedRectangle(cornerRadius: 34)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 30, y: 20)
                )
            }
            
            
            // Detail Popup
            
            if showDetailPopup, let note = selectedNote {
                
                popupBackground
                
                VStack(spacing: 24) {
                    
                    Text(note.date.formatted(date: .complete, time: .shortened))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ScrollView {
                        Text(note.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(maxHeight: 250)
                    
                    HStack(spacing: 20) {
                        
                        Button("Edit") {
                            noteText = note.text
                            isEditing = true
                            showDetailPopup = false
                            showAddPopup = true
                        }
                        .buttonStyle(OutlineButton())
                        
                        Button("Delete") {
                            data.notes.removeAll { $0.id == note.id }
                            data.save()
                            showDetailPopup = false
                        }
                        .foregroundColor(.red)
                    }
                }
                .padding(40)
                .frame(width: 520)
                .background(
                    RoundedRectangle(cornerRadius: 34)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 30, y: 20)
                )
            }
        }
    }
    
    
    var popupBackground: some View {
        Color.black.opacity(0.25)
            .ignoresSafeArea()
            .onTapGesture {
                showAddPopup = false
                showDetailPopup = false
            }
    }
    
    
    var headerCard: some View {
        VStack {
            Text("Notes")
                .font(.system(size: 36, weight: .bold))
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 36)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
        )
        .padding(.horizontal, 60)
    }
}
    // MARK: HISTORY VIEW

struct HistoryView: View {
    
    @EnvironmentObject var data: AppData
    
    var body: some View {
        
        PremiumBackground {
            ScrollView {
                VStack(spacing: 30) {
                    
                    headerCard
                    
                    if data.periods.isEmpty {
                        Text("No cycle history yet.")
                            .foregroundColor(.secondary)
                            .padding(.top, 80)
                    }
                    
                    ForEach(data.periods.sorted(by: { $0.start > $1.start })) { period in
                        
                        historyCard(for: period)
                            .padding(.horizontal, 80)
                    }
                    
                    Spacer(minLength: 140)
                }
                .padding(.top, 40)
            }
        }
    }
    
    
    // MARK: History Card
    
    func historyCard(for period: PeriodRecord) -> some View {
        
        let duration = period.end != nil ?
        Calendar.current.dateComponents([.day], from: period.start, to: period.end!).day ?? 0
        : nil
        
        return VStack(alignment: .leading, spacing: 18) {
            
            HStack {
                Text("Cycle")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let days = duration {
                    Text("\(days + 1) days")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color(red: 0.95, green: 0.35, blue: 0.55))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.95, green: 0.35, blue: 0.55).opacity(0.12))
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                
                HStack {
                    Text("Start")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(period.start.formatted(date: .abbreviated, time: .omitted))
                        .fontWeight(.medium)
                }
                
                if let end = period.end {
                    HStack {
                        Text("End")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(end.formatted(date: .abbreviated, time: .omitted))
                            .fontWeight(.medium)
                    }
                } else {
                    HStack {
                        Text("Status")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Active")
                            .fontWeight(.semibold)
                            .foregroundColor(.pink)
                    }
                }
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.pink.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .pink.opacity(0.08), radius: 20, y: 10)
        )
    }
    
    
    // MARK: Header
    
    var headerCard: some View {
        VStack {
            Text("History")
                .font(.system(size: 36, weight: .bold))
        }
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 36)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
        )
        .padding(.horizontal, 60)
    }
}

// MARK: RECIPE HUB

struct RecipeHubView: View {
    @State private var expandedRecipeID: UUID?
    var body: some View {
        
        PremiumBackground {
            ScrollView {
                
                VStack(spacing: 40) {
                    
                    headerCard
                    
                    recipeSection(
                        title: "Breakfast: Hormone-Balancing Starts",
                        recipes: breakfastRecipes
                    )
                    
                    recipeSection(
                        title: "Lunch: High-Protein & Anti-Inflammatory",
                        recipes: lunchRecipes
                    )
                    
                    recipeSection(
                        title: "Dinner: Restorative & Mineral-Rich",
                        recipes: dinnerRecipes
                    )
                    
                    recipeSection(
                        title: "Snacks & Drinks: Hormone Support",
                        recipes: snackRecipes
                    )
                    
                    Spacer(minLength: 120)
                }
                .padding(.top, 40)
            }
        }
    }
    
    func recipeSection(title: String, recipes: [Recipe]) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            
            Text(title)
                .font(.title2.bold())
                .padding(.horizontal, 60)
            
            ForEach(recipes) { recipe in
                recipeCard(recipe)
                    .padding(.horizontal, 60)
            }
        }
    }
    
    func recipeCard(_ recipe: Recipe) -> some View {
        
        let isExpanded = expandedRecipeID == recipe.id
        
        return VStack(alignment: .leading, spacing: 16) {
            
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if expandedRecipeID == recipe.id {
                        expandedRecipeID = nil
                    } else {
                        expandedRecipeID = recipe.id
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(recipe.title)
                            .font(.headline)
                        
                        Text("Focus: \(recipe.focus)")
                            .font(.subheadline)
                            .foregroundColor(Color(red: 0.95, green: 0.35, blue: 0.55))
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                
                Divider()
                
                Text("Ingredients")
                    .font(.subheadline.bold())
                
                ForEach(recipe.ingredients, id: \.self) { ingredient in
                    Text("• \(ingredient)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                Text("Steps")
                    .font(.subheadline.bold())
                
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    Text("\(index + 1). \(step)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.pink.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .pink.opacity(0.08), radius: 20, y: 10)
        )
    }
    
    struct Recipe: Identifiable {
        let id = UUID()
        let title: String
        let focus: String
        let ingredients: [String]
        let steps: [String]
    }
    
    let breakfastRecipes: [Recipe] = [
        
        Recipe(
            title: "Overnight Berry & Chia Power Seed Pudding",
            focus: "High Fiber & Omega-3",
            ingredients: [
                "3 tbsp chia seeds",
                "1 cup unsweetened almond milk",
                "½ tsp vanilla extract",
                "Pinch cinnamon",
                "1 tsp monk fruit sweetener (optional)",
                "½ cup fresh raspberries",
                "1 tbsp crushed walnuts"
            ],
            steps: [
                "Whisk chia seeds, almond milk, vanilla, and cinnamon in a jar.",
                "Add monk fruit sweetener if desired.",
                "Seal and refrigerate for at least 4 hours or overnight.",
                "Stir well before serving to loosen texture.",
                "Top with raspberries and crushed walnuts."
            ]
        ),
        
        Recipe(
            title: "Savory Avocado & Soft-Boiled Egg Toast",
            focus: "Healthy Fats & Protein",
            ingredients: [
                "1 slice sprouted grain bread",
                "½ ripe avocado",
                "Juice of ¼ lime",
                "Sea salt",
                "Red pepper flakes",
                "2 eggs",
                "Microgreens",
                "Hemp seeds"
            ],
            steps: [
                "Toast the bread until golden and crisp.",
                "Mash avocado with lime juice, salt and red pepper flakes.",
                "Boil eggs for exactly 6½ minutes.",
                "Transfer eggs to ice water to stop cooking.",
                "Peel and slice eggs.",
                "Spread avocado mixture thickly on toast.",
                "Top with eggs, microgreens and hemp seeds."
            ]
        ),
        
        Recipe(
            title: "Flaxseed & Blueberry Protein Pancakes",
            focus: "Low Carb & Phytoestrogens",
            ingredients: [
                "2 eggs",
                "½ cup almond flour",
                "2 tbsp ground flaxseeds",
                "¼ cup ricotta cheese",
                "5–6 blueberries per pancake",
                "1 tbsp almond butter",
                "Coconut oil for cooking"
            ],
            steps: [
                "Blend eggs, almond flour, flaxseeds and ricotta into a smooth batter.",
                "Heat coconut oil in a non-stick pan.",
                "Pour small pancake circles.",
                "Press blueberries into the wet side before flipping.",
                "Cook until golden on both sides.",
                "Serve stacked with almond butter."
            ]
        )
    ]
    let lunchRecipes: [Recipe] = [
        
        Recipe(
            title: "Turmeric Ginger Salmon Salad",
            focus: "Anti-inflammatory & Omega-3",
            ingredients: [
                "1 salmon fillet",
                "½ tsp turmeric",
                "½ tsp ginger powder",
                "1 tbsp olive oil",
                "2 cups baby spinach",
                "½ cucumber (sliced)",
                "3 radishes (sliced)",
                "1 tbsp toasted pumpkin seeds",
                "Lemon vinaigrette"
            ],
            steps: [
                "Rub salmon with turmeric, ginger and olive oil.",
                "Air-fry at 200°C for 10–12 minutes.",
                "Toss spinach with lemon vinaigrette.",
                "Add cucumbers, radishes and pumpkin seeds.",
                "Flake warm salmon over the greens and serve."
            ]
        ),
        
        Recipe(
            title: "Mediterranean Quinoa & Chickpea Bowl",
            focus: "Slow-Release Carbs & Fiber",
            ingredients: [
                "1 cup cooked quinoa",
                "½ cup chickpeas (rinsed)",
                "½ cup cherry tomatoes",
                "½ Persian cucumber (diced)",
                "2 tbsp kalamata olives",
                "1 tbsp olive oil",
                "1 clove minced garlic",
                "Juice of ½ lemon",
                "Dried oregano",
                "Sheep’s milk feta (optional)"
            ],
            steps: [
                "Cook quinoa in vegetable broth and cool slightly.",
                "Combine quinoa with chickpeas, tomatoes, cucumber and olives.",
                "Whisk olive oil, garlic, oregano and lemon juice.",
                "Toss dressing into bowl.",
                "Top with feta before serving."
            ]
        ),
        
        Recipe(
            title: "Zucchini Noodles with Pumpkin Seed Pesto",
            focus: "Low GI & Zinc-Rich",
            ingredients: [
                "2 large zucchinis",
                "2 cups fresh basil",
                "½ cup toasted pumpkin seeds",
                "1 garlic clove",
                "¼ cup olive oil",
                "4 oz grilled chicken strips"
            ],
            steps: [
                "Spiralize zucchini into noodles.",
                "Sauté lightly for 2 minutes to keep al dente.",
                "Blend basil, pumpkin seeds, garlic and olive oil into pesto.",
                "Toss pesto with zucchini noodles.",
                "Top with grilled chicken."
            ]
        ),
        
        Recipe(
            title: "Lean Turkey & Bell Pepper Tacos",
            focus: "High Protein & Antioxidants",
            ingredients: [
                "200g lean ground turkey",
                "½ tsp cumin",
                "½ tsp paprika",
                "Romaine lettuce leaves or halved bell peppers",
                "Greek yogurt",
                "Pickled onions",
                "Fresh cilantro"
            ],
            steps: [
                "Cook turkey with cumin and paprika until browned.",
                "Use lettuce leaves or bell peppers as taco shells.",
                "Fill with turkey mixture.",
                "Top with Greek yogurt, pickled onions and cilantro."
            ]
        )
    ]
    let dinnerRecipes: [Recipe] = [
        
        Recipe(
            title: "Lemon Herb Roasted Chicken with Asparagus",
            focus: "Lean Protein & Liver Support",
            ingredients: [
                "2 chicken breasts",
                "Rosemary and thyme",
                "Zest of 1 lemon",
                "1 bunch asparagus",
                "1 tbsp olive oil",
                "2 garlic cloves"
            ],
            steps: [
                "Season chicken with herbs and lemon zest.",
                "Trim asparagus and toss with olive oil and garlic.",
                "Place everything on a sheet pan.",
                "Bake at 200°C for 20–25 minutes.",
                "Finish with fresh lemon juice."
            ]
        ),
        
        Recipe(
            title: "Red Lentil & Spinach Dahl",
            focus: "Iron & Plant Protein",
            ingredients: [
                "1 cup red lentils",
                "1 small onion",
                "2 garlic cloves",
                "1 tbsp grated ginger",
                "1 tbsp yellow curry powder",
                "3 cups water",
                "2 handfuls fresh spinach"
            ],
            steps: [
                "Sauté onion, garlic and ginger in coconut oil.",
                "Add curry powder and toast briefly.",
                "Add lentils and water.",
                "Simmer 15–20 minutes until soft.",
                "Stir in spinach until wilted.",
                "Serve with cauliflower rice."
            ]
        ),
        
        Recipe(
            title: "Baked Cod with Cherry Tomato & Caper Relish",
            focus: "High Mineral & Light",
            ingredients: [
                "2 cod fillets",
                "½ cup cherry tomatoes",
                "1 tbsp capers",
                "Fresh parsley",
                "1 tbsp olive oil"
            ],
            steps: [
                "Mix tomatoes, capers, parsley and olive oil.",
                "Place cod in baking dish.",
                "Top with relish mixture.",
                "Bake at 190°C for 15 minutes until flaky."
            ]
        ),
        
        Recipe(
            title: "Beef & Broccoli Stir-Fry (Soy-Free)",
            focus: "Iron & Cruciferous Support",
            ingredients: [
                "200g lean flank steak",
                "1 cup broccoli florets",
                "2 tbsp coconut aminos",
                "1 tsp grated ginger",
                "1 tsp sesame oil",
                "Toasted sesame seeds"
            ],
            steps: [
                "Slice steak thinly.",
                "Heat wok on high.",
                "Cook broccoli briefly until bright green.",
                "Add beef and stir-fry 5–7 minutes.",
                "Add coconut aminos and sesame oil.",
                "Garnish with sesame seeds."
            ]
        )
    ]
    let snackRecipes: [Recipe] = [
        
        Recipe(
            title: "Apple Slices with Cinnamon & Hemp Seeds",
            focus: "Blood Sugar Support",
            ingredients: [
                "1 green apple",
                "1 tbsp sunflower seed butter",
                "Cinnamon",
                "1 tbsp hemp seeds"
            ],
            steps: [
                "Core and slice apple.",
                "Lightly spread sunflower seed butter.",
                "Sprinkle with cinnamon and hemp seeds."
            ]
        ),
        
        Recipe(
            title: "Roasted Spiced Chickpeas",
            focus: "High Fiber Crunch",
            ingredients: [
                "1 can chickpeas",
                "1 tbsp olive oil",
                "½ tsp smoked paprika",
                "Pinch salt"
            ],
            steps: [
                "Pat chickpeas completely dry.",
                "Toss with olive oil and paprika.",
                "Roast at 200°C for 30 minutes.",
                "Shake tray halfway through."
            ]
        ),
        
        Recipe(
            title: "Spearmint & Ginger Hormone Tea",
            focus: "Anti-Androgen Support",
            ingredients: [
                "1 tsp dried spearmint leaves",
                "2 slices fresh ginger",
                "1 cup boiling water"
            ],
            steps: [
                "Add spearmint and ginger to cup.",
                "Pour boiling water over.",
                "Steep 10 minutes.",
                "Drink warm twice daily."
            ]
        ),
        
        Recipe(
            title: "Dark Chocolate & Raspberry Bark",
            focus: "Low Sugar Treat",
            ingredients: [
                "85% dark chocolate",
                "Fresh raspberries",
                "Sea salt flakes"
            ],
            steps: [
                "Melt chocolate in double boiler.",
                "Spread thin on parchment paper.",
                "Press raspberries and sea salt into surface.",
                "Freeze 30 minutes.",
                "Break into shards before serving."
            ]
        )
    ]
    //////////////////////////////////////////////////////////
    // MARK: Header
    //////////////////////////////////////////////////////////
    
    var headerCard: some View {
        VStack {
            Text("Recipe Hub")
                .font(.system(size: 36, weight: .bold))
        }
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 36)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
        )
        .padding(.horizontal, 60)
    }
}

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.pink)
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
}

struct OutlineButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .overlay(Capsule().stroke(Color.pink))
    }
}
struct CustomTabBar: View {
    
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack {
            tabButton(icon: "calendar", index: 0)
            tabButton(icon: "note.text", index: 1)
            tabButton(icon: "clock.arrow.circlepath", index: 2)
            tabButton(icon: "fork.knife", index: 3)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        )
    }
    
    func tabButton(icon: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut) {
                selectedTab = index
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(selectedTab == index ? .pink : .gray)
                .frame(maxWidth: .infinity)
        }
    }
}
