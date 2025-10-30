//
//  EmojiCategory.swift
//  EmojiPicker
//
//  Created by Edward Sanchez on 10/22/25.
//

import Foundation

nonisolated enum EmojiCategory: Identifiable, Hashable, Sendable {
    case frequentlyUsed
    case people(PeopleSubcategories)
    case expressive(ExpressiveSubcategories)
    case nature(NatureSubCatchories)
    case food(FoodSubcategories)
    case activities(ActivitiesSubcategories)
    case travel(TravelSubcategories)
    case objects(ObjectsSubcategories)
    case symbols(SymbolsSubcategories)

    var id: String {
        switch self {
        case .frequentlyUsed: "frequentlyUsed"
        case let .people(sub): "people_\(sub.rawValue)"
        case let .expressive(sub): "expressive_\(sub.rawValue)"
        case let .nature(sub): "nature_\(sub.rawValue)"
        case let .food(sub): "food_\(sub.rawValue)"
        case let .activities(sub): "activities_\(sub.rawValue)"
        case let .travel(sub): "travel_\(sub.rawValue)"
        case let .objects(sub): "objects_\(sub.rawValue)"
        case let .symbols(sub): "symbols_\(sub.rawValue)"
        }
    }

    var rawValue: String { id }

    var displayName: String {
        switch self {
        case .frequentlyUsed: "Frequently Used"
        case .people: "Smileys & People"
        case .expressive: "Expressions"
        case .nature: "Animals & Nature"
        case .food: "Food & Drink"
        case .activities: "Activities"
        case .travel: "Travel & Places"
        case .objects: "Objects"
        case .symbols: "Symbols & Flags"
        }
    }

    var iconName: String {
        switch self {
        case .frequentlyUsed: "clock.fill"
        case .people: "face.smiling.fill"
        case .expressive: "heart.fill"
        case .nature: "dog.fill"
        case .food: "fork.knife"
        case .activities: "soccerball"
        case .travel: "airplane"
        case .objects: "lightbulb.fill"
        case .symbols: "flag.fill"
        }
    }

    // Manual implementation since we can't use CaseIterable with associated values
    static var allCases: [EmojiCategory] {
        [
            .frequentlyUsed,
            .people(.happy),
            .expressive(.heart),
            .nature(.mammal),
            .food(.fruit),
            .activities(.celebration),
            .travel(.nature),
            .objects(.clothing),
            .symbols(.sign)
        ]
    }
}

enum PeopleSubcategories: String, CaseIterable, Identifiable, Hashable {
    case happy, love, playful, sad, angry, surprised, tired, sick, worried, neutral
    case jobs, fantasy, matrimony, sports, reactions, ageBased, family, royalty, other

    var description: String {
        switch self {
        case .happy:
            "Joyful, smiling, grinning faces"
        case .love:
            "Heart eyes, kissing, affectionate faces"
        case .playful:
            "Silly, tongue out, winking, playful faces"
        case .sad:
            "Crying, disappointed, pensive faces"
        case .angry:
            "Mad, enraged, frustrated faces"
        case .surprised:
            "Shocked, astonished, amazed faces"
        case .tired:
            "Sleepy, yawning, exhausted faces"
        case .sick:
            "Medical mask, ill, nauseated faces"
        case .worried:
            "Anxious, confused, concerned faces"
        case .neutral:
            "Meh, expressionless, unamused, skeptical faces"
        case .jobs:
            "Professions and occupations"
        case .fantasy:
            "Fantasy and supernatural characters"
        case .matrimony:
            "Wedding-related people"
        case .sports:
            "People doing sports activities"
        case .reactions:
            "Gesture-based reactions and poses"
        case .ageBased:
            "Basic people figures by age and appearance"
        case .family:
            "Family combinations and parent–child groupings"
        case .royalty:
            "Royal figures and nobility"
        case .other:
            "Other people emojis"
        }
    }

    var id: String { rawValue }
}

enum ExpressiveSubcategories: String, CaseIterable, Identifiable, Hashable {
    case heart, gesture, creature, bodyPart

    var description: String {
        switch self {
        case .heart:
            "Heart symbols and love expressions"
        case .gesture:
            "Hand gestures and body language"
        case .creature:
            "Expressive creatures and characters, like cats and monkeys"
        case .bodyPart:
            "Body parts and anatomical features"
        }
    }

    var id: String { rawValue }
}

enum NatureSubCatchories: String, CaseIterable, Identifiable, Hashable {
    case mammal, bird, aquatic, reptile, insect, flower, plant

    var description: String {
        switch self {
        case .mammal:
            "Mammals and furry animals"
        case .bird:
            "Birds and feathered creatures"
        case .aquatic:
            "Water-dwelling creatures"
        case .reptile:
            "Reptiles, amphibians, and dinosaurs"
        case .insect:
            "Insects and small crawling creatures"
        case .flower:
            "Flowers and blossoms"
        case .plant:
            "Plants, trees, and greenery"
        }
    }

    var id: String { rawValue }
}

enum FoodSubcategories: String, CaseIterable, Identifiable, Hashable {
    case fruit, vegetable, preparedFood, asian, dessert, drink

