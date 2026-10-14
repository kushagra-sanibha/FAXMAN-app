import Foundation

/// Countries a fax number can be rented in — the same US/Canada scope as sending.
enum FaxNumberCountry: String, CaseIterable, Identifiable, Hashable, Sendable {
    case unitedStates = "US"
    case canada = "CA"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .unitedStates: "United States"
        case .canada: "Canada"
        }
    }

    var flag: String {
        switch self {
        case .unitedStates: "🇺🇸"
        case .canada: "🇨🇦"
        }
    }

    /// "state" vs "province" in the picker copy.
    var regionNoun: String {
        switch self {
        case .unitedStates: "state"
        case .canada: "province"
        }
    }
}

/// A state, province or territory and the area codes that serve it.
struct AreaCodeRegion: Identifiable, Hashable, Sendable {
    let code: String
    let name: String
    let country: FaxNumberCountry
    let areaCodes: [String]

    var id: String { "\(country.rawValue)-\(code)" }
}

/// North American Numbering Plan geographic area codes, grouped by region.
/// Used to offer the state/province picker and to validate a typed-in area
/// code before searching for numbers.
enum AreaCodeDirectory {
    static func regions(in country: FaxNumberCountry) -> [AreaCodeRegion] {
        all.filter { $0.country == country }
    }

    /// Regions served by `areaCode` (a few codes, e.g. 902, span two provinces).
    static func regions(forAreaCode areaCode: String, in country: FaxNumberCountry) -> [AreaCodeRegion] {
        regions(in: country).filter { $0.areaCodes.contains(areaCode) }
    }

    static func allAreaCodes(in country: FaxNumberCountry) -> [String] {
        Array(Set(regions(in: country).flatMap(\.areaCodes))).sorted()
    }

    private static func us(_ code: String, _ name: String, _ codes: [String]) -> AreaCodeRegion {
        AreaCodeRegion(code: code, name: name, country: .unitedStates, areaCodes: codes)
    }

    private static func ca(_ code: String, _ name: String, _ codes: [String]) -> AreaCodeRegion {
        AreaCodeRegion(code: code, name: name, country: .canada, areaCodes: codes)
    }

    static let all: [AreaCodeRegion] = [
        us("AL", "Alabama", ["205", "251", "256", "334", "938"]),
        us("AK", "Alaska", ["907"]),
        us("AZ", "Arizona", ["480", "520", "602", "623", "928"]),
        us("AR", "Arkansas", ["479", "501", "870"]),
        us("CA", "California", ["209", "213", "310", "323", "408", "415", "510", "530", "559", "562", "619", "626", "650", "661", "707", "714", "760", "805", "818", "831", "858", "909", "916", "925", "949", "951"]),
        us("CO", "Colorado", ["303", "719", "720", "970"]),
        us("CT", "Connecticut", ["203", "475", "860", "959"]),
        us("DE", "Delaware", ["302"]),
        us("DC", "District of Columbia", ["202"]),
        us("FL", "Florida", ["239", "305", "321", "352", "386", "407", "561", "727", "754", "772", "786", "813", "850", "863", "904", "941", "954"]),
        us("GA", "Georgia", ["229", "404", "470", "478", "678", "706", "762", "770", "912"]),
        us("HI", "Hawaii", ["808"]),
        us("ID", "Idaho", ["208", "986"]),
        us("IL", "Illinois", ["217", "224", "309", "312", "331", "618", "630", "708", "773", "779", "815", "847", "872"]),
        us("IN", "Indiana", ["219", "260", "317", "463", "574", "765", "812", "930"]),
        us("IA", "Iowa", ["319", "515", "563", "641", "712"]),
        us("KS", "Kansas", ["316", "620", "785", "913"]),
        us("KY", "Kentucky", ["270", "364", "502", "606", "859"]),
        us("LA", "Louisiana", ["225", "318", "337", "504", "985"]),
        us("ME", "Maine", ["207"]),
        us("MD", "Maryland", ["240", "301", "410", "443", "667"]),
        us("MA", "Massachusetts", ["339", "351", "413", "508", "617", "774", "781", "857", "978"]),
        us("MI", "Michigan", ["231", "248", "269", "313", "517", "586", "616", "734", "810", "906", "947", "989"]),
        us("MN", "Minnesota", ["218", "320", "507", "612", "651", "763", "952"]),
        us("MS", "Mississippi", ["228", "601", "662", "769"]),
        us("MO", "Missouri", ["314", "417", "573", "636", "660", "816"]),
        us("MT", "Montana", ["406"]),
        us("NE", "Nebraska", ["308", "402", "531"]),
        us("NV", "Nevada", ["702", "725", "775"]),
        us("NH", "New Hampshire", ["603"]),
        us("NJ", "New Jersey", ["201", "551", "609", "640", "732", "848", "856", "862", "908", "973"]),
        us("NM", "New Mexico", ["505", "575"]),
        us("NY", "New York", ["212", "315", "332", "347", "516", "518", "585", "607", "631", "646", "680", "716", "718", "845", "914", "917", "929", "934"]),
        us("NC", "North Carolina", ["252", "336", "704", "743", "828", "910", "919", "980", "984"]),
        us("ND", "North Dakota", ["701"]),
        us("OH", "Ohio", ["216", "220", "234", "330", "380", "419", "440", "513", "567", "614", "740", "937"]),
        us("OK", "Oklahoma", ["405", "539", "580", "918"]),
        us("OR", "Oregon", ["458", "503", "541", "971"]),
        us("PA", "Pennsylvania", ["215", "223", "267", "272", "412", "445", "484", "570", "610", "717", "724", "814", "878"]),
        us("RI", "Rhode Island", ["401"]),
        us("SC", "South Carolina", ["803", "839", "843", "854", "864"]),
        us("SD", "South Dakota", ["605"]),
        us("TN", "Tennessee", ["423", "615", "629", "731", "865", "901", "931"]),
        us("TX", "Texas", ["210", "214", "254", "281", "325", "346", "361", "409", "430", "432", "469", "512", "682", "713", "726", "737", "806", "817", "830", "832", "903", "915", "936", "940", "956", "972", "979"]),
        us("UT", "Utah", ["385", "435", "801"]),
        us("VT", "Vermont", ["802"]),
        us("VA", "Virginia", ["276", "434", "540", "571", "703", "757", "804"]),
        us("WA", "Washington", ["206", "253", "360", "425", "509", "564"]),
        us("WV", "West Virginia", ["304", "681"]),
        us("WI", "Wisconsin", ["262", "414", "534", "608", "715", "920"]),
        us("WY", "Wyoming", ["307"]),

        ca("AB", "Alberta", ["403", "587", "780", "825"]),
        ca("BC", "British Columbia", ["236", "250", "604", "672", "778"]),
        ca("MB", "Manitoba", ["204", "431"]),
        ca("NB", "New Brunswick", ["506"]),
        ca("NL", "Newfoundland and Labrador", ["709"]),
        ca("NS", "Nova Scotia", ["782", "902"]),
        ca("ON", "Ontario", ["226", "249", "289", "343", "365", "416", "437", "519", "548", "613", "647", "705", "807", "905"]),
        ca("PE", "Prince Edward Island", ["782", "902"]),
        ca("QC", "Quebec", ["367", "418", "438", "450", "514", "579", "581", "819", "873"]),
        ca("SK", "Saskatchewan", ["306", "639"]),
        ca("NT", "Northwest Territories, Nunavut & Yukon", ["867"])
    ]
}
