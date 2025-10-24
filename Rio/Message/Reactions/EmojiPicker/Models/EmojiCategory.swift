//
//  EmojiCategory.swift
//  EmojiPicker
//
//  Created by Edward Sanchez on 10/22/25.
//

import Foundation

enum EmojiCategory: Identifiable, Hashable {
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
        case .frequentlyUsed: return "frequentlyUsed"
        case .people(let sub): return "people_\(sub.rawValue)"
        case .expressive(let sub): return "expressive_\(sub.rawValue)"
        case .nature(let sub): return "nature_\(sub.rawValue)"
        case .food(let sub): return "food_\(sub.rawValue)"
        case .activities(let sub): return "activities_\(sub.rawValue)"
        case .travel(let sub): return "travel_\(sub.rawValue)"
        case .objects(let sub): return "objects_\(sub.rawValue)"
        case .symbols(let sub): return "symbols_\(sub.id)"
        }
    }
    
    var rawValue: String { id }
    
    var displayName: String {
        switch self {
        case .frequentlyUsed: return "Frequently Used"
        case .people: return "Smileys & People"
        case .expressive: return "Expressions"
        case .nature: return "Animals & Nature"
        case .food: return "Food & Drink"
        case .activities: return "Activities"
        case .travel: return "Travel & Places"
        case .objects: return "Objects"
        case .symbols: return "Symbols & Flags"
        }
    }
    
    var iconName: String {
        switch self {
        case .frequentlyUsed: return "clock.fill"
        case .people: return "face.smiling.fill"
        case .expressive: return "heart.fill"
        case .nature: return "dog.fill"
        case .food: return "fork.knife"
        case .activities: return "soccerball"
        case .travel: return "airplane"
        case .objects: return "lightbulb.fill"
        case .symbols: return "flag.fill"
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
    case jobs, fantasy, matrimony, sports, reactions, ageBased, royalty, other

    var description: String {
        switch self {
        case .happy:
            return "Joyful, smiling, grinning faces"
        case .love:
            return "Heart eyes, kissing, affectionate faces"
        case .playful:
            return "Silly, tongue out, winking, playful faces"
        case .sad:
            return "Crying, disappointed, pensive faces"
        case .angry:
            return "Mad, enraged, frustrated faces"
        case .surprised:
            return "Shocked, astonished, amazed faces"
        case .tired:
            return "Sleepy, yawning, exhausted faces"
        case .sick:
            return "Medical mask, ill, nauseated faces"
        case .worried:
            return "Anxious, confused, concerned faces"
        case .neutral:
            return "Meh, expressionless, unamused, skeptical faces"
        case .jobs:
            return "Professions and occupations"
        case .fantasy:
            return "Fantasy and supernatural characters"
        case .matrimony:
            return "Wedding-related people"
        case .sports:
            return "People doing sports activities"
        case .reactions:
            return "Gesture-based reactions and poses"
        case .ageBased:
            return "Basic people figures by age and appearance"
        case .royalty:
            return "Royal figures and nobility"
        case .other:
            return "Other people emojis"
        }
    }

    var id: String { rawValue }
}

enum ExpressiveSubcategories: String, CaseIterable, Identifiable, Hashable {
    case heart, gesture, creature, bodyPart

    var description: String {
        switch self {
        case .heart:
            return "Heart symbols and love expressions"
        case .gesture:
            return "Hand gestures and body language"
        case .creature:
            return "Expressive creatures and characters, like cats and monkeys"
        case .bodyPart:
            return "Body parts and anatomical features"
        }
    }

    var id: String { rawValue }
}

enum NatureSubCatchories: String, CaseIterable, Identifiable, Hashable {
    case mammal, bird, aquatic, reptile, insect, flower, plant
    
    var description: String {
        switch self {
        case .mammal:
            return "Mammals and furry animals"
        case .bird:
            return "Birds and feathered creatures"
        case .aquatic:
            return "Water-dwelling creatures"
        case .reptile:
            return "Reptiles, amphibians, and dinosaurs"
        case .insect:
            return "Insects and small crawling creatures"
        case .flower:
            return "Flowers and blossoms"
        case .plant:
            return "Plants, trees, and greenery"
        }
    }
    
    var id: String { rawValue }
}

enum FoodSubcategories: String, CaseIterable, Identifiable, Hashable {
    case fruit, vegetable, preparedFood, asian, dessert, drink
    
    var description: String {
        switch self {
        case .fruit:
            return "Fruits and berries"
        case .vegetable:
            return "Vegetables and legumes"
        case .preparedFood:
            return "Prepared meals and dishes"
        case .asian:
            return "Asian cuisine and dishes"
        case .dessert:
            return "Sweets, desserts, and baked goods"
        case .drink:
            return "Beverages and drinks"
        }
    }
    
    var id: String { rawValue }
}

enum ActivitiesSubcategories: String, CaseIterable, Identifiable, Hashable {
    case celebration, sport, game, hobby, art
    
    var description: String {
        switch self {
        case .celebration:
            return "Celebrations, parties, and events"
        case .sport:
            return "Sports and athletic activities"
        case .game:
            return "Games and gaming"
        case .hobby:
            return "Hobbies and leisure activities"
        case .art:
            return "Arts and creative activities"
        }
    }
    
    var id: String { rawValue }
}

enum TravelSubcategories: String, CaseIterable, Identifiable, Hashable {
    case nature, building, religious, scene, landVehicle, airVehicle, waterVehicle, sign, sky
    
    var description: String {
        switch self {
        case .nature:
            return "Natural landmarks and environments"
        case .building:
            return "Buildings and structures"
        case .religious:
            return "Religious buildings and places of worship"
        case .scene:
            return "Scenic views and locations"
        case .landVehicle:
            return "Cars, trains, and land vehicles"
        case .airVehicle:
            return "Airplanes, helicopters, and aircraft"
        case .waterVehicle:
            return "Boats, ships, and water vessels"
        case .sign:
            return "Traffic signs and road markers"
        case .sky:
            return "Sky, weather, and celestial phenomena"
        }
    }
    
    var id: String { rawValue }
}

enum ObjectsSubcategories: String, CaseIterable, Identifiable, Hashable {
    case clothing, accessory, music, tech, tool, office, household, medical, book
    
    var description: String {
        switch self {
        case .clothing:
            return "Clothes and garments"
        case .accessory:
            return "Accessories and wearable items"
        case .music:
            return "Musical instruments and audio"
        case .tech:
            return "Technology and electronics"
        case .tool:
            return "Tools and equipment"
        case .office:
            return "Office supplies and stationery"
        case .household:
            return "Household items and furniture"
        case .medical:
            return "Medical and health-related items"
        case .book:
            return "Books and reading materials"
        }
    }
    
    var id: String { rawValue }
}

enum SymbolsSubcategories: Identifiable, Hashable {
    case sign, arrow, religious, zodiac, media, number
    case flag(FlagSubcategories)
    case shape, other

    enum FlagSubcategories: String, CaseIterable, Identifiable, Hashable {
        case northAmerica, centralAmerica, southAmerica, africa, asia, europe, oceania, other

        var description: String {
            switch self {
            case .northAmerica:
                return "Flags from North America"
            case .centralAmerica:
                return "Flags from Central America"
            case .southAmerica:
                return "Flags from South America"
            case .africa:
                return "Flags from Africa"
            case .asia:
                return "Flags from Asia"
            case .europe:
                return "Flags from Europe"
            case .oceania:
                return "Flags from Oceania"
            case .other:
                return "Flags not from countries"
            }
        }
        
        var id: String { rawValue }
    }

    var description: String {
        switch self {
        case .sign:
            return "Warning signs and symbols"
        case .arrow:
            return "Arrows and directional symbols"
        case .religious:
            return "Religious and spiritual symbols"
        case .zodiac:
            return "Zodiac and astrological signs"
        case .media:
            return "Media controls and playback symbols"
        case .number:
            return "Numbers and numeric symbols"
        case .flag:
            return "Country and regional flags"
        case .shape:
            return "Geometric shapes and patterns"
        case .other:
            return "Other symbols and miscellaneous"
        }
    }
    
    var id: String {
        switch self {
        case .sign: return "sign"
        case .arrow: return "arrow"
        case .religious: return "religious"
        case .zodiac: return "zodiac"
        case .media: return "media"
        case .number: return "number"
        case .flag(let subcat): return "flag_\(subcat.rawValue)"
        case .shape: return "shape"
        case .other: return "other"
        }
    }
    
    // Manual implementation since we can't use CaseIterable with associated values
    static var allCases: [SymbolsSubcategories] {
        var cases: [SymbolsSubcategories] = [.sign, .arrow, .religious, .zodiac, .media, .number]
        cases.append(contentsOf: FlagSubcategories.allCases.map { .flag($0) })
        cases.append(contentsOf: [.shape, .other])
        return cases
    }
}