    var description: String {
        switch self {
        case .fruit:
            "Fruits and berries"
        case .vegetable:
            "Vegetables and legumes"
        case .preparedFood:
            "Prepared meals and dishes"
        case .asian:
            "Asian cuisine and dishes"
        case .dessert:
            "Sweets, desserts, and baked goods"
        case .drink:
            "Beverages and drinks"
        }
    }

    var id: String { rawValue }
}

enum ActivitiesSubcategories: String, CaseIterable, Identifiable, Hashable {
    case celebration, sport, game, hobby, art

    var description: String {
        switch self {
        case .celebration:
            "Celebrations, parties, and events"
        case .sport:
            "Sports and athletic activities"
        case .game:
            "Games and gaming"
        case .hobby:
            "Hobbies and leisure activities"
        case .art:
            "Arts and creative activities"
        }
    }

    var id: String { rawValue }
}

enum TravelSubcategories: String, CaseIterable, Identifiable, Hashable {
    case nature, building, religious, scene, landVehicle, airVehicle, waterVehicle, sign, sky

    var description: String {
        switch self {
        case .nature:
            "Natural landmarks and environments"
        case .building:
            "Buildings and structures"
        case .religious:
            "Religious buildings and places of worship"
        case .scene:
            "Scenic views and locations"
        case .landVehicle:
            "Cars, trains, and land vehicles"
        case .airVehicle:
            "Airplanes, helicopters, and aircraft"
        case .waterVehicle:
            "Boats, ships, and water vessels"
        case .sign:
            "Traffic signs and road markers"
        case .sky:
            "Sky, weather, and celestial phenomena"
        }
    }

    var id: String { rawValue }
}

enum ObjectsSubcategories: String, CaseIterable, Identifiable, Hashable {
    case clothing, accessory, music, tech, tool, office, household, medical, book

    var description: String {
        switch self {
        case .clothing:
            "Clothes and garments"
        case .accessory:
            "Accessories and wearable items"
        case .music:
            "Musical instruments and audio"
        case .tech:
            "Technology and electronics"
        case .tool:
            "Tools and equipment"
        case .office:
            "Office supplies and stationery"
        case .household:
            "Household items and furniture"
        case .medical:
            "Medical and health-related items"
        case .book:
            "Books and reading materials"
        }
    }

    var id: String { rawValue }
}

nonisolated enum SymbolsSubcategories: Identifiable, Hashable, CaseIterable, Sendable {
    case sign, arrow, religious, zodiac, media, number
    case flag(FlagSubcategories)
    case shape, other

    enum FlagSubcategories: String, CaseIterable, Identifiable, Hashable, Sendable {
        case northAmerica, centralAmerica, southAmerica, africa, asia, europe, oceania, other

        var description: String {
            switch self {
            case .northAmerica: "Flags from North America"
            case .centralAmerica: "Flags from Central America"
            case .southAmerica: "Flags from South America"
            case .africa: "Flags from Africa"
            case .asia: "Flags from Asia"
            case .europe: "Flags from Europe"
            case .oceania: "Flags from Oceania"
            case .other: "Flags not from countries"
            }
        }

        var id: String { rawValue }
    }

    var description: String {
        switch self {
        case .sign: "Warning signs and symbols"
        case .arrow: "Arrows and directional symbols"
        case .religious: "Religious and spiritual symbols"
        case .zodiac: "Zodiac and astrological signs"
        case .media: "Media controls and playback symbols"
        case .number: "Numbers and numeric symbols"
        case .flag: "Country and regional flags"
        case .shape: "Geometric shapes and patterns"
        case .other: "Other symbols and miscellaneous"
        }
    }

    var id: String {
        switch self {
        case .sign: "sign"
        case .arrow: "arrow"
        case .religious: "religious"
        case .zodiac: "zodiac"
        case .media: "media"
        case .number: "number"
        case let .flag(subcat): "flag_\(subcat.rawValue)"
        case .shape: "shape"
        case .other: "other"
        }
    }

    // Manual implementation since we can't use CaseIterable with associated values
    static var allCases: [SymbolsSubcategories] {
        var cases: [SymbolsSubcategories] = [.sign, .arrow, .religious, .zodiac, .media, .number]
        cases += FlagSubcategories.allCases.map { .flag($0) }
        cases += [.shape, .other]
        return cases
    }
}

nonisolated extension SymbolsSubcategories: RawRepresentable {
    typealias RawValue = String

    init?(rawValue: String) {
        switch rawValue {
        case "sign": self = .sign
        case "arrow": self = .arrow
        case "religious": self = .religious
        case "zodiac": self = .zodiac
        case "media": self = .media
        case "number": self = .number
        case "shape": self = .shape
        case "other": self = .other
        default:
            if rawValue.hasPrefix("flag_") {
                let suffix = String(rawValue.dropFirst(5))
                guard let sub = FlagSubcategories(rawValue: suffix) else { return nil }
                self = .flag(sub)
            } else {
                return nil
            }
        }
    }

    var rawValue: String { id }
}
